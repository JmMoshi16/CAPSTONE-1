import 'package:animations/animations.dart' show SharedAxisPageTransitionsBuilder, SharedAxisTransitionType;
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

/// Tabs that keep their state: each tab is built the first time it is shown and then kept
/// (offstage, with its animations paused) while another tab is visible. The incoming tab
/// fades and grows in (fade-through style, 300 ms); with reduced motion it simply fades.
class FadeIndexedStack extends StatefulWidget {
  const FadeIndexedStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300), value: 1);
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: const Interval(0.2, 1, curve: Curves.easeOut));
  late final Animation<double> _scale =
      Tween<double>(begin: 0.96, end: 1).animate(CurvedAnimation(parent: _c, curve: AppMotion.standard));
  final Set<int> _built = {};

  @override
  void didUpdateWidget(FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _c.duration = AppMotion.reduced(context) ? AppMotion.fast : const Duration(milliseconds: 300);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _built.add(widget.index);
    final reduced = AppMotion.reduced(context);
    const still = AlwaysStoppedAnimation<double>(1);
    return Stack(fit: StackFit.expand, children: [
      for (var i = 0; i < widget.children.length; i++)
        KeyedSubtree(
          key: ValueKey(i),
          child: !_built.contains(i)
              ? const SizedBox.shrink()
              : Offstage(
                  offstage: i != widget.index,
                  child: TickerMode(
                    enabled: i == widget.index,
                    // The wrappers stay the same type for every tab, so a tab's state survives switching.
                    child: FadeTransition(
                      opacity: i == widget.index ? _fade : still,
                      child: ScaleTransition(
                        scale: i == widget.index && !reduced ? _scale : still,
                        child: widget.children[i],
                      ),
                    ),
                  ),
                ),
        ),
    ]);
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
            semanticsValue: '${(progress.clamp(0.0, 1.0) * 100).round()}%',
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
