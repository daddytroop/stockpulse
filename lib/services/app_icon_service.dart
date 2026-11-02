import 'dart:ui' show Color;

import 'package:flutter/services.dart';

import 'platform_check.dart';

/// An alternate home-screen icon (Android).
enum AppIconStyle {
  classic('classic', 'Classic', Color(0xFF061D2B), Color(0xFF66F0B3)),
  neon('neon', 'Neon', Color(0xFF060912), Color(0xFF00F5A0)),
  gold('gold', 'Gold', Color(0xFF14100A), Color(0xFFF5C451)),
  aurora('aurora', 'Aurora', Color(0xFF110F2A), Color(0xFF5EEAD4)),
  sakura('sakura', 'Sakura', Color(0xFFFFF0F5), Color(0xFFE85D9A));

  const AppIconStyle(this.id, this.label, this.background, this.mark);

  /// The name the Android side uses.
  final String id;
  final String label;
  final Color background;
  final Color mark;

  /// The classic icon is free; the others come with Pro.
  bool get isPremium => this != AppIconStyle.classic;
}

/// Switches the launcher icon through the `app.stockpulse/icons` channel
/// (see AppIcons.kt). Only Android has alternate icons.
class AppIconService {
  AppIconService._();

  static const _channel = MethodChannel('app.stockpulse/icons');

  static bool get supported => isAndroidPlatform;

  static Future<AppIconStyle> current() async {
    if (!supported) return AppIconStyle.classic;
    try {
      final id = await _channel.invokeMethod<String>('current');
      return AppIconStyle.values.firstWhere((s) => s.id == id,
          orElse: () => AppIconStyle.classic);
    } catch (_) {
      return AppIconStyle.classic;
    }
  }

  static Future<bool> set(AppIconStyle style) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('set', {'name': style.id}) ?? false;
    } catch (_) {
      return false;
    }
  }
}
