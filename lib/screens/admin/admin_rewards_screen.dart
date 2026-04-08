import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';

const kGreen = Color(0xFF00E676);
const kDarkGreen = Color(0xFF00C853);
const kDark = Color(0xFF0D1117);
const kCard = Color(0xFF161B22);
const kBorder = Color(0xFF30363D);

class AdminRewardsScreen extends StatefulWidget {
  final List<Reward> rewards;
  final VoidCallback onChanged;
  const AdminRewardsScreen({super.key, required this.rewards, required this.onChanged});
  @override
  State<AdminRewardsScreen> createState() => _AdminRewardsScreenState();
}

class _AdminRewardsScreenState extends State<AdminRewardsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Redemption> _redemptions = [];
  bool _loadingRedemptions = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRedemptions();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadRedemptions() async {
    final r = await FirebaseService.getAllRedemptions();
    if (mounted) setState(() { _redemptions = r; _loadingRedemptions = false; });
  }

  void _showForm({Reward? reward}) {
    final titleCtrl = TextEditingController(text: reward?.title ?? '');
    final descCtrl = TextEditingController(text: reward?.description ?? '');
    final pointsCtrl = TextEditingController(text: reward?.pointsCost.toString() ?? '');
    String category = reward?.category ?? 'Coffee';
    bool isActive = reward?.isActive ?? true;
    final formKey = GlobalKey<FormState>();
    final categories = ['Coffee', 'Food', 'Discount', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(reward == null ? 'Add New Reward' : 'Edit Reward',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                _field(titleCtrl, 'Title', Icons.title_rounded),
                const SizedBox(height: 10),
                _field(descCtrl, 'Description', Icons.description_rounded),
                const SizedBox(height: 10),
                _field(pointsCtrl, 'Points Cost', Icons.stars_rounded, keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                // Category dropdown
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: kCard,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.category_rounded, color: kGreen, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.07),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: categories.map((c) => DropdownMenuItem(value: c,
                      child: Row(children: [
                        Icon(_catIcon(c), size: 16, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text(c),
                      ]))).toList(),
                  onChanged: (v) => setS(() => category = v!),
                ),
                const SizedBox(height: 10),
                // Active toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.toggle_on_rounded, color: kGreen, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Active (visible to customers)', style: TextStyle(color: Colors.white70, fontSize: 13))),
                    Switch(value: isActive, onChanged: (v) => setS(() => isActive = v),
                        activeColor: kGreen, activeTrackColor: kGreen.withOpacity(0.3)),
                  ]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final r = Reward(
                        id: reward?.id,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        pointsCost: int.tryParse(pointsCtrl.text.trim()) ?? 0,
                        category: category,
                        isActive: isActive,
                      );
                      if (reward == null) {
                        await FirebaseService.addReward(r);
                      } else {
                        await FirebaseService.updateReward(r);
                      }
                      widget.onChanged();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: kGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    child: Text(reward == null ? 'Add Reward' : 'Save Changes',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markClaimed(Redemption r) async {
    await FirebaseService.claimRedemption(r.id!);
    await _loadRedemptions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✓ "${r.rewardTitle}" marked as claimed'),
        backgroundColor: kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _redemptions.where((r) => r.status == 'pending').length;

    return Scaffold(
      backgroundColor: kDark,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: kCard,
            automaticallyImplyLeading: false,
            title: const Text('Rewards Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: kGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kGreen.withOpacity(0.3))),
                  child: const Icon(Icons.add_rounded, color: kGreen, size: 20),
                ),
                onPressed: _showForm,
              ),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: kGreen,
              indicatorWeight: 3,
              labelColor: kGreen,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: 'Rewards (${widget.rewards.length})'),
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Redemptions'),
                  if (pending > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                      child: Text('$pending', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ])),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildRewards(), _buildRedemptions()],
        ),
      ),
    );
  }

  Widget _buildRewards() {
    if (widget.rewards.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.card_giftcard_rounded, color: Colors.white24, size: 64),
        const SizedBox(height: 12),
        const Text('No rewards yet', style: TextStyle(color: Colors.white38, fontSize: 15)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showForm,
          style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add First Reward', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: widget.rewards.length,
      itemBuilder: (_, i) {
        final r = widget.rewards[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: r.isActive ? kGreen.withOpacity(0.2) : kBorder),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            leading: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: r.isActive ? kGreen.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: r.isActive ? kGreen.withOpacity(0.3) : kBorder),
              ),
              child: Icon(_catIcon(r.category), color: r.isActive ? kGreen : Colors.white24, size: 22),
            ),
            title: Row(children: [
              Expanded(child: Text(r.title, style: TextStyle(color: r.isActive ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.w600, fontSize: 14))),
              if (!r.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Inactive', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
            ]),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 2),
              Text(r.description, style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 12),
                const SizedBox(width: 3),
                Text('${r.pointsCost} pts', style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                  child: Text(r.category, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ),
              ]),
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () => _showForm(reward: r),
                child: Container(padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withOpacity(0.2))),
                    child: const Icon(Icons.edit_outlined, color: Colors.blue, size: 16)),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: kCard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Delete Reward', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      content: Text('Delete "${r.title}"?', style: const TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                        ElevatedButton(onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            child: const Text('Delete', style: TextStyle(color: Colors.white))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await FirebaseService.deleteReward(r.id!);
                    widget.onChanged();
                  }
                },
                child: Container(padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.2))),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 16)),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildRedemptions() {
    if (_loadingRedemptions) return const Center(child: CircularProgressIndicator(color: kGreen));

    if (_redemptions.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_rounded, color: Colors.white24, size: 64),
        SizedBox(height: 12),
        Text('No redemptions yet', style: TextStyle(color: Colors.white38, fontSize: 15)),
      ]));
    }

    final pending = _redemptions.where((r) => r.status == 'pending').toList();
    final claimed = _redemptions.where((r) => r.status == 'claimed').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        if (pending.isNotEmpty) ...[
          _sectionHeader('Pending Approval', Colors.orange, pending.length),
          const SizedBox(height: 10),
          ...pending.map((r) => _redemptionCard(r, isPending: true)),
          const SizedBox(height: 20),
        ],
        if (claimed.isNotEmpty) ...[
          _sectionHeader('Claimed', kGreen, claimed.length),
          const SizedBox(height: 10),
          ...claimed.map((r) => _redemptionCard(r, isPending: false)),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, Color color, int count) => Row(children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ]);

  Widget _redemptionCard(Redemption r, {required bool isPending}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPending ? Colors.orange.withOpacity(0.3) : kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isPending ? Colors.orange.withOpacity(0.1) : kGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                color: isPending ? Colors.orange : kGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.rewardTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(r.userEmail.isNotEmpty ? r.userEmail : r.userId.substring(0, 8),
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ])),
          Text('-${r.pointsUsed} pts', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        // Redemption code
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
          child: Row(children: [
            const Icon(Icons.confirmation_number_rounded, color: Colors.white38, size: 14),
            const SizedBox(width: 8),
            Text('Code: ', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            Text(r.redemptionCode,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2)),
            const Spacer(),
            Text(_formatDate(r.redeemedAt), style: const TextStyle(color: Colors.white24, fontSize: 10)),
          ]),
        ),
        if (isPending) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity, height: 40,
            child: ElevatedButton.icon(
              onPressed: () => _markClaimed(r),
              style: ElevatedButton.styleFrom(backgroundColor: kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
              icon: const Icon(Icons.check_rounded, color: Colors.black, size: 16),
              label: const Text('Mark as Claimed', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  IconData _catIcon(String cat) {
    switch (cat) {
      case 'Coffee': return Icons.coffee_rounded;
      case 'Food': return Icons.fastfood_rounded;
      case 'Discount': return Icons.local_offer_rounded;
      default: return Icons.card_giftcard_rounded;
    }
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: kGreen, size: 20),
          filled: true,
          fillColor: Colors.white.withOpacity(0.07),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
      );
}
