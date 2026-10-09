// ECOReward Bin brand animations (Lottie).
//
// Requires:  lottie: ^3.1.2   (pubspec.yaml)
// Assets:    assets/animations/{splash,loader,success,idle}.json
//
// Every widget respects the system "Remove animations" setting
// (MediaQuery.disableAnimations): it shows the finished frame instead of moving.

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../core/tokens.dart';

/// Brand palette used by the animations. Keep in sync with tool/generate_lottie.py.
class EcoBrand {
  static const forest = AppPalette.forest;
  static const coffee = AppPalette.coffee;
  static const cream = AppPalette.cream;
  static const mint = AppPalette.mint;
}

class EcoAnimations {
  static const splash = 'assets/animations/splash.json';   // 4.0 s, plays once
  static const loader = 'assets/animations/loader.json';   // 1.5 s, loops
  static const success = 'assets/animations/success.json'; // 1.2 s, plays once
  static const idle = 'assets/animations/idle.json';       // 4.0 s, loops

  /// Optional: call once at startup so the first animation shows instantly.
  static Future<void> precache() async {
    await Future.wait([
      AssetLottie(splash).load(),
      AssetLottie(loader).load(),
      AssetLottie(success).load(),
    ]);
  }
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Compact looping loader: the symbol with a mint arc travelling round the ring.
/// Drop-in replacement for CircularProgressIndicator.
class EcoLoader extends StatelessWidget {
  const EcoLoader({super.key, this.size = 72, this.semanticLabel = 'Loading'});
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Lottie.asset(
        EcoAnimations.loader,
        width: size,
        height: size,
        repeat: true,
        animate: !_reduceMotion(context),
        errorBuilder: (_, __, ___) => SizedBox(
          width: size * .5,
          height: size * .5,
          child: const CircularProgressIndicator(color: EcoBrand.forest, strokeWidth: 3),
        ),
      ),
    );
  }
}

/// Plays the green disc + checkmark once, then calls [onCompleted].
class EcoSuccess extends StatefulWidget {
  const EcoSuccess({super.key, this.size = 140, this.onCompleted});
  final double size;
  final VoidCallback? onCompleted;

  @override
  State<EcoSuccess> createState() => _EcoSuccessState();
}

class _EcoSuccessState extends State<EcoSuccess> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start(LottieComposition comp) {
    _c.duration = comp.duration;
    if (_reduceMotion(context)) {
      _c.value = 1;
      widget.onCompleted?.call();
    } else {
      _c.forward(from: 0).whenComplete(() {
        if (mounted) widget.onCompleted?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Success',
      liveRegion: true,
      child: Lottie.asset(
        EcoAnimations.success,
        controller: _c,
        width: widget.size,
        height: widget.size,
        onLoaded: _start,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.check_circle, color: EcoBrand.forest, size: widget.size * .6),
      ),
    );
  }
}

/// Very subtle seamless loop for a "ready for the next user" state.
class EcoIdle extends StatelessWidget {
  const EcoIdle({super.key, this.size = 200});
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Lottie.asset(
        EcoAnimations.idle,
        width: size,
        height: size,
        repeat: true,
        animate: !_reduceMotion(context),
      ),
    );
  }
}
