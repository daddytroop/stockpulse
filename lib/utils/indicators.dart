import 'dart:math';

/// Technical indicators for the advanced chart.
///
/// Every function returns a list the same length as its input, with null
/// where the indicator has no value yet (before enough bars exist), so the
/// results line up bar for bar with the prices.

/// Simple moving average over [period] bars.
List<double?> sma(List<double> values, int period) {
  final out = List<double?>.filled(values.length, null);
  if (period <= 0) return out;
  var sum = 0.0;
  for (var i = 0; i < values.length; i++) {
    sum += values[i];
    if (i >= period) sum -= values[i - period];
    if (i >= period - 1) out[i] = sum / period;
  }
  return out;
}

/// Exponential moving average over [period] bars, seeded with the SMA of
/// the first [period] bars (the common charting convention).
List<double?> ema(List<double> values, int period) {
  final out = List<double?>.filled(values.length, null);
  if (period <= 0 || values.length < period) return out;
  final k = 2 / (period + 1);
  var prev = values.take(period).reduce((a, b) => a + b) / period;
  out[period - 1] = prev;
  for (var i = period; i < values.length; i++) {
    prev = values[i] * k + prev * (1 - k);
    out[i] = prev;
  }
  return out;
}

/// Bollinger bands: the [period]-bar SMA, and that plus/minus [width]
/// population standard deviations.
({List<double?> middle, List<double?> upper, List<double?> lower}) bollinger(
    List<double> values,
    {int period = 20,
    double width = 2}) {
  final middle = sma(values, period);
  final upper = List<double?>.filled(values.length, null);
  final lower = List<double?>.filled(values.length, null);
  for (var i = period - 1; i < values.length; i++) {
    final m = middle[i];
    if (m == null) continue;
    var variance = 0.0;
    for (var j = i - period + 1; j <= i; j++) {
      variance += (values[j] - m) * (values[j] - m);
    }
    final sd = sqrt(variance / period);
    upper[i] = m + width * sd;
    lower[i] = m - width * sd;
  }
  return (middle: middle, upper: upper, lower: lower);
}

/// Relative strength index with Wilder's smoothing, 0..100.
List<double?> rsi(List<double> values, {int period = 14}) {
  final out = List<double?>.filled(values.length, null);
  if (values.length <= period) return out;
  var gain = 0.0, loss = 0.0;
  for (var i = 1; i <= period; i++) {
    final d = values[i] - values[i - 1];
    if (d >= 0) {
      gain += d;
    } else {
      loss -= d;
    }
  }
  gain /= period;
  loss /= period;
  double value(double g, double l) => l == 0 ? (g == 0 ? 50 : 100) : 100 - 100 / (1 + g / l);
  out[period] = value(gain, loss);
  for (var i = period + 1; i < values.length; i++) {
    final d = values[i] - values[i - 1];
    gain = (gain * (period - 1) + max(d, 0)) / period;
    loss = (loss * (period - 1) + max(-d, 0)) / period;
    out[i] = value(gain, loss);
  }
  return out;
}

/// MACD: fast EMA minus slow EMA, its signal-line EMA, and the histogram
/// (MACD minus signal).
({List<double?> macd, List<double?> signal, List<double?> histogram}) macd(
    List<double> values,
    {int fast = 12,
    int slow = 26,
    int signalPeriod = 9}) {
  final f = ema(values, fast);
  final s = ema(values, slow);
  final line = List<double?>.generate(
      values.length, (i) => f[i] != null && s[i] != null ? f[i]! - s[i]! : null);

  // The signal is an EMA of the MACD line, over the bars where it exists.
  final start = line.indexWhere((v) => v != null);
  final signal = List<double?>.filled(values.length, null);
  if (start >= 0) {
    final defined = [for (var i = start; i < line.length; i++) line[i]!];
    final sig = ema(defined, signalPeriod);
    for (var i = 0; i < sig.length; i++) {
      signal[start + i] = sig[i];
    }
  }
  final histogram = List<double?>.generate(values.length,
      (i) => line[i] != null && signal[i] != null ? line[i]! - signal[i]! : null);
  return (macd: line, signal: signal, histogram: histogram);
}
