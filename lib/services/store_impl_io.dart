import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Native file storage implementation.
Future<String?> resolveAppSupportDir() async {
  final dir = await getApplicationSupportDirectory();
  return dir.path;
}

Future<String?> readTextFile(String path) async {
  final f = File(_normalize(path));
  if (!await f.exists()) return null;
  return f.readAsString();
}

Future<void> writeTextFileAtomic(String path, String content) async {
  final f = File(_normalize(path));
  final dir = f.parent;
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  await f.writeAsString(content, flush: true);
}

/// Moves the tmp file over the real one. On Android, Linux and macOS a
/// rename replaces the old file in one step, so the data is never missing.
/// Windows cannot rename onto an existing file, so there it is deleted
/// first.
Future<void> finalizeAtom(String tmpPath, String finalPath) async {
  final tmp = File(_normalize(tmpPath));
  final fin = File(_normalize(finalPath));
  if (Platform.isWindows && await fin.exists()) await fin.delete();
  await tmp.rename(_normalize(fin.path));
}

String _normalize(String p) => p.replaceAll('/', Platform.pathSeparator);