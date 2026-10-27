import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stock_pulse/services/yahoo_service.dart';

/// A client that answers the Yahoo handshake and echoes back whatever
/// symbols were requested.
class _FakeYahooClient extends http.BaseClient {
  final List<Uri> urls = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url;
    urls.add(url);

    if (url.host.contains('fc.yahoo.com')) {
      return http.StreamedResponse(
        const Stream<List<int>>.empty(),
        404,
        headers: const {'set-cookie': 'A3=fake-cookie; Path=/'},
      );
    }
    if (url.path.contains('/v1/test/getcrumb')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('fakeCrumb')),
        200,
      );
    }
    if (url.path.contains('/v7/finance/quote')) {
      // The raw query is what Yahoo sees. Echo the symbols back so the
      // service can be checked end to end. Yahoo decodes each symbol before
      // using it, and the response carries the decoded form.
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
              {
                'symbol': s,
                'shortName': s,
                'regularMarketPrice': s.contains('=') ? 0.71272 : 100.0,
                'currency': 'USD',
                'quoteType': s.contains('=') ? 'CURRENCY' : 'EQUITY',
              },
          ],
        },
      });
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
      );
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('{}')),
      200,
    );
  }
}

void main() {
  group('quote request encoding', () {
    test('FX pairs are percent-encoded exactly once', () async {
      final client = _FakeYahooClient();
      final service = YahooService(client: client);

      await service.quotes({'USDCAD=X'});

      final quoteUrl = client.urls.firstWhere((u) => u.path.contains('/quote'));
      final raw = quoteUrl.query;

      // "%3D" is the encoded "=". "%253D" would mean it was encoded twice,
      // which is what made Yahoo return nothing for currency pairs.
      expect(raw, contains('USDCAD%3DX'));
      expect(raw, isNot(contains('%253D')));
    });

    test('the separator between symbols stays a literal comma', () async {
      final client = _FakeYahooClient();
      final service = YahooService(client: client);

      await service.quotes({'AAPL', 'MSFT'});

      final quoteUrl = client.urls.firstWhere((u) => u.path.contains('/quote'));
      expect(quoteUrl.query, contains('symbols=AAPL,MSFT'));
      expect(quoteUrl.query, isNot(contains('%2C')));
    });

    test('a currency pair comes back with its rate', () async {
      final client = _FakeYahooClient();
      final service = YahooService(client: client);

      final quotes = await service.quotes({'USDCAD=X'});

      expect(quotes.containsKey('USDCAD=X'), isTrue);
      expect(quotes['USDCAD=X']!.price, closeTo(0.71272, 0.00001));
    });

    test('a mixed batch keeps every symbol', () async {
      final client = _FakeYahooClient();
      final service = YahooService(client: client);

      final quotes = await service.quotes({'AAPL', 'USDCAD=X', 'EURCAD=X'});

      expect(quotes.keys.toSet(), {'AAPL', 'USDCAD=X', 'EURCAD=X'});
    });
  });
}
