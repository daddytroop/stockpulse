/// Files: save/share/pick helpers. Dispatches to the IO implementation
/// natively and to the web-safe implementation on Flutter web (where
/// `dart:io` cannot be imported).
export 'export_stub.dart' if (dart.library.io) 'export_io.dart';