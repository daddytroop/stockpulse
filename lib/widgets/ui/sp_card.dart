import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

/// A polished card with optional gradient surface, subtle border, and press
/// animation. Used as the visual foundation for most cards in the app.
class SpCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final List<Color>? gradient;
  final VoidCallback? onTap;
  final double borderRadius;
  final double borderAlpha;

  /// A soft coloured halo around the card, for the one or two surfaces on a
  /// screen that deserve attention.
  final Color? glow;

  const SpCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.backgroundColor,
    this.gradient,
    this.onTap,
    this.borderRadius = 20,
    this.borderAlpha = 0.08,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    final isDark = scheme.brightness == Brightness.dark;
    final baseColor = backgroundColor ?? scheme.surface;
    final radius = BorderRadius.circular(borderRadius);

    Widget content = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: gradient == null ? baseColor : null,
        gradient: gradient != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient!,
              )
            : null,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : scheme.outline.withValues(alpha: borderAlpha),
          width: 1,
        ),
        boxShadow: [
          if (glow != null)
            BoxShadow(
              color: glow!.withValues(alpha: isDark ? .22 : .16),
              blurRadius: 32,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          BoxShadow(
            color: (isDark ? Colors.black : colors.shimmerBase)
                .withValues(alpha: isDark ? .32 : .05),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: isDark
            // A faint sheen along the top edge, like light catching glass.
            ? DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.white.withValues(alpha: 0.035),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Padding(padding: padding, child: child),
              )
            : Padding(padding: padding, child: child),
      ),
    );

    if (onTap != null) {
      content = _PressScale(
        onTap: onTap!,
        child: content,
      );
    }

    return Padding(padding: margin, child: content);
  }
}

/// Subtle scale down on tap for a tactile "premium" feel.
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.animateTo(0.97),
      onTapUp: (_) {
        _controller.animateTo(1.0);
        if (!MediaQuery.disableAnimationsOf(context)) {
          HapticFeedback.selectionClick();
        }
        widget.onTap();
      },
      onTapCancel: () => _controller.animateTo(1.0),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => Transform.scale(
          scale: MediaQuery.disableAnimationsOf(context) ? 1 : _controller.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
