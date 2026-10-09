import 'package:flutter/material.dart';
import '../../core/tap.dart';
import 'package:flutter/services.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';

const _kGreen = Color(0xFF4CAF50);
const _kDarkGreen = Color(0xFF2E7D32);

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

  List<String> get _categories => ['All', ..._rewards.map((r) => r.category).toSet()];

  Future<void> _redeem(Reward reward) async {
    // FIX 10: Block sold-out rewards at UI level too
    if (reward.stock == 0) return;

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
            decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(_catIcon(reward.category), color: _kGreen, size: 34),
          ),
          const SizedBox(height: 14),
          Text(reward.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(reward.description, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
          // FIX 10: Show low stock warning in dialog
          if (reward.stock > 0 && reward.stock <= 5) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('Only ${reward.stock} left!',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Cost', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text('${reward.pointsCost} pts', style: const TextStyle(color: _kGreen, fontWeight: FontWeight.bold)),
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
            style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white,
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
        // FIX 6: Haptic on successful redemption before switching tabs
        HapticFeedback.lightImpact();
        widget.onRedeemed();
        await _loadHistory();
        _tabController.animateTo(1);
        final latest = _redemptions.isNotEmpty ? _redemptions.first : null;
        if (latest != null) _showRedemptionCode(latest);
      } else {
        _showSnack('Not enough points or item sold out', Colors.red);
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
            decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: _kGreen, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('Reward Redeemed! 🎉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(r.rewardTitle, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          const Text('Your Redemption Code', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Tap(label: 'Copy redemption code ${r.redemptionCode}', 
            onTap: () {
              Clipboard.setData(ClipboardData(text: r.redemptionCode));
              _showSnack('Code copied!', _kGreen);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(r.redemptionCode,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4, color: _kDarkGreen)),
                const SizedBox(width: 10),
                const Icon(Icons.copy_rounded, color: _kGreen, size: 18),
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
              style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white,
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
            backgroundColor: _kDarkGreen,
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
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
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
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
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
    if (_loadingRewards) return const Center(child: CircularProgressIndicator(color: _kGreen));
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
                return Tap(label: '$cat rewards', selected: selected, 
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? _kGreen : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? _kGreen : Colors.grey.shade200),
                      boxShadow: selected ? [BoxShadow(color: _kGreen.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
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

        // Rewards grid or empty state
        if (_filteredRewards.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_catIcon(_selectedCategory), size: 52, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No $_selectedCategory rewards yet',
                    style: const TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Tap(label: 'Show all rewards', 
                  onTap: () => setState(() => _selectedCategory = 'All'),
                  child: const Text('Show all rewards',
                      style: TextStyle(color: _kGreen, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _AnimatedRewardCard(
                  reward: _filteredRewards[i],
                  index: i,
                  onTap: () => _redeem(_filteredRewards[i]),
                  user: widget.user,
                  catIcon: _catIcon,
                ),
                childCount: _filteredRewards.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistory() {
    if (_loadingHistory) return const Center(child: CircularProgressIndicator(color: _kGreen));
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
          _sectionHeader('Claimed', Icons.check_circle_rounded, _kGreen, claimed.length),
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
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ]);

  // FIX 9: Expiry countdown for pending redemptions
  Widget _redemptionCard(Redemption r, {required bool isPending}) {
    final now = DateTime.now();
    final isExpired = isPending && now.isAfter(r.expiresAt);
    final daysLeft = isPending ? r.expiresAt.difference(now).inDays : 0;
    final expiryColor = daysLeft <= 3 ? Colors.orange : Colors.grey;

    return Tap(label: '${r.rewardTitle}${isPending && !isExpired ? ', show redemption code' : ''}', 
      onTap: (isPending && !isExpired) ? () => _showRedemptionCode(r) : null,
      child: Opacity(
        opacity: isExpired ? 0.6 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: isPending && !isExpired
                ? Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5)
                : isExpired
                    ? Border.all(color: Colors.red.withValues(alpha: 0.2), width: 1)
                    : null,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isExpired
                    ? Colors.red.withValues(alpha: 0.08)
                    : isPending ? Colors.orange.withValues(alpha: 0.1) : _kGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isExpired ? Icons.timer_off_rounded : (isPending ? Icons.confirmation_number_rounded : Icons.check_circle_rounded),
                color: isExpired ? Colors.red : (isPending ? Colors.orange : _kGreen),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.rewardTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              if (isPending && !isExpired)
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                    child: Text(r.redemptionCode,
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold,
                            fontSize: 12, letterSpacing: 2, color: _kDarkGreen)),
                  ),
                  const SizedBox(width: 6),
                  Tap(label: 'Copy code', tooltip: true, 
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: r.redemptionCode));
                      _showSnack('Code copied!', _kGreen);
                    },
                    child: const Icon(Icons.copy_rounded, color: Colors.grey, size: 14),
                  ),
                ])
              else if (isExpired)
                const Text('Expired', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))
              else
                Text(_formatDate(r.redeemedAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
              // FIX 9: Expiry countdown label
              if (isPending && !isExpired) ...[
                const SizedBox(height: 4),
                Text(
                  daysLeft == 0 ? 'Expires today!' : 'Expires in $daysLeft day${daysLeft == 1 ? '' : 's'}',
                  style: TextStyle(color: expiryColor, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('-${r.pointsUsed} pts', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isExpired
                      ? Colors.red.withValues(alpha: 0.08)
                      : isPending ? Colors.orange.withValues(alpha: 0.1) : _kGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isExpired ? 'Expired' : (isPending ? 'Pending' : 'Claimed'),
                  style: TextStyle(
                    color: isExpired ? Colors.red : (isPending ? Colors.orange : _kGreen),
                    fontSize: 10, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
          ]),
        ),
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

// ── Animated Reward Card ──────────────────────────────────────────────────────
class _AnimatedRewardCard extends StatefulWidget {
  final Reward reward;
  final int index;
  final VoidCallback onTap;
  final UserModel user;
  final IconData Function(String) catIcon;
  const _AnimatedRewardCard({required this.reward, required this.index, required this.onTap, required this.user, required this.catIcon});
  @override
  State<_AnimatedRewardCard> createState() => _AnimatedRewardCardState();
}

class _AnimatedRewardCardState extends State<_AnimatedRewardCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    final delay = (widget.index * 80).clamp(0, 600);
    Future.delayed(Duration(milliseconds: 100 + delay), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isSoldOut = widget.reward.stock == 0;
    final isLowStock = widget.reward.stock > 0 && widget.reward.stock <= 5;
    final canAfford = widget.user.points >= widget.reward.pointsCost && !isSoldOut;
    final progress  = (widget.user.points / widget.reward.pointsCost).clamp(0.0, 1.0);
    final catColors = {
      'Coffee': const Color(0xFF795548),
      'Food': const Color(0xFFFF7043),
      'Discount': const Color(0xFF7C4DFF),
      'Other': _kGreen,
    };
    final catColor = catColors[widget.reward.category] ?? _kGreen;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Tap(label: '${widget.reward.title}, ${widget.reward.pointsCost} points${isSoldOut ? ', sold out' : ''}', 
          // FIX 10: Disable tap for sold-out rewards
          onTap: isSoldOut ? null : widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
              border: canAfford ? Border.all(color: _kGreen.withValues(alpha: 0.3), width: 1.5) : null,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // FIX 10: Image area with sold-out overlay
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                child: Stack(children: [
                  Container(
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: (canAfford || isLowStock)
                            ? [catColor.withValues(alpha: 0.8), catColor]
                            : [Colors.grey.shade200, Colors.grey.shade300],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(children: [
                      Center(child: Icon(widget.catIcon(widget.reward.category), color: Colors.white, size: 40)),
                      if (canAfford)
                        Positioned(top: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: const Text('Redeem', style: TextStyle(color: _kGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                          )),
                      Positioned(bottom: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                          child: Text(widget.reward.category, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                        )),
                    ]),
                  ),
                  // FIX 10: Sold-out overlay banner
                  if (isSoldOut)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade700,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('SOLD OUT',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                        ),
                      ),
                    ),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.reward.title,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                            color: isSoldOut ? Colors.grey : Colors.black87),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(widget.reward.description, style: const TextStyle(color: Colors.grey, fontSize: 10),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    // FIX 10: Low stock warning label
                    if (isLowStock) ...[
                      const SizedBox(height: 4),
                      Text('Only ${widget.reward.stock} left!',
                          style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                    const Spacer(),
                    if (!canAfford && !isSoldOut) ...[
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${widget.user.points}/${widget.reward.pointsCost}',
                            style: const TextStyle(color: Colors.grey, fontSize: 9)),
                        Text('${((1 - progress) * widget.reward.pointsCost).round()} more',
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
                        color: isSoldOut ? Colors.grey.shade200 : (canAfford ? _kGreen : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(
                          isSoldOut ? Icons.block_rounded : Icons.stars_rounded,
                          color: isSoldOut ? Colors.grey : (canAfford ? Colors.amber : Colors.grey),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSoldOut ? 'Sold Out' : '${widget.reward.pointsCost} pts',
                          style: TextStyle(
                            color: isSoldOut ? Colors.grey : (canAfford ? Colors.white : Colors.grey),
                            fontWeight: FontWeight.bold, fontSize: 12,
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
