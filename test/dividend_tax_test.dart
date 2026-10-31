import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/utils/dividend_tax.dart';

void main() {
  group('countryForMarket', () {
    test('the US markets map to the United States', () {
      for (final m in ['NASDAQ', 'NYSE', 'NYSE Arca', 'Cboe', 'OTC']) {
        expect(countryForMarket(m), 'US');
      }
    });

    test('the Canadian markets map to Canada', () {
      expect(countryForMarket('TSX'), 'CA');
      expect(countryForMarket('TSX Venture'), 'CA');
    });

    test('other markets have no withholding country', () {
      expect(countryForMarket('LSE'), '');
      expect(countryForMarket('Crypto'), '');
      expect(countryForMarket(null), '');
    });
  });

  group('withholdingRate', () {
    test('no country means no withholding', () {
      expect(withholdingRate('', 'US'), 0);
      expect(withholdingRate('CA', ''), 0);
    });

    test('a domestic dividend is never withheld', () {
      expect(withholdingRate('CA', 'CA'), 0);
      expect(withholdingRate('US', 'US'), 0);
    });

    test('a Canadian resident keeps 85% of a US dividend', () {
      expect(withholdingRate('CA', 'US'), closeTo(0.15, 0.0001));
    });

    test('a US resident is taxed 15% on Canadian dividends', () {
      // The Canada-US treaty reduces Canada's 25% statutory rate to 15%.
      expect(withholdingRate('US', 'CA'), closeTo(0.15, 0.0001));
    });

    test('without a treaty Canada withholds 25%', () {
      expect(withholdingRate('BR', 'CA'), closeTo(0.25, 0.0001));
    });

    test('without a treaty the US withholds 30%', () {
      expect(withholdingRate('BR', 'US'), closeTo(0.30, 0.0001));
    });

    test('Japan has its own US treaty rate', () {
      expect(withholdingRate('JP', 'US'), closeTo(0.10, 0.0001));
    });

    test('other markets are shown gross', () {
      expect(withholdingRate('CA', 'GB'), 0);
      expect(withholdingRate('GB', 'DE'), 0);
    });

    test('the rate can be shown as a percentage', () {
      expect(withholdingPercent('CA', 'US'), closeTo(15, 0.0001));
    });
  });

  group('countryLabel', () {
    test('names the country', () {
      expect(countryLabel('CA'), 'Canada');
      expect(countryLabel('US'), 'United States');
      expect(countryLabel(''), 'No withholding');
    });
  });
}
