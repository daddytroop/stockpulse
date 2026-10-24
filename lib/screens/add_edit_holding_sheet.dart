import 'dart:async';

import 'package:flutter/material.dart';

import '../models/quote.dart';
import '../providers/portfolio_provider.dart';

/// Modal bottom sheet to add or edit a holding. Features Yahoo symbol
/// autocomplete while typing.
Future<void> showAddEditHoldingSheet(
  BuildContext context,
  PortfolioProvider provider,
  String portfolioId, {
  String? editSymbol,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddEditSheet(
      provider: provider,
      portfolioId: portfolioId,
      editSymbol: editSymbol,
    ),
  );
}

class _AddEditSheet extends StatefulWidget {
  final PortfolioProvider provider;
  final String portfolioId;
  final String? editSymbol;

  const _AddEditSheet({
    required this.provider,
    required this.portfolioId,
    this.editSymbol,
  });

  @override
  State<_AddEditSheet> createState() => _AddEditSheetState();
}

class _AddEditSheetState extends State<_AddEditSheet> {
  final _symbolCtl = TextEditingController();
  final _qtyCtl = TextEditingController();
  final _costCtl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<SearchResult> _suggestions = const [];
  bool _searching = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.editSymbol != null;

  @override
  void initState() {
    super.initState();
    final h = _holding();
    if (h != null) {
      _symbolCtl.text = h.symbol;
      _qtyCtl.text = _trimNum(h.quantity);
      _costCtl.text = h.avgCost > 0 ? _trimNum(h.avgCost) : '';
    }
    _symbolCtl.addListener(_onSymbolChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _symbolCtl.removeListener(_onSymbolChanged);
    _symbolCtl.dispose();
    _qtyCtl.dispose();
    _costCtl.dispose();
    _focus.dispose();
    super.dispose();
  }

  dynamic _holding() {
    if (widget.editSymbol == null) return null;
    final p = widget.provider.byId(widget.portfolioId);
    return p?.holdings[widget.editSymbol!.toUpperCase()];
  }

  static String _trimNum(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '');

  void _onSymbolChanged() {
    if (_isEdit) return;
    _debounce?.cancel();
    final q = _symbolCtl.text.trim();
    if (q.length < 2 || !mounted) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      try {
        final results = await widget.provider.searchSymbols(q);
        if (!mounted) return;
        setState(() {
          _suggestions = results.take(8).toList();
          _searching = false;
        });
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _save() async {
    final symbol = _symbolCtl.text.trim().toUpperCase();
    final qty = double.tryParse(_qtyCtl.text.trim().replaceAll(',', '.'));
    var cost = double.tryParse(_costCtl.text.trim().replaceAll(',', '.'));
    if (cost != null && cost < 0) cost = null;

    if (symbol.isEmpty) {
      setState(() => _error = 'Enter a symbol.');
      return;
    }
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await widget.provider.updateHolding(
          portfolioId: widget.portfolioId,
          symbol: symbol,
          quantity: qty,
          avgCost: cost ?? 0,
        );
      } else {
        final err = await widget.provider.addHolding(
          portfolioId: widget.portfolioId,
          symbol: symbol,
          quantity: qty,
          avgCost: cost ?? 0,
        );
        if (err != null) {
          setState(() {
            _error = err;
            _saving = false;
          });
          return;
        }
        widget.provider.ensureDividendInfo(symbolsIn: {symbol});
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Something went wrong: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit holding' : 'Add holding',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _symbolCtl,
              focusNode: _focus,
              enabled: !_isEdit,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Symbol',
                hintText: 'AAPL, SCHD, BTC-USD, SHOP.TO ...',
                border: const OutlineInputBorder(),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
            ),
            if (_suggestions.isNotEmpty && !_isEdit)
              Container(
                constraints: const BoxConstraints(maxHeight: 240),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, i) {
                    final s = _suggestions[i];
                    return ListTile(
                      dense: true,
                      title: Text(s.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${s.name}${s.exchange != null ? ' · ${s.exchange}' : ''}${s.type != null ? ' · ${s.type}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        _symbolCtl.text = s.symbol;
                        setState(() => _suggestions = const []);
                        _focus.unfocus();
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _costCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Avg cost per unit',
                      hintText: 'optional',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEdit ? 'Save changes' : 'Add to portfolio'),
              ),
            ),
            if (!_isEdit)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Buying more of the same symbol? Add again - quantities and average cost merge automatically.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}