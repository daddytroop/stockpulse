import 'package:flutter/foundation.dart';

/// A market snapshot for one symbol. Parsed from either the batched
/// `v7/finance/quote` endpoint (preferred) or the `v8/finance/chart` meta
/// (fallback when the crumb-protected endpoint is unavailable).
@immutable
class Quote {
  final String symbol;
  final String name;
  final String currency;
  final String? quoteType; // EQUITY, ETF, CRYPTOCURRENCY, ...
  final String? exchange; // venue code, e.g. NMS, NYQ, TOR
  final String? fullExchangeName; // venue name, e.g. NasdaqGS, NYSE, Toronto
  final String? marketState;

  final double price;
  final double? previousClose;
  final double? dayChange;
  final double? dayChangePercent;

  final double? fiftyTwoWeekHigh;
  final double? fiftyTwoWeekLow;

  /// Trailing 12-month dividend per share (null for non-payers).
  final double? dividendRate;
  final double? dividendYield;
  final DateTime? dividendPayDate;
  final DateTime? earningsDate;
  final bool earningsIsEstimate;

  final DateTime updatedAt;
  final DateTime? marketTime;

  const Quote({
    required this.symbol,
    required this.name,
    required this.currency,
    required this.price,
    required this.updatedAt,
    this.marketTime,
    this.quoteType,
    this.exchange,
    this.fullExchangeName,
    this.marketState,
    this.previousClose,
    this.dayChange,
    this.dayChangePercent,
    this.fiftyTwoWeekHigh,
    this.fiftyTwoWeekLow,
    this.dividendRate,
    this.dividendYield,
    this.dividendPayDate,
    this.earningsDate,
    this.earningsIsEstimate = false,
  });

  bool get isCrypto => quoteType == 'CRYPTOCURRENCY';

  factory Quote.fromV7Json(Map<String, dynamic> j) {
    final price = (j['regularMarketPrice'] as num?)?.toDouble() ?? 0;
    final change = (j['regularMarketChange'] as num?)?.toDouble();
    final changePct = (j['regularMarketChangePercent'] as num?)?.toDouble();
    DateTime? ts(int? s) => s == null || s <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(s * 1000);
    return Quote(
      symbol: (j['symbol'] ?? '') as String,
      name: (j['shortName'] ?? j['longName'] ?? '') as String,
      currency: (j['currency'] ?? 'USD') as String,
      quoteType: j['quoteType'] as String?,
      exchange: j['exchange'] as String?,
      fullExchangeName: j['fullExchangeName'] as String?,
      marketState: j['marketState'] as String?,
      price: price,
      previousClose: (j['regularMarketPreviousClose'] as num?)?.toDouble(),
      dayChange: change ?? (changePct == null ? null : price * changePct / 100),
      dayChangePercent: changePct,
      fiftyTwoWeekHigh: (j['fiftyTwoWeekHigh'] as num?)?.toDouble(),
      fiftyTwoWeekLow: (j['fiftyTwoWeekLow'] as num?)?.toDouble(),
      dividendRate: _positive((j['trailingAnnualDividendRate'] as num?)?.toDouble() ?? (j['dividendRate'] as num?)?.toDouble()),
      dividendYield: _positive((j['trailingAnnualDividendYield'] as num?)?.toDouble() ?? (j['dividendYield'] as num?)?.toDouble()),
      dividendPayDate: ts((j['dividendDate'] as num?)?.toInt()),
      earningsDate: ts((j['earningsTimestampStart'] as num?)?.toInt() ?? (j['earningsTimestamp'] as num?)?.toInt()),
      updatedAt: DateTime.now(),
      marketTime: ts((j['regularMarketTime'] as num?)?.toInt()),
    );
  }

  /// Parsed from the v8 chart meta + series (used as fallback).
  factory Quote.fromChartJson(
    Map<String, dynamic> meta, {
    required double? previousClose,
    List<double?>? closes,
  }) {
    final price = (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0;
    final changePct = (meta['regularMarketChangePercent'] as num?)?.toDouble();
    // Derive previous close from the second-to-last bar when the meta does
    // not provide it directly.
    double? prev = previousClose;
    if (prev == null && closes != null) {
      final valid = closes.where((c) => c != null && c > 0).toList();
      // Walk back to find the close strictly before the last one.
      if (valid.length >= 2) prev = valid[valid.length - 2];
    }
    final change = changePct != null ? price * changePct / 100 : (prev != null ? price - prev : null);
    return Quote(
      symbol: (meta['symbol'] ?? '') as String,
      name: (meta['shortName'] ?? meta['longName'] ?? '') as String,
      currency: (meta['currency'] ?? 'USD') as String,
      quoteType: meta['instrumentType'] as String?,
      exchange: meta['exchangeName'] as String?,
      fullExchangeName: meta['fullExchangeName'] as String?,
      price: price,
      previousClose: prev,
      dayChange: change,
      dayChangePercent: changePct,
      fiftyTwoWeekHigh: (meta['fiftyTwoWeekHigh'] as num?)?.toDouble(),
      fiftyTwoWeekLow: (meta['fiftyTwoWeekLow'] as num?)?.toDouble(),
      updatedAt: DateTime.now(),
      marketTime: (meta['regularMarketTime'] as num?) == null ? null
          : DateTime.fromMillisecondsSinceEpoch((meta['regularMarketTime'] as num).toInt() * 1000),
    );
  }

  static double? _positive(double? v) => (v == null || v <= 0) ? null : v;

  Map<String, dynamic> toMap() => {
        'marketTime': marketTime?.toIso8601String(),
        'symbol': symbol,
        'name': name,
        'currency': currency,
        'quoteType': quoteType,
        'exchange': exchange,
        'fullExchangeName': fullExchangeName,
        'marketState': marketState,
        'price': price,
        'previousClose': previousClose,
        'dayChange': dayChange,
        'dayChangePercent': dayChangePercent,
        'fiftyTwoWeekHigh': fiftyTwoWeekHigh,
        'fiftyTwoWeekLow': fiftyTwoWeekLow,
        'dividendRate': dividendRate,
        'dividendYield': dividendYield,
        'dividendPayDateMs': dividendPayDate?.millisecondsSinceEpoch,
        'earningsDateMs': earningsDate?.millisecondsSinceEpoch,
        'earningsIsEstimate': earningsIsEstimate,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Quote.fromMap(Map<String, dynamic> m) {
    return Quote(
      symbol: (m['symbol'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      currency: (m['currency'] ?? 'USD') as String,
      quoteType: m['quoteType'] as String?,
      exchange: m['exchange'] as String?,
      fullExchangeName: m['fullExchangeName'] as String?,
      marketState: m['marketState'] as String?,
      price: (m['price'] as num? ?? 0).toDouble(),
      previousClose: (m['previousClose'] as num?)?.toDouble(),
      dayChange: (m['dayChange'] as num?)?.toDouble(),
      dayChangePercent: (m['dayChangePercent'] as num?)?.toDouble(),
      fiftyTwoWeekHigh: (m['fiftyTwoWeekHigh'] as num?)?.toDouble(),
      fiftyTwoWeekLow: (m['fiftyTwoWeekLow'] as num?)?.toDouble(),
      dividendRate: (m['dividendRate'] as num?)?.toDouble(),
      dividendYield: (m['dividendYield'] as num?)?.toDouble(),
      dividendPayDate: _msToDt(m['dividendPayDateMs'] as num?),
      earningsDate: _msToDt(m['earningsDateMs'] as num?),
      earningsIsEstimate: (m['earningsIsEstimate'] as bool? ?? false),
      updatedAt: m['updatedAt'] == null ? DateTime.now() : (DateTime.tryParse(m['updatedAt'] as String) ?? DateTime.now()),
      marketTime: m['marketTime'] == null
          ? null
          : DateTime.tryParse(m['marketTime'] as String),
    );
  }

  static DateTime? _msToDt(num? ms) =>
      ms == null || ms <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms.toInt() * 1000);
}

/// One point of a price history series.
@immutable
class ChartPoint {
  final DateTime time;
  final double close;
  const ChartPoint(this.time, this.close);
}

/// Result of a yahoo symbol search.
@immutable
class SearchResult {
  final String symbol;
  final String name;
  final String? type; // e.g. Equity, ETF, Crypto
  final String? exchange;
  const SearchResult({required this.symbol, required this.name, this.type, this.exchange});
}

/// A news story related to a symbol.
@immutable
class NewsItem {
  final String title;
  final String publisher;
  final String link;
  final DateTime publishedAt;
  final List<String> relatedTickers;
  const NewsItem({
    required this.title,
    required this.publisher,
    required this.link,
    required this.publishedAt,
    this.relatedTickers = const [],
  });
}

/// Exact dividend/earnings calendar data from quoteSummary (when available).
@immutable
class CalendarData {
  final DateTime? exDividendDate;
  final DateTime? payDate;
  final DateTime? earningsDate;
  final bool earningsIsEstimate;
  const CalendarData({this.exDividendDate, this.payDate, this.earningsDate, this.earningsIsEstimate = false});
}
