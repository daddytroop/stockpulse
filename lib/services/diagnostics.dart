import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Minimal local diagnostics. Errors are written to a short text log only when
/// the in-app privacy setting is enabled; the log is never sent automatically.
class Diagnostics {
  Diagnostics._();

  static bool _enabled = false;
  static String? _path;

  static String? get path => _path;
  static bool get enabled => _enabled;

  static void setEnabled(bool enabled) => _enabled = enabled;

  static Future<void> install({required bool enabled}) async {
    _enabled = enabled;
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      log('FlutterError: ${details.exceptionAsString()}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      log('PlatformError: $error');
      return false;
    };
    runZonedGuarded(() {}, (error, stack) => log('ZoneError: $error'));
  }

  static Future<void> log(String message) async {
    if (!_enabled) return;
    if (kIsWeb) return;
    final redacted = message.replaceAll(RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+'), '<redacted>');
    try {
      final dir = Directory.systemTemp.path;
      _path = '$dir/stockpulse_diagnostics.txt';
      await File(_path!).writeAsString(
        '${DateTime.now().toIso8601String()}  $redacted\n',
        mode: FileMode.append,
      );
    } on PlatformException {
      // Diagnostic storage is optional and must never break the app.
    }
  }
}
