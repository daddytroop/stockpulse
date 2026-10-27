import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/widgets/pulse_logo.dart';

/// The launcher icon and the in-app icon must be the same picture, so the
/// committed PNG is compared against the widget that draws it in the app.
void main() {
  testWidgets('the launcher PNG matches the in-app icon', (tester) async {
    final png = File('assets/icon/app_icon.png');
    expect(png.existsSync(), isTrue,
        reason: 'Run tools/icon.ps1 to regenerate the launcher artwork.');

    final bytes = png.readAsBytesSync();
    final decoded = await ui.instantiateImageCodec(bytes);
    final frame = await decoded.getNextFrame();
    final launcher = frame.image;

    // Render the in-app icon at the same size.
    const size = 256.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(size / 1024, size / 1024);
    final painter = _LogoPainter();
    painter.paint(canvas, const Size(1024, 1024));
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(1024, 1024);

    final launcherBytes = await launcher.toByteData(format: ui.ImageByteFormat.rawRgba);
    final renderedBytes = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(launcherBytes, isNotNull);
    expect(renderedBytes, isNotNull);

    final a = launcherBytes!.buffer.asUint8List();
    final b = renderedBytes!.buffer.asUint8List();
    expect(a.length, b.length);

    // Compare a downsampled grid: the PNG is anti-aliased differently from
    // the widget, so exact pixels are not expected.
    var differences = 0;
    var sampled = 0;
    for (var y = 0; y < 1024; y += 8) {
      for (var x = 0; x < 1024; x += 8) {
        final i = (y * 1024 + x) * 4;
        sampled++;
        final dr = (a[i] - b[i]).abs();
        final dg = (a[i + 1] - b[i + 1]).abs();
        final db = (a[i + 2] - b[i + 2]).abs();
        final da = (a[i + 3] - b[i + 3]).abs();
        if (dr > 90 || dg > 90 || db > 90 || da > 90) differences++;
      }
    }
    // A handful of anti-aliasing samples may differ; a real shape change
    // would miss far more than this.
    expect(differences / sampled, lessThan(0.06),
        reason: 'The launcher artwork and the in-app icon have diverged.');
  });
}

/// Mirrors the painter used by [PulseLogo] so the comparison is against the
/// same drawing commands.
class _LogoPainter {
  void paint(Canvas canvas, Size size) {
    const background = PulseBrand.background;
    const mark = PulseBrand.mark;
    final r = size.width * 0.22;
    final tile = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(r),
      ));
    canvas.drawPath(tile, Paint()..color = background);

    final extent = size.width * 0.62;
    final offset = (size.width - extent) / 2;
    canvas.translate(offset, offset);
    canvas.scale(extent / 100, extent / 100);
    final pen = Paint()
      ..color = mark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawArc(const Rect.fromLTWH(10, 10, 80, 80),
        0.08, 3.141592653589793 * 1.71, false, pen);
    final pulse = Path()
      ..moveTo(12, 59)
      ..lineTo(29, 59)
      ..cubicTo(35, 59, 39, 44, 45, 44)
      ..cubicTo(50, 44, 54, 61, 60, 61)
      ..lineTo(87, 33);
    canvas.drawPath(pulse, pen);
    canvas.drawPath(Path()..moveTo(74, 35)..lineTo(88, 31)
      ..lineTo(88, 46), pen);
  }
}
