import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// Round letter avatar with a stable per-symbol color.
class SymbolAvatar extends StatelessWidget {
  final String symbol;
  final double radius;
  const SymbolAvatar({super.key, required this.symbol, this.radius = 18});

  static Color colorFor(BuildContext context, String symbol) {
    final palette = AppColors.of(context).allocationPalette;
    return palette[colorIndexFor(symbol) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(context, symbol);
    final initials = _initials(symbol);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }

  String _initials(String symbol) {
    final clean = symbol.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.isEmpty) return '?';
    if (clean.length == 1) return clean;
    // Take letters from the start; crypto like BTC-USD -> BT.
    return clean.substring(0, 2);
  }
}

/// Small circular percentage/change chip, color-coded.
class ChangeChip extends StatelessWidget {
  final double? percent;
  final String label;
  const ChangeChip({super.key, required this.percent, required this.label});

  Color _color(BuildContext context) {
    final colors = AppColors.of(context);
    if (percent == null) return Theme.of(context).hintColor;
    if (percent! > 0) return colors.gain;
    if (percent! < 0) return colors.loss;
    return Theme.of(context).hintColor;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (percent != null && percent! != 0)
            Icon(
              percent! > 0 ? Icons.trending_up : Icons.trending_down,
              size: 14,
              color: color,
            ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}