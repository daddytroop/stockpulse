import 'package:flutter/foundation.dart';

/// A recorded trade against a symbol in a portfolio (buys and sells).
/// Created automatically when holdings are added; one "buy" per row.
@immutable
class Txn {
  final String kind; // 'buy' | 'sell'
  final double quantity; // always positive; sign of [kind]
  final double unitPrice;
  final double fee;
  final DateTime date;
  final String note;

  const Txn({
    required this.kind,
    required this.quantity,
    required this.unitPrice,
    this.fee = 0,
    required this.date,
    this.note = '',
  });

  bool get isBuy => kind == 'buy';

  Map<String, dynamic> toMap() => {
        'kind': kind,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'fee': fee,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Txn.fromMap(Map<String, dynamic> m) => Txn(
        kind: (m['kind'] ?? 'buy') as String,
        quantity: (m['quantity'] as num? ?? 0).toDouble(),
        unitPrice: (m['unitPrice'] as num? ?? 0).toDouble(),
        fee: (m['fee'] as num? ?? 0).toDouble(),
        date: DateTime.tryParse((m['date'] ?? '') as String) ?? DateTime.now(),
        note: (m['note'] ?? '') as String,
      );

  @override
  String toString() => '$kind x$quantity @$unitPrice';
}