import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';

/// The highlights of this release, shown once to people who update.
Future<void> showWhatsNewSheet(BuildContext context, {VoidCallback? onOpenMarkets}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _WhatsNew(onOpenMarkets: onOpenMarkets),
  );
}

class _WhatsNew extends StatelessWidget {
  final VoidCallback? onOpenMarkets;
  const _WhatsNew({this.onOpenMarkets});

  static const _items = [
    (
      Icons.dashboard_customize_outlined,
      'A cleaner home screen',
      'Your balance and its chart now share one card, and the rest fits in half the scrolling.',
    ),
    (
      Icons.view_agenda_outlined,
      'Tidier holdings',
      "Holdings sit in compact lists by market. Sort by size or by today's movers.",
    ),
    (
      Icons.show_chart_rounded,
      'Holding pages, rebuilt',
      'Price, chart, value, total gain and weight together at the top.',
    ),
    (
      Icons.bolt_rounded,
      'Faster and lighter',
      'The app opens quicker, scrolls smoother and uses less battery.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = AppColors.of(context).accentGradient;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (r) => LinearGradient(colors: gradient).createShader(r),
              child: Text(
                "What's new",
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ).animate().fadeIn(duration: 400.ms).slideX(begin: -.05, end: 0),
            const SizedBox(height: 4),
            Text('Stock Pulse 1.7',
                style: theme.textTheme.labelLarge?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 18),
            for (final (i, item) in _items.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: LinearGradient(colors: [
                          gradient[i % gradient.length],
                          gradient[(i + 1) % gradient.length],
                        ]),
                      ),
                      child: Icon(item.$1, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$2, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(item.$3,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: (120 + 90 * i).ms, duration: 380.ms)
                  .slideY(begin: .25, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it'),
                  ),
                ),
                if (onOpenMarkets != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.candlestick_chart_outlined, size: 18),
                      label: const Text('Open Markets'),
                      onPressed: () {
                        Navigator.pop(context);
                        onOpenMarkets!();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
