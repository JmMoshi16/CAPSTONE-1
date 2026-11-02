import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// How far a surface sits above the page.
/// - [base]: solid and quiet, for most cards.
/// - [raised]: lit from above, for content that should be picked out (carousel cards, tickets).
/// - [floating]: the strongest separation, for the one thing a screen is about (the Home balance).
enum Depth { base, raised, floating }

/// The app's material. On the forest hero ([onHero]) it is frosted glass: a blur of what is behind, a white
/// tint that is brighter at the top (light from above) and a hairline edge. On the page it is the card surface,
/// lifted by a shadow in light mode and by a lit top edge in dark mode, where shadows read as dirt.
/// With the system's high-contrast setting on, glass becomes solid.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.depth = Depth.raised,
    this.onHero = false,
    this.padding = const EdgeInsets.all(AppSpace.md),
    this.radius = AppRadius.xl,
  });

  final Widget child;
  final Depth depth;
  final bool onHero;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final solid = MediaQuery.highContrastOf(context);
    final r = AppRadius.all(radius);
    return onHero ? _glass(solid, r) : _card(context, solid, r);
  }

  Widget _glass(bool solid, BorderRadius r) {
    final strength = switch (depth) { Depth.base => 0.5, Depth.raised => 0.75, Depth.floating => 1.0 };
    final pane = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: r,
        color: solid ? AppPalette.forestDeep : null,
        gradient: solid
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.35, 1],
                colors: [
                  Colors.white.withValues(alpha: 0.24 * strength),
                  Colors.white.withValues(alpha: 0.13 * strength),
                  Colors.white.withValues(alpha: 0.08 * strength),
                ],
              ),
        border: Border.all(color: Colors.white.withValues(alpha: solid ? 0.6 : 0.14 + 0.1 * strength)),
      ),
      child: child,
    );
    if (solid || depth == Depth.base) return pane;
    final glass = ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: depth == Depth.floating ? 24 : 16, sigmaY: depth == Depth.floating ? 24 : 16),
        child: pane,
      ),
    );
    if (depth != Depth.floating) return glass;
    // The shadow sits outside the clip, so the pane seems to hover over the forest.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: const [
        BoxShadow(color: Color(0x40102A19), blurRadius: 28, offset: Offset(0, 12)),
      ]),
      child: glass,
    );
  }

  Widget _card(BuildContext context, bool solid, BorderRadius r) {
    final c = context.colors;
    final flat = depth == Depth.base || solid;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: r,
        color: flat ? c.surface : null,
        gradient: flat
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.12, 1],
                colors: c.isDark
                    ? [Color.lerp(c.surface, Colors.white, 0.08)!, c.surface, c.surface]
                    : [Colors.white, c.surface, Color.lerp(c.surface, c.background, 0.7)!],
              ),
        border: Border.all(
            color: c.isDark && !flat ? Color.lerp(c.border, Colors.white, depth == Depth.floating ? 0.2 : 0.1)! : c.border),
        boxShadow: flat ? null : AppShadows.of(context, depth == Depth.floating ? AppShadows.e3 : AppShadows.e1),
      ),
      child: child,
    );
  }
}

/// A card you can almost hold: while a finger rests on it, it leans a few degrees towards the finger and
/// settles back on release. A touch that turns into a scroll does not tilt it. Still under reduced motion.
class TiltOnTouch extends StatefulWidget {
  const TiltOnTouch({super.key, required this.child, this.maxDegrees = 5});

  final Widget child;
  final double maxDegrees;

  @override
  State<TiltOnTouch> createState() => _TiltOnTouchState();
}

class _TiltOnTouchState extends State<TiltOnTouch> {
  Offset _tilt = Offset.zero;   // -1..1 on each axis, from the centre
  Offset? _down;
  bool _scrolling = false;

  void _lean(Offset local) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    setState(() => _tilt = Offset((local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0)));
  }

  void _release() {
    _down = null;
    if (_tilt != Offset.zero) setState(() => _tilt = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return widget.child;
    final rad = widget.maxDegrees * math.pi / 180;
    return Listener(
      onPointerDown: (e) {
        _down = e.localPosition;
        _scrolling = false;
        _lean(e.localPosition);
      },
      onPointerMove: (e) {
        if (_down == null || _scrolling) return;
        if ((e.localPosition - _down!).distance > 12) {
          _scrolling = true;   // the finger is scrolling the page, not pressing the card
          setState(() => _tilt = Offset.zero);
          return;
        }
        _lean(e.localPosition);
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: _tilt),
        duration: AppMotion.medium,
        curve: AppMotion.standard,
        builder: (_, t, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateX(-t.dy * rad)
            ..rotateY(t.dx * rad),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
