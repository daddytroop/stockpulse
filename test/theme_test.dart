import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stock_pulse/app.dart';
import 'package:stock_pulse/providers/portfolio_provider.dart';
import 'package:stock_pulse/screens/settings_screen.dart';
import 'package:stock_pulse/services/ad_service.dart';
import 'package:stock_pulse/services/store.dart';
import 'package:stock_pulse/theme/app_theme.dart';
import 'package:stock_pulse/widgets/ui/theme_toggle.dart';

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
  /// The settings screen reads both the portfolio and the ad service.
  Widget wrap(Widget child, PortfolioProvider provider) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PortfolioProvider>.value(value: provider),
        ChangeNotifierProvider<AdService>.value(value: AdService()),
      ],
      child: child,
    );
  }

  /// Loading the provider starts background fetches with short delays.
  /// They have to be flushed before a widget test ends.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  group('theme', () {
    testWidgets('tapping a theme in the settings changes the theme', (tester) async {
      final provider = PortfolioProvider(store: _MemoryStore());
      await provider.load();

      await tester.pumpWidget(wrap(
        const MaterialApp(home: SettingsScreen()),
        provider,
      ));
      await settle(tester);

      // The theme section is near the top now, but a long list can still
      // push it off the first screen.
      await tester.scrollUntilVisible(find.text('Dark'), 120);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(provider.themeMode, AppThemeId.dark);
    });

    testWidgets('the whole app follows the chosen theme', (tester) async {
      final provider = PortfolioProvider(store: _MemoryStore());
      await provider.load();

      await tester.pumpWidget(wrap(StockPulseApp(), provider));
      await settle(tester);

      final captured = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(captured).brightness, Brightness.light);

      await provider.setThemeMode(AppThemeId.dark);
      await tester.pumpAndSettle();

      expect(Theme.of(captured).brightness, Brightness.dark);
    });

    testWidgets('the theme button opens the picker and applies a theme',
        (tester) async {
      final provider = PortfolioProvider(store: _MemoryStore());
      await provider.load();

      await tester.pumpWidget(wrap(
        const MaterialApp(home: Scaffold(body: ThemeToggleButton())),
        provider,
      ));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.light_mode_outlined));
      await tester.pumpAndSettle();

      expect(find.text('AMOLED black'), findsOneWidget);
      await tester.tap(find.text('AMOLED black'));
      await tester.pumpAndSettle();

      expect(provider.themeMode, AppThemeId.amoled);
    });

    testWidgets('every theme can be selected', (tester) async {
      final provider = PortfolioProvider(store: _MemoryStore());
      await provider.load();

      await tester.pumpWidget(wrap(
        const MaterialApp(home: SettingsScreen()),
        provider,
      ));
      await settle(tester);

      for (final mode in AppThemeId.values) {
        await tester.scrollUntilVisible(find.text(mode.label), 120);
        await tester.tap(find.text(mode.label));
        await tester.pumpAndSettle();
        expect(provider.themeMode, mode);
      }
    });
  });
}
