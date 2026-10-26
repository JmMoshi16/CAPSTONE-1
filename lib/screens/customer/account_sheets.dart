// Profile > settings sheets: how the programme works, privacy, appearance and password reset.
// Every fact here comes from the code or the project's privacy notice (kiosk repo docs/privacy.md).

import 'package:flutter/material.dart';
import '../../services/appearance.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ui.dart';

Widget _para(BuildContext context, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: context.text.titleSmall),
        const SizedBox(height: AppSpace.xxs),
        Text(body, style: context.text.bodyMedium!.copyWith(color: context.colors.textSecondary, height: 1.45)),
      ]),
    );

void showHowItWorksSheet(BuildContext context) {
  const pts = kBasePoints;
  AppSheet.show(context, title: 'How ECOReward works', initialSize: 0.75, builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xl),
        children: [
          _para(ctx, '1. Sort at the bin',
              'Place one item on the tray. The bin recognises it and drops it into the right compartment.'),
          _para(ctx, '2. Scan the code',
              'The screen shows a QR code for that item. Tap Scan in the app and point your camera at it. '
              'A code works for 20 minutes and only once.'),
          _para(ctx, '3. Earn points',
              'Biodegradable ${pts['Biodegradable']} pts · Recyclable ${pts['Recyclable']} pts · Residual ${pts['Residual']} pts. '
              'Scan on consecutive days for a streak: 1.5× points from day 3, 2× from day 7.'),
          _para(ctx, '4. Redeem at the counter',
              'Choose a reward in Rewards. You get a code; show it to staff within 7 days to collect your reward.'),
          _para(ctx, 'No phone with you?',
              'Tap "No phone? Claim code" on the bin screen and give staff the code and your username. '
              'They add the points for you.'),
          _para(ctx, 'Questions or problems', 'Ask any staff member at the counter.'),
        ],
      ));
}

void showPrivacySheet(BuildContext context) {
  AppSheet.show(context, title: 'Privacy', initialSize: 0.8, builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xl),
        children: [
          _para(ctx, 'What we keep',
              'Your email and username, each scan (waste type, time, points), the rewards you redeem, and your '
              'profile photo if you add one. Your password is handled by Google Firebase; we never see it.'),
          _para(ctx, 'The bin camera',
              'The kiosk camera looks at the item to decide its category. Images are processed on the kiosk and are '
              'not saved or uploaded; only the result is recorded.'),
          _para(ctx, 'Who can see it',
              'You see everything about your account. Other customers see only your username, points and badges on '
              'the leaderboard, never your email or photo. Café staff can see your account to run the programme.'),
          _para(ctx, 'No tracking', 'The app has no advertising, analytics or tracking tools.'),
          _para(ctx, 'Deleting your data',
              'Ask staff at the counter. After confirming it is your account, they delete it and everything linked '
              'to it. Points and unclaimed rewards are lost when the account is deleted.'),
        ],
      ));
}

void showAppearanceSheet(BuildContext context) {
  AppSheet.show(context, title: 'Appearance', initialSize: 0.4, minSize: 0.3, builder: (ctx, scroll) =>
      ValueListenableBuilder<ThemeMode>(
        valueListenable: Appearance.mode,
        builder: (ctx, mode, _) => ListView(controller: scroll, children: [
          for (final m in const [ThemeMode.system, ThemeMode.light, ThemeMode.dark])
            ListTile(
              leading: Icon(switch (m) {
                ThemeMode.light => Icons.light_mode_outlined,
                ThemeMode.dark => Icons.dark_mode_outlined,
                ThemeMode.system => Icons.settings_suggest_outlined,
              }),
              title: Text(Appearance.label(m)),
              trailing: mode == m ? Icon(Icons.check_rounded, color: ctx.colors.primary) : null,
              selected: mode == m,
              onTap: () { AppHaptics.tap(); Appearance.set(m); },
            ),
        ]),
      ));
}

/// Sends Firebase's password-reset email to the signed-in address, after a confirmation.
Future<void> confirmPasswordReset(BuildContext context, String email) async {
  final send = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Change password'),
      content: Text('We will email a link to $email. Open it on any device to choose a new password.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send link')),
      ],
    ),
  );
  if (send != true || !context.mounted) return;
  try {
    await FirebaseService.sendPasswordReset(email);
    if (context.mounted) AppSnackbar.success(context, 'Reset link sent to $email');
  } catch (_) {
    if (context.mounted) AppSnackbar.error(context, 'Could not send the link. Check your connection and try again.');
  }
}
