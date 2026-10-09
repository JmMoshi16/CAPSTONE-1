import 'package:flutter/material.dart';
import 'haptics.dart';
import 'min_tap_area.dart';
import 'tokens.dart';

/// A tappable area that screen readers announce as a button with [label] (audit M-14).
/// It gives instant feedback (a slight press-in and a light haptic), guarantees a
/// 48 dp touch target, and with [tooltip] shows the label on long-press.
class Tap extends StatefulWidget {
  final VoidCallback? onTap;
  final String label;
  final bool tooltip;
  final bool? selected;
  final Widget child;

  const Tap({super.key, required this.onTap, required this.label, required this.child,
      this.tooltip = false, this.selected});

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;

  void _press(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  void _activate() {
    AppHaptics.tap();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final tappable = Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.label,
      onTap: enabled ? _activate : null,   // needed: excludeSemantics also hides the GestureDetector's tap action
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? _activate : null,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        behavior: HitTestBehavior.opaque,
        // At least 48x48 dp to touch, even when the visible child is smaller.
        child: MinTapArea(
          min: kMinInteractiveDimension,
          child: AnimatedScale(
            scale: _down ? 0.94 : 1,
            duration: AppMotion.of(context, AppMotion.fast),
            curve: AppMotion.standard,
            child: widget.child,
          ),
        ),
      ),
    );
    return widget.tooltip ? Tooltip(message: widget.label, child: tappable) : tappable;
  }
}
