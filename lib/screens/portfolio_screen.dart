import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/holding.dart';
import '../models/portfolio.dart';
import '../models/quote.dart';
import '../providers/portfolio_provider.dart';
import '../services/ad_service.dart';
import '../services/app_navigation.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';
import '../utils/market_identity.dart';
import '../widgets/allocation_donut.dart';
import '../widgets/ad_slot.dart';
import '../widgets/portfolio_chart.dart';
import '../widgets/pulse_logo.dart';
import '../widgets/symbol_avatar.dart';
import '../widgets/tools_grid.dart';
import '../widgets/ui/animated_number.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/entrance.dart';
import '../widgets/ui/kpi_tile.dart';
import '../widgets/ui/page_transitions.dart';
import '../widgets/ui/pulse_indicator.dart';
import '../widgets/ui/range_selector.dart';
import '../widgets/ui/section_header.dart';
import '../widgets/ui/shimmer_skeleton.dart';
import '../widgets/ui/sp_card.dart';
import '../widgets/ui/text_prompt.dart';
import '../widgets/ui/theme_toggle.dart';
import '../widgets/ui/whats_new_card.dart';
import 'add_edit_holding_sheet.dart';
import 'holding_detail_screen.dart';
import 'import_screen.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  String _range = '3mo';
  String _allocBy = 'type';
  String _query = '';
  String _sort = 'symbol';
  bool _compare = false;

  /// Whether the chart shows the total return (value + dividends) instead
  /// of the price alone.
  bool _totalReturn = false;
  bool _groupByMarket = true;
  String? _historyKey;
  Future<List<List<ChartPoint>?>>? _history;

  static const _rangeLabels = {
    '1mo': '1M', '3mo': '3M', '6mo': '6M', '1y': '1Y', '2y': '2Y', '5y': '5Y',
  };

  /// When the screen first appeared. Its blocks ease in only then, not
  /// every time they scroll back into view.
  final DateTime _shownAt = DateTime.now();

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh(PortfolioProvider provider) async {
    await provider.refreshQuotes();
    await provider.ensureDividendInfo();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final portfolio = provider.active;
    final totals = provider.totalsFor(portfolio);
    final currency = totals.displayCurrency ??
        (portfolio.holdings.isEmpty ? null : portfolio.holdings.values.first.currency);
    final events = provider.upcomingEventsFor([portfolio], horizonDays: 90).take(5).toList();
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final query = _query.toLowerCase();
    final holdings = portfolio.holdings.values
        .where((h) => '${h.symbol} ${h.name}'.toLowerCase().contains(query))
        .toList();
    double valueOf(Holding h) => (provider.quoteOf(h.symbol)?.price ?? 0) * h.quantity;
    double dayOf(Holding h) =>
        provider.quoteOf(h.symbol)?.dayChangePercent ?? double.negativeInfinity;
    holdings.sort((a, b) => switch (_sort) {
          'day' => dayOf(b).compareTo(dayOf(a)),
          'value' => valueOf(b).compareTo(valueOf(a)),
          _ => a.symbol.compareTo(b.symbol),
        });

    final entering =
        DateTime.now().difference(_shownAt) < const Duration(milliseconds: 1500);
    var order = 0;
    Widget enter(Widget child) =>
        Entrance(order: order++, enabled: entering, child: child);

    // The story first, like a good finance app: what it's worth and how it
    // got here, then the details. The list is built lazily, so a long
    // portfolio costs nothing until it is scrolled to.
    final items = <Widget>[
      if (provider.lastError != null)
        _errorBanner(context, provider.lastError!)
      else if (provider.quotesLoading)
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: LinearProgressIndicator(minHeight: 2),
        )
      else
        const SizedBox.shrink(),
      _freshnessBanner(context, provider),
      enter(_heroCard(context, portfolio, provider, totals, currency, colors)),
      enter(Padding(
        padding: const EdgeInsets.only(bottom: Sp.gap),
        child: _kpiRow(context, provider, portfolio, totals, currency),
      )),
      enter(WhatsNewCard(provider: provider, portfolio: portfolio, currency: currency)),
      enter(const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Tools'),
          ToolsGrid(),
          SizedBox(height: Sp.gap + 4),
        ],
      )),
      if (portfolio.holdings.isNotEmpty)
        enter(_allocationCard(
            context, provider, portfolio, totals.displayCurrency ?? currency)),
      if (events.isNotEmpty) ...[
        const SectionHeader(title: 'Upcoming', subtitle: 'Dividends and earnings, next 90 days'),
        _eventsCard(context, events, colors),
      ],
      if (portfolio.holdings.isEmpty)
        _emptyState(context)
      else ...[
        _holdingsHeader(context, portfolio.holdings.length),
        if (holdings.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No matching holdings')),
          ),
        ..._groupedHoldings(context, provider, portfolio.id, holdings),
        // A native ad after the holdings (inside a long list, see
        // _groupedHoldings), and a banner at the very end of the
        // screen. Both sit below the content the user came for.
        if (holdings.length < _inFeedAdMinHoldings)
          const AdSlot(placement: AdPlacement.holdingsNative, native: true),
        const AdSlot(placement: AdPlacement.portfolioBanner),
        const SizedBox(height: 12),
        _dataProvenance(context, provider),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Prices from Yahoo Finance (unofficial). Values are estimates,\nnot investment advice.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          ),
        ),
      ],
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Row(
          children: [
            const PulseLogo(size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor),
                  ),
                  _portfolioSelector(context, provider),
                ],
              ),
            ),
          ],
        ),
        actions: [
          const ThemeToggleButton(),
          _refreshButton(context, provider),
          _moreMenu(context, provider, portfolio),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'addHolding',
        tooltip: 'Add holding',
        elevation: 1.5,
        child: const Icon(Icons.add),
        onPressed: () => showAddEditHoldingSheet(context, provider, portfolio.id),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(provider),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView.builder(
              key: const PageStorageKey('portfolio-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Sp.page, 4, Sp.page, 104),
              itemCount: items.length,
              itemBuilder: (context, i) => items[i],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  /// A friendly hello that follows the time of day.
  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Up late? Here\'s your portfolio';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _portfolioSelector(BuildContext context, PortfolioProvider provider) {
    if (provider.portfolios.length == 1) {
      final p = provider.portfolios.first;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(p.name, overflow: TextOverflow.ellipsis),
          if (provider.portfolioCount > 1) const Icon(Icons.expand_more, size: 22),
        ],
      );
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: provider.activeIndex.clamp(0, provider.portfolios.length - 1),
        borderRadius: BorderRadius.circular(12),
        isDense: true,
        items: [
          for (var i = 0; i < provider.portfolios.length; i++)
            DropdownMenuItem(
              value: i,
              child: Text(
                provider.portfolios[i].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (i) {
          if (i != null) provider.setActiveIndex(i);
        },
      ),
    );
  }

  Widget _refreshButton(BuildContext context, PortfolioProvider provider) {
    if (provider.quotesLoading) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    return IconButton(
      icon: const Icon(Icons.refresh),
      tooltip: 'Refresh quotes',
      onPressed: () async {
        await provider.refreshQuotes();
        await provider.ensureDividendInfo();
      },
    );
  }

  Widget _moreMenu(BuildContext context, PortfolioProvider provider, Portfolio portfolio) {
    return PopupMenuButton<String>(
      onSelected: (v) async {
        switch (v) {
          case 'rename':
            final name = await promptText(context, title: 'Rename portfolio', initial: portfolio.name);
            if (name != null && name.trim().isNotEmpty) {
              provider.renamePortfolio(portfolio.id, name);
            }
          case 'add':
            final name = await promptText(context, title: 'New portfolio', hint: 'e.g. Retirement');
            if (name != null && name.trim().isNotEmpty) provider.addPortfolio(name);
          case 'delete':
            if (provider.portfolioCount > 1) {
              provider.deletePortfolio(portfolio.id);
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Keep at least one portfolio.')),
              );
            }
          case 'import':
            if (context.mounted) {
              pushSharedAxis(context, const ImportScreen());
            }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'rename', child: Row(children: [
            Icon(Icons.edit_outlined, size: 20), SizedBox(width: 10), Text('Rename portfolio')])),
        PopupMenuItem(value: 'add', child: Row(children: [
            Icon(Icons.playlist_add, size: 20), SizedBox(width: 10), Text('New portfolio')])),
        PopupMenuItem(value: 'import', child: Row(children: [
            Icon(Icons.upload_file_outlined, size: 20), SizedBox(width: 10), Text('Import holdings')])),
        PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Row(children: [
            Icon(Icons.delete_outline, size: 20), SizedBox(width: 10), Text('Delete portfolio')])),
      ],
    );
  }

  Widget _allocationCard(BuildContext context, PortfolioProvider provider,
      Portfolio portfolio, String? currency) {
    if (portfolio.holdings.isEmpty) return const SizedBox.shrink();
    final slices = provider.allocationFor(portfolio, by: _allocBy);
    final theme = Theme.of(context);
    final industryPending = _allocBy == 'industry' && provider.profilesLoading;

    return SpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Allocation', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              SegmentedButton<String>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 'type', label: Text('Type')),
                  ButtonSegment(value: 'currency', label: Text('Currency')),
                  ButtonSegment(value: 'industry', label: Text('Industry')),
                ],
                selected: {_allocBy},
                onSelectionChanged: (s) => _selectAllocation(provider, s.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (industryPending)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const SizedBox(
                      width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6)),
                  const SizedBox(width: 8),
                  Text(
                    'Looking up industries…',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
          AllocationDonut(slices: slices, currency: currency),
        ],
      ),
    );
  }

  /// Switches the allocation view and loads the data it needs.
  void _selectAllocation(PortfolioProvider provider, String by) {
    setState(() => _allocBy = by);
    if (by == 'industry' || by == 'sector') {
      provider.ensureProfiles(provider.active.symbols.toSet());
    }
  }

  Widget _errorBanner(BuildContext context, String message) {
    final theme = Theme.of(context);
    return SpCard(
      gradient: [theme.colorScheme.errorContainer, theme.colorScheme.errorContainer],
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: () async {
              final provider = context.read<PortfolioProvider>();
              await provider.refreshQuotes();
              await provider.ensureDividendInfo();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _freshnessBanner(BuildContext context, PortfolioProvider provider) {
    if (provider.quotesLoading || provider.lastError != null) return const SizedBox.shrink();
    final at = provider.lastRefreshAt;
    if (at != null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SpCard(
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Quotes have not refreshed yet. Pull down to try again.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () async {
              await provider.refreshQuotes();
              await provider.ensureDividendInfo();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// The at-a-glance metric row under the balance.
  ///
  /// Every tile is a live number from the quote data - no approximations -
  /// and each one is tappable to drill into the screen that explains it.
  Widget _kpiRow(
    BuildContext context,
    PortfolioProvider provider,
    Portfolio portfolio,
    PortfolioTotals totals,
    String? currency,
  ) {
    final colors = AppColors.of(context);
    final dayUp = totals.dayChange >= 0;

    return KpiRow(
      tiles: [
        KpiTile(
          label: 'Today',
          value: totals.hasDayChange ? totals.dayChange : 0,
          formatter: (v) => fmtSignedMoney(v, currency: currency),
          valueColor:
              totals.hasDayChange ? (dayUp ? colors.gain : colors.loss) : null,
          icon: dayUp ? Icons.trending_up : Icons.trending_down,
          sub: totals.hasDayChange
              ? '${fmtPct(totals.dayChangePercent)} vs yesterday'
              : 'No quote yet',
          onTap: () => _openTab(context, 1),
        ),
        KpiTile(
          label: 'Total return',
          value: totals.totalReturn,
          formatter: (v) => fmtSignedMoney(v, currency: currency),
          valueColor: totals.totalReturn >= 0 ? colors.gain : colors.loss,
          icon: totals.totalReturn >= 0 ? Icons.savings_outlined : Icons.trending_down,
          sub: totals.dividendsReceived > 0
              ? '${fmtPct(totals.totalReturnPercent)} with dividends'
              : '${fmtPct(totals.totalReturnPercent)} on cost',
        ),
        KpiTile(
          label: 'Annual income',
          value: totals.annualIncome,
          formatter: (v) => fmtMoney(v, currency: currency),
          valueColor: colors.dividend,
          icon: Icons.payments_outlined,
          sub: provider.withholdingCountry.isNotEmpty
              ? '≈ ${fmtMoney(provider.netAnnualIncomeFor(portfolio), currency: currency)} after tax'
              : (totals.incomeYield > 0
                  ? '${fmtPct(totals.incomeYield, signed: false)} yield'
                  : 'From dividends'),
          onTap: () => _openTab(context, 1),
        ),
        KpiTile(
          label: 'Holdings',
          value: provider.active.holdings.length,
          formatter: (v) => '${v.round()}',
          icon: Icons.pie_chart_outline,
          sub: provider.active.holdings.isEmpty
              ? 'Add your first'
              : '${_marketCount(provider)} markets',
        ),
      ],
    );
  }

  /// How many distinct markets the holdings span.
  int _marketCount(PortfolioProvider provider) {
    final markets = <String>{};
    for (final h in provider.active.holdings.values) {
      final q = provider.quoteOf(h.symbol);
      markets.add(marketFor(
        symbol: h.symbol,
        exchangeCode: q?.exchange,
        exchangeName: q?.fullExchangeName,
        quoteType: q?.quoteType,
      ) ??
          'Other');
    }
    return markets.length;
  }

  void _openTab(BuildContext context, int index) {
    context.read<AppNavigation>().goTo(index);
  }

  /// Shows where the numbers come from and how fresh they are.
  ///
  /// Every price is a real quote from Yahoo Finance. The exchange timestamp
  /// Yahoo reports is shown next to the time the app fetched it, so a delayed
  /// or stale price is never presented as a live one.
  Widget _dataProvenance(BuildContext context, PortfolioProvider provider) {
    final theme = Theme.of(context);
    final holdings = provider.active.holdings.values;
    if (holdings.isEmpty) return const SizedBox.shrink();

    // The newest exchange timestamp across the holdings.
    DateTime? newest;
    var withQuote = 0;
    var missing = 0;
    for (final h in holdings) {
      final q = provider.quoteOf(h.symbol);
      if (q == null || q.price <= 0) {
        missing++;
        continue;
      }
      withQuote++;
      final t = q.marketTime;
      if (t != null && (newest == null || t.isAfter(newest))) newest = t;
    }

    final refreshedAt = provider.lastRefreshAt;
    final rows = <String>[];
    rows.add('Source: Yahoo Finance (unofficial endpoints)');
    if (newest != null) {
      rows.add('Prices as of ${fmtTime(newest)} exchange time');
    }
    if (refreshedAt != null) {
      rows.add('Fetched ${timeAgo(refreshedAt)}');
    }
    rows.add('Quotes may be delayed; not exchange real-time');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                row,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                  height: 1.4,
                ),
              ),
            ),
          if (missing > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$missing of ${holdings.length} holdings have no quote yet.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (withQuote > 0 && missing == 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'All $withQuote holdings priced.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The top of the screen in one card: what the portfolio is worth, how
  /// today went, and the chart of how it got here.
  Widget _heroCard(BuildContext context, Portfolio portfolio, PortfolioProvider provider,
      PortfolioTotals t, String? currency, AppColors colors) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final up = t.dayChange >= 0;
    final mood = t.hasDayChange ? (up ? colors.gain : colors.loss) : scheme.primary;

    return SpCard(
      padding: EdgeInsets.zero,
      glow: colors.glow ? mood : null,
      borderRadius: 22,
      child: Stack(
        children: [
          // A soft orb of the day's colour in the corner.
          Positioned(
            right: -80,
            top: -100,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    mood.withValues(alpha: isDark ? .20 : .12),
                    mood.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
          ),
          // A band of light that sweeps across the card now and then.
          const Positioned.fill(child: IgnorePointer(child: _Sheen())),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Total balance',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.hintColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (portfolio.name.startsWith('Sample')) ...[
                      const SizedBox(width: 8),
                      const _Pill(label: 'Sample'),
                    ],
                    const Spacer(),
                    if (t.hasDayChange) ...[
                      PulseIndicator(size: 6, color: mood),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: mood,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedNumber(
                    value: t.marketValue,
                    formatter: (v) => fmtMoney(v, currency: currency),
                    style: theme.textTheme.displayLarge,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MoodPill(
                      color: mood,
                      icon: !t.hasDayChange
                          ? Icons.remove
                          : (up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                      label: t.hasDayChange
                          ? '${fmtSignedMoney(t.dayChange, currency: currency)} · ${fmtPct(t.dayChangePercent)} today'
                          : 'No change data yet',
                    ),
                    if (t.converted && t.displayCurrency != null)
                      _Pill(label: 'in ${t.displayCurrency}', icon: Icons.currency_exchange),
                    if (t.hasDayChange)
                      _Pill(
                        label: 'Cost ${fmtMoney(t.costBasis, currency: currency)}',
                        icon: Icons.savings_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                _chart(context, portfolio, provider, currency),
                const SizedBox(height: 4),
                RangeSelector(
                  ranges: _rangeLabels,
                  selected: _range,
                  onChanged: (r) => setState(() => _range = r),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Toggle(
                      label: 'Compare SPY',
                      selected: _compare,
                      onChanged: (v) => setState(() => _compare = v),
                    ),
                    const SizedBox(width: 8),
                    _Toggle(
                      label: 'Total return',
                      selected: _totalReturn,
                      onChanged: (v) => setState(() => _totalReturn = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context, Portfolio portfolio, PortfolioProvider provider,
      String? currency) {
    final key = '${portfolio.id}|$_range|${portfolio.holdings.values.map((h) => '${h.symbol}:${h.quantity}').join(',')}|${provider.lastRefreshAt}|$_totalReturn';
    if (_historyKey != key) {
      _historyKey = key;
      _history = Future.wait([
        _totalReturn
            ? provider.portfolioTotalReturn(portfolio.id, _range)
            : provider.portfolioHistory(portfolio.id, _range),
        provider.benchmarkHistory(_range),
      ]);
    }
    return FutureBuilder(
      key: ValueKey(key),
      future: _history,
      builder: (context, snap) {
        if (snap.hasError) {
          return SizedBox(height: 170, child: Center(child: TextButton.icon(
            icon: const Icon(Icons.refresh), label: const Text('Retry chart'),
            onPressed: () => setState(() => _historyKey = null),
          )));
        }
        if (!snap.hasData && snap.connectionState != ConnectionState.done) {
          return const ShimmerSkeleton.chart(height: 170);
        }
        final results = snap.data as List? ?? const [];
        final points = results.isNotEmpty ? (results[0] as List<ChartPoint>) : const <ChartPoint>[];
        final benchmark = results.length > 1 ? results[1] as List<ChartPoint>? : null;
        return PortfolioChart(
          points: points,
          benchmark: _compare ? benchmark : null,
          height: 170,
          currency: currency,
          valueFormatter: (v) => fmtMoney(v, currency: currency),
        );
      },
    );
  }

  /// A list at least this long carries its native ad after the
  /// [_inFeedAdAfter]th holding instead of at the end. Few people scroll to
  /// the bottom of a long list, so an ad there is rarely seen.
  static const _inFeedAdMinHoldings = 8;
  static const _inFeedAdAfter = 5;

  /// The holdings title with its controls: group, sort and (for a list
  /// long enough to need it) search.
  Widget _holdingsHeader(BuildContext context, int count) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Text('Holdings', style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              _CountBadge(count: count),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _groupByMarket ? 'Stop grouping by market' : 'Group by market',
                isSelected: _groupByMarket,
                icon: const Icon(Icons.account_balance_outlined, size: 20),
                color: scheme.onSurfaceVariant,
                selectedIcon:
                    Icon(Icons.account_balance, size: 20, color: scheme.primary),
                onPressed: () => setState(() => _groupByMarket = !_groupByMarket),
              ),
              PopupMenuButton<String>(
                tooltip: 'Sort holdings',
                initialValue: _sort,
                icon: Icon(Icons.swap_vert_rounded, size: 22, color: scheme.onSurfaceVariant),
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'symbol', child: Text('Symbol A–Z')),
                  PopupMenuItem(value: 'value', child: Text('Largest first')),
                  PopupMenuItem(value: 'day', child: Text('Biggest movers today')),
                ],
              ),
            ],
          ),
          if (count > 5) ...[
            const SizedBox(height: 4),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Find a holding',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
              textInputAction: TextInputAction.search,
            ),
          ],
        ],
      ),
    );
  }

  /// Renders the holdings as cards of rows, one card per market when
  /// grouping is on.
  List<Widget> _groupedHoldings(
    BuildContext context,
    PortfolioProvider provider,
    String portfolioId,
    List<Holding> holdings,
  ) {
    final inFeedAd = holdings.length >= _inFeedAdMinHoldings;
    final out = <Widget>[];
    var rows = <Widget>[];
    var tiles = 0;

    // The ad goes in after the card that holds the fifth holding: between
    // two cards, never inside one.
    var adDue = false;

    void flush() {
      if (rows.isEmpty) return;
      out.add(_RowsCard(rows: rows));
      rows = [];
      if (adDue) {
        adDue = false;
        out.add(const AdSlot(placement: AdPlacement.holdingsNative, native: true));
      }
    }

    void add(Holding h) {
      rows.add(_holdingRow(context, provider, portfolioId, h));
      tiles++;
      if (inFeedAd && tiles == _inFeedAdAfter) {
        adDue = true;
        // An ungrouped list is one long card, so it is split for the ad.
        if (!_groupByMarket) flush();
      }
    }

    if (!_groupByMarket) {
      holdings.forEach(add);
      flush();
      return out;
    }

    // Bucket the holdings by the exchange their quote reports. Symbols
    // without a quote yet are placed under "Other" so nothing is hidden.
    final buckets = <String, List<Holding>>{};
    for (final h in holdings) {
      final q = provider.quoteOf(h.symbol);
      final market = marketFor(
        symbol: h.symbol,
        exchangeCode: q?.exchange,
        exchangeName: q?.fullExchangeName,
        quoteType: q?.quoteType,
      ) ?? 'Other';
      buckets.putIfAbsent(market, () => []).add(h);
    }

    final markets = buckets.keys.toList()
      ..sort((a, b) => compareMarkets(a, b));

    for (final market in markets) {
      final group = buckets[market]!;
      flush();
      out.add(_marketHeader(context, market, group.length));
      group.forEach(add);
    }
    flush();
    return out;
  }

  Widget _marketHeader(BuildContext context, String market, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Row(
        children: [
          Text(
            market.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '· $count',
            style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  Widget _holdingRow(
      BuildContext context, PortfolioProvider provider, String portfolioId, Holding h) {
    final theme = Theme.of(context);
    final q = provider.quoteOf(h.symbol);
    final price = q?.price ?? 0;
    final value = price * h.quantity;
    final pnl = value - h.costBasis;
    final dayPct = q?.dayChangePercent;
    final currency = q?.currency ?? h.currency;
    final colors = AppColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.hintColor);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => pushSharedAxis(
          context,
          HoldingDetailScreen(portfolioId: portfolioId, symbol: h.symbol),
        ),
        onLongPress: () =>
            showAddEditHoldingSheet(context, provider, portfolioId, editSymbol: h.symbol),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          child: Row(
            children: [
              Hero(
                tag: 'avatar_${portfolioId}_${h.symbol}',
                child: SymbolAvatar(symbol: h.symbol, companyName: q?.name),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      h.name.isEmpty
                          ? fmtQty(h.quantity)
                          : '${fmtQty(h.quantity)} · ${h.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                  ],
                ),
              ),
              if (width >= 360)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  // Its own layer: a row repainting (a price ticking) does
                  // not redraw the line.
                  child: RepaintBoundary(
                    child: _HoldingSparkline(
                      symbol: h.symbol,
                      provider: provider,
                      color: dayPct == null
                          ? theme.hintColor
                          : (dayPct >= 0 ? colors.gain : colors.loss),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmtMoney(value, currency: currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The total gain needs room; a small phone shows the
                      // day's change alone.
                      if (h.avgCost > 0 && width >= 400) ...[
                        Text(
                          fmtSignedMoney(pnl, currency: currency),
                          style: muted?.copyWith(
                            color: pnlColor(pnl, context),
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (dayPct != null)
                        ChangeChip(percent: dayPct, label: fmtPct(dayPct))
                      else
                        Text('No quote', style: muted),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The next few dividends and earnings dates, as rows in one card.
  Widget _eventsCard(BuildContext context, List<UpcomingEvent> events, AppColors colors) {
    final portfolioId = context.read<PortfolioProvider>().active.id;
    return _RowsCard(
      indent: 68,
      rows: [
        for (final e in events) _eventRow(context, e, colors, portfolioId),
      ],
    );
  }

  Widget _eventRow(
      BuildContext context, UpcomingEvent e, AppColors colors, String portfolioId) {
    final theme = Theme.of(context);
    final isDiv = e.kind == 'dividend';
    final color = isDiv ? colors.dividend : colors.earnings;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => pushSharedAxis(
          context,
          HoldingDetailScreen(portfolioId: portfolioId, symbol: e.symbol),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Sp.radiusSmall),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${e.date.day}',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w800, fontSize: 16, height: 1.1)),
                    Text(isDiv ? 'DIV' : 'EPS',
                        style: TextStyle(
                            color: color, fontSize: 9, fontWeight: FontWeight.w700, height: 1.2)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.symbol,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    Text(
                      isDiv
                          ? '${e.isPayDate ? 'Pays' : 'Ex-dividend'} ${fmtDate(e.date)}${e.estimated ? ' (est.)' : ''}'
                          : 'Earnings ${fmtDate(e.date)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              if (isDiv && e.total != null && e.total! > 0)
                Text(
                  fmtSignedMoney(e.total, currency: null),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.wallet_outlined,
      title: 'No holdings yet',
      subtitle: 'Add a symbol one-by-one, or import a full portfolio from a CSV file in seconds.'
        ' This sample portfolio is replaced as soon as you add or import your own.',
      action: FilledButton.tonalIcon(
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Import CSV / paste'),
        onPressed: () => pushSharedAxis(context, const ImportScreen()),
      ),
    );
  }
}

/// A small inline trend line for a holding, loaded from real price history.
class _HoldingSparkline extends StatefulWidget {
  final String symbol;
  final PortfolioProvider provider;
  final Color color;

  const _HoldingSparkline({
    required this.symbol,
    required this.provider,
    required this.color,
  });

  @override
  State<_HoldingSparkline> createState() => _HoldingSparklineState();
}

class _HoldingSparklineState extends State<_HoldingSparkline> {
  List<double>? _points;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_HoldingSparkline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) _load();
  }

  Future<void> _load() async {
    final points = await widget.provider.symbolSparkline(widget.symbol);
    if (!mounted) return;
    if (points.length < 2) return;
    setState(() => _points = points);
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    if (points == null) return const SizedBox.shrink();
    return MiniSparkline(points: points, color: widget.color);
  }
}

/// The day's change on the balance card: a solid, glowing pill in the
/// colour of the day.
class _MoodPill extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _MoodPill({required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 14),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 12, color: Colors.black.withValues(alpha: .8)),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small rounded label used for contextual details next to a headline.
class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _Pill({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: theme.hintColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft diagonal band of light that glides across the balance card every
/// few seconds, like light catching glass. Still when motion is reduced.
class _Sheen extends StatefulWidget {
  const _Sheen();

  @override
  State<_Sheen> createState() => _SheenState();
}

class _SheenState extends State<_Sheen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Starts a sweep every few seconds. The controller only ticks while the
  /// band is moving, so the card costs nothing in between.
  Timer? _every;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _every?.cancel();
      _every = null;
      _c.value = 0;
    } else {
      _every ??= Timer.periodic(const Duration(seconds: 7), (_) => _c.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _every?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        if (t <= 0 || t >= 1) return const SizedBox.expand();
        final x = -1.6 + 3.2 * Curves.easeInOut.transform(t);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(x - .5, -1),
              end: Alignment(x + .5, 1),
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: isDark ? .07 : .35),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Rows in one card, separated by hairlines.
class _RowsCard extends StatelessWidget {
  final List<Widget> rows;

  /// Where the hairlines start, so they line up with the row text.
  final double indent;

  const _RowsCard({required this.rows, this.indent = 62});

  @override
  Widget build(BuildContext context) {
    return SpCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: indent),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// A small count next to a section title.
class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor),
      ),
    );
  }
}

/// A compact on/off pill for a chart option.
class _Toggle extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.label, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!selected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: .14) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? scheme.primary.withValues(alpha: .45) : scheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
