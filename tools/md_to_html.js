// Converts the privacy policy into a small, standalone web page.
//
// The Play Console and the AdMob console both want a URL a person can
// open, and the app shows the same text. One source of truth: the
// PRIVACY.md file in the repository root.
//
//   node tools/md_to_html.js PRIVACY.md build/web/privacy.html

const fs = require('fs');

const [, , inputPath, outputPath] = process.argv;
if (!inputPath || !outputPath) {
  console.error('usage: node tools/md_to_html.js <input.md> <output.html>');
  process.exit(1);
}

function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function inline(text) {
  return escapeHtml(text)
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>');
}

function convert(markdown) {
  const lines = markdown.split('\n');
  const out = [];
  let paragraph = [];

  const flush = () => {
    if (!paragraph.length) return;
    out.push(`    <p>${inline(paragraph.join(' '))}</p>`);
    paragraph = [];
  };

  for (const raw of lines) {
    const line = raw.trim();
    if (!line) {
      flush();
      continue;
    }
    if (line.startsWith('### ')) {
      flush();
      out.push(`    <h3>${inline(line.slice(4))}</h3>`);
      continue;
    }
    if (line.startsWith('## ')) {
      flush();
      out.push(`    <h2>${inline(line.slice(3))}</h2>`);
      continue;
    }
    if (line.startsWith('# ')) {
      flush();
      out.push(`    <h1>${inline(line.slice(2))}</h1>`);
      continue;
    }
    if (line.startsWith('- ')) {
      flush();
      out.push(`    <li>${inline(line.slice(2))}</li>`);
      continue;
    }
    paragraph.push(line);
  }
  flush();

  // Wrap the loose list items in a single list.
  const html = out
    .join('\n')
    .replace(/((?:    <li>.*<\/li>\n?)+)/g, (block) => `    <ul>\n${block}    </ul>\n`);

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Stock Pulse - Privacy Policy</title>
  <style>
    :root { color-scheme: dark; }
    body {
      margin: 0;
      padding: 40px 20px 80px;
      background: #061620;
      color: #E8EEF2;
      font: 16px/1.6 -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    main { max-width: 720px; margin: 0 auto; }
    h1 { font-size: 30px; letter-spacing: -.5px; margin: 0 0 24px; color: #64EFAE; }
    h2 { font-size: 19px; margin: 32px 0 10px; color: #64EFAE; }
    h3 { font-size: 16px; margin: 24px 0 8px; }
    p { margin: 0 0 14px; }
    ul { margin: 0 0 16px; padding-left: 20px; }
    li { margin-bottom: 8px; }
    strong { color: #fff; }
    a { color: #64EFAE; }
    footer { margin-top: 40px; padding-top: 16px; border-top: 1px solid #1E3A4A;
             color: #8A98A4; font-size: 13px; }
  </style>
</head>
<body>
  <main>
${html}
    <footer>Stock Pulse - a free, open-source portfolio and dividend tracker.</footer>
  </main>
</body>
</html>
`;
}

const markdown = fs.readFileSync(inputPath, 'utf8');
fs.writeFileSync(outputPath, convert(markdown), 'utf8');
console.log(`Wrote ${outputPath}`);
