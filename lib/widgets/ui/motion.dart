import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// Pushed screens: horizontal shared-axis (300 ms). With reduced motion: a plain fade.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const _sharedAxis = SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.horizontal);

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (AppMotion.reduced(context)) return FadeTransition(opacity: animation, child: child);
    return _sharedAxis.buildTransitions(route, context, animation, secondaryAnimation, child);
  }
}

/// Tab content: fade-through when [child]'s key changes. With reduced motion: a short fade.
class FadeThroughSwitcher extends StatelessWidget {
  const FadeThroughSwitcher({super.key, required this.child});

  /// Must carry a key that changes with the tab (e.g. ValueKey(index)).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return PageTransitionSwitcher(
      duration: reduced ? AppMotion.fast : const Duration(milliseconds: 300),
      transitionBuilder: (child, primary, secondary) => reduced
          ? FadeTransition(opacity: primary, child: child)
          : FadeThroughTransition(
              animation: primary,
              secondaryAnimation: secondary,
              fillColor: Colors.transparent,
              child: child,
            ),
      child: child,
    );
  }
}

/// A number that counts from its previous value to the new one whenever it changes.
/// With [fromZero], the first appearance also counts up from 0.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount(
    this.value, {
    super.key,
    this.style,
    this.format,
    this.prefix = '',
    this.suffix = '',
    this.fromZero = false,
    this.duration = AppMotion.countUp,
  });

  final int value;
  final TextStyle? style;
  final String Function(int)? format;
  final String prefix;
  final String suffix;
  final bool fromZero;
  final Duration duration;

  String _text(int v) => '$prefix${format?.call(v) ?? v}$suffix';

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: fromZero ? 0 : value.toDouble(), end: value.toDouble()),
        duration: AppMotion.of(context, duration),
        curve: AppMotion.standard,
        // Screen readers get the final number, not every intermediate frame.
        builder: (_, v, __) => Text(_text(v.round()), style: style, semanticsLabel: _text(value)),
      );
}

/// Progress bar that fills from 0 on first show and then from the old value to the new one.
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({super.key, required this.progress, required this.color, this.height = 8, this.trackColor,
      this.fromZero = true});

  final double progress;
  /// Fill from 0 when first shown; false shows the current value at once (e.g. revisiting a tab).
  final bool fromZero;
  final Color color;
  final double height;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: fromZero ? 0 : progress.clamp(0.0, 1.0), end: progress.clamp(0.0, 1.0)),
        duration: AppMotion.of(context, AppMotion.slow),
        curve: AppMotion.standard,
        builder: (_, v, __) => ClipRRect(
          borderRadius: AppRadius.all(height),
          child: LinearProgressIndicator(
            value: v,
            minHeight: height,
            backgroundColor: trackColor ?? context.colors.surfaceAlt,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      );
}

/// Hero flight that keeps text styled mid-flight (the overlay has no Material ancestor).
Widget heroMaterialFlight(BuildContext _, Animation<double> __, HeroFlightDirection ___,
        BuildContext from, BuildContext to) =>
    Material(type: MaterialType.transparency, child: (to.widget as Hero).child);
