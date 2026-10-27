/// Exchange identity helpers.
///
/// Yahoo Finance reports two fields per quote:
///  * `exchange`          - a short venue code (NMS, NYQ, TOR, PCX, ...).
///  * `fullExchangeName`  - a human name (NasdaqGS, NYSE, Toronto, ...).
///
/// Codes are preferred because several venues share a name (for example the
/// Toronto exchange reports `Toronto` while Toronto Venture reports
/// `TSXV`). Symbols are only used as a last resort, and only for the
/// suffixes Yahoo itself uses, so a US listing is never mislabelled.
library;

/// Friendly label for each venue code Yahoo can report.
const Map<String, String> _marketByCode = {
  // United States
  'NMS': 'NASDAQ',
  'NGM': 'NASDAQ',
  'NCM': 'NASDAQ',
  'NASDAQGS': 'NASDAQ',
  'NASDAQGM': 'NASDAQ',
  'NASDAQCM': 'NASDAQ',
  'NASDAQ': 'NASDAQ',
  'NYQ': 'NYSE',
  'NYSE': 'NYSE',
  'PCX': 'NYSE Arca',
  'NYSEARCA': 'NYSE Arca',
  'ARCA': 'NYSE Arca',
  'ASE': 'NYSE American',
  'NYSEAMERICAN': 'NYSE American',
  'AMEX': 'NYSE American',
  'BTS': 'Cboe',
  'CBOE': 'Cboe',
  'OQX': 'OTC',
  'OQB': 'OTC',
  'PNK': 'OTC',
  'OTC': 'OTC',
  // Canada
  'TOR': 'TSX',
  'TSX': 'TSX',
  'TORONTO': 'TSX',
  'VAN': 'TSX Venture',
  'TSXV': 'TSX Venture',
  'CNQ': 'TSX',
  // United Kingdom / Europe
  'LSE': 'LSE',
  'LON': 'LSE',
  'AMS': 'Euronext',
  'PAR': 'Euronext',
  'EUR': 'Euronext',
  'GER': 'Xetra',
  'XETRA': 'Xetra',
  'MIL': 'Borsa Italiana',
  'STO': 'Nasdaq Stockholm',
  'HEL': 'Nasdaq Helsinki',
  'CPH': 'Nasdaq Copenhagen',
  'SWX': 'SIX',
  'SW': 'SIX',
  // Asia / Pacific
  'HKG': 'Hong Kong',
  'KSC': 'KRX',
  'NSE': 'NSE India',
  'BSE': 'BSE India',
  'SHH': 'Shanghai',
  'SHG': 'Shanghai',
  'SHZ': 'Shenzhen',
  'TSE': 'Tokyo',
  'JPX': 'Tokyo',
  'ASX': 'ASX',
  'NZX': 'NZX',
  'SET': 'SET',
  'TWO': 'Taiwan',
  'TW': 'Taiwan',
  // Crypto / FX
  'CCC': 'Crypto',
  'CCY': 'Crypto',
  'CNX': 'Crypto',
};

/// Friendly label for each full venue name Yahoo can report.
const Map<String, String> _marketByName = {
  'NASDAQGS': 'NASDAQ',
  'NASDAQGM': 'NASDAQ',
  'NASDAQCM': 'NASDAQ',
  'NASDAQ': 'NASDAQ',
  'NYSE': 'NYSE',
  'NYSEARCA': 'NYSE Arca',
  'NYSE AMERICAN': 'NYSE American',
  'ASE': 'NYSE American',
  'TORONTO': 'TSX',
  'TSX': 'TSX',
  'TSXV': 'TSX Venture',
  'CBOE': 'Cboe',
  'BATS': 'Cboe',
  'OTC': 'OTC',
  'LSE': 'LSE',
  'CCC': 'Crypto',
};

/// Order markets are shown in; anything else follows alphabetically.
const List<String> _marketOrder = [
  'NASDAQ',
  'NYSE',
  'NYSE Arca',
  'NYSE American',
  'Cboe',
  'TSX',
  'TSX Venture',
  'Crypto',
];

/// Resolves the market a symbol trades on.
///
/// Prefers the venue code reported by the data source, then the venue name,
/// then the well-known Yahoo symbol suffix. Returns `null` when the market
/// genuinely cannot be determined - it is never guessed.
String? marketFor({
  String? symbol,
  String? exchangeCode,
  String? exchangeName,
  String? quoteType,
}) {
  if (quoteType == 'CRYPTOCURRENCY') return 'Crypto';

  final code = exchangeCode?.trim().toUpperCase() ?? '';
  if (code.isNotEmpty) {
    final mapped = _marketByCode[code];
    if (mapped != null) return mapped;
  }

  final name = exchangeName?.trim().toUpperCase() ?? '';
  if (name.isNotEmpty) {
    final mapped = _marketByName[name];
    if (mapped != null) return mapped;
  }

  final sym = symbol?.trim().toUpperCase() ?? '';
  if (sym.endsWith('.TO')) return 'TSX';
  if (sym.endsWith('.V')) return 'TSX Venture';
  if (sym.endsWith('.L')) return 'LSE';
  if (sym.endsWith('.SW')) return 'SIX';
  if (sym.endsWith('.T')) return 'Tokyo';
  if (sym.endsWith('.HK')) return 'Hong Kong';
  if (sym.endsWith('.AX')) return 'ASX';
  if (sym.endsWith('.NS') || sym.endsWith('.BO')) return 'NSE India';
  if (sym.endsWith('-USD') || sym.endsWith('-CAD') || sym.endsWith('-EUR')) {
    return 'Crypto';
  }
  return null;
}

/// Sorts market labels into a stable, readable order.
int compareMarkets(String a, String b) {
  final ia = _marketOrder.indexOf(a);
  final ib = _marketOrder.indexOf(b);
  if (ia == -1 && ib == -1) return a.compareTo(b);
  if (ia == -1) return 1;
  if (ib == -1) return -1;
  return ia.compareTo(ib);
}
