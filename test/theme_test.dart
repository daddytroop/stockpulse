import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stock_pulse/app.dart';
import 'package:stock_pulse/providers/portfolio_provider.dart';
import 'package:stock_pulse/screens/settings_screen.dart';
import 'package:stock_pulse/services/ad_service.dart';
import 'package:stock_pulse/services/pro_service.dart';
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
  Widget wrap(Widget child, PortfolioProvider provider, {ProService? pro}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PortfolioProvider>.value(value: provider),
        ChangeNotifierProvider<AdService>.value(value: AdService()),
        ChangeNotifierProvider<ProService>.value(value: pro ?? ProService()),
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

      // A fresh install opens in the neon theme, which is dark.
      final captured = tester.element(find.byType(Scaffold).first);
      expect(provider.themeMode, AppThemeId.neon);
      expect(Theme.of(captured).brightness, Brightness.dark);

      await provider.setThemeMode(AppThemeId.light);
      await tester.pumpAndSettle();

      expect(Theme.of(captured).brightness, Brightness.light);
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

      for (final mode in AppThemeId.pickerOrder) {
        await tester.scrollUntilVisible(find.text(mode.label), 120);
        await tester.tap(find.text(mode.label));
        await tester.pumpAndSettle();
        expect(provider.themeMode, mode);
      }
    });

    testWidgets('a locked Pro theme opens the Pro page instead of applying',
        (tester) async {
      final provider = PortfolioProvider(store: _MemoryStore());
      await provider.load();
      final pro = ProService(store: _MemoryStore(), sellsProForTest: true);

      await tester.pumpWidget(wrap(
        const MaterialApp(home: SettingsScreen()),
        provider,
        pro: pro,
      ));
      await settle(tester);

      await tester.scrollUntilVisible(find.text('Gold'), 120);
      await tester.ensureVisible(find.text('Gold'));
      await tester.pump();
      await tester.tap(find.text('Gold'));
      // The Pro page animates forever, so pump rather than settle.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('PRO'), findsWidgets);
      expect(find.textContaining('is part of Pro'), findsOneWidget);
      expect(provider.themeMode, isNot(AppThemeId.gold));

      // A rewarded trial unlocks the themes; the choice then applies.
      await pro.grantTrial(ProFeature.themes);
      await tester.pump();
      expect(find.text('You\'re Pro. Thank you!'), findsNothing);
    });
  });
}
