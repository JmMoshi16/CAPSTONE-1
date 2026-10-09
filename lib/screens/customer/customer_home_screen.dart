import 'package:flutter/material.dart';
import '../../core/tap.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../core/theme.dart';
import '../../core/gamification.dart';
import '../../widgets/eco_animations.dart';
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
      final results = await Future.wait([
        FirebaseService.getUserWasteLogs(uid),
        FirebaseService.getRewards(),
        FirebaseService.getUserRank(uid),
        FirebaseService.getUserRedemptions(uid),
      ]).timeout(const Duration(seconds: 10), onTimeout: () => [[], [], 0, []]);
      if (mounted) {
        setState(() {
        _user = user;
        _logs = results[0] as List<WasteLog>;
        _rewards = results[1] as List<Reward>;
        _myRank = results[2] as int;
        _redemptions = results[3] as List<Redemption>;
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
        backgroundColor: kBg,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Could not load data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Check your connection and try again', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white),
          ),
        ])),
      );
    }
    if (_user == null) {
      return const Scaffold(backgroundColor: kBg,
          body: Center(child: EcoLoader(size: 72)));
    }

    final screens = [
      _HomeTab(
        user: _user!, logs: _logs, rewards: _rewards, myRank: _myRank,
        redemptions: _redemptions,
        onScan: () async {
          if (_scannerOpen) return;
          _scannerOpen = true;
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => QRScannerScreen(userId: _user!.uid, username: _user!.username)));
          _loadData();
          _scannerOpen = false;
        },
        onRewards:     () => setState(() => _selectedIndex = 1),
        onImpact:      () => setState(() => _selectedIndex = 2),
        onHistory: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ScanHistoryScreen(logs: _logs))).then((_) => _loadData()),
        onLeaderboard: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => LeaderboardScreen(currentUid: _user!.uid))),
        onBadges: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => BadgesScreen(user: _user!))),
        onRefresh: _loadData,
      ),
      RewardsScreen(user: _user!, rewards: _rewards, onRedeemed: _loadData),
      ImpactScreen(logs: _logs),
      CustomerProfileScreen(user: _user!, logs: _logs, onUpdated: _loadData),
    ];

    return Scaffold(
      backgroundColor: kBg,
      extendBody: true,
      body: screens[_selectedIndex],
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        onScan: () async {
          if (_scannerOpen) return;
          _scannerOpen = true;
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => QRScannerScreen(userId: _user!.uid, username: _user!.username)));
          _loadData();
          _scannerOpen = false;
        },
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final UserModel user;
  final List<WasteLog> logs;
  final List<Reward> rewards;
  final List<Redemption> redemptions;
  final int myRank;
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

    // Stagger controller — 900ms total
    _staggerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

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
          .animate(CurvedAnimation(parent: _staggerCtrl, curve: Interval(iv.begin, iv.end, curve: Curves.easeOut))));
    }

    // Points count-up
    _pointsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _pointsAnim = Tween<double>(begin: 0, end: widget.user.points.toDouble())
        .animate(CurvedAnimation(parent: _pointsCtrl, curve: Curves.easeOut));

    // Pulse for scan button
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Start animations
    _staggerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _pointsCtrl.forward();
    });
  }

  @override
  void didUpdateWidget(_HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.points != widget.user.points) {
      _pointsAnim = Tween<double>(begin: oldWidget.user.points.toDouble(), end: widget.user.points.toDouble())
          .animate(CurvedAnimation(parent: _pointsCtrl, curve: Curves.easeOut));
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
        iconColor: isExpired ? Colors.red : isPending ? Colors.orange : kGreen,
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
                  backgroundColor: kGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              }
            : null,
      ));
    }

    // Activity notifications
    if (widget.user.scanCount > 0) {
      items.add(_NotifItem(
        icon: Icons.recycling_rounded, iconColor: kGreen,
        title: 'Points Credited',
        subtitle: '${widget.user.scanCount} scan${widget.user.scanCount > 1 ? "s" : ""} recorded. Keep recycling!',
        time: 'Today', isUnread: false, onTap: null,
      ));
    }
    if (widget.user.badges.isNotEmpty) {
      items.add(_NotifItem(
        icon: Icons.military_tech_rounded, iconColor: Colors.amber,
        title: 'Badge Unlocked',
        subtitle: 'You earned ${widget.user.badges.length} badge${widget.user.badges.length > 1 ? "s" : ""}. Check your collection!',
        time: 'Recently', isUnread: false, onTap: null,
      ));
    }
    if (widget.myRank > 0 && widget.myRank <= 10) {
      items.add(_NotifItem(
        icon: Icons.leaderboard_rounded, iconColor: const Color(0xFFB8860B),
        title: 'Top 10 Leaderboard',
        subtitle: "You're ranked #${widget.myRank} on the leaderboard!",
        time: 'Today', isUnread: false, onTap: null,
      ));
    }
    final streak = effectiveStreak(widget.user.streak, widget.user.lastScanDate, DateTime.now());
    if (streak > 2) {
      items.add(_NotifItem(
        icon: Icons.local_fire_department_rounded, iconColor: Colors.deepOrange,
        title: '$streak-Day Streak',
        subtitle: 'Amazing! Keep recycling every day.',
        time: 'Today', isUnread: false, onTap: null,
      ));
    }
    if (items.isEmpty) {
      items.add(const _NotifItem(
        icon: Icons.eco_rounded, iconColor: kGreen,
        title: 'Welcome to ECOReward!',
        subtitle: 'Start scanning waste QR codes to earn points and rewards.',
        time: 'Now', isUnread: false, onTap: null,
      ));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.60,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            // drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(children: [
                const Expanded(
                  child: Text('Notifications',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                ),
                if (items.any((e) => e.isUnread))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('${items.where((e) => e.isUnread).length} new',
                        style: const TextStyle(color: kGreen, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
              ]),
            ),
            const Divider(height: 1),
            // notification list
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 68, endIndent: 16),
                itemBuilder: (_, i) {
                  final n = items[i];
                  return InkWell(
                    onTap: n.onTap,
                    child: Container(
                      color: n.isUnread ? kGreen.withValues(alpha: 0.04) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // icon circle
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: n.iconColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(n.icon, color: n.iconColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        // text
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(n.title,
                                style: TextStyle(
                                  fontWeight: n.isUnread ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 14, color: Colors.black87,
                                ))),
                            Text(n.time,
                                style: TextStyle(fontSize: 11,
                                    color: n.isUnread ? kGreen : Colors.grey,
                                    fontWeight: n.isUnread ? FontWeight.w600 : FontWeight.normal)),
                          ]),
                          const SizedBox(height: 3),
                          Text(n.subtitle,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ])),
                        // unread dot
                        if (n.isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
                          ),
                        ],
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
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
      color: kGreenLight,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
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

          // ── Progress bars + Buttons (no box, direct on bg) ───────────────
          SliverToBoxAdapter(
            child: _fadeSlide(1, Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Rank bar
                _ProgressBarRow(
                  leftLabel: '${rank.icon}  ${rank.label}',
                  rightLabel: rank.next != null
                      ? '${rank.nextPts - lifetime} pts to ${rank.next}'
                      : 'Max Rank',
                  progress: rankProgress(lifetime),
                  color: rank.color,
                  labelColor: rank.color,
                ),
                const SizedBox(height: 10),
                // Level bar
                _ProgressBarRow(
                  leftLabel: '${level.emoji}  ${level.title}  Lv ${level.level}',
                  rightLabel: ptsToNextLevel(lifetime) == 0
                      ? '🎉 Max Level'
                      : '${ptsToNextLevel(lifetime)} pts to next',
                  progress: levelProgress(lifetime),
                  color: level.color,
                  labelColor: level.color,
                ),
                const SizedBox(height: 20),
                // Scan button
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Tap(label: 'Scan QR code', 
                    onTap: widget.onScan,
                    child: Container(
                      width: double.infinity, height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
                          begin: Alignment.centerLeft, end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(
                          color: kGreen.withValues(alpha: 0.40),
                          blurRadius: 16, offset: const Offset(0, 6),
                        )],
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text('Scan QR Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.3)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Rewards button
                Tap(label: 'Claim rewards', 
                  onTap: widget.onRewards,
                  child: Container(
                    width: double.infinity, height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kGreen.withValues(alpha: 0.30), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.card_giftcard_rounded, color: kGreen, size: 20),
                      SizedBox(width: 8),
                      Text('Claim Rewards', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 15)),
                    ]),
                  ),
                ),
              ]),
            )),
          ),


          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Progress Stats ──
          SliverToBoxAdapter(
            child: _fadeSlide(2, Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Section header
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Your Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    Text('Tap a card for details', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      const Icon(Icons.local_fire_department_rounded, color: kGreen, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        streak > 0 ? '$streak-day streak!' : 'Start your streak',
                        style: const TextStyle(fontSize: 11, color: kGreen, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                // Stat cards
                Row(children: [
                  _StatCard(emoji: '🔥', value: '${streak}d',
                      label: 'streak', valueColor: streak > 0 ? Colors.deepOrange : Colors.grey,
                      accentColor: Colors.deepOrange,
                      delay: 0, ctrl: _staggerCtrl, onTap: widget.onLeaderboard),
                  const SizedBox(width: 10),
                  _StatCard(emoji: '🏆', value: widget.myRank > 0 ? '#${widget.myRank}' : '--',
                      label: 'rank', valueColor: widget.myRank > 0 ? const Color(0xFFB8860B) : Colors.grey,
                      accentColor: const Color(0xFFB8860B),
                      delay: 80, ctrl: _staggerCtrl, onTap: widget.onLeaderboard),
                  const SizedBox(width: 10),
                  _StatCard(emoji: '🏅', value: '${widget.user.badges.length}',
                      label: 'badges', valueColor: widget.user.badges.isNotEmpty ? Colors.amber : Colors.grey,
                      accentColor: Colors.amber,
                      delay: 160, ctrl: _staggerCtrl, onTap: widget.onBadges),
                  const SizedBox(width: 10),
                  _StatCard(emoji: '♻️', value: '${widget.user.scanCount}',
                      label: 'scans', valueColor: const Color(0xFF2E7D32),
                      accentColor: const Color(0xFF2E7D32),
                      delay: 240, ctrl: _staggerCtrl, onTap: widget.onImpact),
                ]),
                const SizedBox(height: 12),
                // Weekly scan goal bar
                _WeeklyGoalBar(scanCount: scansThisWeek, weeklyGoal: 10),
                if (widget.user.scanCount == 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: kGreen.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kGreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      const Text('🌱', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Scan your first QR to earn badges and start your streak!',
                          style: TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.w500))),
                      Tap(label: 'Scan your first QR code', 
                        onTap: widget.onScan,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(10)),
                          child: const Text('Scan', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                  ),
                ],
              ]),
            )),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Quick Access Grid ──
          SliverToBoxAdapter(
            child: _fadeSlide(3, Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Quick Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _ScaleTapButton(onTap: widget.onRewards, child: _gridTileContent(icon: Icons.coffee_rounded, color: const Color(0xFF795548), label: 'Free Coffee', subtitle: '${widget.rewards.where((r) => r.category == 'Coffee').length} available'))),
                  const SizedBox(width: 12),
                  Expanded(child: _ScaleTapButton(onTap: widget.onRewards, child: _gridTileContent(icon: Icons.local_offer_rounded, color: const Color(0xFF7C4DFF), label: 'Eco Discount', subtitle: '${widget.rewards.where((r) => r.category == 'Discount').length} available'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _ScaleTapButton(onTap: widget.onHistory, child: _gridTileContent(icon: Icons.history_rounded, color: const Color(0xFF0288D1), label: 'Scan History', subtitle: '${widget.logs.length} total scans'))),
                  const SizedBox(width: 12),
                  Expanded(child: _ScaleTapButton(onTap: widget.onImpact, child: _gridTileContent(icon: Icons.eco_rounded, color: const Color(0xFF2E7D32), label: 'Eco Impact', subtitle: '${co2}kg CO₂ reduced'))),
                ]),
              ]),
            )),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Recent Activity ──
          if (recent.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _fadeSlide(4, Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  Tap(label: 'See all scan history', 
                    onTap: widget.onHistory,
                    child: const Text('See All', style: TextStyle(color: kGreenLight, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ]),
              )),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _fadeSlide(5, _activityTile(recent[i])),
                  childCount: recent.length,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _gridTileContent({required IconData icon, required Color color, required String label, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.08)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      ]),
    );
  }

  Widget _activityTile(WasteLog log) {
    final colors = {'Biodegradable': const Color(0xFF7CB342), 'Recyclable': const Color(0xFF0288D1), 'Residual': const Color(0xFFE53935)};
    final icons = {'Biodegradable': Icons.compost_rounded, 'Recyclable': Icons.recycling_rounded, 'Residual': Icons.delete_outline_rounded};
    final color = colors[log.wasteType] ?? kGreenLight;
    final icon = icons[log.wasteType] ?? Icons.recycling_rounded;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        // Colored left accent bar
        Container(
          width: 4, height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18), bottomLeft: Radius.circular(18)),
          ),
        ),
        const SizedBox(width: 12),
        Container(width: 38, height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(log.wasteType, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87)),
          Text(DateFormat('MMM d · h:mm a').format(log.timestamp),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ])),
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [kGreen.withValues(alpha: 0.15), kGreenLight.withValues(alpha: 0.08)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('+${log.pointsAwarded} pts',
                style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}
