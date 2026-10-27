import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import 'animated_number.dart';

/// A headline metric tile.
///
/// Designed as the app's primary "at a glance" surface: a large animated
/// value, a supporting sub-line, an optional trend sparkline, and a subtle
/// accent wash that ties the tile to the current theme.
class KpiTile extends StatelessWidget {
  final String label;
  final num value;
  final String Function(num) formatter;

  /// Secondary line under the value.
  final String? sub;

  /// Colours the value (for example green for a gain).
  final Color? valueColor;

  /// Icon shown in the tile's corner.
  final IconData? icon;

  /// Optional sparkline drawn behind the value.
  final List<double>? spark;

  /// Colour of the sparkline.
  final Color? sparkColor;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  /// Emphasis level. [KpiEmphasis.hero] is the big summary tile.
  final KpiEmphasis emphasis;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.formatter,
    this.sub,
    this.valueColor,
    this.icon,
    this.spark,
    this.sparkColor,
    this.onTap,
    this.emphasis = KpiEmphasis.normal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final isDark = scheme.brightness == Brightness.dark;
    final hero = emphasis == KpiEmphasis.hero;

    final accent = valueColor ?? scheme.primary;
    final sparkPoints = spark;

    Widget content = Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: isDark ? 0.16 : 0.10),
                  accent.withValues(alpha: isDark ? 0.04 : 0.02),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, hero ? 16 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: accent),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.hintColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: hero ? 6 : 4),
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  if (sparkPoints != null && sparkPoints.length > 1)
                    Positioned.fill(
                      child: _Sparkline(
                        points: sparkPoints,
                        color: sparkColor ?? accent,
                      ),
                    ),
                  AnimatedNumber(
                    value: value,
                    formatter: formatter,
                    duration: const Duration(milliseconds: 900),
                    style: (hero
                            ? theme.textTheme.displaySmall
                            : theme.textTheme.titleLarge)
                        ?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: valueColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              if (sub != null) ...[
                const SizedBox(height: 3),
                Text(
                  sub!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    content = Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : colors.shimmerBase)
                .withValues(alpha: isDark ? 0.24 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (onTap != null) {
      content = _TilePress(onTap: onTap!, child: content);
    }
    return content;
  }
}

/// How prominent a [KpiTile] is.
enum KpiEmphasis { normal, hero }

/// A faint trend line drawn behind a tile's value.
class _Sparkline extends StatelessWidget {
  final List<double> points;
  final Color color;

  const _Sparkline({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SparklinePainter(points, color));
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  _SparklinePainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    var min = points.first, max = points.first;
    for (final p in points) {
      if (p < min) min = p;
      if (p > max) max = p;
    }
    final span = max - min;
    if (span <= 0) return;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = size.height - ((points[i] - min) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.color != color || !identical(oldDelegate.points, points);
}

/// Press feedback for a tile: a subtle lift and scale.
class _TilePress extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TilePress({required this.child, required this.onTap});

  @override
  State<_TilePress> createState() => _TilePressState();
}

class _TilePressState extends State<_TilePress> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        if (!reduceMotion) {
          HapticFeedback.selectionClick();
        }
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down && !reduceMotion ? 0.98 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          transform: Matrix4.translationValues(0, _down ? -1 : 0, 0),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A row of [KpiTile]s that wraps on narrow screens.
class KpiRow extends StatelessWidget {
  final List<KpiTile> tiles;
  final double spacing;

  const KpiRow({super.key, required this.tiles, this.spacing = 10});

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Two columns on a phone, more when there is room.
        final columns = width >= 760 ? 4 : (width >= 420 ? 3 : 2);
        const gap = 10.0;
        final tileWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}
