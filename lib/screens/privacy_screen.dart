import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../theme/app_colors.dart';

/// The app's privacy policy, shown inside the app.
///
/// Google reviews both the Play Console policy URL and, often, the policy
/// reachable from inside the app, so the same text that is published with
/// the web build is rendered here from the very same file.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  String? _text;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('PRIVACY.md');
      if (!mounted) return;
      setState(() => _text = raw);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'The privacy policy could not be loaded: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _text == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    for (final block in _parse(_text!)) block,
                  ],
                ),
    );
  }

  /// A deliberately small Markdown subset: headings, paragraphs, bullets
  /// and bold text. The policy is written in this subset on purpose, so
  /// nothing needs a full Markdown library.
  List<Widget> _parse(String source) {
    final theme = Theme.of(context);
    final blocks = <Widget>[];
    final lines = source.split('\n');
    var paragraph = <String>[];

    void flush() {
      if (paragraph.isEmpty) return;
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _inline(paragraph.join(' ')),
      ));
      paragraph = [];
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flush();
        continue;
      }
      if (trimmed.startsWith('### ')) {
        flush();
        blocks.add(_heading(trimmed.substring(4), 3, theme));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        flush();
        blocks.add(_heading(trimmed.substring(3), 2, theme));
        continue;
      }
      if (trimmed.startsWith('# ')) {
        flush();
        blocks.add(_heading(trimmed.substring(2), 1, theme));
        continue;
      }
      if (trimmed.startsWith('- ')) {
        flush();
        blocks.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 8),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(child: _inline(trimmed.substring(2))),
            ],
          ),
        ));
        continue;
      }
      paragraph.add(trimmed);
    }
    flush();
    return blocks;
  }

  Widget _heading(String text, int level, ThemeData theme) {
    final style = switch (level) {
      1 => theme.textTheme.headlineSmall,
      2 => theme.textTheme.titleLarge,
      _ => theme.textTheme.titleMedium,
    };
    return Padding(
      padding: EdgeInsets.only(top: level == 1 ? 0 : 18, bottom: 8),
      child: Text(
        text,
        style: style?.copyWith(
          fontWeight: FontWeight.w800,
          color: level == 1 ? null : theme.colorScheme.primary,
          letterSpacing: level == 1 ? -0.4 : 0,
        ),
      ),
    );
  }

  /// Renders `**bold**` and `*italic*` inside a paragraph.
  Widget _inline(String text) {
    final theme = Theme.of(context);
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    var index = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else {
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return Text.rich(
      TextSpan(children: spans),
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
    );
  }
}

/// A small helper used by the settings screen.
class PrivacyLink extends StatelessWidget {
  const PrivacyLink({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListTile(
      leading: Icon(Icons.privacy_tip_outlined, color: colors.dividend),
      title: const Text('Privacy policy'),
      subtitle: const Text('What the app stores and what it sends'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PrivacyScreen()),
      ),
    );
  }
}
