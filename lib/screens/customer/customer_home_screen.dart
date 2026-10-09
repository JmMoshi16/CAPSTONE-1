import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'info_sheets.dart';

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
      // The real layout in grey, with the brand loader in the header (first launch / cold start).
      return const Scaffold(body: HomeSkeleton(center: EcoLoader(size: 72, semanticLabel: 'Loading')));
    }

    final screens = [
      _HomeTab(
        user: _user!, logs: _logs, rewards: _rewards, myRank: _myRank,
        redemptions: _redemptions,
        offline: _offline,
        onScan: _openScanner,
        onRewards:     () => _openRewards(),
        onRewardsCategory: (cat) => _openRewards(category: cat),
        onMyCodes: () => _openRewards(myCodes: true),
        onImpact:      () => setState(() => _selectedIndex = 2),
        onHistory: () => _openHistory(),
        onLeaderboard: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => LeaderboardScreen(currentUid: _user!.uid, me: _user))),
        onBadges: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => BadgesScreen(user: _user!))),
        onRefresh: _loadData,
      ),
      RewardsScreen(key: _rewardsKey, user: _user!, rewards: _rewards, onRedeemed: _loadData),
      ImpactScreen(logs: _logs, onRefresh: _loadData, onScan: _openScanner,
          onOpenHistory: (type) => _openHistory(filter: type)),
      CustomerProfileScreen(user: _user!, logs: _logs, onUpdated: _loadData, onOpenRewards: () => _openRewards()),
    ];

    return Scaffold(
      extendBody: true,
      body: FadeIndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        onScan: _openScanner,
        onScanWithLight: () => _openScanner(torch: true),
      ),
    );
  }

  final _rewardsKey = GlobalKey<RewardsScreenState>();

  /// Rewards tab, optionally pre-filtered to a category or showing My Codes.
  void _openRewards({String? category, bool myCodes = false}) {
    setState(() => _selectedIndex = 1);
    // The tab may be built for the first time in this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rewards = _rewardsKey.currentState;
      if (rewards == null) return;
      if (myCodes) {
        rewards.showMyCodes();
      } else {
        rewards.showCategory(category ?? 'All');
      }
    });
  }

  void _openHistory({String filter = 'All'}) => Navigator.push(context, MaterialPageRoute(
      builder: (_) => ScanHistoryScreen(
        logs: _logs,
        initialFilter: filter,
        onRefresh: () async { await _loadData(); return _logs; },
        onScan: _openScanner,
      ))).then((_) => _loadData());

  Future<void> _openScanner({bool torch = false}) async {
    if (_scannerOpen || _user == null) return;
    _scannerOpen = true;
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => QRScannerScreen(
            userId: _user!.uid, username: _user!.username, lifetimeBefore: _user!.lifetimePoints,
            pointsBefore: _user!.points, startWithTorch: torch)));
    _loadData();
    _scannerOpen = false;
  }
}

/// Home tab and nav bar without Firebase, for layout tests.
@visibleForTesting
Widget homeTabPreview({
  required UserModel user,
  List<WasteLog> logs = const [],
  List<Reward> rewards = const [],
  List<Redemption> redemptions = const [],
  int myRank = 0,
  bool offline = false,
}) =>
    Scaffold(
      extendBody: true,
      body: _HomeTab(
        user: user, logs: logs, rewards: rewards, redemptions: redemptions, myRank: myRank, offline: offline,
        onScan: () {}, onRewards: () {}, onRewardsCategory: (_) {}, onMyCodes: () {},
        onImpact: () {}, onHistory: () {}, onLeaderboard: () {}, onBadges: () {},
        onRefresh: () async {},
      ),
      bottomNavigationBar: _FloatingNavBar(selectedIndex: 0, onTap: (_) {}, onScan: () {}, onScanWithLight: () {}),
    );

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
  final ValueChanged<String> onRewardsCategory;
  final VoidCallback onMyCodes;
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
    required this.onScan, required this.onRewards, required this.onRewardsCategory, required this.onMyCodes,
    required this.onImpact,
    required this.onHistory, required this.onLeaderboard, required this.onBadges,
    required this.onRefresh,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with TickerProviderStateMixin {
  late AnimationController _staggerCtrl;
  late AnimationController _pulseCtrl;
  final _scroll = ScrollController();   // drives the header parallax
  /// Entrance animations and count-ups play on the first visit of the session only.
  late final bool _firstLoad = AppMotion.firstTime('home');
  late Animation<double> _pulseAnim;

  // 6 staggered sections
  final List<Animation<double>> _fadeAnims = [];
  final List<Animation<Offset>> _slideAnims = [];

  @override
  void initState() {
    super.initState();

    // 800 ms in total, but each section moves for at most 320 ms (overlapping 40 % intervals).
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

    // Pulse for scan button
    _pulseCtrl = AnimationController(vsync: this, duration: AppMotion.ambient)
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Start animations
    if (_firstLoad) {
      _staggerCtrl.forward();
    } else {
      _staggerCtrl.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: no slide-in and no pulsing; content simply appears.
    if (AppMotion.reduced(context)) {
      _staggerCtrl.value = 1;
      _pulseCtrl
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _pulseCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static const _dismissedKey = 'dismissed_notifications';

  Future<void> _showNotificationsSheet(BuildContext context) async {
    // Dismissed rows are remembered on this phone only (nothing is written to Firestore).
    var dismissed = <String>{};
    try {
      dismissed = (await SharedPreferences.getInstance()).getStringList(_dismissedKey)?.toSet() ?? {};
    } catch (_) {}
    if (!context.mounted) return;
    final c = context.colors;
    // Build flat notification list
    final items = <_NotifItem>[];

    // Redemptions first — each becomes one notification row
    for (final r in widget.redemptions) {
      final isPending = r.status == 'pending';
      final isExpired = isPending && DateTime.now().isAfter(r.expiresAt);
      items.add(_NotifItem(
        id: 'redemption-${r.id}-${r.status}-${isExpired ? 'expired' : 'live'}',
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
        // Pending: copy the code (sheet stays open). Expired/claimed: open My Codes.
        closes: !(isPending && !isExpired),
        onTap: (isPending && !isExpired)
            ? () {
                Clipboard.setData(ClipboardData(text: r.redemptionCode));
                AppSnackbar.success(context, 'Code ${r.redemptionCode} copied');
              }
            : widget.onMyCodes,
      ));
    }

    // Activity notifications
    if (widget.user.scanCount > 0) {
      items.add(_NotifItem(
        icon: Icons.recycling_rounded, iconColor: c.success,
        id: 'points-${widget.user.scanCount}',
        title: 'Points Credited',
        subtitle: '${widget.user.scanCount} scan${widget.user.scanCount > 1 ? "s" : ""} recorded. Keep recycling!',
        time: _lastScanLabel(widget.user.lastScanDate), isUnread: false, onTap: widget.onHistory,
      ));
    }
    if (widget.user.badges.isNotEmpty) {
      items.add(_NotifItem(
        icon: Icons.military_tech_rounded, iconColor: c.gold,
        id: 'badges-${widget.user.badges.length}',
        title: 'Badge Unlocked',
        subtitle: 'You earned ${widget.user.badges.length} badge${widget.user.badges.length > 1 ? "s" : ""}. Check your collection!',
        time: '', isUnread: false, onTap: widget.onBadges,
      ));
    }
    if (widget.myRank > 0 && widget.myRank <= 10) {
      items.add(_NotifItem(
        icon: Icons.leaderboard_rounded, iconColor: c.gold,
        id: 'rank-${widget.myRank}',
        title: 'Top 10 Leaderboard',
        subtitle: "You're ranked #${widget.myRank} on the leaderboard!",
        time: 'Now', isUnread: false, onTap: widget.onLeaderboard,
      ));
    }
    final streak = effectiveStreak(widget.user.streak, widget.user.lastScanDate, DateTime.now());
    if (streak > 2) {
      items.add(_NotifItem(
        icon: Icons.local_fire_department_rounded, iconColor: c.warning,
        id: 'streak-$streak',
        title: '$streak-Day Streak',
        subtitle: 'Amazing! Keep recycling every day.',
        time: 'Now', isUnread: false, onTap: () => showStreakSheet(context, streak: streak, onScan: widget.onScan),
      ));
    }
    if (items.isEmpty) {
      items.add(_NotifItem(
        icon: Icons.eco_rounded, iconColor: c.success,
        id: 'welcome',
        title: 'Welcome to ECOReward!',
        subtitle: 'Start scanning waste QR codes to earn points and rewards.',
        time: 'Now', isUnread: false, onTap: widget.onScan,
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
      builder: (ctx, scroll) => StatefulBuilder(builder: (ctx, setSheet) {
        final c = ctx.colors;
        final visible = items.where((n) => !dismissed.contains(n.id)).toList();
        final fresh = visible.where((n) => n.isUnread).toList();
        final earlier = visible.where((n) => !n.isUnread).toList();
        if (visible.isEmpty) {
          return const EmptyState(icon: Icons.notifications_none_rounded, title: "You're all caught up", dense: true);
        }

        Widget group(String label) => Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xs),
              child: Semantics(header: true, child: Text(label.toUpperCase(),
                  style: ctx.text.labelSmall!.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800))),
            );

        // Swipe either way to dismiss (remembered on this phone).
        Widget row(_NotifItem n) => Dismissible(
              key: ValueKey(n.id),
              background: _dismissBackground(ctx, Alignment.centerLeft),
              secondaryBackground: _dismissBackground(ctx, Alignment.centerRight),
              onDismissed: (_) async {
                AppHaptics.tap();
                setSheet(() => dismissed.add(n.id));
                try {
                  await (await SharedPreferences.getInstance()).setStringList(_dismissedKey, dismissed.toList());
                } catch (_) {}
              },
              child: _notifRow(ctx, n),
            );

        return ListView(controller: scroll, children: [
          if (fresh.isNotEmpty) ...[group('New'), ...fresh.map(row)],
          if (earlier.isNotEmpty) ...[group('Earlier'), ...earlier.map(row)],
          Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Text('Swipe a notification sideways to dismiss it.',
                textAlign: TextAlign.center, style: ctx.text.labelSmall!.copyWith(color: c.textTertiary)),
          ),
        ]);
      }),
    );
  }

  /// When the last scan happened ("Today", "Yesterday", "Oct 9"); the old label always said "Today".
  Widget _dismissBackground(BuildContext ctx, Alignment align) => Container(
        color: ctx.colors.surfaceAlt,
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.done_all_rounded, color: ctx.colors.textSecondary),
          const SizedBox(width: AppSpace.xs),
          Text('Dismiss', style: ctx.text.labelMedium!.copyWith(color: ctx.colors.textSecondary)),
        ]),
      );

  Widget _notifRow(BuildContext ctx, _NotifItem n) {
    final c = ctx.colors;
    final t = ctx.text;
    return InkWell(
      onTap: n.onTap == null ? null : () {
        AppHaptics.tap();
        if (n.closes) Navigator.pop(ctx);
        n.onTap!();
      },
      child: Container(
        color: n.isUnread ? c.primaryContainer.withValues(alpha: 0.5) : c.surface,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.md - 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: n.iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(n.icon, color: n.iconColor, size: 20),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(n.title, style: t.titleSmall!.copyWith(
                  fontWeight: n.isUnread ? FontWeight.w700 : FontWeight.w600))),
              Text(n.time, style: t.labelSmall!.copyWith(color: n.isUnread ? c.primary : c.textTertiary)),
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
  }

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
    // Display only: what the scan history already shows, summed over the last 7 days.
    final weekPoints = widget.logs
        .where((l) => now.difference(l.timestamp).inDays < 7)
        .fold(0, (s, l) => s + l.pointsAwarded);

    return RefreshIndicator(
      color: c.primary,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Hero Header (with points embedded) ───────────────────────────
          SliverToBoxAdapter(
            child: _fadeSlide(0, _HeroHeaderCard(
              scroll: _scroll,
              user: widget.user,
              myRank: widget.myRank,
              lifetimePoints: lifetime,
              points: widget.user.points,
              countFromZero: _firstLoad,
              streak: streak,
              onBell: () => _showNotificationsSheet(context),
              onRankInfo: () => showRankLevelSheet(context, lifetimePoints: lifetime),
              onLeaderboard: widget.onLeaderboard,
              onProfile: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => CustomerProfileScreen(
                      user: widget.user, logs: widget.logs, onUpdated: widget.onRefresh, heroAvatar: true,
                      onOpenRewards: () {
                        Navigator.pop(context);
                        widget.onRewards();
                      }))),
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
                // Rank and level rings: fill on first load, then old -> new after a scan.
                Row(children: [
                  Expanded(child: _RingCard(
                    progress: rankProgress(lifetime),
                    color: rank.color,
                    center: Text(rank.icon, style: const TextStyle(fontSize: 22)),
                    title: '${rank.label} rank',
                    subtitle: rank.next != null ? '${rank.nextPts - lifetime} pts to ${rank.next}' : 'Top rank reached',
                    fromZero: _firstLoad,
                    onTap: () => showRankLevelSheet(context, lifetimePoints: lifetime),
                  )),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: _RingCard(
                    progress: levelProgress(lifetime),
                    color: level.color,
                    center: Text('${level.level}', style: AppType.numeral.copyWith(fontSize: 22, color: c.ink(level.color))),
                    title: 'Lv ${level.level} ${level.title}',
                    subtitle: ptsToNextLevel(lifetime) == 0 ? 'Max level' : '${ptsToNextLevel(lifetime)} pts to next',
                    fromZero: _firstLoad,
                    onTap: () => showRankLevelSheet(context, lifetimePoints: lifetime),
                  )),
                ]),
                const SizedBox(height: AppSpace.lg),
                // Scan button
                RepaintBoundary(child: ScaleTransition(
                  scale: _pulseAnim,
                  child: GlowButton(
                    label: 'Scan QR Code',
                    icon: Icons.qr_code_scanner_rounded,
                    onPressed: widget.onScan,
                  ),
                )),
                const SizedBox(height: AppSpace.sm),
                // Rewards button
                AppButton.secondary(
                  label: 'Redeem rewards',
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
                  subtitle: 'Tap a card for details · swipe for more',
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
                // Stat cards: a swipeable row (the fifth card peeks in to invite the swipe).
                SizedBox(
                  height: 116 * AppLayout.textScale(context).clamp(1.0, 1.6),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      for (final card in [
                        StatCard(leading: _Flame(active: streak > 0), value: '${streak}d', count: streak, suffix: 'd',
                            label: streak >= 3 ? 'streak · ${streakMultiplier(streak) == 2 ? '2' : '1.5'}× bonus' : 'day streak',
                            accent: c.warning, valueColor: streak > 0 ? null : c.textTertiary,
                            onTap: () => showStreakSheet(context, streak: streak, onScan: widget.onScan)),
                        StatCard(emoji: '⭐', value: '$weekPoints', count: weekPoints, label: 'pts this week',
                            accent: c.primary, onTap: widget.onHistory),
                        StatCard(emoji: '🏆', value: widget.myRank > 0 ? '#${widget.myRank}' : '--',
                            label: 'leaderboard', accent: c.gold, valueColor: widget.myRank > 0 ? null : c.textTertiary,
                            onTap: widget.onLeaderboard),
                        StatCard(emoji: '🏅', value: '${widget.user.badges.length}', count: widget.user.badges.length, label: 'badges',
                            accent: c.gold, valueColor: widget.user.badges.isNotEmpty ? null : c.textTertiary,
                            onTap: widget.onBadges),
                        StatCard(emoji: '♻️', value: '${widget.user.scanCount}', count: widget.user.scanCount, label: 'total scans',
                            accent: c.success, onTap: widget.onImpact),
                      ]) ...[
                        SizedBox(width: 124 * AppLayout.textScale(context).clamp(1.0, 1.4), child: card),
                        const SizedBox(width: AppSpace.sm - 2),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                // Weekly scan goal bar
                _WeeklyGoalBar(scanCount: scansThisWeek, weeklyGoal: 10, fromZero: _firstLoad),
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
                  Expanded(child: _gridTile(onTap: () => widget.onRewardsCategory('Coffee'), icon: Icons.coffee_rounded, color: c.coffee, label: 'Coffee rewards', subtitle: '${widget.rewards.where((r) => r.category == 'Coffee').length} available')),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: _gridTile(onTap: () => widget.onRewardsCategory('Discount'), icon: Icons.local_offer_rounded, color: AppPalette.categories['Discount']!, label: 'Eco Discount', subtitle: '${widget.rewards.where((r) => r.category == 'Discount').length} available')),
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
                  (_, i) => _fadeSlide(5, Tap(
                    label: '${recent[i].wasteType} scan, +${recent[i].pointsAwarded} points, details',
                    onTap: () => showScanDetailSheet(context, recent[i]),
                    child: _activityTile(recent[i]),
                  )),
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
