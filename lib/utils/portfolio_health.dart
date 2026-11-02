import 'dart:math';

/// A position as the health check sees it: its weight and what it is.
class HealthPosition {
  final String symbol;
  final double value;
  final double annualIncome;

  /// Sector or industry, when known.
  final String? sector;

  /// Asset type, e.g. 'Stock', 'ETF', 'Crypto'.
  final String type;

  /// The market the position trades on.
  final String market;

  /// Current dividend yield, 0..1.
  final double yield;

  const HealthPosition({
    required this.symbol,
    required this.value,
    this.annualIncome = 0,
    this.sector,
    this.type = 'Stock',
    this.market = 'Other',
    this.yield = 0,
  });
}

enum HealthLevel { good, watch, risk }

/// One plain-language finding.
class HealthFinding {
  final HealthLevel level;
  final String title;
  final String detail;

  const HealthFinding(this.level, this.title, this.detail);
}

/// The result of a portfolio health check.
class HealthReport {
  /// 0..100, higher is more diversified.
  final int score;

  /// How many equally sized positions the portfolio behaves like.
  final double effectivePositions;

  /// The largest single position's share, 0..1.
  final double largestWeight;
  final String? largestSymbol;

  /// The largest sector's share of the positions whose sector is known.
  final double largestSectorWeight;
  final String? largestSector;

  /// Share of income from the biggest payer, 0..1.
  final double topIncomeShare;
  final String? topIncomeSymbol;

  final List<HealthFinding> findings;

  const HealthReport({
    required this.score,
    required this.effectivePositions,
    required this.largestWeight,
    required this.largestSymbol,
    required this.largestSectorWeight,
    required this.largestSector,
    required this.topIncomeShare,
    required this.topIncomeSymbol,
    required this.findings,
  });

  String get grade => score >= 80
      ? 'Well diversified'
      : score >= 60
          ? 'Fairly diversified'
          : score >= 40
              ? 'Concentrated'
              : 'Highly concentrated';
}

/// Scores how diversified a portfolio is and explains why.
///
/// The score is a transparent heuristic, not a rating of the investments:
///  * 40 points for breadth: the effective number of positions (the
///    inverse of the Herfindahl index), full marks at 20 or more,
///  * 25 points for the largest position staying at or under 10%,
///  * 20 points for the largest sector staying at or under 25%,
///  * 15 points for spreading across asset types and markets.
HealthReport checkHealth(List<HealthPosition> positions) {
  final held = positions.where((p) => p.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final total = held.fold<double>(0, (s, p) => s + p.value);
  if (held.isEmpty || total <= 0) {
    return const HealthReport(
      score: 0,
      effectivePositions: 0,
      largestWeight: 0,
      largestSymbol: null,
      largestSectorWeight: 0,
      largestSector: null,
      topIncomeShare: 0,
      topIncomeSymbol: null,
      findings: [
        HealthFinding(HealthLevel.watch, 'Nothing to check yet',
            'Add holdings with prices to see a health check.'),
      ],
    );
  }

  final weights = [for (final p in held) p.value / total];
  final hhi = weights.fold<double>(0, (s, w) => s + w * w);
  final effective = hhi > 0 ? 1 / hhi : 0.0;
  final largest = weights.first;

  // Sectors, among the positions where the sector is known.
  final bySector = <String, double>{};
  var sectorKnown = 0.0;
  for (final p in held) {
    final s = p.sector?.trim();
    if (s == null || s.isEmpty) continue;
    bySector[s] = (bySector[s] ?? 0) + p.value;
    sectorKnown += p.value;
  }
  String? topSector;
  var topSectorWeight = 0.0;
  if (sectorKnown > 0) {
    for (final e in bySector.entries) {
      final w = e.value / sectorKnown;
      if (w > topSectorWeight) {
        topSectorWeight = w;
        topSector = e.key;
      }
    }
  }

  // Income concentration.
  final totalIncome = held.fold<double>(0, (s, p) => s + p.annualIncome);
  String? topPayer;
  var topPayerShare = 0.0;
  if (totalIncome > 0) {
    for (final p in held) {
      final share = p.annualIncome / totalIncome;
      if (share > topPayerShare) {
        topPayerShare = share;
        topPayer = p.symbol;
      }
    }
  }

  final types = {for (final p in held) p.type}.length;
  final markets = {for (final p in held) p.market}.length;

  final breadth = 40 * min(1.0, effective / 20);
  final single = largest <= 0.10 ? 25.0 : 25 * max(0.0, 1 - (largest - 0.10) / 0.40);
  final sector = sectorKnown <= 0
      ? 10.0 // unknown: neither rewarded nor punished in full
      : (topSectorWeight <= 0.25
          ? 20.0
          : 20 * max(0.0, 1 - (topSectorWeight - 0.25) / 0.50));
  final spread = 15 * min(1.0, ((types - 1) + (markets - 1)) / 3);
  final score = (breadth + single + sector + spread).round().clamp(0, 100);

  String pct(double v) => '${(v * 100).toStringAsFixed(0)}%';
  final findings = <HealthFinding>[];

  if (largest > 0.25) {
    findings.add(HealthFinding(HealthLevel.risk, '${held.first.symbol} is ${pct(largest)} of everything',
        'One company this large means a single bad quarter can move your whole portfolio.'));
  } else if (largest > 0.10) {
    findings.add(HealthFinding(HealthLevel.watch, '${held.first.symbol} is your biggest bet at ${pct(largest)}',
        'Many investors keep any single stock under about 10%.'));
  } else {
    findings.add(HealthFinding(HealthLevel.good, 'No single stock dominates',
        'Your largest position is ${pct(largest)}.'));
  }

  if (effective < 5) {
    findings.add(HealthFinding(HealthLevel.risk, 'Behaves like ${effective.toStringAsFixed(1)} stocks',
        'By weight, your portfolio acts like only a handful of equal positions.'));
  } else if (effective < 12) {
    findings.add(HealthFinding(HealthLevel.watch, 'Behaves like ${effective.toStringAsFixed(1)} stocks',
        'Spreading money across more positions smooths out the swings.'));
  } else {
    findings.add(HealthFinding(HealthLevel.good, 'Broad spread',
        'By weight, your portfolio acts like ${effective.toStringAsFixed(0)} equal positions.'));
  }

  if (topSector != null && topSectorWeight > 0.40) {
    findings.add(HealthFinding(HealthLevel.risk, '${pct(topSectorWeight)} in $topSector',
        'A slump in one industry would hit most of your holdings at once.'));
  } else if (topSector != null && topSectorWeight > 0.25) {
    findings.add(HealthFinding(HealthLevel.watch, '$topSector leads at ${pct(topSectorWeight)}',
        'Worth keeping an eye on as that sector grows.'));
  }

  if (totalIncome > 0 && topPayerShare > 0.35 && held.length > 1) {
    findings.add(HealthFinding(HealthLevel.watch, '$topPayer pays ${pct(topPayerShare)} of your dividends',
        'A cut there would take a big bite out of your income.'));
  }

  final highYield = held.where((p) => p.yield >= 0.09).map((p) => p.symbol).toList();
  if (highYield.isNotEmpty) {
    findings.add(HealthFinding(HealthLevel.watch, 'Very high yield: ${highYield.take(3).join(', ')}',
        'Yields above about 9% can signal the market expects a dividend cut.'));
  }

  if (types == 1 && markets == 1 && held.length > 1) {
    findings.add(const HealthFinding(HealthLevel.watch, 'One market, one asset type',
        'Everything trades in the same place and in the same way.'));
  }

  return HealthReport(
    score: score,
    effectivePositions: effective,
    largestWeight: largest,
    largestSymbol: held.first.symbol,
    largestSectorWeight: topSectorWeight,
    largestSector: topSector,
    topIncomeShare: topPayerShare,
    topIncomeSymbol: topPayer,
    findings: findings,
  );
}
