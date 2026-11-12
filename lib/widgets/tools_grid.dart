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
import '../theme/tokens.dart';
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

    // One row: side by side when there is room, swiped on a phone. A grid
    // here pushed the holdings a full screen further down.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            children: [
              for (var i = 0; i < tools.length; i++) ...[
                if (i > 0) const SizedBox(width: Sp.gapSmall),
                Expanded(child: tools[i]),
              ],
            ],
          );
        }
        return SizedBox(
          height: _Tool.height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            // Tiles slide out past the page margin instead of being cut at it.
            clipBehavior: Clip.none,
            itemCount: tools.length,
            separatorBuilder: (_, __) => const SizedBox(width: Sp.gapSmall),
            itemBuilder: (_, i) => SizedBox(width: 148, child: tools[i]),
          ),
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

  static const double height = 108;

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
      borderRadius: BorderRadius.circular(Sp.radius - 2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Sp.radius - 2),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: .07)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                    ),
                    child: Icon(icon, size: 18, color: const Color(0xFF060912)),
                  ),
                  const Spacer(),
                  if (locked) const ProBadge(locked: true),
                ],
              ),
              const Spacer(),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
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
