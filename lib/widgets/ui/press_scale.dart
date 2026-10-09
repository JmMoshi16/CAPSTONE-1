import 'package:flutter/material.dart';
import '../../core/haptics.dart';
import '../../core/min_tap_area.dart';
import '../../core/tokens.dart';

/// A tappable area with press-scale feedback, a 48 dp minimum touch target and
/// button semantics. With [label], screen readers announce that label instead of the child.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.onTap,
    required this.child,
    this.label,
    this.selected,
    this.scale = 0.96,
    this.minSize = AppSpace.touch,
    this.onLongPress,
    this.longPressHint,
  });

  /// Optional quick action (with a haptic); announced to screen readers via [longPressHint].
  final VoidCallback? onLongPress;
  final String? longPressHint;

  final VoidCallback? onTap;
  final Widget child;
  final String? label;
  final bool? selected;
  final double scale;
  final double minSize;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _activate() {
    AppHaptics.tap();
    widget.onTap!();
  }

  void _longPress() {
    AppHaptics.primary();
    widget.onLongPress!();
  }

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      selected: widget.selected,
      label: widget.label,
      onTap: widget.onTap == null ? null : _activate,
      onLongPress: widget.onLongPress == null ? null : _longPress,
      onLongPressHint: widget.longPressHint,
      excludeSemantics: widget.label != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null ? null : _activate,
        onLongPress: widget.onLongPress == null ? null : _longPress,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: MinTapArea(
          min: widget.minSize,
          child: AnimatedScale(
            scale: _down ? widget.scale : 1,
            duration: AppMotion.of(context, AppMotion.fast),
            curve: AppMotion.standard,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
