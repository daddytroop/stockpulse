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

/// Renames the tmp file over the real one (deleting the existing first
/// because Windows renames fail onto existing files).
Future<void> finalizeAtom(String tmpPath, String finalPath) async {
  final tmp = File(_normalize(tmpPath));
  final fin = File(_normalize(finalPath));
  if (await fin.exists()) await fin.delete();
  await tmp.rename(_normalize(fin.path));
}

String _normalize(String p) => p.replaceAll('/', Platform.pathSeparator);