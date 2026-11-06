import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/portfolio_provider.dart';
import '../screens/advanced_chart_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/pro_screen.dart';
import '../screens/recap_screen.dart';
import '../screens/snowball_screen.dart';
import '../screens/watchlist_screen.dart';
import '../services/pro_service.dart';
import 'ui/page_transitions.dart';

/// The portfolio screen's tools: the Pro features and the free recap.
///
/// Locked tools wear a PRO tag and open the Pro page; nothing pops up on
/// its own.
class ToolsGrid extends StatelessWidget {
  const ToolsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProService>();
    final watching = context.select<PortfolioProvider, int>((p) => p.watchlist.length);
    final tools = [
      _Tool(
        icon: Icons.ac_unit_rounded,
        title: 'Dividend snowball',
        subtitle: 'Your income in 10 years',
        colors: const [Color(0xFF00F5A0), Color(0xFF00D9F5)],
        locked: !pro.has(ProFeature.snowball),
        onTap: () => openProFeature(context, ProFeature.snowball, () => const SnowballScreen()),
      ),
      _Tool(
        icon: Icons.health_and_safety_outlined,
        title: 'Portfolio health',
        subtitle: 'Diversification score',
        colors: const [Color(0xFF7C5CFF), Color(0xFFFF3BCB)],
        locked: !pro.has(ProFeature.insights),
        onTap: () => openProFeature(context, ProFeature.insights, () => const InsightsScreen()),
      ),
      _Tool(
        icon: Icons.visibility_outlined,
        title: 'Watchlist',
        subtitle: watching == 0 ? 'Follow stocks you want' : '$watching followed',
        colors: const [Color(0xFF3B82F6), Color(0xFF00D9F5)],
        // The watchlist itself is free up to a few stocks.
        locked: false,
        onTap: () => pushSharedAxis(context, const WatchlistScreen()),
      ),
      _Tool(
        icon: Icons.candlestick_chart_outlined,
        title: 'Advanced charts',
        subtitle: 'Candles, RSI, MACD & more',
        colors: const [Color(0xFF22D3EE), Color(0xFF7C5CFF)],
        locked: false,
        onTap: () {
          final held = context.read<PortfolioProvider>().active.symbols;
          openAdvancedChart(context, held.isEmpty ? 'SPY' : held.first);
        },
      ),
      _Tool(
        icon: Icons.ios_share_rounded,
        title: 'Share recap',
        subtitle: 'Your month in a picture',
        colors: const [Color(0xFFFFB547), Color(0xFFFF3B6B)],
        locked: false,
        onTap: () => pushSharedAxis(context, const RecapScreen()),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < tools.length; i++)
              SizedBox(
                // An odd tile out spans the row instead of leaving a gap.
                width: i == tools.length - 1 && tools.length % columns != 0
                    ? constraints.maxWidth
                    : width,
                child: tools[i],
              ),
          ],
        );
      },
    );
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final bool locked;
  final VoidCallback onTap;

  const _Tool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? colors.first.withValues(alpha: .22)
                  : theme.colorScheme.outline.withValues(alpha: .1),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.first.withValues(alpha: isDark ? .12 : .08),
                colors.last.withValues(alpha: isDark ? .03 : .02),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(colors: colors),
                      boxShadow: [
                        BoxShadow(color: colors.first.withValues(alpha: .35), blurRadius: 12),
                      ],
                    ),
                    child: Icon(icon, size: 20, color: const Color(0xFF060912)),
                  ),
                  const Spacer(),
                  if (locked) const ProBadge(locked: true),
                ],
              ),
              const SizedBox(height: 12),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
            ],
          ),
        ),
      ),
    );
  }
}
