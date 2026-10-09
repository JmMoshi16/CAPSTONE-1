import 'package:flutter/material.dart';
import '../../core/haptics.dart';
import '../../core/tokens.dart';

enum SnackKind { success, error, info }

/// One snackbar style for the whole app: an icon, a colour that matches the outcome,
/// and the matching haptic (success / error). Text is white on fills that pass AA.
class AppSnackbar {
  static void show(BuildContext context, String message,
      {SnackKind kind = SnackKind.info, String? actionLabel, VoidCallback? onAction, Duration? duration}) {
    final c = context.colors;
    final (icon, bg) = switch (kind) {
      SnackKind.success => (Icons.check_circle_rounded, AppColors.light.success),
      SnackKind.error => (Icons.error_rounded, AppColors.light.danger),
      SnackKind.info => (Icons.info_rounded, c.isDark ? AppColors.dark.border : AppPalette.forestDeep),
    };
    if (kind == SnackKind.success) AppHaptics.success();
    if (kind == SnackKind.error) AppHaptics.error();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: bg,
        duration: duration ?? const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
        ]),
        action: actionLabel == null
            ? null
            // Mint passes only on the dark info fill (6.3:1); white on green/red (5.1 / 5.6:1).
            : SnackBarAction(label: actionLabel, textColor: kind == SnackKind.info ? AppPalette.mint : Colors.white,
                onPressed: onAction ?? () {}),
      ));
  }

  static void success(BuildContext context, String message) => show(context, message, kind: SnackKind.success);
  static void error(BuildContext context, String message) => show(context, message, kind: SnackKind.error);
  static void info(BuildContext context, String message) => show(context, message);
}
