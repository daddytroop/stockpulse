import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Tiny JSON-file persistence helper with atomic-ish writes.
class StockPulseStore {
  final Future<Directory> Function() _resolveDir;

  StockPulseStore({Future<Directory> Function()? resolver})
      : _resolveDir = resolver ?? _defaultDir;

  static Future<Directory> _defaultDir() async => getApplicationSupportDirectory();

  Future<File> _file(String name) async {
    final dir = await _resolveDir();
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  Future<Map<String, dynamic>?> load(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      final text = await f.readAsString();
      if (text.trim().isEmpty) return null;
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String name, Map<String, dynamic> data) async {
    try {
      final f = await _file(name);
      final dir = f.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      if (await f.exists()) await f.delete();
      await tmp.rename(f.path);
    } catch (_) {
      // persistence failures should never crash the app
    }
  }

  /// Directory used for manual exports (documents folder).
  Future<String> documentsPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }
}