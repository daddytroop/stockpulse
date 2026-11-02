import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quote.dart';
import '../models/watch_item.dart';
import '../providers/portfolio_provider.dart';
import '../services/pro_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/symbol_avatar.dart';
import '../widgets/ui/empty_state.dart';
import '../widgets/ui/sp_card.dart';
import 'pro_screen.dart';

/// Stocks the user follows without owning them.
///
/// Free: up to [PortfolioProvider.freeWatchlistLimit] symbols. Pro: any
/// number, plus price targets that send a notification.
class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final provider = context.read<PortfolioProvider>();
    final pro = context.read<ProService>();
    if (!pro.has(ProFeature.watchlist) &&
        provider.watchlist.length >= PortfolioProvider.freeWatchlistLimit) {
      await showProPaywall(context, feature: ProFeature.watchlist);
      if (!context.mounted || !context.read<ProService>().has(ProFeature.watchlist)) return;
    }
    final symbol = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SymbolSearchSheet(provider: provider),
    );
    if (symbol != null) await provider.addToWatchlist(symbol);
  }

  Future<void> _editTargets(BuildContext context, WatchItem item) async {
    if (!context.read<ProService>().has(ProFeature.watchlist)) {
      await showProPaywall(context, feature: ProFeature.watchlist);
      if (!context.mounted || !context.read<ProService>().has(ProFeature.watchlist)) return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TargetSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final pro = context.watch<ProService>();
    final items = provider.watchlist;
    final unlocked = pro.has(ProFeature.watchlist);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Watchlist')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addWatch',
        icon: const Icon(Icons.add),
        label: const Text('Follow a stock'),
        onPressed: () => _add(context),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.refreshQuotes(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              children: [
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.visibility_outlined,
                    title: 'Follow stocks you don\'t own yet',
                    subtitle: 'See their price and daily move next to your portfolio, '
                        'and set a target to be told when it is time to buy.',
                  )
                else ...[
                  if (!unlocked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${items.length} of ${PortfolioProvider.freeWatchlistLimit} free spots used · '
                        'Pro adds unlimited stocks and price-target alerts',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    ),
                  for (final item in items)
                    _WatchTile(
                      item: item,
                      quote: provider.quoteOf(item.symbol),
                      locked: !unlocked,
                      onTargets: () => _editTargets(context, item),
                      onRemove: () => provider.removeFromWatchlist(item.symbol),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WatchTile extends StatelessWidget {
  final WatchItem item;
  final Quote? quote;
  final bool locked;
  final VoidCallback onTargets;
  final VoidCallback onRemove;

  const _WatchTile({
    required this.item,
    required this.quote,
    required this.locked,
    required this.onTargets,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final q = quote;
    final pct = q?.dayChangePercent;
    final hit = q == null ? null : item.hitBy(q.price);

    String targetsText() {
      final parts = <String>[
        if (item.below != null) 'Buy below ${fmtMoney(item.below, currency: q?.currency)}',
        if (item.above != null) 'Alert above ${fmtMoney(item.above, currency: q?.currency)}',
      ];
      return parts.isEmpty ? 'Set a price target' : parts.join(' · ');
    }

    return Dismissible(
      key: ValueKey('watch-${item.symbol}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: colors.lossContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.delete_outline, color: colors.loss),
      ),
      child: SpCard(
        margin: const EdgeInsets.only(bottom: 8),
        glow: hit != null ? colors.gain : null,
        onTap: onTargets,
        child: Row(
          children: [
            SymbolAvatar(symbol: item.symbol, companyName: q?.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.symbol,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  if ((q?.name ?? '').isNotEmpty)
                    Text(q!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        hit != null
                            ? Icons.notifications_active_rounded
                            : (item.hasTargets ? Icons.notifications_none_rounded : Icons.add_alert_outlined),
                        size: 14,
                        color: hit != null ? colors.gain : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          hit == null ? targetsText() : 'Target reached',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: hit != null ? colors.gain : theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        const ProBadge(locked: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  q == null ? '…' : fmtMoney(q.price, currency: q.currency),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                if (pct != null) ChangeChip(percent: pct, label: fmtPct(pct)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Finds a symbol to follow.
class _SymbolSearchSheet extends StatefulWidget {
  final PortfolioProvider provider;

  const _SymbolSearchSheet({required this.provider});

  @override
  State<_SymbolSearchSheet> createState() => _SymbolSearchSheetState();
}

class _SymbolSearchSheetState extends State<_SymbolSearchSheet> {
  Timer? _debounce;
  List<SearchResult> _results = const [];
  bool _searching = false;
  String _query = '';

  void _onChanged(String value) {
    _query = value.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (_query.isEmpty) {
        setState(() => _results = const []);
        return;
      }
      setState(() => _searching = true);
      final q = _query;
      try {
        final results = await widget.provider.searchSymbols(q);
        if (!mounted || q != _query) return;
        setState(() => _results = results);
      } catch (_) {
        // Keep the previous results.
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Search a company or ticker',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
                onChanged: _onChanged,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Navigator.pop(context, v.trim().toUpperCase());
                },
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final r in _results)
                    ListTile(
                      leading: SymbolAvatar(symbol: r.symbol, companyName: r.name),
                      title: Text(r.symbol, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        [r.name, if (r.exchange != null) r.exchange!].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: widget.provider.isWatched(r.symbol)
                          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                          : const Icon(Icons.add_rounded),
                      onTap: () => Navigator.pop(context, r.symbol),
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

/// Sets the buy-below and alert-above prices for a watched stock.
class _TargetSheet extends StatefulWidget {
  final WatchItem item;

  const _TargetSheet({required this.item});

  @override
  State<_TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends State<_TargetSheet> {
  late final TextEditingController _below =
      TextEditingController(text: widget.item.below?.toString() ?? '');
  late final TextEditingController _above =
      TextEditingController(text: widget.item.above?.toString() ?? '');

  double? _parse(String s) {
    final v = double.tryParse(s.trim().replaceAll(',', '.'));
    return v == null || v <= 0 ? null : v;
  }

  @override
  void dispose() {
    _below.dispose();
    _above.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PortfolioProvider>();
    final q = provider.quoteOf(widget.item.symbol);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Price targets for ${widget.item.symbol}', style: theme.textTheme.titleLarge),
          if (q != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Now ${fmtMoney(q.price, currency: q.currency)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _below,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Notify me when it drops to',
              prefixIcon: Icon(Icons.south_east_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _above,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Notify me when it rises to',
              prefixIcon: Icon(Icons.north_east_rounded),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Checked about once an hour in the background on Android.',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await provider.setWatchTargets(
                widget.item.symbol,
                above: _parse(_above.text),
                below: _parse(_below.text),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save targets'),
          ),
        ],
      ),
    );
  }
}
