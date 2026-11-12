import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';

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
    this.borderRadius = Sp.radius,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              ? Colors.white.withValues(alpha: 0.07)
              : scheme.outlineVariant,
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
          // Dark surfaces separate by their border and tone; a shadow under
          // every card only costs frames. Light themes keep one soft one.
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
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
