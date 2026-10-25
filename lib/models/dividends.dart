import 'dart:math';

import 'package:flutter/foundation.dart';

/// A company stock split event (e.g. 4:1 -> multiply quantity by 4 / divide cost).
@immutable
class StockSplit {
  final DateTime date;
  final int numerator;
  final int denominator;
  const StockSplit({required this.date, required this.numerator, this.denominator = 1});

  double get multiplier => numerator / max(denominator, 1);

  factory StockSplit.fromEventJson(Map<String, dynamic> j) {
    final ts = (j['date'] as num?)?.toInt() ?? 0;
    return StockSplit(
      date: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
      numerator: ((j['numerator'] as num?) ?? 1).toInt(),
      denominator: max(((j['denominator'] as num?) ?? 1).toInt(), 1),
    );
  }
}

/// A historical dividend per share. Yahoo chart `dividends` events are keyed
/// by the ex-dividend date.
@immutable
class DividendPayment {
  final DateTime exDate;
  final double amount;
  const DividendPayment({required this.exDate, required this.amount});

  Map<String, dynamic> toMap() => {'t': exDate.millisecondsSinceEpoch ~/ 1000, 'a': amount};

  factory DividendPayment.fromMap(Map<String, dynamic> m) => DividendPayment(
        exDate: DateTime.fromMillisecondsSinceEpoch(((m['t'] as num?)?.toInt() ?? 0) * 1000),
        amount: (m['a'] as num? ?? 0).toDouble(),
      );
}

/// Everything we know about a symbol's dividend history. Cached for ~24h.
@immutable
class DividendInfo {
  final String symbol;
  final List<DividendPayment> payments; // ascending by exDate
  final List<StockSplit> splits; // ascending by date
  final DateTime? exDividendDate; // exact upcoming ex-date (if known)
  final DateTime? payDate; // exact upcoming pay date (if known)
  final DateTime cachedAt;

  const DividendInfo({
    required this.symbol,
    required this.payments,
    this.splits = const [],
    required this.cachedAt,
    this.exDividendDate,
    this.payDate,
  });

  void sortPayments() {
    payments.sort((a, b) => a.exDate.compareTo(b.exDate));
  }

  /// Median gap in days between consecutive payments (0 if <2 payments).
  int get medianGapDays {
    if (payments.length < 2) return 0;
    final gaps = <int>[];
    for (var i = 1; i < payments.length; i++) {
      gaps.add(payments[i].exDate.difference(payments[i - 1].exDate).inDays.abs());
    }
    gaps.sort();
    return gaps[gaps.length ~/ 2];
  }

  /// Estimated payments per year (clamped to 1..12). Quarterly default.
  int get periodsPerYear {
    final gap = medianGapDays;
    if (gap <= 0) return 4;
    return (365 / gap).round().clamp(1, 12);
  }

  /// Most recent per-share payment.
  double get lastAmount => payments.isEmpty ? 0 : payments.last.amount;

  /// Trailing-twelve-months dividend per share. Falls back to the cadence
  /// estimate when the last 12 months contain no payment (annual payer).
  double get ttmPerShare {
    if (payments.isEmpty) return 0;
    final cutoff = DateTime.now().subtract(const Duration(days: 366));
    final ttm = payments.where((p) => p.exDate.isAfter(cutoff)).fold<double>(0, (s, p) => s + p.amount);
    if (ttm > 0) return ttm;
    return lastAmount * periodsPerYear;
  }
}

/// An estimated or exact upcoming dividend for a holding.
@immutable
class UpcomingDividend {
  final String symbol;
  final double quantity;
  final DateTime exDate;
  final DateTime? payDate;
  final double amountPerShare;
  final bool estimated; // true when dates/amounts are inferred
  const UpcomingDividend({
    required this.symbol,
    required this.quantity,
    required this.exDate,
    required this.amountPerShare,
    this.payDate,
    this.estimated = true,
  });

  double get total => quantity * amountPerShare;

  Map<String, dynamic> toMap() => {
        'symbol': symbol,
        'quantity': quantity,
        'exDate': exDate.millisecondsSinceEpoch ~/ 1000,
        'payDate': payDate?.millisecondsSinceEpoch,
        'amountPerShare': amountPerShare,
        'estimated': estimated,
      };
}