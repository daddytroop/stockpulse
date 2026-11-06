import 'package:flutter/material.dart';

/// Semantic finance colors for the current theme.
///
/// Use `AppColors.of(context).gain` and friends instead of literal colors.
/// Every theme ships its own set (see [AppTheme]), so gains are always a
/// clear green and losses a clear red, whatever the accent colour is.
/// Green/red is never the only signal: values also carry a sign or arrow.
class AppColors extends ThemeExtension<AppColors> {
  final Color gain;
  final Color gainContainer;
  final Color onGainContainer;
  final Color loss;
  final Color lossContainer;
  final Color onLossContainer;
  final Color earnings;
  final Color earningsContainer;
  final Color dividend;
  final Color crypto;
  final Color etf;
  final Color stock;
  final Color cash;
  final Color other;
  final Color benchmark;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final List<Color> allocationPalette;

  /// The theme's signature gradient, used for hero surfaces, highlights
  /// and the ambient background glow.
  final List<Color> accentGradient;

  /// Whether the theme uses glowing effects (the dark "neon family").
  final bool glow;

  const AppColors._({
    required this.gain,
    required this.gainContainer,
    required this.onGainContainer,
    required this.loss,
    required this.lossContainer,
    required this.onLossContainer,
    required this.earnings,
    required this.earningsContainer,
    required this.dividend,
    required this.crypto,
    required this.etf,
    required this.stock,
    required this.cash,
    required this.other,
    required this.benchmark,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.allocationPalette,
    required this.accentGradient,
    required this.glow,
  });

  /// The neon family's gain colour.
  static const neonGain = Color(0xFF00F5A0);

  /// Colours for a theme built from [scheme].
  ///
  /// [gain] and [loss] default to finance green and red tuned for the
  /// scheme's brightness. [gradient] defaults to primary → secondary →
  /// tertiary.
  factory AppColors.forScheme(
    ColorScheme scheme, {
    Color? gain,
    Color? loss,
    List<Color>? gradient,
    bool glow = false,
    List<Color>? palette,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final g = gain ?? (isDark ? const Color(0xFF34D399) : const Color(0xFF0E9F6E));
    final l = loss ?? (isDark ? const Color(0xFFFF5C7A) : const Color(0xFFE5484D));
    final containerAlpha = isDark ? 0.15 : 0.11;
    return AppColors._(
      gain: g,
      gainContainer: g.withValues(alpha: containerAlpha),
      onGainContainer: g,
      loss: l,
      lossContainer: l.withValues(alpha: containerAlpha),
      onLossContainer: l,
      earnings: isDark ? const Color(0xFFFFB547) : const Color(0xFFE07B00),
      earningsContainer:
          const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.12),
      dividend: isDark ? const Color(0xFF5CF2C4) : const Color(0xFF0E9F6E),
      crypto: const Color(0xFFF7931A),
      etf: scheme.tertiary,
      stock: scheme.primary,
      cash: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      other: scheme.outline,
      benchmark: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      shimmerBase: Color.lerp(scheme.surface, scheme.onSurface, isDark ? .06 : .05)!,
      shimmerHighlight:
          Color.lerp(scheme.surface, scheme.onSurface, isDark ? .12 : .015)!,
      allocationPalette: palette ?? _palette(scheme, isDark),
      accentGradient: gradient ?? [scheme.primary, scheme.secondary, scheme.tertiary],
      glow: glow,
    );
  }

  /// Kept for callers that only have a scheme.
  factory AppColors.fromScheme(ColorScheme scheme) => AppColors.forScheme(scheme);

  /// The glowing palette shared by Neon, Gold and Aurora.
  factory AppColors.neon(ColorScheme scheme, {List<Color>? gradient}) =>
      AppColors.forScheme(
        scheme,
        gain: neonGain,
        loss: const Color(0xFFFF3B6B),
        gradient: gradient,
        glow: true,
        palette: const [
          Color(0xFF00F5A0),
          Color(0xFF00D9F5),
          Color(0xFF7C5CFF),
          Color(0xFFFF3BCB),
          Color(0xFFFFB547),
          Color(0xFF3B82F6),
          Color(0xFFB7FF3B),
          Color(0xFFFF6B3B),
          Color(0xFF5CF2C4),
          Color(0xFFA78BFA),
          Color(0xFFFF3B6B),
          Color(0xFF38BDF8),
          Color(0xFFFDE047),
          Color(0xFF2DD4BF),
          Color(0xFFF472B6),
          Color(0xFF94A3B8),
        ],
      );

  /// The colours of the current theme.
  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ?? AppColors.forScheme(theme.colorScheme);
  }

  static List<Color> _palette(ColorScheme scheme, bool isDark) => [
        scheme.primary,
        scheme.secondary,
        scheme.tertiary,
        isDark ? const Color(0xFF4FC3F7) : const Color(0xFF0284C7),
        isDark ? const Color(0xFFFFB74D) : const Color(0xFFEA580C),
        isDark ? const Color(0xFFCE93D8) : const Color(0xFF9333EA),
        isDark ? const Color(0xFFFF8A80) : const Color(0xFFDC2626),
        isDark ? const Color(0xFF80CBC4) : const Color(0xFF0D9488),
        isDark ? const Color(0xFFFFF59D) : const Color(0xFFCA8A04),
        isDark ? const Color(0xFF90CAF9) : const Color(0xFF1D4ED8),
        isDark ? const Color(0xFFB39DDB) : const Color(0xFF6D28D9),
        isDark ? const Color(0xFFFFAB91) : const Color(0xFFC2410C),
        isDark ? const Color(0xFFBCAAA4) : const Color(0xFF78350F),
        isDark ? const Color(0xFF80DEEA) : const Color(0xFF0891B2),
        isDark ? const Color(0xFFA5D6A7) : const Color(0xFF15803D),
        isDark ? const Color(0xFFF48FB1) : const Color(0xFFBE185D),
      ];

  @override
  AppColors copyWith() => this;

  /// Blends every colour, so switching themes cross-fades instead of
  /// snapping.
  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> list(List<Color> a, List<Color> b) => [
          for (var i = 0; i < a.length; i++) i < b.length ? c(a[i], b[i]) : a[i],
        ];
    return AppColors._(
      gain: c(gain, other.gain),
      gainContainer: c(gainContainer, other.gainContainer),
      onGainContainer: c(onGainContainer, other.onGainContainer),
      loss: c(loss, other.loss),
      lossContainer: c(lossContainer, other.lossContainer),
      onLossContainer: c(onLossContainer, other.onLossContainer),
      earnings: c(earnings, other.earnings),
      earningsContainer: c(earningsContainer, other.earningsContainer),
      dividend: c(dividend, other.dividend),
      crypto: c(crypto, other.crypto),
      etf: c(etf, other.etf),
      stock: c(stock, other.stock),
      cash: c(cash, other.cash),
      other: c(this.other, other.other),
      benchmark: c(benchmark, other.benchmark),
      shimmerBase: c(shimmerBase, other.shimmerBase),
      shimmerHighlight: c(shimmerHighlight, other.shimmerHighlight),
      allocationPalette: list(allocationPalette, other.allocationPalette),
      accentGradient: list(accentGradient, other.accentGradient),
      glow: t < .5 ? glow : other.glow,
    );
  }
}
