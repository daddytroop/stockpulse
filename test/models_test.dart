import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/models/dividends.dart';
import 'package:stock_pulse/models/holding.dart';
import 'package:stock_pulse/models/portfolio.dart';
import 'package:stock_pulse/models/quote.dart';

void main() {
  group('Holding', () {
    test('JSON roundtrip preserves fields', () {
      final h = Holding(
        symbol: 'AAPL',
        name: 'Apple Inc.',
        currency: 'USD',
        quantity: 11.5,
        avgCost: 101.25,
        addedAt: DateTime(2026, 1, 2),
      );
      final back = Holding.fromMap(h.toMap());
      expect(back.symbol, 'AAPL');
      expect(back.quantity, 11.5);
      expect(back.avgCost, 101.25);
      expect(back.addedAt?.toIso8601String(), '2026-01-02T00:00:00.000');
    });

    test('mergeWith weights the average cost', () {
      final h = Holding(symbol: 'X', quantity: 10, avgCost: 100);
      final merged = h.mergeWith(30, 60);
      expect(merged.quantity, 40);
      expect(merged.avgCost, (10 * 100 + 30 * 60) / 40);
    });

    test('costBasis computes qty * avg', () {
      expect(Holding(symbol: 'X', quantity: 4, avgCost: 12.5).costBasis, 50.0);
    });
  });

  group('Portfolio', () {
    test('JSON roundtrip with holdings', () {
      const p = Portfolio(id: 'p1', name: 'TFSA');
      final restored = Portfolio.fromMap(p.toMap());
      expect(restored.name, 'TFSA');
      expect(restored.holdings, isEmpty);
    });

    test('fromMap keys holdings by symbol', () {
      final m = {
        'id': 'p1',
        'name': 'Main',
        'holdings': [
          {'symbol': 'aapl', 'quantity': 5, 'avgCost': 100},
        ],
      };
      final p = Portfolio.fromMap(m);
      expect(p.holdings.containsKey('AAPL'), isTrue);
    });
  });

  group('Quote', () {
    test('parses v7 quote JSON', () {
      final q = Quote.fromV7Json({
        'symbol': 'SCHD',
        'shortName': 'Schwab US Dividend Equity ETF',
        'currency': 'USD',
        'regularMarketPrice': 35.27,
        'regularMarketPreviousClose': 35.1,
        'regularMarketChange': 0.17,
        'regularMarketChangePercent': 0.4845,
        'trailingAnnualDividendRate': 0.85,
        'trailingAnnualDividendYield': 0.024,
        'dividendDate': 1786579200,
        'earningsTimestampStart': 0,
        'quoteType': 'ETF',
      });
      expect(q.price, 35.27);
      expect(q.dayChange, 0.17);
      expect(q.dividendRate, 0.85);
      expect(q.dividendPayDate, isNotNull);
      expect(q.earningsDate, isNull);
    });

    test('parses chart meta fallback', () {
      final q = Quote.fromChartJson({
        'symbol': 'BTC-USD',
        'currency': 'USD',
        'regularMarketPrice': 79715.87,
        'regularMarketChangePercent': 0.55,
        'instrumentType': 'CRYPTOCURRENCY',
      }, previousClose: null, closes: [1.0, 2.0]);
      expect(q.dayChangePercent, 0.55);
      // Falls back to the second-to-last close when the meta has none.
      expect(q.previousClose, 1.0);
    });

    test('JSON roundtrip', () {
      final q = Quote.fromV7Json({
        'symbol': 'AAPL',
        'shortName': 'Apple Inc.',
        'currency': 'USD',
        'regularMarketPrice': 347.72,
        'regularMarketChange': -0.49,
        'regularMarketChangePercent': -0.14,
      });
      final back = Quote.fromMap(q.toMap());
      expect(back.symbol, q.symbol);
      expect(back.price, q.price);
      expect(back.dayChangePercent, q.dayChangePercent);
    });

    test('keeps the exchange, market time and market state', () {
      final q = Quote.fromV7Json({
        'symbol': 'RY.TO',
        'shortName': 'Royal Bank of Canada',
        'currency': 'CAD',
        'regularMarketPrice': 284.26,
        'exchange': 'TOR',
        'fullExchangeName': 'Toronto',
        'marketState': 'POSTPOST',
        'regularMarketTime': 1793044800,
      });
      expect(q.exchange, 'TOR');
      expect(q.fullExchangeName, 'Toronto');
      expect(q.marketState, 'POSTPOST');
      expect(q.marketTime, isNotNull);
      expect(
        q.marketTime!.millisecondsSinceEpoch,
        1793044800 * 1000,
      );

      final back = Quote.fromMap(q.toMap());
      expect(back.exchange, 'TOR');
      expect(back.fullExchangeName, 'Toronto');
      expect(back.marketState, 'POSTPOST');
      expect(back.marketTime, q.marketTime);
    });

    test('chart fallback keeps the venue code and name', () {
      final q = Quote.fromChartJson({
        'symbol': 'AAPL',
        'currency': 'USD',
        'regularMarketPrice': 343.91,
        'exchangeName': 'NMS',
        'fullExchangeName': 'NasdaqGS',
        'regularMarketTime': 1793044801,
      }, previousClose: null, closes: null);
      expect(q.exchange, 'NMS');
      expect(q.fullExchangeName, 'NasdaqGS');
      expect(q.marketTime, isNotNull);
    });
  });

  group('DividendInfo', () {
    DividendInfo info(List<int> ts, List<double> amounts) => DividendInfo(
          symbol: 'X',
          payments: [
            for (var i = 0; i < ts.length; i++)
              DividendPayment(exDate: DateTime.fromMillisecondsSinceEpoch(ts[i] * 1000), amount: amounts[i]),
          ]..sort((a, b) => a.exDate.compareTo(b.exDate)),
          cachedAt: DateTime.now(),
        );

    test('quarterly cadence -> 4 periods, ttm sums 4 payments', () {
      const day = Duration(days: 1);
      final base = DateTime(2026, 6, 1);
      int ms(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
      final i = info(
        [ms(base), ms(base.add(day * 91)), ms(base.add(day * 182)), ms(base.add(day * 273))],
        [0.25, 0.25, 0.25, 0.25],
      );
      expect(i.periodsPerYear, 4);
      expect(i.ttmPerShare, closeTo(1.0, 0.0001));
      expect(i.medianGapDays, 91);
    });

    test('monthly cadence -> 12 periods', () {
      int ms(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
      final base = DateTime(2026, 6, 1);
      final dates = <int>[];
      final amounts = <double>[];
      for (var k = 0; k < 6; k++) {
        dates.add(ms(base.subtract(Duration(days: 30 * k))));
        amounts.add(0.02);
      }
      final i = info(dates, amounts);
      expect(i.periodsPerYear, 12);
    });

    test('empty payments are safe', () {
      final i = DividendInfo(symbol: 'Y', payments: const [], cachedAt: DateTime.now());
      expect(i.ttmPerShare, 0);
      expect(i.periodsPerYear, 4);
      expect(i.lastAmount, 0);
    });
  });

  group('DividendPayment', () {
    test('JSON roundtrip', () {
      final p = DividendPayment(exDate: DateTime(2026, 8, 10), amount: 0.27);
      final back = DividendPayment.fromMap(p.toMap());
      // Timestamp stored in whole seconds.
      expect(back.amount, 0.27);
      expect(back.exDate.millisecondsSinceEpoch ~/ 1000, p.exDate.millisecondsSinceEpoch ~/ 1000);
    });
  });
}