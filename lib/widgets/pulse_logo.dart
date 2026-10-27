import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brand colours for the Stock Pulse mark.
///
/// The launcher icon, the splash artwork and the in-app icon are all built
/// from these values, so the icon on the home screen is the same picture as
/// the icon inside the app.
///
/// A launcher icon is baked into the app package at build time, so it cannot
/// follow a colour the user picks later. The icon therefore uses these fixed
/// brand colours in both places; the accent colour themes the rest of the
/// app.
class PulseBrand {
  PulseBrand._();

  /// Background of the app icon tile.
  static const Color background = Color(0xFF061D2B);

  /// The rising-pulse stroke.
  static const Color mark = Color(0xFF64EFAE);
}

/// The geometry of the mark, shared with `tools/icon.ps1`.
///
/// Keeping these in one place is what makes the launcher artwork and the
/// in-app icon the same picture; the test suite checks the generated PNG
/// still matches.
class PulseLogoGeometry {
  PulseLogoGeometry._();

  /// The mark is drawn inside a 100x100 box.
  static const double units = 100;

  /// Fraction of the tile the mark occupies.
  static const double markScale = 0.62;

  /// Fraction of the tile left as padding around the mark.
  static const double markOffset = 0.19;

  /// Corner radius of the tile, as a fraction of its edge.
  static const double tileRadius = 0.22;

  /// Stroke width of the mark, in the 100x100 space.
  static const double strokeWidth = 7;

  /// The orbit, in the 100x100 space.
  static const Rect orbit = Rect.fromLTWH(10, 10, 80, 80);

  /// Where the orbit starts and how far it sweeps.
  static const double orbitStart = 0.08;
  static const double orbitSweep = math.pi * 1.71;
}

/// The Stock Pulse app icon: a rounded tile with an open orbit and a rising
/// pulse arrow. This is the exact artwork used for the Android launcher icon,
/// the splash screen and the in-app icon.
class PulseLogo extends StatelessWidget {
  final double size;

  /// Draws the icon on a rounded tile. Set to false for the bare mark.
  final bool tiled;

  /// Colour of the pulse stroke.
  final Color? markColor;

  const PulseLogo({
    super.key,
    this.size = 40,
    this.tiled = true,
    this.markColor,
  });

  @override
  Widget build(BuildContext context) {
    final mark = markColor ?? PulseBrand.mark;
    return Semantics(
      label: 'Stock Pulse',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _PulseLogoPainter(
            mark,
            tiled: tiled,
            background: PulseBrand.background,
          ),
        ),
      ),
    );
  }
}

class _PulseLogoPainter extends CustomPainter {
  final Color color;
  final bool tiled;
  final Color background;

  const _PulseLogoPainter(this.color, {required this.tiled, required this.background});

  @override
  void paint(Canvas canvas, Size size) {
    if (tiled) {
      // Rounded tile, matching the masked shape Android gives an adaptive
      // icon.
      final r = size.width * PulseLogoGeometry.tileRadius;
      final tile = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(r),
        ));
      canvas.drawPath(tile, Paint()..color = background);
    }
    canvas.save();
    // The mark occupies the middle of the tile, matching the launcher
    // artwork's safe area. The bare mark fills the whole box instead.
    final scale = tiled
        ? size.width / PulseLogoGeometry.units * PulseLogoGeometry.markScale
        : size.width / PulseLogoGeometry.units;
    final offset = tiled ? size.width * PulseLogoGeometry.markOffset : 0.0;
    canvas.translate(offset, offset);
    canvas.scale(scale, scale);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = PulseLogoGeometry.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawArc(
      PulseLogoGeometry.orbit,
      PulseLogoGeometry.orbitStart,
      PulseLogoGeometry.orbitSweep,
      false,
      pen,
    );
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
  bool shouldRepaint(_PulseLogoPainter oldDelegate) =>
      color != oldDelegate.color ||
      tiled != oldDelegate.tiled ||
      background != oldDelegate.background;
}
