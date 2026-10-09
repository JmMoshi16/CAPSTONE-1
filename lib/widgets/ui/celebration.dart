import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// One-shot confetti burst for celebrations. [strong] is used when a badge unlocks:
/// more pieces, gold included, and side cannons. Draws on its own layer, ignores
/// touches, and renders nothing when the user asked for reduced motion.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.strong = false, this.origin = const Alignment(0, -0.55)});

  final bool strong;
  final Alignment origin;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.strong ? AppMotion.celebration + const Duration(milliseconds: 600) : AppMotion.celebration,
  );
  late final List<_Piece> _pieces = _make();

  static const _brand = AppPalette.confetti;
  static const _gold = AppPalette.confettiGold;

  List<_Piece> _make() {
    final r = math.Random();
    final colors = widget.strong ? [..._brand, ..._gold, ..._gold] : _brand;
    _Piece piece(double angle, double spread, double speed, Alignment from) => _Piece(
          from: from,
          angle: angle + (r.nextDouble() - 0.5) * spread,
          speed: speed * (0.6 + r.nextDouble() * 0.6),
          size: 5 + r.nextDouble() * 6,
          spin: (r.nextDouble() - 0.5) * 14,
          color: colors[r.nextInt(colors.length)],
          round: r.nextBool(),
          delay: r.nextDouble() * 0.08,
        );
    return [
      // Main burst, upwards from the success mark.
      for (var i = 0; i < (widget.strong ? 70 : 40); i++) piece(-math.pi / 2, 2.2, 900, widget.origin),
      // Badge unlock: two side cannons aimed at the middle.
      if (widget.strong) ...[
        for (var i = 0; i < 30; i++) piece(-math.pi / 3, 0.6, 1150, const Alignment(-1, 0.6)),
        for (var i = 0; i < 30; i++) piece(-2 * math.pi / 3, 0.6, 1150, const Alignment(1, 0.6)),
      ],
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.reduced(context) && !_c.isAnimating && _c.value == 0) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => _c.isCompleted
                ? const SizedBox.expand()
                : CustomPaint(
                    size: Size.infinite,
                    painter: _ConfettiPainter(_pieces, _c.value, _c.duration!.inMilliseconds / 1000),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Piece {
  final Alignment from;
  final double angle, speed, size, spin, delay;
  final Color color;
  final bool round;
  const _Piece({required this.from, required this.angle, required this.speed, required this.size,
      required this.spin, required this.color, required this.round, required this.delay});
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress, this.seconds);
  final List<_Piece> pieces;
  final double progress;
  final double seconds;

  static const _gravity = 1500.0; // px/s²
  static const _drag = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final local = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local == 0) continue;
      final t = local * seconds;
      final origin = p.from.alongSize(size);
      // Air drag slows the throw; gravity pulls the piece down.
      final travel = (1 - math.exp(-_drag * t * 3)) / (_drag * 3);
      final x = origin.dx + math.cos(p.angle) * p.speed * travel;
      final y = origin.dy + math.sin(p.angle) * p.speed * travel + 0.5 * _gravity * t * t * 0.35;
      final fade = local < 0.7 ? 1.0 : (1 - (local - 0.7) / 0.3);
      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        // Flat ribbon that "flutters" by scaling its width.
        canvas.scale(math.cos(t * p.spin).abs() * 0.8 + 0.2, 1);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

/// Reveals [child] with a card flip around the vertical axis after [delay].
/// Reduced motion: a plain fade.
class FlipReveal extends StatefulWidget {
  const FlipReveal({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<FlipReveal> createState() => _FlipRevealState();
}

class _FlipRevealState extends State<FlipReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.slow);
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    Future.delayed(widget.delay, () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return FadeTransition(opacity: _c, child: widget.child);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final v = Curves.easeOutBack.transform(_c.value);
        // Starts edge-on (90°) and turns to face the user.
        final angle = (1 - v) * math.pi / 2;
        return Opacity(
          opacity: _c.value < 0.05 ? 0 : 1,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(angle),
            child: child,
          ),
        );
      },
    );
  }
}
