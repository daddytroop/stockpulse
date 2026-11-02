import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/holding.dart';
import '../models/portfolio.dart';
import '../models/quote.dart';
import '../providers/portfolio_provider.dart';
import '../services/ad_service.dart';
import '../services/app_navigation.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/market_identity.dart';
import '../widgets/allocation_donut.dart';
import '../widgets/ad_slot.dart';
import '../widgets/portfolio_chart.dart';
import '../widgets/pulse_logo.dart';
import '../widgets/symbol_avatar.dart';
import '../widgets/ui/animated_number.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/kpi_tile.dart';
import '../widgets/ui/page_transitions.dart';
import '../widgets/ui/pulse_indicator.dart';
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final portfolio = provider.active;
    final totals = provider.totalsFor(portfolio);
    final currency = totals.displayCurrency ??
        (portfolio.holdings.isEmpty ? null : portfolio.holdings.values.first.currency);
    final events = provider.upcomingEventsFor([portfolio], horizonDays: 90).take(5).toList();
    final colors = AppColors.of(context);
    final holdings = portfolio.holdings.values.where((h) =>
        '${h.symbol} ${h.name}'.toLowerCase().contains(_query.toLowerCase())).toList();
    holdings.sort((a, b) {
      if (_sort == 'day') {
        return (provider.quoteOf(b.symbol)?.dayChangePercent ?? double.negativeInfinity)
            .compareTo(provider.quoteOf(a.symbol)?.dayChangePercent ?? double.negativeInfinity);
      }
      return a.symbol.compareTo(b.symbol);
    });

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 96,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const PulseLogo(size: 30),
              const SizedBox(width: 10),
              Flexible(child: _portfolioSelector(context, provider)),
            ]),          ],
        ),
        actions: [
          const ThemeToggleButton(),
          _refreshButton(context, provider),
          _moreMenu(context, provider, portfolio),
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
        onRefresh: () async {
          await provider.refreshQuotes();
          await provider.ensureDividendInfo();
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
          key: const PageStorageKey('portfolio-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            if (provider.lastError != null)
              _errorBanner(context, provider.lastError!)
            else if (provider.quotesLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            _freshnessBanner(context, provider),
            _totalsCard(context, totals, currency, colors, portfolio.name.startsWith('Sample')),
            const SizedBox(height: 12),
            _kpiRow(context, provider, portfolio, totals, currency),
            const SizedBox(height: 10),
            WhatsNewCard(
              provider: provider,
              portfolio: portfolio,
              currency: currency,
            ),
            const SizedBox(height: 4),
            _dataProvenance(context, provider),
            const SizedBox(height: 12),
            SpCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('Performance', style: Theme.of(context).textTheme.titleLarge),
                  FilterChip(label: const Text('Compare SPY'), selected: _compare,
                    onSelected: (v) => setState(() => _compare = v)),
                  FilterChip(
                    label: const Text('Total return'),
                    selected: _totalReturn,
                    onSelected: (v) => setState(() => _totalReturn = v),
                  ),
                ]),
                const SizedBox(height: 10),
                _chart(context, portfolio, provider, currency),
                const SizedBox(height: 10),
                _rangeChips(context),
                const SizedBox(height: 2),
                Text(
                  _totalReturn
                      ? 'Value plus every dividend received · drag the chart'
                      : 'Price only · drag the chart',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            )),
            const SizedBox(height: 12),
            _allocationCard(context, provider, portfolio, totals.displayCurrency ?? currency),
            const SizedBox(height: 12),
            if (events.isNotEmpty) ...[
              SectionHeader(title: 'Upcoming', subtitle: '${events.length} events in the next 90 days'),
              ...events.map((e) => _eventTile(context, e, colors)).toList().animate(
                interval: 40.ms,
                effects: [FadeEffect(duration: 300.ms), SlideEffect(begin: const Offset(0, 0.08), end: Offset.zero, duration: 300.ms)],
              ),
              const SizedBox(height: 12),
            ],
            if (portfolio.holdings.isEmpty)
              _emptyState(context)
            else ...[
              SectionHeader(title: 'Holdings (${portfolio.holdings.length})'),
              Row(children: [
                Expanded(child: TextField(
                  decoration: const InputDecoration(hintText: 'Find a holding',
                    prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _query = v.trim()),
                  textInputAction: TextInputAction.search,
                )),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Sort'),
                  onPressed: () async {
                    final v = await showModalBottomSheet<String>(
                      context: context,
                      builder: (ctx) => SafeArea(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(padding: EdgeInsets.all(16), child: Text('Sort holdings', style: TextStyle(fontWeight: FontWeight.w800))),
                          ListTile(leading: Icon(Icons.sort_by_alpha), title: Text('Symbol A–Z'), subtitle: Text('Easy to scan'), onTap: () => Navigator.pop(ctx, 'symbol')),
                          ListTile(leading: Icon(Icons.trending_up), title: Text('Daily change'), subtitle: Text('Biggest movers first'), onTap: () => Navigator.pop(ctx, 'day')),
                        ],
                      )),
                    );
                    if (v != null) setState(() => _sort = v);
                  },
                ),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.account_balance_outlined, size: 16),
                    label: const Text('Group by market'),
                    selected: _groupByMarket,
                    onSelected: (v) => setState(() => _groupByMarket = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (holdings.isEmpty) const Padding(
                padding: EdgeInsets.all(24), child: Center(child: Text('No matching holdings'))),
              ..._groupedHoldings(context, provider, portfolio.id, holdings).animate(
                interval: 45.ms,
                effects: [
                  FadeEffect(duration: 320.ms),
                  SlideEffect(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                    duration: 320.ms,
                    curve: Curves.easeOut,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // A native ad after the holdings (inside a long list, see
              // _groupedHoldings), and a banner at the very end of the
              // screen. Both sit below the content the user came for.
              if (holdings.length < _inFeedAdMinHoldings)
                const AdSlot(
                  placement: AdPlacement.holdingsNative,
                  native: true,
                ),
              const AdSlot(placement: AdPlacement.portfolioBanner),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Prices from Yahoo Finance (unofficial). Values are estimates,\nnot investment advice.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
                ),
              ),
            ],
          ],
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
              ? '${fmtPct(totals.totalReturnPercent)} · incl. '
                  '${fmtMoney(totals.dividendsReceived, currency: currency)} dividends'
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

  Widget _totalsCard(BuildContext context, PortfolioTotals t, String? currency, AppColors colors, bool sampleMode) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final up = t.dayChange >= 0;
    final mood = t.hasDayChange ? (up ? colors.gain : colors.loss) : scheme.primary;

    return SpCard(
      padding: EdgeInsets.zero,
      glow: mood,
      borderRadius: 26,
      gradient: isDark
          ? [
              Color.alphaBlend(mood.withValues(alpha: .10), scheme.surface),
              scheme.surface,
              Color.alphaBlend(scheme.tertiary.withValues(alpha: .08), scheme.surface),
            ]
          : [
              Color.alphaBlend(mood.withValues(alpha: .10), Colors.white),
              Colors.white,
            ],
      child: Stack(
        children: [
          // A soft orb of the day's colour in the corner.
          Positioned(
            right: -60,
            top: -70,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    mood.withValues(alpha: isDark ? .28 : .18),
                    mood.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
          ),
          // The signature gradient along the top edge.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  scheme.primary,
                  scheme.secondary,
                  scheme.tertiary,
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TOTAL BALANCE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (sampleMode) ...[
                const SizedBox(width: 8),
                Chip(label: const Text('Sample'), visualDensity: VisualDensity.compact),
              ],
              const Spacer(),
              if (t.hasDayChange) ...[
                PulseIndicator(size: 6, color: mood),
                const SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: mood,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedNumber(
              value: t.marketValue,
              formatter: (v) => fmtMoney(v, currency: currency),
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1.6,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
                _Pill(
                  label: 'in ${t.displayCurrency}',
                  icon: Icons.currency_exchange,
                ),
              if (t.hasDayChange)
                _Pill(
                  label: 'Cost ${fmtMoney(t.costBasis, currency: currency)}',
                  icon: Icons.savings_outlined,
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

  /// The chart range picker: one segmented bar, the selected range lit up.
  Widget _rangeChips(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final e in _rangeLabels.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: _range == e.key,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _range = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _range == e.key
                          ? scheme.primary.withValues(alpha: .16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _range == e.key
                            ? scheme.primary.withValues(alpha: .5)
                            : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _range == e.key
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
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
          return SizedBox(height: 180, child: Center(child: TextButton.icon(
            icon: const Icon(Icons.refresh), label: const Text('Retry chart'),
            onPressed: () => setState(() => _historyKey = null),
          )));
        }
        if (!snap.hasData && snap.connectionState != ConnectionState.done) {
          return const ShimmerSkeleton.chart(height: 180);
        }
        final results = snap.data as List? ?? const [];
        final points = results.isNotEmpty ? (results[0] as List<ChartPoint>) : const <ChartPoint>[];
        final benchmark = results.length > 1 ? results[1] as List<ChartPoint>? : null;
        return PortfolioChart(
          points: points,
          benchmark: _compare ? benchmark : null,
          title: _totalReturn
              ? 'Total return'
              : (_compare ? 'Relative growth' : 'Value history'),
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

  /// Renders the holdings, grouped into market sections when enabled.
  List<Widget> _groupedHoldings(
    BuildContext context,
    PortfolioProvider provider,
    String portfolioId,
    List<Holding> holdings,
  ) {
    final inFeedAd = holdings.length >= _inFeedAdMinHoldings;
    var tiles = 0;
    List<Widget> tileWithAd(Holding h) {
      tiles++;
      return [
        _holdingTile(context, provider, portfolioId, h),
        if (inFeedAd && tiles == _inFeedAdAfter)
          const AdSlot(placement: AdPlacement.holdingsNative, native: true),
      ];
    }

    if (!_groupByMarket) {
      return [
        for (final h in holdings) ...tileWithAd(h),
      ];
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

    final widgets = <Widget>[];
    for (final market in markets) {
      final group = buckets[market]!;
      widgets.add(_marketHeader(context, market, group.length));
      for (final h in group) {
        widgets.addAll(tileWithAd(h));
      }
    }
    return widgets;
  }

  Widget _marketHeader(BuildContext context, String market, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Icon(Icons.account_balance_outlined,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            market,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count == 1 ? '1 holding' : '$count holdings',
              style: theme.textTheme.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _holdingTile(
      BuildContext context, PortfolioProvider provider, String portfolioId, Holding h) {
    final q = provider.quoteOf(h.symbol);
    final price = q?.price ?? 0;
    final value = price * h.quantity;
    final pnl = value - h.costBasis;
    final dayPct = q?.dayChangePercent;
    final currency = q?.currency ?? h.currency;
    final colors = AppColors.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;

    return GestureDetector(
      onLongPress: () => showAddEditHoldingSheet(context, provider, portfolioId, editSymbol: h.symbol),
      child: SpCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        onTap: () => pushSharedAxis(
          context,
          HoldingDetailScreen(portfolioId: portfolioId, symbol: h.symbol),
        ),
        child: Row(
        children: [
          Hero(
            tag: 'avatar_${portfolioId}_${h.symbol}',
            child: SymbolAvatar(
              symbol: h.symbol,
              companyName: q?.name,
            ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
                if (h.name.isNotEmpty)
                  Text(
                    h.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                  ),
                Text(
                  '${fmtQty(h.quantity)} ${h.avgCost > 0 ? '× ${fmtMoney(h.avgCost, currency: currency)}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          if (!narrow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _HoldingSparkline(
                symbol: h.symbol,
                provider: provider,
                color: dayPct == null
                    ? Theme.of(context).hintColor
                    : (dayPct >= 0 ? colors.gain : colors.loss),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtMoney(value, currency: currency),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    q == null ? ' ' : '${fmtMoney(q.price, currency: currency)} ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                  ),
                  if (dayPct != null) ChangeChip(percent: dayPct, label: fmtPct(dayPct)),
                ],
              ),
              Text(
                h.avgCost > 0 ? '${fmtSignedMoney(pnl, currency: currency)} P/L' : ' ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: h.avgCost > 0 ? pnlColor(pnl, context) : null,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _eventTile(BuildContext context, UpcomingEvent e, AppColors colors) {
    final theme = Theme.of(context);
    final isDiv = e.kind == 'dividend';
    final color = isDiv ? colors.dividend : colors.earnings;
    return SpCard(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onTap: () => pushSharedAxis(context, HoldingDetailScreen(
        portfolioId: context.read<PortfolioProvider>().active.id,
        symbol: e.symbol,
      )),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${e.date.day}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
            Text(isDiv ? 'DIV' : 'EPS', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ]),
        ),
        title: Text(e.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          isDiv
              ? '${e.isPayDate ? 'Pays' : 'Ex-dividend'} ${fmtDate(e.date)}${e.estimated ? ' (est.)' : ''}'
              : 'Earnings ${fmtDate(e.date)}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: isDiv && e.total != null && e.total! > 0
            ? Text(
                fmtSignedMoney(e.total, currency: null),
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              )
            : null,
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
