import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../core/theme.dart';
import '../../core/gamification.dart';
import '../../widgets/ui.dart';
import '../login_screen.dart';
import 'leaderboard_screen.dart';
import 'badges_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  final UserModel user;
  final List<WasteLog> logs;
  final VoidCallback onUpdated;
  /// True when opened from the Home avatar, so the avatar flies in (Hero).
  final bool heroAvatar;
  /// Opens the Rewards tab from the points chip (spend your points).
  final VoidCallback? onOpenRewards;
  const CustomerProfileScreen({super.key, required this.user, required this.logs, required this.onUpdated,
      this.heroAvatar = false, this.onOpenRewards});
  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _userCtrl = TextEditingController(text: widget.user.username);
  bool _editing = false;
  bool _saving  = false;
  int  _myRank  = 0;

  @override
  void initState() {
    super.initState();
    _loadRank();
  }

  Future<void> _loadRank() async {
    try {
      final r = await FirebaseService.getUserRank(widget.user.uid).timeout(const Duration(seconds: 10));
      if (mounted) setState(() => _myRank = r);
    } catch (_) {
      // Rank is optional on this screen; the chip simply stays hidden.
    }
  }

  Future<void> _refresh() async {
    widget.onUpdated();
    await _loadRank();
  }

  @override
  void dispose() { _userCtrl.dispose(); super.dispose(); }

  Map<String, dynamic> get _rank {
    final r = getRank(widget.user.lifetimePoints);
    return {'label': r.label, 'color': r.color, 'icon': r.icon, 'next': r.next, 'nextPts': r.nextPts};
  }

  double get _rankProgress => rankProgress(widget.user.lifetimePoints);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final newUsername = _userCtrl.text.trim();
    try {
      await FirebaseService.updateUsername(widget.user.uid, newUsername);
      widget.user.username = newUsername; // only after the write succeeded
      widget.onUpdated();
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile updated!'),
          backgroundColor: context.colors.success,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not update your profile. Check your connection and try again.'),
          backgroundColor: context.colors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: ctx.colors.textSecondary))),
          AppButton(label: 'Logout', kind: AppButtonKind.danger, expand: false, height: 48,
              onPressed: () => Navigator.pop(ctx, true)),
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
      builder: (_) => LeaderboardScreen(currentUid: widget.user.uid)));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final bio = widget.logs.where((l) => l.wasteType == 'Biodegradable').length;
    final rec = widget.logs.where((l) => l.wasteType == 'Recyclable').length;
    final res = widget.logs.where((l) => l.wasteType == 'Residual').length;
    final rank      = _rank;
    final rankColor = rank['color'] as Color;

    // FIX 8: Use actual rank info instead of computed level
    final rankInfo   = getRank(widget.user.lifetimePoints);
    final streak     = effectiveStreak(widget.user.streak, widget.user.lastScanDate, DateTime.now());
    final winRate    = widget.logs.isEmpty ? 0 : ((rec + bio) / widget.logs.length * 100).round();
    final daysSince  = DateTime.now().difference(widget.user.createdAt).inDays;

    // This screen has no coloured header, so the status-bar icons follow the theme.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [

            // ── Top bar ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Points chip — taps to leaderboard
                      PressScale(
                        label: '${widget.user.points} points, open rewards',
                        onTap: widget.onOpenRewards ?? _openLeaderboard,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md - 2, vertical: AppSpace.xs),
                          decoration: cardDecoration(context, radius: AppRadius.pill,
                              borderColor: c.primary.withValues(alpha: 0.3)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                              child: Icon(Icons.stars_rounded, size: 13, color: c.onPrimary),
                            ),
                            const SizedBox(width: AppSpace.xs),
                            AnimatedCount(widget.user.points, suffix: ' pts', style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                      PressScale(
                        label: 'Logout',
                        onTap: _logout,
                        child: Tooltip(
                          message: 'Logout',
                          child: Container(
                            width: 44, height: 44,
                            decoration: cardDecoration(context, radius: AppRadius.md),
                            child: Icon(Icons.logout_rounded, color: c.danger, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Avatar + name ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl, AppSpace.lg, 0),
                child: Column(children: [
                  _DashedAvatar(
                    initial: widget.user.username.isNotEmpty ? widget.user.username[0].toUpperCase() : 'U',
                    rankIcon: rank['icon'] as String,
                    rankColor: rankColor,
                    heroTag: widget.heroAvatar ? 'avatar-${widget.user.uid}' : null,
                  ),
                  const SizedBox(height: AppSpace.md - 2),
                  Text(widget.user.username, style: t.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpace.xxs),
                  // There are no @handles in the app, so show something real instead.
                  Text(
                    'Member since ${_monthYear(widget.user.createdAt)}',
                    style: t.bodyMedium!.copyWith(color: c.textSecondary),
                  ),
                  if (_myRank > 0)
                    TextButton(
                      onPressed: _openLeaderboard,
                      child: Text('🏆  Rank #$_myRank'),
                    ),
                  const SizedBox(height: AppSpace.xs),
                  // ── Edit profile button ──
                  PressScale(
                    onTap: () => setState(() {
                      _editing = !_editing;
                      if (!_editing) _userCtrl.text = widget.user.username;
                    }),
                    child: AnimatedContainer(
                      duration: AppMotion.of(context, AppMotion.medium),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm - 2),
                      decoration: BoxDecoration(
                        color: _editing ? c.dangerContainer : c.primaryContainer,
                        borderRadius: AppRadius.all(AppRadius.pill),
                        border: Border.all(
                          color: (_editing ? c.danger : c.primary).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_editing ? Icons.close_rounded : Icons.edit_rounded,
                            color: _editing ? c.danger : c.primary, size: 16),
                        const SizedBox(width: AppSpace.xs - 2),
                        Text(_editing ? 'Cancel' : 'Edit Profile',
                            style: t.labelMedium!.copyWith(
                                color: _editing ? c.danger : c.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),

            // ── 3-stat row (Eco Rate · Rank · Days) ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl, AppSpace.lg, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md + 2),
                  decoration: cardDecoration(context),
                  child: Row(children: [
                    Expanded(child: _statPill('$winRate%', 'Eco Rate', Icons.recycling_rounded, c.success)),
                    _divider(),
                    // FIX 8: Show rank (icon + label) with rank color
                    Expanded(child: _statPill('${rankInfo.icon} ${rankInfo.label}', 'Rank',
                        Icons.military_tech_rounded, c.ink(rankInfo.color))),
                    _divider(),
                    Expanded(child: _statPill('$daysSince', 'Days', Icons.calendar_today_rounded, c.info)),
                  ]),
                ),
              ),
            ),

            // ── "Keep it up!" streak banner ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: cardDecoration(context),
                  child: Row(children: [
                    ExcludeSemantics(
                      child: SizedBox(
                        width: 56,
                        height: 40,
                        child: Stack(
                          children: List.generate(3, (i) => Positioned(
                            left: i * 16.0,
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: [c.success, c.gold, c.info][i].withValues(alpha: 0.2),
                                border: Border.all(color: c.surface, width: 2),
                              ),
                              child: Center(child: Text(['♻', '🌿', '🔥'][i], style: const TextStyle(fontSize: 13))),
                            ),
                          )),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(streak > 0 ? 'Keep it up!' : 'Start your streak!', style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        streak > 0
                            ? '$streak day${streak > 1 ? 's' : ''} in a row — you\'re here!'
                            : 'Scan waste today to begin your streak',
                        style: t.bodySmall,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Row(children: List.generate(7, (i) => Container(
                        width: 10, height: 10,
                        margin: const EdgeInsets.only(right: AppSpace.xxs + 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < streak ? c.primary : c.surfaceAlt,
                          border: i < streak ? null : Border.all(color: c.border),
                        ),
                      ))),
                    ])),
                    const SizedBox(width: AppSpace.sm),
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadius.all(AppRadius.lg - 2)),
                      child: const Center(child: ExcludeSemantics(child: Text('🏆', style: TextStyle(fontSize: 26)))),
                    ),
                  ]),
                ),
              ),
            ),

            // ── Badges banner ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
                child: PressScale(
                  scale: 0.98,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => BadgesScreen(user: widget.user))),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: BoxDecoration(
                      color: c.primaryContainer,
                      borderRadius: AppRadius.all(AppRadius.xl),
                      border: Border.all(color: c.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      ExcludeSemantics(
                        child: SizedBox(
                          width: 56, height: 40,
                          child: Stack(
                            children: List.generate(2, (i) => Positioned(
                              left: i * 20.0,
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.primaryContainer, width: 2),
                                ),
                                child: Center(child: Text(['🌱', '♻️'][i], style: const TextStyle(fontSize: 16))),
                              ),
                            )),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Your badges', style: t.titleSmall!.copyWith(
                            color: c.onPrimaryContainer, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          widget.user.badges.isEmpty
                              ? 'Earn badges by scanning waste!'
                              : '${widget.user.badges.length} badge${widget.user.badges.length > 1 ? 's' : ''} earned — tap to see all',
                          style: t.bodySmall!.copyWith(color: c.onPrimaryContainer),
                        ),
                      ])),
                      Icon(Icons.chevron_right_rounded, color: c.onPrimaryContainer),
                    ]),
                  ),
                ),
              ),
            ),

            // ── Divider label ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl + 4, AppSpace.lg, AppSpace.sm),
                child: Row(children: [
                  Container(width: 4, height: 16, decoration: BoxDecoration(color: c.primary, borderRadius: AppRadius.all(2))),
                  const SizedBox(width: AppSpace.sm - 2),
                  Text('Your Stats', style: t.titleMedium),
                ]),
              ),
            ),

            // ── Progress to next rank ─────────────────────────────────────────
            if (rank['next'] != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: cardDecoration(context),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: AppSpace.xs, runSpacing: AppSpace.xxs, children: [
                        Icon(Icons.military_tech_rounded, color: c.ink(rankColor), size: 20),
                        Text('Progress to ${rank['next']}', style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                        Text('${widget.user.lifetimePoints} / ${rank['nextPts']} lifetime pts',
                            style: t.labelMedium!.copyWith(color: c.ink(rankColor), fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: AppSpace.sm),
                      AnimatedBar(progress: _rankProgress, color: rankColor),
                      const SizedBox(height: AppSpace.xs - 2),
                      Text('${(rank['nextPts'] as int) - widget.user.lifetimePoints} more points to reach ${rank['next']}',
                          style: t.labelSmall!.copyWith(fontWeight: FontWeight.w400)),
                    ]),
                  ),
                ),
              ),

            // ── Waste breakdown ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.md),
                  decoration: cardDecoration(context),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.pie_chart_rounded, color: c.primary, size: 18),
                      const SizedBox(width: AppSpace.xs),
                      Text('Waste Breakdown', style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: AppSpace.md - 2),
                    if (widget.logs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                        child: Center(
                          child: Text('No scans yet — start recycling to see your breakdown!',
                              textAlign: TextAlign.center, style: t.bodySmall),
                        ),
                      )
                    else ...[
                      _wasteBar('Biodegradable', bio, widget.logs.length, c.bio, wasteIcon('Biodegradable')),
                      const SizedBox(height: AppSpace.sm - 2),
                      _wasteBar('Recyclable',    rec, widget.logs.length, c.rec, wasteIcon('Recyclable')),
                      const SizedBox(height: AppSpace.sm - 2),
                      _wasteBar('Residual',      res, widget.logs.length, c.res, wasteIcon('Residual')),
                    ],
                  ]),
                ),
              ),
            ),

            // ── Account info / edit form ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: cardDecoration(context),
                  child: Form(
                    key: _formKey,
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xs),
                        child: Row(children: [
                          IconBadge(icon: Icons.person_outline_rounded, color: c.primary, size: 34),
                          const SizedBox(width: AppSpace.sm - 2),
                          Text('Account Info', style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                        ]),
                      ),
                      const Divider(height: 1),
                      TextFormField(
                        controller: _userCtrl,
                        enabled: _editing,
                        style: t.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline_rounded,
                              color: _editing ? c.primary : c.textTertiary, size: 20),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.md - 2),
                          filled: _editing,
                          fillColor: _editing ? c.primaryContainer.withValues(alpha: 0.4) : null,
                        ),
                        validator: (v) => v!.trim().length < 3 ? 'Min 3 characters' : null,
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.md - 2),
                        child: Row(children: [
                          Icon(Icons.email_outlined, color: c.textTertiary, size: 20),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(child: Text(widget.user.email,
                              style: t.bodyMedium!.copyWith(color: c.textSecondary), overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),

            if (_editing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md - 2, AppSpace.lg, 0),
                  child: AppButton(label: 'Save Changes', height: 54, loading: _saving, onPressed: _save),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.navClearance)),
          ],
        )),
      ),
    );
  }

  String _monthYear(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.year}';
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _statPill(String value, String label, IconData icon, Color color) =>
      Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: AppSpace.xs - 2),
        Text(value, style: context.text.titleSmall!.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: context.text.labelSmall),
      ]);

  Widget _divider() => Container(width: 1, height: 40, color: context.colors.border);

  Widget _wasteBar(String label, int count, int total, Color color, IconData icon) {
    final c = context.colors;
    final pct = total == 0 ? 0.0 : count / total;
    return Row(children: [
      IconBadge(icon: icon, color: color, size: 28),
      const SizedBox(width: AppSpace.sm - 2),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: context.text.labelMedium!.copyWith(fontWeight: FontWeight.w500)),
          Text('$count', style: context.text.labelMedium!.copyWith(color: c.ink(color), fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: AppSpace.xxs),
        AnimatedBar(progress: pct, color: color, height: 6),
      ])),
    ]);
  }
}

// ── Dashed ring avatar ────────────────────────────────────────────────────────
class _DashedAvatar extends StatelessWidget {
  final String initial;
  final String rankIcon;
  final Color rankColor;
  final String? heroTag;
  const _DashedAvatar({required this.initial, required this.rankIcon, required this.rankColor, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CustomPaint(
          painter: _DashedCirclePainter(color: c.primary),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xs - 2),
            child: _hero(Container(
              width: 88, height: 88,
              decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
              child: Center(
                child: Text(initial, style: AppType.numeral.copyWith(color: c.onPrimaryContainer, fontSize: 36)),
              ),
            )),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpace.xxs),
          decoration: BoxDecoration(
            color: rankColor,
            shape: BoxShape.circle,
            border: Border.all(color: c.background, width: 2),
          ),
          child: Text(rankIcon, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

extension on _DashedAvatar {
  Widget _hero(Widget child) =>
      heroTag == null ? child : Hero(tag: heroTag!, flightShuttleBuilder: heroMaterialFlight, child: child);
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    const dashCount = 24;
    const dashAngle = 3.14159 * 2 / dashCount;
    const gapFraction = 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      const sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
