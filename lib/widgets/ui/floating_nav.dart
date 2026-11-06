import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/tap.dart';
import '../../core/tokens.dart';
import 'nav_glyphs.dart';

/// A tab of [FloatingPillNav]: its glyph (outlined at rest, filled in the bubble when selected) and its name.
class FloatingNavTab {
  const FloatingNavTab({required this.glyph, required this.label});
  final NavGlyphKind glyph;
  final String label;
}

/// The action in the middle of [FloatingPillNav] (Scan): a round button that is never a tab.
class FloatingNavAction {
  const FloatingNavAction({required this.glyph, required this.label, required this.semanticLabel, required this.onTap,
      this.onLongPress, this.longPressHint});
  final NavGlyphKind glyph;
  final String label, semanticLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? longPressHint;
}

/// ECOReward's tab bar. A slim capsule with continuous (superellipse) corners floats over the page: deep navy
/// shading into royal blue, lit from above, with a fine highlight along its top edge and layered soft shadows. The
/// selected tab's filled glyph rides in a lit yellow bubble that sits low on the bar's edge, and a soft pool of yellow
/// light on the bar marks the tab beneath it. Choosing another tab, the bubble hops there (it lifts, arcs over,
/// lands with a gentle pop) while the light pool slides along under it. The selected name is bold yellow; the rest
/// are quiet cream outlines. The middle [action] (Scan) is a frosted-glass button with its own viewfinder glyph:
/// it never rises and never takes the bubble's yellow, so it is never mistaken for the selected tab.
class FloatingPillNav extends StatefulWidget {
  const FloatingPillNav({super.key, required this.tabs, required this.selectedIndex, required this.onTap, this.action});

  final List<FloatingNavTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final FloatingNavAction? action;

  static const double bubble = 46;          // the selected tab's circle
  static const double _drop = 9;            // bubble centre below the bar's top edge at rest (rises ~14 above it)
  static const double _lift = 8;            // how high the bubble lifts in mid-hop
  static const double _iconBox = 34;        // icon row height, shared by every slot so the labels line up
  static const double _inset = 6;           // space inside the capsule's ends
  static const double _maxWidth = 520;      // tablets get a bar, not a stripe across the screen

  /// The space above the bar for the bubble at the top of its hop (and its glow).
  static const double _rise = bubble / 2 - _drop + _lift + 4;

  /// The bar's height at the user's text size: 60 at normal size, taller for larger text.
  static double barHeight(BuildContext context) => 44 + MediaQuery.textScalerOf(context).scale(16);

  @override
  State<FloatingPillNav> createState() => _FloatingPillNavState();
}

class _FloatingPillNavState extends State<FloatingPillNav> with SingleTickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(vsync: this, duration: AppMotion.slow, value: 1);
  late double _from = _slotOf(widget.selectedIndex).toDouble();

  int get _half => widget.tabs.length ~/ 2;
  int get _slotCount => widget.tabs.length + (widget.action == null ? 0 : 1);
  int _slotOf(int tab) => widget.action != null && tab >= _half ? tab + 1 : tab;

  /// Where the bubble is, in slots (fractional while it travels).
  double get _position =>
      _from + (_slotOf(widget.selectedIndex) - _from) * AppMotion.emphasized.transform(_hop.value);

  @override
  void didUpdateWidget(FloatingPillNav old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex == widget.selectedIndex) return;
    // Leave from wherever the bubble is now, so a second quick tap turns it in flight instead of jumping.
    final t = AppMotion.emphasized.transform(_hop.value);
    _from = _from + (_slotOf(old.selectedIndex) - _from) * t;
    if (AppMotion.reduced(context)) {
      _hop.value = 1;
    } else {
      _hop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  /// The bubble's size over a hop: a little smaller while it travels, a gentle ~5 % pop as it lands, then 1.
  static double _scaleAt(double t) {
    final landing = ((t - 0.62) / 0.38).clamp(0.0, 1.0);
    return 1 - 0.08 * math.sin(math.pi * t) + 0.09 * math.sin(math.pi * landing) * (1 - landing * 0.35);
  }

  /// Unselected glyphs and names: cream, quieter than the selected yellow (about 7:1 on the navy).
  static const _quiet = Color(0xBDFFF8EC);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final barH = FloatingPillNav.barHeight(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final side = narrow ? AppSpace.sm : AppSpace.lg;
    return DecoratedBox(
      // The page scrolls behind the floating bar; it fades out towards the bottom edge so it never competes.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.55, 1],
          colors: [c.background.withValues(alpha: 0), c.background.withValues(alpha: 0.75), c.background],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(side, 0, side, AppSpace.sm),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: FloatingPillNav._maxWidth),
              child: SizedBox(
                height: FloatingPillNav._rise + barH,
                child: LayoutBuilder(builder: (context, box) {
                  final slotW = (box.maxWidth - FloatingPillNav._inset * 2) / _slotCount;
                  const top = FloatingPillNav._rise;
                  final capsule = Rect.fromLTWH(0, top, box.maxWidth, barH);
                  // Built once per layout: the capsule and the slots do not move during a hop.
                  final bar = Positioned.fill(
                      child: CustomPaint(key: const ValueKey('nav-capsule'),
                          painter: _CapsulePainter(capsule, isDark: c.isDark, colors: c.hero)));
                  final slots = Positioned(
                    top: top,
                    left: FloatingPillNav._inset,
                    right: FloatingPillNav._inset,
                    height: barH,
                    child: Row(children: [
                      for (var slot = 0; slot < _slotCount; slot++)
                        Expanded(
                          child: widget.action != null && slot == _half
                              ? _actionSlot(context, widget.action!)
                              : _tabSlot(context, slot > _half && widget.action != null ? slot - 1 : slot),
                        ),
                    ]),
                  );
                  final reduced = AppMotion.reduced(context);
                  return AnimatedBuilder(
                    animation: _hop,
                    builder: (context, _) {
                      final t = _hop.value;
                      final arc = math.sin(math.pi * t);   // 0 at rest, 1 in mid-hop
                      final x = FloatingPillNav._inset + slotW * (_position + 0.5);
                      final y = top + FloatingPillNav._drop - FloatingPillNav._lift * arc;
                      return Stack(clipBehavior: Clip.none, children: [
                        bar,
                        // The pool of yellow light on the bar, under the bubble: it ties bubble and bar together.
                        Positioned.fill(child: IgnorePointer(child: CustomPaint(
                            painter: _LightPoolPainter(capsule, x: x, width: slotW, lift: arc)))),
                        slots,
                        Positioned(
                          key: const ValueKey('nav-pill'),
                          left: x - FloatingPillNav.bubble / 2,
                          top: y - FloatingPillNav.bubble / 2,
                          width: FloatingPillNav.bubble,
                          height: FloatingPillNav.bubble,
                          child: IgnorePointer(child: ExcludeSemantics(child: Transform.scale(
                            scale: reduced ? 1 : _scaleAt(t),
                            child: _Bubble(
                              glyph: widget.tabs[widget.selectedIndex].glyph,
                              index: widget.selectedIndex,
                              duration: AppMotion.of(context, AppMotion.page),
                            ),
                          ))),
                        ),
                      ]);
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabSlot(BuildContext context, int index) {
    final c = context.colors;
    final selected = index == widget.selectedIndex;
    final tab = widget.tabs[index];
    return Tap(
      label: tab.label,
      selected: selected,
      onTap: () => widget.onTap(index),
      child: _slot(
        // The selected glyph has risen into the bubble; its place stays so the name keeps its line.
        icon: AnimatedOpacity(
          opacity: selected ? 0 : 1,
          duration: AppMotion.of(context, AppMotion.fast),
          child: NavGlyph(tab.glyph, size: 22, color: _quiet),
        ),
        label: AnimatedDefaultTextStyle(
          duration: AppMotion.of(context, AppMotion.medium),
          curve: AppMotion.standard,
          style: context.text.labelSmall!.copyWith(
            color: selected ? c.accent : _quiet,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: selected ? 0.3 : 0.1,
          ),
          child: Text(tab.label, maxLines: 1),
        ),
      ),
    );
  }

  Widget _actionSlot(BuildContext context, FloatingNavAction a) {
    final c = context.colors;
    return Tap(
      label: a.semanticLabel,
      onTap: a.onTap,
      onLongPress: a.onLongPress,
      longPressHint: a.longPressHint,
      child: _slot(
        // Frosted glass with a yellow viewfinder, like the glass buttons on Home's header: an action resting in the
        // bar, never the bubble's yellow fill.
        icon: SizedBox.square(
          dimension: FloatingPillNav._iconBox,
          child: DecoratedBox(
            key: const ValueKey('nav-scan'),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.05)],
              ),
              border: Border.all(color: c.accent.withValues(alpha: 0.5)),
            ),
            child: Center(child: NavGlyph(a.glyph, size: 19, color: c.accent)),
          ),
        ),
        label: Text(a.label, maxLines: 1,
            style: context.text.labelSmall!.copyWith(color: _quiet, fontWeight: FontWeight.w600, letterSpacing: 0.1)),
      ),
    );
  }

  Widget _slot({required Widget icon, required Widget label}) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: FloatingPillNav._iconBox, child: Center(child: icon)),
          const SizedBox(height: 1),
          // Shrinks rather than cuts at very large text on a narrow phone.
          FittedBox(fit: BoxFit.scaleDown, child: label),
        ],
      );
}

/// The selected tab's circle: brand yellow lit from the top left (like the coin and the glass balance), a fine rim of
/// light, a soft yellow glow over a tight contact shadow, and the filled glyph in navy, popping in as it lands.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.glyph, required this.index, required this.duration});
  final NavGlyphKind glyph;
  final int index;
  final Duration duration;

  static const _sunDeep = AppPalette.sunDeep;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(AppPalette.sun, Colors.white, 0.32)!, AppPalette.sun, _sunDeep],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          const BoxShadow(color: Color(0x2E08124F), blurRadius: 3, offset: Offset(0, 1.5)),
          BoxShadow(color: AppPalette.sun.withValues(alpha: 0.38), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: AppMotion.standard,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween<double>(begin: 0.6, end: 1).animate(a), child: child),
          ),
          child: NavGlyph(glyph, key: ValueKey(index), size: 23, color: AppPalette.navyDeep, filled: true,
              cutout: AppPalette.sun),
        ),
      ),
    );
  }
}

/// The capsule: continuous corners; navy shading to royal blue along its length, lit from above; a fine highlight
/// along the top edge that fades out towards the ends; soft shadows beneath (contact, mid, ambient).
class _CapsulePainter extends CustomPainter {
  const _CapsulePainter(this.capsule, {required this.isDark, required this.colors});

  final Rect capsule;
  final bool isDark;
  final List<Color> colors;   // the hero gradient: navy deep, navy, the lighter navy

  static const _royal = Color(0xFF2A3FBF);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(capsule.height / 2);
    final shape = Path()..addRSuperellipse(RSuperellipse.fromRectAndRadius(capsule, radius));
    final shadows = isDark
        ? const [BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 10))]
        : const [
            BoxShadow(color: Color(0x2B0A1240), blurRadius: 2, offset: Offset(0, 1)),
            BoxShadow(color: Color(0x2B0A1240), blurRadius: 12, offset: Offset(0, 6)),
            BoxShadow(color: Color(0x240B1550), blurRadius: 32, offset: Offset(0, 18)),
          ];
    for (final s in shadows) {
      canvas.drawPath(shape.shift(s.offset), s.toPaint());
    }
    // Navy into royal blue along the bar.
    final emerald = Color.lerp(colors.last, _royal, isDark ? 0.25 : 0.45)!;
    canvas.drawPath(shape, Paint()
      ..shader = LinearGradient(colors: [colors.first, colors[1], emerald], stops: const [0, 0.55, 1])
          .createShader(capsule));
    // Light from above: a soft sheen over the top half.
    canvas.drawPath(shape, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: isDark ? 0.05 : 0.08), Colors.white.withValues(alpha: 0)],
        stops: const [0, 0.55],
      ).createShader(capsule));
    // A fine highlight along the top edge only: the edge's stroke, fading to nothing below the top third.
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawRSuperellipse(
      RSuperellipse.fromRectAndRadius(capsule.deflate(0.5), radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: isDark ? 0.16 : 0.22), Colors.white.withValues(alpha: 0)],
          stops: const [0, 0.35],
        ).createShader(capsule),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CapsulePainter old) =>
      old.capsule != capsule || old.isDark != isDark || old.colors.first != colors.first;
}

/// The soft pool of yellow light on the bar under the selected tab, clipped to the capsule. It dims a little while
/// the bubble is in the air and brightens again as it lands.
class _LightPoolPainter extends CustomPainter {
  const _LightPoolPainter(this.capsule, {required this.x, required this.width, required this.lift});

  final Rect capsule;
  final double x, width, lift;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(Path()
      ..addRSuperellipse(RSuperellipse.fromRectAndRadius(capsule, Radius.circular(capsule.height / 2))));
    final centre = Offset(x, capsule.top + capsule.height * 0.2);
    final radius = width * 0.95;
    canvas.drawCircle(centre, radius, Paint()
      ..shader = RadialGradient(colors: [
        AppPalette.sun.withValues(alpha: 0.24 * (1 - 0.4 * lift)),
        AppPalette.sun.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: centre, radius: radius)));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LightPoolPainter old) => old.x != x || old.lift != lift || old.capsule != capsule;
}
