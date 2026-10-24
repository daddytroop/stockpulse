import 'dart:io';

import 'package:home_widget/home_widget.dart';

/// Bridges portfolio data into the Android home-screen widgets.
///
/// The widget layouts live in `platform_overlay/android/` and are applied by
/// the CI build (or scripts/setup_platforms). On non-Android platforms every
/// call here is a no-op.
class StockPulseWidgetService {
  StockPulseWidgetService._();

  static const String _appId = 'app.stockpulse';

  /// True when this device can display the home-screen widgets.
  static bool get supported => Platform.isAndroid;

  /// Pushes the latest portfolio numbers to both widgets.
  ///
  /// [change] is preformatted, e.g. "+123.45 (+1.20%)" ; [changeSign] is
  /// -1, 0 or +1 so the native side can color it green/red/gray.
  static Future<bool> push({
    required String total,
    required String change,
    required int changeSign,
    required String nextDividendLine1,
    required String nextDividendLine2,
  }) async {
    if (!supported) return false;
    try {
      await HomeWidget.saveWidgetData<String>('widget_total', total);
      await HomeWidget.saveWidgetData<String>('widget_change', change);
      await HomeWidget.saveWidgetData<int>('widget_change_sign', changeSign);
      await HomeWidget.saveWidgetData<String>('nd_line1', nextDividendLine1);
      await HomeWidget.saveWidgetData<String>('nd_line2', nextDividendLine2);
      await HomeWidget.saveWidgetData<String>(
          'nd_updated', DateTime.now().millisecondsSinceEpoch.toString());
      final ok1 = await HomeWidget.updateWidget(
          qualifiedAndroidName: '$_appId.PortfolioWidgetProvider');
      final ok2 = await HomeWidget.updateWidget(
          qualifiedAndroidName: '$_appId.NextDividendWidgetProvider');
      return ok1 == true && ok2 == true;
    } catch (_) {
      return false;
    }
  }
}