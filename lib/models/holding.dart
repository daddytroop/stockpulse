import 'package:flutter/foundation.dart';

/// A position in a portfolio: how many units of a symbol you own and at what
/// average cost. One row per symbol (multiple buys are merged by weighting).
@immutable
class Holding {
  final String symbol; // Yahoo symbol, e.g. AAPL, BTC-USD, SHOP.TO
  final String name; // display name
  final String currency; // ISO currency of the quote, e.g. USD, CAD
  final double quantity;
  final double avgCost; // average cost per unit in [currency]; 0 = unknown
  final DateTime? addedAt;

  const Holding({
    required this.symbol,
    required this.quantity,
    required this.avgCost,
    this.name = '',
    this.currency = 'USD',
    this.addedAt,
  });

  double get costBasis => quantity * avgCost;

  Holding mergeWith(double addQuantity, double addAvgCost) {
    final total = quantity + addQuantity;
    if (addAvgCost <= 0) return copyWith(quantity: total);
    final newAvg = quantity <= 0
        ? addAvgCost
        : (quantity * avgCost + addQuantity * addAvgCost) / total;
    return copyWith(quantity: total, avgCost: newAvg);
  }

  Holding addQuantity(double delta) =>
      copyWith(quantity: (quantity + delta).clamp(0, double.infinity).toDouble());

  Holding copyWith({
    String? name,
    String? currency,
    double? quantity,
    double? avgCost,
    DateTime? addedAt,
  }) {
    return Holding(
      symbol: symbol,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      quantity: quantity ?? this.quantity,
      avgCost: avgCost ?? this.avgCost,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'symbol': symbol,
        'name': name,
        'currency': currency,
        'quantity': quantity,
        'avgCost': avgCost,
        'addedAt': addedAt?.toIso8601String(),
      };

  factory Holding.fromMap(Map<String, dynamic> m) {
    return Holding(
      symbol: (m['symbol'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      currency: (m['currency'] ?? 'USD') as String,
      quantity: (m['quantity'] as num? ?? 0).toDouble(),
      avgCost: (m['avgCost'] as num? ?? 0).toDouble(),
      addedAt: m['addedAt'] == null ? null : DateTime.tryParse(m['addedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) => other is Holding && other.symbol == symbol;

  @override
  int get hashCode => symbol.hashCode;

  @override
  String toString() => 'Holding($symbol x$quantity @$avgCost $currency)';
}