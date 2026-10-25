import 'package:flutter/material.dart';

/// Semantic finance colors that adapt to the current Material 3 [ColorScheme].
///
/// Stop copy-pasting `0xFF2E7D32` everywhere: use `AppColors.of(context).gain`
/// and friends instead. The palette works in both light and dark themes and
/// is color-blind friendly (green/red are never the only signal).
class AppColors extends ThemeExtension<AppColors> {
  @override
  ThemeExtension<AppColors> copyWith() => this;

  @override
  ThemeExtension<AppColors> lerp(covariant ThemeExtension<AppColors>? other, double t) => this;
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
  });

  factory AppColors.fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    // Gain/loss: derive from the scheme's error/tertiary so they respond to
    // dark mode and user theming, but shift the hue toward classic finance
    // greens for recognizability.
    final gain = _shiftHue(scheme.tertiary, isDark ? -10 : -15).withValues(alpha: 1.0);
    final gainContainer = gain.withValues(alpha: isDark ? 0.15 : 0.12);
    final loss = scheme.error;
    final lossContainer = loss.withValues(alpha: isDark ? 0.15 : 0.12);

    return AppColors._(
      gain: gain,
      gainContainer: gainContainer,
      onGainContainer: gain,
      loss: loss,
      lossContainer: lossContainer,
      onLossContainer: loss,
      earnings: isDark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00),
      earningsContainer: const Color(0xFFF57C00).withValues(alpha: isDark ? 0.15 : 0.12),
      dividend: isDark ? const Color(0xFF81C784) : const Color(0xFF43A047),
      crypto: const Color(0xFFF7931A),
      etf: scheme.secondary,
      stock: scheme.primary,
      cash: isDark ? const Color(0xFF90A4AE) : const Color(0xFF607D8B),
      other: scheme.outline,
      benchmark: scheme.outline,
      shimmerBase: isDark ? const Color(0xFF1E2A30) : const Color(0xFFEFF2F4),
      shimmerHighlight: isDark ? const Color(0xFF2A3A42) : const Color(0xFFF8FAFB),
      allocationPalette: _buildPalette(scheme, isDark),
    );
  }

  static AppColors of(BuildContext context) {
    return AppColors.fromScheme(Theme.of(context).colorScheme);
  }

  static List<Color> _buildPalette(ColorScheme scheme, bool isDark) {
    return [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      isDark ? const Color(0xFF4FC3F7) : const Color(0xFF039BE5),
      isDark ? const Color(0xFFFFB74D) : const Color(0xFFFB8C00),
      isDark ? const Color(0xFFCE93D8) : const Color(0xFF8E24AA),
      isDark ? const Color(0xFFEF5350) : const Color(0xFFE53935),
      isDark ? const Color(0xFF80CBC4) : const Color(0xFF00897B),
      isDark ? const Color(0xFFFFF59D) : const Color(0xFFFBC02D),
      isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
      isDark ? const Color(0xFFB39DDB) : const Color(0xFF5E35B1),
      isDark ? const Color(0xFFFFAB91) : const Color(0xFFD84315),
      isDark ? const Color(0xFFBCAAA4) : const Color(0xFF6D4C41),
      isDark ? const Color(0xFF80DEEA) : const Color(0xFF00ACC1),
      isDark ? const Color(0xFFA5D6A7) : const Color(0xFF43A047),
      isDark ? const Color(0xFFF48FB1) : const Color(0xFFC2185B),
    ];
  }

  /// Shift hue of [color] by [degrees].
  static Color _shiftHue(Color color, double degrees) {
    final hsl = HSLColor.fromColor(color);
    final shifted = hsl.withHue((hsl.hue + degrees) % 360);
    return shifted.toColor();
  }
}
