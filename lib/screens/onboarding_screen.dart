import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/pulse_logo.dart';
import '../widgets/ui/entrance.dart';
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
            end: Alignment.center,
            colors: [
              theme.colorScheme.primary.withValues(alpha: .16),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  // The choices scroll if the screen is short; the button
                  // below always stays in reach.
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(Sp.page + 4, 28, Sp.page + 4, 12),
                      children: [
                        Entrance(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const PulseMark(size: 52),
                              const SizedBox(height: 18),
                              Text(
                                'Welcome to your money dashboard',
                                style: theme.textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Private by default, no account needed. Pick where to start.',
                                style: theme.textTheme.bodyLarge
                                    ?.copyWith(color: theme.hintColor),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Entrance(
                          order: 2,
                          child: _Step(
                            icon: Icons.add_chart,
                            title: 'Add your first holding',
                            copy: 'A symbol, how many you own, and what you paid.',
                            onPressed: () => onAction('add'),
                          ),
                        ),
                        Entrance(
                          order: 3,
                          child: _Step(
                            icon: Icons.upload_file_outlined,
                            title: 'Or import everything at once',
                            copy: 'Paste or open a CSV from your broker.',
                            onPressed: () => onAction('import'),
                          ),
                        ),
                        Entrance(
                          order: 4,
                          child: _Step(
                            icon: Icons.candlestick_chart_outlined,
                            title: 'Or just watch the markets',
                            copy: 'Indices, popular stocks and pro charts.',
                            onPressed: () => onAction('markets'),
                          ),
                        ),
                        Entrance(
                          order: 5,
                          child: _Step(
                            icon: Icons.tune_outlined,
                            title: 'Make it yours',
                            copy: 'Theme, currency, widgets, backup and lock.',
                            onPressed: () => onAction('settings'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Sp.page + 4, 4, Sp.page + 4, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          key: const ValueKey('onboarding-start'),
                          onPressed: onDone,
                          child: const Text('Start exploring'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Prices come from Yahoo Finance and may be delayed. Not investment advice.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
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
    return PulseLogo(size: size);
  }
}

/// One way to start: the whole card is the button.
class _Step extends StatelessWidget {
  final IconData icon;
  final String title;
  final String copy;
  final VoidCallback onPressed;

  const _Step({
    required this.icon,
    required this.title,
    required this.copy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      child: SpCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        onTap: onPressed,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(Sp.radiusSmall),
              ),
              child: Icon(icon, size: 22, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(copy,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
