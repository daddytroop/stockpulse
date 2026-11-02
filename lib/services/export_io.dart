import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// UTF-8 decode identical to the web implementation's helper.
String utf8Decode(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);

/// Native implementation: save dialog on desktop, share sheet on mobile.
class ExportService {
  ExportService._();

  static Future<({String name, String content})?> pickFile({
    required List<String> extensions,
  }) async {
    final group = XTypeGroup(label: 'Document', extensions: extensions);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return (
      name: file.name,
      content: utf8Decode(bytes),
    );
  }

  static Future<bool> saveOrShare({
    required String fileName,
    required String content,
    String mimeType = 'text/plain',
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        final location = await getSaveLocation(suggestedName: fileName);
        if (location == null) return false;
        await File(location.path).writeAsString(content, flush: true);
        return true;
      } catch (_) {
        return false;
      }
    }
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final tmp = await getTemporaryDirectory();
        final path = '${tmp.path}${Platform.pathSeparator}$fileName';
        await File(path).writeAsString(content, flush: true);
        await Share.shareXFiles([XFile(path, mimeType: mimeType)], text: fileName);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Shares an image (the share sheet on phones, a save dialog on desktop).
  static Future<bool> shareImage({
    required String fileName,
    required Uint8List bytes,
    String? text,
  }) async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final location = await getSaveLocation(suggestedName: fileName);
        if (location == null) return false;
        await File(location.path).writeAsBytes(bytes, flush: true);
        return true;
      }
      final tmp = await getTemporaryDirectory();
      final path = '${tmp.path}${Platform.pathSeparator}$fileName';
      await File(path).writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(path, mimeType: 'image/png')], text: text);
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool get clipboardFallbackUsed => false;
}