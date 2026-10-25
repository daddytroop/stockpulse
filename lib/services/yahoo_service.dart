import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dividends.dart';
import '../models/quote.dart';

class YahooException implements Exception {
  final String message;
  const YahooException(this.message);
  @override
  String toString() => 'YahooException: $message';
}

/// A parsed price-history response (v8 chart).
class ChartHistory {
  final Map<String, dynamic> meta;
  final List<ChartPoint> points;
  final List<DividendPayment> dividends;
  final List<StockSplit> splits;
  const ChartHistory({
    required this.meta,
    required this.points,
    required this.dividends,
    this.splits = const [],
  });
}

class _Cached<T> {
  final T value;
  final DateTime at;
  _Cached(this.value, this.at);
  bool fresh(Duration ttl) => DateTime.now().difference(at) < ttl;
}

/// Unofficial Yahoo Finance client. No API key required.
///
/// Two request paths are used:
///  * Batched quotes / calendar data  -> `v7/finance/quote` and
///    `v10/finance/quoteSummary`, protected by a cookie+crumb handshake
///    (fc.yahoo.com sets the A3 cookie, /v1/test/getcrumb returns the crumb).
///  * Everything else (search, news, chart history incl. dividends) works
///    without the handshake.
///
/// If the handshake fails at runtime the service transparently falls back to
/// per-symbol chart requests.
class YahooService {
  YahooService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static const List<String> _hosts = [
    'query1.finance.yahoo.com',
    'query2.finance.yahoo.com',
  ];

  String? _cookie;
  String? _crumb;
  DateTime _crumbAt = DateTime.fromMillisecondsSinceEpoch(0);

  final Map<String, _Cached<ChartHistory>> _chartCache = {};
  final Map<String, _Cached<CalendarData?>> _calendarCache = {};
  final Map<String, _Cached<List<NewsItem>>> _newsCache = {};

  static const Duration _chartTtl = Duration(minutes: 10);
  static const Duration _newsTtl = Duration(minutes: 15);
  static const Duration _calendarTtl = Duration(hours: 12);

  // ---------------------------------------------------------------------------
  // Low-level helpers
  // ---------------------------------------------------------------------------

  Map<String, String> _headers({bool withCookie = false}) {
    final h = <String, String>{'User-Agent': _ua};
    if (withCookie && _cookie != null) h['Cookie'] = _cookie!;
    return h;
  }

  /// GET with host failover; returns null if every attempt fails.
  Future<http.Response?> _get(String path, Map<String, String> params,
      {bool withCookie = false}) async {
    final query = Uri(queryParameters: params).query;
    for (final host in _hosts) {
      try {
        final uri = Uri.parse('https://$host$path?$query');
        final r = await _client
            .get(uri, headers: _headers(withCookie: withCookie))
            .timeout(const Duration(seconds: 12));
        if (r.statusCode == 200) return r;
        if (r.statusCode == 429 || r.statusCode == 503) {
          await Future<void>.delayed(const Duration(milliseconds: 700));
          continue;
        }
      } catch (_) {
        // try next host
      }
    }
    return null;
  }

  /// Makes sure the cookie+crumb handshake is available for protected paths.
  Future<void> _ensureCrumb({bool force = false}) async {
    final fresh =
        _crumb != null && DateTime.now().difference(_crumbAt) < const Duration(minutes: 30);
    if (fresh && !force) return;

    // 1. Obtain the A3 cookie (fc.yahoo.com answers 404 but sets it).
    try {
      final r = await _client
          .get(Uri.parse('https://fc.yahoo.com/'), headers: _headers())
          .timeout(const Duration(seconds: 10));
      final sc = r.headers['set-cookie'];
      if (sc != null && sc.isNotEmpty) {
        _cookie = sc.split(';').first;
      }
    } catch (_) {
      // continue without cookie
    }

    // 2. Exchange the cookie for a crumb. No Accept header here: the endpoint
    //    returns text/plain and a JSON Accept header yields HTTP 406.
    if (_cookie != null) {
      try {
        final r = await _client
            .get(Uri.parse('https://${_hosts[0]}/v1/test/getcrumb'),
                headers: _headers(withCookie: true))
            .timeout(const Duration(seconds: 10));
        final body = r.body.trim();
        if (r.statusCode == 200 && body.isNotEmpty && body.length < 40 && !body.contains('"')) {
          _crumb = body;
          _crumbAt = DateTime.now();
          return;
        }
      } catch (_) {}
    }
    _crumb = null;
  }

  // ---------------------------------------------------------------------------
  // Quotes
  // ---------------------------------------------------------------------------

  /// Batched quotes. Falls back to per-symbol chart requests if the
  /// crumb-protected quote endpoint is unavailable.
  Future<Map<String, Quote>> quotes(Set<String> symbols) async {
    final out = <String, Quote>{};
    if (symbols.isEmpty) return out;

    for (var attempt = 0; attempt < 2; attempt++) {
      await _ensureCrumb(force: attempt > 0);
      if (_crumb == null) break;
      try {
        final list = symbols.toList();
        for (var i = 0; i < list.length; i += 25) {
          final end = (i + 25).clamp(0, list.length);
          final chunk = list.sublist(i, end).map(Uri.encodeComponent).join(',');
          final r = await _get('/v7/finance/quote',
              {'symbols': chunk, 'crumb': _crumb!}, withCookie: true);
          if (r == null) throw const YahooException('quote request failed');
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          final qr = body['quoteResponse'] as Map<String, dynamic>?;
          final results = (qr?['result'] as List?) ?? const [];
          for (final e in results.whereType<Map<String, dynamic>>()) {
            final q = Quote.fromV7Json(e);
            if (q.symbol.isNotEmpty && q.price > 0) out[q.symbol] = q;
          }
          if (end < list.length) {
            await Future<void>.delayed(const Duration(milliseconds: 120));
          }
        }
        if (out.isNotEmpty) return out;
      } catch (_) {
        // retried on next pass, else fall back below
      }
    }

    // Fallback: per-symbol chart meta.
    for (final s in symbols) {
      if (out.containsKey(s)) continue;
      try {
        final h = await chartHistory(s, range: '5d', interval: '1d');
        if (h != null && h.meta.isNotEmpty) {
          final q =
              Quote.fromChartJson(h.meta, previousClose: null, closes: null);
          if (q.price > 0) out[s] = q;
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
      } catch (_) {
        // skip symbol, leave last known value in place
      }
    }
    return out;
  }

  Future<Quote?> quote(String symbol) async {
    final m = await quotes({symbol});
    return m[symbol];
  }

  // ---------------------------------------------------------------------------
  // Price history & dividends
  // ---------------------------------------------------------------------------

  Future<ChartHistory?> chartHistory(String symbol,
      {String range = '1y', String interval = '1d'}) async {
    final key = '$symbol|$range|$interval';
    final c = _chartCache[key];
    if (c != null && c.fresh(_chartTtl)) return c.value;

    final r = await _get('/v8/finance/chart/${Uri.encodeComponent(symbol)}',
        {'interval': interval, 'range': range, 'events': 'div'});
    if (r == null) return null;
    if (!r.body.contains('"chart"')) return null;
    try {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final chart = body['chart'] as Map<String, dynamic>?;
      final results = chart?['result'] as List?;
      if (results == null || results.isEmpty) return null;
      final res = results.first as Map<String, dynamic>;
      final meta = (res['meta'] as Map<String, dynamic>?) ?? const {};
      final indicators = res['indicators'] as Map<String, dynamic>?;
      final quoteArr = indicators?['quote'] as List?;
      final quoteSeries = (quoteArr != null && quoteArr.isNotEmpty)
          ? (quoteArr.first as Map<String, dynamic>)
          : null;
      final times = (res['timestamp'] as List?) ?? const [];
      final closes = (quoteSeries?['close'] as List?) ?? const [];

      final points = <ChartPoint>[];
      for (var i = 0; i < times.length && i < closes.length; i++) {
        final c = (closes[i] as num?)?.toDouble();
        if (c == null || c <= 0) continue;
        points.add(ChartPoint(
          DateTime.fromMillisecondsSinceEpoch((times[i] as num).toInt() * 1000),
          c,
        ));
      }

      final dividends = <DividendPayment>[];
      final events = res['events'] as Map<String, dynamic>?;
      final divMap = events?['dividends'] as Map<String, dynamic>?;
      if (divMap != null) {
        for (final e in divMap.values.whereType<Map<String, dynamic>>()) {
          final amount = (e['amount'] as num?)?.toDouble() ?? 0;
          final date = (e['date'] as num?)?.toInt() ?? 0;
          if (amount > 0 && date > 0) {
            dividends.add(DividendPayment(
              exDate: DateTime.fromMillisecondsSinceEpoch(date * 1000),
              amount: amount,
            ));
          }
        }
        dividends.sort((a, b) => a.exDate.compareTo(b.exDate));
      }

      final splits = <StockSplit>[];
      final splitsMap = events?['splits'] as Map<String, dynamic>?;
      if (splitsMap != null) {
        for (final e in splitsMap.values.whereType<Map<String, dynamic>>()) {
          try {
            splits.add(StockSplit.fromEventJson(e));
          } catch (_) {}
        }
        splits.sort((a, b) => a.date.compareTo(b.date));
      }

      final hist = ChartHistory(
        meta: meta,
        points: points,
        dividends: dividends,
        splits: splits,
      );
      _chartCache[key] = _Cached(hist, DateTime.now());
      return hist;
    } catch (_) {
      return null;
    }
  }

  /// Dividend per-share history (2 years, cached via chartHistory).
  Future<List<DividendPayment>> dividendHistory(String symbol) async {
    final h = await chartHistory(symbol, range: '2y', interval: '1d');
    return h?.dividends ?? const [];
  }

  // ---------------------------------------------------------------------------
  // Calendar (exact upcoming ex-dividend / pay / earnings dates)
  // ---------------------------------------------------------------------------

  Future<CalendarData?> calendarEvents(String symbol) async {
    final c = _calendarCache[symbol];
    if (c != null && c.fresh(_calendarTtl)) return c.value;

    await _ensureCrumb();
    if (_crumb == null) return null;

    final r = await _get(
      '/v10/finance/quoteSummary/${Uri.encodeComponent(symbol)}',
      {'modules': 'calendarEvents'},
      withCookie: true,
    );
    if (r == null) return null;
    try {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final results = (body['quoteSummary']?['result'] as List?) ?? const [];
      if (results.isEmpty) return null;
      final cal = ((results.first as Map<String, dynamic>)['calendarEvents']
          as Map<String, dynamic>?);
      if (cal == null) return null;

      DateTime? fromRaw(dynamic v) {
        if (v is Map && v['raw'] is num) {
          final s = (v['raw'] as num).toInt();
          if (s > 0) return DateTime.fromMillisecondsSinceEpoch(s * 1000);
        }
        return null;
      }

      final earnings = cal['earnings'] as Map<String, dynamic>?;
      DateTime? earnDate;
      bool isEstimate = false;
      if (earnings != null) {
        final dates = (earnings['earningsDate'] as List?) ?? const [];
        if (dates.isNotEmpty) earnDate = fromRaw(dates.first);
        isEstimate = earnings['isEarningsDateEstimate'] as bool? ?? false;
      }

      final data = CalendarData(
        exDividendDate: fromRaw(cal['exDividendDate']),
        payDate: fromRaw(cal['dividendDate']),
        earningsDate: earnDate,
        earningsIsEstimate: isEstimate,
      );
      _calendarCache[symbol] = _Cached(data, DateTime.now());
      return data;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Search & news
  // ---------------------------------------------------------------------------

  Future<List<SearchResult>> searchSymbols(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final r = await _get('/v1/finance/search',
        {'q': q, 'quotesCount': '10', 'newsCount': '0', 'listsCount': '0'});
    if (r == null) return const [];
    try {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final quotes = (body['quotes'] as List?) ?? const [];
      return quotes
          .whereType<Map<String, dynamic>>()
          .where((e) => (e['symbol'] as String? ?? '').isNotEmpty)
          .map((e) => SearchResult(
                symbol: e['symbol'] as String,
                name: (e['shortname'] ?? e['longname'] ?? e['symbol'] ?? '') as String,
                type: (e['typeDisp'] ?? e['quoteType']) as String?,
                exchange: (e['exchDisp'] ?? e['exchange']) as String?,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<NewsItem>> newsFor(String symbol) async {
    final c = _newsCache[symbol];
    if (c != null && c.fresh(_newsTtl)) return c.value;

    final r = await _get('/v1/finance/search',
        {'q': symbol, 'quotesCount': '1', 'newsCount': '12'});
    if (r == null) return const [];
    try {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final news = (body['news'] as List?) ?? const [];
      final symUpper = symbol.toUpperCase();
      final items = news
          .whereType<Map<String, dynamic>>()
          .where((e) {
            final related = (e['relatedTickers'] as List?) ?? const [];
            if (related.isEmpty) return true;
            return related
                .map((t) => t.toString().toUpperCase())
                .contains(symUpper);
          })
          .map((e) {
            final ts = (e['providerPublishTime'] as num?)?.toInt() ?? 0;
            return NewsItem(
              title: (e['title'] ?? '') as String,
              publisher: (e['publisher'] ?? '') as String,
              link: (e['link'] ?? '') as String,
              publishedAt: ts > 0
                  ? DateTime.fromMillisecondsSinceEpoch(ts * 1000)
                  : DateTime.now(),
              relatedTickers: [
                for (final t in ((e['relatedTickers'] as List?) ?? const [])) t.toString()
              ],
            );
          })
          .where((n) => n.title.isNotEmpty && n.link.isNotEmpty)
          .toList();
      _newsCache[symbol] = _Cached(items, DateTime.now());
      return items;
    } catch (_) {
      return const [];
    }
  }
}