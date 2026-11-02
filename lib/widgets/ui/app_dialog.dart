import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import 'app_button.dart';

/// The app's dialog: an optional icon, a title, a message, then the actions stacked full width with the
/// confirming one on top. Returns true (confirm), false (cancel) or null (closed by tapping outside or back).
Future<bool?> showAppDialog(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  IconData? icon,
  Color? iconColor,
  Color? iconBackground,
  required String confirmLabel,
  IconData? confirmIcon,
  String? cancelLabel = 'Cancel',
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.colors;
      return AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: iconBackground ?? c.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor ?? c.primary, size: 34),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          Text(title, style: ctx.text.titleLarge, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(message, style: ctx.text.bodyMedium!.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
          ],
          if (content != null) ...[const SizedBox(height: AppSpace.md), content],
        ]),
        actions: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            AppButton(
              label: confirmLabel,
              icon: confirmIcon,
              height: 48,
              kind: destructive ? AppButtonKind.danger : AppButtonKind.primary,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            if (cancelLabel != null) ...[
              const SizedBox(height: AppSpace.xs),
              AppButton.secondary(label: cancelLabel, height: 48, onPressed: () => Navigator.pop(ctx, false)),
            ],
          ]),
        ],
      );
    },
  );
}
