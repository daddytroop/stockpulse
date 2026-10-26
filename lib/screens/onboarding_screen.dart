import 'package:flutter/material.dart';

import '../widgets/ui/sp_card.dart';

/// One-time, skippable first-run orientation. Core tracking remains usable
/// without holding any account or API keys.
class OnboardingScreen extends StatelessWidget {
  final ValueChanged<String> onAction;
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onAction, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: .18),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                children: [
                  Row(children: [
                    const PulseMark(size: 66),
                    const SizedBox(width: 14),
                    Expanded(child: Text(
                      'Welcome to your money dashboard',
                      style: theme.textTheme.headlineMedium,
                    )),
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    'Stock Pulse is private by default and keeps getting more useful as you add holdings.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 24),
                  _Step(
                    icon: Icons.add_chart,
                    title: 'Add your first holding',
                    copy: 'Track stocks, ETFs, and crypto with a symbol, quantity, and optional cost.',
                    actionLabel: 'Add holding',
                    onPressed: () => onAction('add'),
                  ),
                  _Step(
                    icon: Icons.upload_file_outlined,
                    title: 'Or import everything at once',
                    copy: 'Paste or open a broker CSV. Duplicate rows merge automatically.',
                    actionLabel: 'Import CSV',
                    onPressed: () => onAction('import'),
                  ),
                  _Step(
                    icon: Icons.tune_outlined,
                    title: 'Make it yours later',
                    copy: 'Theme, currency, widgets, backup, sync, and lock live in Settings. No account is required to get the core features.',
                    actionLabel: 'Open settings',
                    onPressed: () => onAction('settings'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prices use Yahoo’s unofficial endpoints and may be delayed or estimated. This app is not investment advice.',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Start exploring'),
                    onPressed: onDone,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PulseMark extends StatelessWidget {
  final double size;
  const PulseMark({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/icon/app_icon_foreground.png', width: size, height: size);
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String title;
  final String copy;
  final String actionLabel;
  final VoidCallback onPressed;

  const _Step({
    required this.icon,
    required this.title,
    required this.copy,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SpCard(
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(copy, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: onPressed,
            child: Text(actionLabel),
          ),
        ])),
      ]),
    );
  }
}
