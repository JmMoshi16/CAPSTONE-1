// Branded splash: Lottie symbol (scenes 1-4) + app name fading in at 3.2 s (scene 5).
// The name is a real Text widget, not baked into the Lottie, so it stays sharp,
// uses the app font, and can be renamed or translated without re-exporting.

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../widgets/eco_animations.dart';

class SmartCafeSplash extends StatefulWidget {
  const SmartCafeSplash({
    super.key,
    required this.next,
    this.appName = 'Smart Cafe Bin',
    this.tagline = 'From coffee to a greener future',
  });

  /// The screen to open when the splash finishes (e.g. LoginScreen()).
  final Widget next;
  final String appName;
  final String? tagline;

  @override
  State<SmartCafeSplash> createState() => _SmartCafeSplashState();
}

class _SmartCafeSplashState extends State<SmartCafeSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  // 4.0 s timeline: the name fades in 3.2-3.7 s, the tagline 3.35-3.85 s.
  late final Animation<double> _name =
      CurvedAnimation(parent: _c, curve: const Interval(.80, .925, curve: Curves.easeOutCubic));
  late final Animation<double> _tag =
      CurvedAnimation(parent: _c, curve: const Interval(.8375, .9625, curve: Curves.easeOutCubic));

  bool _left = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition comp) {
    _c.duration = comp.duration;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.value = 1;
      Future.delayed(const Duration(milliseconds: 700), _leave);
    } else {
      _c.forward().whenComplete(
          () => Future.delayed(const Duration(milliseconds: 250), _leave)); // brief hold
    }
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => widget.next,
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
    ));
  }

  Widget _rise(Animation<double> a, Widget child) => AnimatedBuilder(
        animation: a,
        builder: (_, c) => Opacity(
          opacity: a.value,
          child: Transform.translate(offset: Offset(0, 10 * (1 - a.value)), child: c),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final symbol = (MediaQuery.sizeOf(context).shortestSide * .62).clamp(180.0, 280.0);
    return Scaffold(
      backgroundColor: EcoBrand.cream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              EcoAnimations.splash,
              controller: _c,
              width: symbol,
              height: symbol,
              onLoaded: _onLoaded,
              // Never trap the user on the splash if the asset is missing.
              errorBuilder: (_, __, ___) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
                return SizedBox(width: symbol, height: symbol);
              },
            ),
            // The ring ends ~24% above the bottom of the canvas; pull the name up into that space.
            Transform.translate(
              offset: Offset(0, -symbol * .16),
              child: Column(children: [
                _rise(
                  _name,
                  Text(widget.appName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .4,
                        color: EcoBrand.forest,
                      )),
                ),
                if (widget.tagline != null) ...[
                  const SizedBox(height: 6),
                  _rise(
                    _tag,
                    Text(widget.tagline!,
                        style: TextStyle(
                          fontSize: 13.5,
                          letterSpacing: .2,
                          color: EcoBrand.coffee.withValues(alpha: .75),
                        )),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
