import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/dividends.dart';
import '../models/holding.dart';
import '../models/portfolio.dart';
import '../models/quote.dart';
import '../providers/portfolio_provider.dart';
import '../utils/formatters.dart';
import '../widgets/portfolio_chart.dart';
import '../widgets/stat_cards.dart';
import '../widgets/symbol_avatar.dart';
import 'add_edit_holding_sheet.dart';
import 'sell_holding_dialog.dart';

class HoldingDetailScreen extends StatefulWidget {
  final String portfolioId;
  final String symbol;
  const HoldingDetailScreen({
    super.key,
    required this.portfolioId,
    required this.symbol,
  });

  @override
  State<HoldingDetailScreen> createState() => _HoldingDetailScreenState();
}

class _HoldingDetailScreenState extends State<HoldingDetailScreen> {
  String _range = '1y';

  static const _rangeLabels = {
    '1mo': '1M', '3mo': '3M', '6mo': '6M', '1y': '1Y', '2y': '2Y', '5y': '5Y',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PortfolioProvider>().ensureDividendInfo(symbolsIn: {widget.symbol});
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final portfolio = provider.byId(widget.portfolioId);
    final Holding? holding = portfolio?.holdings[widget.symbol.toUpperCase()];
    final Quote? quote = provider.quoteOf(widget.symbol);
    final info = provider.dividendInfoOf(widget.symbol);
    final currency = quote?.currency ?? holding?.currency ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.symbol),
        actions: [
          IconButton(
            tooltip: 'Sell / reduce position',
            icon: const Icon(Icons.sell_outlined),
            onPressed: holding == null
                ? null
                : () => showSellDialog(context, provider, widget.portfolioId, holding),
          ),
          IconButton(
            tooltip: 'Edit holding',
            icon: const Icon(Icons.edit_outlined),
            onPressed: holding == null
                ? null
                : () => showAddEditHoldingSheet(context, provider, widget.portfolioId,
                    editSymbol: widget.symbol),
          ),
          IconButton(
            tooltip: 'Remove holding',
            icon: const Icon(Icons.delete_outline),
            onPressed: holding == null ? null : () => _confirmRemove(provider, holding),
          ),
        ],
      ),
      body: holding == null
          ? const Center(child: Text('Holding removed.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              children: [
                if (provider.splitSuggestionFor(holding) != null) ...[
                  _splitBanner(
                      context, provider, provider.splitSuggestionFor(holding)!, holding),
                  const SizedBox(height: 12),
                ],
                _header(context, holding, quote, currency),
                const SizedBox(height: 12),
                _rangeChips(context),
                FutureBuilder(
                  key: ValueKey('${widget.symbol}|$_range|'
                      '${provider.lastRefreshAt?.millisecondsSinceEpoch ?? 0}'),
                  future: _history(provider, quote),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done && !snap.hasData) {
                      return const SizedBox(
                          height: 180, child: Center(child: CircularProgressIndicator()));
                    }
                    return PortfolioChart(points: snap.data ?? const []);
                  },
                ),
                const SizedBox(height: 12),
                _statsGrid(context, provider, holding, quote, info, currency),
                const SizedBox(height: 12),
                if ((portfolio?.txnsFor(holding.symbol) ?? const []).isNotEmpty)
                  _transactionsSection(context, provider, portfolio!, holding, currency),
                if (info != null && info.payments.isNotEmpty) ...[
                  Text('Dividend history',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    'Received so far: '
                    '${fmtMoney(provider.dividendsReceivedFor(portfolio!, holding), currency: currency)}'
                    '${(provider.realizedPnlFor(portfolio, holding.symbol) != null)
                        ? ' · realized P/L: ${fmtSignedMoney(provider.realizedPnlFor(portfolio, holding.symbol)!, currency: currency)}'
                        : ''}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  ...[
                    for (final p in info.payments.reversed.take(24))
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.payments_outlined,
                            color: Color(0xFF2E7D32)),
                        title: Text(fmtDate(p.exDate)),
                        subtitle: Text(p.exDate.isAfter(
                                DateTime.now().subtract(const Duration(days: 366)))
                            ? 'Paid ${fmtMoney(p.amount * holding.quantity, currency: currency)} total (for ${fmtQty(holding.quantity)} units)'
                            : 'Per share ${fmtMoney(p.amount, currency: currency)}'),
                        trailing: Text(
                          fmtMoney(p.amount, currency: currency),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                ],
                _newsSection(context, provider),
              ],
            ),
    );
  }

  Widget _splitBanner(
      BuildContext context, PortfolioProvider provider, Split split, Holding holding) {
    final theme = Theme.of(context);
    final newQty = holding.quantity * split.multiplier;
    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.swap_horiz, color: theme.colorScheme.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${split.numerator}:${split.denominator} split on ${fmtDate(split.date)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onTertiaryContainer),
                  ),
                  Text(
                    'Adjust ${fmtQty(holding.quantity)} units to ${fmtQty(newQty)} '
                    '(avg cost ${holding.avgCost > 0 ? fmtMoney(holding.avgCost / split.multiplier, currency: holding.currency) : '-'})?',
                    style: TextStyle(
                        fontSize: 12, color: theme.colorScheme.onTertiaryContainer),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => provider.applySplit(
                  portfolioId: widget.portfolioId, symbol: holding.symbol),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionsSection(BuildContext context, PortfolioProvider provider,
      Portfolio portfolio, Holding holding, String currency) {
    final theme = Theme.of(context);
    final txns = portfolio.txnsFor(holding.symbol).reversed.take(12).toList(growable: false);
    final realized = provider.realizedPnlFor(portfolio, holding.symbol);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Transactions',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (realized != null) ...[
              Text('Realized: ', style: Theme.of(context).textTheme.labelSmall),
              Text(
                fmtSignedMoney(realized, currency: currency),
                style: TextStyle(
                    color: pnlColor(realized), fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ...[
          for (final t in txns)
            ListTile(
              dense: true,
              leading: Icon(
                t.isBuy ? Icons.add_shopping_cart_outlined : Icons.sell_outlined,
                color: t.isBuy ? const Color(0xFF1565C0) : const Color(0xFFC62828),
              ),
              title: Text(
                '${t.isBuy ? 'Buy' : 'Sell'} ${fmtQty(t.quantity)} @ ${fmtMoney(t.unitPrice, currency: currency)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${fmtDate(t.date)}${t.fee > 0 ? ' · fee ${fmtMoney(t.fee, currency: currency)}' : ''}'
                '${t.note.isNotEmpty ? ' · ${t.note}' : ''}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Text(
                fmtMoney(t.quantity * t.unitPrice + (t.isBuy ? t.fee : -t.fee),
                    currency: currency),
              ),
            ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }

  Future<List<ChartPoint>> _history(PortfolioProvider provider, Quote? quote) {
    return provider.symbolHistory(widget.symbol, _range);
  }

  Widget _header(BuildContext context, Holding holding, Quote? quote, String currency) {
    final theme = Theme.of(context);
    final value = (quote?.price ?? 0) * holding.quantity;
    final pnl = value - holding.costBasis;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SymbolAvatar(symbol: holding.symbol, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holding.name.isEmpty ? holding.symbol : holding.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${fmtQty(holding.quantity)} units'
                    '${holding.avgCost > 0 ? ' @ ${fmtMoney(holding.avgCost, currency: currency)}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                  Text(
                    'Value ${fmtMoney(value, currency: currency)}'
                    '${holding.avgCost > 0 ? ' · P/L ${fmtSignedMoney(pnl, currency: currency)}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtMoney(quote?.price ?? 0, currency: currency),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                ChangeChip(
                  percent: quote?.dayChangePercent,
                  label: quote?.dayChangePercent == null
                      ? '–'
                      : '${fmtSignedMoney(quote!.dayChange, currency: currency)} (${fmtPct(quote.dayChangePercent)})',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeChips(BuildContext context) {
    return Wrap(
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
    );
  }

  Widget _statsGrid(
    BuildContext context,
    PortfolioProvider provider,
    Holding holding,
    Quote? quote,
    DividendInfo? info,
    String currency,
  ) {
    final ttm = info != null && info.ttmPerShare > 0 ? info.ttmPerShare : (quote?.dividendRate ?? 0.0);
    final annual = ttm * holding.quantity;
    final yoc = holding.costBasis > 0 ? annual / holding.costBasis * 100 : 0.0;
    final nextUp = provider.upcomingFor(holding.symbol, holding.quantity);

    return StatGrid(cards: [
      StatCard(
        label: 'Previous close',
        value: quote?.previousClose == null ? '–' : fmtMoney(quote!.previousClose, currency: currency),
      ),
      StatCard(
        label: '52-week range',
        value: quote?.fiftyTwoWeekHigh == null
            ? '–'
            : '${fmtMoney(quote!.fiftyTwoWeekLow, currency: currency)} – ${fmtMoney(quote.fiftyTwoWeekHigh, currency: currency)}',
      ),
      StatCard(
        label: 'Dividend (TTM/share)',
        value: ttm > 0 ? fmtMoney(ttm, currency: currency) : '–',
        sub: quote?.dividendYield == null ? null : '${fmtPct(quote!.dividendYield! * 100, signed: false)} yield',
      ),
      StatCard(
        label: 'Annual income',
        value: ttm > 0 ? fmtMoney(annual, currency: currency) : '–',
        sub: yoc > 0 ? '${fmtPct(yoc, signed: false)} on cost' : null,
        valueColor: ttm > 0 ? const Color(0xFF2E7D32) : null,
      ),
      StatCard(
        label: 'Next ex-dividend',
        value: nextUp == null ? '–' : '${fmtDate(nextUp.exDate)}${nextUp.estimated ? '*' : ''}',
        sub: nextUp == null
            ? null
            : '${fmtMoney(nextUp.amountPerShare, currency: currency)}/unit · est. ${fmtMoney(nextUp.total, currency: currency)}',
      ),
      StatCard(
        label: 'Expected payment',
        value: nextUp == null ? '–' : fmtDate(nextUp.payDate),
      ),
      StatCard(
        label: currency,
        value: quote?.exchange ?? '–',
        sub: quote?.quoteType,
      ),
      StatCard(
        label: 'Market state',
        value: quote?.marketState ?? '–',
      ),
    ]);
  }

  Future<void> _confirmRemove(PortfolioProvider provider, Holding holding) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove holding?'),
        content: Text('Remove ${holding.symbol} (${fmtQty(holding.quantity)} units) from this portfolio?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await provider.removeHolding(widget.portfolioId, holding.symbol);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _newsSection(BuildContext context, PortfolioProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text('Recent news',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        FutureBuilder(
          future: provider.newsFor(widget.symbol),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done && !snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final items = snap.data ?? const <NewsItem>[];
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No recent stories.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              );
            }
            return Column(
              children: [
                for (final n in items.take(8))
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        n.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${n.publisher} · ${timeAgo(n.publishedAt)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      trailing: const Icon(Icons.open_in_new, size: 16),
                      onTap: () => _open(n.link),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _open(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // ignore
    }
  }
}