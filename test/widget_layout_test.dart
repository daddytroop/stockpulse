import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/services/widget_service.dart';

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

    test('the layouts only use views a home-screen widget can show', () {
      // RemoteViews inflates an allow-list of classes. Anything else (a
      // plain <View> divider, say) makes the launcher show "Can't load
      // widget" for the whole widget.
      const allowed = {
        'FrameLayout', 'LinearLayout', 'RelativeLayout', 'GridLayout',
        'TextView', 'ImageView', 'Button', 'ImageButton', 'ProgressBar',
        'Chronometer', 'AnalogClock', 'TextClock', 'ListView', 'GridView',
        'StackView', 'AdapterViewFlipper', 'ViewFlipper', 'ViewStub',
      };
      final layouts = Directory(layoutDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.xml'));
      for (final file in layouts) {
        final tags = RegExp(r'<([A-Za-z][\w.]*)')
            .allMatches(file.readAsStringSync())
            .map((m) => m.group(1)!)
            .where((t) => t != 'merge' && t != 'include');
        for (final tag in tags) {
          expect(allowed, contains(tag),
              reason: '${file.path} uses <$tag>, which widgets cannot inflate');
        }
      }
    });

    test('the trend line is stored as finite values, at most 60', () {
      final many = [for (var i = 0; i < 200; i++) i.toDouble()];
      final json = StockPulseWidgetService.sparklinePointsJson(
          [double.nan, ...many, double.infinity]);
      final values = (jsonDecode(json) as List).cast<num>();
      expect(values.length, lessThanOrEqualTo(61));
      expect(values.first, 0);
      expect(values.last, 199);
      expect(StockPulseWidgetService.sparklinePointsJson([1, 2]), '[1.0,2.0]');
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
