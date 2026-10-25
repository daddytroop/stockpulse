import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../models/quote.dart';

/// A smooth line chart of value points with 4 date labels on the x-axis.
///
/// When a [benchmark] series (e.g. SPY closes for the same window) is given,
/// both series are normalized to % change since their first point and drawn
/// together - the y-axis becomes percent.
class PortfolioChart extends StatelessWidget {
  final List<ChartPoint> points;
  final List<ChartPoint>? benchmark;
  final String title;
  const PortfolioChart({super.key, required this.points, this.benchmark, this.title = ''});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.length < 2) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Not enough history yet',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
      );
    }

    final color = ColorScheme.fromSeed(seedColor: const Color(0xFF009688)).primary;
    final bench = benchmark;
    final normalized = bench != null && bench.length >= 2;

    final series = normalized ? _normalize(points) : points;
    final benchSeries = normalized ? _normalize(bench) : null;

    double minX = 0, maxX = 0;
    for (var i = 0; i < points.length; i++) {
      final x = points[i].time.millisecondsSinceEpoch.toDouble();
      if (i == 0 || x < minX) minX = x;
      if (i == 0 || x > maxX) maxX = x;
    }

    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final p in series) {
      if (p.close < minY) minY = p.close;
      if (p.close > maxY) maxY = p.close;
    }
    if (benchSeries != null) {
      for (final p in benchSeries) {
        if (p.close < minY) minY = p.close;
        if (p.close > maxY) maxY = p.close;
      }
    }
    final span = maxY - minY;
    if (span <= 0) {
      minY -= 1;
      maxY += 1;
    } else {
      minY -= span * 0.08;
      maxY += span * 0.08;
    }

    // Pick ~4 evenly spaced label positions aligned to the axis interval.
    final labelMap = <double, String>{};
    final labelCount = 4;
    final step = (maxX - minX) / (labelCount - 1);
    for (var i = 0; i < labelCount; i++) {
      final t = minX + i * step;
      ChartPoint nearest = points[0];
      double best = double.infinity;
      for (final p in points) {
        final d = (p.time.millisecondsSinceEpoch - t).abs().toDouble();
        if (d < best) {
          best = d;
          nearest = p;
        }
      }
      labelMap[t] = DateFormat('d MMM').format(nearest.time);
    }

    final fillColor = color.withValues(alpha: 0.14);
    final benchColor = theme.hintColor;

    final bars = <LineChartBarData>[
      LineChartBarData(
        spots: [for (final p in series) FlSpot(p.time.millisecondsSinceEpoch.toDouble(), p.close)],
        isCurved: true,
        curveSmoothness: 0.25,
        barWidth: 2.2,
        color: color,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: normalized ? BarAreaData(show: false) : BarAreaData(show: true, color: fillColor),
      ),
    ];
    if (benchSeries != null) {
      bars.add(LineChartBarData(
        spots: [
          for (final p in benchSeries) FlSpot(p.time.millisecondsSinceEpoch.toDouble(), p.close),
        ],
        isCurved: true,
        curveSmoothness: 0.25,
        barWidth: 1.4,
        color: benchColor,
        dashArray: [4, 3],
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty || normalized)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              children: [
                if (title.isNotEmpty)
                  Text(title,
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
                const Spacer(),
                if (normalized) ...[
                  _legendDot(color),
                  const SizedBox(width: 4),
                  Text('You', style: theme.textTheme.labelSmall),
                  const SizedBox(width: 10),
                  _legendDot(benchColor),
                  const SizedBox(width: 4),
                  Text('SPY', style: theme.textTheme.labelSmall),
                ],
              ],
            ),
          ),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.none(),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: normalized
                    ? AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: _yInterval(minY, maxY),
                          getTitlesWidget: (v, meta) => Text(
                            '${v.round()}%',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.hintColor, fontSize: 10),
                          ),
                        ),
                      )
                    : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: (maxX - minX) / (labelCount - 1),
                    getTitlesWidget: (value, meta) => Text(
                      labelMap[value] ?? '',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                    ),
                  ),
                ),
              ),
              lineBarsData: bars,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        normalized ? '${s.y.toStringAsFixed(1)}%' : NumberFormat('#,##0.00').format(s.y),
                        TextStyle(
                          color: s.bar.color ?? theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color c) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  double _yInterval(double minY, double maxY) {
    final span = (maxY - minY).abs();
    final raw = span / 4;
    const candidates = [
      0.5, 1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 5000,
      10000, 20000, 50000, 100000, 250000, 500000, 1000000,
    ];
    for (final c in candidates) {
      if (c >= raw) return c.toDouble();
    }
    return 1000000.0;
  }

  List<ChartPoint> _normalize(List<ChartPoint> raw) {
    if (raw.length < 2) return raw;
    final base = raw.first.close;
    if (base == 0) return raw;
    return [for (final p in raw) ChartPoint(p.time, (p.close / base - 1) * 100)];
  }
}