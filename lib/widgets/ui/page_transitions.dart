import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// A shared-axis route transition used for drill-down screens
/// (HoldingDetail, Import, etc.). Feels modern and connected.
class SharedAxisRoute<T> extends MaterialPageRoute<T> {
  SharedAxisRoute({required super.builder, super.settings})
      : super(
          maintainState: true,
          fullscreenDialog: false,
        );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: SharedAxisTransitionType.horizontal,
      child: child,
    );
  }
}

/// A fade-through route for modal-ish full-screen flows.
class FadeThroughRoute<T> extends MaterialPageRoute<T> {
  FadeThroughRoute({required super.builder, super.settings})
      : super(
          maintainState: true,
          fullscreenDialog: false,
        );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeThroughTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// Convenience Navigator helper for the app's main drill-down.
Future<T?> pushSharedAxis<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push<T>(SharedAxisRoute<T>(builder: (_) => screen));
}
