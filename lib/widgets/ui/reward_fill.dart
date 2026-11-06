import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import 'marks.dart';

/// A reward's picture as a glass the points fill: Crave's yellow rises from the bottom to [level] (0 to 1) behind and
/// through the photo, its surface lively as it rises, then rolling in a gentle wave that never stops. Full when the
/// reward is ready. The rise replays each time the card comes into view, and changes in [level] animate from where
/// it was. With reduced motion the fill simply sits at its level, still.
///
/// [parallax] is the card's distance from the carousel's centre (-1 to 1); the photo drifts a little against it, so
/// it seems to sit deeper than the card.
class RewardFill extends StatefulWidget {
  const RewardFill({super.key, required this.title, required this.category, required this.level, this.parallax = 0,
      this.fit = BoxFit.cover});

  final String title, category;
  final double level;
  final double parallax;

  /// How the photo sits in the glass ([RewardPicture.fit]).
  final BoxFit fit;

  @override
  State<RewardFill> createState() => RewardFillState();
}

class RewardFillState extends State<RewardFill> with TickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  // One loop of the surface's wave; it repeats for as long as the card is on screen.
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final Animation<double> _eased = CurvedAnimation(parent: _rise, curve: Curves.easeOutCubic);
  double _from = 0;
  bool _started = false;

  /// The level drawn right now (between where it was and [RewardFill.level] while rising).
  double get shownLevel => _from + (widget.level - _from) * _eased.value;

  /// Where the surface's wave is in its loop (0 to 1).
  double get wavePhase => _wave.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _rise.value = 1;
    } else {
      _rise.forward();
      _wave.repeat();
    }
  }

  @override
  void didUpdateWidget(RewardFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level == widget.level) return;
    _from = _from + (oldWidget.level - _from) * _eased.value; // from where it is drawn right now
    AppMotion.reduced(context) ? _rise.value = 1 : _rise.forward(from: 0);
  }

  @override
  void dispose() {
    _rise.dispose();
    _wave.dispose();
    super.dispose();
  }

  // The fill's colour: light enough that a photo multiplied by it still reads (white backdrop turns this yellow).
  static const _fill = Color(0xFFFFE9A0);

  @override
  Widget build(BuildContext context) {
    // Unzoomed: in an upright glass the covering photo is wider than the glass, so the drift has room at the sides.
    final picture = Transform.translate(
      offset: Offset(widget.parallax * -18, 0),
      child: RewardPicture(title: widget.title, category: widget.category, fit: widget.fit),
    );
    return ClipRect(
      child: AnimatedBuilder(
        animation: Listenable.merge([_rise, _wave]),
        builder: (context, _) {
          final surface = _Surface(level: shownLevel, settle: _rise.value, roll: _wave.value);
          return Stack(fit: StackFit.expand, children: [
            // The glass: white like the photos' own backdrop, so a cup stands in it without a seam.
            const ColoredBox(color: Colors.white),
            picture,
            // Below the surface the same picture, multiplied by the fill: the white turns yellow, the cup sits in it.
            ClipPath(
              clipper: _BelowSurface(surface),
              child: ColorFiltered(colorFilter: const ColorFilter.mode(_fill, BlendMode.multiply), child: picture),
            ),
            IgnorePointer(child: CustomPaint(painter: _SurfaceLine(surface))),
          ]);
        },
      ),
    );
  }
}

/// The liquid's surface at a moment: its height, a ripple that is livelier while it rises, and the endless wave.
class _Surface {
  const _Surface({required this.level, required this.settle, required this.roll});

  final double level; // 0 empty .. 1 full
  final double settle; // 0 just poured .. 1 risen
  final double roll; // 0 .. 1, one loop of the rolling wave

  Path wave(Size size, {required bool closeBelow}) {
    final amp = 2.6 + 4 * (1 - settle); // a gently rolling surface, livelier while it rises
    // Whole turns of the loop, so the wave rolls on without a seam; a smaller second wave keeps it from looking
    // like a plain sine.
    final phase = settle * math.pi * 3 + roll * math.pi * 2;
    final chop = -roll * math.pi * 4;
    // Full sits above the top edge, so no surface shows on a ready reward.
    final y = size.height * (1 - level) - (level >= 1 ? amp * 3 : 0);
    double at(double x) {
      final u = x / size.width * math.pi * 2;
      return y + amp * math.sin(phase + u) + amp * 0.35 * math.sin(chop + u * 2.3);
    }

    final path = Path()..moveTo(0, at(0));
    for (var x = 0.0; x <= size.width; x += 4) {
      path.lineTo(x, at(x));
    }
    if (closeBelow) {
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    return path;
  }

  bool differs(_Surface o) => o.level != level || o.settle != settle || o.roll != roll;
}

class _BelowSurface extends CustomClipper<Path> {
  const _BelowSurface(this.surface);

  final _Surface surface;

  @override
  Path getClip(Size size) => surface.wave(size, closeBelow: true);

  @override
  bool shouldReclip(_BelowSurface old) => surface.differs(old.surface);
}

/// A thin highlight along the surface, the light catching the liquid.
class _SurfaceLine extends CustomPainter {
  const _SurfaceLine(this.surface);

  final _Surface surface;

  @override
  void paint(Canvas canvas, Size size) {
    if (surface.level <= 0 || surface.level >= 1) return;
    canvas.drawPath(
      surface.wave(size, closeBelow: false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppPalette.sunDeep.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_SurfaceLine old) => surface.differs(old.surface);
}
