import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/quote.dart';
import '../providers/portfolio_provider.dart';
import '../services/pro_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/advanced_chart.dart';
import '../widgets/symbol_avatar.dart';
import '../widgets/ui/animated_number.dart';
import '../widgets/ui/shimmer_skeleton.dart';
import '../widgets/ui/sp_card.dart';
import 'pro_screen.dart';
import 'watchlist_screen.dart';

/// Opens the advanced chart for [symbol].
Future<void> openAdvancedChart(BuildContext context, String symbol) {
  HapticFeedback.lightImpact();
  return Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => AdvancedChartScreen(symbol: symbol),
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  ));
}

/// A power-user chart for any symbol, held or not: candles, studies,
/// every range from one day to the whole history.
class AdvancedChartScreen extends StatefulWidget {
  final String symbol;

  const AdvancedChartScreen({super.key, required this.symbol});

  @override
  State<AdvancedChartScreen> createState() => _AdvancedChartScreenState();
}

class _AdvancedChartScreenState extends State<AdvancedChartScreen> {
  static const _ranges = {
    '1d': '1D',
    '5d': '5D',
    '1mo': '1M',
    '3mo': '3M',
    '6mo': '6M',
    'ytd': 'YTD',
    '1y': '1Y',
    '5y': '5Y',
    'max': 'MAX',
  };

  // Remembered for the session, so every chart opens the way the last one
  // was left.
  static String _range = '6mo';
  static ChartStyle _style = ChartStyle.candles;
  static Set<Study> _studies = {Study.volume, Study.sma20};

  late String _symbol = widget.symbol.toUpperCase();
  Future<List<ChartPoint>>? _future;
  Quote? _quote;
  ChartPoint? _scrub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final provider = context.read<PortfolioProvider>();
    setState(() {
      _scrub = null;
      _future = provider.candles(_symbol, _range);
    });
    provider.marketQuotes([_symbol]).then((q) {
      if (mounted) setState(() => _quote = q[_symbol]);
    });
  }

  Future<void> _switchSymbol() async {
    final s = await pickSymbol(context);
    if (s == null || !mounted) return;
    _symbol = s.toUpperCase();
    _quote = null;
    _load();
  }

  Future<void> _toggleWatch() async {
    final provider = context.read<PortfolioProvider>();
    HapticFeedback.selectionClick();
    if (provider.isWatched(_symbol)) {
      await provider.removeFromWatchlist(_symbol);
      return;
    }
    if (!context.read<ProService>().has(ProFeature.watchlist) &&
        provider.watchlist.length >= PortfolioProvider.freeWatchlistLimit) {
      await showProPaywall(context, feature: ProFeature.watchlist);
      if (!mounted || !context.read<ProService>().has(ProFeature.watchlist)) return;
    }
    await provider.addToWatchlist(_symbol);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_symbol added to your watchlist')),
      );
    }
  }

  Future<void> _editStudies() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _StudiesSheet(
        selected: _studies,
        onChanged: (s) => setState(() => _studies = s),
      ),
    );
  }

  /// The studies to draw: Pro ones only while Pro is unlocked.
  Set<Study> _active(ProService pro) => pro.has(ProFeature.charts)
      ? _studies
      : _studies.where((s) => !s.isPro).toSet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final provider = context.watch<PortfolioProvider>();
    final pro = context.watch<ProService>();
    final quote = _quote ?? provider.quoteOf(_symbol);
    final currency = quote?.currency ?? 'USD';
    // Indices are points, not money.
    final isIndex = _symbol.startsWith('^') || quote?.quoteType == 'INDEX';
    String money(double v) => isIndex
        ? NumberFormat('#,##0.00').format(v)
        : fmtMoney(v, currency: currency, decimals: v.abs() < 1 ? 4 : 2);
    final studies = _active(pro);
    final panes = studies.where((s) => s.hasPane).length;
    final watched = provider.isWatched(_symbol);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            SymbolAvatar(symbol: _symbol, companyName: quote?.name, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_symbol, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  if (quote != null && quote.name.isNotEmpty)
                    Text(quote.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chart another symbol',
            icon: const Icon(Icons.search_rounded),
            onPressed: _switchSymbol,
          ),
          IconButton(
            tooltip: watched ? 'Stop watching' : 'Add to watchlist',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(
                watched ? Icons.star_rounded : Icons.star_border_rounded,
                key: ValueKey(watched),
                color: watched ? colors.earnings : null,
              ),
            ),
            onPressed: _toggleWatch,
          ),
        ],
      ),
      body: FutureBuilder<List<ChartPoint>>(
        future: _future,
        builder: (context, snap) {
          final points = snap.data ?? const <ChartPoint>[];
          final loading = snap.connectionState != ConnectionState.done;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _header(context, quote, points, money),
              const SizedBox(height: 12),
              _rangeBar(context),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StyleToggle(
                    style: _style,
                    onChanged: (s) {
                      HapticFeedback.selectionClick();
                      setState(() => _style = s);
                    },
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _editStudies,
                    icon: const Icon(Icons.stacked_line_chart_rounded, size: 18),
                    label: Text('Studies${studies.isEmpty ? '' : ' · ${studies.length}'}'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _legend(context, studies),
              SizedBox(
                height: 340.0 + panes * 96,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: loading && points.isEmpty
                      ? ShimmerSkeleton.chart(height: 340.0 + panes * 96)
                      : AdvancedChart(
                          key: ValueKey('$_symbol|$_range'),
                          points: points,
                          style: _style,
                          studies: studies,
                          intraday: _range == '1d' || _range == '5d' || _range == '1mo',
                          formatPrice: (v) => _axisPrice(v),
                          onScrub: (p) => setState(() => _scrub = p),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Drag to read a bar · pinch or scroll to zoom · double-tap to reset',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                ),
              ),
              const SizedBox(height: 16),
              if (points.length > 1) _stats(context, quote, points, money),
            ],
          );
        },
      ),
    );
  }

  /// Compact prices for the axis: no currency symbol, fewer digits.
  String _axisPrice(double v) {
    final a = v.abs();
    if (a >= 100000) return NumberFormat.compact().format(v);
    if (a >= 1000) return NumberFormat('#,##0').format(v);
    if (a >= 1) return v.toStringAsFixed(2);
    return v.toStringAsFixed(4);
  }

  Widget _header(BuildContext context, Quote? quote, List<ChartPoint> points,
      String Function(double) money) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final scrub = _scrub;
    final price = scrub?.close ?? quote?.price ?? (points.isNotEmpty ? points.last.close : 0);
    final base = points.isNotEmpty ? points.first.close : null;
    final change = base == null ? null : price - base;
    final pct = base == null || base == 0 ? null : change! / base * 100;
    final up = (change ?? 0) >= 0;
    final tone = up ? colors.gain : colors.loss;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedNumber(
          value: price,
          formatter: (v) => money(v.toDouble()),
          duration: const Duration(milliseconds: 300),
          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        // Switches instantly: reading the chart should feel immediate.
        SizedBox(
          height: 24,
          child: scrub != null
              ? _scrubLine(context, scrub, money)
              : Row(
                  key: const ValueKey('change'),
                  children: [
                    if (change != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: up ? colors.gainContainer : colors.lossContainer,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 14, color: tone),
                          const SizedBox(width: 2),
                          Text('${change >= 0 ? '+' : '-'}${money(change.abs())} (${fmtPct(pct)})',
                              style: TextStyle(color: tone, fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ]),
                      ),
                    const SizedBox(width: 8),
                    Text(_rangeWords(),
                        style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
                    const Spacer(),
                    if (quote?.marketState != null) _MarketState(state: quote!.marketState!),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _scrubLine(BuildContext context, ChartPoint p, String Function(double) money) {
    final theme = Theme.of(context);
    final intraday = _range == '1d' || _range == '5d' || _range == '1mo';
    final when = intraday
        ? DateFormat('EEE d MMM, HH:mm').format(p.time)
        : DateFormat('EEE d MMM yyyy').format(p.time);
    final style = theme.textTheme.labelMedium?.copyWith(color: theme.hintColor);
    final bold = theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800);
    return Wrap(
      key: const ValueKey('scrub'),
      spacing: 10,
      runSpacing: 2,
      children: [
        Text(when, style: bold),
        Text.rich(TextSpan(children: [TextSpan(text: 'O ', style: style), TextSpan(text: money(p.open), style: bold)])),
        Text.rich(TextSpan(children: [TextSpan(text: 'H ', style: style), TextSpan(text: money(p.high), style: bold)])),
        Text.rich(TextSpan(children: [TextSpan(text: 'L ', style: style), TextSpan(text: money(p.low), style: bold)])),
        if (p.volume > 0)
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Vol ', style: style),
            TextSpan(text: NumberFormat.compact().format(p.volume), style: bold),
          ])),
      ],
    );
  }

  String _rangeWords() => switch (_range) {
        '1d' => 'today',
        '5d' => 'past 5 days',
        '1mo' => 'past month',
        '3mo' => 'past 3 months',
        '6mo' => 'past 6 months',
        'ytd' => 'this year',
        '1y' => 'past year',
        '5y' => 'past 5 years',
        _ => 'all time',
      };

  Widget _rangeBar(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final e in _ranges.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  if (_range == e.key) return;
                  HapticFeedback.selectionClick();
                  _range = e.key;
                  _load();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _range == e.key
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: _range == e.key
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Set<Study> studies) {
    final lines = studies.where((s) => studyColors.containsKey(s) || s == Study.bollinger);
    if (lines.isEmpty) return const SizedBox(height: 4);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final s in lines)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 12,
                height: 3,
                decoration: BoxDecoration(
                  color: studyColors[s] ?? theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Text(s.label, style: theme.textTheme.labelSmall),
            ]),
        ],
      ),
    );
  }

  Widget _stats(BuildContext context, Quote? quote, List<ChartPoint> points,
      String Function(double) money) {
    final hi = points.map((p) => p.high).reduce(max);
    final lo = points.map((p) => p.low).reduce(min);
    final vols = points.map((p) => p.volume).where((v) => v > 0).toList();
    final avgVol = vols.isEmpty ? null : vols.reduce((a, b) => a + b) / vols.length;

    // Daily-ish volatility from bar-to-bar moves, annualised for daily bars.
    double? vol;
    if (points.length > 10 && !(_range == '1d' || _range == '5d' || _range == '1mo')) {
      final rets = <double>[];
      for (var i = 1; i < points.length; i++) {
        rets.add(log(points[i].close / points[i - 1].close));
      }
      final mean = rets.reduce((a, b) => a + b) / rets.length;
      final variance = rets.map((r) => (r - mean) * (r - mean)).reduce((a, b) => a + b) / rets.length;
      final perYear = _range == '5y' ? 52 : (_range == 'max' ? 12 : 252);
      vol = sqrt(variance) * sqrt(perYear) * 100;
    }

    final items = <(String, String)>[
      ('Range high', money(hi)),
      ('Range low', money(lo)),
      if (quote?.previousClose != null) ('Previous close', money(quote!.previousClose!)),
      if (quote?.fiftyTwoWeekHigh != null) ('52-week high', money(quote!.fiftyTwoWeekHigh!)),
      if (quote?.fiftyTwoWeekLow != null) ('52-week low', money(quote!.fiftyTwoWeekLow!)),
      if (avgVol != null) ('Avg volume / bar', NumberFormat.compact().format(avgVol)),
      if (vol != null) ('Volatility (yearly)', '${vol.toStringAsFixed(1)}%'),
      if (quote?.dividendYield != null && quote!.dividendYield! > 0)
        ('Dividend yield', fmtPct(quote.dividendYield! * (quote.dividendYield! < 1 ? 100 : 1), signed: false)),
    ];
    final theme = Theme.of(context);
    return SpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Key stats', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (label, value) in items)
                  SizedBox(
                    width: w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
                        const SizedBox(height: 2),
                        Text(value,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _StyleToggle extends StatelessWidget {
  final ChartStyle style;
  final ValueChanged<ChartStyle> onChanged;

  const _StyleToggle({required this.style, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ChartStyle>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(
          value: ChartStyle.line,
          icon: Icon(Icons.show_chart_rounded, size: 18),
          tooltip: 'Line',
        ),
        ButtonSegment(
          value: ChartStyle.candles,
          icon: Icon(Icons.candlestick_chart_outlined, size: 18),
          tooltip: 'Candles',
        ),
      ],
      selected: {style},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _MarketState extends StatelessWidget {
  final String state;
  const _MarketState({required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final open = state == 'REGULAR';
    final label = switch (state) {
      'REGULAR' => 'Market open',
      'PRE' || 'PREPRE' => 'Pre-market',
      'POST' || 'POSTPOST' => 'After hours',
      _ => 'Market closed',
    };
    final c = open ? colors.gain : Theme.of(context).hintColor;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _StudiesSheet extends StatefulWidget {
  final Set<Study> selected;
  final ValueChanged<Set<Study>> onChanged;

  const _StudiesSheet({required this.selected, required this.onChanged});

  @override
  State<_StudiesSheet> createState() => _StudiesSheetState();
}

class _StudiesSheetState extends State<_StudiesSheet> {
  late final Set<Study> _selected = {...widget.selected};

  Future<void> _toggle(Study s, bool on) async {
    if (on && s.isPro && !context.read<ProService>().has(ProFeature.charts)) {
      final ok = await showProPaywall(context, feature: ProFeature.charts);
      if (!ok || !mounted) return;
    }
    HapticFeedback.selectionClick();
    setState(() => on ? _selected.add(s) : _selected.remove(s));
    widget.onChanged({..._selected});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pro = context.watch<ProService>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text('Studies',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            ),
            for (final s in Study.values)
              SwitchListTile(
                value: _selected.contains(s) && (!s.isPro || pro.has(ProFeature.charts)),
                onChanged: (v) => _toggle(s, v),
                secondary: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: studyColors[s] ??
                        (s == Study.rsi
                            ? const Color(0xFF8B5CF6)
                            : s == Study.macd
                                ? const Color(0xFF3B82F6)
                                : s == Study.volume
                                    ? theme.hintColor
                                    : theme.colorScheme.secondary),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Row(children: [
                  Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (s.isPro) ...[
                    const SizedBox(width: 8),
                    ProBadge(locked: !pro.has(ProFeature.charts)),
                  ],
                ]),
                subtitle: Text(s.detail),
              ),
          ],
        ),
      ),
    );
  }
}
