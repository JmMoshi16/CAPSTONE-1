import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// ECOReward's signature mark: a champagne-gold coin with a navy leaf struck into it. Every recycled item
/// becomes value. Drawn in code (no image asset), so it is sharp at any size and needs no package.
/// With [turnIn] it turns from edge-on to face-on once when it first appears; never under reduced motion.
/// Decorative: screen readers skip it (the number beside it carries the meaning).
class EcoCoin extends StatefulWidget {
  const EcoCoin({super.key, required this.size, this.turnIn = false});

  final double size;
  final bool turnIn;

  @override
  State<EcoCoin> createState() => _EcoCoinState();
}

class _EcoCoinState extends State<EcoCoin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.slow * 2);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _c.value = 1;
    } else if (!_started) {
      if (widget.turnIn) {
        _c.forward();
      } else {
        _c.value = 1;
      }
    }
    _started = true;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => Transform(
            alignment: Alignment.center,
            // From nearly edge-on to face-on, with a little overshoot, like a coin landing.
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY((1 - AppMotion.spring.transform(_c.value)) * -1.3),
            child: child,
          ),
          child: const ExcludeSemantics(child: CustomPaint(painter: _CoinPainter(), size: Size.infinite)),
        ),
      );
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final r = s * 0.42;
    final c = Offset(size.width / 2, size.height / 2 - s * 0.03);
    final face = Rect.fromCircle(center: c, radius: r);

    // Contact shadow under the coin.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx, c.dy + r + s * 0.07), width: r * 1.5, height: s * 0.09),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.035),
    );
    // The coin's edge: the same disc a little lower and darker gives it thickness.
    canvas.drawCircle(c.translate(0, s * 0.04), r, Paint()..color = AppPalette.champagneDeep);
    // The face, lit from the top left.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [AppPalette.champagneLight, AppPalette.champagne, AppPalette.champagneDeep],
          stops: [0, 0.6, 1],
        ).createShader(face),
    );
    // Milled rim: light and dark bands around the edge.
    canvas.drawCircle(
      c,
      r * 0.95,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.03
        ..shader = const SweepGradient(colors: [
          AppPalette.champagneLight, AppPalette.champagneDeep, AppPalette.champagneLight,
          AppPalette.champagneDeep, AppPalette.champagneLight,
        ]).createShader(face),
    );
    // A struck groove: dark line with a light line just under it.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, s * 0.012);
    canvas.drawCircle(c.translate(0, s * 0.008), r * 0.76, groove..color = Colors.white.withValues(alpha: 0.5));
    canvas.drawCircle(c, r * 0.76, groove..color = AppPalette.champagneDeep.withValues(alpha: 0.7));

    // The leaf, embossed: a light copy below the navy one reads as a raised edge.
    final leaf = _leaf(c, r * 0.5);
    canvas.drawPath(leaf.shift(Offset(0, s * 0.012)), Paint()..color = Colors.white.withValues(alpha: 0.45));
    canvas.drawPath(
      leaf,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.navyLight, AppPalette.navyDeep],
        ).createShader(face),
    );
    canvas.drawPath(
      _vein(c, r * 0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.8, s * 0.016)
        ..color = AppPalette.champagneLight.withValues(alpha: 0.85),
    );

    // Specular light along the top-left of the rim.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.86),
      math.pi * 1.05,
      math.pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.035
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  static final _tilt = Matrix4.rotationZ(-0.6).storage;

  /// A leaf of half-length [h] centred on [c], leaning to the right, with a short stem.
  static Path _leaf(Offset c, double h) {
    final w = h * 1.05;
    final p = Path()
      ..moveTo(0, -h)
      ..quadraticBezierTo(w, -h * 0.15, 0, h)
      ..quadraticBezierTo(-w, -h * 0.15, 0, -h)
      ..close()
      ..addRect(Rect.fromLTWH(-h * 0.05, h * 0.85, h * 0.1, h * 0.35));
    return p.transform(_tilt).shift(c);
  }

  static Path _vein(Offset c, double h) =>
      (Path()..moveTo(0, -h * 0.75)..lineTo(0, h * 0.9)).transform(_tilt).shift(c);

  @override
  bool shouldRepaint(_CoinPainter oldDelegate) => false;
}
