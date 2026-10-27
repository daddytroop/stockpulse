import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Resolves real company logos for stock symbols.
///
/// Logos come from Wikimedia, which serves them with permissive CORS headers
/// so the same URLs work in the Android app, the Windows build and the
/// browser build.
///
/// Resolution order:
///  1. A curated map of well known tickers (fast, no extra lookups).
///  2. A Wikidata query for the exact ticker symbol, disambiguated against
///     the company name the quote carries, so `C` resolves to Citigroup and
///     not to a different company that happens to share the ticker.
///
/// Anything that cannot be resolved keeps the coloured letter avatar.
class LogoService {
  LogoService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _commonsBase =
      'https://commons.wikimedia.org/wiki/Special:FilePath/';
  static const String _wikipediaBase =
      'https://en.wikipedia.org/wiki/Special:FilePath/';

  /// Logo files hosted on Wikimedia Commons.
  static const Map<String, String> _curated = {
    // United States - technology
    'AAPL': 'Apple logo black.svg',
    'MSFT': 'Microsoft logo (2012).svg',
    'GOOG': 'Google 2026 logo.svg',
    'GOOGL': 'Google 2026 logo.svg',
    'AMZN': 'Amazon 2024.svg',
    'NVDA': 'NVIDIA logo.svg',
    'META': 'Meta Platforms Inc. logo.svg',
    'TSLA': 'Tesla Motors.svg',
    'AMD': 'AMD Logo.svg',
    'INTC': 'Intel logo 2023.svg',
    'AVGO': 'Broadcom logo (2016-present).svg',
    'ORCL': 'Oracle logo.svg',
    'ADBE': 'Adobe Corporate wordmark.svg',
    'CRM': 'Salesforce.com logo.svg',
    'CSCO': 'Cisco logo blue 2016.svg',
    'QCOM': 'Qualcomm-Logo.svg',
    'MU': 'Micron Technology logo 2024.svg',
    'AMAT': 'Applied Materials Logo.svg',
    'LRCX': 'Lam-Research-Logo.svg',
    'KLAC': 'KLA Corp. logo.svg',
    'ADI': 'Analog Devices Logo.svg',
    'NXPI': 'NXP Semiconductors logo 2023.svg',
    'TXN': 'TexasInstruments-Logo.svg',
    'APH': 'Logo Amphenol.svg',
    'TEL': 'TE Connectivity logo.svg',
    'GLW': 'Corning Incorporated Logo.svg',
    'IBM': 'IBM logo.svg',
    'PLTR': 'Palantir Technologies logo.svg',
    'SNOW': 'Snowflake Logo.svg',
    'NET': 'Cloudflare Logo.svg',
    'OKTA': 'Okta logo (2023).svg',
    'DOCS': 'Doximity.svg',
    'ROKU': 'Roku logo.svg',
    'SPOT': '2024 Spotify Logo.svg',
    'PYPL': 'Paypal.svg',
    'RBLX': 'Roblox Logo 2022.svg',
    'UBER': 'Uber logo 2018.svg',
    'DASH': 'DoorDash Logo.svg',
    'COIN': 'Coinbase.svg',
    'HOOD': 'Robinhood (company) logo.svg',
    'SOFI': 'SoFi logo.svg',
    'PINS': 'Pinterest Logo 3.svg',
    'SNAP': 'Snap Inc. logo.svg',
    'ZM': 'Zoom Communications Logo.svg',
    'TWLO': 'Twilio-logo-red.svg',
    'U': 'Unity 2021.svg',
    // United States - consumer, energy and financials
    'KO': 'The Coca-Cola Company (2020).svg',
    'PEP': 'PepsiCo (2025, wordmark).svg',
    'MCD': "McDonald's with slogan 2020.svg",
    'SBUX': 'Starbucks coffee wordmark.png',
    'NKE': 'Logo NIKE.svg',
    'WMT': 'Walmart logo (2025).svg',
    'COST': 'Costco Wholesale logo 2010-10-26.svg',
    'HD': 'The Home Depot logo.svg',
    'LOW': 'Lowes Companies Logo.svg',
    'TGT': 'Target Corporation logo.svg',
    'TJX': 'TJX Logo.svg',
    'BKNG': 'Priceline.com logo.svg',
    'DIS': 'The Walt Disney Company Logo.svg',
    'NFLX': 'Netflix 2014 logo.svg',
    'CMCSA': 'Comcast logo.svg',
    'T': 'AT&T logo 2016.svg',
    'VZ': 'Verizon logo.svg',
    'CVX': 'Chevron Logo.svg',
    'XOM': 'Exxon Mobil Logo.svg',
    'JPM': 'Logo of JPMorganChase 2024.svg',
    'BAC': 'Bank of America logo.svg',
    'C': 'Citi logo March 2023.svg',
    'GS': 'Goldman Sachs logo.svg',
    'MS': 'Morgan Stanley Logo 2024.png',
    'V': 'Visa Inc. logo (2021–present).svg',
    'MA': 'Mastercard 2019 logo.svg',
    'AXP': 'American Express logo.svg',
    'BRK-B': 'Berkshire-Hathaway-Logo.svg',
    'BRK.B': 'Berkshire-Hathaway-Logo.svg',
    'SCHD': 'Charles Schwab Corporation logo.svg',
    'SCHB': 'Charles Schwab Corporation logo.svg',
    'O': 'Realty Income logo.svg',
    'JNJ': 'JNJ Logo New.svg',
    'PG': 'Procter & Gamble logo.svg',
    'MRK': 'Merck Logo.svg',
    'PFE': 'Pfizer (2021).svg',
    'LLY': 'Eli Lilly and Company.svg',
    'ABBV': 'AbbVie logo.svg',
    'AMGN': 'Amgen.svg',
    'ISRG': 'Intuitive Surgical logo.svg',
    'VRTX': 'VertexPharma-logo2.png',
    'TMO': 'Thermo Fisher Scientific logo.svg',
    'KMB': 'Kimberly-Clark logo.svg',
    'CL': 'Colgate-Palmolive (2025).svg',
    'GIS': 'General Mills logo.svg',
    'MDLZ': 'Mondelez International.svg',
    'CB': 'Chubb-Limited-logo.svg',
    'ALL': 'Allstate wordmark.svg',
    'TRV': 'Trav umb 5inch.jpg',
    'AON': 'Aon Corporation logo.svg',
    'MMC': 'MarshMcLennan h rgb c.svg',
    'SPGI': 'S&P Global logo.svg',
    'ICE': 'Logo of the IntercontinentalExchange.svg',
    'CME': 'CME Group Logo.svg',
    'NDAQ': 'NASDAQ Logo.svg',
    'KEY': 'KeyBank.png',
    // Canada
    'RY': 'RBC logo.jpg',
    'TD': 'Toronto-Dominion Bank logo.svg',
    'BMO': 'BMO Logo.svg',
    'BNS': 'Banque Scotia (logo, 2019).svg',
    'CN': 'CN Railway logo.svg',
    'CP': 'CPKC Wordmark.svg',
    'BCE': 'BCE Inc Logo.svg',
    'SU': 'Suncor Energy.svg',
    'FTS': 'Fortis Inc logo.svg',
    'NTR': 'Nutrien Logo.svg',
    'AEP': 'AEP logo.svg',
    'LUN': 'Lundin-MiningLogo.svg',
    'IFP': 'Interfor Corporation Logo.svg',
    'SHOP': 'Shopify logo 2018.svg',
    // Funds and trusts
    'VOO': 'Vanguard.svg',
    'VTI': 'Vanguard.svg',
    'VYM': 'Vanguard.svg',
    'VEA': 'Vanguard.svg',
    'VWO': 'Vanguard.svg',
    'SPY': 'State Street Global Advisors.svg',
    'XIU': 'Logo-ishares 2019.svg',
    'XEQT': 'Logo-ishares 2019.svg',
    'VEQT': 'Vanguard.svg',
    'VFV': 'Vanguard.svg',
    // Crypto
    'BTC-USD': 'Bitcoin.svg',
    'ETH-USD': 'Ethereum-icon-purple.svg',
  };

  /// Logo files that only exist on the English Wikipedia (non-free logos).
  static const Map<String, String> _curatedEnglish = {
    'CM': 'CIBC logo.svg',
  };

  /// Cache of resolved logo URLs, keyed by symbol.
  final Map<String, String?> _cache = {};

  /// Returns the logo URL for [symbol], or null when no logo was found.
  ///
  /// [companyName] is the name the quote carries; it is used to pick the
  /// right company when a ticker maps to more than one issuer.
  Future<String?> logoUrlFor(String symbol, {String? companyName}) async {
    final key = symbol.trim().toUpperCase();
    if (key.isEmpty) return null;
    if (_cache.containsKey(key)) return _cache[key];

    final url = _curatedUrl(key) ??
        _curatedUrl(_baseTicker(key)) ??
        await _lookupUrl(_baseTicker(key), companyName);
    _cache[key] = url;
    return url;
  }

  /// The ticker without an exchange suffix, e.g. `RY.TO` -> `RY`.
  ///
  /// The same company trades under the same ticker on both its home exchange
  /// and the US, so the logo is the same either way.
  static String _baseTicker(String symbol) {
    final dot = symbol.indexOf('.');
    if (dot <= 0) return symbol;
    final suffix = symbol.substring(dot + 1);
    const knownSuffixes = {'TO', 'V', 'L', 'SW', 'T', 'HK', 'AX', 'NS', 'BO'};
    if (!knownSuffixes.contains(suffix)) return symbol;
    return symbol.substring(0, dot);
  }

  String? _curatedUrl(String key) {
    final commons = _curated[key];
    if (commons != null) return _fileUrl(_commonsBase, commons);
    final english = _curatedEnglish[key];
    if (english != null) return _fileUrl(_wikipediaBase, english);
    return null;
  }

  String _fileUrl(String base, String file) =>
      '$base${Uri.encodeComponent(file)}?width=160';

  /// Asks Wikidata which company claims this ticker and returns its logo.
  Future<String?> _lookupUrl(String ticker, String? companyName) async {
    final uri = Uri.https('query.wikidata.org', '/sparql', {
      'format': 'json',
      'query': _sparqlFor(ticker),
    });
    http.Response response;
    try {
      response = await _client.get(uri, headers: {
        'Accept': 'application/sparql-results+json',
        'User-Agent': 'StockPulse/1.5 (https://github.com/daddytroop/stockpulse)',
      }).timeout(const Duration(seconds: 12));
    } catch (_) {
      return null;
    }
    if (response.statusCode != 200) return null;

    List<dynamic> rows;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      rows = decoded['results']?['bindings'] as List? ?? const [];
    } catch (_) {
      return null;
    }

    final candidates = <_Candidate>[];
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final label = row['label']?['value'] as String?;
      final logo = row['logo']?['value'] as String?;
      if (label == null || logo == null) continue;
      final file = logo.split('/Special:FilePath/').last;
      if (file.isEmpty) continue;
      // Non-free logos live on the English Wikipedia rather than Commons.
      final base = logo.contains('en.wikipedia.org') ? _wikipediaBase : _commonsBase;
      candidates.add(_Candidate(label: label, url: _fileUrl(base, file)));
    }
    if (candidates.isEmpty) return null;

    final name = companyName?.trim() ?? '';
    if (name.isEmpty) return candidates.first.url;

    // Rank by how many significant words the two names share. Ties go to the
    // more specific label (fewest extra words), so "Merck & Co." wins over
    // "Merck KGaA" for a company called "Merck & Co., Inc.".
    candidates.sort((a, b) {
      final byShared = _sharedTokens(name, b.label).compareTo(
            _sharedTokens(name, a.label),
          );
      if (byShared != 0) return byShared;
      return _tokens(a.label).length.compareTo(_tokens(b.label).length);
    });
    if (_sharedTokens(name, candidates.first.label) == 0) return null;
    return candidates.first.url;
  }

  String _sparqlFor(String ticker) => '''
SELECT ?label ?logo WHERE {
  ?item p:P414 ?statement .
  ?statement pq:P249 "$ticker" .
  ?item wdt:P154 ?logo .
  ?item rdfs:label ?label .
  FILTER(lang(?label) = "en")
}''';

  static int _sharedTokens(String companyName, String label) {
    final a = _tokens(companyName);
    final b = _tokens(label);
    if (a.isEmpty || b.isEmpty) return 0;
    var shared = 0;
    for (final token in a) {
      if (b.contains(token)) shared++;
    }
    return shared;
  }

  static Set<String> _tokens(String value) {
    const stop = {
      'inc', 'corp', 'corporation', 'co', 'company', 'ltd', 'limited', 'plc',
      'the', 'sa', 'nv', 'ag', 'lp', 'class', 'and', 'of', 'holdings', 'group',
      'us', 'usa', 'american', 'international', 'trading', 'etf', 'trust', 'fund',
      'shares',
    };
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !stop.contains(w))
        .toSet();
  }

  @visibleForTesting
  static int sharedTokensForTest(String companyName, String label) =>
      _sharedTokens(companyName, label);
}

class _Candidate {
  final String label;
  final String url;
  const _Candidate({required this.label, required this.url});
}
