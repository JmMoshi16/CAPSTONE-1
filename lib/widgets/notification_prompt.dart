import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import 'ui.dart';

const _askedKey = 'notifications_prompted';

/// After a successful scan: once per device, explain why we would like to send
/// notifications, then show the Android permission dialog only if the user agrees.
Future<void> askForNotificationsOnce(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_askedKey) ?? false) return;
  await prefs.setBool(_askedKey, true);
  if (await NotificationService.enabled()) return;
  if (!context.mounted) return;

  final yes = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final c = ctx.colors;
      final t = ctx.text;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.notifications_active_rounded, color: c.onPrimaryContainer, size: 32),
            ),
            const SizedBox(height: AppSpace.md),
            Text('Get notified about your points?', style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.xs),
            Text("We'll send a short notification when points or a badge are credited. Nothing else.",
                style: t.bodyMedium!.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.lg),
            AppButton(label: 'Turn on notifications', icon: Icons.notifications_rounded,
                onPressed: () => Navigator.pop(ctx, true)),
            const SizedBox(height: AppSpace.xs),
            AppButton.secondary(label: 'Not now', onPressed: () => Navigator.pop(ctx, false)),
          ]),
        ),
      );
    },
  );
  if (yes == true) await NotificationService.requestPermission();
}
