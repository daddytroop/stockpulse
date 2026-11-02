import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import 'export_common.dart';

/// Web implementation: clipboard for save, browser input for pick.
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
    try {
      await Clipboard.setData(ClipboardData(text: content));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shares an image through the browser (share sheet or download).
  static Future<bool> shareImage({
    required String fileName,
    required Uint8List bytes,
    String? text,
  }) async {
    try {
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
        text: text,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool get clipboardFallbackUsed => true;
}