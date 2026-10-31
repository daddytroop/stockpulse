/// Currency handling for FX conversion.
///
/// Yahoo quotes a currency as `[FROM][TO]=X`, meaning "one FROM is worth
/// this many TO". Not every pair exists: there is no `SGDCAD=X` or
/// `PLNCAD=X`, but there *is* an `SGDUSD=X` and a `USDCAD=X`. So every
/// conversion goes through the dollar, which is the pair Yahoo actually
/// quotes for every currency it supports.
library;

/// The Yahoo symbol for a currency's rate against the dollar.
///
/// For example `SGDUSD=X`.
String fxSymbol(String currency) {
  final code = _normalisedCode(currency);
  return '${code}USD=X';
}

/// The currency code Yahoo uses for the pair.
String _normalisedCode(String currency) {
  final code = currency.trim().toUpperCase();
  // Yahoo reports London-listed stocks in pence.
  if (code == 'GBP') return 'GBP';
  return code;
}

/// How many units of the pair's currency one unit of [currency] is worth.
///
/// Yahoo quotes London stocks in pence, so a price of 500 "GBp" is really
/// 5 pounds.
double fxUnitFactor(String currency) =>
    currency.trim().toUpperCase() == 'GBP' && currency.trim() != 'GBP' ? 0.01 : 1.0;

/// Whether a currency is quoted in minor units (pence) rather than pounds.
bool isMinorUnitCurrency(String currency) {
  final raw = currency.trim();
  return raw.toUpperCase() == 'GBP' && raw != 'GBP';
}
