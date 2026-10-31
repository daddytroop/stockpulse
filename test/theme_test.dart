import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stock_pulse/app.dart';
import 'package:stock_pulse/providers/portfolio_provider.dart';
import 'package:stock_pulse/screens/settings_screen.dart';
import 'package:stock_pulse/services/store.dart';
import 'package:stock_pulse/theme/app_theme.dart';

/// A store that keeps everything in memory.
class _MemoryStore extends StockPulseStore {
  final Map<String, Map<String, dynamic>> files = {};

  @override
  Future<Map<String, dynamic>?> load(String name) async => files[name];

  @override
  Future<void> save(String name, Map<String, dynamic> data) async {
    files[name] = data;
  }
}

void main() {
  group('theme', () {
    testWidgets('tapping a theme in the settings changes the theme', (tester) async {
      final provider = PortfolioProvider(store: _MemoryStore());
      await provider.load();

      await tester.pumpWidget(ChangeNotifierProvider<PortfolioProvider>.value(
        value: provider,
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(provider.themeMode, AppThemeId.dark);
    });

    testWidgets('the whole app follows the chosen theme', (tester) async {
      final provider = PortfolioProvider(store: _MemoryStore());
      await provider.load();

      late BuildContext captured;
      await tester.pumpWidget(ChangeNotifierProvider<PortfolioProvider>.value(
        value: provider,
        child: MaterialApp(
          builder: (context, child) {
            captured = context;
            return child!;
          },
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ));
      await tester.pumpAndSettle();
      expect(Theme.of(captured).brightness, Brightness.light);

      await provider.setThemeMode(AppThemeId.dark);
      await tester.pumpAndSettle();

      expect(Theme.of(captured).brightness, Brightness.dark);
    });

    testWidgets('every theme can be selected', (tester) async {
      final provider = PortfolioProvider(store: _MemoryStore());
      await provider.load();

      await tester.pumpWidget(ChangeNotifierProvider<PortfolioProvider>.value(
        value: provider,
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pumpAndSettle();

      for (final mode in AppThemeId.values) {
        await tester.tap(find.text(mode.label));
        await tester.pumpAndSettle();
        expect(provider.themeMode, mode);
      }
    });
  });
}
