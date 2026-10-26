import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/holding.dart';
import '../models/portfolio.dart';
import '../models/quote.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/allocation_donut.dart';
import '../widgets/portfolio_banner.dart';
import '../widgets/portfolio_chart.dart';
import '../widgets/symbol_avatar.dart';
import '../widgets/stat_cards.dart';
import '../widgets/ui/animated_number.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/page_transitions.dart';
import '../widgets/ui/pulse_indicator.dart';
import '../widgets/ui/section_header.dart';
import '../widgets/ui/shimmer_skeleton.dart';
import '../widgets/ui/sp_card.dart';
import '../widgets/ui/text_prompt.dart';
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
            Text('Your money in motion', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/icon/app_icon_foreground.png', width: 34, height: 34),
              const SizedBox(width: 10),
              _portfolioSelector(context, provider),
            ]),
          ],
        ),
        actions: [
          _refreshButton(context, provider),
          _moreMenu(context, provider, portfolio),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addHolding',
        icon: const Icon(Icons.add),
        label: const Text('Add holding'),
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
            _totalsCard(context, totals, currency, colors),
            const SizedBox(height: 12),
            SpCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('Performance', style: Theme.of(context).textTheme.titleLarge),
                  FilterChip(label: const Text('Compare SPY'), selected: _compare,
                    onSelected: (v) => setState(() => _compare = v)),
                ]),
                const SizedBox(height: 16),
                _chart(context, portfolio, provider),
                const SizedBox(height: 12),
                _rangeChips(context),
                Text('Based on current holdings · drag chart to explore',
                  style: Theme.of(context).textTheme.labelSmall),
              ],
            )),
            const SizedBox(height: 12),
            _allocationCard(context, provider, portfolio, totals.displayCurrency ?? currency),
            const PortfolioBanner(),
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
                )),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Sort holdings',
                  icon: const Icon(Icons.sort),
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'symbol', child: Text('Symbol A–Z')),
                    PopupMenuItem(value: 'day', child: Text('Daily change: highest first')),
                  ],
                ),
              ]),
              const SizedBox(height: 12),
              if (holdings.isEmpty) const Padding(
                padding: EdgeInsets.all(24), child: Center(child: Text('No matching holdings'))),
              ...holdings.map((h) => _holdingTile(context, provider, portfolio.id, h)),
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
                ],
                selected: {_allocBy},
                onSelectionChanged: (s) => setState(() => _allocBy = s.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AllocationDonut(slices: slices, currency: currency),
        ],
      ),
    );
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
        ],
      ),
    );
  }

  Widget _totalsCard(BuildContext context, PortfolioTotals t, String? currency, AppColors colors) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return SpCard(
      padding: const EdgeInsets.all(18),
      gradient: isDark
          ? [const Color(0xFF12333A), const Color(0xFF0C2027)]
          : [const Color(0xFFDCF8F1), const Color(0xFFFFFFFF)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Portfolio value',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
              ),
              const Spacer(),
              if (t.hasDayChange) const PulseIndicator(size: 6),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AnimatedNumber(
                value: t.marketValue,
                formatter: (v) => fmtMoney(v, currency: currency),
                style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              ChangeChip(
                percent: t.hasDayChange ? t.dayChangePercent : null,
                label: t.hasDayChange
                    ? '${fmtSignedMoney(t.dayChange, currency: currency)} (${fmtPct(t.dayChangePercent)}) today'
                    : '–',
              ),
            ],
          ),
          if (t.converted && t.displayCurrency != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'FX-converted to ${t.displayCurrency}',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _inlineStat('Total P/L', fmtSignedMoney(t.pnl, currency: currency),
                  '(${fmtPct(t.pnlPercent)})', pnlColor(t.pnl, context)),
              _inlineStat('Annual dividends', fmtMoney(t.annualIncome, currency: currency),
                  null, colors.dividend),
              _inlineStat('Yield', fmtPct(t.incomeYield, signed: false), 'on value', null),
              _inlineStat('Yield on cost', fmtPct(t.yieldOnCost, signed: false), 'on cost', null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inlineStat(String label, String value, String? sub, Color? color) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?
            .copyWith(color: theme.hintColor, letterSpacing: 0.7)),
        const SizedBox(height: 2),
        Text(
          sub == null ? value : '$value  $sub',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _rangeChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        children: [
          for (final e in _rangeLabels.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: _range == e.key,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _range = e.key),
            ),
        ],
      ),
    );
  }

  Widget _chart(BuildContext context, Portfolio portfolio, PortfolioProvider provider) {
    final key = '${portfolio.id}|$_range|${portfolio.holdings.values.map((h) => '${h.symbol}:${h.quantity}').join(',')}|${provider.lastRefreshAt}';
    if (_historyKey != key) {
      _historyKey = key;
      _history = Future.wait([
        provider.portfolioHistory(portfolio.id, _range),
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
          title: _compare ? 'Relative growth' : 'Value history',
        );
      },
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

    return GestureDetector(
      onLongPress: () => showAddEditHoldingSheet(context, provider, portfolioId, editSymbol: h.symbol),
      child: SpCard(
        margin: const EdgeInsets.only(bottom: 8),
        onTap: () => pushSharedAxis(
          context,
          HoldingDetailScreen(portfolioId: portfolioId, symbol: h.symbol),
        ),
        child: Row(
        children: [
          Hero(
            tag: 'avatar_${portfolioId}_${h.symbol}',
            child: SymbolAvatar(symbol: h.symbol),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtMoney(value, currency: currency),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
      subtitle: 'Add a symbol one-by-one, or import a full portfolio from a CSV file in seconds.',
      action: FilledButton.tonalIcon(
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Import CSV / paste'),
        onPressed: () => pushSharedAxis(context, const ImportScreen()),
      ),
    );
  }
}
