import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import 'qr_scanner_screen.dart';
import 'rewards_screen.dart';
import 'impact_screen.dart';
import 'customer_profile_screen.dart';

const kGreen = Color(0xFF2E7D32);
const kGreenLight = Color(0xFF4CAF50);
const kGold = Color(0xFFB8860B);
const kGoldLight = Color(0xFFD4A017);
const kBg = Color(0xFFF8F9FA);

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedIndex = 0;
  UserModel? _user;
  List<WasteLog> _logs = [];
  List<Reward> _rewards = [];

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final user = await FirebaseService.getCurrentUser();
    final uid = FirebaseService.currentUid;
    if (uid == null || user == null) return;
    final logs = await FirebaseService.getUserWasteLogs(uid);
    final rewards = await FirebaseService.getRewards();
    if (mounted) setState(() { _user = user; _logs = logs; _rewards = rewards; });
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(backgroundColor: kBg,
          body: Center(child: CircularProgressIndicator(color: kGreenLight)));
    }

    final screens = [
      _HomeTab(
        user: _user!, logs: _logs, rewards: _rewards,
        onScan: () async {
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => QRScannerScreen(userId: _user!.uid, username: _user!.username)));
          _loadData();
        },
        onRewards: () => setState(() => _selectedIndex = 1),
        onImpact: () => setState(() => _selectedIndex = 2),
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
          await Navigator.push(context, MaterialPageRoute(
              builder: (_) => QRScannerScreen(userId: _user!.uid, username: _user!.username)));
          _loadData();
        },
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final UserModel user;
  final List<WasteLog> logs;
  final List<Reward> rewards;
  final VoidCallback onScan;
  final VoidCallback onRewards;
  final VoidCallback onImpact;

  const _HomeTab({
    required this.user, required this.logs, required this.rewards,
    required this.onScan, required this.onRewards, required this.onImpact,
  });

  @override
  Widget build(BuildContext context) {
    final bio = logs.where((l) => l.wasteType == 'Biodegradable').length;
    final rec = logs.where((l) => l.wasteType == 'Recyclable').length;
    final co2 = (rec * 0.5 + bio * 0.3).toStringAsFixed(1);
    final recent = logs.take(3).toList();

    return RefreshIndicator(
      color: kGreenLight,
      onRefresh: () async {},
      child: CustomScrollView(
        slivers: [
          // ── Top bar ──
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Hello, ${user.username} 👋',
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                    const Text('Keep recycling, keep earning!',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                  const Spacer(),
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: kGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Text(
                      user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    )),
                  ),
                ]),
              ),
            ),
          ),

          // ── Giant Points Counter ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(children: [
                // Gold coin + points
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)]),
                      boxShadow: [BoxShadow(color: kGold.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.stars_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      NumberFormat('#,###').format(user.points),
                      style: const TextStyle(
                        fontSize: 52, fontWeight: FontWeight.bold, color: Colors.black87,
                        letterSpacing: -1,
                      ),
                    ),
                    const Text('my credits', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                ]),
                const SizedBox(height: 28),

                // Two action buttons
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onScan,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: kGreen,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: kGreen.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
                        ),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text('Scan QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: onRewards,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 5))],
                        ),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.card_giftcard_rounded, color: Color(0xFF2E7D32), size: 22),
                          SizedBox(width: 8),
                          Text('Claim Rewards', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 15)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── 4-tile grid ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Quick Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.1,
                  children: [
                    _gridTile(
                      icon: Icons.coffee_rounded,
                      color: const Color(0xFF795548),
                      label: 'Free Coffee',
                      subtitle: '${rewards.where((r) => r.category == 'Coffee').length} available',
                      onTap: onRewards,
                    ),
                    _gridTile(
                      icon: Icons.local_offer_rounded,
                      color: const Color(0xFF7C4DFF),
                      label: 'Eco Discount',
                      subtitle: '${rewards.where((r) => r.category == 'Discount').length} available',
                      onTap: onRewards,
                    ),
                    _gridTile(
                      icon: Icons.bar_chart_rounded,
                      color: const Color(0xFF0288D1),
                      label: 'Segregation History',
                      subtitle: '${logs.length} total logs',
                      onTap: onImpact,
                    ),
                    _gridTile(
                      icon: Icons.eco_rounded,
                      color: const Color(0xFF2E7D32),
                      label: 'Eco Impact',
                      subtitle: '${co2}kg CO₂ reduced',
                      onTap: onImpact,
                    ),
                  ],
                ),
              ]),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── Recent Activity ──
          if (recent.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  GestureDetector(
                    onTap: onImpact,
                    child: const Text('See All', style: TextStyle(color: kGreenLight, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _activityTile(recent[i]),
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

  Widget _gridTile({required IconData icon, required Color color, required String label, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _activityTile(WasteLog log) {
    final colors = {'Biodegradable': const Color(0xFF8BC34A), 'Recyclable': const Color(0xFF29B6F6), 'Residual': const Color(0xFFEF5350)};
    final icons = {'Biodegradable': Icons.compost_rounded, 'Recyclable': Icons.recycling_rounded, 'Residual': Icons.delete_outline_rounded};
    final color = colors[log.wasteType] ?? kGreenLight;
    final icon = icons[log.wasteType] ?? Icons.recycling_rounded;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(log.wasteType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(DateFormat('MMM d · h:mm a').format(log.timestamp),
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: kGreenLight.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('+${log.pointsEarned} pts',
              style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ]),
    );
  }
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))],
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
                    boxShadow: [BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
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
          color: selected ? kGreenLight.withOpacity(0.1) : Colors.transparent,
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
