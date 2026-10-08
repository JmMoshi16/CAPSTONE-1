import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../core/theme.dart';
import 'qr_scanner_screen.dart';
import 'rewards_screen.dart';
import 'impact_screen.dart';
import 'scan_history_screen.dart';
import 'customer_profile_screen.dart';
import 'leaderboard_screen.dart';
import 'badges_screen.dart';

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
      if (mounted) setState(() {
        _user = user;
        _logs = results[0] as List<WasteLog>;
        _rewards = results[1] as List<Reward>;
        _myRank = results[2] as int;
        _redemptions = results[3] as List<Redemption>;
        _loadError = false;
      });
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
          body: Center(child: CircularProgressIndicator(color: kGreenLight)));
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
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
    if (widget.user.streak > 2) {
      items.add(_NotifItem(
        icon: Icons.local_fire_department_rounded, iconColor: Colors.deepOrange,
        title: '${widget.user.streak}-Day Streak',
        subtitle: 'Amazing! Keep recycling every day.',
        time: 'Today', isUnread: false, onTap: null,
      ));
    }
    if (items.isEmpty) {
      items.add(_NotifItem(
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
    final rank = getRank(widget.user.points);
    final progress = rankProgress(widget.user.points);

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
              points: widget.user.points,
              pointsAnim: _pointsAnim,
              streak: widget.user.streak,
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
                  leftLabel: '${getRank(widget.user.points).icon}  ${getRank(widget.user.points).label}',
                  rightLabel: getRank(widget.user.points).next != null
                      ? '${getRank(widget.user.points).nextPts - widget.user.points} pts to ${getRank(widget.user.points).next}'
                      : 'Max Rank',
                  progress: rankProgress(widget.user.points),
                  color: getRank(widget.user.points).color,
                  labelColor: getRank(widget.user.points).color,
                ),
                const SizedBox(height: 10),
                // Level bar
                _ProgressBarRow(
                  leftLabel: '${getLevel(widget.user.points).emoji}  ${getLevel(widget.user.points).title}  Lv ${getLevel(widget.user.points).level}',
                  rightLabel: ptsToNextLevel(widget.user.points) == 0
                      ? '🎉 Max Level'
                      : '${ptsToNextLevel(widget.user.points)} pts to next',
                  progress: levelProgress(widget.user.points),
                  color: getLevel(widget.user.points).color,
                  labelColor: getLevel(widget.user.points).color,
                ),
                const SizedBox(height: 20),
                // Scan button
                ScaleTransition(
                  scale: _pulseAnim,
                  child: GestureDetector(
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
                GestureDetector(
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
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Your Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    const Text('Tap a card for details', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                        widget.user.streak > 0 ? '${widget.user.streak}-day streak!' : 'Start your streak',
                        style: const TextStyle(fontSize: 11, color: kGreen, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                // Stat cards
                Row(children: [
                  _StatCard(emoji: '🔥', value: widget.user.streak > 0 ? '${widget.user.streak}d' : '0d',
                      label: 'streak', valueColor: widget.user.streak > 0 ? Colors.deepOrange : Colors.grey,
                      accentColor: Colors.deepOrange,
                      delay: 0, ctrl: _staggerCtrl, onTap: widget.onLeaderboard),
                  const SizedBox(width: 10),
                  _StatCard(emoji: '🏆', value: widget.myRank > 0 ? '#${widget.myRank}' : '--',
                      label: 'rank', valueColor: widget.myRank > 0 ? const Color(0xFFB8860B) : Colors.grey,
                      accentColor: Color(0xFFB8860B),
                      delay: 80, ctrl: _staggerCtrl, onTap: widget.onLeaderboard),
                  const SizedBox(width: 10),
                  _StatCard(emoji: '🏅', value: '${widget.user.badges.length}',
                      label: 'badges', valueColor: widget.user.badges.isNotEmpty ? Colors.amber : Colors.grey,
                      accentColor: Colors.amber,
                      delay: 160, ctrl: _staggerCtrl, onTap: widget.onBadges),
                  const SizedBox(width: 10),
                  _StatCard(emoji: '♻️', value: '${widget.user.scanCount}',
                      label: 'scans', valueColor: const Color(0xFF2E7D32),
                      accentColor: Color(0xFF2E7D32),
                      delay: 240, ctrl: _staggerCtrl, onTap: widget.onImpact),
                ]),
                const SizedBox(height: 12),
                // Weekly scan goal bar
                _WeeklyGoalBar(scanCount: widget.user.scanCount, weeklyGoal: 10),
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
                      GestureDetector(
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
                  GestureDetector(
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
            child: Text('+${log.pointsEarned} pts',
                style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}

// ── Hero Header Card ──────────────────────────────────────────────────────────
class _HeroHeaderCard extends StatelessWidget {
  final UserModel user;
  final int myRank, pendingRedemptions, points, streak;
  final Animation<double> pointsAnim;
  final VoidCallback onBell, onProfile;
  const _HeroHeaderCard({
    required this.user, required this.myRank, required this.pendingRedemptions,
    required this.points, required this.pointsAnim, required this.streak,
    required this.onBell, required this.onProfile,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final lv = getLevel(points);
    final rk = getRank(points);
    final multiplier = streakMultiplier(streak);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Stack(children: [
        Positioned(top: -40, right: -40,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05)))),
        Positioned(bottom: 20, left: -30,
          child: Container(width: 110, height: 110,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04)))),

        SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
          child: Column(children: [

            // ── Top row: avatar / name / bell ──────────────────────────────
            Row(children: [
              GestureDetector(
                onTap: onProfile,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(child: Text(
                    user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting, style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 11)),
                Text(user.username, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ])),
              GestureDetector(
                onTap: onBell,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 19),
                  ),
                  if (pendingRedemptions > 0)
                    Positioned(top: -2, right: -2,
                      child: Container(
                        width: 15, height: 15,
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: Center(child: Text('$pendingRedemptions',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                      )),
                ]),
              ),
            ]),

            const SizedBox(height: 24),

            // ── Points display (centered, no box) ──────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFE566), Color(0xFFFFD700), Color(0xFFB8860B)],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.stars_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedBuilder(
                  animation: pointsAnim,
                  builder: (_, __) => Text(
                    NumberFormat('#,###').format(pointsAnim.value.toInt()),
                    style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -2, height: 1.0),
                  ),
                ),
                Row(children: [
                  Text('eco credits', style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12)),
                  if (multiplier > 1.0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        streak >= 7 ? '🔥 2× Bonus' : '🔥 1.5× Bonus',
                        style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ]),
              ]),
            ]),

            const SizedBox(height: 20),

            // ── Rank + Level pills ─────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _pill('${lv.emoji} Lv ${lv.level} ${lv.title}'),
              const SizedBox(width: 8),
              _pill('${rk.icon} ${rk.label}'),
              if (myRank > 0) ...[
                const SizedBox(width: 8),
                _pill('🏆 #$myRank'),
              ],
            ]),
          ]),
        )),
      ]),
    );
  }

  Widget _pill(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}



// ── Progress Bar Row (labeled) ────────────────────────────────────────────────

class _ProgressBarRow extends StatelessWidget {
  final String leftLabel, rightLabel;
  final double progress;
  final Color color, labelColor;
  const _ProgressBarRow({
    required this.leftLabel, required this.rightLabel,
    required this.progress, required this.color, required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(leftLabel,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: labelColor)),
        Text(rightLabel,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]),
      const SizedBox(height: 6),
      _AnimatedProgressBar(progress: progress, color: color),
    ]);
  }
}

// ── Animated Avatar ───────────────────────────────────────────────────────────

class _AnimatedAvatar extends StatefulWidget {
  final String initial;
  const _AnimatedAvatar({required this.initial});
  @override
  State<_AnimatedAvatar> createState() => _AnimatedAvatarState();
}


class _AnimatedAvatarState extends State<_AnimatedAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(14)),
      child: Center(child: Text(widget.initial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
    ),
  );
}

// ── Animated Progress Bar ─────────────────────────────────────────────────────
class _AnimatedProgressBar extends StatefulWidget {
  final double progress;
  final Color color;
  const _AnimatedProgressBar({required this.progress, required this.color});
  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _anim = Tween<double>(begin: 0, end: widget.progress)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 400), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: _anim.value,
        backgroundColor: Colors.grey.shade100,
        valueColor: AlwaysStoppedAnimation(widget.color),
        minHeight: 8,
      ),
    ),
  );
}

// ── Stat Card with staggered pop-in ──────────────────────────────────────────
class _StatCard extends StatefulWidget {
  final String emoji, value, label;
  final Color valueColor;
  final Color accentColor;
  final int delay;
  final AnimationController ctrl;
  final VoidCallback onTap;
  const _StatCard({required this.emoji, required this.value, required this.label,
      required this.valueColor, required this.accentColor,
      required this.delay, required this.ctrl, required this.onTap});
  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> with SingleTickerProviderStateMixin {
  late AnimationController _popCtrl;
  late Animation<double> _pop;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _popCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pop = CurvedAnimation(parent: _popCtrl, curve: Curves.elasticOut);
    Future.delayed(Duration(milliseconds: 300 + widget.delay), () { if (mounted) _popCtrl.forward(); });
  }

  @override
  void dispose() { _popCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Expanded(
    child: ScaleTransition(
      scale: _pop,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Colored accent line at top
              Container(
                height: 3,
                width: 24,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Text(widget.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(widget.value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: widget.valueColor)),
              Text(widget.label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ]),
          ),
        ),
      ),
    ),
  );
}

// ── Weekly Goal Bar ───────────────────────────────────────────────────────────
class _WeeklyGoalBar extends StatelessWidget {
  final int scanCount;
  final int weeklyGoal;
  const _WeeklyGoalBar({required this.scanCount, required this.weeklyGoal});

  @override
  Widget build(BuildContext context) {
    final progress = (scanCount / weeklyGoal).clamp(0.0, 1.0);
    final done = scanCount >= weeklyGoal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Text('🎯', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            const Text('Weekly Goal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black87)),
          ]),
          Text(
            done ? '✅ Goal reached!' : '$scanCount / $weeklyGoal scans',
            style: TextStyle(
              fontSize: 11,
              color: done ? kGreen : Colors.grey,
              fontWeight: done ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(done ? kGreen : kGreenLight),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }
}

// ── Pulse Scan Button ─────────────────────────────────────────────────────────
class _PulseButton extends StatelessWidget {
  final Animation<double> pulse;
  final VoidCallback onTap;
  const _PulseButton({required this.pulse, required this.onTap});

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: pulse,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: kGreen,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: kGreen.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text('Scan QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ),
    ),
  );
}

// ── Scale-on-tap wrapper ──────────────────────────────────────────────────────
class _ScaleTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleTapButton({required this.child, required this.onTap});
  @override
  State<_ScaleTapButton> createState() => _ScaleTapButtonState();
}

class _ScaleTapButtonState extends State<_ScaleTapButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100), lowerBound: 0.93, upperBound: 1.0, value: 1.0);
    _scale = _ctrl;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ctrl.reverse(),
    onTapUp: (_) { _ctrl.forward(); widget.onTap(); },
    onTapCancel: () => _ctrl.forward(),
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}

// ── Floating Nav Bar ──────────────────────────────────────────────────────────
class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScan;
  const _FloatingNavBar({required this.selectedIndex, required this.onTap, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, Icons.home_outlined, 'Home', 0),
              _navItem(Icons.card_giftcard_rounded, Icons.card_giftcard_outlined, 'Rewards', 1),
              GestureDetector(
                onTap: onScan,
                child: Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: kGreen,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: kGreen.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
                ),
              ),
              _navItem(Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Insight', 2),
              _navItem(Icons.person_rounded, Icons.person_outlined, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData active, IconData inactive, String label, int index) {
    final selected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kGreenLight.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(selected ? active : inactive, color: selected ? kGreen : Colors.grey, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: selected ? kGreen : Colors.grey,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}

// ── Notification item data model ──────────────────────────────────────────────
class _NotifItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;
  final VoidCallback? onTap;

  const _NotifItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
    required this.onTap,
  });
}

