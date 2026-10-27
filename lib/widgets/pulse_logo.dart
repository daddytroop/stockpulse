import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An open orbit and rising pulse, drawn at any size in the user's accent.
class PulseLogo extends StatelessWidget {
  final double size;
  const PulseLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Stock Pulse',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _PulseLogoPainter(scheme.primary)),
      ),
    );
  }
}

class _PulseLogoPainter extends CustomPainter {
  final Color color;
  const _PulseLogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawArc(const Rect.fromLTWH(10, 10, 80, 80),
        0.08, math.pi * 1.71, false, pen);
    final pulse = Path()
      ..moveTo(12, 59)
      ..lineTo(29, 59)
      ..cubicTo(35, 59, 39, 44, 45, 44)
      ..cubicTo(50, 44, 54, 61, 60, 61)
      ..lineTo(87, 33);
    canvas.drawPath(pulse, pen);
    canvas.drawPath(Path()..moveTo(74, 35)..lineTo(88, 31)
      ..lineTo(88, 46), pen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PulseLogoPainter oldDelegate) => color != oldDelegate.color;
}
