import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/quote.dart';

/// A smooth line chart of value points with 4 date labels on the x-axis.
class PortfolioChart extends StatelessWidget {
  final List<ChartPoint> points;
  final String title;
  const PortfolioChart({super.key, required this.points, this.title = ''});

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
    // Use the theme color at low opacity for the fill under the curve.
    final fillColor = color.withValues(alpha: 0.14);

    double minX = 0, maxX = 0;
    for (var i = 0; i < points.length; i++) {
      final x = points[i].time.millisecondsSinceEpoch.toDouble();
      if (i == 0 || x < minX) minX = x;
      if (i == 0 || x > maxX) maxX = x;
    }
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final p in points) {
      if (p.close < minY) minY = p.close;
      if (p.close > maxY) maxY = p.close;
    }
    final span = maxY - minY;
    minY = (minY - span * 0.08).clamp(0, double.infinity);
    maxY = maxY + span * 0.08;

    // Pick ~4 evenly spaced label positions aligned to the axis interval so
    // the getTitlesWidget lookups actually hit.
    final labelMap = <double, String>{};
    final labelCount = 4;
    final step = (maxX - minX) / (labelCount - 1);
    for (var i = 0; i < labelCount; i++) {
      final t = minX + i * step;
      // nearest point by time
      ChartPoint nearest = points[0];
      double best = (points[0].time.millisecondsSinceEpoch - t).abs().toDouble();
      for (final p in points) {
        final d = (p.time.millisecondsSinceEpoch - t).abs().toDouble();
        if (d < best) {
          best = d;
          nearest = p;
        }
      }
      labelMap[t] = DateFormat('d MMM').format(nearest.time);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(title, style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
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
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (final p in points)
                      FlSpot(p.time.millisecondsSinceEpoch.toDouble(), p.close),
                  ],
                  isCurved: true,
                  curveSmoothness: 0.25,
                  barWidth: 2,
                  color: color,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: fillColor),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        NumberFormat('#,##0.00').format(s.y),
                        TextStyle(
                          color: theme.colorScheme.onSurface,
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
}