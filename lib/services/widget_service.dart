import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../widgets/widget_sparkline.dart';
import 'platform_check.dart' show isAndroidPlatform;

/// Bridges portfolio data into the Android home-screen widgets.
///
/// The widget layouts live in `platform_overlay/android/` and are applied by
/// the CI build (or scripts/setup_platforms). Outside Android this is a no-op.
class StockPulseWidgetService {
  StockPulseWidgetService._();

  static const String _appId = 'app.stockpulse';

  /// True when this device can display the home-screen widgets.
  static bool get supported => isAndroidPlatform && !kIsWeb;

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
    String meta = '',
    String nextDividendSymbol = '',
    String nextDividendAmount = '',
    String nextDividendWhen = '',
    String nextDividendPaid = '',
    String nextDividendEx = '',
    String nextLabel = '',
    String nextAmount = '',
    String nextWhen = '',
  }) async {
    if (!supported) return false;
    try {
      await HomeWidget.saveWidgetData<String>('widget_total', total);
      await HomeWidget.saveWidgetData<String>('widget_change', change);
      await HomeWidget.saveWidgetData<int>('widget_change_sign', changeSign);
      await HomeWidget.saveWidgetData<String>('widget_meta', meta);
      await HomeWidget.saveWidgetData<String>('nd_line1', nextDividendLine1);
      await HomeWidget.saveWidgetData<String>('nd_line2', nextDividendLine2);
      await HomeWidget.saveWidgetData<String>('nd_symbol', nextDividendSymbol);
      await HomeWidget.saveWidgetData<String>('nd_amount', nextDividendAmount);
      await HomeWidget.saveWidgetData<String>('nd_when', nextDividendWhen);
      await HomeWidget.saveWidgetData<String>('nd_paid', nextDividendPaid);
      await HomeWidget.saveWidgetData<String>('nd_ex', nextDividendEx);
      // The portfolio widget shows the next dividend in its own words.
      await HomeWidget.saveWidgetData<String>('widget_next', nextLabel);
      await HomeWidget.saveWidgetData<String>('widget_next_amount', nextAmount);
      await HomeWidget.saveWidgetData<String>('widget_next_when', nextWhen);
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

  /// Renders the trend line that sits inside the portfolio widget.
  ///
  /// The widget is drawn by Android, so the line is rendered here as a
  /// small transparent PNG and the widget picks it up by path.
  static Future<bool> pushSparkline({
    required List<double> points,
    required int colorValue,
    double width = 280,
    double height = 26,
  }) async {
    if (!supported) return false;
    try {
      await HomeWidget.renderFlutterWidget(
        WidgetSparkline(points: points, color: Color(colorValue)),
        key: sparklineKey,
        logicalSize: Size(width, height),
        pixelRatio: 3.0,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The preferences key the rendered sparkline is stored under.
  static const String sparklineKey = 'widget_sparkline';

  /// Writes the compact snapshot the Kotlin background worker consumes:
  /// aggregated positions, FX rates into the display currency, the next
  /// ex-dividend date, upcoming earnings and price-alert thresholds.
  static Future<bool> pushBackgroundSnapshot({
    required List<({String symbol, double qty, String currency, String name})> positions,
    required String displayCurrency,
    required Map<String, double> ratesByFrom,
    required ({String symbol, DateTime? exDate})? nextDividend,
    required Map<String, int> earningsBySymbol,
    required Map<String, double>? alerts,
  }) async {
    if (!supported) return false;
    try {
      final symbols = [
        for (final p in positions) {'s': p.symbol, 'q': p.qty, 'cur': p.currency, 'name': p.name},
      ];
      await HomeWidget.saveWidgetData<String>('bg_symbols', jsonEncode(symbols));
      await HomeWidget.saveWidgetData<String>('bg_display', displayCurrency);
      await HomeWidget.saveWidgetData<String>('bg_rates', jsonEncode(ratesByFrom));

      if (nextDividend != null) {
        await HomeWidget.saveWidgetData<String>(
          'bg_next_div',
          jsonEncode({
            's': nextDividend.symbol,
            'exMs': nextDividend.exDate?.millisecondsSinceEpoch ?? 0,
          }),
        );
      }
      await HomeWidget.saveWidgetData<String>(
          'bg_earnings', jsonEncode(earningsBySymbol));
      await HomeWidget.saveWidgetData<String>(
          'bg_alerts', jsonEncode(alerts ?? const {}));
      return true;
    } catch (_) {
      return false;
    }
  }
}