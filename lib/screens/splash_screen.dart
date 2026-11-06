// Launch screen: Crave by: Secret Cafe's logo revealed on its own yellow, then a fade into the first screen.
// The native launch window is the same yellow (android/.../colors.xml, ios LaunchScreen), so opening the app goes
// from the phone's launch screen straight into the reveal.
//
// The logo is never redrawn. It is the official image four times over, each copy clipped to one band of its rows
// (CraveBrand.layers: steam, cup and saucer, CRAVE, BY: SECRET CAFE), so each part can arrive on its own; at rest
// the bands meet exactly and the screen shows the image once, untouched. The rising vapour is a soft copy of the
// logo's own steam, drawn behind it, and a warm light keeps drifting over the yellow (SplashLight).

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/ui.dart';

class BrandSplash extends StatefulWidget {
  const BrandSplash({super.key, this.child});

  /// The first screen, once it is known. The reveal plays to its end, then fades into it; until then (a slow
  /// sign-in check) the finished logo stays, its steam still rising.
  final Widget? child;

  /// The reveal, ending on the complete logo after a short hold.
  static const intro = Duration(milliseconds: 2600);

  /// The fade into the first screen.
  static const handoff = Duration(milliseconds: 400);

  /// With reduced motion: the complete logo, still, for this long.
  static const stillHold = Duration(milliseconds: 700);

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) setState(() => _done = true);
    });
  late final AnimationController _vapour =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final AnimationController _light = AnimationController(vsync: this, duration: const Duration(seconds: 8));
  bool _started = false, _done = false, _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = AppMotion.reduced(context);
    // With reduced motion the controller only times the hold; every layer is drawn at rest.
    _intro.duration = _reduced ? BrandSplash.stillHold : BrandSplash.intro;
    _intro.forward();
    if (!_reduced) {
      _vapour.repeat();
      _light.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _vapour.dispose();
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = _done ? widget.child : null;
    return AnimatedSwitcher(
      duration: _reduced ? Duration.zero : BrandSplash.handoff,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: next != null
          ? KeyedSubtree(key: const ValueKey('next'), child: next)
          : KeyedSubtree(key: const ValueKey('splash'), child: _splash()),
    );
  }

  Widget _splash() => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: CraveBrand.ground,
          body: AnimatedBuilder(
            animation: Listenable.merge([_light, _intro]),
            // The light grows in from flat yellow, so the phone's still launch screen hands over without a jump.
            builder: (context, child) => SplashLight(
              phase: _light.value,
              strength: _reduced ? 0 : _at(0, 900, Curves.easeInOut).transform(_intro.value),
              child: child!,
            ),
            child: ColoredBox(
              color: CraveBrand.ground,
              child: SafeArea(
                child: LayoutBuilder(builder: (context, box) {
                  final side = math.min(math.min(box.maxWidth * 0.84, box.maxHeight * 0.6), 560.0);
                  return Center(
                    child: Semantics(
                      label: '${CraveBrand.name}. Loading',
                      excludeSemantics: true,
                      child: SizedBox.square(
                        key: const ValueKey('splash-logo'),
                        dimension: side,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_intro, _vapour]),
                          builder: (context, _) => _logo(context, side),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      );

  // Where each part is in the reveal, as Intervals of the 2.6 s intro.
  static const _ms = 2600;
  static Interval _at(int from, int to, [Curve curve = Curves.easeOutCubic]) =>
      Interval(from / _ms, to / _ms, curve: curve);

  Widget _logo(BuildContext context, double side) {
    final t = _reduced ? 1.0 : _intro.value;
    final px = (side * MediaQuery.devicePixelRatioOf(context)).round();
    final image = Image(
      image: ResizeImage.resizeIfNeeded(px < 1254 ? px : null, null, const AssetImage(CraveBrand.logo)),
      width: side,
      height: side,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
    double rise(Interval i, double by) => side * by * (1 - i.transform(t)); // below its place, then home

    Widget layer(String id, int band, double opacity, Widget Function(Widget) move) => Opacity(
          key: ValueKey('logo-$id'),
          opacity: opacity,
          child: ClipRect(clipper: _Band(CraveBrand.layers[band]), child: move(image)),
        );

    return Stack(fit: StackFit.expand, children: [
      if (!_reduced) _vapourLayer(image, side, t),
      // The cup and saucer arrive first, settling from slightly small.
      layer(
          'cup',
          1,
          _at(250, 750, Curves.easeOut).transform(t),
          (i) => Transform.scale(
              scale: 1 - 0.1 * (1 - _at(250, 1000).transform(t)), alignment: const Alignment(-0.05, -0.14), child: i)),
      // The steam rises out of the cup: its band ends at the rim, so it emerges from inside.
      layer('steam', 0, _at(600, 1100, Curves.easeOut).transform(t),
          (i) => Transform.translate(offset: Offset(0, rise(_at(600, 1450), 0.09)), child: i)),
      layer('name', 2, _at(1100, 1600, Curves.easeOut).transform(t),
          (i) => Transform.translate(offset: Offset(0, rise(_at(1100, 1750), 0.02)), child: i)),
      layer('tagline', 3, _at(1500, 2000, Curves.easeOut).transform(t),
          (i) => Transform.translate(offset: Offset(0, rise(_at(1500, 2100), 0.015)), child: i)),
    ]);
  }

  /// Fresh steam: a soft, faint copy of the logo's steam drifting up from it and thinning out, over and over.
  Widget _vapourLayer(Widget image, double side, double t) {
    final v = _vapour.value;
    final band = CraveBrand.layers[0];
    return Opacity(
      key: const ValueKey('logo-vapour'),
      opacity: 0.3 * math.sin(math.pi * v) * _at(1300, 1800, Curves.easeIn).transform(t),
      child: ClipRect(
        clipper: _Band(band),
        child: Transform.translate(
          offset: Offset(side * 0.008 * math.sin(2 * math.pi * v), -side * 0.07 * v),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: side * (0.004 + 0.008 * v), sigmaY: side * (0.004 + 0.008 * v)),
            child: ClipRect(clipper: _Band(band), child: image),
          ),
        ),
      ),
    );
  }
}

/// The splash's living yellow: a warm light drifting slowly and endlessly across the screen. It falls over the logo
/// too, as light falls on paper, so the image's own square of yellow never shows as a box. It only deepens colour
/// (modulate): the yellow moves between bright and a deeper gold while the navy stays navy. [phase] is the place in
/// one 8 s loop (0 to 1); [strength] 0 is flat yellow, 1 the full light.
class SplashLight extends StatelessWidget {
  const SplashLight({super.key, required this.phase, required this.strength, required this.child});

  final double phase, strength;
  final Widget child;

  // Multiplied into the screen at the light's edge: the logo's yellow #FDCF09 becomes a deep gold.
  static const _shade = Color(0xFFF4D2E0);

  @override
  Widget build(BuildContext context) {
    if (strength == 0) return child;
    final a = 2 * math.pi * phase;
    final edge = Color.lerp(Colors.white, _shade, strength)!;
    return ShaderMask(
      shaderCallback: (rect) => RadialGradient(
        // A wandering loop (whole multiples of the phase, so it joins up seamlessly), breathing a little as it goes.
        center: Alignment(0.7 * math.sin(a), -0.15 + 0.5 * math.sin(2 * a + 1)),
        radius: 1.0 + 0.12 * math.sin(3 * a),
        colors: [Colors.white, Colors.white, edge],
        stops: const [0, 0.25, 1],
      ).createShader(rect),
      child: child,
    );
  }
}

/// One band of the logo's rows, (top, bottom) as fractions of its height, full width.
class _Band extends CustomClipper<Rect> {
  const _Band(this.band);

  final (double, double) band;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, size.height * band.$1, size.width, size.height * band.$2);

  @override
  bool shouldReclip(_Band old) => old.band != band;
}
