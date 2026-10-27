import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/services/logo_service.dart';

void main() {
  group('LogoService', () {
    test('resolves well known tickers without a network lookup', () async {
      final service = LogoService();
      final url = await service.logoUrlFor('AAPL');
      expect(url, isNotNull);
      expect(url, contains('commons.wikimedia.org'));
      expect(url, contains('Apple'));
    });

    test('is case insensitive', () async {
      final service = LogoService();
      expect(
        await service.logoUrlFor('aapl'),
        await service.logoUrlFor('AAPL'),
      );
    });

    test('returns null for a blank symbol', () async {
      final service = LogoService();
      expect(await service.logoUrlFor('  '), isNull);
    });

    test('caches the result so a symbol is only resolved once', () async {
      final service = LogoService();
      final first = await service.logoUrlFor('MSFT');
      final second = await service.logoUrlFor('MSFT');
      expect(first, second);
    });
  });

  group('company name matching', () {
    test('matches a company name against a candidate label', () {
      expect(
        LogoService.sharedTokensForTest('Citigroup Inc.', 'Citigroup'),
        1,
      );
      expect(
        LogoService.sharedTokensForTest('Citigroup Inc.', 'Stellantis'),
        0,
      );
    });

    test('ignores legal suffixes so the real name still matches', () {
      expect(
        LogoService.sharedTokensForTest('Merck & Co., Inc.', 'Merck & Co.'),
        1,
      );
    });
  });
}
