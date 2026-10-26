import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../core/theme.dart';
import '../../core/gamification.dart';
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
    final loading = _user == null;
    // While the first data loads: Home's silhouette, with the real nav bar already in place.
    final screens = loading ? const <Widget>[] : [
      _HomeTab(
        user: _user!, logs: _logs, rewards: _rewards, myRank: _myRank,
        redemptions: _redemptions,
        offline: _offline,
        onScan: _openScanner,
        onRewards: () => _openRewards(),
        onOpenReward: _openReward,
        onMyCodes: () => _openRewards(myCodes: true),
        onHistory: () => _openHistory(),
        onLeaderboard: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => LeaderboardScreen(currentUid: _user!.uid, me: _user))),
        onBadges: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => BadgesScreen(user: _user!))),
        // One Profile: the avatar switches to the Profile tab instead of pushing a second copy.
        onProfile: () => setState(() => _selectedIndex = 3),
        onRefresh: _loadData,
      ),
      RewardsScreen(key: _rewardsKey, user: _user!, rewards: _rewards, onRedeemed: _loadData),
      ImpactScreen(logs: _logs, onRefresh: _loadData, onScan: _openScanner,
          onOpenHistory: (type) => _openHistory(filter: type)),
      CustomerProfileScreen(user: _user!, logs: _logs, myRank: _myRank, onUpdated: _loadData,
          onOpenRewards: () => _openRewards(), onOpenHistory: () => _openHistory()),
    ];

    // Docked tab bar (no body swipe: it fought the iOS back gesture and the charts).
    return Scaffold(
      body: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.medium),
        child: loading
            ? const HomeSkeleton(key: ValueKey('loading'))
            : FadeIndexedStack(key: const ValueKey('ready'), index: _selectedIndex, children: screens),
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) { AppHaptics.tap(); setState(() => _selectedIndex = i); },
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

  /// A reward from Home: straight into its detail and redeem flow on the Rewards tab.
  void _openReward(Reward reward) {
    setState(() => _selectedIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _rewardsKey.currentState?.openReward(reward));
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
      body: _HomeTab(
        user: user, logs: logs, rewards: rewards, redemptions: redemptions, myRank: myRank, offline: offline,
        onScan: () {}, onRewards: () {}, onOpenReward: (_) {}, onMyCodes: () {},
        onHistory: () {}, onLeaderboard: () {}, onBadges: () {}, onProfile: () {},
        onRefresh: () async {},
      ),
      bottomNavigationBar: _BottomNav(selectedIndex: 0, onTap: (_) {}, onScan: () {}, onScanWithLight: () {}),
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
  final ValueChanged<Reward> onOpenReward;
  final VoidCallback onMyCodes;
  final VoidCallback onHistory;
  final VoidCallback onLeaderboard;
  final VoidCallback onBadges;
  final VoidCallback onProfile;
  final Future<void> Function() onRefresh;

  const _HomeTab({
    required this.user, required this.logs, required this.rewards,
    required this.redemptions,
    required this.myRank,
    required this.offline,
    required this.onScan, required this.onRewards, required this.onOpenReward, required this.onMyCodes,
    required this.onHistory, required this.onLeaderboard, required this.onBadges, required this.onProfile,
    required this.onRefresh,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with SingleTickerProviderStateMixin {
  late AnimationController _staggerCtrl;
  /// Entrance animations and count-ups play on the first visit of the session only.
  late final bool _firstLoad = AppMotion.firstTime('home');
  final List<Animation<double>> _fadeAnims = [];
  final List<Animation<Offset>> _slideAnims = [];

  @override
  void initState() {
    super.initState();
    // One short entrance on the first visit; sections overlap so nothing waits long.
    _staggerCtrl = AnimationController(vsync: this, duration: AppMotion.slow * 2);
    for (final iv in const [Interval(0.0, 0.45), Interval(0.15, 0.6), Interval(0.3, 0.75), Interval(0.45, 0.9), Interval(0.55, 1.0)]) {
      _fadeAnims.add(CurvedAnimation(parent: _staggerCtrl, curve: iv));
      _slideAnims.add(Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
          .animate(CurvedAnimation(parent: _staggerCtrl, curve: Interval(iv.begin, iv.end, curve: AppMotion.standard))));
    }
    if (_firstLoad) {
      _staggerCtrl.forward();
    } else {
      _staggerCtrl.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _staggerCtrl.value = 1;
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
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
              child: Semantics(header: true, child: Text(label, style: ctx.text.titleSmall)),
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

  /// Rewards for the strip: the ones the user can redeem now (best first), else the three closest.
  List<Reward> _stripRewards() {
    final open = widget.rewards.where((r) => r.isActive && r.stock != 0).toList();
    final ready = open.where((r) => r.pointsCost <= widget.user.points).toList()
      ..sort((a, b) => b.pointsCost.compareTo(a.pointsCost));
    if (ready.isNotEmpty) return ready.take(6).toList();
    return (open..sort((a, b) => a.pointsCost.compareTo(b.pointsCost))).take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final now = DateTime.now();
    final recent = widget.logs.take(3).toList();
    final streak = effectiveStreak(widget.user.streak, widget.user.lastScanDate, now);
    final scansThisWeek = scansInLastDays(widget.logs.map((l) => l.timestamp), now);
    final strip = _stripRewards();
    final canRedeem = strip.isNotEmpty && strip.first.pointsCost <= widget.user.points;
    final pending = widget.redemptions.where((r) => r.status == 'pending' && !now.isAfter(r.expiresAt)).length;

    Widget section(String title, {String? action, VoidCallback? onAction}) => Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xl, AppSpace.lg, AppSpace.sm),
          child: SectionHeader(title: title, actionLabel: action, onAction: onAction),
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Home no longer sits under a dark header: status-bar icons follow the theme.
      value: c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: EcoRefresh(
        onRefresh: widget.onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                  child: _fadeSlide(0, _HomeHeader(
                    user: widget.user,
                    pending: pending,
                    onProfile: widget.onProfile,
                    onBell: () => _showNotificationsSheet(context),
                  )),
                ),
              ),
            ),

            if (widget.offline)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                  child: _OfflineBanner(onRetry: widget.onRefresh),
                ),
              ),

            // Balance + the one primary action.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 0),
                child: _fadeSlide(1, Column(children: [
                  _BalanceCard(
                    user: widget.user,
                    rewards: widget.rewards,
                    countFromZero: _firstLoad,
                    onTap: () => showRankLevelSheet(context, lifetimePoints: widget.user.lifetimePoints),
                  ),
                  const SizedBox(height: AppSpace.md),
                  AppButton(label: 'Scan at the bin', icon: Icons.qr_code_scanner_rounded, onPressed: widget.onScan),
                ])),
              ),
            ),

            // What the points buy.
            if (strip.isNotEmpty) ...[
              SliverToBoxAdapter(child: _fadeSlide(2,
                  section(canRedeem ? 'Ready to redeem' : 'Rewards to work towards', action: 'See all', onAction: widget.onRewards))),
              SliverToBoxAdapter(child: _fadeSlide(2,
                  _RewardStrip(rewards: strip, points: widget.user.points, onOpen: widget.onOpenReward))),
            ],

            // This week.
            SliverToBoxAdapter(child: _fadeSlide(3, section('This week'))),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: _fadeSlide(3, _WeekCard(
                  streak: streak,
                  scansThisWeek: scansThisWeek,
                  fromZero: _firstLoad,
                  onTap: () => showStreakSheet(context, streak: streak, onScan: widget.onScan),
                )),
              ),
            ),

            // Recent activity: one list, every row opens its details.
            SliverToBoxAdapter(child: _fadeSlide(4, section('Recent activity',
                action: recent.isEmpty ? null : 'See all', onAction: widget.onHistory))),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: _fadeSlide(4, recent.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        decoration: cardDecoration(context),
                        child: Column(children: [
                          Text('No scans yet', style: t.titleSmall),
                          const SizedBox(height: AppSpace.xxs),
                          Text('Drop an item in the bin, then scan its QR code to earn your first points.',
                              textAlign: TextAlign.center, style: t.bodySmall),
                        ]),
                      )
                    : Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: cardDecoration(context),
                        child: Material(
                          color: Colors.transparent,
                          child: Column(children: [
                            for (var i = 0; i < recent.length; i++) ...[
                              if (i > 0) Divider(height: 1, thickness: 1, indent: 64, color: c.border),
                              _activityRow(recent[i]),
                            ],
                          ]),
                        ),
                      )),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),
          ],
        ),
      ),
    );
  }

  Widget _activityRow(WasteLog log) {
    final c = context.colors;
    final t = context.text;
    final color = c.waste(log.wasteType);
    return Semantics(
      button: true,
      label: '${log.wasteType} scan, +${log.pointsAwarded} points, details',
      excludeSemantics: true,
      child: InkWell(
        onTap: () { AppHaptics.tap(); showScanDetailSheet(context, log); },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
          child: Row(children: [
            Medallion(icon: wasteIcon(log.wasteType), color: color, size: 36),
            const SizedBox(width: AppSpace.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(log.wasteType, style: t.titleSmall),
              Text(DateFormat('MMM d, h:mm a').format(log.timestamp), style: t.bodySmall),
            ])),
            Text('+${log.pointsAwarded} pts', style: t.titleSmall!.copyWith(color: c.success)),
          ]),
        ),
      ),
    );
  }
}
