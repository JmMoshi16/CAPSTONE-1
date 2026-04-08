import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';

const kGreen = Color(0xFF4CAF50);
const kDarkGreen = Color(0xFF2E7D32);

class RewardsScreen extends StatefulWidget {
  final UserModel user;
  final List<Reward> rewards;
  final VoidCallback onRedeemed;
  const RewardsScreen({super.key, required this.user, required this.rewards, required this.onRedeemed});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Redemption> _redemptions = [];
  List<Reward> _rewards = [];
  bool _loadingHistory = true;
  bool _loadingRewards = true;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRewards();
    _loadHistory();
  }

  Future<void> _loadRewards() async {
    final r = await FirebaseService.getRewards();
    if (mounted) setState(() { _rewards = r; _loadingRewards = false; });
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadHistory() async {
    final uid = FirebaseService.currentUid;
    if (uid == null) return;
    final r = await FirebaseService.getUserRedemptions(uid);
    if (mounted) setState(() { _redemptions = r; _loadingHistory = false; });
  }

  List<Reward> get _filteredRewards {
    if (_selectedCategory == 'All') return _rewards;
    return _rewards.where((r) => r.category == _selectedCategory).toList();
  }

  List<String> get _categories => ['All', ..._rewards.map((r) => r.category).toSet().toList()];

  Future<void> _redeem(Reward reward) async {
    if (widget.user.points < reward.pointsCost) {
      _showSnack('Need ${reward.pointsCost - widget.user.points} more points', Colors.orange);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Confirm Redemption', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(color: kGreen.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(_catIcon(reward.category), color: kGreen, size: 34),
          ),
          const SizedBox(height: 14),
          Text(reward.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(reward.description, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Cost', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text('${reward.pointsCost} pts', style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Remaining', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text('${widget.user.points - reward.pointsCost} pts',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Redeem Now'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await FirebaseService.redeemReward(widget.user, reward);
      if (!mounted) return;
      if (success) {
        widget.onRedeemed();
        await _loadHistory();
        // Switch to redemptions tab and show the code
        _tabController.animateTo(1);
        final latest = _redemptions.isNotEmpty ? _redemptions.first : null;
        if (latest != null) _showRedemptionCode(latest);
      } else {
        _showSnack('Not enough points', Colors.red);
      }
    }
  }

  void _showRedemptionCode(Redemption r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: kGreen.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: kGreen, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('Reward Redeemed! 🎉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(r.rewardTitle, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          const Text('Your Redemption Code', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: r.redemptionCode));
              _showSnack('Code copied!', kGreen);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGreen.withOpacity(0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(r.redemptionCode,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4, color: kDarkGreen)),
                const SizedBox(width: 10),
                const Icon(Icons.copy_rounded, color: kGreen, size: 18),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Show this code to the staff to claim your reward',
              style: TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
        ]),
        actions: [
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white,
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Got it!', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 170,
            pinned: true,
            backgroundColor: kDarkGreen,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rewards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                        const SizedBox(height: 4),
                        const Text('Redeem your points for great rewards', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 14),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: 6),
                              Text('${widget.user.points} pts available',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.receipt_long_rounded, color: Colors.white70, size: 16),
                              const SizedBox(width: 6),
                              Text('${_redemptions.length} redeemed',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ]),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(text: 'Available (${_rewards.length})'),
                Tab(text: 'My Codes (${_redemptions.length})'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildAvailable(), _buildHistory()],
        ),
      ),
    );
  }

  Widget _buildAvailable() {
    if (_loadingRewards) return const Center(child: CircularProgressIndicator(color: kGreen));
    if (_rewards.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.card_giftcard_rounded, size: 64, color: Colors.grey),
        SizedBox(height: 12),
        Text('No rewards available yet', style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600)),
        SizedBox(height: 4),
        Text('Check back later!', style: TextStyle(color: Colors.grey, fontSize: 13)),
      ]));
    }

    return CustomScrollView(
      slivers: [
        // Category filter chips
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? kGreen : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? kGreen : Colors.grey.shade200),
                      boxShadow: selected ? [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (cat != 'All') ...[Icon(_catIcon(cat), color: selected ? Colors.white : Colors.grey, size: 14), const SizedBox(width: 4)],
                      Text(cat, style: TextStyle(color: selected ? Colors.white : Colors.grey,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),

        // Rewards grid
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _rewardCard(_filteredRewards[i]),
              childCount: _filteredRewards.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _rewardCard(Reward reward) {
    final canAfford = widget.user.points >= reward.pointsCost;
    final progress = (widget.user.points / reward.pointsCost).clamp(0.0, 1.0);
    final catColors = {
      'Coffee': const Color(0xFF795548),
      'Food': const Color(0xFFFF7043),
      'Discount': const Color(0xFF7C4DFF),
      'Other': kGreen,
    };
    final catColor = catColors[reward.category] ?? kGreen;

    return GestureDetector(
      onTap: () => _redeem(reward),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
          border: canAfford ? Border.all(color: kGreen.withOpacity(0.3), width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header
            Container(
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: canAfford ? [catColor.withOpacity(0.8), catColor] : [Colors.grey.shade200, Colors.grey.shade300],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Stack(children: [
                Center(child: Icon(_catIcon(reward.category), color: Colors.white, size: 40)),
                if (canAfford)
                  Positioned(top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Redeem', style: TextStyle(color: kGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
                Positioned(bottom: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                    child: Text(reward.category, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(reward.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(reward.description, style: const TextStyle(color: Colors.grey, fontSize: 10),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  if (!canAfford) ...[
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${widget.user.points}/${reward.pointsCost}',
                          style: const TextStyle(color: Colors.grey, fontSize: 9)),
                      Text('${((1 - progress) * reward.pointsCost).round()} more',
                          style: const TextStyle(color: Colors.grey, fontSize: 9)),
                    ]),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation(catColor), minHeight: 4),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: canAfford ? kGreen : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.stars_rounded, color: canAfford ? Colors.amber : Colors.grey, size: 13),
                      const SizedBox(width: 4),
                      Text('${reward.pointsCost} pts',
                          style: TextStyle(color: canAfford ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (_loadingHistory) return const Center(child: CircularProgressIndicator(color: kGreen));
    if (_redemptions.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
          child: const Icon(Icons.receipt_long_rounded, size: 40, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        const Text('No redemptions yet', style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Redeem a reward to get your code', style: TextStyle(color: Colors.grey, fontSize: 13)),
      ]));
    }

    final pending = _redemptions.where((r) => r.status == 'pending').toList();
    final claimed = _redemptions.where((r) => r.status == 'claimed').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        if (pending.isNotEmpty) ...[
          _sectionHeader('Pending Codes', Icons.hourglass_top_rounded, Colors.orange, pending.length),
          const SizedBox(height: 10),
          ...pending.map((r) => _redemptionCard(r, isPending: true)),
          const SizedBox(height: 20),
        ],
        if (claimed.isNotEmpty) ...[
          _sectionHeader('Claimed', Icons.check_circle_rounded, kGreen, claimed.length),
          const SizedBox(height: 10),
          ...claimed.map((r) => _redemptionCard(r, isPending: false)),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color, int count) => Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ]);

  Widget _redemptionCard(Redemption r, {required bool isPending}) {
    return GestureDetector(
      onTap: isPending ? () => _showRedemptionCode(r) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isPending ? Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isPending ? Colors.orange.withOpacity(0.1) : kGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(isPending ? Icons.confirmation_number_rounded : Icons.check_circle_rounded,
                color: isPending ? Colors.orange : kGreen, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.rewardTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            if (isPending)
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Text(r.redemptionCode,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold,
                          fontSize: 12, letterSpacing: 2, color: kDarkGreen)),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: r.redemptionCode));
                    _showSnack('Code copied!', kGreen);
                  },
                  child: const Icon(Icons.copy_rounded, color: Colors.grey, size: 14),
                ),
              ])
            else
              Text(_formatDate(r.redeemedAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('-${r.pointsUsed} pts', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isPending ? Colors.orange.withOpacity(0.1) : kGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(isPending ? 'Pending' : 'Claimed',
                  style: TextStyle(color: isPending ? Colors.orange : kGreen,
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
        ]),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  IconData _catIcon(String cat) {
    switch (cat) {
      case 'Coffee': return Icons.coffee_rounded;
      case 'Food': return Icons.fastfood_rounded;
      case 'Discount': return Icons.local_offer_rounded;
      default: return Icons.card_giftcard_rounded;
    }
  }
}
