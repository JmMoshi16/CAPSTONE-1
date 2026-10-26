import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// The brand's deep-forest surface: the hero gradient with soft mint light drifting slowly across it and a
/// faint leaf vein. The drift plays for a couple of slow cycles when the surface appears, then rests (alive on
/// arrival, calm after, no battery drain); with "Remove animations" it is still from the start.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child, this.borderRadius});

  final Widget child;
  final BorderRadius? borderRadius;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: AppMotion.aurora);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating && _drift.value == 0) {
      _drift.repeat(reverse: true, count: 2);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: c.hero, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _drift,
                builder: (_, __) => CustomPaint(painter: _AuroraPainter(_drift.value, c.accent)),
              ),
            ),
          ),
          widget.child,
        ]),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t, this.mint);

  final double t;
  final Color mint;

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * math.pi;
    // Three soft lights (radial gradients, no blur pass): top right, lower left, centre.
    void light(Offset centre, double radius, double alpha) {
      final rect = Rect.fromCircle(center: centre, radius: radius);
      canvas.drawRect(rect, Paint()
        ..shader = RadialGradient(colors: [mint.withValues(alpha: alpha), mint.withValues(alpha: 0)]).createShader(rect));
    }

    final w = size.width, h = size.height;
    light(Offset(w * (0.85 + 0.08 * math.sin(a)), h * (0.1 + 0.08 * math.cos(a))), w * 0.65, 0.22);
    light(Offset(w * (0.1 + 0.1 * math.cos(a)), h * (0.95 - 0.1 * math.sin(a))), w * 0.6, 0.14);
    light(Offset(w * (0.5 + 0.15 * math.sin(a * 0.7)), h * 0.55), w * 0.35, 0.06);

    // One long faint curve, bottom right: a leaf's midrib as texture.
    canvas.drawPath(
      Path()
        ..moveTo(w * 1.02, h * 1.05)
        ..quadraticBezierTo(w * 0.62, h * 0.72, w * 0.52, h * 0.08),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t || old.mint != mint;
}

/// Fades and rises [child] into place, [index] steps after the first, once. Pass [play] from an
/// [EntranceGate] so revisits, refreshes and reduced motion show it straight away.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({super.key, required this.index, required this.play, required this.child});

  final int index;
  final bool play;
  final Widget child;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.slow);
  late final Animation<double> _v = CurvedAnimation(parent: _c, curve: AppMotion.standard);

  @override
  void initState() {
    super.initState();
    if (!widget.play) {
      _c.value = 1;
      return;
    }
    Future.delayed(AppMotion.cascade * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _v,
        child: widget.child,
        builder: (_, child) => Opacity(
          opacity: _v.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _v.value) * 16),
            child: Transform.scale(scale: 0.98 + 0.02 * _v.value, child: child),
          ),
        ),
      );
}

/// A light sweep across [child] whenever [value] changes after the first build (e.g. the balance went up).
/// One sweep, never a loop.
class SheenOnChange extends StatefulWidget {
  const SheenOnChange({super.key, required this.value, required this.child});

  final Object value;
  final Widget child;

  @override
  State<SheenOnChange> createState() => _SheenOnChangeState();
}

class _SheenOnChangeState extends State<SheenOnChange> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(SheenOnChange old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !AppMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) {
          if (!_c.isAnimating) return child!;
          final x = -1.5 + 3 * Curves.easeInOut.transform(_c.value);
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(x - 0.4, -1),
              end: Alignment(x + 0.4, 1),
              colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0)],
            ).createShader(rect),
            child: child,
          );
        },
      );
}
