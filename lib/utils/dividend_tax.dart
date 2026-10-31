/// Dividend withholding tax.
///
/// A dividend paid by a company in one country to a resident of another is
/// usually taxed before it is paid out, and the rate depends on the two
/// countries. This is the tax you keep, not the tax you owe - it is
/// therefore worth knowing, because a 15% withholding on a US dividend
/// changes which share is actually the better buy.
///
/// The rates here are the treaty rates that apply to US and Canadian
/// dividends, which is where withholding actually bites for most people.
/// Dividends from other markets are shown gross, because the rules vary
/// too much to guess.
///
/// This is an estimate to help with comparing income, not tax advice.
library;

/// Countries the user can pick, with the code used in the rate tables.
class TaxCountry {
  final String code;
  final String label;
  const TaxCountry(this.code, this.label);
}

const List<TaxCountry> taxCountries = [
  TaxCountry('', 'No withholding'),
  TaxCountry('CA', 'Canada'),
  TaxCountry('US', 'United States'),
  TaxCountry('GB', 'United Kingdom'),
  TaxCountry('AU', 'Australia'),
  TaxCountry('IE', 'Ireland'),
  TaxCountry('NZ', 'New Zealand'),
  TaxCountry('JP', 'Japan'),
  TaxCountry('DE', 'Germany'),
  TaxCountry('FR', 'France'),
];

/// The country a market belongs to, for withholding purposes.
///
/// Only the markets where withholding actually applies are listed; the
/// rest return an empty string, which means "shown gross".
String countryForMarket(String? market) {
  switch (market) {
    case 'NASDAQ':
    case 'NYSE':
    case 'NYSE Arca':
    case 'NYSE American':
    case 'Cboe':
    case 'OTC':
      return 'US';
    case 'TSX':
    case 'TSX Venture':
      return 'CA';
    default:
      return '';
  }
}

/// The dividend withholding rate for a resident of [home] holding an issuer
/// in [issuer], as a fraction (0.15 = 15%).
///
/// Only US and Canadian source dividends are covered; everything else is
/// gross.
double withholdingRate(String home, String issuer) {
  if (home.isEmpty || issuer.isEmpty) return 0;
  if (home == issuer) return 0;

  // Treaty rates on dividends paid by US companies.
  const usTreaty = {
    'CA': 0.15,
    'GB': 0.15,
    'AU': 0.15,
    'IE': 0.15,
    'NZ': 0.15,
    'DE': 0.15,
    'FR': 0.15,
    'JP': 0.10,
  };

  // Treaty rates on dividends paid by Canadian companies.
  const canadaTreaty = {
    'US': 0.15,
    'GB': 0.15,
    'AU': 0.15,
    'IE': 0.15,
    'NZ': 0.15,
    'DE': 0.15,
    'FR': 0.15,
    'JP': 0.15,
  };

  if (issuer == 'US') {
    // The United States withholds 30% unless a treaty applies.
    return usTreaty[home] ?? 0.30;
  }
  if (issuer == 'CA') {
    // Canada withholds 25% unless a treaty applies.
    return canadaTreaty[home] ?? 0.25;
  }
  return 0;
}

/// The rate as a percentage, for display.
double withholdingPercent(String home, String issuer) =>
    withholdingRate(home, issuer) * 100;

/// The name of a country code, for display.
String countryLabel(String code) {
  for (final c in taxCountries) {
    if (c.code == code) return c.label;
  }
  return code;
}
