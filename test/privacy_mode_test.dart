import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/utils/formatters.dart';
import 'package:stock_pulse/utils/privacy.dart';

void main() {
  group('hide balances', () {
    tearDown(() => PrivacyMode.hideBalances = false);

    test('money is shown normally by default', () {
      expect(PrivacyMode.hideBalances, isFalse);
      expect(fmtMoney(1234.5, currency: 'USD'), contains('1,234.50'));
      expect(fmtSignedMoney(10, currency: 'USD'), contains('10.00'));
    });

    test('every currency amount is hidden when the mode is on', () {
      PrivacyMode.hideBalances = true;
      expect(fmtMoney(1234.5, currency: 'USD'), '••••');
      expect(fmtSignedMoney(-10, currency: 'CAD'), '••••');
    });

    test('percentages and quantities are not hidden', () {
      PrivacyMode.hideBalances = true;
      expect(fmtPct(12.34), '+12.34%');
      expect(fmtQty(1500), '1,500');
    });

    test('a missing value still shows a dash', () {
      PrivacyMode.hideBalances = true;
      expect(fmtMoney(null, currency: 'USD'), '–');
    });
  });
}
