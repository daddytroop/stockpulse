import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/utils/indicators.dart';

void main() {
  final ramp = [for (var i = 1; i <= 30; i++) i.toDouble()];

  test('SMA averages the last n bars and is empty before that', () {
    final s = sma([1, 2, 3, 4, 5], 3);
    expect(s, [null, null, 2, 3, 4]);
  });

  test('EMA starts at the SMA and then follows the price', () {
    final e = ema([2, 4, 6, 8, 10, 12], 3);
    expect(e.take(2), [null, null]);
    expect(e[2], 4); // SMA of 2, 4, 6
    // k = 0.5: 8 * .5 + 4 * .5 = 6
    expect(e[3], 6);
    expect(e[5], closeTo(10, 1e-9));
  });

  test('Bollinger bands collapse on a flat price', () {
    final b = bollinger(List.filled(25, 10.0));
    expect(b.middle.last, 10);
    expect(b.upper.last, 10);
    expect(b.lower.last, 10);
    expect(b.upper[18], isNull);
  });

  test('Bollinger bands are symmetric around the middle', () {
    final b = bollinger(ramp);
    final i = ramp.length - 1;
    expect(b.upper[i]! - b.middle[i]!, closeTo(b.middle[i]! - b.lower[i]!, 1e-9));
    expect(b.upper[i]! > b.middle[i]!, isTrue);
  });

  test('RSI is 100 on a steady climb and 0 on a steady fall', () {
    expect(rsi(ramp).last, 100);
    expect(rsi(ramp.reversed.toList()).last, 0);
    expect(rsi(ramp)[13], isNull);
    expect(rsi(ramp)[14], isNotNull);
  });

  test('RSI stays between 0 and 100 on a choppy series', () {
    final chop = [for (var i = 0; i < 60; i++) 100 + (i.isEven ? 3.0 : -2.0) * (i % 7)];
    for (final v in rsi(chop).whereType<double>()) {
      expect(v, inInclusiveRange(0, 100));
    }
  });

  test('MACD is positive on a rising series and the histogram lines up', () {
    final m = macd([for (var i = 0; i < 60; i++) 50 + i * 0.5]);
    expect(m.macd.last, greaterThan(0));
    expect(m.signal.last, isNotNull);
    expect(m.histogram.last, closeTo(m.macd.last! - m.signal.last!, 1e-12));
    expect(m.macd[24], isNull);
    expect(m.macd[25], isNotNull);
  });

  test('every indicator keeps the input length', () {
    for (final list in [
      sma(ramp, 5),
      ema(ramp, 5),
      rsi(ramp),
      macd(ramp).macd,
      bollinger(ramp).upper,
    ]) {
      expect(list.length, ramp.length);
    }
  });
}
