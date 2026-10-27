import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/utils/market_identity.dart';

void main() {
  group('marketFor', () {
    test('maps Yahoo venue codes to friendly market names', () {
      expect(marketFor(exchangeCode: 'NMS'), 'NASDAQ');
      expect(marketFor(exchangeCode: 'NGM'), 'NASDAQ');
      expect(marketFor(exchangeCode: 'NCM'), 'NASDAQ');
      expect(marketFor(exchangeCode: 'NYQ'), 'NYSE');
      expect(marketFor(exchangeCode: 'PCX'), 'NYSE Arca');
      expect(marketFor(exchangeCode: 'ASE'), 'NYSE American');
      expect(marketFor(exchangeCode: 'TOR'), 'TSX');
      expect(marketFor(exchangeCode: 'VAN'), 'TSX Venture');
      expect(marketFor(exchangeCode: 'CCC'), 'Crypto');
    });

    test('maps venue names when the code is unknown', () {
      expect(marketFor(exchangeName: 'NasdaqGS'), 'NASDAQ');
      expect(marketFor(exchangeName: 'NYSE'), 'NYSE');
      expect(marketFor(exchangeName: 'Toronto'), 'TSX');
      expect(marketFor(exchangeName: 'NYSEArca'), 'NYSE Arca');
    });

    test('prefers the venue code over the venue name', () {
      // Same name, different venue: the code must win.
      expect(
        marketFor(exchangeCode: 'TOR', exchangeName: 'NasdaqGS'),
        'TSX',
      );
    });

    test('falls back to well-known symbol suffixes', () {
      expect(marketFor(symbol: 'XYZ.TO'), 'TSX');
      expect(marketFor(symbol: 'XYZ.V'), 'TSX Venture');
      expect(marketFor(symbol: 'BTC-USD'), 'Crypto');
    });

    test('returns null when the market is genuinely unknown', () {
      expect(marketFor(symbol: 'AAPL'), isNull);
      expect(marketFor(exchangeCode: 'ZZZZ'), isNull);
    });

    test('crypto quote type always wins', () {
      expect(
        marketFor(exchangeCode: 'NMS', quoteType: 'CRYPTOCURRENCY'),
        'Crypto',
      );
    });
  });

  group('compareMarkets', () {
    test('orders the main markets first, then alphabetically', () {
      final markets = ['Other', 'TSX', 'NYSE', 'NASDAQ', 'Crypto'];
      markets.sort(compareMarkets);
      expect(markets, ['NASDAQ', 'NYSE', 'TSX', 'Crypto', 'Other']);
    });
  });
}
