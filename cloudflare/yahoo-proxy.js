// Stock Pulse Yahoo CORS proxy for the Flutter web build.
//
// Deploy (from this folder): npx wrangler deploy
// Use in the app: Settings -> Web build -> proxy URL e.g.
//   https://yahoo-proxy.<yoursubdomain>.workers.dev
//
// The browser cannot call query1.finance.yahoo.com directly (no CORS
// headers), and the cookie+crumb handshake needs the Set-Cookie value which
// JavaScript is never allowed to read - so this proxy:
//   * passes ?url=<target> requests to a fixed allowlist of Yahoo hosts,
//   * re-exposes the Yahoo Set-Cookie as a readable x-set-cookie header,
//   * forwards the client's Cookie header for the crumb handshake,
//   * answers CORS preflights.

const ALLOWED_HOSTS = new Set([
  'query1.finance.yahoo.com',
  'query2.finance.yahoo.com',
  'fc.yahoo.com',
  'finance.yahoo.com',
]);

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Cookie, Accept, User-Agent',
  'Access-Control-Expose-Headers': 'x-set-cookie',
};

export default {
  async fetch(request) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }
    if (request.method !== 'GET') {
      return json({ error: 'GET only' }, 405);
    }

    const u = new URL(request.url);
    const target = u.searchParams.get('url');
    if (!target) return json({ error: 'pass ?url=<encoded yahoo url>' }, 400);

    let parsed;
    try {
      parsed = new URL(target);
    } catch {
      return json({ error: 'invalid url' }, 400);
    }
    if (!ALLOWED_HOSTS.has(parsed.hostname)) {
      return json({ error: 'host not allowed: ' + parsed.hostname }, 403);
    }

    const headers = new Headers();
    headers.set('User-Agent', UA);
    headers.set('Accept', 'application/json, text/plain, */*');
    const accept = request.headers.get('accept');
    if (accept) headers.set('Accept', accept);
    const cookie = request.headers.get('cookie');
    if (cookie) headers.set('Cookie', cookie);

    try {
      const resp = await fetch(parsed.toString(), {
        headers,
        redirect: 'follow',
        cf: { cacheTtl: 0 },
      });
      const out = new Headers(resp.headers);
      out.set('Access-Control-Allow-Origin', '*');
      out.set('Access-Control-Expose-Headers', 'x-set-cookie');
      const setCookie = resp.headers.get('set-cookie');
      if (setCookie) out.set('x-set-cookie', setCookie);
      return new Response(resp.body, { status: resp.status, headers: out });
    } catch (e) {
      return json({ error: 'upstream failed: ' + String(e) }, 502);
    }
  },
};

function json(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}