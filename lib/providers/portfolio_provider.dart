import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../models/dividends.dart';
import '../models/holding.dart';
import '../models/portfolio.dart';
import '../models/quote.dart';
import '../services/csv_import.dart';
import '../services/store.dart';
import '../services/widget_service.dart';
import '../services/yahoo_service.dart';
import '../utils/formatters.dart';

/// Aggregate money stats for a portfolio (or all portfolios at once).
@immutable
class PortfolioTotals {
  final double marketValue;
  final double costBasis;
  final double dayChange;
  final bool hasDayChange;
  final double annualIncome;
  const PortfolioTotals({
    required this.marketValue,
    required this.costBasis,
    required this.dayChange,
    required this.hasDayChange,
    required this.annualIncome,
  });

  double get pnl => marketValue - costBasis;
  double get pnlPercent => costBasis > 0 ? pnl / costBasis * 100 : 0;
  double get dayChangePercent =>
      hasDayChange && (marketValue - dayChange) > 0 ? dayChange / (marketValue - dayChange) * 100 : 0;
  double get incomeYield => marketValue > 0 ? annualIncome / marketValue * 100 : 0;
  double get yieldOnCost => costBasis > 0 ? annualIncome / costBasis * 100 : 0;
}

/// Entry in the upcoming-events list: a dividend (ex or pay date) or earnings.
@immutable
class UpcomingEvent {
  final String symbol;
  final String kind; // 'dividend' | 'earnings'
  final DateTime date;
  final double? amountPerShare;
  final double? total;
  final bool estimated;
  final bool isPayDate;
  const UpcomingEvent({
    required this.symbol,
    required this.kind,
    required this.date,
    this.amountPerShare,
    this.total,
    required this.estimated,
    this.isPayDate = false,
  });
}

class PortfolioProvider extends ChangeNotifier {
  PortfolioProvider({YahooService? yahoo, StockPulseStore? store})
      : _yahoo = yahoo ?? YahooService(),
        _store = store ?? StockPulseStore();

  final YahooService _yahoo;
  final StockPulseStore _store;

  static const String _dataFile = 'stockpulse_data.json';
  static const String _cacheFile = 'stockpulse_cache.json';
  static const Duration _dividendTtl = Duration(hours: 24);

  List<Portfolio> _portfolios = [];
  int _activeIndex = 0;
  Map<String, Quote> _quotes = {};
  Map<String, DividendInfo> _dividendInfo = {};

  bool _loaded = false;
  bool _quotesLoading = false;
  bool _dividendsLoading = false;
  double _dividendsProgress = 0;
  String? _lastError;
  DateTime? _lastRefreshAt;
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoRefreshOnStart = true;

  final Map<String, _CachedHistory> _historyCache = {};
  final Map<String, Future<List<ChartPoint>>> _historyInflight = {};

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  bool get loaded => _loaded;
  List<Portfolio> get portfolios => List.unmodifiable(_portfolios);
  int get activeIndex => _activeIndex;
  int get portfolioCount => _portfolios.length;
  Portfolio? get activeOrNull =>
      _activeIndex >= 0 && _activeIndex < _portfolios.length ? _portfolios[_activeIndex] : null;
  Quote? quoteOf(String symbol) => _quotes[symbol];
  DividendInfo? dividendInfoOf(String symbol) => _dividendInfo[symbol];
  bool get quotesLoading => _quotesLoading;
  bool get dividendsLoading => _dividendsLoading;
  double get dividendsProgress => _dividendsProgress;
  String? get lastError => _lastError;
  DateTime? get lastRefreshAt => _lastRefreshAt;
  ThemeMode get themeMode => _themeMode;
  bool get autoRefreshOnStart => _autoRefreshOnStart;

  /// Portfolio shown in the UI - always resolves to a portfolio.
  Portfolio get active {
    if (_portfolios.isEmpty) {
      _portfolios = [Portfolio(id: _newId(), name: 'Main')];
      _activeIndex = 0;
    }
    if (_activeIndex >= _portfolios.length) _activeIndex = 0;
    return _portfolios[_activeIndex];
  }

  Portfolio? byId(String id) {
    for (final p in _portfolios) {
      if (p.id == id) return p;
    }
    return null;
  }

  Set<String> get allSymbols => {
        for (final p in _portfolios) ...p.holdings.keys,
      };

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    final data = await _store.load(_dataFile);
    if (data != null) {
      _portfolios = [
        for (final m in ((data['portfolios'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>())
          Portfolio.fromMap(m)
      ];
      _activeIndex = ((data['activeIndex'] as num?) ?? 0).toInt();
      _themeMode =
          ThemeMode.values[min(((data['themeMode'] as num?) ?? 0).toInt(), 2)];
      _autoRefreshOnStart = data['autoRefreshOnStart'] as bool? ?? true;
    }
    if (_portfolios.isEmpty) {
      _portfolios = [Portfolio(id: _newId(), name: 'Main')];
      _activeIndex = 0;
      await _persistData();
    } else if (_activeIndex >= _portfolios.length) {
      _activeIndex = 0;
    }

    final cache = await _store.load(_cacheFile);
    if (cache != null) {
      final quotes = (cache['quotes'] as Map<String, dynamic>?) ?? const {};
      _quotes = {
        for (final e in quotes.entries)
          if (e.value is Map<String, dynamic>)
            e.key: Quote.fromMap(e.value as Map<String, dynamic>),
      };
      final infos = (cache['dividendInfo'] as Map<String, dynamic>?) ?? const {};
      _dividendInfo = {
        for (final e in infos.entries)
          if (e.value is Map<String, dynamic>)
            e.key: _dividendInfoFromMap(e.key, e.value as Map<String, dynamic>),
      };
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persistData() async {
    await _store.save(_dataFile, {
      'version': 1,
      'portfolios': [for (final p in _portfolios) p.toMap()],
      'activeIndex': _activeIndex,
      'themeMode': _themeMode.index,
      'autoRefreshOnStart': _autoRefreshOnStart,
    });
  }

  Future<void> _persistCache() async {
    await _store.save(_cacheFile, {
      'version': 1,
      'quotes': {for (final e in _quotes.entries) e.key: e.value.toMap()},
      'dividendInfo': {
        for (final e in _dividendInfo.entries) e.key: _dividendInfoToMap(e.value),
      },
    });
  }

  Map<String, dynamic> _dividendInfoToMap(DividendInfo i) => {
        'payments': [for (final p in i.payments) p.toMap()],
        'exDividendDateMs': i.exDividendDate?.millisecondsSinceEpoch,
        'payDateMs': i.payDate?.millisecondsSinceEpoch,
        'cachedAt': i.cachedAt.toIso8601String(),
      };

  DividendInfo _dividendInfoFromMap(String symbol, Map<String, dynamic> m) {
    return DividendInfo(
      symbol: symbol,
      payments: [
        for (final p in ((m['payments'] as List?) ?? const []).whereType<Map<String, dynamic>>())
          DividendPayment.fromMap(p)
      ]..sort((a, b) => a.exDate.compareTo(b.exDate)),
      exDividendDate: _ms(m['exDividendDateMs']),
      payDate: _ms(m['payDateMs']),
      cachedAt: m['cachedAt'] == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : (DateTime.tryParse(m['cachedAt'] as String) ?? DateTime.now()),
    );
  }

  static DateTime? _ms(dynamic v) =>
      v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${Random().nextInt(1 << 30).toRadixString(36)}';

  void _replaceAt(int index, Portfolio p) {
    _portfolios[index] = p;
  }

  // ---------------------------------------------------------------------------
  // Portfolio & holding CRUD
  // ---------------------------------------------------------------------------

  void setActiveIndex(int index) {
    if (index < 0 || index >= _portfolios.length) return;
    _activeIndex = index;
    notifyListeners();
    _persistData();
  }

  void addPortfolio(String name) {
    _portfolios.add(
        Portfolio(id: _newId(), name: name.trim().isEmpty ? 'Portfolio' : name.trim()));
    _activeIndex = _portfolios.length - 1;
    notifyListeners();
    _persistData();
  }

  void renamePortfolio(String id, String name) {
    final i = _portfolios.indexWhere((p) => p.id == id);
    if (i < 0 || name.trim().isEmpty) return;
    _replaceAt(i, _portfolios[i].copyWith(name: name.trim()));
    notifyListeners();
    _persistData();
  }

  void deletePortfolio(String id) {
    if (_portfolios.length <= 1) return; // always keep at least one
    final i = _portfolios.indexWhere((p) => p.id == id);
    if (i < 0) return;
    _portfolios.removeAt(i);
    if (_activeIndex >= _portfolios.length) _activeIndex = _portfolios.length - 1;
    notifyListeners();
    _persistData();
    _pushWidget();
  }

  /// Adds or merges a holding. Returns an error string, or null on success.
  Future<String?> addHolding({
    required String portfolioId,
    required String symbol,
    required double quantity,
    required double avgCost,
  }) async {
    symbol = symbol.trim().toUpperCase();
    if (symbol.isEmpty) return 'Enter a symbol.';
    if (quantity <= 0) return 'Quantity must be greater than zero.';

    final index = _portfolios.indexWhere((p) => p.id == portfolioId);
    if (index < 0) return null;
    final p = _portfolios[index];

    if (_quotes[symbol] == null || _quotes[symbol]!.price <= 0) {
      final q = await _yahoo.quote(symbol);
      if (q == null || q.price <= 0) {
        return "Could not find '$symbol' on Yahoo Finance.";
      }
      _quotes[symbol] = q;
    }
    final quote = _quotes[symbol]!;
    final existing = p.holdings[symbol];
    final Holding updated;
    if (existing == null) {
      updated = Holding(
        symbol: symbol,
        name: quote.name,
        currency: quote.currency,
        quantity: quantity,
        avgCost: avgCost,
        addedAt: DateTime.now(),
      );
    } else {
      updated = existing
          .mergeWith(quantity, avgCost)
          .copyWith(
            name: existing.name.isEmpty ? quote.name : null,
            currency: quote.currency,
          );
    }
    final holdings = Map.of(p.holdings);
    holdings[symbol] = updated;
    _replaceAt(index, p.copyWith(holdings: holdings));
    notifyListeners();
    await _persistData();
    await _pushWidget();
    return null;
  }

  Future<void> updateHolding({
    required String portfolioId,
    required String symbol,
    required double quantity,
    required double avgCost,
  }) async {
    final index = _portfolios.indexWhere((p) => p.id == portfolioId);
    if (index < 0) return;
    final p = _portfolios[index];
    final s = symbol.toUpperCase();
    final existing = p.holdings[s];
    if (existing == null) return;
    final holdings = Map.of(p.holdings);
    holdings[s] = existing.copyWith(quantity: quantity, avgCost: avgCost);
    _replaceAt(index, p.copyWith(holdings: holdings));
    notifyListeners();
    await _persistData();
    await _pushWidget();
  }

  Future<void> removeHolding(String portfolioId, String symbol) async {
    final index = _portfolios.indexWhere((p) => p.id == portfolioId);
    if (index < 0) return;
    final p = _portfolios[index];
    final s = symbol.toUpperCase();
    if (!p.holdings.containsKey(s)) return;
    final holdings = Map.of(p.holdings)..remove(s);
    _replaceAt(index, p.copyWith(holdings: holdings));
    notifyListeners();
    await _persistData();
    await _pushWidget();
  }

  /// Applies a parsed CSV import to a portfolio. Returns the number of rows
  /// merged, or -1 when the portfolio was not found.
  Future<int> importHoldings({
    required String portfolioId,
    required List<ParsedHolding> parsed,
    bool replaceExisting = false,
  }) async {
    final index = _portfolios.indexWhere((p) => p.id == portfolioId);
    if (index < 0) return -1;

    if (replaceExisting) {
      _replaceAt(index, _portfolios[index].copyWith(holdings: {}));
    }

    // Batch-fetch quotes for symbols with nothing cached.
    final missing = {
      for (final h in parsed)
        if (!_quotes.containsKey(h.symbol.toUpperCase())) h.symbol.toUpperCase(),
    };
    if (missing.isNotEmpty) {
      final fetched = await _yahoo.quotes(missing);
      _quotes = Map.of(_quotes)..addAll(fetched);
    }

    final holdings = Map.of(_portfolios[index].holdings);
    var count = 0;
    for (final h in parsed) {
      final symbol = h.symbol.toUpperCase();
      final quote = _quotes[symbol];
      final name = (h.name != null && h.name!.isNotEmpty) ? h.name! : (quote?.name ?? '');
      final currency = quote?.currency ?? 'USD';
      final existing = holdings[symbol];
      if (existing == null) {
        holdings[symbol] = Holding(
          symbol: symbol,
          name: name,
          currency: currency,
          quantity: h.quantity,
          avgCost: h.avgCost ?? 0,
          addedAt: DateTime.now(),
        );
      } else {
        holdings[symbol] = existing.mergeWith(h.quantity, h.avgCost ?? 0);
      }
      count++;
    }
    _replaceAt(index, _portfolios[index].copyWith(holdings: holdings));
    notifyListeners();
    await _persistData();
    await _persistCache();
    await _pushWidget();
    return count;
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  Future<void> refreshQuotes({bool manual = true}) async {
    if (_quotesLoading) return;
    _quotesLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final symbols = allSymbols;
      if (symbols.isNotEmpty) {
        final fetched = await _yahoo.quotes(symbols);
        if (fetched.isNotEmpty) {
          _quotes = Map.of(_quotes)..addAll(fetched);
          _lastRefreshAt = DateTime.now();
          // Backfill names into holdings that were imported without them.
          for (var i = 0; i < _portfolios.length; i++) {
            var changed = false;
            final holdings = Map.of(_portfolios[i].holdings);
            for (final e in holdings.entries) {
              final q = _quotes[e.key];
              if (q != null && e.value.name.isEmpty && q.name.isNotEmpty) {
                holdings[e.key] = e.value.copyWith(name: q.name, currency: q.currency);
                changed = true;
              }
            }
            if (changed) _replaceAt(i, _portfolios[i].copyWith(holdings: holdings));
          }
        } else if (manual) {
          _lastError = 'Could not reach Yahoo Finance. Check your connection.';
        }
      } else {
        _lastRefreshAt = DateTime.now();
      }
    } catch (e) {
      _lastError = 'Refresh failed: $e';
    }
    _quotesLoading = false;
    notifyListeners();
    await _persistCache();
    await _pushWidget();
  }

  /// Fetches dividend data for all held symbols (24h cache per symbol).
  Future<void> ensureDividendInfo({bool force = false, Set<String>? symbolsIn}) async {
    if (_dividendsLoading) return;
    final symbols = symbolsIn ?? allSymbols;
    final need = <String>[
      for (final s in symbols)
        if (!_isDividendInfoFresh(s, force)) s,
    ];
    if (need.isEmpty) return;

    _dividendsLoading = true;
    _dividendsProgress = 0;
    notifyListeners();
    try {
      var done = 0;
      for (final s in need) {
        List<DividendPayment> payments;
        CalendarData? cal;
        try {
          payments = await _yahoo.dividendHistory(s);
        } catch (_) {
          payments = const [];
        }
        try {
          cal = await _yahoo.calendarEvents(s);
        } catch (_) {
          cal = null;
        }
        _dividendInfo[s] = DividendInfo(
          symbol: s,
          payments: payments,
          exDividendDate: cal?.exDividendDate,
          payDate: cal?.payDate,
          cachedAt: DateTime.now(),
        );
        done++;
        _dividendsProgress = done / need.length;
        notifyListeners();
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    } finally {
      _dividendsLoading = false;
      notifyListeners();
      await _persistCache();
      await _pushWidget();
    }
  }

  bool _isDividendInfoFresh(String symbol, bool force) {
    final info = _dividendInfo[symbol];
    if (info == null) return false;
    if (force) return false;
    return DateTime.now().difference(info.cachedAt) < _dividendTtl;
  }

  // ---------------------------------------------------------------------------
  // Computed values
  // ---------------------------------------------------------------------------

  PortfolioTotals totalsFor(Portfolio p) {
    var value = 0.0;
    var cost = 0.0;
    var day = 0.0;
    var income = 0.0;
    var hasDay = false;
    for (final h in p.holdings.values) {
      final q = _quotes[h.symbol];
      final price = q?.price ?? 0;
      value += price * h.quantity;
      cost += h.costBasis;
      final dc = q?.dayChange;
      if (dc != null) {
        day += dc * h.quantity;
        hasDay = true;
      }
      final info = _dividendInfo[h.symbol];
      final rate = info != null
          ? (info.ttmPerShare > 0 ? info.ttmPerShare : (q?.dividendRate ?? 0))
          : (q?.dividendRate ?? 0);
      income += rate * h.quantity;
    }
    return PortfolioTotals(
      marketValue: value,
      costBasis: cost,
      dayChange: day,
      hasDayChange: hasDay,
      annualIncome: income,
    );
  }

  PortfolioTotals totalsForAll() {
    var value = 0.0;
    var cost = 0.0;
    var day = 0.0;
    var income = 0.0;
    var hasDay = false;
    for (final p in _portfolios) {
      final t = totalsFor(p);
      value += t.marketValue;
      cost += t.costBasis;
      day += t.dayChange;
      income += t.annualIncome;
      hasDay |= t.hasDayChange;
    }
    return PortfolioTotals(
      marketValue: value,
      costBasis: cost,
      dayChange: day,
      hasDayChange: hasDay,
      annualIncome: income,
    );
  }

  /// Estimated or exact upcoming dividend for a holding (null = non-payer).
  UpcomingDividend? upcomingFor(String symbol, double quantity) {
    final info = _dividendInfo[symbol];
    final q = _quotes[symbol];
    final knownRate = (q?.dividendRate ?? 0) > 0 || (info != null && info.ttmPerShare > 0);
    if (!knownRate && (info == null || info.payments.isEmpty)) return null;

    final now = DateTime.now();
    final ttm = info == null ? 0.0 : info.ttmPerShare;
    final rate = ttm > 0 ? ttm : (q!.dividendRate!);
    final ppy = info == null ? 4 : max(info.periodsPerYear, 1);
    final amountPerShare =
        (info != null && info.lastAmount > 0) ? info.lastAmount : (rate / ppy);

    var estimated = true;
    DateTime ex;
    final exactEx = info?.exDividendDate;
    if (exactEx != null && exactEx.isAfter(now)) {
      ex = exactEx;
      estimated = false;
    } else {
      final gap = (info != null && info.medianGapDays > 0) ? info.medianGapDays : 91;
      var cand = (info != null && info.payments.isNotEmpty)
          ? info.payments.last.exDate.add(Duration(days: gap))
          : now.add(const Duration(days: 30));
      var guard = 0;
      while (cand.isBefore(now) && guard < 16) {
        cand = cand.add(Duration(days: gap));
        guard++;
      }
      if (cand.isBefore(now)) cand = now.add(Duration(days: gap));
      ex = cand;
    }

    var pay = info?.payDate;
    if (pay == null || pay.isBefore(ex)) {
      pay = ex.add(const Duration(days: 14));
    }
    return UpcomingDividend(
      symbol: symbol,
      quantity: quantity,
      exDate: ex,
      payDate: pay,
      amountPerShare: amountPerShare,
      estimated: estimated,
    );
  }

  /// Upcoming dividends for one portfolio within [horizonDays], sorted.
  List<UpcomingDividend> upcomingDividendsFor(Portfolio p, {int horizonDays = 120}) {
    final out = <UpcomingDividend>[];
    final limit = DateTime.now().add(Duration(days: horizonDays));
    for (final h in p.holdings.values) {
      final up = upcomingFor(h.symbol, h.quantity);
      if (up != null && !up.exDate.isAfter(limit)) out.add(up);
    }
    out.sort((a, b) => a.exDate.compareTo(b.exDate));
    return out;
  }

  /// Combined upcoming events (dividends + earnings) across portfolios.
  List<UpcomingEvent> upcomingEvents({int horizonDays = 120}) {
    return upcomingEventsFor(_portfolios.toList(), horizonDays: horizonDays);
  }

  List<UpcomingEvent> upcomingEventsFor(List<Portfolio> selected, {int horizonDays = 120}) {
    final out = <UpcomingEvent>[];
    final limit = DateTime.now().add(Duration(days: horizonDays));
    for (final p in selected) {
      for (final h in p.holdings.values) {
        final up = upcomingFor(h.symbol, h.quantity);
        if (up != null && !up.exDate.isAfter(limit)) {
          out.add(UpcomingEvent(
            symbol: up.symbol,
            kind: 'dividend',
            date: up.exDate,
            amountPerShare: up.amountPerShare,
            total: up.total,
            estimated: up.estimated,
          ));
          if (up.payDate != null &&
              up.payDate!.isAfter(up.exDate) &&
              !up.payDate!.isAfter(limit)) {
            out.add(UpcomingEvent(
              symbol: up.symbol,
              kind: 'dividend',
              date: up.payDate!,
              amountPerShare: up.amountPerShare,
              total: up.total,
              estimated: up.estimated,
              isPayDate: true,
            ));
          }
        }
        final earn = _quotes[h.symbol]?.earningsDate;
        if (earn != null && earn.isAfter(DateTime.now()) && !earn.isAfter(limit)) {
          out.add(UpcomingEvent(
              symbol: h.symbol, kind: 'earnings', date: earn, estimated: false));
        }
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// Next upcoming dividend across every portfolio (drives the widget).
  UpcomingDividend? nextUpcomingAcrossAll() {
    UpcomingDividend? best;
    for (final p in _portfolios) {
      for (final h in p.holdings.values) {
        final up = upcomingFor(h.symbol, h.quantity);
        if (up == null) continue;
        if (best == null || up.exDate.isBefore(best.exDate)) best = up;
      }
    }
    return best;
  }

  /// Income expected within the next [days] from upcoming dividends.
  double incomeWithinDays(int days) {
    var sum = 0.0;
    for (final e in upcomingEvents(horizonDays: days)) {
      if (e.kind == 'dividend' && !e.isPayDate) sum += e.total ?? 0;
    }
    return sum;
  }

  /// Per-symbol price history (delegates to the shared chart cache).
  Future<List<ChartPoint>> symbolHistory(String symbol, String range) async {
    final interval = range == '5y' ? '1wk' : '1d';
    try {
      final h = await _yahoo.chartHistory(symbol, range: range, interval: interval);
      if (h == null) return const [];
      // Drop the live (incomplete) last bar for stable charts.
      final pts = h.points;
      return pts.length > 1 ? pts.sublist(0, pts.length - 1) : pts;
    } catch (_) {
      return const [];
    }
  }

  /// Portfolio value history merged from every holding's chart.
  Future<List<ChartPoint>> portfolioHistory(String portfolioId, String range) async {
    final key = '$portfolioId|$range';
    final cached = _historyCache[key];
    if (cached != null && cached.fresh) return cached.points;
    final inflight = _historyInflight[key];
    if (inflight != null) return inflight;

    final future = _buildHistory(portfolioId, range);
    _historyInflight[key] = future;
    try {
      final points = await future;
      _historyCache[key] = _CachedHistory(points);
      return points;
    } finally {
      _historyInflight.remove(key);
    }
  }

  Future<List<ChartPoint>> _buildHistory(String portfolioId, String range) async {
    final p = byId(portfolioId);
    if (p == null || p.holdings.isEmpty) return [];
    final interval = range == '5y' ? '1wk' : '1d';

    final series = <String, List<ChartPoint>>{};
    for (final symbol in p.symbols) {
      try {
        final h = await _yahoo.chartHistory(symbol, range: range, interval: interval);
        if (h == null || h.points.isEmpty) continue;
        // Drop the live (incomplete) last bar to keep history stable.
        series[symbol] = h.points.length > 1 ? h.points.sublist(0, h.points.length - 1) : h.points;
      } catch (_) {
        // symbol skipped
      }
    }
    if (series.isEmpty) return [];

    final union = <int>{
      for (final pts in series.values) ...[for (final pt in pts) pt.time.millisecondsSinceEpoch],
    }.toList()
      ..sort();

    final pointers = {for (final k in series.keys) k: 0};
    final out = <ChartPoint>[];
    for (final tMs in union) {
      var total = 0.0;
      for (final e in series.entries) {
        final symbol = e.key;
        final pts = e.value;
        var i = pointers[symbol]!;
        while (i < pts.length && pts[i].time.millisecondsSinceEpoch <= tMs) {
          i++;
        }
        pointers[symbol] = i;
        if (i == 0) continue; // symbol not trading yet at this timestamp
        total += (p.holdings[symbol]?.quantity ?? 0) * pts[i - 1].close;
      }
      out.add(ChartPoint(DateTime.fromMillisecondsSinceEpoch(tMs), total));
    }

    // Trim leading zeros (before the position existed).
    while (out.isNotEmpty && out.first.close <= 0) {
      out.removeAt(0);
    }
    return out;
  }

  /// Upcoming earnings across all held symbols (sorted).
  List<UpcomingEarnings> upcomingEarnings({int horizonDays = 180}) {
    final out = <UpcomingEarnings>[];
    final limit = DateTime.now().add(Duration(days: horizonDays));
    for (final s in allSymbols) {
      final q = _quotes[s];
      final earn = q?.earningsDate;
      if (earn != null && earn.isAfter(DateTime.now()) && !earn.isAfter(limit)) {
        out.add(UpcomingEarnings(symbol: s, date: earn, estimate: q!.earningsIsEstimate));
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  // ---------------------------------------------------------------------------
  // Settings & export
  // ---------------------------------------------------------------------------

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _persistData();
  }

  Future<void> setAutoRefreshOnStart(bool v) async {
    _autoRefreshOnStart = v;
    notifyListeners();
    await _persistData();
  }

  Map<String, dynamic> exportBackup() {
    return {
      'app': 'Stock Pulse',
      'backupVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'activeIndex': _activeIndex,
      'themeMode': _themeMode.index,
      'portfolios': [for (final p in _portfolios) p.toMap()],
    };
  }

  Future<bool> restoreBackup(Map<String, dynamic> data) async {
    final list = (data['portfolios'] as List?) ?? const [];
    final parsed = [
      for (final m in list.whereType<Map<String, dynamic>>()) Portfolio.fromMap(m)
    ];
    if (parsed.isEmpty) return false;
    _portfolios = parsed;
    _activeIndex = ((data['activeIndex'] as num?) ?? 0).toInt().clamp(0, parsed.length - 1);
    _loaded = true;
    notifyListeners();
    await _persistData();
    await refreshQuotes(manual: false);
    await ensureDividendInfo(force: true);
    return true;
  }

  /// CSV rows for a portfolio: header + one row per holding.
  List<List<String>> holdingsCsvRows(Portfolio p) {
    final rows = <List<String>>[
      ['symbol', 'name', 'quantity', 'avgCost', 'currency'],
    ];
    for (final h in p.holdings.values) {
      rows.add([h.symbol, h.name, _num(h.quantity), _num(h.avgCost), h.currency]);
    }
    return rows;
  }

  static String _num(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '');
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Future<void> pushWidgets() => _pushWidget();

  Future<void> _pushWidget() async {
    if (!StockPulseWidgetService.supported) return;
    final t = totalsForAll();
    final currency = _dominantCurrency();
    final total = fmtMoney(t.marketValue, currency: currency);
    final change = t.hasDayChange
        ? '${fmtSignedMoney(t.dayChange, currency: currency)} (${fmtPct(t.dayChangePercent)})'
        : '';
    final sign = t.hasDayChange ? (t.dayChange > 0 ? 1 : (t.dayChange < 0 ? -1 : 0)) : 0;

    final next = nextUpcomingAcrossAll();
    String nd1;
    String nd2;
    if (next == null) {
      nd1 = 'No upcoming dividends';
      nd2 = '';
    } else {
      nd1 = '${next.symbol} ${fmtMoney(next.amountPerShare, currency: currency)}/share';
      nd2 = '${next.estimated ? 'Est. ' : ''}ex ${fmtShortDate(next.exDate)}'
          ' | pays ${fmtShortDate(next.payDate)}';
    }

    await StockPulseWidgetService.push(
      total: total,
      change: change,
      changeSign: sign,
      nextDividendLine1: nd1,
      nextDividendLine2: nd2,
    );
  }

  String _dominantCurrency() {
    final counts = <String, int>{};
    for (final p in _portfolios) {
      for (final h in p.holdings.values) {
        counts[h.currency] = (counts[h.currency] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return 'USD';
    var best = 'USD';
    var bestN = -1;
    counts.forEach((k, v) {
      if (v > bestN) {
        best = k;
        bestN = v;
      }
    });
    return best;
  }

  /// Called once at app start: load, refresh quotes, seed dividends.
  Future<void> warmStart() async {
    if (!_loaded) await load();
    if (_autoRefreshOnStart || _quotes.isEmpty) {
      await refreshQuotes(manual: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Yahoo pass-throughs for screens (search, news)
  // ---------------------------------------------------------------------------

  Future<List<SearchResult>> searchSymbols(String query) => _yahoo.searchSymbols(query);

  Future<List<NewsItem>> newsFor(String symbol) => _yahoo.newsFor(symbol);

  /// Aggregated news across every held symbol (deduped, newest first).
  /// Uses per-symbol caches (15 min) inside [YahooService].
  Future<List<NewsItem>> newsForAllHoldings() async {
    final symbols = allSymbols;
    if (symbols.isEmpty) return const [];
    final all = <NewsItem>[];
    for (final s in symbols) {
      try {
        final items = await _yahoo.newsFor(s);
        all.addAll(items);
      } catch (_) {
        // skip symbol
      }
    }
    final seen = <String>{};
    final out = <NewsItem>[];
    for (final n in all) {
      if (seen.add(n.link)) out.add(n);
    }
    out.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return out;
  }
}

/// One row in the upcoming earnings strip.
@immutable
class UpcomingEarnings {
  final String symbol;
  final DateTime date;
  final bool estimate;
  const UpcomingEarnings({required this.symbol, required this.date, required this.estimate});
}

class _CachedHistory {
  final List<ChartPoint> points;
  final DateTime at;
  _CachedHistory(this.points) : at = DateTime.now();
  bool get fresh => DateTime.now().difference(at) < const Duration(minutes: 5);
}