import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ECOReward's own icons: one family drawn on a 24-unit grid with one stroke weight (1.8, round caps and joins),
/// so the tab bar (Home, Rewards, Scan, Activity, Profile) and Home's shortcuts (My codes, Leaderboard, Badges) sit
/// together evenly. Each has an outline form (at rest) and a filled
/// form (selected, inside the bubble); [cutout] is the colour behind a filled glyph, used for its inner lines.
enum NavGlyphKind { home, rewards, scan, activity, profile, codes, leaderboard, badges }

class NavGlyph extends StatelessWidget {
  const NavGlyph(this.kind, {super.key, required this.color, this.size = 24, this.filled = false, this.cutout});

  final NavGlyphKind kind;
  final Color color;
  final double size;
  final bool filled;
  final Color? cutout;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: _GlyphPainter(kind, color, filled, cutout ?? Colors.transparent),
        ),
      );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.kind, this.color, this.filled, this.cutout);

  final NavGlyphKind kind;
  final Color color, cutout;
  final bool filled;

  static const _stroke = 1.8;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    final knock = Paint()
      ..color = cutout
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (kind) {
      case NavGlyphKind.home:
        final house = Path()
          ..moveTo(4.5, 10.2)
          ..lineTo(12, 4.2)
          ..lineTo(19.5, 10.2)
          ..lineTo(19.5, 18)
          ..arcToPoint(const Offset(17.5, 20), radius: const Radius.circular(2))
          ..lineTo(6.5, 20)
          ..arcToPoint(const Offset(4.5, 18), radius: const Radius.circular(2))
          ..close();
        final door = Path()
          ..moveTo(10, 20)
          ..lineTo(10, 15.6)
          ..arcToPoint(const Offset(11, 14.6), radius: const Radius.circular(1))
          ..lineTo(13, 14.6)
          ..arcToPoint(const Offset(14, 15.6), radius: const Radius.circular(1))
          ..lineTo(14, 20);
        if (filled) {
          canvas.drawPath(house, fill);
          canvas.drawPath(house, line);
          canvas.drawPath(door, knock);
        } else {
          canvas.drawPath(house, line);
          canvas.drawPath(door, line);
        }
      case NavGlyphKind.rewards:
        final box = RRect.fromLTRBR(5, 11.2, 19, 20, const Radius.circular(2));
        final lid = RRect.fromLTRBR(3.8, 7.8, 20.2, 11.2, const Radius.circular(1.4));
        final bow = Path()
          ..moveTo(12, 7.8)
          ..cubicTo(10.6, 4.6, 7, 4.4, 7.6, 6.6)
          ..cubicTo(8, 7.8, 10, 7.8, 12, 7.8)
          ..moveTo(12, 7.8)
          ..cubicTo(13.4, 4.6, 17, 4.4, 16.4, 6.6)
          ..cubicTo(16, 7.8, 14, 7.8, 12, 7.8);
        final ribbon = Path()
          ..moveTo(12, 7.8)
          ..lineTo(12, 20);
        if (filled) {
          canvas.drawRRect(box, fill);
          canvas.drawRRect(lid, fill);
          canvas.drawPath(bow, fill..style = PaintingStyle.fill);
          canvas.drawPath(bow, line);
          canvas.drawPath(ribbon, knock);
          canvas.drawLine(const Offset(5.6, 11.2), const Offset(18.4, 11.2), knock..strokeWidth = 1.2);
        } else {
          canvas.drawRRect(box, line);
          canvas.drawRRect(lid, line);
          canvas.drawPath(bow, line);
          canvas.drawPath(ribbon, line);
        }
      case NavGlyphKind.scan:
        final corners = Path()
          ..moveTo(4.2, 8.6)
          ..lineTo(4.2, 6.6)
          ..arcToPoint(const Offset(6.6, 4.2), radius: const Radius.circular(2.4))
          ..lineTo(8.6, 4.2)
          ..moveTo(15.4, 4.2)
          ..lineTo(17.4, 4.2)
          ..arcToPoint(const Offset(19.8, 6.6), radius: const Radius.circular(2.4))
          ..lineTo(19.8, 8.6)
          ..moveTo(19.8, 15.4)
          ..lineTo(19.8, 17.4)
          ..arcToPoint(const Offset(17.4, 19.8), radius: const Radius.circular(2.4))
          ..lineTo(15.4, 19.8)
          ..moveTo(8.6, 19.8)
          ..lineTo(6.6, 19.8)
          ..arcToPoint(const Offset(4.2, 17.4), radius: const Radius.circular(2.4))
          ..lineTo(4.2, 15.4);
        canvas.drawPath(corners, line..strokeWidth = filled ? 2.2 : _stroke);
        canvas.drawLine(const Offset(7.4, 12), const Offset(16.6, 12), line);
      case NavGlyphKind.activity:
        final trend = Path()
          ..moveTo(3.8, 16.6)
          ..lineTo(9, 11.4)
          ..lineTo(12.6, 14.8)
          ..lineTo(19.4, 8);
        final arrow = Path()
          ..moveTo(15.2, 7.8)
          ..lineTo(19.6, 7.8)
          ..lineTo(19.6, 12.2);
        if (filled) {
          // The area under the trend, shaded: the selected chart reads as a full one.
          final area = Path()
            ..moveTo(3.8, 16.6)
            ..lineTo(9, 11.4)
            ..lineTo(12.6, 14.8)
            ..lineTo(19.4, 8)
            ..lineTo(19.4, 20)
            ..lineTo(3.8, 20)
            ..close();
          canvas.drawPath(area, Paint()..color = color.withValues(alpha: color.a * 0.18));
          line.strokeWidth = 2.2;
        }
        canvas.drawPath(trend, line);
        canvas.drawPath(arrow, line);
      case NavGlyphKind.codes:
        // A ticket: notched at both sides, a perforation before the stub.
        final ticket = Path()
          ..moveTo(5.5, 6.5)
          ..lineTo(18.5, 6.5)
          ..arcToPoint(const Offset(20.5, 8.5), radius: const Radius.circular(2))
          ..lineTo(20.5, 10.2)
          ..arcToPoint(const Offset(20.5, 13.8), radius: const Radius.circular(1.8), clockwise: false)
          ..lineTo(20.5, 15.5)
          ..arcToPoint(const Offset(18.5, 17.5), radius: const Radius.circular(2))
          ..lineTo(5.5, 17.5)
          ..arcToPoint(const Offset(3.5, 15.5), radius: const Radius.circular(2))
          ..lineTo(3.5, 13.8)
          ..arcToPoint(const Offset(3.5, 10.2), radius: const Radius.circular(1.8), clockwise: false)
          ..lineTo(3.5, 8.5)
          ..arcToPoint(const Offset(5.5, 6.5), radius: const Radius.circular(2))
          ..close();
        final perforation = filled ? knock : line;
        if (filled) canvas.drawPath(ticket, fill);
        canvas.drawPath(ticket, line);
        // Three round dots (zero-length strokes with round caps).
        for (final y in [9.3, 12.0, 14.7]) {
          canvas.drawLine(Offset(15, y), Offset(15, y), perforation);
        }
      case NavGlyphKind.leaderboard:
        // A podium, first place in the middle, with its star above.
        final podium = Path()
          ..moveTo(3.5, 20)
          ..lineTo(3.5, 13.2)
          ..arcToPoint(const Offset(4.7, 12), radius: const Radius.circular(1.2))
          ..lineTo(9, 12)
          ..lineTo(9, 10.2)
          ..arcToPoint(const Offset(10.2, 9), radius: const Radius.circular(1.2))
          ..lineTo(13.8, 9)
          ..arcToPoint(const Offset(15, 10.2), radius: const Radius.circular(1.2))
          ..lineTo(15, 14.5)
          ..lineTo(19.3, 14.5)
          ..arcToPoint(const Offset(20.5, 15.7), radius: const Radius.circular(1.2))
          ..lineTo(20.5, 20)
          ..close();
        if (filled) canvas.drawPath(podium, fill);
        canvas.drawPath(podium, line);
        final steps = filled ? knock : line;
        canvas.drawLine(const Offset(9, 12), const Offset(9, 20), steps);
        canvas.drawLine(const Offset(15, 14.5), const Offset(15, 20), steps);
        canvas.drawPath(_star(const Offset(12, 4.6), 2.2), fill);
      case NavGlyphKind.badges:
        // A medal on a ribbon, a star struck in the middle.
        final ribbon = Path()
          ..moveTo(10.6, 9.6)
          ..lineTo(7.6, 3.5)
          ..moveTo(13.4, 9.6)
          ..lineTo(16.4, 3.5);
        canvas.drawPath(ribbon, line);
        const centre = Offset(12, 14.6);
        if (filled) {
          canvas.drawCircle(centre, 5.4, fill);
          canvas.drawCircle(centre, 5.4, line);
          canvas.drawPath(_star(centre, 2.4), Paint()..color = cutout);
        } else {
          canvas.drawCircle(centre, 5.4, line);
          canvas.drawPath(_star(centre, 2.4), fill);
        }
      case NavGlyphKind.profile:
        final body = Path()
          ..moveTo(5, 19.6)
          ..cubicTo(5.4, 16.2, 8.3, 14, 12, 14)
          ..cubicTo(15.7, 14, 18.6, 16.2, 19, 19.6);
        if (filled) {
          canvas.drawCircle(const Offset(12, 8.4), 3.6, fill);
          final solid = Path.from(body)
            ..quadraticBezierTo(19.1, 20.4, 18.3, 20.4)
            ..lineTo(5.7, 20.4)
            ..quadraticBezierTo(4.9, 20.4, 5, 19.6)
            ..close();
          canvas.drawPath(solid, fill);
        } else {
          canvas.drawCircle(const Offset(12, 8.4), 3.6, line);
          canvas.drawPath(body, line);
        }
    }
    canvas.restore();
  }

  /// A five-point star centred on [c], [r] to its points.
  static Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final d = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a) * d, math.sin(a) * d);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.kind != kind || old.color != color || old.filled != filled || old.cutout != cutout;
}
