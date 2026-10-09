import 'package:flutter/material.dart';

/// A tappable area that screen readers announce as a button with [label] (audit M-14).
/// Use [tooltip] for icon-only controls so the label is also shown on long-press.
class Tap extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final bool tooltip;
  final bool? selected;
  final Widget child;

  const Tap({super.key, required this.onTap, required this.label, required this.child,
      this.tooltip = false, this.selected});

  @override
  Widget build(BuildContext context) {
    final tappable = Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: label,
      onTap: onTap,            // needed: excludeSemantics also hides the GestureDetector's tap action
      excludeSemantics: true,
      child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: child),
    );
    return tooltip ? Tooltip(message: label, child: tappable) : tappable;
  }
}
