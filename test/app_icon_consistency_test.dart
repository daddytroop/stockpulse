import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/widgets/pulse_logo.dart';

/// The launcher icon and the in-app icon must be the same picture.
///
/// `tools/icon.ps1` bakes the artwork into `assets/icon/app_icon.png`, and
/// `lib/widgets/pulse_logo.dart` paints the same shape in the app. This test
/// checks the committed PNG against the shared geometry constants, so the two
/// cannot silently drift apart.
void main() {
  test('the launcher PNG matches the in-app icon geometry', () async {
    final png = File('assets/icon/app_icon.png');
    expect(png.existsSync(), isTrue,
        reason: 'Run tools/icon.ps1 to regenerate the launcher artwork.');

    final codec = await ui.instantiateImageCodec(png.readAsBytesSync());
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(bytes, isNotNull);
    final data = bytes!.buffer.asUint8List();

    const size = 1024;
    int alphaAt(double x, double y) {
      final px = x.round().clamp(0, size - 1);
      final py = y.round().clamp(0, size - 1);
      return data[(py * size + px) * 4 + 3];
    }

    // The mark stroke is much brighter than the tile background, so the red
    // channel tells the two apart.
    bool isMark(double x, double y) {
      final px = x.round().clamp(0, size - 1);
      final py = y.round().clamp(0, size - 1);
      return data[(py * size + px) * 4] > 40;
    }

    // Where the mark sits inside the tile, from the shared constants.
    final extent = size * PulseLogoGeometry.markScale;
    final offset = (size - extent) / 2;
    final unit = extent / PulseLogoGeometry.units;
    final centre = offset + PulseLogoGeometry.orbit.center.dx * unit;
    final radius = PulseLogoGeometry.orbit.width / 2 * unit;

    // The tile is filled with the brand background and its corners are cut
    // away.
    expect(alphaAt(512, 150), 255, reason: 'The tile must be filled.');
    expect(isMark(512, 150), isFalse,
        reason: 'The area above the mark must be the tile background.');
    expect(alphaAt(2, 2), lessThan(40), reason: 'The tile corners are rounded.');

    // Walk the orbit and confirm it is drawn almost everywhere, with a
    // deliberate gap where the arrow breaks out of the ring.
    var gapDegrees = 0;
    for (var deg = 0; deg < 360; deg++) {
      final angle = deg * math.pi / 180;
      final x = centre + radius * math.cos(angle);
      final y = centre + radius * math.sin(angle);
      if (!isMark(x, y)) gapDegrees++;
    }
    expect(gapDegrees, greaterThan(3),
        reason: 'The gap in the orbit has disappeared.');
    expect(gapDegrees, lessThan(30),
        reason: 'The orbit is no longer drawn as a ring.');

    // The arrow head at the end of the rising pulse is painted.
    expect(isMark(offset + 88 * unit, offset + 31 * unit), isTrue,
        reason: 'The arrow head is missing.');

    // The stroke colour is the brand mark colour. Flutter colour channels are
    // 0.0-1.0 while the raw bytes are 0-255.
    final arrowX = (offset + 88 * unit).round();
    final arrowY = (offset + 31 * unit).round();
    final i = (arrowY * size + arrowX) * 4;
    expect(data[i], (PulseBrand.mark.r * 255).round());
    expect(data[i + 1], (PulseBrand.mark.g * 255).round());
    expect(data[i + 2], (PulseBrand.mark.b * 255).round());
  });
}
