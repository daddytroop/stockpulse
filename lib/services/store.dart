import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import 'store_impl_web.dart'
    if (dart.library.io) 'store_impl_io.dart';

/// Tiny persistence helper. Local JSON files (atomic-ish) on Android/desktop;
/// SharedPreferences (localStorage) on Flutter web where `dart:io` can't be
/// imported. Callers only ever deal with JSON maps.
class StockPulseStore {
  StockPulseStore({@visibleForTesting String? directory}) : _directory = directory;

  /// A fixed folder instead of the app's support folder (tests only).
  final String? _directory;

  static const String _tmpSuffix = '.tmp';

  Future<String?> _nativeDir() async => _directory ?? await resolveAppSupportDir();

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

  /// The last write queued for each file. Saves of the same file run one
  /// after another: two overlapping saves used to share one tmp file, and
  /// the second deleted the file the first had just written, so the data
  /// file could vanish entirely (everything reset on the next start).
  static final Map<String, Future<void>> _queue = {};

  Future<void> save(String name, Map<String, dynamic> data) {
    final String content;
    try {
      content = const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      // Unencodable data (say, NaN) must not take the app down.
      return Future.value();
    }
    final previous = _queue[name] ?? Future<void>.value();
    final next = previous.then((_) => _write(name, content));
    _queue[name] = next;
    return next;
  }

  Future<void> _write(String name, String content) async {
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