import 'dart:math';

/// One year of a dividend snowball projection.
class SnowballYear {
  /// Years from today; 0 is the starting point.
  final int year;

  /// Portfolio value at the end of the year.
  final double value;

  /// Dividends paid during the year (0 for the starting point, which shows
  /// today's annual income instead).
  final double income;

  /// Everything the user put in so far, including the starting value.
  final double contributed;

  /// Dividends reinvested so far.
  final double reinvested;

  const SnowballYear({
    required this.year,
    required this.value,
    required this.income,
    required this.contributed,
    required this.reinvested,
  });

  /// Income per month at this point.
  double get monthlyIncome => income / 12;
}

/// The inputs to a projection.
class SnowballInputs {
  /// Today's portfolio value.
  final double startValue;

  /// Today's yearly dividend income.
  final double startIncome;

  /// Years to project.
  final int years;

  /// Yearly growth of the dividend per share, e.g. 0.06 for 6%.
  final double dividendGrowth;

  /// Yearly growth of the share price.
  final double priceGrowth;

  /// Whether dividends buy more shares.
  final bool reinvest;

  /// Money added every month.
  final double monthlyContribution;

  /// Share of each dividend lost to withholding tax, 0..1.
  final double taxRate;

  /// A yield to use instead of today's actual one, for "what if" questions
  /// (and for portfolios that pay nothing yet).
  final double? yieldOverride;

  const SnowballInputs({
    required this.startValue,
    required this.startIncome,
    this.years = 10,
    this.dividendGrowth = 0.05,
    this.priceGrowth = 0.05,
    this.reinvest = true,
    this.monthlyContribution = 0,
    this.taxRate = 0,
    this.yieldOverride,
  });

  /// The yield the projection starts from.
  double get startYield =>
      yieldOverride ?? (startValue > 0 ? startIncome / startValue : 0);
}

/// Projects a dividend portfolio forward, year by year.
///
/// The portfolio is modelled as units of a single blended holding: each
/// unit starts at a price of 1 and pays today's yield. Every year the price
/// grows by [SnowballInputs.priceGrowth] and the payout per unit by
/// [SnowballInputs.dividendGrowth]. Contributions and reinvested dividends
/// buy units at the average price of the year. It is a projection under
/// fixed assumptions, not a forecast.
List<SnowballYear> projectSnowball(SnowballInputs input) {
  final out = <SnowballYear>[
    SnowballYear(
      year: 0,
      value: input.startValue,
      income: input.startValue * input.startYield,
      contributed: input.startValue,
      reinvested: 0,
    ),
  ];
  if (input.startValue <= 0 && input.monthlyContribution <= 0) return out;

  var units = input.startValue;
  var price = 1.0;
  var perUnit = input.startYield;
  var contributed = input.startValue;
  var reinvested = 0.0;
  final yearlyContribution = max(0.0, input.monthlyContribution) * 12;

  for (var y = 1; y <= input.years; y++) {
    final startPrice = price;
    price *= 1 + input.priceGrowth;
    perUnit *= 1 + input.dividendGrowth;
    final avgPrice = (startPrice + price) / 2;

    // Contributions arrive through the year, so on average they earn half
    // a year of dividends.
    final newUnits = yearlyContribution / avgPrice;
    final income = (units + newUnits / 2) * perUnit * (1 - input.taxRate);
    units += newUnits;
    contributed += yearlyContribution;

    if (input.reinvest) {
      units += income / avgPrice;
      reinvested += income;
    }
    out.add(SnowballYear(
      year: y,
      value: units * price,
      income: income,
      contributed: contributed,
      reinvested: reinvested,
    ));
  }
  return out;
}

/// The first projected year whose monthly income reaches [monthly], if any.
SnowballYear? firstYearReaching(List<SnowballYear> years, double monthly) {
  for (final y in years) {
    if (y.year > 0 && y.monthlyIncome >= monthly) return y;
  }
  return null;
}
