import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Visual themes for Stock Pulse. Themes are intentionally named instead of
/// just light/dark so accents, contrast, and surface depth can feel distinct.
enum AppThemeId {
  system,
  light,
  dark,
  amoled,
  mint,
  ocean;

  String get label => switch (this) {
        AppThemeId.system => 'Follow system',
        AppThemeId.light => 'Light',
        AppThemeId.dark => 'Dark',
        AppThemeId.amoled => 'AMOLED black',
        AppThemeId.mint => 'Mint',
        AppThemeId.ocean => 'Ocean',
      };
}

class AppTheme {
  AppTheme._();

  static const accents = [
    Color(0xFF14B8A6),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF0EA5E9),
    Color(0xFFF97316),
    Color(0xFFE11D48),
    Color(0xFF84CC16),
    Color(0xFFEAB308),
  ];

  static ThemeData themeFor(AppThemeId id, Brightness platformBrightness,
      {Color? accent}) {
    final effective = id == AppThemeId.system
        ? (platformBrightness == Brightness.dark ? AppThemeId.dark : AppThemeId.light)
        : id;
    final seed = accent ?? _defaultAccent(effective);
    return switch (effective) {
      AppThemeId.system || AppThemeId.light => _custom(seed, Brightness.light),
      AppThemeId.dark => _custom(seed, Brightness.dark),
      AppThemeId.amoled => amoled(seed),
      AppThemeId.mint => mint(seed),
      AppThemeId.ocean => ocean(seed),
    };
  }

  static Color _defaultAccent(AppThemeId id) => switch (id) {
        AppThemeId.mint => const Color(0xFF00A878),
        AppThemeId.ocean => const Color(0xFF2563EB),
        AppThemeId.amoled => const Color(0xFF34D399),
        _ => accents.first,
      };

  static ThemeData _custom(Color seed, Brightness brightness) => _build(
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness, surface: brightness == Brightness.dark ? const Color(0xFF111A1F) : Colors.white),
      );

  static ThemeData light() => _build(_scheme(const Color(0xFF14B8A6), Brightness.light));

  static ThemeData dark() => _build(_scheme(const Color(0xFF2DD4BF), Brightness.dark));

  static ThemeData amoled([Color seed = const Color(0xFF34D399)]) => _build(
        _scheme(seed, Brightness.dark)
            .copyWith(surface: Colors.black, surfaceContainer: Colors.black),
        amoled: true,
      );

  static ThemeData mint([Color seed = const Color(0xFF00A878)]) => _build(
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xFFF4FFFA),
        ),
        background: const Color(0xFFEEFAFA),
      );

  static ThemeData ocean([Color seed = const Color(0xFF2563EB)]) => _build(
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF0B1220),
        ),
        background: const Color(0xFF070B14),
      );

  static ColorScheme _scheme(Color seed, Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: brightness == Brightness.dark ? const Color(0xFF111A1F) : Colors.white,
    );
  }

  static ThemeData _build(ColorScheme scheme, {bool amoled = false, Color? background}) {
    final colors = AppColors.fromScheme(scheme);
    final isDark = scheme.brightness == Brightness.dark;
    final base = background ?? (isDark ? const Color(0xFF081116) : const Color(0xFFF7F9F7));

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme.copyWith(surface: amoled ? Colors.black : scheme.surface),
      scaffoldBackgroundColor: base,
      textTheme: _textTheme(scheme),
      cardTheme: CardThemeData(
        elevation: 0,
        color: amoled ? const Color(0xFF050505) : scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: .72),
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide.none,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .58),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: .22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: base.withValues(alpha: isDark ? .92 : .82),
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        elevation: 0,
        backgroundColor: scheme.surface.withValues(alpha: .94),
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: .55), space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      splashColor: scheme.primary.withValues(alpha: .08),
      highlightColor: scheme.primary.withValues(alpha: .04),
      extensions: [colors],
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    const base = TextTheme(
      displayLarge: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1.3),
      displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.9),
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.35),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.45),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .45),
    );
    return base.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
