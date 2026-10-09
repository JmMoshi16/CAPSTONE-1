import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// Slowly drifting leaf shapes for brand backgrounds (Login, Register). Paints on its own
/// layer, and holds still when the user asked for reduced motion.
class FloatingLeaves extends StatefulWidget {
  const FloatingLeaves({super.key});
  @override
  State<FloatingLeaves> createState() => _FloatingLeavesState();
}

class _FloatingLeavesState extends State<FloatingLeaves> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.ambient * 4);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(size: Size.infinite, painter: _LeafPainter(_c.value)),
            ),
          ),
        ),
      );
}

class _LeafPainter extends CustomPainter {
  final double progress;
  static final _rand = math.Random(42);
  static final _particles = List.generate(14, (i) => _Particle(
    x:       _rand.nextDouble(),
    speed:   0.04 + _rand.nextDouble() * 0.07,
    size:    4 + _rand.nextDouble() * 7,
    opacity: 0.06 + _rand.nextDouble() * 0.13,
    phase:   _rand.nextDouble(),
    drift:   (_rand.nextDouble() - 0.5) * 0.04,
  ));

  _LeafPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = ((p.phase + progress * p.speed * 10) % 1.0);
      final y = size.height * (1.0 - t);
      final x = size.width * (p.x + math.sin(t * math.pi * 2 + p.phase) * p.drift);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * math.pi * 2);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 1.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LeafPainter old) => old.progress != progress;
}

class _Particle {
  final double x, speed, size, opacity, phase, drift;
  const _Particle({required this.x, required this.speed, required this.size,
      required this.opacity, required this.phase, required this.drift});
}
