import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/models/watch_item.dart';
import 'package:stock_pulse/services/pro_service.dart';
import 'package:stock_pulse/services/store.dart';
import 'package:stock_pulse/utils/portfolio_health.dart';
import 'package:stock_pulse/utils/snowball.dart';

class _MemoryStore extends StockPulseStore {
  final Map<String, Map<String, dynamic>> files = {};

  @override
  Future<Map<String, dynamic>?> load(String name) async => files[name];

  @override
  Future<void> save(String name, Map<String, dynamic> data) async {
    files[name] = data;
  }
}

void main() {
  group('snowball', () {
    test('with no growth and no reinvestment, income stays flat', () {
      final years = projectSnowball(const SnowballInputs(
        startValue: 10000,
        startIncome: 400,
        years: 5,
        dividendGrowth: 0,
        priceGrowth: 0,
        reinvest: false,
      ));
      expect(years, hasLength(6));
      for (final y in years.skip(1)) {
        expect(y.income, closeTo(400, 1e-6));
        expect(y.value, closeTo(10000, 1e-6));
      }
    });

    test('reinvesting compounds the income', () {
      SnowballInputs inputs(bool reinvest) => SnowballInputs(
            startValue: 10000,
            startIncome: 400,
            years: 10,
            dividendGrowth: 0,
            priceGrowth: 0,
            reinvest: reinvest,
          );
      final flat = projectSnowball(inputs(false)).last.income;
      final compounding = projectSnowball(inputs(true)).last.income;
      expect(compounding, greaterThan(flat));
      // 4% yield reinvested at a flat price: income grows ~4% a year.
      expect(compounding, closeTo(400 * 1.04 * 1.04 * 1.04 * 1.04 * 1.04 * 1.04 * 1.04 * 1.04 * 1.04, 1));
    });

    test('dividend growth raises income at that rate', () {
      final years = projectSnowball(const SnowballInputs(
        startValue: 10000,
        startIncome: 400,
        years: 1,
        dividendGrowth: 0.10,
        priceGrowth: 0,
        reinvest: false,
      ));
      expect(years.last.income, closeTo(440, 1e-6));
    });

    test('contributions are counted and earn income', () {
      final years = projectSnowball(const SnowballInputs(
        startValue: 10000,
        startIncome: 400,
        years: 2,
        dividendGrowth: 0,
        priceGrowth: 0,
        reinvest: false,
        monthlyContribution: 100,
      ));
      expect(years.last.contributed, closeTo(12400, 1e-6));
      expect(years[1].income, greaterThan(400));
    });

    test('withholding tax reduces income', () {
      final years = projectSnowball(const SnowballInputs(
        startValue: 10000,
        startIncome: 400,
        years: 1,
        dividendGrowth: 0,
        priceGrowth: 0,
        reinvest: false,
        taxRate: 0.15,
      ));
      expect(years.last.income, closeTo(340, 1e-6));
    });

    test('an empty portfolio projects nothing', () {
      expect(projectSnowball(const SnowballInputs(startValue: 0, startIncome: 0)),
          hasLength(1));
    });

    test('finds the first year reaching a monthly income', () {
      final years = projectSnowball(const SnowballInputs(
        startValue: 10000,
        startIncome: 1200,
        years: 10,
        dividendGrowth: 0.10,
        priceGrowth: 0,
        reinvest: false,
      ));
      final hit = firstYearReaching(years, 150);
      expect(hit, isNotNull);
      expect(hit!.monthlyIncome, greaterThanOrEqualTo(150));
      expect(firstYearReaching(years, 1e9), isNull);
    });
  });

  group('portfolio health', () {
    test('one stock is highly concentrated', () {
      final r = checkHealth(const [HealthPosition(symbol: 'AAPL', value: 1000)]);
      expect(r.score, lessThan(40));
      expect(r.largestWeight, 1);
      expect(r.findings.first.level, HealthLevel.risk);
    });

    test('many equal positions across types and markets score well', () {
      final r = checkHealth([
        for (var i = 0; i < 25; i++)
          HealthPosition(
            symbol: 'S$i',
            value: 100,
            sector: 'Sector ${i % 6}',
            type: i % 3 == 0 ? 'ETF' : 'Stock',
            market: i.isEven ? 'NYSE' : 'TSX',
          ),
      ]);
      expect(r.score, greaterThanOrEqualTo(90));
      expect(r.effectivePositions, closeTo(25, 1e-6));
      expect(r.grade, 'Well diversified');
    });

    test('flags a dominant sector and a dominant payer', () {
      final r = checkHealth(const [
        HealthPosition(symbol: 'A', value: 500, sector: 'Tech', annualIncome: 90),
        HealthPosition(symbol: 'B', value: 300, sector: 'Tech', annualIncome: 5),
        HealthPosition(symbol: 'C', value: 200, sector: 'Energy', annualIncome: 5),
      ]);
      expect(r.largestSector, 'Tech');
      expect(r.largestSectorWeight, closeTo(0.8, 1e-6));
      expect(r.topIncomeSymbol, 'A');
      expect(r.findings.any((f) => f.title.contains('Tech')), isTrue);
      expect(r.findings.any((f) => f.title.contains('pays')), isTrue);
    });

    test('an empty portfolio has no score', () {
      expect(checkHealth(const []).score, 0);
    });
  });

  group('watch item', () {
    test('detects targets being hit', () {
      final w = WatchItem(symbol: 'NVDA', addedAt: DateTime(2026), above: 150, below: 90);
      expect(w.hitBy(160), 'above');
      expect(w.hitBy(80), 'below');
      expect(w.hitBy(120), isNull);
    });

    test('round-trips through a map', () {
      final w = WatchItem(symbol: 'nvda', addedAt: DateTime(2026), above: 150);
      final back = WatchItem.fromMap(w.toMap())!;
      expect(back.symbol, 'NVDA');
      expect(back.above, 150);
      expect(back.below, isNull);
    });

    test('clearing a target removes it', () {
      final w = WatchItem(symbol: 'X', addedAt: DateTime(2026), above: 1, below: 2);
      expect(w.copyWith(clearAbove: true).above, isNull);
      expect(w.copyWith(clearAbove: true).below, 2);
    });
  });

  group('pro service', () {
    test('a trial unlocks one feature and survives a restart', () async {
      final store = _MemoryStore();
      final pro = ProService(store: store);
      await pro.grantTrial(ProFeature.snowball);
      expect(pro.trialEndsAt(ProFeature.snowball), isNotNull);

      final again = ProService(store: store);
      await again.load();
      expect(again.trialEndsAt(ProFeature.snowball), isNotNull);
      expect(again.trialEndsAt(ProFeature.insights), isNull);
    });

    test('a second ad extends the trial', () async {
      final pro = ProService(store: _MemoryStore());
      await pro.grantTrial(ProFeature.insights);
      final first = pro.trialEndsAt(ProFeature.insights)!;
      await pro.grantTrial(ProFeature.insights);
      final second = pro.trialEndsAt(ProFeature.insights)!;
      expect(second.difference(first), ProService.trialLength);
    });

    test('ownership is saved', () async {
      final store = _MemoryStore();
      await ProService(store: store).grantOwnership();
      final again = ProService(store: store);
      await again.load();
      expect(again.owned, isTrue);
      expect(again.isPro, isTrue);
    });
  });
}
