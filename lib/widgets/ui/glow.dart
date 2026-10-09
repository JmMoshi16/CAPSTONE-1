import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/haptics.dart';
import '../../core/tokens.dart';

/// The hero call-to-action: forest gradient, soft coloured glow, press-in to 0.96 with a
/// haptic, and a loading state that keeps its size. White text on the forest gradient is
/// at least 4.8:1 on every stop.
class GlowButton extends StatefulWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.height = 56,
    this.gradient = AppGradients.forest,
    this.glowColor = AppPalette.forest,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;
  final double height;
  final Gradient gradient;
  final Color glowColor;

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _set(bool v) {
    if (_enabled && v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final reduced = AppMotion.reduced(context);
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.loading ? '${widget.label}, working' : widget.label,
      excludeSemantics: true,
      onTap: _enabled ? _tap : null,
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: _enabled ? _tap : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: AppMotion.of(context, AppMotion.fast),
          curve: AppMotion.standard,
          child: AnimatedContainer(
            duration: reduced ? Duration.zero : AppMotion.medium,
            height: widget.height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: AppRadius.all(AppRadius.lg + 2),
              boxShadow: _enabled ? AppShadows.glow(widget.glowColor, strength: _down ? 0.6 : 1) : AppShadows.none,
            ),
            foregroundDecoration: _enabled || widget.loading
                ? null
                : BoxDecoration(color: Colors.white.withValues(alpha: 0.45), borderRadius: AppRadius.all(AppRadius.lg + 2)),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: widget.loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.icon != null) ...[Icon(widget.icon, color: Colors.white, size: 22), const SizedBox(width: AppSpace.sm - 2)],
                    Flexible(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: t.labelLarge!.copyWith(color: Colors.white, fontSize: 16, letterSpacing: 0.3))),
                    if (widget.trailingIcon != null) ...[const SizedBox(width: AppSpace.sm - 2), Icon(widget.trailingIcon, color: Colors.white, size: 18)],
                  ]),
          ),
        ),
      ),
    );
  }

  void _tap() {
    AppHaptics.primary();
    widget.onPressed!();
  }
}

/// Frosted panel for content that sits on a gradient or photo. Blur is costly, so use it
/// for a few small surfaces (header chips, overlays), never for long lists.
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
