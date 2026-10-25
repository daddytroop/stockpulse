import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'store_impl_web.dart'
    if (dart.library.io) 'store_impl_io.dart';

/// Tiny persistence helper. Local JSON files (atomic-ish) on Android/desktop;
/// SharedPreferences (localStorage) on Flutter web where `dart:io` can't be
/// imported. Callers only ever deal with JSON maps.
class StockPulseStore {
  static const String _tmpSuffix = '.tmp';

  Future<String?> _nativeDir() => resolveAppSupportDir();

  Future<Map<String, dynamic>?> load(String name) async {
    if (kIsWeb) {
      try {
        final sp = await SharedPreferences.getInstance();
        final raw = sp.getString('stockpulse_$name');
        if (raw == null || raw.isEmpty) return null;
        final decoded = jsonDecode(raw);
        return decoded is Map<String, dynamic> ? decoded : null;
      } catch (_) {
        return null;
      }
    }
    try {
      final dir = await _nativeDir();
      if (dir == null) return null;
      final raw = await readTextFile('$dir/$name');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String name, Map<String, dynamic> data) async {
    final content = const JsonEncoder.withIndent('  ').convert(data);
    if (kIsWeb) {
      try {
        final sp = await SharedPreferences.getInstance();
        await sp.setString('stockpulse_$name', content);
      } catch (_) {}
      return;
    }
    try {
      final dir = await _nativeDir();
      if (dir == null) return;
      // write to a tmp file, then swap, so a crash mid-write can't corrupt
      // data. (Windows cannot rename over an existing file - finalizeAtom
      // deletes it first.)
      final tmpPath = '${dir}$sep$name$_tmpSuffix';
      final finalPath = '${dir}$sep$name';
      await writeTextFileAtomic(tmpPath, content);
      await finalizeAtom(tmpPath, finalPath);
    } catch (_) {
      // persistence failures should never crash the app
    }
  }

  static const String sep = '/';
}