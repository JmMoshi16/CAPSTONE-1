// ECOReward Bin brand animations (Lottie).
//
// Requires:  lottie: ^3.1.2   (pubspec.yaml)
// Assets:    assets/animations/{loader,success,idle}.json
//
// Every widget respects the system "Remove animations" setting
// (MediaQuery.disableAnimations): it shows the finished frame instead of moving.

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../core/tokens.dart';

class EcoAnimations {
  static const loader = 'assets/animations/loader.json';   // 1.5 s, loops
  static const success = 'assets/animations/success.json'; // 1.2 s, plays once
  static const idle = 'assets/animations/idle.json';       // 4.0 s, loops

  /// Optional: call once at startup so the first animation shows instantly.
  static Future<void> precache() async {
    await Future.wait([
      AssetLottie(loader).load(),
      AssetLottie(success).load(),
    ]);
  }
}

bool _reduceMotion(BuildContext context) => AppMotion.reduced(context);

/// Compact looping loader: the symbol with a yellow arc travelling round the ring.
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
        // Fallbacks follow the theme: the brand navy is too dark to see on the dark background.
        errorBuilder: (ctx, __, ___) => SizedBox(
          width: size * .5,
          height: size * .5,
          child: CircularProgressIndicator(color: Theme.of(ctx).colorScheme.primary, strokeWidth: 3),
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
        errorBuilder: (ctx, __, ___) =>
            Icon(Icons.check_circle, color: Theme.of(ctx).colorScheme.primary, size: widget.size * .6),
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
