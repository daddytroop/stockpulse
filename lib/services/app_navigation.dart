import 'package:flutter/foundation.dart';

/// Which bottom-navigation tab the app is showing.
///
/// Exposed as a notifier so any screen can ask the shell to switch tabs -
/// the KPI tiles use it to jump from "annual income" straight to the
/// dividend calendar.
class AppNavigation extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  /// Tabs the app can show, in order.
  static const List<String> labels = [
    'Portfolio',
    'Dividends',
    'News',
    'Import',
    'Settings',
  ];

  static const int portfolioTab = 0;
  static const int dividendsTab = 1;
  static const int newsTab = 2;

  void goTo(int index) {
    if (index < 0 || index >= labels.length) return;
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }
}
