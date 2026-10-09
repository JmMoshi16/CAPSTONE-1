import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../core/theme.dart';
import '../../core/gamification.dart';
import '../../widgets/eco_animations.dart';
import '../../widgets/ui.dart';
import 'qr_scanner_screen.dart';
import 'rewards_screen.dart';
import 'impact_screen.dart';
import 'scan_history_screen.dart';
import 'customer_profile_screen.dart';
import 'leaderboard_screen.dart';
import 'badges_screen.dart';

part 'customer_home_widgets.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedIndex = 0;
  UserModel? _user;
  bool _scannerOpen = false;
  bool _loadError = false;
  bool _offline = false;   // last refresh failed; showing the previous data
  List<WasteLog> _logs = [];
  List<Reward> _rewards = [];
  List<Redemption> _redemptions = [];
  int _myRank = 0;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loadError = false);
    try {
      final user = await FirebaseService.getCurrentUser()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      final uid = FirebaseService.currentUid;
      if (uid == null || user == null) {
        if (mounted) setState(() => _loadError = true);
        return;
      }
      // A slow or failed refresh keeps the last data and says so, instead of showing zeros as real.
      List<Object>? results;
      try {
        results = await Future.wait<Object>([
          FirebaseService.getUserWasteLogs(uid),
          FirebaseService.getRewards(),
          FirebaseService.getUserRank(uid),
          FirebaseService.getUserRedemptions(uid),
        ]).timeout(const Duration(seconds: 10));
      } catch (_) {
        results = null;
      }
      if (mounted) {
        setState(() {
        _user = user;
        _offline = results == null;
        if (results != null) {
          _logs = results[0] as List<WasteLog>;
          _rewards = results[1] as List<Reward>;
          _myRank = results[2] as int;
          _redemptions = results[3] as List<Redemption>;
        }
        _loadError = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError) {
      return Scaffold(
        body: ErrorState(
          title: 'Could not load data',
          message: 'Check your connection and try again',
          onRetry: _loadData,
        ),
      );
    }
    if (_user == null) {
      return const Scaffold(body: Center(child: EcoLoader(size: 72)));
    }

    final screens = [
      _HomeTab(
        user: _user!, logs: _logs, rewards: _rewards, myRank: _myRank,
        redemptions: _redemptions,
        offline: _offline,
        onScan: _openScanner,
        onRewards:     () => setState(() => _selectedIndex = 1),
        onImpact:      () => setState(() => _selectedIndex = 2),
        onHistory: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ScanHistoryScreen(
              logs: _logs,
              onRefresh: () async { await _loadData(); return _logs; },
              onScan: _openScanner,
            ))).then((_) => _loadData()),
        onLeaderboard: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => LeaderboardScreen(currentUid: _user!.uid))),
        onBadges: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => BadgesScreen(user: _user!))),
        onRefresh: _loadData,
      ),
      RewardsScreen(user: _user!, rewards: _rewards, onRedeemed: _loadData),
      ImpactScreen(logs: _logs, onRefresh: _loadData, onScan: _openScanner),
      CustomerProfileScreen(user: _user!, logs: _logs, onUpdated: _loadData),
    ];

    return Scaffold(
      extendBody: true,
      body: FadeThroughSwitcher(child: KeyedSubtree(key: ValueKey(_selectedIndex), child: screens[_selectedIndex])),
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        onScan: _openScanner,
      ),
    );
  }

  Future<void> _openScanner() async {
    if (_scannerOpen || _user == null) return;
    _scannerOpen = true;
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => QRScannerScreen(userId: _user!.uid, username: _user!.username)));
    _loadData();
    _scannerOpen = false;
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final UserModel user;
  final List<WasteLog> logs;
  final List<Reward> rewards;
  final List<Redemption> redemptions;
  final int myRank;
  final bool offline;
  final VoidCallback onScan;
  final VoidCallback onRewards;
  final VoidCallback onImpact;
  final VoidCallback onHistory;
  final VoidCallback onLeaderboard;
  final VoidCallback onBadges;
  final Future<void> Function() onRefresh;

  const _HomeTab({
    required this.user, required this.logs, required this.rewards,
    required this.redemptions,
    required this.myRank,
    required this.offline,
    required this.onScan, required this.onRewards, required this.onImpact,
    required this.onHistory, required this.onLeaderboard, required this.onBadges,
    required this.onRefresh,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with TickerProviderStateMixin {
  late AnimationController _staggerCtrl;
  late AnimationController _pointsCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pointsAnim;
  late Animation<double> _pulseAnim;

  // 6 staggered sections
  final List<Animation<double>> _fadeAnims = [];
  final List<Animation<Offset>> _slideAnims = [];

  @override
  void initState() {
    super.initState();

    _staggerCtrl = AnimationController(vsync: this, duration: AppMotion.slow * 2);

    // Build 6 staggered fade+slide animations with overlapping intervals
    final intervals = [
      const Interval(0.0, 0.4),
      const Interval(0.1, 0.5),
      const Interval(0.2, 0.6),
      const Interval(0.35, 0.7),
      const Interval(0.5, 0.85),
      const Interval(0.65, 1.0),
    ];
    for (final iv in intervals) {
      _fadeAnims.add(CurvedAnimation(parent: _staggerCtrl, curve: iv));
      _slideAnims.add(Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
          .animate(CurvedAnimation(parent: _staggerCtrl, curve: Interval(iv.begin, iv.end, curve: AppMotion.standard))));
    }

    // Points count-up
    _pointsCtrl = AnimationController(vsync: this, duration: AppMotion.countUp);
    _pointsAnim = Tween<double>(begin: 0, end: widget.user.points.toDouble())
        .animate(CurvedAnimation(parent: _pointsCtrl, curve: AppMotion.standard));

    // Pulse for scan button
    _pulseCtrl = AnimationController(vsync: this, duration: AppMotion.ambient)
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Start animations
    _staggerCtrl.forward();
    Future.delayed(AppMotion.medium, () {
      if (mounted) _pointsCtrl.forward();
    });
  }

  @override
  void didUpdateWidget(_HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.points != widget.user.points) {
      _pointsAnim = Tween<double>(begin: oldWidget.user.points.toDouble(), end: widget.user.points.toDouble())
          .animate(CurvedAnimation(parent: _pointsCtrl, curve: AppMotion.standard));
      _pointsCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _pointsCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _showNotificationsSheet(BuildContext context) {
    final c = context.colors;
    // Build flat notification list
    final items = <_NotifItem>[];

    // Redemptions first — each becomes one notification row
    for (final r in widget.redemptions) {
      final isPending = r.status == 'pending';
      final isExpired = isPending && DateTime.now().isAfter(r.expiresAt);
      items.add(_NotifItem(
        icon: isExpired
            ? Icons.timer_off_rounded
            : isPending
                ? Icons.confirmation_number_rounded
                : Icons.check_circle_rounded,
        iconColor: isExpired ? c.danger : isPending ? c.warning : c.success,
        title: r.rewardTitle,
        subtitle: isPending && !isExpired
            ? 'Code: ${r.redemptionCode}  •  Tap to copy'
            : isExpired
                ? 'Expired on ${_fmtDate(r.expiresAt)}'
                : 'Claimed on ${_fmtDate(r.redeemedAt)}',
        time: _fmtDate(r.redeemedAt),
        isUnread: isPending && !isExpired,
        onTap: (isPending && !isExpired)
            ? () {
                Clipboard.setData(ClipboardData(text: r.redemptionCode));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Code ${r.redemptionCode} copied!'),
                  backgroundColor: c.success,
                ));
              }
            : null,
      ));
    }

    // Activity notifications
    if (widget.user.scanCount > 0) {
      items.add(_NotifItem(
        icon: Icons.recycling_rounded, iconColor: c.success,
        title: 'Points Credited',
        subtitle: '${widget.user.scanCount} scan${widget.user.scanCount > 1 ? "s" : ""} recorded. Keep recycling!',
        time: _lastScanLabel(widget.user.lastScanDate), isUnread: false, onTap: null,
      ));
    }
    if (widget.user.badges.isNotEmpty) {
      items.add(_NotifItem(
        icon: Icons.military_tech_rounded, iconColor: c.gold,
        title: 'Badge Unlocked',
        subtitle: 'You earned ${widget.user.badges.length} badge${widget.user.badges.length > 1 ? "s" : ""}. Check your collection!',
        time: '', isUnread: false, onTap: null,
      ));
    }
    if (widget.myRank > 0 && widget.myRank <= 10) {
      items.add(_NotifItem(
        icon: Icons.leaderboard_rounded, iconColor: c.gold,
        title: 'Top 10 Leaderboard',
        subtitle: "You're ranked #${widget.myRank} on the leaderboard!",
        time: 'Now', isUnread: false, onTap: null,
      ));
    }
    final streak = effectiveStreak(widget.user.streak, widget.user.lastScanDate, DateTime.now());
    if (streak > 2) {
      items.add(_NotifItem(
        icon: Icons.local_fire_department_rounded, iconColor: c.warning,
        title: '$streak-Day Streak',
        subtitle: 'Amazing! Keep recycling every day.',
        time: 'Now', isUnread: false, onTap: null,
      ));
    }
    if (items.isEmpty) {
      items.add(_NotifItem(
        icon: Icons.eco_rounded, iconColor: c.success,
        title: 'Welcome to ECOReward!',
        subtitle: 'Start scanning waste QR codes to earn points and rewards.',
        time: 'Now', isUnread: false, onTap: null,
      ));
    }

    final unread = items.where((e) => e.isUnread).length;
    AppSheet.show(
      context,
      title: 'Notifications',
      initialSize: 0.6,
      maxSize: 0.85,
      trailing: unread > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm - 2, vertical: AppSpace.xxs),
              decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadius.all(AppRadius.pill)),
              child: Text('$unread new',
                  style: context.text.labelMedium!.copyWith(color: c.onPrimaryContainer)),
            )
          : null,
      builder: (ctx, scroll) => ListView.separated(
        controller: scroll,
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 68, endIndent: AppSpace.md),
        itemBuilder: (_, i) {
          final n = items[i];
          final t = ctx.text;
          return InkWell(
            onTap: n.onTap,
            child: Container(
              color: n.isUnread ? c.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.md - 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: n.iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(n.icon, color: n.iconColor, size: 20),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(n.title, style: t.titleSmall!.copyWith(
                        fontWeight: n.isUnread ? FontWeight.w700 : FontWeight.w600))),
                    Text(n.time, style: t.labelSmall!.copyWith(
                        color: n.isUnread ? c.primary : c.textTertiary)),
                  ]),
                  const SizedBox(height: 3),
                  Text(n.subtitle, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ])),
                if (n.isUnread) ...[
                  const SizedBox(width: AppSpace.xs),
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(top: AppSpace.xxs),
                    decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  /// When the last scan happened ("Today", "Yesterday", "Oct 9"); the old label always said "Today".
  String _lastScanLabel(String? yyyyMmDd) {
    final d = yyyyMmDd == null ? null : DateTime.tryParse(yyyyMmDd);
    if (d == null) return '';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return _fmtDate(d);
  }

  String _fmtDate(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month - 1]} ${dt.day}';
  }
  Widget _fadeSlide(int index, Widget child) => FadeTransition(
        opacity: _fadeAnims[index],
        child: SlideTransition(position: _slideAnims[index], child: child),
      );


  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final bio = widget.logs.where((l) => l.wasteType == 'Biodegradable').length;
    final rec = widget.logs.where((l) => l.wasteType == 'Recyclable').length;
    final co2 = (rec * 0.5 + bio * 0.3).toStringAsFixed(1);
    final recent = widget.logs.take(3).toList();
    final now = DateTime.now();
    final lifetime = widget.user.lifetimePoints;
    final rank = getRank(lifetime);
    final level = getLevel(lifetime);
    final streak = effectiveStreak(widget.user.streak, widget.user.lastScanDate, now);
    final scansThisWeek = scansInLastDays(widget.logs.map((l) => l.timestamp), now);

    return RefreshIndicator(
      color: c.primary,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Hero Header (with points embedded) ───────────────────────────
          SliverToBoxAdapter(
            child: _fadeSlide(0, _HeroHeaderCard(
              user: widget.user,
              myRank: widget.myRank,
              lifetimePoints: lifetime,
              pointsAnim: _pointsAnim,
              streak: streak,
              onBell: () => _showNotificationsSheet(context),
              onProfile: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => CustomerProfileScreen(user: widget.user, logs: widget.logs, onUpdated: widget.onRefresh))),
              pendingRedemptions: widget.redemptions.where((r) => r.status == 'pending' && !DateTime.now().isAfter(r.expiresAt)).length,
            )),
          ),

          if (widget.offline)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                child: _OfflineBanner(onRetry: widget.onRefresh),
              ),
            ),

          // ── Progress bars + Buttons (no box, direct on bg) ───────────────
          SliverToBoxAdapter(
            child: _fadeSlide(1, Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Rank bar
                _ProgressBarRow(
                  leftLabel: '${rank.icon}  ${rank.label}',
                  rightLabel: rank.next != null
                      ? '${rank.nextPts - lifetime} pts to ${rank.next}'
                      : 'Max Rank',
                  progress: rankProgress(lifetime),
                  color: rank.color,
                ),
                const SizedBox(height: AppSpace.sm),
                // Level bar
                _ProgressBarRow(
                  leftLabel: '${level.emoji}  ${level.title}  Lv ${level.level}',
                  rightLabel: ptsToNextLevel(lifetime) == 0
                      ? '🎉 Max Level'
                      : '${ptsToNextLevel(lifetime)} pts to next',
                  progress: levelProgress(lifetime),
                  color: level.color,
                ),
                const SizedBox(height: AppSpace.lg),
                // Scan button
                ScaleTransition(
                  scale: _pulseAnim,
                  child: AppButton(
                    label: 'Scan QR Code',
                    icon: Icons.qr_code_scanner_rounded,
                    height: 56,
                    onPressed: widget.onScan,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                // Rewards button
                AppButton.secondary(
                  label: 'Claim Rewards',
                  icon: Icons.card_giftcard_rounded,
                  onPressed: widget.onRewards,
                ),
              ]),
            )),
          ),


          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.lg)),

          // ── Progress Stats ──
          SliverToBoxAdapter(
            child: _fadeSlide(2, Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHeader(
                  title: 'Your Progress',
                  subtitle: 'Tap a card for details',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm - 2, vertical: AppSpace.xxs),
                    decoration: BoxDecoration(
                      color: c.primaryContainer,
                      borderRadius: AppRadius.all(AppRadius.pill),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_fire_department_rounded, color: c.onPrimaryContainer, size: 14),
                      const SizedBox(width: AppSpace.xxs),
                      Text(
                        streak > 0 ? '$streak-day streak!' : 'Start your streak',
                        style: t.labelSmall!.copyWith(color: c.onPrimaryContainer),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                // Stat cards
                Row(children: [
                  Expanded(child: StatCard(emoji: '🔥', value: '${streak}d', label: 'streak',
                      accent: c.warning, valueColor: streak > 0 ? null : c.textTertiary,
                      onTap: widget.onLeaderboard)),
                  const SizedBox(width: AppSpace.sm - 2),
                  Expanded(child: StatCard(emoji: '🏆', value: widget.myRank > 0 ? '#${widget.myRank}' : '--',
                      label: 'rank', accent: c.gold, valueColor: widget.myRank > 0 ? null : c.textTertiary,
                      onTap: widget.onLeaderboard)),
                  const SizedBox(width: AppSpace.sm - 2),
                  Expanded(child: StatCard(emoji: '🏅', value: '${widget.user.badges.length}', label: 'badges',
                      accent: c.gold, valueColor: widget.user.badges.isNotEmpty ? null : c.textTertiary,
                      onTap: widget.onBadges)),
                  const SizedBox(width: AppSpace.sm - 2),
                  Expanded(child: StatCard(emoji: '♻️', value: '${widget.user.scanCount}', label: 'scans',
                      accent: c.success, onTap: widget.onImpact)),
                ]),
                const SizedBox(height: AppSpace.sm),
                // Weekly scan goal bar
                _WeeklyGoalBar(scanCount: scansThisWeek, weeklyGoal: 10),
                if (widget.user.scanCount == 0) ...[
                  const SizedBox(height: AppSpace.sm - 2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xxs, AppSpace.xxs, AppSpace.xxs),
                    decoration: BoxDecoration(
                      color: c.primaryContainer,
                      borderRadius: AppRadius.all(AppRadius.lg - 2),
                      border: Border.all(color: c.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const ExcludeSemantics(child: Text('🌱', style: TextStyle(fontSize: 18))),
                      const SizedBox(width: AppSpace.sm - 2),
                      Expanded(child: Text('Scan your first QR to earn badges and start your streak!',
                          style: t.labelMedium!.copyWith(color: c.onPrimaryContainer, fontWeight: FontWeight.w500))),
                      Tap(label: 'Scan your first QR code',
                        onTap: widget.onScan,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
                          decoration: BoxDecoration(color: c.primary, borderRadius: AppRadius.all(AppRadius.sm + 2)),
                          child: Text('Scan', style: t.labelMedium!.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ),
                ],
              ]),
            )),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.lg)),

          // ── Quick Access Grid ──
          SliverToBoxAdapter(
            child: _fadeSlide(3, Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionHeader(title: 'Quick Access'),
                const SizedBox(height: AppSpace.sm),
                Row(children: [
                  Expanded(child: _gridTile(onTap: widget.onRewards, icon: Icons.coffee_rounded, color: c.coffee, label: 'Coffee rewards', subtitle: '${widget.rewards.where((r) => r.category == 'Coffee').length} available')),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: _gridTile(onTap: widget.onRewards, icon: Icons.local_offer_rounded, color: const Color(0xFF7C4DFF), label: 'Eco Discount', subtitle: '${widget.rewards.where((r) => r.category == 'Discount').length} available')),
                ]),
                const SizedBox(height: AppSpace.sm),
                Row(children: [
                  Expanded(child: _gridTile(onTap: widget.onHistory, icon: Icons.history_rounded, color: c.info, label: 'Scan History', subtitle: '${widget.logs.length} total scans')),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: _gridTile(onTap: widget.onImpact, icon: Icons.eco_rounded, color: c.success, label: 'Your impact', subtitle: '${co2}kg CO₂ reduced')),
                ]),
              ]),
            )),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.sm)),

          // ── Recent Activity ──
          if (recent.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _fadeSlide(4, Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: SectionHeader(title: 'Recent Activity', actionLabel: 'See All', onAction: widget.onHistory),
              )),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xs)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _fadeSlide(5, _activityTile(recent[i])),
                  childCount: recent.length,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.navClearance)),
        ],
      ),
    );
  }

  Widget _gridTile({required VoidCallback onTap, required IconData icon, required Color color, required String label, required String subtitle}) {
    final c = context.colors;
    return PressScale(
      onTap: onTap,
      label: '$label, $subtitle',
      scale: 0.95,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: cardDecoration(context, radius: AppRadius.xl + 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          IconBadge(icon: icon, color: c.ink(color)),
          const SizedBox(height: AppSpace.sm),
          Text(label, style: context.text.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, style: context.text.bodySmall),
        ]),
      ),
    );
  }

  Widget _activityTile(WasteLog log) {
    final c = context.colors;
    final color = c.waste(log.wasteType);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.sm - 2),
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(context, radius: AppRadius.lg + 2),
      child: IntrinsicHeight(
        child: Row(children: [
          // Colored left accent bar
          Container(width: 4, color: color),
          const SizedBox(width: AppSpace.sm),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm - 1),
            child: IconBadge(icon: wasteIcon(log.wasteType), color: color, size: 38),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(log.wasteType, style: context.text.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
            Text(DateFormat('MMM d · h:mm a').format(log.timestamp), style: context.text.bodySmall),
          ])),
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.md - 2),
            child: Center(child: PointsPill('+${log.pointsAwarded} pts')),
          ),
        ]),
      ),
    );
  }
}
