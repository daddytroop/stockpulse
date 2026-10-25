import 'dart:math';

import '../models/dividends.dart';
import '../models/transaction.dart';

/// Pure-Dart position ledger computations (no I/O, easily unit tested).

/// Net share count at [when], replaying all transactions dated on or before
/// that day (same-day trades count as held).
double sharesAt(DateTime when, List<Txn> txns) {
  var q = 0.0;
  for (final t in txns) {
    if (!t.date.isAfter(when)) {
      q += t.isBuy ? t.quantity : -t.quantity;
    }
  }
  return max(q, 0);
}

/// Replays a full buy/sell history and returns realized P/L, or null when
/// the history is incomplete (sells without recorded buys - e.g. imported
/// positions where past buys are unknown).
double? replayRealizedPnl(List<Txn> txns) {
  final sorted = txns.toList()..sort((a, b) => a.date.compareTo(b.date));
  final hasSells = sorted.any((t) => !t.isBuy);
  final hasBuys = sorted.any((t) => t.isBuy);
  if (!hasSells) return null;
  if (!hasBuys) return null; // legacy: cost basis unknown at sell time

  double qty = 0;
  double cost = 0;
  var realized = 0.0;
  for (final t in sorted) {
    if (t.isBuy) {
      qty += t.quantity;
      cost += t.unitPrice * t.quantity + t.fee;
    } else {
      if (qty <= 0) return null;
      final avg = cost / qty;
      final sold = min(t.quantity, qty);
      realized += (t.unitPrice - avg) * sold - t.fee;
      qty -= sold;
      cost = avg * qty;
    }
  }
  return realized;
}

/// Total dividend cash actually collected for a position so far.
///
/// With a [txns] history it uses the share count at each ex-date. Legacy
/// positions without a transaction history approximate with the current
/// quantity for every payment after [holdingStart].
double dividendsReceived({
  required List<Txn> txns,
  required List<DividendPayment> payments,
  required double currentQty,
  required DateTime? holdingStart,
}) {
  if (payments.isEmpty) return 0;
  final start = holdingStart ?? DateTime.fromMillisecondsSinceEpoch(0);
  if (txns.isEmpty) {
    return payments
        .where((p) => p.exDate.isAfter(start))
        .fold(0.0, (s, p) => s + currentQty * p.amount);
  }
  var total = 0.0;
  for (final p in payments) {
    if (!p.exDate.isAfter(start)) continue;
    total += sharesAt(p.exDate, txns) * p.amount;
  }
  return total;
}

/// Estimated 5-year dividend income if payments are reinvested (DRIP) at
/// [annualYieldPct]. Straight compounding approximation.
double dripProjection(double annualIncome, double annualYieldPct, {int years = 5}) {
  final y = annualYieldPct / 100;
  if (y <= 0 || annualIncome <= 0) return 0;
  return annualIncome * (pow(1 + y, years) - 1) / y;
}