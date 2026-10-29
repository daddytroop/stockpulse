import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The trend line drawn inside the Android home-screen widget.
///
/// The widget is drawn by Android, not by Flutter, so this is rendered
/// to a small image by the app and handed over to the widget. It is a
/// plain, quiet line: the number is the headline, the line is context.
class WidgetSparkline extends StatelessWidget {
  final List<double> points;
  final Color color;

  const WidgetSparkline({
    super.key,
    required this.points,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparkPainter(points, color),
      size: Size.infinite,
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> points;
  final Color color;

  _SparkPainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.width <= 0 || size.height <= 0) return;

    var min = points.first, max = points.first;
    for (final p in points) {
      if (p < min) min = p;
      if (p > max) max = p;
    }
    final span = max - min;
    // A flat series is drawn through the middle rather than as a line on
    // the edge of the box.
    final pad = size.height * 0.18;
    final usable = size.height - pad * 2;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = span <= 0
          ? size.height / 2
          : pad + usable - ((points[i] - min) / span) * usable;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // A soft area under the line makes it read as a chart rather than a
    // stray squiggle.
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter oldDelegate) =>
      oldDelegate.color != color || !identical(oldDelegate.points, points);
}

/// The colour the widget's trend line uses.
Color widgetSparkColor(BuildContext context) => AppColors.of(context).gain;
