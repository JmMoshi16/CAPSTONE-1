import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firebase_service.dart';
import '../../services/sound_service.dart';
import '../../services/appearance.dart';
import '../../models/models.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../login_screen.dart';
import 'leaderboard_screen.dart';
import 'badges_screen.dart';
import 'edit_profile_screen.dart';
import 'account_sheets.dart';

/// Profile: who you are, three numbers that each open their screen, your badges, and grouped settings.
class CustomerProfileScreen extends StatefulWidget {
  final UserModel user;
  final List<WasteLog> logs;
  final int myRank;                       // leaderboard position, 0 = not ranked yet
  final VoidCallback onUpdated;
  final VoidCallback? onOpenRewards;
  final VoidCallback? onOpenHistory;
  const CustomerProfileScreen({super.key, required this.user, required this.logs, required this.onUpdated,
      this.myRank = 0, this.onOpenRewards, this.onOpenHistory});
  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  Future<void> _editProfile() async {
    final saved = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => EditProfileScreen(user: widget.user)));
    if (saved == true && mounted) {
      setState(() {});
      widget.onUpdated();
      AppSnackbar.success(context, 'Profile updated');
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign in again any time with your email and password.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Sign out', style: TextStyle(color: ctx.colors.danger))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
      }
    }
  }

  void _openLeaderboard() => Navigator.push(context, MaterialPageRoute(
      builder: (_) => LeaderboardScreen(currentUid: widget.user.uid, me: widget.user)));

  void _openBadges() => Navigator.push(context, MaterialPageRoute(builder: (_) => BadgesScreen(user: widget.user)));

  static String _monthYear(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final user = widget.user;
    final rank = getRank(user.lifetimePoints);
    final level = getLevel(user.lifetimePoints);

    Widget gap([double h = AppSpace.xl]) => SliverToBoxAdapter(child: SizedBox(height: h));
    Widget padded(Widget child) => SliverToBoxAdapter(
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg), child: child));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: EcoRefresh(
          onRefresh: () async => widget.onUpdated(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                    child: Text('Profile', style: t.headlineMedium),
                  ),
                ),
              ),
              gap(AppSpace.lg),

              // ── Identity ──
              padded(Column(children: [
                Tap(label: 'Edit profile photo', onTap: _editProfile,
                    child: UserAvatar(name: user.username, photo: user.photo, size: 96)),
                const SizedBox(height: AppSpace.md),
                Text(user.username, style: t.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: AppSpace.xxs),
                Text('Member since ${_monthYear(user.createdAt)}', style: t.bodyMedium!.copyWith(color: c.textSecondary)),
                const SizedBox(height: AppSpace.sm),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  RankMark(lifetimePoints: user.lifetimePoints, size: 24),
                  const SizedBox(width: AppSpace.xs),
                  Flexible(child: Text('${rank.label} member · Level ${level.level} ${level.title}',
                      style: t.labelLarge, textAlign: TextAlign.center)),
                ]),
                const SizedBox(height: AppSpace.md),
                OutlinedButton.icon(
                  onPressed: _editProfile,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit profile'),
                ),
              ])),
              gap(),

              // ── Numbers: each opens the screen it summarises ──
              padded(Container(
                clipBehavior: Clip.antiAlias,
                decoration: cardDecoration(context),
                child: Material(
                  color: Colors.transparent,
                  child: IntrinsicHeight(
                    child: Row(children: [
                      _stat('${user.points}', 'Points', 'Open rewards', widget.onOpenRewards),
                      VerticalDivider(width: 1, thickness: 1, color: c.border),
                      _stat('${user.scanCount}', 'Scans', 'Open scan history', widget.onOpenHistory),
                      VerticalDivider(width: 1, thickness: 1, color: c.border),
                      _stat(widget.myRank > 0 ? '#${widget.myRank}' : '—', 'Leaderboard', 'Open leaderboard',
                          _openLeaderboard),
                    ]),
                  ),
                ),
              )),
              gap(),

              // ── Achievements ──
              padded(SectionHeader(title: 'Achievements', actionLabel: 'See all', onAction: _openBadges)),
              gap(AppSpace.sm),
              padded(Tap(
                label: '${user.badges.length} badges earned, see all badges',
                onTap: _openBadges,
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: cardDecoration(context),
                  child: user.badges.isEmpty
                      ? Row(children: [
                          BadgeMark(id: 'first_scan', color: c.primary, earned: false, size: 40),
                          const SizedBox(width: AppSpace.md),
                          Expanded(child: Text('Scan your first item to earn a badge.', style: t.bodyMedium)),
                          Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                        ])
                      : Row(children: [
                          for (final id in user.badges.take(5)) ...[
                            Tooltip(
                              message: FirebaseService.getBadgeInfo(id)['label'] as String,
                              child: BadgeMark(id: id, color: c.primary, size: 40),
                            ),
                            const SizedBox(width: AppSpace.xs),
                          ],
                          const Spacer(),
                          Text('${user.badges.length}', style: t.titleMedium),
                          Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                        ]),
                ),
              )),
              gap(),

              // ── Settings ──
              padded(SettingsGroup(title: 'Account', children: [
                SettingsRow(icon: Icons.person_outline_rounded, title: 'Edit profile',
                    subtitle: 'Photo and username', onTap: _editProfile),
                SettingsRow(icon: Icons.password_rounded, title: 'Change password',
                    onTap: () => confirmPasswordReset(context, user.email)),
                SettingsRow(icon: Icons.alternate_email_rounded, title: 'Email', value: user.email),
              ])),
              gap(AppSpace.lg),
              padded(SettingsGroup(title: 'Preferences', children: [
                // Hidden where this build has no sound player (iPhone), instead of a switch that does nothing.
                if (AppSounds.available)
                  SettingsRow(
                    icon: Icons.volume_up_outlined,
                    title: 'Sound effects',
                    trailing: Switch(
                      value: AppSounds.enabled,
                      onChanged: (v) async {
                        AppHaptics.tap();
                        await AppSounds.setEnabled(v);
                        if (mounted) setState(() {});
                        if (v) AppSounds.play(AppSound.success);
                      },
                    ),
                  ),
                SettingsRow(icon: Icons.notifications_none_rounded, title: 'Notifications',
                    subtitle: 'Points credited and reward reminders',
                    onTap: () => AppSettings.openAppSettings(type: AppSettingsType.notification)),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: Appearance.mode,
                  builder: (_, mode, __) => SettingsRow(icon: Icons.contrast_rounded, title: 'Appearance',
                      value: Appearance.label(mode), onTap: () => showAppearanceSheet(context)),
                ),
              ])),
              gap(AppSpace.lg),
              padded(SettingsGroup(title: 'Help & legal', children: [
                SettingsRow(icon: Icons.help_outline_rounded, title: 'How ECOReward works',
                    onTap: () => showHowItWorksSheet(context)),
                SettingsRow(icon: Icons.privacy_tip_outlined, title: 'Privacy', onTap: () => showPrivacySheet(context)),
              ])),
              gap(AppSpace.lg),
              padded(SettingsGroup(children: [
                SettingsRow(icon: Icons.logout_rounded, title: 'Sign out', destructive: true, onTap: _signOut),
              ])),
              gap(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label, String hint, VoidCallback? onTap) => Expanded(
        child: Semantics(
          button: onTap != null,
          label: '$label $value, $hint',
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap == null ? null : () { AppHaptics.tap(); onTap(); },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              child: Column(children: [
                FittedBox(fit: BoxFit.scaleDown,
                    child: Text(value, style: AppType.numeral.copyWith(fontSize: 26, color: context.colors.textPrimary))),
                const SizedBox(height: AppSpace.xxs),
                Text(label, style: context.text.bodySmall),
              ]),
            ),
          ),
        ),
      );
}
