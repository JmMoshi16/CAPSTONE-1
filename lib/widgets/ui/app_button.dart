import 'package:flutter/material.dart';
import '../../core/haptics.dart';
import '../../core/tokens.dart';

enum AppButtonKind { primary, secondary, danger }

/// Primary / secondary / danger button: 52 dp tall, press-scale feedback, optional
/// leading and trailing icons, and a busy state that keeps the button's size.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.kind = AppButtonKind.primary,
    this.loading = false,
    this.expand = true,
    this.height = 52,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
  }) : kind = AppButtonKind.secondary;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final AppButtonKind kind;
  final bool loading;
  final bool expand;
  final double height;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null && !widget.loading;
    final fg = switch (widget.kind) {
      AppButtonKind.primary => scheme.onPrimary,
      AppButtonKind.secondary => scheme.primary,
      AppButtonKind.danger => Colors.white,
    };

    final content = widget.loading
        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[Icon(widget.icon, size: 20), const SizedBox(width: AppSpace.xs)],
            Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis)),
            if (widget.trailingIcon != null) ...[const SizedBox(width: AppSpace.xs), Icon(widget.trailingIcon, size: 18)],
          ]);

    final size = Size(widget.expand ? double.infinity : AppSpace.touch, widget.height);
    // Primary actions get a light haptic; secondary ones a softer click.
    final onPressed = enabled
        ? () {
            widget.kind == AppButtonKind.secondary ? AppHaptics.tap() : AppHaptics.primary();
            widget.onPressed!();
          }
        : null;
    final Widget button = switch (widget.kind) {
      AppButtonKind.primary => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(minimumSize: size,
              disabledBackgroundColor: widget.loading ? scheme.primary : null),
          child: content),
      AppButtonKind.secondary => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(minimumSize: size, backgroundColor: c.surface),
          child: content),
      AppButtonKind.danger => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(minimumSize: size, backgroundColor: AppColors.light.danger, // white text 5.6:1 in both themes
              foregroundColor: Colors.white),
          child: content),
    };

    return Listener(
      onPointerDown: (_) { if (enabled) setState(() => _down = true); },
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: AppMotion.of(context, AppMotion.fast),
        curve: AppMotion.standard,
        child: button,
      ),
    );
  }
}
