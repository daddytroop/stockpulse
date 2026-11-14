import 'package:flutter/material.dart';

/// Fades and lifts [child] in once, [order] steps after its siblings.
///
/// With [enabled] false the child is simply shown, in the same widget
/// shape, so a screen can stop animating after its first appearance
/// without rebuilding what is inside (a list that scrolls back into view
/// should not play its entrance again).
class Entrance extends StatefulWidget {
  final int order;
  final bool enabled;
  final Widget child;

  const Entrance({
    super.key,
    this.order = 0,
    this.enabled = true,
    required this.child,
  });

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  static const _stepMs = 55;
  static const _moveMs = 360;

  late final AnimationController _c;
  late final Animation<double> _t;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final delay = _stepMs * widget.order;
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: delay + _moveMs),
    );
    // The wait is part of the animation, so no timer is left running.
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(delay / (delay + _moveMs), 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.enabled && !still) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _t,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(_t),
        child: widget.child,
      ),
    );
  }
}
