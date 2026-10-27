import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../theme/app_theme.dart';

import '../models/dividends.dart';
import '../models/holding.dart';
import '../models/portfolio.dart';
import '../models/quote.dart';
import '../models/transaction.dart';
import '../services/csv_import.dart';
import '../services/ledger.dart' as ledger;
import '../services/store.dart';
import '../services/diagnostics.dart';
import '../services/widget_service.dart';
import '../services/yahoo_service.dart';
import '../utils/formatters.dart';
import '../utils/market_identity.dart';

/// Aggregate money stats for a portfolio (or all portfolios at once).
@immutable
class PortfolioTotals {
  final double marketValue;
  final double costBasis;
  final double dayChange;
  final bool hasDayChange;
  final double annualIncome;
  final bool converted;
  final String? displayCurrency;
  const PortfolioTotals({
    required this.marketValue,
    required this.costBasis,
    required this.dayChange,
    required this.hasDayChange,
    required this.annualIncome,
    this.converted = false,
    this.displayCurrency,
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
  static const Duration _sparkTtl = Duration(minutes: 10);

  List<Portfolio> _portfolios = [];
  int _activeIndex = 0;
  Map<String, Quote> _quotes = {};
  Map<String, DividendInfo> _dividendInfo = {};
  String _displayCurrency = '';
  final Map<String, double> _fxRates = {}; // 'CADUSD' -> rate
  bool _fxLoading = false;
  DateTime? _fxLastAttempt;

  /// How long to wait before retrying a failed FX lookup.
  static const Duration _fxRetryCooldown = Duration(minutes: 5);
  bool _notifyDividends = true;
  bool _notifyEarnings = true;
  double _priceAlertPct = 0; // 0 = off
  bool _lockEnabled = false;
  String _gistId = '';
  String _gistToken = '';
  DateTime? _lastSyncAt;
  String _webProxyUrl = '';

  bool _loaded = false;
  bool _quotesLoading = false;
  bool _dividendsLoading = false;
  double _dividendsProgress = 0;
  String? _lastError;
  DateTime? _lastRefreshAt;
  AppThemeId _themeMode = AppThemeId.system;
  int _accentIndex = 0;
  bool _autoRefreshOnStart = true;
  bool _onboardingComplete = false;
  bool _crashDiagnostics = false;
  DateTime? _lastBackupReminderAt;

  final Map<String, _CachedHistory> _historyCache = {};
  final Map<String, Future<List<ChartPoint>>> _historyInflight = {};

  /// Short trend lines shown next to holdings.
  final Map<String, _CachedSparkline> _sparkCache = {};
  final Map<String, Future<List<double>>> _sparkInflight = {};

  /// Sector / industry per symbol, filled in on demand.
  final Map<String, CompanyProfile> _profiles = {};
  bool _profilesLoading = false;

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
  AppThemeId get themeMode => _themeMode;
  int get accentIndex => _accentIndex.clamp(0, AppTheme.accents.length - 1);
  bool get autoRefreshOnStart => _autoRefreshOnStart;
  bool get showsOnboarding => _onboardingComplete;
  bool get crashDiagnostics => _crashDiagnostics;
  bool get backupReminderDue {
    if (_portfolios.every((p) => p.holdings.isEmpty)) return false;
    final at = _lastBackupReminderAt;
    return at == null || DateTime.now().difference(at) >= const Duration(days: 30);
  }
  String get displayCurrency => _displayCurrency;
  bool get fxLoading => _fxLoading;
  bool get converting => _displayCurrency.isNotEmpty;

  /// Whether every currency used by the holdings has a rate into the
  /// display currency.
  ///
  /// When this is false the totals are still shown, but in the native
  /// currencies, and the UI says so rather than silently mixing them.
  bool get fxRatesReady {
    if (_displayCurrency.isEmpty) return true;
    for (final p in _portfolios) {
      for (final h in p.holdings.values) {
        final c = h.currency.toUpperCase();
        if (c.isEmpty || c == _displayCurrency) continue;
        if ((_fxRates['$c$_displayCurrency'] ?? 0) <= 0) return false;
      }
    }
    return true;
  }
  bool get notifyDividends => _notifyDividends;
  bool get notifyEarnings => _notifyEarnings;
  double get priceAlertPct => _priceAlertPct;
  bool get lockEnabled => _lockEnabled;
  String get gistId => _gistId;
  String get gistToken => _gistToken;
  DateTime? get lastSyncAt => _lastSyncAt;

  bool get hasSyncConfig => _gistId.isNotEmpty && _gistToken.isNotEmpty;

  String get webProxyUrl => _webProxyUrl;

  Future<void> setWebProxyUrl(String url) async {
    _webProxyUrl = url.trim();
    YahooService.webProxyBase = _webProxyUrl;
    notifyListeners();
    await _persistData();
    await refreshQuotes();
  }

  Future<void> configureSync({required String token, String? gistId}) async {
    _gistToken = token.trim();
    if (gistId != null && gistId.trim().isNotEmpty) _gistId = gistId.trim();
    notifyListeners();
    await _persistData();
  }

  Future<void> setGistCreated(String id) async {
    _gistId = id.trim();
    notifyListeners();
    await _persistData();
  }

  Future<void> setLastSyncAt(DateTime t) async {
    _lastSyncAt = t;
    notifyListeners();
    await _persistData();
  }

  Future<void> setLockEnabled(bool v) async {
    _lockEnabled = v;
    notifyListeners();
    await _persistData();
  }

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    notifyListeners();
    await _persistData();
  }

  Future<void> setCrashDiagnostics(bool v) async {
    _crashDiagnostics = v;
    Diagnostics.setEnabled(v);
    notifyListeners();
    await _persistData();
  }

  Future<void> markBackupReminderShown() async {
    _lastBackupReminderAt = DateTime.now();
    notifyListeners();
    await _persistData();
  }

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
      _themeMode = AppThemeId.values[
          min(((data['themeMode'] as num?) ?? 0).toInt(), AppThemeId.values.length - 1)];
      _accentIndex = ((data['accentIndex'] as num?) ?? 0).toInt()
          .clamp(0, AppTheme.accents.length - 1);
      _autoRefreshOnStart = data['autoRefreshOnStart'] as bool? ?? true;
      _displayCurrency =
          (data['displayCurrency']?.toString() ?? '').trim().toUpperCase();
      _notifyDividends = data['notifyDividends'] as bool? ?? true;
      _notifyEarnings = data['notifyEarnings'] as bool? ?? true;
      _priceAlertPct = (data['priceAlertPct'] as num? ?? 0).toDouble();
      _lockEnabled = data['lockEnabled'] as bool? ?? false;
      _onboardingComplete = data['onboardingComplete'] as bool? ?? false;
      Diagnostics.setEnabled(data['crashDiagnostics'] as bool? ?? false);
      _crashDiagnostics = data['crashDiagnostics'] as bool? ?? false;
      _lastBackupReminderAt = _ms(data['lastBackupReminderMs']);
      _gistId = data['gistId']?.toString() ?? '';
      _gistToken = data['gistToken']?.toString() ?? '';
      _lastSyncAt = _ms(data['lastSyncMs']);
      _webProxyUrl = data['webProxyUrl']?.toString() ?? '';
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
    if (_portfolios.every((p) => p.holdings.isEmpty)) _seedSamplePortfolio();
    YahooService.webProxyBase = _webProxyUrl;
    notifyListeners();
  }

  void _seedSamplePortfolio() {
    final now = DateTime.now();
    // Illustrative positions across several exchanges so the market grouping
    // has something to show. Prices for these symbols are live quotes; the
    // quantities and cost bases are made up.
    final samples = {
      'SCHD': const Holding(symbol: 'SCHD', name: 'Schwab U.S. Dividend Equity ETF', quantity: 18, avgCost: 76.40),
      'AAPL': const Holding(symbol: 'AAPL', name: 'Apple Inc.', quantity: 6, avgCost: 182.25),
      'MSFT': const Holding(symbol: 'MSFT', name: 'Microsoft', quantity: 3, avgCost: 410.10),
      'V': const Holding(symbol: 'V', name: 'Visa', quantity: 4, avgCost: 252.30),
      'O': const Holding(symbol: 'O', name: 'Realty Income', quantity: 12, avgCost: 55.85),
      'RY.TO': const Holding(symbol: 'RY.TO', name: 'Royal Bank of Canada', quantity: 8, avgCost: 78.40),
      'ENB.TO': const Holding(symbol: 'ENB.TO', name: 'Enbridge', quantity: 15, avgCost: 52.10),
      'BTC-USD': const Holding(symbol: 'BTC-USD', name: 'Bitcoin', quantity: 0.035, avgCost: 62000),
    };
    _portfolios = [
      Portfolio(id: _newId(), name: 'Sample portfolio', holdings: {
        for (final e in samples.entries) e.key: e.value.copyWith(addedAt: now),
      }),
    ];
    _activeIndex = 0;
    unawaited(refreshQuotes());
    unawaited(ensureDividendInfo());
  }

  Future<void> _persistData() async {
    await _store.save(_dataFile, {
      'version': 1,
      'portfolios': [for (final p in _portfolios) p.toMap()],
      'activeIndex': _activeIndex,
      'themeMode': _themeMode.index,
      'accentIndex': _accentIndex,
      'autoRefreshOnStart': _autoRefreshOnStart,
      'onboardingComplete': _onboardingComplete,
      'crashDiagnostics': _crashDiagnostics,
      'lastBackupReminderMs': _lastBackupReminderAt?.millisecondsSinceEpoch,
      'displayCurrency': _displayCurrency,
      'notifyDividends': _notifyDividends,
      'notifyEarnings': _notifyEarnings,
      'priceAlertPct': _priceAlertPct,
      'lockEnabled': _lockEnabled,
      'gistId': _gistId,
      'gistToken': _gistToken,
      'lastSyncMs': _lastSyncAt?.millisecondsSinceEpoch,
      'webProxyUrl': _webProxyUrl,
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
        'splits': [
          for (final s in i.splits)
            {'dateMs': s.date.millisecondsSinceEpoch, 'n': s.numerator, 'd': s.denominator},
        ],
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
      splits: [
        for (final s in ((m['splits'] as List?) ?? const []))
          if (s is Map<String, dynamic>)
            StockSplit(
              date: DateTime.fromMillisecondsSinceEpoch(((s['dateMs'] as num?) ?? 0).toInt()),
              numerator: ((s['n'] as num?) ?? 1).toInt(),
              denominator: ((s['d'] as num?) ?? 1).toInt(),
            ),
      ]..sort((a, b) => a.date.compareTo(b.date)),
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
    final transactions = Map.of(p.transactions);
    transactions[symbol] = [
      ...p.txnsFor(symbol),
      Txn(
        kind: 'buy',
        quantity: quantity,
        unitPrice: avgCost > 0 ? avgCost : quote.price,
        date: DateTime.now(),
        note: existing == null ? 'Added holding' : 'Added units',
      ),
    ];
    _replaceAt(index, p.copyWith(holdings: holdings, transactions: transactions));
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

  /// Sells (part or all of) a position and records the trade. Returns an
  /// error string, or null on success.
  Future<String?> sellHolding({
    required String portfolioId,
    required String symbol,
    required double quantity,
    required double unitPrice,
    double fee = 0,
  }) async {
    final index = _portfolios.indexWhere((p) => p.id == portfolioId);
    if (index < 0) return null;
    final p = _portfolios[index];
    final s = symbol.toUpperCase();
    final h = p.holdings[s];
    if (h == null) return 'Position not found.';
    if (quantity <= 0) return 'Quantity must be greater than zero.';
    if (quantity > h.quantity + 0.0000001) {
      return 'You only own ${fmtQty(h.quantity)} ${h.symbol}.';
    }

    final newQty = h.quantity - quantity;
    final holdings = Map.of(p.holdings);
    if (newQty <= 0.0000001) {
      holdings.remove(s);
    } else {
      holdings[s] = h.copyWith(quantity: newQty);
    }
    final transactions = Map.of(p.transactions);
    transactions[s] = [
      ...p.txnsFor(s),
      Txn(
        kind: 'sell',
        quantity: quantity,
        unitPrice: unitPrice,
        fee: fee,
        date: DateTime.now(),
        note: newQty <= 0.0000001 ? 'Closed position' : 'Partial sale',
      ),
    ];
    _replaceAt(index, p.copyWith(holdings: holdings, transactions: transactions));
    notifyListeners();
    await _persistData();
    await _pushWidget();
    return null;
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
    final transactions = Map.of(_portfolios[index].transactions);
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
      transactions[symbol] = [
        ...transactions[symbol] ?? const <Txn>[],
        Txn(
          kind: 'buy',
          quantity: h.quantity,
          unitPrice: (h.avgCost != null && h.avgCost! > 0)
              ? h.avgCost!
              : (quote?.price ?? 0),
          date: DateTime.now(),
          note: 'CSV import${(h.avgCost != null && h.avgCost! <= 0) ? ' (cost from market price)' : ''}',
        ),
      ];
      count++;
    }
    _replaceAt(index,
        _portfolios[index].copyWith(holdings: holdings, transactions: transactions));
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
    await ensureFxRates();
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
        List<StockSplit> splits;
        try {
          final hist = await _yahoo.chartHistory(s, range: '2y', interval: '1d');
          splits = hist?.splits ?? const [];
        } catch (_) {
          splits = const [];
        }
        try {
          cal = await _yahoo.calendarEvents(s);
        } catch (_) {
          cal = null;
        }
        _dividendInfo[s] = DividendInfo(
          symbol: s,
          payments: payments,
          splits: splits,
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
    final display = _displayCurrency;
    final converting = display.isNotEmpty;

    double rateOf(String currency) {
      if (currency.isEmpty || !converting || currency == display) return 1;
      return _fxRates['${currency.toUpperCase()}$display'] ?? 0;
    }

    // Conversion only kicks in once every needed FX rate has arrived.
    final needed = p.holdings.values.map((h) => h.currency).toSet().toList();
    final allReady = !converting || needed.every((c) => rateOf(c) > 0);
    final effectiveConvert = converting && allReady;

    var value = 0.0;
    var cost = 0.0;
    var day = 0.0;
    var income = 0.0;
    var hasDay = false;
    for (final h in p.holdings.values) {
      final q = _quotes[h.symbol];
      final price = q?.price ?? 0;
      final fx = effectiveConvert ? rateOf(h.currency) : 1.0;
      value += price * h.quantity * fx;
      cost += h.costBasis * fx;
      final dc = q?.dayChange;
      if (dc != null) {
        day += dc * h.quantity * fx;
        hasDay = true;
      }
      final info = _dividendInfo[h.symbol];
      final rate = info != null
          ? (info.ttmPerShare > 0 ? info.ttmPerShare : (q?.dividendRate ?? 0))
          : (q?.dividendRate ?? 0);
      income += rate * h.quantity * fx;
    }

    // Kick off the FX fetch so the next frame can show converted values.
    if (converting && !allReady) ensureFxRates();

    return PortfolioTotals(
      marketValue: value,
      costBasis: cost,
      dayChange: day,
      hasDayChange: hasDay,
      annualIncome: income,
      converted: effectiveConvert,
      displayCurrency: effectiveConvert ? display : null,
    );
  }

  /// Fetches FX conversion rates (Yahoo `[FROM][TO]=X` pairs) for every
  /// portfolio currency into the chosen display currency (one cached quote
  /// per pair).
  Future<void> ensureFxRates({bool force = false}) async {
    if (_displayCurrency.isEmpty || _fxLoading) return;

    // A failed lookup must not turn into a hot retry loop, because the
    // totals rebuild on every frame.
    final now = DateTime.now();
    if (!force &&
        _fxLastAttempt != null &&
        now.difference(_fxLastAttempt!) < _fxRetryCooldown) {
      return;
    }

    final froms = {
      for (final p in _portfolios) ...[
        for (final h in p.holdings.values) h.currency.toUpperCase(),
      ]
    }..removeWhere((c) => c.isEmpty || c == _displayCurrency);

    final need = [
      for (final f in froms)
        if (force || !_fxRates.containsKey('$f$_displayCurrency')) f,
    ];
    if (need.isEmpty) return;

    _fxLoading = true;
    _fxLastAttempt = now;
    notifyListeners();
    try {
      final pairs = {
        for (final f in need) '$f$_displayCurrency=X',
      };
      final quotes = await _yahoo.quotes(pairs);
      for (final f in need) {
        final q = quotes['$f$_displayCurrency=X'];
        if (q != null && q.price > 0) {
          _fxRates['$f$_displayCurrency'] = q.price;
        }
      }
    } catch (_) {
      // rates stay missing; totals fall back to native currencies
    } finally {
      _fxLoading = false;
      notifyListeners();
    }
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

  /// A short recent trend for a symbol, used for the inline sparklines.
  ///
  /// Shares the chart cache with [symbolHistory], so the extra request is
  /// made at most once every few minutes per symbol.
  Future<List<double>> symbolSparkline(String symbol) async {
    final cached = _sparkCache[symbol];
    if (cached != null && DateTime.now().difference(cached.at) < _sparkTtl) {
      return cached.points;
    }
    final inflight = _sparkInflight[symbol];
    if (inflight != null) return inflight;

    final future = _loadSparkline(symbol);
    _sparkInflight[symbol] = future;
    try {
      final points = await future;
      _sparkCache[symbol] = _CachedSparkline(points);
      return points;
    } finally {
      _sparkInflight.remove(symbol);
    }
  }

  Future<List<double>> _loadSparkline(String symbol) async {
    try {
      final h = await _yahoo.chartHistory(symbol, range: '1mo', interval: '1d');
      if (h == null || h.points.length < 2) return const [];
      // Drop the live bar so the sparkline does not wobble between refreshes.
      final pts = h.points;
      final stable = pts.length > 1 ? pts.sublist(0, pts.length - 1) : pts;
      return [for (final p in stable) p.close];
    } catch (_) {
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Company profiles (sector / industry)
  // ---------------------------------------------------------------------------

  /// Fetches the sector and industry for the given symbols.
  ///
  /// Yahoo only answers one symbol per request, so this runs in small
  /// batches with a pause between them. Results are cached inside the
  /// service for a week.
  Future<void> ensureProfiles(Set<String> symbols) async {
    if (_profilesLoading) return;
    final wanted = symbols
        .map((s) => s.toUpperCase())
        .where((s) => s.isNotEmpty && !_profiles.containsKey(s))
        .toSet()
        .toList();
    if (wanted.isEmpty) return;

    _profilesLoading = true;
    try {
      const batchSize = 3;
      for (var i = 0; i < wanted.length; i += batchSize) {
        final batch = wanted.skip(i).take(batchSize).toList();
        final results = await Future.wait([
          for (final symbol in batch)
            _yahoo.companyProfile(symbol).catchError((_) => null),
        ]);
        for (final profile in results) {
          if (profile != null) _profiles[profile.symbol] = profile;
        }
        notifyListeners();
        if (i + batchSize < wanted.length) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
    } finally {
      _profilesLoading = false;
      notifyListeners();
    }
  }

  /// The cached company profile for a symbol, if one has been fetched.
  CompanyProfile? profileOf(String symbol) => _profiles[symbol.toUpperCase()];

  /// The industry Yahoo reports for a symbol ('Other' when unknown).
  String industryOf(String symbol) =>
      _profiles[symbol.toUpperCase()]?.industryLabel ?? 'Other';

  /// The industry for a symbol, falling back to its type when Yahoo does
  /// not describe one (funds, crypto).
  String _industryKey(String symbol) {
    final industry = industryOf(symbol);
    if (industry != 'Other') return industry;
    return typeLabelOf(symbol);
  }

  /// The sector Yahoo reports for a symbol ('Other' when unknown).
  String sectorOf(String symbol) =>
      _profiles[symbol.toUpperCase()]?.sectorLabel ?? 'Other';

  /// True while sector/industry data is still being fetched.
  bool get profilesLoading => _profilesLoading;

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

  /// Latest StockSplit that happened after the position was created, if any.
  /// Returns null when up-to-date (nothing to fix).
  StockSplit? splitSuggestionFor(Holding h) {
    final info = _dividendInfo[h.symbol];
    if (info == null || info.splits.isEmpty) return null;
    final start = h.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    StockSplit? latest;
    for (final s in info.splits) {
      if (s.date.isAfter(start) && (latest == null || s.date.isAfter(latest.date))) {
        latest = s;
      }
    }
    return latest;
  }

  /// Applies the suggested split to quantity (multiplied) and average cost
  /// (divided).
  Future<void> applySplit({required String portfolioId, required String symbol}) async {
    final p = byId(portfolioId);
    final h = p?.holdings[symbol.toUpperCase()];
    if (p == null || h == null) return;
    final split = splitSuggestionFor(h);
    if (split == null) return;
    await updateHolding(
      portfolioId: portfolioId,
      symbol: h.symbol,
      quantity: h.quantity * split.multiplier,
      avgCost: h.avgCost / split.multiplier,
    );
  }

  /// Recorded transaction list for a symbol (newest handled by caller).
  List<Txn> transactionsFor(Portfolio p, String symbol) => p.txnsFor(symbol);

  /// Dividend cash actually collected for a holding (uses txn timeline).
  double dividendsReceivedFor(Portfolio p, Holding h) => ledger.dividendsReceived(
        txns: p.txnsFor(h.symbol),
        payments: _dividendInfo[h.symbol]?.payments ?? const [],
        currentQty: h.quantity,
        holdingStart: h.addedAt,
      );

  /// Realized P/L from the transaction history, or null when the history is
  /// incomplete (no recorded buys).
  double? realizedPnlFor(Portfolio p, String symbol) =>
      ledger.replayRealizedPnl(p.txnsFor(symbol));

  /// 5-year projected dividend income with reinvested payments (DRIP).
  double dripProjectionFor(Portfolio p) {
    final t = totalsFor(p);
    return ledger.dripProjection(t.annualIncome, t.incomeYield);
  }

  // ---------------------------------------------------------------------------
  // Analysis (allocation, growth, benchmark)
  // ---------------------------------------------------------------------------

  static const String benchmarkSymbol = 'SPY';

  /// FX rate into the display currency (1.0 when not converting).
  double _fxRateFor(String currency) {
    if (_displayCurrency.isEmpty) return 1;
    if (currency.isEmpty || currency == _displayCurrency) return 1;
    return _fxRates['${currency.toUpperCase()}$_displayCurrency'] ?? 0;
  }

  /// SPY closes for the same range (for the benchmark overlay).
  Future<List<ChartPoint>?> benchmarkHistory(String range) async {
    try {
      final h = await _yahoo.chartHistory(benchmarkSymbol,
          range: range, interval: range == '5y' ? '1wk' : '1d');
      if (h == null || h.points.length < 2) return null;
      final pts = h.points;
      return pts.sublist(0, pts.length - 1); // drop the live bar
    } catch (_) {
      return null;
    }
  }

  /// Per-share YoY dividend growth in percent (null if not computable).
  double? dividendGrowthFor(String symbol) {
    final info = _dividendInfo[symbol];
    if (info == null || info.payments.isEmpty) return null;
    return ledger.dividendGrowthPct(info.payments);
  }

  /// Growth rows for the dividends screen: symbol, growth %, TTM income total.
  List<({String symbol, double? growthPct, double ttmIncome})> dividendGrowthRows(Portfolio p) {
    final out = <({String symbol, double? growthPct, double ttmIncome})>[];
    for (final h in p.holdings.values) {
      final info = _dividendInfo[h.symbol];
      if (info == null || info.payments.isEmpty) continue;
      out.add((
        symbol: h.symbol,
        growthPct: ledger.dividendGrowthPct(info.payments),
        ttmIncome: info.ttmPerShare * h.quantity,
      ));
    }
    out.sort((a, b) {
      final ga = a.growthPct ?? -999999;
      final gb = b.growthPct ?? -999999;
      return gb.compareTo(ga);
    });
    return out;
  }

  /// Portfolio dividend income per calendar year (current quantities,
  /// FX-converted when available - approximate).
  double dailyDividendRateFor(Portfolio p) => totalsFor(p).annualIncome / 365.0;
  double monthlyDividendRateFor(Portfolio p) => totalsFor(p).annualIncome / 12.0;
  double quarterlyDividendRateFor(Portfolio p) => totalsFor(p).annualIncome / 4.0;

  Map<int, double> annualIncomeByYearFor(Portfolio p) {
    final byYear = <int, double>{};
    for (final h in p.holdings.values) {
      final info = _dividendInfo[h.symbol];
      if (info == null) continue;
      final fx = _fxRateFor(h.currency);
      if (fx == 0) continue;
      ledger.dividendYearTotals(info.payments).forEach((year, perShare) {
        byYear[year] = (byYear[year] ?? 0) + perShare * h.quantity * fx;
      });
    }
    return byYear;
  }

  /// Allocation slices for the donut chart.
  ///
  /// [by] is one of 'type', 'currency', 'industry' or 'sector'. Values are
  /// FX-converted when a display currency is active.
  List<AllocationSlice> allocationFor(Portfolio p, {required String by}) {
    final display = _displayCurrency;
    final converting = display.isNotEmpty;
    final currencies = p.holdings.values.map((h) => h.currency).toSet();
    final ready = !converting ||
        currencies
            .every((c) => c == display || (_fxRates['${c.toUpperCase()}$display'] ?? 0) > 0);

    final groups = <String, double>{};
    for (final h in p.holdings.values) {
      final q = _quotes[h.symbol];
      final fx = converting && ready ? (_fxRateFor(h.currency) == 0 ? 1 : _fxRateFor(h.currency)) : 1.0;
      final value = (q?.price ?? 0) * h.quantity * fx;
      final key = switch (by) {
        'type' => typeLabelOf(h.symbol),
        'currency' => h.currency,
        // Instruments Yahoo does not describe an industry for (funds,
        // crypto) fall back to their type, so the chart still says
        // something useful.
        'industry' => _industryKey(h.symbol),
        'sector' => sectorOf(h.symbol),
        _ => h.currency,
      };
      groups[key] = (groups[key] ?? 0) + value;
    }
    final entries = groups.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in entries)
        AllocationSlice(
          label: e.key,
          value: e.value,
          color: by == 'type' ? typeColorOf(e.key) : _paletteColorFor(e.key),
        ),
    ];
  }

  Color _paletteColorFor(String key) {
    const palette = <Color>[
      Color(0xFF1E88E5), Color(0xFF00897B), Color(0xFF8E24AA), Color(0xFFF4511E),
      Color(0xFF3949AB), Color(0xFF43A047), Color(0xFFD81B60), Color(0xFF6D4C41),
      Color(0xFF5E35B1), Color(0xFF00ACC1), Color(0xFF7CB342), Color(0xFFFB8C00),
      Color(0xFFC0CA33), Color(0xFF039BE5), Color(0xFFE53935), Color(0xFF546E7A),
    ];
    return palette[colorIndexFor(key) % palette.length];
  }

  String typeLabelOf(String symbol) {
    final type = _quotes[symbol]?.quoteType;
    switch (type) {
      case 'ETF':
      case 'MUTUALFUND':
        return 'ETFs & funds';
      case 'CRYPTOCURRENCY':
        return 'Crypto';
      case 'INDEX':
        return 'Indexes';
      case 'CURRENCY':
        return 'Cash / FX';
      case 'EQUITY':
        return 'Stocks';
      default:
        return 'Other';
    }
  }

  Color typeColorOf(String label) {
    switch (label) {
      case 'Stocks':
        return const Color(0xFF1E88E5);
      case 'ETFs & funds':
        return const Color(0xFF00897B);
      case 'Crypto':
        return const Color(0xFFF7931A);
      case 'Indexes':
        return const Color(0xFF8E24AA);
      case 'Cash / FX':
        return const Color(0xFF43A047);
      default:
        return const Color(0xFF546E7A);
    }
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

  Future<void> setThemeMode(AppThemeId mode) async {
    _themeMode = mode;
    notifyListeners();
    await _persistData();
  }

  Future<void> setAccentIndex(int index) async {
    _accentIndex = index.clamp(0, AppTheme.accents.length - 1);
    notifyListeners();
    await _persistData();
  }

  Future<void> setAutoRefreshOnStart(bool v) async {
    _autoRefreshOnStart = v;
    notifyListeners();
    await _persistData();
  }

  Future<void> setDisplayCurrency(String code) async {
    _displayCurrency = code.trim().toUpperCase();
    if (_displayCurrency == 'NONE') _displayCurrency = '';
    // A new display currency needs its own rates, so the retry cooldown
    // from a previous failure must not block the first attempt.
    _fxLastAttempt = null;
    notifyListeners();
    await _persistData();
    await ensureFxRates();
  }

  Future<void> setNotifyDividends(bool v) async {
    _notifyDividends = v;
    notifyListeners();
    await _persistData();
    await pushWorkerSnapshot();
  }

  Future<void> setNotifyEarnings(bool v) async {
    _notifyEarnings = v;
    notifyListeners();
    await _persistData();
    await pushWorkerSnapshot();
  }

  Future<void> setPriceAlertPct(double pct) async {
    _priceAlertPct = pct;
    notifyListeners();
    await _persistData();
    await pushWorkerSnapshot();
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
    final currency =
        (t.converted && t.displayCurrency != null) ? t.displayCurrency! : _dominantCurrency();
    final total = fmtMoney(t.marketValue, currency: currency);
    final change = t.hasDayChange
        ? '${fmtSignedMoney(t.dayChange, currency: currency)} (${fmtPct(t.dayChangePercent)})'
        : '';
    final sign = t.hasDayChange ? (t.dayChange > 0 ? 1 : (t.dayChange < 0 ? -1 : 0)) : 0;

    // A short summary of what the number is made of.
    final holdingCount = _portfolios.fold<int>(
        0, (sum, p) => sum + p.holdings.length);
    final markets = <String>{};
    for (final p in _portfolios) {
      for (final h in p.holdings.values) {
        final q = _quotes[h.symbol];
        markets.add(marketFor(
          symbol: h.symbol,
          exchangeCode: q?.exchange,
          exchangeName: q?.fullExchangeName,
          quoteType: q?.quoteType,
        ) ??
            'Other');
      }
    }
    final meta = holdingCount == 0
        ? 'No holdings yet'
        : '$holdingCount holding${holdingCount == 1 ? '' : 's'}'
            '${markets.isEmpty ? '' : ' · ${markets.length} market${markets.length == 1 ? '' : 's'}'}';

    final next = nextUpcomingAcrossAll();
    String nd1;
    String nd2;
    String ndSymbol;
    String ndAmount;
    String ndWhen;
    if (next == null) {
      nd1 = 'No upcoming dividends';
      nd2 = '';
      ndSymbol = 'No dividends';
      ndAmount = '';
      ndWhen = '';
    } else {
      nd1 = '${next.symbol} ${fmtMoney(next.amountPerShare, currency: currency)}/share';
      nd2 = '${next.estimated ? 'Est. ' : ''}ex ${fmtShortDate(next.exDate)}'
          ' | pays ${fmtShortDate(next.payDate)}';
      ndSymbol = next.symbol;
      ndAmount = '${fmtMoney(next.amountPerShare, currency: currency)}/share';
      final days = next.exDate.difference(DateTime.now()).inDays;
      ndWhen = days <= 0 ? 'today' : 'in $days day${days == 1 ? '' : 's'}';
    }

    await StockPulseWidgetService.push(
      total: total,
      change: change,
      changeSign: sign,
      nextDividendLine1: nd1,
      nextDividendLine2: nd2,
      meta: meta,
      nextDividendSymbol: ndSymbol,
      nextDividendAmount: ndAmount,
      nextDividendWhen: ndWhen,
    );
    await pushWorkerSnapshot();
  }

  /// Writes the compact JSON snapshot the native background worker reads:
  /// aggregated positions, FX rates into the display currency, next
  /// ex-dividend and earnings dates, and price-alert thresholds.
  Future<void> pushWorkerSnapshot() async {
    if (!StockPulseWidgetService.supported) return;

    final qtyBySymbol = <String, double>{};
    final curBySymbol = <String, String>{};
    final nameBySymbol = <String, String>{};
    for (final p in _portfolios) {
      for (final h in p.holdings.values) {
        qtyBySymbol[h.symbol] = (qtyBySymbol[h.symbol] ?? 0) + h.quantity;
        curBySymbol[h.symbol] = h.currency;
        final name = nameBySymbol[h.symbol];
        if ((name == null || name.isEmpty) && h.name.isNotEmpty) {
          nameBySymbol[h.symbol] = h.name;
        }
      }
    }
    if (qtyBySymbol.isEmpty) return;

    final positions = [
      for (final e in qtyBySymbol.entries)
        (
          symbol: e.key,
          qty: e.value,
          currency: curBySymbol[e.key] ?? 'USD',
          name: nameBySymbol[e.key] ?? '',
        ),
    ];

    // rates keyed FROM currency -> value, only pairs targeting the display
    final display = _displayCurrency;
    final rates = {
      for (final e in _fxRates.entries)
        if (display.isNotEmpty &&
            e.key.length > display.length &&
            e.key.endsWith(display))
          e.key.substring(0, e.key.length - display.length): e.value,
    };

    final next = nextUpcomingAcrossAll();
    final earnings = <String, int>{};
    for (final s in qtyBySymbol.keys) {
      final earn = _quotes[s]?.earningsDate;
      if (earn != null && earn.isAfter(DateTime.now())) {
        earnings[s] = earn.millisecondsSinceEpoch;
      }
    }

    final alerts = _priceAlertPct > 0
        ? {for (final e in qtyBySymbol.entries) e.key: _priceAlertPct}
        : null;

    await StockPulseWidgetService.pushBackgroundSnapshot(
      positions: positions,
      displayCurrency: display,
      ratesByFrom: rates,
      nextDividend:
          (next != null && _notifyDividends) ? (symbol: next.symbol, exDate: next.exDate) : null,
      earningsBySymbol: _notifyEarnings ? earnings : const {},
      alerts: alerts,
    );
  }

  /// Fills in-memory state with realistic demo data. Used by integration
  /// tests to capture deterministic screenshots without the network.
  @visibleForTesting
  void seedDemoData() {
    DateTime inDays(int d) => DateTime.now().add(Duration(days: d));
    DividendInfo hist(
      List<double> amounts, {
      int gap = 91,
      DateTime? exactEx,
      DateTime? exactPay,
    }) {
      final now = DateTime.now();
      return DividendInfo(
        symbol: 'seed',
        payments: [
          for (var i = 1; i <= amounts.length; i++)
            DividendPayment(
              exDate: now.subtract(Duration(days: gap * i)),
              amount: amounts[amounts.length - i],
            ),
        ],
        exDividendDate: exactEx,
        payDate: exactPay,
        cachedAt: DateTime.now(),
      );
    }

    _portfolios = [
      Portfolio(id: 'demo-long', name: 'Long-term', holdings: {
        'AAPL': Holding(
            symbol: 'AAPL',
            name: 'Apple Inc.',
            currency: 'USD',
            quantity: 12,
            avgCost: 187.50),
        'SCHD': Holding(
            symbol: 'SCHD',
            name: 'Schwab US Dividend Equity ETF',
            currency: 'USD',
            quantity: 55,
            avgCost: 26.80),
        'MSFT': Holding(
            symbol: 'MSFT',
            name: 'Microsoft Corporation',
            currency: 'USD',
            quantity: 4,
            avgCost: 243.20),
        'O': Holding(
            symbol: 'O',
            name: 'Realty Income Corp',
            currency: 'USD',
            quantity: 40,
            avgCost: 57.75),
        'BTC-USD': Holding(
            symbol: 'BTC-USD',
            name: 'Bitcoin USD',
            currency: 'USD',
            quantity: 0.35,
            avgCost: 61200),
      }),
      Portfolio(id: 'demo-tsx', name: 'Canada', holdings: {
        'RY.TO': Holding(
            symbol: 'RY.TO',
            name: 'Royal Bank of Canada',
            currency: 'CAD',
            quantity: 30,
            avgCost: 148.20),
        'SHOP.TO': Holding(
            symbol: 'SHOP.TO',
            name: 'Shopify Inc',
            currency: 'CAD',
            quantity: 15,
            avgCost: 96.40),
      }),
    ];
    _activeIndex = 0;

    Quote q(String symbol, String name, String currency, double price,
        double pct, double? divRate,
        {String? type, String? exchange}) {
      return Quote(
        symbol: symbol,
        name: name,
        currency: currency,
        quoteType: type ?? 'EQUITY',
        exchange: exchange,
        marketState: 'REGULAR',
        price: price,
        previousClose: price - price * pct / 100,
        dayChange: price * pct / 100,
        dayChangePercent: pct,
        fiftyTwoWeekHigh: price * 1.08,
        fiftyTwoWeekLow: price * 0.74,
        dividendRate: divRate,
        dividendYield: divRate == null ? null : divRate / price,
        updatedAt: DateTime.now(),
      );
    }

    _quotes = {
      'AAPL': q('AAPL', 'Apple Inc.', 'USD', 261.48, 0.62, 1.08, exchange: 'NASDAQ'),
      'SCHD': q('SCHD', 'Schwab US Dividend Equity ETF', 'USD', 29.15, 0.35, 0.62,
          type: 'ETF', exchange: 'NYSEARCA'),
      'MSFT': q('MSFT', 'Microsoft Corporation', 'USD', 508.20, -0.41, 3.32, exchange: 'NASDAQ'),
      'O': q('O', 'Realty Income Corp', 'USD', 61.20, 0.24, 3.10, exchange: 'NYSE'),
      'BTC-USD': q('BTC-USD', 'Bitcoin USD', 'USD', 98450.00, 1.10, null,
          type: 'CRYPTOCURRENCY', exchange: 'CCC'),
      'RY.TO': q('RY.TO', 'Royal Bank of Canada', 'CAD', 172.40, 0.31, 5.96, exchange: 'TSX'),
      'SHOP.TO': q('SHOP.TO', 'Shopify Inc', 'CAD', 310.20, -0.55, null, exchange: 'TSX'),
    };

    _dividendInfo = {
      'AAPL': hist([1.04, 1.04, 1.06, 1.08],
          exactEx: inDays(6), exactPay: inDays(16)),
      'SCHD': hist([0.63, 0.65, 0.70, 0.74],
          exactEx: inDays(12), exactPay: inDays(21)),
      'MSFT': hist([0.75, 0.79, 0.83, 0.83]),
      'O': hist(
        List.filled(24, 0.2565),
        gap: 30,
      ),
      'RY.TO': hist([1.32, 1.36, 1.40, 1.42]),
    };

    _loaded = true;
    notifyListeners();
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
    await ensureFxRates();
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

/// One slice of the allocation donut.
@immutable
class AllocationSlice {
  final String label;
  final double value;
  final Color color;
  const AllocationSlice({required this.label, required this.value, required this.color});
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

class _CachedSparkline {
  final List<double> points;
  final DateTime at;
  _CachedSparkline(this.points) : at = DateTime.now();
}