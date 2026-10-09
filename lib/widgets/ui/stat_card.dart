import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import 'press_scale.dart';
import 'surfaces.dart';
import 'motion.dart';

/// Compact metric: emoji or icon, a value and a label. Tappable when [onTap] is set.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.emoji,
    this.icon,
    this.accent,
    this.valueColor,
    this.onTap,
    this.count,
    this.suffix = '',
    this.leading,
  });

  /// Replaces [emoji]/[icon], e.g. an animated flame.
  final Widget? leading;

  /// When set, the value counts up to [count] (and from the old value when it changes).
  final int? count;
  final String suffix;

  final String value;
  final String label;
  final String? emoji;
  final IconData? icon;
  final Color? accent;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = accent ?? c.primary;
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: cardDecoration(context, radius: AppRadius.lg + 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 3,
          width: 24,
          decoration: BoxDecoration(color: a.withValues(alpha: 0.7), borderRadius: AppRadius.all(2)),
        ),
        const SizedBox(height: AppSpace.xs),
        if (leading != null)
          ExcludeSemantics(child: leading!)
        else if (emoji != null)
          ExcludeSemantics(child: Text(emoji!, style: const TextStyle(fontSize: 20)))
        else if (icon != null)
          Icon(icon, color: a, size: 20),
        const SizedBox(height: AppSpace.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: count != null
              ? AnimatedCount(count!, suffix: suffix,
                  style: context.text.titleLarge!.copyWith(fontFamily: AppType.displayFamily, color: valueColor ?? c.ink(a)))
              : Text(value, style: context.text.titleLarge!.copyWith(fontFamily: AppType.displayFamily, color: valueColor ?? c.ink(a))),
        ),
        Text(label, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
    if (onTap == null) return Semantics(label: '$value $label', excludeSemantics: true, child: card);
    return PressScale(onTap: onTap, label: '$value $label', scale: 0.94, child: card);
  }
}
