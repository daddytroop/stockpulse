import 'dart:math';

import 'package:flutter/material.dart';

/// Counts up (or directly shows) a numeric value with a smooth tween.
/// Useful for portfolio totals and large metric cards.
class AnimatedNumber extends StatefulWidget {
  final num value;
  final String Function(num) formatter;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;

  const AnimatedNumber({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
  });

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  num _previous = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _previous = widget.value;
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant AnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previous = oldWidget.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        final current = widget.value;
        final displayed = _previous + (current - _previous) * _ease(t);
        return Text(
          widget.formatter(displayed),
          style: widget.style,
          textAlign: widget.textAlign,
        );
      },
    );
  }

  // Ease-out quint for snappy settling.
  static double _ease(double t) => 1 - pow(1 - t, 5).toDouble();
}
