import 'dart:convert';

/// UTF-8 decode identical on all implementations (shared tiny helper).
String utf8Decode(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);