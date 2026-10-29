import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android home-screen widgets against the two mistakes that
/// are easy to make and invisible until the widget is on a home screen:
/// reading the wrong preferences file, and referencing an id that the
/// layout does not have.
void main() {
  const kotlinPath =
      'platform_overlay/android/app/src/main/kotlin/app/stockpulse/WidgetRenderer.kt';
  const layoutDir = 'platform_overlay/android/app/src/main/res/layout';

  String read(String path) => File(path).readAsStringSync();

  group('widget renderer', () {
    test('reads the preferences file the home_widget plugin writes', () {
      final source = read(kotlinPath);
      // The plugin stores its data in "HomeWidgetPreferences". A different
      // name means the widget reads an empty file and shows placeholders.
      expect(source, contains('"HomeWidgetPreferences"'));
      expect(source, isNot(contains('"HomeWidgetPlugin"')));
    });

    test('every view id it sets exists in a layout', () {
      final source = read(kotlinPath);
      final ids = RegExp(r'R\.id\.(\w+)')
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();

      expect(ids, isNotEmpty);

      final layouts = Directory(layoutDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.xml'))
          .map((f) => f.readAsStringSync())
          .join('\n');

      for (final id in ids) {
        expect(
          layouts,
          contains('@+id/$id'),
          reason: 'R.id.$id is used by the renderer but no layout defines it',
        );
      }
    });

    test('the layouts define the brand dot and the trend line', () {
      final portfolio = read('$layoutDir/widget_portfolio.xml');
      expect(portfolio, contains('@drawable/widget_dot'));
      expect(portfolio, contains('@+id/widget_sparkline'));
      // The trend line is drawn by the app, so the image view must be
      // allowed to grow with the widget.
      expect(portfolio, contains('layout_weight="1"'));
    });
  });
}
