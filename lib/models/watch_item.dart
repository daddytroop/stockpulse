/// A stock the user follows without owning it, with optional price targets.
class WatchItem {
  final String symbol;
  final DateTime addedAt;

  /// Notify when the price rises to this level or above.
  final double? above;

  /// Notify when the price falls to this level or below.
  final double? below;

  const WatchItem({
    required this.symbol,
    required this.addedAt,
    this.above,
    this.below,
  });

  bool get hasTargets => above != null || below != null;

  WatchItem copyWith({
    double? above,
    double? below,
    bool clearAbove = false,
    bool clearBelow = false,
  }) =>
      WatchItem(
        symbol: symbol,
        addedAt: addedAt,
        above: clearAbove ? null : (above ?? this.above),
        below: clearBelow ? null : (below ?? this.below),
      );

  /// Which target [price] has reached, if any: 'above', 'below' or null.
  String? hitBy(double price) {
    if (price <= 0) return null;
    if (above != null && price >= above!) return 'above';
    if (below != null && price <= below!) return 'below';
    return null;
  }

  Map<String, dynamic> toMap() => {
        'symbol': symbol,
        'addedAt': addedAt.toIso8601String(),
        if (above != null) 'above': above,
        if (below != null) 'below': below,
      };

  static WatchItem? fromMap(Map<String, dynamic> m) {
    final symbol = (m['symbol'] as String? ?? '').trim().toUpperCase();
    if (symbol.isEmpty) return null;
    return WatchItem(
      symbol: symbol,
      addedAt: DateTime.tryParse(m['addedAt'] as String? ?? '') ?? DateTime.now(),
      above: (m['above'] as num?)?.toDouble(),
      below: (m['below'] as num?)?.toDouble(),
    );
  }
}
