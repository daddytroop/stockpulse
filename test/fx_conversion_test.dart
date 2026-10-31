import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stock_pulse/providers/portfolio_provider.dart';
import 'package:stock_pulse/services/store.dart';
import 'package:stock_pulse/services/yahoo_service.dart';
import 'package:stock_pulse/utils/fx_currency.dart';

/// A client that answers the Yahoo handshake and the quote endpoint with a
/// fixed set of prices.
class _FakeYahoo extends http.BaseClient {
  final Map<String, double> prices;
  final Map<String, String> currencies;

  _FakeYahoo(this.prices, this.currencies);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url;
    if (url.host.contains('fc.yahoo.com')) {
      return http.StreamedResponse(
        const Stream<List<int>>.empty(),
        404,
        headers: const {'set-cookie': 'A3=fake; Path=/'},
      );
    }
    if (url.path.contains('/v1/test/getcrumb')) {
      return http.StreamedResponse(Stream.value(utf8.encode('crumb')), 200);
    }
    if (url.path.contains('/v7/finance/quote')) {
      final raw = url.query.split('&').firstWhere(
            (p) => p.startsWith('symbols='),
            orElse: () => 'symbols=',
          );
      final symbols = raw
          .substring('symbols='.length)
          .split(',')
          .map(Uri.decodeComponent)
          .toList();
      final body = jsonEncode({
        'quoteResponse': {
          'result': [
            for (final s in symbols)
              if (prices.containsKey(s))
                {
                  'symbol': s,
                  'shortName': s,
                  'regularMarketPrice': prices[s],
                  'currency': currencies[s] ?? 'USD',
                  'quoteType': s.contains('=X') ? 'CURRENCY' : 'EQUITY',
                },
          ],
        },
      });
      return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }
}

/// A store that keeps everything in memory.
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
  group('fx currency helpers', () {
    test('the pair symbol is always against the dollar', () {
      expect(fxSymbol('SGD'), 'SGDUSD=X');
      expect(fxSymbol('CAD'), 'CADUSD=X');
      expect(fxSymbol('EUR'), 'EURUSD=X');
    });

    test('pence are converted into pounds', () {
      expect(fxSymbol('GBp'), 'GBPUSD=X');
      expect(fxUnitFactor('GBp'), 0.01);
      expect(fxUnitFactor('GBP'), 1.0);
      expect(fxUnitFactor('USD'), 1.0);
    });
  });

  group('currency conversion', () {
    late _FakeYahoo yahoo;
    late PortfolioProvider provider;

    setUp(() async {
      yahoo = _FakeYahoo(
        {
          'AAPL': 100,
          'D05.SI': 5,
          'SGDUSD=X': 0.74,
          'CADUSD=X': 0.7127,
          'USDUSD=X': 1,
        },
        {
          'AAPL': 'USD',
          'D05.SI': 'SGD',
        },
      );
      provider = PortfolioProvider(
        yahoo: YahooService(client: yahoo),
        store: _MemoryStore(),
      );
      await provider.load();
      // Remove the demo portfolio so the test controls every holding.
      for (final p in provider.portfolios.where((p) => p.name.contains('Sample'))) {
        provider.deletePortfolio(p.id);
      }
    });

    test('a portfolio converts into the display currency', () async {
      final id = provider.active.id;
      await provider.addHolding(
          portfolioId: id, symbol: 'AAPL', quantity: 10, avgCost: 90);
      await provider.setDisplayCurrency('CAD');

      final totals = provider.totalsFor(provider.active);
      expect(totals.converted, isTrue);
      // 10 x 100 USD, and 1 USD = 1 / 0.7127 CAD.
      expect(totals.marketValue, closeTo(1000 / 0.7127, 0.01));
      expect(provider.fxMissingCurrencies, isEmpty);
    });

    test('a currency with no direct cross still converts', () async {
      final id = provider.active.id;
      await provider.addHolding(
          portfolioId: id, symbol: 'D05.SI', quantity: 10, avgCost: 4);
      await provider.setDisplayCurrency('CAD');

      final totals = provider.totalsFor(provider.active);
      // Yahoo has no SGDCAD=X, but SGDUSD=X and CADUSD=X both exist, so the
      // rate is found through the dollar.
      expect(totals.converted, isTrue);
      expect(totals.marketValue, closeTo(50 * 0.74 / 0.7127, 0.01));
      expect(provider.fxMissingCurrencies, isEmpty);
    });

    test('a currency with no rate at all is reported', () async {
      final id = provider.active.id;
      await provider.addHolding(
          portfolioId: id, symbol: 'AAPL', quantity: 10, avgCost: 90);
      // A currency Yahoo does not quote at all.
      await provider.setDisplayCurrency('ZWL');

      final totals = provider.totalsFor(provider.active);
      expect(totals.converted, isFalse);
      // The holding that could not be converted is named.
      expect(provider.fxMissingCurrencies, contains('USD'));
    });
  });
}
