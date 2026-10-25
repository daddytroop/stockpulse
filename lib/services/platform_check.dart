/// Platform detection that compiles on Flutter web too (where `dart:io` is
/// unavailable). Uses conditional exports; use these instead of
/// `Platform.isSomething` anywhere outside io-only files.
export 'platform_check_stub.dart' if (dart.library.io) 'platform_check_io.dart';