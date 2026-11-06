import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/quote.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/portfolio_chart.dart';
import '../widgets/symbol_avatar.dart';
import '../widgets/ui/section_header.dart';
import '../widgets/ui/shimmer_skeleton.dart';
import '../widgets/ui/theme_toggle.dart';
import 'advanced_chart_screen.dart';
import 'watchlist_screen.dart';

/// The market at a glance: the big indices, what people are trading, and
/// a search that opens any symbol on the advanced chart.
class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  /// The indices and benchmarks, with names people recognise.
  static const indices = {
    '^GSPC': 'S&P 500',
    '^IXIC': 'Nasdaq',
    '^DJI': 'Dow Jones',
    '^RUT': 'Russell 2000',
    '^GSPTSE': 'TSX',
    'BTC-USD': 'Bitcoin',
    'GC=F': 'Gold',
    'CL=F': 'Crude oil',
  };

  /// Popular stocks and funds most people have heard of.
  static const popular = [
    'NVDA', 'AAPL', 'MSFT', 'AMZN', 'TSLA', 'META', 'GOOGL', 'AMD',
    'SPY', 'QQQ', 'VOO', 'SCHD',
  ];

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  Future<Map<String, Quote>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<PortfolioProvider>();
    final f = provider.marketQuotes([
      ...MarketsScreen.indices.keys,
      ...MarketsScreen.popular,
    ]);
    setState(() => _future = f);
    await f;
  }

  Future<void> _search() async {
    final s = await pickSymbol(context);
    if (s != null && mounted) await openAdvancedChart(context, s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<PortfolioProvider>();
    final held = provider.active.symbols.take(12).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Markets'),
        actions: const [ThemeToggleButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          HapticFeedback.mediumImpact();
          return _load();
        },
        child: FutureBuilder<Map<String, Quote>>(
          future: _future,
          builder: (context, snap) {
            final quotes = snap.data ?? const <String, Quote>{};
            final loading = snap.connectionState != ConnectionState.done;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              children: [
                _SearchField(onTap: _search),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Market pulse'),
                const SizedBox(height: 8),
                LayoutBuilder(builder: (context, c) {
                  final columns = c.maxWidth >= 700 ? 4 : 2;
                  const gap = 10.0;
                  final w = (c.maxWidth - gap * (columns - 1)) / columns;
                  var i = 0;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final e in MarketsScreen.indices.entries)
                        SizedBox(
                          width: w,
                          child: loading && quotes.isEmpty
                              ? const ShimmerSkeleton(width: double.infinity, height: 104, borderRadius: 18)
                              : _IndexTile(symbol: e.key, name: e.value, quote: quotes[e.key])
                                  .animate()
                                  .fadeIn(delay: (40 * i++).ms, duration: 350.ms)
                                  .slideY(begin: .15, end: 0, curve: Curves.easeOutCubic),
                        ),
                    ],
                  );
                }),
                if (held.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const SectionHeader(title: 'Chart your holdings'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final s in held)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              avatar: SymbolAvatar(symbol: s, radius: 10),
                              label: Text(s),
                              onPressed: () => openAdvancedChart(context, s),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const SectionHeader(title: 'Popular right now'),
                const SizedBox(height: 4),
                for (final (i, s) in MarketsScreen.popular.indexed)
                  _PopularRow(symbol: s, quote: quotes[s])
                      .animate()
                      .fadeIn(delay: (30 * i).ms, duration: 300.ms),
                const SizedBox(height: 16),
                Text(
                  'Prices may be delayed. Not investment advice.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchField({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(Icons.search_rounded, color: theme.hintColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Search any stock, ETF or crypto',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor)),
            ),
            Icon(Icons.candlestick_chart_outlined, color: theme.colorScheme.primary, size: 20),
          ]),
        ),
      ),
    );
  }
}

/// One index: its level, today's move, and a month of trend.
class _IndexTile extends StatelessWidget {
  final String symbol;
  final String name;
  final Quote? quote;

  const _IndexTile({required this.symbol, required this.name, required this.quote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final pct = quote?.dayChangePercent;
    final up = (pct ?? 0) >= 0;
    final tone = pct == null ? theme.hintColor : (up ? colors.gain : colors.loss);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openAdvancedChart(context, symbol),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tone.withValues(alpha: .10), tone.withValues(alpha: 0)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
              const SizedBox(height: 2),
              Text(
                quote == null ? '—' : _level(quote!.price),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    pct == null ? '' : '${up ? '▲' : '▼'} ${fmtPct(pct.abs(), signed: false)}',
                    style: TextStyle(color: tone, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const Spacer(),
                  _Spark(symbol: symbol, color: tone),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _level(double v) =>
      v >= 1000 ? fmtMoney(v, currency: null, decimals: 0) : fmtMoney(v, currency: null);
}

/// A popular stock: logo, name, price and today's move.
class _PopularRow extends StatelessWidget {
  final String symbol;
  final Quote? quote;

  const _PopularRow({required this.symbol, required this.quote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final pct = quote?.dayChangePercent;
    final up = (pct ?? 0) >= 0;
    final tone = up ? colors.gain : colors.loss;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openAdvancedChart(context, symbol),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            SymbolAvatar(symbol: symbol, companyName: quote?.name, radius: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(symbol, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(quote?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                ],
              ),
            ),
            _Spark(symbol: symbol, color: tone),
            const SizedBox(width: 12),
            SizedBox(
              width: 86,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(quote == null ? '—' : fmtMoney(quote!.price, currency: quote!.currency),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  const SizedBox(height: 2),
                  if (pct != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: up ? colors.gainContainer : colors.lossContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(fmtPct(pct),
                          style: TextStyle(color: tone, fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spark extends StatefulWidget {
  final String symbol;
  final Color color;
  const _Spark({required this.symbol, required this.color});

  @override
  State<_Spark> createState() => _SparkState();
}

class _SparkState extends State<_Spark> {
  late final Future<List<double>> _future =
      context.read<PortfolioProvider>().symbolSparkline(widget.symbol);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<double>>(
      future: _future,
      builder: (context, snap) {
        final pts = snap.data ?? const <double>[];
        if (pts.length < 2) return const SizedBox(width: 54, height: 22);
        return MiniSparkline(points: pts, color: widget.color)
            .animate()
            .fadeIn(duration: 300.ms);
      },
    );
  }
}
