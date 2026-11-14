import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'tokens.dart';

/// Visual themes for Stock Pulse. Every theme is a hand-tuned palette, not
/// a generated one, so each looks clearly different from the others.
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

  /// One line describing the theme in the picker.
  String get blurb => switch (this) {
        AppThemeId.system => 'Light by day, dark by night',
        AppThemeId.light => 'Crisp and bright',
        AppThemeId.dark => 'Easy on the eyes',
        AppThemeId.amoled => 'True black, saves battery',
        AppThemeId.mint => 'Fresh green on white',
        AppThemeId.ocean => 'Deep blue sea',
        AppThemeId.neon => 'Electric glow',
        AppThemeId.gold => 'Black and gold',
        AppThemeId.aurora => 'Northern lights',
        AppThemeId.sakura => 'Cherry blossom',
      };

  /// The order the picker lists the themes in: the signature look first,
  /// the Pro themes last.
  static const pickerOrder = [
    neon, system, light, dark, amoled, mint, ocean, gold, aurora, sakura,
  ];
}

class AppTheme {
  AppTheme._();

  /// Accent colours the user can pick. The first entry means "the theme's
  /// own accent"; the swatch shown for it is only a stand-in.
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

  /// The accent for a saved accent index: null for the theme's own.
  static Color? accentFor(int index) =>
      index <= 0 || index >= accents.length ? null : accents[index];

  /// The theme for [id]. "Follow system" resolves with [platformBrightness].
  static ThemeData themeFor(AppThemeId id, Brightness platformBrightness,
      {Color? accent}) {
    final effective = id == AppThemeId.system
        ? (platformBrightness == Brightness.dark ? AppThemeId.dark : AppThemeId.light)
        : id;
    return switch (effective) {
      AppThemeId.system || AppThemeId.light => light(accent),
      AppThemeId.dark => dark(accent),
      AppThemeId.amoled => amoled(accent),
      AppThemeId.mint => mint(accent),
      AppThemeId.ocean => ocean(accent),
      AppThemeId.neon => neon(accent),
      AppThemeId.gold => gold(),
      AppThemeId.aurora => aurora(),
      AppThemeId.sakura => sakura(),
    };
  }

  /// Whether [id] is a dark theme (for "Follow system", on a light device).
  static bool isDarkTheme(AppThemeId id) =>
      themeFor(id, Brightness.light).brightness == Brightness.dark;

  // The neon palette, also used by the Pro page.
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

  static ThemeData light([Color? accent]) => _palette(
        brightness: Brightness.light,
        primary: accent ?? const Color(0xFF0D9488),
        onPrimary: Colors.white,
        secondary: const Color(0xFF0284C7),
        tertiary: const Color(0xFF7C3AED),
        background: const Color(0xFFF4F6FA),
        surface: Colors.white,
        surfaceHigh: const Color(0xFFEEF2F7),
        surfaceHighest: const Color(0xFFE3E8F0),
        text: const Color(0xFF0B1220),
        muted: const Color(0xFF5B6577),
        outline: const Color(0xFFC3CBD7),
        outlineVariant: const Color(0xFFE2E7EE),
      );

  static ThemeData dark([Color? accent]) => _palette(
        brightness: Brightness.dark,
        primary: accent ?? const Color(0xFF2DD4BF),
        onPrimary: const Color(0xFF04201C),
        secondary: const Color(0xFF60A5FA),
        tertiary: const Color(0xFFA78BFA),
        background: const Color(0xFF0B0F14),
        surface: const Color(0xFF131922),
        surfaceHigh: const Color(0xFF1A222D),
        surfaceHighest: const Color(0xFF232D3A),
        text: const Color(0xFFE8EDF4),
        muted: const Color(0xFF8D98A8),
        outline: const Color(0xFF3A4554),
        outlineVariant: const Color(0xFF232C38),
      );

  static ThemeData amoled([Color? accent]) => _palette(
        brightness: Brightness.dark,
        primary: accent ?? const Color(0xFF34D399),
        onPrimary: const Color(0xFF00180F),
        secondary: const Color(0xFF22D3EE),
        tertiary: const Color(0xFFA78BFA),
        background: Colors.black,
        surface: const Color(0xFF0A0A0B),
        surfaceHigh: const Color(0xFF141416),
        surfaceHighest: const Color(0xFF1D1D20),
        text: const Color(0xFFF2F2F2),
        muted: const Color(0xFF8A8A8F),
        outline: const Color(0xFF34343A),
        outlineVariant: const Color(0xFF1C1C20),
      );

  static ThemeData mint([Color? accent]) => _palette(
        brightness: Brightness.light,
        primary: accent ?? const Color(0xFF00A878),
        onPrimary: Colors.white,
        secondary: const Color(0xFF14B8A6),
        tertiary: const Color(0xFF0EA5E9),
        background: const Color(0xFFE9FAF2),
        surface: const Color(0xFFFBFFFD),
        surfaceHigh: const Color(0xFFE0F6EB),
        surfaceHighest: const Color(0xFFCFEFDF),
        text: const Color(0xFF06281D),
        muted: const Color(0xFF4A6B5E),
        outline: const Color(0xFFB2DAC8),
        outlineVariant: const Color(0xFFD3EEE1),
      );

  static ThemeData ocean([Color? accent]) => _palette(
        brightness: Brightness.dark,
        primary: accent ?? const Color(0xFF38BDF8),
        onPrimary: const Color(0xFF021627),
        secondary: const Color(0xFF818CF8),
        tertiary: const Color(0xFF22D3EE),
        background: const Color(0xFF030B18),
        surface: const Color(0xFF0A1A2F),
        surfaceHigh: const Color(0xFF10243F),
        surfaceHighest: const Color(0xFF17304F),
        text: const Color(0xFFE6F1FF),
        muted: const Color(0xFF8AA3C2),
        outline: const Color(0xFF2B4466),
        outlineVariant: const Color(0xFF15294A),
      );

  /// Deep near-black surfaces with electric mint highlights. [accent]
  /// replaces the mint when the user picks a different accent colour.
  static ThemeData neon([Color? accent]) => _palette(
        brightness: Brightness.dark,
        glow: true,
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
  static ThemeData gold() => _palette(
        brightness: Brightness.dark,
        glow: true,
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
  static ThemeData aurora() => _palette(
        brightness: Brightness.dark,
        glow: true,
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
  static ThemeData sakura() => _palette(
        brightness: Brightness.light,
        primary: const Color(0xFFDB2777),
        onPrimary: Colors.white,
        secondary: const Color(0xFFA855F7),
        tertiary: const Color(0xFFFB7185),
        background: const Color(0xFFFFF4F8),
        surface: Colors.white,
        surfaceHigh: const Color(0xFFFDEAF1),
        surfaceHighest: const Color(0xFFF9DAE6),
        text: const Color(0xFF2A0E19),
        muted: const Color(0xFF7A5464),
        outline: const Color(0xFFEBC2D2),
        outlineVariant: const Color(0xFFF6DEE8),
      );

  /// Builds a theme from a hand-picked palette.
  static ThemeData _palette({
    required Brightness brightness,
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
    bool glow = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primary.withValues(alpha: isDark ? .18 : .12),
      onPrimaryContainer: isDark ? primary : Color.lerp(primary, Colors.black, .35)!,
      secondary: secondary,
      onSecondary: onPrimary,
      secondaryContainer: secondary.withValues(alpha: isDark ? .16 : .12),
      onSecondaryContainer: isDark ? secondary : Color.lerp(secondary, Colors.black, .35)!,
      tertiary: tertiary,
      onTertiary: Colors.white,
      tertiaryContainer: tertiary.withValues(alpha: isDark ? .2 : .12),
      onTertiaryContainer: isDark
          ? Color.lerp(tertiary, Colors.white, .6)!
          : Color.lerp(tertiary, Colors.black, .35)!,
      error: isDark ? const Color(0xFFFF3B6B) : const Color(0xFFDC2626),
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF3A0E1C) : const Color(0xFFFDE8E8),
      onErrorContainer: isDark ? const Color(0xFFFFB3C4) : const Color(0xFF7F1D1D),
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
      scrim: Colors.black,
      inverseSurface: text,
      onInverseSurface: background,
      inversePrimary: Color.lerp(primary, isDark ? Colors.black : Colors.white, .3)!,
    );
    final colors = glow
        ? AppColors.neon(scheme, gradient: [primary, secondary, tertiary])
        : AppColors.forScheme(scheme);
    return _build(scheme, background: background, neon: glow, colors: colors);
  }

  /// Whether [theme] belongs to the glowing neon family (Neon, Gold,
  /// Aurora).
  static bool isNeon(ThemeData theme) => theme.extension<AppColors>()?.glow ?? false;

  static ThemeData _build(ColorScheme scheme,
      {bool neon = false, Color? background, AppColors? colors}) {
    colors ??= AppColors.forScheme(scheme);
    final isDark = scheme.brightness == Brightness.dark;
    final base = background ?? (isDark ? const Color(0xFF081116) : const Color(0xFFF7F9F7));

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: base,
      hintColor: scheme.onSurfaceVariant,
      textTheme: _textTheme(scheme),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        // The same hairline edge as SpCard, so plain cards match.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sp.radius),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: .07) : scheme.outlineVariant,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: neon ? .5 : .72),
        selectedColor: neon ? scheme.primary.withValues(alpha: .16) : scheme.primaryContainer,
        checkmarkColor: scheme.primary,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        showCheckmark: false,
        secondaryLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: .7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: base.withValues(alpha: isDark ? .92 : .82),
        titleSpacing: Sp.page,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.3, color: scheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 62,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? .16 : .14),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: base,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? .16 : .14),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w800, color: scheme.primary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: .12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // The containers are translucent, which would make a muddy
        // button: every theme gets a solid one in its accent instead.
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.4, height: 1.05, fontFeatures: tabular),
      displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.1, fontFeatures: tabular),
      displaySmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.15, fontFeatures: tabular),
      headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineSmall: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.4),
      bodyMedium: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: .2),
    );
    return base.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
