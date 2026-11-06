import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:stock_pulse/services/yahoo_service.dart';

/// Behaves like Yahoo: quoteSummary answers 401 unless the crumb is sent.
class _CrumbCheckingClient extends http.BaseClient {
  final List<Uri> urls = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url;
    urls.add(url);
    http.StreamedResponse reply(String body, [int status = 200]) =>
        http.StreamedResponse(Stream.value(utf8.encode(body)), status);

    if (url.host.contains('fc.yahoo.com')) {
      return http.StreamedResponse(
        const Stream<List<int>>.empty(),
        404,
        headers: const {'set-cookie': 'A3=fake-cookie; Path=/'},
      );
    }
    if (url.path.contains('/v1/test/getcrumb')) return reply('fakeCrumb');
    if (url.path.contains('/v10/finance/quoteSummary/')) {
      if (url.queryParameters['crumb'] != 'fakeCrumb') {
        return reply('{"finance":{"error":{"code":"Unauthorized"}}}', 401);
      }
      return reply(jsonEncode({
        'quoteSummary': {
          'result': [
            {
              'assetProfile': {
                'sectorDisp': 'Technology',
                'industryDisp': 'Consumer Electronics',
              },
              'calendarEvents': {'dividendDate': 1767225600},
            },
          ],
        },
      }));
    }
    return reply('{}', 404);
  }
}

void main() {
  test('company profiles send the crumb Yahoo requires', () async {
    final client = _CrumbCheckingClient();
    final yahoo = YahooService(client: client);

    final profile = await yahoo.companyProfile('AAPL');

    expect(profile, isNotNull);
    expect(profile!.industry, 'Consumer Electronics');
    expect(profile.sector, 'Technology');
  });

  test('dividend calendar requests send the crumb too', () async {
    final client = _CrumbCheckingClient();
    final yahoo = YahooService(client: client);

    await yahoo.calendarEvents('AAPL');

    final calls = client.urls
        .where((u) => u.path.contains('/v10/finance/quoteSummary/'))
        .toList();
    expect(calls, isNotEmpty);
    expect(calls.every((u) => u.queryParameters['crumb'] == 'fakeCrumb'), isTrue);
  });
}
