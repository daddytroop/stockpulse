import 'dart:convert';

import 'package:http/http.dart' as http;

/// Portfolios <-> private GitHub Gist sync. A fine-grained or classic PAT
/// with `gist` scope is required; the gist holds a single file
/// `stockpulse.json` with a full backup payload.
///
/// Semantics are deliberately simple and manual: PUSH overwrites the gist
/// with this device's data; PULL replaces this device's data with the gist.
/// No merging, no conflict resolution - check both devices before pulling.
class SyncService {
  SyncService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String fileName = 'stockpulse.json';

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'Content-Type': 'application/json',
        'User-Agent': 'StockPulse',
      };

  String _apiError(http.Response r) {
    try {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final msg = j['message'] ?? j.toString();
      return 'GitHub API ${r.statusCode}: $msg';
    } catch (_) {
      return 'GitHub API error ${r.statusCode}';
    }
  }

  /// Creates a fresh private gist holding [content]. Returns its id.
  Future<String> createGist({
    required String token,
    required String content,
    String description = 'Stock Pulse backup',
  }) async {
    final r = await _client
        .post(
          Uri.parse('https://api.github.com/gists'),
          headers: _headers(token),
          body: jsonEncode({
            'description': description,
            'public': false,
            'files': {
              fileName: {'content': content},
            },
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (r.statusCode == 200 || r.statusCode == 201) {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return (j['id'] ?? '') as String;
    }
    throw SyncException(_apiError(r));
  }

  /// Overwrites the gist file with [content].
  Future<void> push({
    required String token,
    required String gistId,
    required String content,
  }) async {
    final r = await _client
        .patch(
          Uri.parse('https://api.github.com/gists/$gistId'),
          headers: _headers(token),
          body: jsonEncode({
            'files': {
              fileName: {'content': content},
            },
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw SyncException(_apiError(r));
  }

  /// Downloads the gist file content.
  Future<String> pull({
    required String token,
    required String gistId,
  }) async {
    final r = await _client
        .get(Uri.parse('https://api.github.com/gists/$gistId'),
            headers: _headers(token))
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw SyncException(_apiError(r));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final files = (j['files'] as Map<String, dynamic>?) ?? const {};
    final f = files[fileName];
    if (f is! Map<String, dynamic>) {
      throw const SyncException('No stockpulse.json in that gist.');
    }
    final content = f['content'] as String?;
    if (content == null || content.isEmpty) {
      throw const SyncException('The gist is empty.');
    }
    return content;
  }
}

class SyncException implements Exception {
  final String message;
  const SyncException(this.message);
  @override
  String toString() => message;
}