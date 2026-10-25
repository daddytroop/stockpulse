import 'dart:io' show Platform;

/// Native (Android/Windows/...) values.
final bool isAndroidPlatform = Platform.isAndroid;
final bool isDesktopPlatform =
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;
final bool isMobilePlatform = Platform.isAndroid || Platform.isIOS;
final bool isWebPlatform = false;