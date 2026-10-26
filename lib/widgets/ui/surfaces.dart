import 'package:flutter/material.dart';
import '../../core/haptics.dart';
import '../../core/tokens.dart';
import 'press_scale.dart';

/// Card surface: one spec everywhere, a flat surface with a hairline border and a 16 px radius. Depth comes from
/// the page background, not shadows (shadows are kept for things that float: sheets, the nav bar).
BoxDecoration cardDecoration(BuildContext context, {double radius = AppRadius.lg, Color? color, Color? borderColor}) {
  final c = context.colors;
  return BoxDecoration(
    color: color ?? c.surface,
    borderRadius: AppRadius.all(radius),
    border: Border.all(color: borderColor ?? c.border, width: borderColor != null ? 1.5 : 1),
  );
}

/// Gradient used behind white header text (meets 4.5:1 with [AppColors.onHero]).
BoxDecoration heroDecoration(BuildContext context, {BorderRadius? radius}) => BoxDecoration(
      gradient: LinearGradient(
        colors: context.colors.hero,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: radius,
    );

/// Section title with optional subtitle and a text action (48 dp target).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.actionLabel, this.onAction, this.trailing});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: t.titleMedium, semanticsLabel: title),
          if (subtitle != null) Text(subtitle!, style: t.bodySmall),
        ]),
      ),
      if (trailing != null) trailing!,
      if (actionLabel != null)
        TextButton(onPressed: onAction, child: Text(actionLabel!)),
    ]);
  }
}

/// Selectable pill. The visible pill is compact; the touch target is 48 dp tall.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.selected, required this.onTap, this.icon, this.semanticLabel});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onPrimary : c.textSecondary;
    return PressScale(
      onTap: onTap,
      selected: selected,
      label: semanticLabel ?? label,
      // Centred at its own size: a list that hands the chip a fixed 48 dp height (the touch target) used to
      // stretch the pill, so a short label such as "All" became a circle.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          curve: AppMotion.standard,
          constraints: const BoxConstraints(minWidth: 56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
          decoration: BoxDecoration(
            color: selected ? c.primary : c.surface,
            borderRadius: AppRadius.all(AppRadius.pill),
            border: Border.all(color: selected ? c.primary : c.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: AppSpace.xxs)],
            Text(label, style: context.text.labelMedium!.copyWith(
                color: fg, fontWeight: selected ? FontWeight.w700 : FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// Small rounded square holding an icon, tinted with [color].
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color, this.size = 44, this.filled = false});

  final IconData icon;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: context.colors.isDark ? 0.22 : 0.12),
          borderRadius: AppRadius.all(size * 0.3),
        ),
        child: Icon(icon, color: filled ? Colors.white : color, size: size * 0.5),
      );
}

/// Card-style list row: leading, title, subtitle, trailing, optional tap.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    this.borderColor,
    this.margin = const EdgeInsets.only(bottom: AppSpace.sm),
  });

  final String title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? borderColor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: margin,
      padding: const EdgeInsets.all(AppSpace.md - 2),
      decoration: cardDecoration(context, radius: AppRadius.lg, borderColor: borderColor),
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: AppSpace.sm)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle != null) ...[const SizedBox(height: 2), subtitle!],
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: AppSpace.xs), trailing!],
      ]),
    );
    if (onTap == null) return row;
    return PressScale(onTap: onTap, label: semanticLabel, scale: 0.98, child: row);
  }
}

/// Points / count pill such as "+15 pts".
class PointsPill extends StatelessWidget {
  const PointsPill(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? c.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xxs + 2),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: c.isDark ? 0.18 : 0.10),
        borderRadius: AppRadius.all(AppRadius.pill),
      ),
      child: Text(text, style: context.text.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

/// Back arrow for page headers: a plain icon, 48 dp touch target, labelled "Back".
class HeroBackButton extends StatelessWidget {
  const HeroBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Back',
        onPressed: onTap,
        icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
      );
}

/// A titled group of settings rows on one card (iOS / Revolut style list).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, thickness: 1, indent: 56, color: c.border));
      rows.add(children[i]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.xs),
          child: Semantics(header: true, child: Text(title!.toUpperCase(),
              style: context.text.labelSmall!.copyWith(letterSpacing: 1.0, color: c.textSecondary))),
        ),
      Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.lg), side: BorderSide(color: c.border)),
        child: Column(children: rows),
      ),
    ]);
  }
}

/// One settings row: icon, title, optional value or subtitle, and a chevron when it opens something.
/// [trailing] replaces the chevron (e.g. a switch). [destructive] colours it for sign-out.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final fg = destructive ? c.danger : c.textPrimary;
    return InkWell(
      onTap: onTap == null ? null : () { AppHaptics.tap(); onTap!(); },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
          child: Row(children: [
            Icon(icon, size: 22, color: destructive ? c.danger : c.textSecondary),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: t.bodyLarge!.copyWith(color: fg, fontWeight: FontWeight.w500)),
                if (subtitle != null) Text(subtitle!, style: t.bodySmall),
              ]),
            ),
            if (value != null) ...[
              const SizedBox(width: AppSpace.xs),
              Flexible(child: Text(value!, style: t.bodyMedium!.copyWith(color: c.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
            ],
            if (trailing != null) ...[const SizedBox(width: AppSpace.xs), trailing!]
            else if (onTap != null && !destructive) ...[
              const SizedBox(width: AppSpace.xxs),
              Icon(Icons.chevron_right_rounded, color: c.textTertiary),
            ],
          ]),
        ),
      ),
    );
  }
}
