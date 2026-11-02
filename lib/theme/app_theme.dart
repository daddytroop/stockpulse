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
  ocean,

  /// Deep near-black with electric mint, cyan and violet glow. Added last so
  /// the saved index of every older theme keeps pointing at the same theme.
  neon,

  /// Pro themes.
  gold,
  aurora,
  sakura;

  /// Whether choosing this theme needs Pro.
  bool get isPremium =>
      this == AppThemeId.gold || this == AppThemeId.aurora || this == AppThemeId.sakura;

  String get label => switch (this) {
        AppThemeId.system => 'Follow system',
        AppThemeId.light => 'Light',
        AppThemeId.dark => 'Dark',
        AppThemeId.amoled => 'AMOLED black',
        AppThemeId.mint => 'Mint',
        AppThemeId.ocean => 'Ocean',
        AppThemeId.neon => 'Neon',
        AppThemeId.gold => 'Gold',
        AppThemeId.aurora => 'Aurora',
        AppThemeId.sakura => 'Sakura',
      };

  /// The order the picker lists the themes in: the signature look first,
  /// the Pro themes last.
  static const pickerOrder = [
    neon, system, light, dark, amoled, mint, ocean, gold, aurora, sakura,
  ];
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
      AppThemeId.neon =>
        neon(accent == null || accent == accents.first ? null : accent),
      AppThemeId.gold => gold(),
      AppThemeId.aurora => aurora(),
      AppThemeId.sakura => sakura(),
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

  // The neon palette.
  static const neonBackground = Color(0xFF060912);
  static const neonSurface = Color(0xFF0E1424);
  static const neonSurfaceHigh = Color(0xFF161E33);
  static const neonMint = Color(0xFF00F5A0);
  static const neonCyan = Color(0xFF00D9F5);
  static const neonViolet = Color(0xFF7C5CFF);
  static const neonText = Color(0xFFEAF0FF);
  static const neonMuted = Color(0xFF8A94B0);

  /// The signature gradient used for hero surfaces and highlights.
  static const neonGradient = [neonMint, neonCyan, neonViolet];

  /// Deep near-black surfaces with electric mint highlights. [accent]
  /// replaces the mint when the user picks a different accent colour.
  static ThemeData neon([Color? accent]) => _glow(
        primary: accent ?? neonMint,
        onPrimary: const Color(0xFF04110C),
        secondary: neonCyan,
        tertiary: neonViolet,
        background: neonBackground,
        surface: neonSurface,
        surfaceHigh: neonSurfaceHigh,
        surfaceHighest: const Color(0xFF1B2440),
        text: neonText,
        muted: neonMuted,
        outline: const Color(0xFF3A4566),
        outlineVariant: const Color(0xFF222B45),
      );

  /// Pro: black and warm gold, like a private-bank statement.
  static ThemeData gold() => _glow(
        primary: const Color(0xFFF5C451),
        onPrimary: const Color(0xFF1A1205),
        secondary: const Color(0xFFFFE3A3),
        tertiary: const Color(0xFFE08E3C),
        background: const Color(0xFF0A0805),
        surface: const Color(0xFF15110A),
        surfaceHigh: const Color(0xFF1F190F),
        surfaceHighest: const Color(0xFF2A2215),
        text: const Color(0xFFF7EEDC),
        muted: const Color(0xFFA8997C),
        outline: const Color(0xFF4F432D),
        outlineVariant: const Color(0xFF2E2619),
      );

  /// Pro: northern-lights violet, teal and pink on deep indigo.
  static ThemeData aurora() => _glow(
        primary: const Color(0xFF5EEAD4),
        onPrimary: const Color(0xFF03201B),
        secondary: const Color(0xFFA78BFA),
        tertiary: const Color(0xFFF472B6),
        background: const Color(0xFF07061A),
        surface: const Color(0xFF110F2A),
        surfaceHigh: const Color(0xFF1A1738),
        surfaceHighest: const Color(0xFF242046),
        text: const Color(0xFFEDEBFF),
        muted: const Color(0xFF9C96C4),
        outline: const Color(0xFF433D70),
        outlineVariant: const Color(0xFF26224A),
      );

  /// Pro: soft blossom pink on warm white.
  static ThemeData sakura() => _build(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFE85D9A),
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        background: const Color(0xFFFFF4F8),
      );

  /// A dark theme with glowing accents: the neon family.
  static ThemeData _glow({
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color tertiary,
    required Color background,
    required Color surface,
    required Color surfaceHigh,
    required Color surfaceHighest,
    required Color text,
    required Color muted,
    required Color outline,
    required Color outlineVariant,
  }) {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primary.withValues(alpha: .18),
      onPrimaryContainer: primary,
      secondary: secondary,
      onSecondary: onPrimary,
      secondaryContainer: secondary.withValues(alpha: .16),
      onSecondaryContainer: secondary,
      tertiary: tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: tertiary.withValues(alpha: .2),
      onTertiaryContainer: Color.lerp(tertiary, Colors.white, .6)!,
      error: const Color(0xFFFF3B6B),
      onError: Colors.white,
      errorContainer: const Color(0xFF3A0E1C),
      onErrorContainer: const Color(0xFFFFB3C4),
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerLowest: background,
      surfaceContainerLow: Color.lerp(background, surface, .5)!,
      surfaceContainer: Color.lerp(surface, surfaceHigh, .4)!,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: Colors.black,
      inverseSurface: text,
      onInverseSurface: background,
      inversePrimary: Color.lerp(primary, Colors.black, .3)!,
    );
    return _build(scheme,
        background: background, neon: true, colors: AppColors.neon(scheme));
  }

  /// Whether [theme] belongs to the neon family (Neon, Gold, Aurora),
  /// which ships its own glowing palette.
  static bool isNeon(ThemeData theme) =>
      theme.extension<AppColors>()?.gain == AppColors.neonGain;

  static ColorScheme _scheme(Color seed, Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: brightness == Brightness.dark ? const Color(0xFF111A1F) : Colors.white,
    );
  }

  static ThemeData _build(ColorScheme scheme,
      {bool amoled = false, bool neon = false, Color? background, AppColors? colors}) {
    colors ??= AppColors.fromScheme(scheme);
    final isDark = scheme.brightness == Brightness.dark;
    final base = background ?? (isDark ? const Color(0xFF081116) : const Color(0xFFF7F9F7));

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme.copyWith(surface: amoled ? Colors.black : scheme.surface),
      scaffoldBackgroundColor: base,
      hintColor: neon ? scheme.onSurfaceVariant : null,
      textTheme: _textTheme(scheme),
      cardTheme: CardThemeData(
        elevation: 0,
        color: amoled ? const Color(0xFF050505) : scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: neon ? .5 : .72),
        selectedColor: neon ? scheme.primary.withValues(alpha: .16) : scheme.primaryContainer,
        checkmarkColor: scheme.primary,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurface),
        secondaryLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: neon
            ? WidgetStateBorderSide.resolveWith((states) => BorderSide(
                  color: states.contains(WidgetState.selected)
                      ? scheme.primary.withValues(alpha: .55)
                      : scheme.outlineVariant,
                ))
            : BorderSide.none,
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
        height: 68,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? .16 : .14),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: neon ? base : null,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? .16 : .14),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w800, color: scheme.primary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: neon ? scheme.surface : null,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: neon ? scheme.surfaceContainerHigh : null,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: neon ? scheme.surfaceContainerHigh : null,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: .12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // The neon containers are translucent, which would make a muddy
        // button: neon gets a solid mint one instead.
        backgroundColor: neon ? scheme.primary : null,
        foregroundColor: neon ? scheme.onPrimary : null,
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
    // Tabular figures keep animated numbers from wobbling as digits change.
    const tabular = [FontFeature.tabularFigures()];
    const base = TextTheme(
      displayLarge: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1.3, fontFeatures: tabular),
      displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.9, fontFeatures: tabular),
      displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.7, fontFeatures: tabular),
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
