import 'dart:math';

import '../models/dividends.dart';
import '../models/quote.dart';
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

/// Dividend cash collected for a position between two dates.
///
/// Same rules as [dividendsReceived], but only the payments that fall
/// inside the window are counted - used for "received this month" and
/// "received so far this year".
double dividendsReceivedInRange({
  required List<Txn> txns,
  required List<DividendPayment> payments,
  required double currentQty,
  required DateTime? holdingStart,
  required DateTime from,
  required DateTime to,
}) {
  if (payments.isEmpty) return 0;
  final start = holdingStart ?? DateTime.fromMillisecondsSinceEpoch(0);
  var total = 0.0;
  for (final p in payments) {
    if (p.exDate.isBefore(from) || p.exDate.isAfter(to)) continue;
    if (!p.exDate.isAfter(start)) continue;
    final qty = txns.isEmpty ? currentQty : sharesAt(p.exDate, txns);
    if (qty > 0) total += qty * p.amount;
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

/// Per-share dividend totals grouped by calendar year (ascending years).
Map<int, double> dividendYearTotals(List<DividendPayment> payments) {
  final byYear = <int, double>{};
  for (final p in payments) {
    byYear[p.exDate.year] = (byYear[p.exDate.year] ?? 0) + p.amount;
  }
  final years = byYear.keys.toList()..sort();
  return {for (final y in years) y: byYear[y]!};
}

/// YoY change in percent between the two most recent years with payments.
/// null when not computable (fewer than 2 years or previous year empty).
double? dividendGrowthPct(List<DividendPayment> payments) {
  final totals = dividendYearTotals(payments);
  if (totals.length < 2) return null;
  final years = totals.keys.toList();
  double? growth;
  for (var i = 1; i < years.length; i++) {
    final prev = totals[years[i - 1]]!;
    final cur = totals[years[i]]!;
    if (prev <= 0) continue;
    growth = (cur - prev) / prev * 100;
  }
  return growth;
}

/// Normalizes a value series to percent change since the first point.
List<ChartPoint>? normalizePercent(List<ChartPoint> series) {
  if (series.length < 2) return null;
  final base = series.first.close;
  if (base == 0) return null;
  return [
    for (final p in series) ChartPoint(p.time, (p.close / base - 1) * 100),
  ];
}