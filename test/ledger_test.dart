import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/models/dividends.dart';
import 'package:stock_pulse/models/quote.dart';
import 'package:stock_pulse/models/transaction.dart';
import 'package:stock_pulse/services/ledger.dart';

void main() {
  DateTime d(int daysAgo) => DateTime.now().subtract(Duration(days: daysAgo));

  group('sharesAt', () {
    test('replays buys and sells up to the given date', () {
      final txns = [
        Txn(kind: 'buy', quantity: 10, unitPrice: 100, date: d(40)),
        Txn(kind: 'buy', quantity: 5, unitPrice: 110, date: d(20)),
        Txn(kind: 'sell', quantity: 4, unitPrice: 120, date: d(10)),
      ];
      expect(sharesAt(d(41), txns), 0);
      expect(sharesAt(d(30), txns), 10);
      expect(sharesAt(d(0), txns), 11);
    });

    test('same-day transactions count as held', () {
      final txns = [Txn(kind: 'buy', quantity: 7, unitPrice: 5, date: d(0))];
      expect(sharesAt(d(0), txns), 7);
    });
  });

  group('replayRealizedPnl', () {
    test('buys then a partial sell', () {
      final realized = replayRealizedPnl([
        Txn(kind: 'buy', quantity: 10, unitPrice: 100, date: d(40)),
        Txn(kind: 'sell', quantity: 5, unitPrice: 150, date: d(5)),
      ]);
      expect(realized, closeTo(250, 0.0001));
    });

    test('fees reduce realized P/L', () {
      final realized = replayRealizedPnl([
        Txn(kind: 'buy', quantity: 2, unitPrice: 100, fee: 4, date: d(40)),
        Txn(kind: 'sell', quantity: 2, unitPrice: 130, fee: 2, date: d(5)),
      ]);
      // avg cost = (200+4)/2 = 102 -> realized = (130-102)*2 - 2 = 54
      expect(realized, closeTo(54, 0.0001));
    });

    test('sell without recorded buys is null (legacy positions)', () {
      final realized = replayRealizedPnl([
        Txn(kind: 'sell', quantity: 5, unitPrice: 150, date: d(5)),
      ]);
      expect(realized, isNull);
    });

    test('no sells at all is null', () {
      final realized = replayRealizedPnl([
        Txn(kind: 'buy', quantity: 5, unitPrice: 150, date: d(5)),
      ]);
      expect(realized, isNull);
    });
  });

  group('dividendsReceived', () {
    final payments = [
      DividendPayment(exDate: d(90), amount: 0.5),
      DividendPayment(exDate: d(40), amount: 0.6),
      DividendPayment(exDate: d(1), amount: 0.7),
    ];

    test('legacy position without txns uses current qty after start date', () {
      final got = dividendsReceived(
        txns: const [],
        payments: payments,
        currentQty: 10,
        holdingStart: d(100),
      );
      expect(got, closeTo((0.5 + 0.6 + 0.7) * 10, 0.0001));
    });

    test('legacy position filters payments before start', () {
      final got = dividendsReceived(
        txns: const [],
        payments: payments,
        currentQty: 10,
        holdingStart: d(50),
      );
      expect(got, closeTo((0.6 + 0.7) * 10, 0.0001));
    });

    test('txn timeline uses the share count at each ex-date', () {
      final txns = [
        Txn(kind: 'buy', quantity: 10, unitPrice: 20, date: d(100)),
        Txn(kind: 'buy', quantity: 10, unitPrice: 22, date: d(70)),
        Txn(kind: 'sell', quantity: 15, unitPrice: 25, date: d(20)),
      ];
      final got = dividendsReceived(
        txns: txns,
        payments: payments,
        currentQty: 5,
        holdingStart: d(100),
      );
      // At ex -90d: 10 shares x 0.5 = 5 ; at -40d: 20 x 0.6 = 12; at -1d: 5 x 0.7 = 3.5
      expect(got, closeTo(5 + 12 + 3.5, 0.0001));
    });
  });

  group('dividendsReceivedInRange', () {
    final payments = [
      DividendPayment(exDate: d(90), amount: 0.5),
      DividendPayment(exDate: d(40), amount: 0.6),
      DividendPayment(exDate: d(1), amount: 0.7),
    ];

    test('only the payments inside the window count', () {
      final got = dividendsReceivedInRange(
        txns: const [],
        payments: payments,
        currentQty: 10,
        holdingStart: d(100),
        from: d(50),
        to: d(0),
      );
      expect(got, closeTo((0.6 + 0.7) * 10, 0.0001));
    });

    test('a window with no payments is zero', () {
      final got = dividendsReceivedInRange(
        txns: const [],
        payments: payments,
        currentQty: 10,
        holdingStart: d(100),
        from: d(500),
        to: d(400),
      );
      expect(got, 0);
    });

    test('the share count at the ex-date is used', () {
      final txns = [
        Txn(kind: 'buy', quantity: 10, unitPrice: 20, date: d(100)),
        Txn(kind: 'sell', quantity: 4, unitPrice: 25, date: d(50)),
      ];
      final got = dividendsReceivedInRange(
        txns: txns,
        payments: payments,
        currentQty: 6,
        holdingStart: d(100),
        from: d(50),
        to: d(0),
      );
      // At -40d: 10 shares x 0.6 = 6 ; at -1d: 6 shares x 0.7 = 4.2
      expect(got, closeTo(6 + 4.2, 0.0001));
    });
  });

  group('dripProjection', () {
    test('5 years of compounding at 5%', () {
      final v = dripProjection(100, 5);
      // 100 * ((1.05^5)-1)/0.05 = 552.5625
      expect(v, closeTo(552.5625, 0.001));
    });

    test('zero yield is zero', () {
      expect(dripProjection(100, 0), 0);
      expect(dripProjection(0, 5), 0);
    });
  });

  group('dividend growth', () {
    test('year totals and YoY growth percent', () {
      final payments = [
        DividendPayment(exDate: DateTime(2024, 3, 15), amount: 0.25),
        DividendPayment(exDate: DateTime(2024, 6, 15), amount: 0.25),
        DividendPayment(exDate: DateTime(2024, 9, 15), amount: 0.25),
        DividendPayment(exDate: DateTime(2024, 12, 15), amount: 0.25),
        DividendPayment(exDate: DateTime(2025, 3, 15), amount: 0.26),
        DividendPayment(exDate: DateTime(2025, 6, 15), amount: 0.26),
        DividendPayment(exDate: DateTime(2025, 9, 15), amount: 0.26),
        DividendPayment(exDate: DateTime(2025, 12, 15), amount: 0.26),
      ];
      final totals = dividendYearTotals(payments);
      expect(totals[2024], closeTo(1.0, 0.0001));
      expect(totals[2025], closeTo(1.04, 0.0001));
      expect(dividendGrowthPct(payments), closeTo(4.0, 0.01));
    });

    test('growth needs two years with payments', () {
      final oneYear = [
        DividendPayment(exDate: DateTime(2025, 3, 15), amount: 0.26),
      ];
      expect(dividendGrowthPct(oneYear), isNull);
    });
  });

  group('normalizePercent', () {
    test('rescales a series to percent change', () {
      final now = DateTime(2026, 1, 1);
      final series = [
        ChartPoint(now, 12.0),
        ChartPoint(now.add(const Duration(days: 1)), 15.0),
      ];
      final norm = normalizePercent(series)!;
      expect(norm.first.close, 0);
      expect(norm[1].close, closeTo(25, 0.0001));
    });

    test('rejects short series', () {
      final now = DateTime(2026, 1, 1);
      expect(normalizePercent([ChartPoint(now, 10.0)]), isNull);
    });
  });

  group('StockSplit', () {
    test('parses event json and computes multiplier', () {
      final s = StockSplit.fromEventJson({
        'date': 1600000000,
        'numerator': 4,
        'denominator': 1,
        'splitRatio': '4:1',
      });
      expect(s.multiplier, 4);
      expect(s.numerator, 4);
      expect(s.denominator, 1);
    });
  });
}