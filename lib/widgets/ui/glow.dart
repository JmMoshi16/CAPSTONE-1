import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/tokens.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpace.md),
      this.radius = AppRadius.lg, this.tint = Colors.white, this.opacity = 0.14, this.blur = 12});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color tint;
  final double opacity;
  final double blur;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: AppRadius.all(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: opacity),
              borderRadius: AppRadius.all(radius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: child,
          ),
        ),
      );
}

/// Circular progress that sweeps from 0 when first shown and from the old value to the
/// new one after that. [child] sits in the middle (e.g. a level number).
class AnimatedProgressRing extends StatelessWidget {
  const AnimatedProgressRing({
    super.key,
    required this.progress,
    required this.size,
    this.stroke = 8,
    this.color,
    this.gradient,
    this.trackColor,
    this.child,
    this.fromZero = true,
    this.semanticsLabel,
  });

  final double progress;
  final double size;
  final double stroke;
  final Color? color;
  final Gradient? gradient;
  final Color? trackColor;
  final Widget? child;
  final bool fromZero;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = progress.clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel,
      value: '${(p * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: fromZero ? 0 : p, end: p),
        duration: AppMotion.of(context, AppMotion.slow),
        curve: AppMotion.emphasized,
        child: child,
        builder: (_, v, inner) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: v,
              stroke: stroke,
              color: color ?? c.primary,
              gradient: gradient,
              track: trackColor ?? c.surfaceAlt,
            ),
            child: Center(child: inner),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.stroke, required this.color, required this.track, this.gradient});

  final double progress, stroke;
  final Color color, track;
  final Gradient? gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(arcRect, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    if (progress <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (gradient != null) {
      paint.shader = gradient!.createShader(arcRect);
    } else {
      paint.color = color;
    }
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track || old.stroke != stroke;
}
