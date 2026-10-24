import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/holding.dart';
import '../models/portfolio.dart';
import '../providers/portfolio_provider.dart';
import '../utils/formatters.dart';
import '../widgets/portfolio_chart.dart';
import '../widgets/symbol_avatar.dart';
import '../widgets/stat_cards.dart';
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

  static const _rangeLabels = {
    '1mo': '1M', '3mo': '3M', '6mo': '6M', '1y': '1Y', '2y': '2Y', '5y': '5Y',
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final portfolio = provider.active;
    final totals = provider.totalsFor(portfolio);
    final currency =
        portfolio.holdings.isEmpty ? null : portfolio.holdings.values.first.currency;
    final events = provider.upcomingEventsFor([portfolio], horizonDays: 90).take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: _portfolioSelector(context, provider),
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
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          children: [
            if (provider.lastError != null)
              _errorBanner(context, provider.lastError!)
            else if (provider.quotesLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            _totalsCard(context, totals, currency),
            const SizedBox(height: 12),
            _rangeChips(context),
            FutureBuilder(
              key: ValueKey('${portfolio.id}|$_range|${portfolio.symbols.length}'
                  '|${provider.lastRefreshAt?.millisecondsSinceEpoch ?? 0}'),
              future: provider.portfolioHistory(portfolio.id, _range),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done && !snap.hasData) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return PortfolioChart(points: snap.data ?? const [], title: 'Portfolio value');
              },
            ),
            const SizedBox(height: 12),
            if (events.isNotEmpty) ...[
              _sectionTitle(context, 'Upcoming'),
              ...[for (final e in events) _eventTile(context, e)],
              const SizedBox(height: 12),
            ],
            if (portfolio.holdings.isEmpty)
              _emptyState(context, provider)
            else ...[
              _sectionTitle(context, 'Holdings (${portfolio.holdings.length})'),
              ...[
                for (final h in portfolio.holdings.values)
                  _holdingTile(context, provider, portfolio.id, h),
              ],
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Prices from Yahoo Finance (unofficial). Values are estimates,\nnot investment advice.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
              ),
            ],
          ],
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
            final name = await _askText(context, 'Rename portfolio', portfolio.name);
            if (name != null && name.trim().isNotEmpty) {
              provider.renamePortfolio(portfolio.id, name);
            }
          case 'add':
            final name = await _askText(context, 'New portfolio', '');
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
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              );
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
        const PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Row(children: [
            Icon(Icons.delete_outline, size: 20), SizedBox(width: 10), Text('Delete portfolio')])),
      ],
    );
  }

  Widget _errorBanner(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
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
      ),
    );
  }

  Widget _totalsCard(BuildContext context, PortfolioTotals t, String? currency) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtMoney(t.marketValue, currency: currency),
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 10),
                ChangeChip(
                  percent: t.hasDayChange ? t.dayChangePercent : null,
                  label: t.hasDayChange
                      ? '${fmtSignedMoney(t.dayChange, currency: currency)} (${fmtPct(t.dayChangePercent)})'
                      : '–',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _inlineStat('Total P/L', fmtSignedMoney(t.pnl, currency: currency),
                    '(${fmtPct(t.pnlPercent)})', pnlColor(t.pnl)),
                _inlineStat('Annual dividends', fmtMoney(t.annualIncome, currency: currency),
                    null, null),
                _inlineStat('Yield', fmtPct(t.incomeYield, signed: false), 'on value', null),
                _inlineStat('Yield on cost', fmtPct(t.yieldOnCost, signed: false), 'on cost', null),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inlineStat(String label, String value, String? sub, Color? color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          sub == null ? value : '$value  $sub',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
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

  Widget _holdingTile(
      BuildContext context, PortfolioProvider provider, String portfolioId, Holding h) {
    final q = provider.quoteOf(h.symbol);
    final price = q?.price ?? 0;
    final value = price * h.quantity;
    final pnl = value - h.costBasis;
    final dayPct = q?.dayChangePercent;
    final currency = q?.currency ?? h.currency;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HoldingDetailScreen(portfolioId: portfolioId, symbol: h.symbol),
          ));
        },
        onLongPress: () => showAddEditHoldingSheet(context, provider, portfolioId, editSymbol: h.symbol),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SymbolAvatar(symbol: h.symbol),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.symbol,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (h.name.isNotEmpty)
                      Text(
                        h.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).hintColor),
                      ),
                    Text(
                      '${fmtQty(h.quantity)} ${h.avgCost > 0 ? '× ${fmtMoney(h.avgCost, currency: currency)}' : ''}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).hintColor),
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
                        q == null
                            ? ' '
                            : '${fmtMoney(q.price, currency: currency)} ',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).hintColor),
                      ),
                      if (dayPct != null)
                        ChangeChip(percent: dayPct, label: fmtPct(dayPct)),
                    ],
                  ),
                  Text(
                    h.avgCost > 0 ? '${fmtSignedMoney(pnl, currency: currency)} P/L' : ' ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: h.avgCost > 0 ? pnlColor(pnl) : null,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventTile(BuildContext context, UpcomingEvent e) {
    final theme = Theme.of(context);
    final isDiv = e.kind == 'dividend';
    final color = isDiv ? const Color(0xFF2E7D32) : const Color(0xFFF57C00);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(isDiv ? Icons.payments_outlined : Icons.query_stats_outlined, color: color),
        title: Text(
          e.symbol,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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

  Widget _emptyState(BuildContext context, PortfolioProvider provider) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.wallet_outlined, size: 44, color: theme.hintColor),
            const SizedBox(height: 10),
            Text('No holdings yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Add a symbol one-by-one, or import a full portfolio from a CSV file in seconds.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Import CSV / paste'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ImportScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _askText(BuildContext context, String title, String initial) async {
  final ctl = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        autofocus: true,
        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Name'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(ctl.text), child: const Text('OK')),
      ],
    ),
  );
  return value;
}