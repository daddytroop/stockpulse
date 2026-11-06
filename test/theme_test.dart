import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stock_pulse/app.dart';
import 'package:stock_pulse/providers/portfolio_provider.dart';
import 'package:stock_pulse/screens/settings_screen.dart';
import 'package:stock_pulse/services/ad_service.dart';
import 'package:stock_pulse/services/pro_service.dart';
import 'package:stock_pulse/services/store.dart';
import 'package:stock_pulse/theme/app_colors.dart';
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

  /// Scrolls the theme row in Settings until [label] is on screen.
  Future<void> showTheme(WidgetTester tester, String label) async {
    final row = find.descendant(
      of: find.byType(ThemeGrid),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.text(label), 120, scrollable: row.first);
    await tester.pumpAndSettle();
  }

  /// Loading the provider starts background fetches with short delays.
  /// They have to be flushed before a widget test ends.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  group('palettes', () {
    test('every theme looks different from every other', () {
      final seen = <String, AppThemeId>{};
      for (final id in AppThemeId.values.where((i) => i != AppThemeId.system)) {
        final t = AppTheme.themeFor(id, Brightness.light);
        final key = '${t.scaffoldBackgroundColor}/'
            '${t.colorScheme.primary}';
        expect(seen[key], isNull, reason: '$id looks the same as ${seen[key]}');
        seen[key] = id;
      }
    });

    test('gains are green and losses red in every theme', () {
      for (final id in AppThemeId.values) {
        for (final b in Brightness.values) {
          final c = AppTheme.themeFor(id, b).extension<AppColors>()!;
          final gainHue = HSLColor.fromColor(c.gain).hue;
          final lossHue = HSLColor.fromColor(c.loss).hue;
          expect(gainHue, inInclusiveRange(120, 170), reason: '$id gain');
          expect(lossHue < 15 || lossHue > 330, isTrue, reason: '$id loss');
        }
      }
    });

    test('the default accent keeps each theme its own colour', () {
      expect(AppTheme.accentFor(0), isNull);
      expect(AppTheme.themeFor(AppThemeId.mint, Brightness.light).colorScheme.primary,
          isNot(AppTheme.themeFor(AppThemeId.ocean, Brightness.light).colorScheme.primary));
      expect(AppTheme.themeFor(AppThemeId.ocean, Brightness.light).brightness,
          Brightness.dark);
    });

    test('follow system resolves with the device brightness', () {
      expect(AppTheme.themeFor(AppThemeId.system, Brightness.dark).brightness,
          Brightness.dark);
      expect(AppTheme.themeFor(AppThemeId.system, Brightness.light).brightness,
          Brightness.light);
    });
  });

  group('theme', () {
    testWidgets('follow system switches with the device', (tester) async {
      final provider = PortfolioProvider(store: _MemoryStore());
      await provider.load();
      await provider.setThemeMode(AppThemeId.system);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(wrap(StockPulseApp(), provider));
      await settle(tester);

      final captured = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(captured).brightness, Brightness.dark);
    });

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
      await showTheme(tester, 'Dark');
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
        await showTheme(tester, mode.label);
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

      await showTheme(tester, 'Gold');
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
