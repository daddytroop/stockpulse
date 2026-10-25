import 'package:flutter/material.dart';

import '../models/holding.dart';
import '../providers/portfolio_provider.dart';
import '../utils/formatters.dart';
import '../widgets/stat_cards.dart';

/// Dialog to sell part or all of a position.
Future<void> showSellDialog(
  BuildContext context,
  PortfolioProvider provider,
  String portfolioId,
  Holding holding,
) {
  return showDialog(
    context: context,
    builder: (_) => _SellDialog(
      provider: provider,
      portfolioId: portfolioId,
      holding: holding,
    ),
  );
}

class _SellDialog extends StatefulWidget {
  final PortfolioProvider provider;
  final String portfolioId;
  final Holding holding;

  const _SellDialog({
    required this.provider,
    required this.portfolioId,
    required this.holding,
  });

  @override
  State<_SellDialog> createState() => _SellDialogState();
}

class _SellDialogState extends State<_SellDialog> {
  late final TextEditingController _qty;
  late final TextEditingController _price;
  final TextEditingController _fee = TextEditingController(text: '0');
  bool _selling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.provider.quoteOf(widget.holding.symbol);
    // Prefill: full position at the current price.
    _qty = TextEditingController(text: _trim(widget.holding.quantity));
    _price = TextEditingController(text: _trim(q?.price ?? widget.holding.avgCost));
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _fee.dispose();
    super.dispose();
  }

  static String _trim(num v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '');

  double get _qtyVal => double.tryParse(_qty.text.trim().replaceAll(',', '.')) ?? 0;
  double get _priceVal => double.tryParse(_price.text.trim().replaceAll(',', '.')) ?? 0;
  double get _feeVal => double.tryParse(_fee.text.trim().replaceAll(',', '.')) ?? 0;

  double get _estimatedRealized {
    final avg = widget.holding.avgCost;
    if (avg <= 0) return 0;
    return (_priceVal - avg) * _qtyVal - _feeVal;
  }

  Future<void> _sell() async {
    setState(() {
      _selling = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final err = await widget.provider.sellHolding(
      portfolioId: widget.portfolioId,
      symbol: widget.holding.symbol,
      quantity: _qtyVal,
      unitPrice: _priceVal,
      fee: _feeVal,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _error = err;
        _selling = false;
      });
      return;
    }
    Navigator.of(context).pop();
    final realized = widget.holding.avgCost > 0 ? _estimatedRealized : null;
    messenger.showSnackBar(SnackBar(
      content: Text(
        realized == null
            ? 'Sold ${fmtQty(_qtyVal)} ${widget.holding.symbol}'
            : 'Sold ${fmtQty(_qtyVal)} ${widget.holding.symbol} · '
                'realized ${fmtSignedMoney(realized, currency: widget.holding.currency)}',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avg = widget.holding.avgCost;
    return AlertDialog(
      title: Text('Sell ${widget.holding.symbol}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You own ${fmtQty(widget.holding.quantity)} units'
              '${avg > 0 ? ' at avg ${fmtMoney(avg, currency: widget.holding.currency)}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantity to sell',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Sell price/unit',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: TextField(
                  controller: _fee,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Fee',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              'Estimated realized P/L: '
              '${fmtSignedMoney(_estimatedRealized, currency: widget.holding.currency)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: pnlColor(_estimatedRealized),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _selling ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _selling || _qtyVal <= 0 || _priceVal <= 0 ? null : _sell,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _selling
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Sell'),
          ),
        ),
      ],
    );
  }
}