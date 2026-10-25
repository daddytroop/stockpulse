import 'package:flutter/foundation.dart';

import 'holding.dart';
import 'transaction.dart';

/// A named collection of holdings. Holdings are keyed by Yahoo symbol.
@immutable
class Portfolio {
  final String id;
  final String name;
  final Map<String, Holding> holdings;
  final Map<String, List<Txn>> transactions;

  const Portfolio({
    required this.id,
    required this.name,
    Map<String, Holding>? holdings,
    Map<String, List<Txn>>? transactions,
  })  : holdings = holdings ?? const {},
        transactions = transactions ?? const {};

  List<String> get symbols => holdings.keys.toList();

  bool has(String symbol) => holdings.containsKey(symbol);

  List<Txn> txnsFor(String symbol) => transactions[symbol] ?? const <Txn>[];

  Portfolio copyWith({
    String? name,
    Map<String, Holding>? holdings,
    Map<String, List<Txn>>? transactions,
  }) {
    return Portfolio(
      id: id,
      name: name ?? this.name,
      holdings: holdings ?? this.holdings,
      transactions: transactions ?? this.transactions,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'holdings': [for (final h in holdings.values) h.toMap()],
        'transactions': {
          for (final e in transactions.entries)
            if (e.value.isNotEmpty) e.key: [for (final t in e.value) t.toMap()],
        },
      };

  factory Portfolio.fromMap(Map<String, dynamic> m) {
    final list = (m['holdings'] as List? ?? []);
    final txnsRaw = (m['transactions'] as Map? ?? {});
    return Portfolio(
      id: (m['id'] ?? '') as String,
      name: (m['name'] ?? 'Portfolio') as String,
      holdings: {
        for (final h in list.whereType<Map<String, dynamic>>())
          ((h['symbol'] ?? '') as String).toUpperCase(): Holding.fromMap(h),
      },
      transactions: {
        for (final e in txnsRaw.entries)
          if (e.value is List)
            e.key.toString(): [
              for (final t in (e.value as List).whereType<Map<String, dynamic>>()) Txn.fromMap(t)
            ],
      }..removeWhere((k, v) => k.isEmpty || v.isEmpty),
    );
  }
}