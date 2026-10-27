import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../models/quote.dart';
import '../theme/app_colors.dart';

/// A smooth, interactive line chart of value points.
///
/// Design goals:
///  * the line draws itself in when the data arrives,
///  * dragging scrubs the chart and reads out the exact value under the
///    finger,
///  * the area under the line is a soft gradient rather than a flat wash,
///  * the benchmark overlay stays readable but clearly secondary.
class PortfolioChart extends StatefulWidget {
  final List<ChartPoint> points;
  final List<ChartPoint>? benchmark;
  final String title;
  final String? currency;

  /// Formats the value shown in the scrub readout.
  final String Function(double)? valueFormatter;

  const PortfolioChart({
    super.key,
    required this.points,
    this.benchmark,
    this.title = '',
    this.currency,
    this.valueFormatter,
  });

  @override
  State<PortfolioChart> createState() => _PortfolioChartState();
}

class _PortfolioChartState extends State<PortfolioChart> {
  /// Index of the point currently being scrubbed, or null when idle.
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.points.length < 2) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Not enough history yet',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
      );
    }

    final colors = AppColors.of(context);
    final color = theme.colorScheme.primary;
    final bench = widget.benchmark;
    final normalized = bench != null && bench.length >= 2;

    final series = normalized ? _normalize(widget.points) : widget.points;
    final benchSeries = normalized ? _normalize(bench) : null;

    double minX = 0, maxX = 0;
    for (var i = 0; i < widget.points.length; i++) {
      final x = widget.points[i].time.millisecondsSinceEpoch.toDouble();
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
      minY -= span * 0.10;
      maxY += span * 0.10;
    }

    final labelCount = 4;
    final labelMap = <double, String>{};
    final step = (maxX - minX) / (labelCount - 1);
    for (var i = 0; i < labelCount; i++) {
      final t = minX + i * step;
      ChartPoint nearest = widget.points[0];
      double best = double.infinity;
      for (final p in widget.points) {
        final d = (p.time.millisecondsSinceEpoch - t).abs().toDouble();
        if (d < best) {
          best = d;
          nearest = p;
        }
      }
      labelMap[t] = DateFormat('d MMM').format(nearest.time);
    }

    // The readout while scrubbing.
    final readout = _activeIndex == null
        ? null
        : _Readout(
            point: widget.points[_activeIndex!.clamp(0, widget.points.length - 1)],
            benchmarkPoint: benchSeries == null
                ? null
                : benchSeries[_activeIndex!.clamp(0, benchSeries.length - 1)],
            normalized: normalized,
            currency: widget.currency,
            valueFormatter: widget.valueFormatter,
          );

    final bars = <LineChartBarData>[
      LineChartBarData(
        spots: [
          for (final p in series)
            FlSpot(p.time.millisecondsSinceEpoch.toDouble(), p.close),
        ],
        isCurved: true,
        curveSmoothness: 0.28,
        barWidth: 2.6,
        color: color,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    ];
    if (benchSeries != null) {
      bars.add(LineChartBarData(
        spots: [
          for (final p in benchSeries)
            FlSpot(p.time.millisecondsSinceEpoch.toDouble(), p.close),
        ],
        isCurved: true,
        curveSmoothness: 0.28,
        barWidth: 1.6,
        color: colors.benchmark,
        dashArray: [5, 4],
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.title.isNotEmpty)
                Flexible(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.hintColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const Spacer(),
              if (normalized) ...[
                _legendDot(color),
                const SizedBox(width: 5),
                Text('You', style: theme.textTheme.labelSmall),
                const SizedBox(width: 12),
                _legendDot(colors.benchmark),
                const SizedBox(width: 5),
                Text('SPY', style: theme.textTheme.labelSmall),
              ],
            ],
          ),
        ),
        // The readout replaces the header while scrubbing so the numbers stay
        // stable and the chart does not jump.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: readout == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: readout,
                ),
        ),
        // The period summary: how the portfolio did against the benchmark.
        if (normalized)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                _periodChip(
                  label: 'You',
                  value: series.last.close - series.first.close,
                  color: color,
                ),
                const SizedBox(width: 8),
                _periodChip(
                  label: 'SPY',
                  value: benchSeries!.last.close - benchSeries.first.close,
                  color: colors.benchmark,
                ),
                const SizedBox(width: 8),
                Text(
                  _beatLabel(series.last.close - series.first.close,
                      benchSeries.last.close - benchSeries.first.close),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.none(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _yInterval(minY, maxY),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outline.withValues(alpha: 0.10),
                  strokeWidth: 1,
                  dashArray: [4, 6],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: normalized
                    ? AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 38,
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
                    reservedSize: 24,
                    interval: (maxX - minX) / (labelCount - 1),
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        labelMap[value] ?? '',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.hintColor),
                      ),
                    ),
                  ),
                ),
              ),
              lineBarsData: bars,
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchSpotThreshold: 24,
                getTouchedSpotIndicator: (barData, indexes) => indexes
                    .map(
                      (_) => TouchedSpotIndicatorData(
                        FlLine(
                          color: (barData.color ?? theme.colorScheme.primary)
                              .withValues(alpha: 0.35),
                          strokeWidth: 1.5,
                          dashArray: [3, 3],
                        ),
                        FlDotData(
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 4.5,
                            color: bar.color ?? theme.colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: theme.colorScheme.surface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Colors.transparent,
                  tooltipPadding: EdgeInsets.zero,
                  tooltipMargin: 0,
                  getTooltipItems: (spots) => const [],
                ),
                touchCallback: (event, response) {
                  final spots = response?.lineBarSpots;
                  final spot = (spots != null && spots.isNotEmpty)
                      ? spots.first
                      : null;
                  if (event is FlTapUpEvent || event is FlPanEndEvent) {
                    if (mounted) setState(() => _activeIndex = null);
                    return;
                  }
                  if (spot == null) return;
                  var closest = 0;
                  var best = double.infinity;
                  for (var i = 0; i < series.length; i++) {
                    final d = (series[i].time.millisecondsSinceEpoch - spot.x).abs();
                    if (d < best) {
                      best = d;
                      closest = i;
                    }
                  }
                  if (mounted && closest != _activeIndex) {
                    setState(() => _activeIndex = closest);
                  }
                },
              ),
            ),
            // The line grows from the left when the data first arrives.
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
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

  /// A small chip with the change over the whole period.
  Widget _periodChip({
    required String label,
    required double value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final up = value >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '${up ? '+' : ''}${value.toStringAsFixed(1)}%',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: up ? colors.gain : colors.loss,
            ),
          ),
        ],
      ),
    );
  }

  /// A plain-language summary of the difference against the benchmark.
  String _beatLabel(double you, double spy) {
    final diff = you - spy;
    if (diff.abs() < 0.05) return 'in line with SPY';
    return '${diff > 0 ? 'ahead of' : 'behind'} SPY by '
        '${diff.abs().toStringAsFixed(1)} pts';
  }  double _yInterval(double minY, double maxY) {
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

/// The value readout shown while the chart is being scrubbed.
class _Readout extends StatelessWidget {
  final ChartPoint point;
  final ChartPoint? benchmarkPoint;
  final bool normalized;
  final String? currency;
  final String Function(double)? valueFormatter;

  const _Readout({
    required this.point,
    this.benchmarkPoint,
    required this.normalized,
    this.currency,
    this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final value = valueFormatter?.call(point.close) ??
        NumberFormat('#,##0.00').format(point.close);
    final date = DateFormat('d MMM yyyy').format(point.time);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              normalized ? '${point.close.toStringAsFixed(1)}%' : value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              date,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
        if (benchmarkPoint != null) ...[
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colors.benchmark,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('SPY',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.hintColor)),
                ],
              ),
              Text(
                '${benchmarkPoint!.close.toStringAsFixed(1)}%',
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A tiny inline trend chart used inside list rows.
class MiniSparkline extends StatelessWidget {
  final List<double> points;
  final Color color;
  final double width;
  final double height;

  const MiniSparkline({
    super.key,
    required this.points,
    required this.color,
    this.width = 54,
    this.height = 22,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _MiniSparklinePainter(points, color)),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  _MiniSparklinePainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    var min = points.first, max = points.first;
    for (final p in points) {
      if (p < min) min = p;
      if (p > max) max = p;
    }
    final span = max - min;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = span <= 0
          ? size.height / 2
          : size.height - ((points[i] - min) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_MiniSparklinePainter oldDelegate) =>
      oldDelegate.color != color || !identical(oldDelegate.points, points);
}
