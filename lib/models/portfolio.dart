import 'package:flutter/foundation.dart';

import 'holding.dart';

/// A named collection of holdings. Holdings are keyed by Yahoo symbol.
@immutable
class Portfolio {
  final String id;
  final String name;
  final Map<String, Holding> holdings;

  const Portfolio({
    required this.id,
    required this.name,
    Map<String, Holding>? holdings,
  }) : holdings = holdings ?? const {};

  List<String> get symbols => holdings.keys.toList();

  bool has(String symbol) => holdings.containsKey(symbol);

  Portfolio copyWith({String? name, Map<String, Holding>? holdings}) {
    return Portfolio(
      id: id,
      name: name ?? this.name,
      holdings: holdings ?? this.holdings,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'holdings': [for (final h in holdings.values) h.toMap()],
      };

  factory Portfolio.fromMap(Map<String, dynamic> m) {
    final list = (m['holdings'] as List? ?? []);
    return Portfolio(
      id: (m['id'] ?? '') as String,
      name: (m['name'] ?? 'Portfolio') as String,
      holdings: {
        for (final h in list.whereType<Map<String, dynamic>>())
          ((h['symbol'] ?? '') as String).toUpperCase(): Holding.fromMap(h),
      },
    );
  }
}