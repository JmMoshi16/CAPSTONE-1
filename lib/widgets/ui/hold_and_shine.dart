import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/haptics.dart';
import '../../core/tokens.dart';

/// Press and hold to confirm: a fill sweeps across the button; releasing early cancels.
/// Screen-reader users (who cannot easily hold) get a confirmation dialog instead.
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 1100),
    this.icon,
    this.confirmQuestion = 'Are you sure?',
  });

  final String label;
  final VoidCallback? onConfirmed;
  final Duration holdDuration;
  final IconData? icon;
  final String confirmQuestion;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.holdDuration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        AppHaptics.success();
        widget.onConfirmed?.call();
      }
    })
    ..addListener(_tickHaptics);
  int _lastTick = 0;

  /// A light tick every quarter of the way, so the hold feels like progress.
  void _tickHaptics() {
    final tick = (_c.value * 4).floor();
    if (_c.status == AnimationStatus.forward && tick != _lastTick && tick > 0 && tick < 4) {
      AppHaptics.tap();
    }
    _lastTick = tick;
  }

  bool get _enabled => widget.onConfirmed != null;

  void _start() {
    if (!_enabled) return;
    AppHaptics.tap();
    _c.forward();
  }

  void _cancel() {
    if (_c.isCompleted) return;
    _c.animateBack(0, duration: AppMotion.of(context, AppMotion.medium), curve: AppMotion.standard);
  }

  Future<void> _accessibleConfirm() async {
    if (!_enabled) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.label),
        content: Text(widget.confirmQuestion),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok == true) widget.onConfirmed?.call();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: '${widget.label}. Double tap to confirm.',
      excludeSemantics: true,
      onTap: _enabled ? _accessibleConfirm : null,
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _cancel(),
        onTapCancel: _cancel,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            return Container(
              height: 58,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _enabled ? c.primaryContainer : c.surfaceAlt,
                borderRadius: AppRadius.all(AppRadius.lg + 2),
                border: Border.all(color: _enabled ? c.primary : c.border, width: 1.5),
              ),
              child: Stack(children: [
                // The fill: the forest gradient grows from the left.
                FractionallySizedBox(
                  widthFactor: _c.value,
                  heightFactor: 1,
                  child: const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.forest)),
                ),
                Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _c.value > 0.5 ? Icons.lock_open_rounded : (widget.icon ?? Icons.touch_app_rounded),
                      color: !_enabled ? c.textTertiary : (_c.value > 0.5 ? Colors.white : c.primary),
                      size: 20,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Text(
                      _c.value > 0 && _c.value < 1 ? 'Keep holding…' : widget.label,
                      style: t.labelLarge!.copyWith(
                        color: !_enabled ? c.textTertiary : (_c.value > 0.5 ? Colors.white : c.primary),
                      ),
                    ),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// Ticket outline: rounded rectangle with two half-circle "punches" at [stubFromRight]
/// on the top and bottom edges, where a perforation line is drawn.
class TicketBorder extends ShapeBorder {
  const TicketBorder({this.radius = AppRadius.lg, this.notch = 9, required this.stubFromRight, this.side = BorderSide.none});

  final double radius;
  final double notch;
  final double stubFromRight;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect r) {
    final x = r.right - stubFromRight;
    final body = Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
    final punches = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, r.top), radius: notch))
      ..addOval(Rect.fromCircle(center: Offset(x, r.bottom), radius: notch));
    return Path.combine(PathOperation.difference, body, punches);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect.deflate(side.width));
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style != BorderStyle.none) {
      canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
    }
    // Perforation: a dashed line between the two punches.
    final x = rect.right - stubFromRight;
    final dash = Paint()
      ..color = (side.style == BorderStyle.none ? const Color(0x33000000) : side.color.withValues(alpha: 0.6))
      ..strokeWidth = 1.2;
    for (var y = rect.top + notch + 3; y < rect.bottom - notch - 3; y += 7) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 3.5, rect.bottom - notch - 3)), dash);
    }
  }

  @override
  ShapeBorder scale(double t) =>
      TicketBorder(radius: radius * t, notch: notch * t, stubFromRight: stubFromRight * t, side: side.scale(t));
}
