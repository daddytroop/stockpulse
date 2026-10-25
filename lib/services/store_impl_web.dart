/// Web implementation - never actually used (store.dart branches on kIsWeb
/// and uses SharedPreferences directly); exists only to satisfy the
/// conditional import with dart:io-free signatures.
Future<String?> resolveAppSupportDir() async => null;

Future<String?> readTextFile(String path) async => null;

Future<void> writeTextFileAtomic(String path, String content) async {}

Future<void> finalizeAtom(String tmpPath, String finalPath) async {}