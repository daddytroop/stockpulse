import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// Round letter avatar with a stable per-symbol color.
class SymbolAvatar extends StatelessWidget {
  final String symbol;
  final double radius;
  const SymbolAvatar({super.key, required this.symbol, this.radius = 18});

  static const List<Color> _palette = [
    Color(0xFF1E88E5), Color(0xFF00897B), Color(0xFF8E24AA), Color(0xFFF4511E),
    Color(0xFF3949AB), Color(0xFF43A047), Color(0xFFD81B60), Color(0xFF6D4C41),
    Color(0xFF5E35B1), Color(0xFF00ACC1), Color(0xFF7CB342), Color(0xFFFB8C00),
    Color(0xFFC0CA33), Color(0xFF039BE5), Color(0xFFE53935), Color(0xFF546E7A),
  ];

  static Color colorFor(String symbol) => _palette[colorIndexFor(symbol)];

  @override
  Widget build(BuildContext context) {
    final color = colorFor(symbol);
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

  Color get _color => percent == null
      ? Colors.grey
      : percent! > 0
          ? const Color(0xFF2E7D32)
          : percent! < 0
              ? const Color(0xFFC62828)
              : Colors.grey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _color.withValues(alpha: 0.25) : _color.withValues(alpha: 0.12);
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
              color: _color,
            ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}