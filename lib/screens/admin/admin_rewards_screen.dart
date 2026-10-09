import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../core/admin_theme.dart';
import '../../widgets/ui.dart';

const kGreen = kAdminGreen;
const kDarkGreen = kAdminDGreen;
const kDark = kAdminDark;
const kCard = kAdminCard;
const kBorder = kAdminBorder;


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
  bool _redemptionsError = false;
  String _codeQuery = '';
  final Set<String> _claiming = {};
  /// Rewards deleted but still undoable (hidden until the Undo snackbar closes).
  final Set<String> _hidden = {};
  List<Reward> get _visibleRewards => widget.rewards.where((r) => !_hidden.contains(r.id)).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRedemptions();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadRedemptions() async {
    try {
      final r = await FirebaseService.getAllRedemptions().timeout(const Duration(seconds: 15));
      if (mounted) setState(() { _redemptions = r; _loadingRedemptions = false; _redemptionsError = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingRedemptions = false; _redemptionsError = true; });
    }
  }

  void _snack(String msg, {bool error = false}) =>
      AppSnackbar.show(context, msg, kind: error ? SnackKind.error : SnackKind.success);

  void _showForm({Reward? reward}) {
    final titleCtrl = TextEditingController(text: reward?.title ?? '');
    final descCtrl = TextEditingController(text: reward?.description ?? '');
    final pointsCtrl = TextEditingController(text: reward?.pointsCost.toString() ?? '');
    // Blank = unlimited (-1). Audit M-12: stock could not be set from any admin UI.
    final stockCtrl = TextEditingController(
        text: (reward == null || reward.stock == -1) ? '' : reward.stock.toString());
    String category = reward?.category ?? 'Coffee';
    bool isActive = reward?.isActive ?? true;
    final formKey = GlobalKey<FormState>();
    bool saving = false;   // disables Save while writing (a double tap used to add the reward twice)
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
            // Inline validation: each field shows its message as soon as it has been touched.
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: AppSpace.md),
                Text(reward == null ? 'Add New Reward' : 'Edit Reward',
                    style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: AppSpace.md),
                _field(titleCtrl, 'Title', Icons.title_rounded),
                const SizedBox(height: 10),
                _field(descCtrl, 'Description', Icons.description_rounded),
                const SizedBox(height: 10),
                _field(pointsCtrl, 'Points Cost', Icons.stars_rounded, keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v!.trim()) ?? 0) > 0 ? null : 'Enter a whole number above 0'),
                const SizedBox(height: 10),
                _field(stockCtrl, 'Stock (leave blank for unlimited)', Icons.inventory_2_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.trim().isEmpty || (int.tryParse(v.trim()) ?? -1) >= 0
                        ? null : 'Enter 0 or more, or leave blank'),
                const SizedBox(height: 10),
                // Category dropdown
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: kCard,
                  style: const TextStyle(color: AdminColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: const TextStyle(color: AdminColors.textSecondary),
                    prefixIcon: const Icon(Icons.category_rounded, color: kGreen, size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: categories.map((c) => DropdownMenuItem(value: c,
                      child: Row(children: [
                        Icon(_catIcon(c), size: 16, color: AdminColors.textSecondary),
                        const SizedBox(width: AppSpace.xs),
                        Text(c),
                      ]))).toList(),
                  onChanged: (v) => setS(() => category = v!),
                ),
                const SizedBox(height: 10),
                // Active toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpace.xxs),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.toggle_on_rounded, color: kGreen, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Active (visible to customers)', style: TextStyle(color: AdminColors.textSecondary, fontSize: 13))),
                    Switch(value: isActive, onChanged: (v) => setS(() => isActive = v),
                        activeThumbColor: kGreen, activeTrackColor: kGreen.withValues(alpha: 0.3)),
                  ]),
                ),
                const SizedBox(height: AppSpace.lg),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: saving ? null : () async {
                      if (!formKey.currentState!.validate()) {
                        AppHaptics.error();
                        return;
                      }
                      setS(() => saving = true);
                      final r = Reward(
                        id: reward?.id,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        pointsCost: int.parse(pointsCtrl.text.trim()),
                        category: category,
                        isActive: isActive,
                        stock: int.tryParse(stockCtrl.text.trim()) ?? -1,
                      );
                      try {
                        if (reward == null) {
                          await FirebaseService.addReward(r);
                        } else {
                          // Only the fields the admin changed: a redemption may have lowered the
                          // stock while this form was open (audit M-12).
                          final changes = r.toMap()
                            ..removeWhere((k, v) => reward.toMap()[k] == v);
                          if (changes.isNotEmpty) await FirebaseService.updateReward(reward.id!, changes);
                        }
                        widget.onChanged();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) _snack(reward == null ? '"${r.title}" added' : 'Changes saved');
                      } catch (_) {
                        if (ctx.mounted) {
                          setS(() => saving = false);
                          AppSnackbar.error(ctx, 'Could not save the reward. Check your connection and try again.');
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: kGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    child: saving
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AdminColors.onAccent))
                        : Text(reward == null ? 'Add Reward' : 'Save Changes',
                            style: const TextStyle(color: AdminColors.onAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Staff confirm with the code in front of them before a reward is handed over.
  Future<void> _markClaimed(Redemption r) async {
    final expired = DateTime.now().isAfter(r.expiresAt);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hand over this reward?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.rewardTitle, style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          if (r.userEmail.isNotEmpty)
            Text(r.userEmail, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13)),
          const SizedBox(height: AppSpace.md),
          const Text("Check this matches the code on the customer's phone:",
              style: TextStyle(color: AdminColors.textSecondary, fontSize: 13)),
          const SizedBox(height: AppSpace.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AdminColors.border)),
            alignment: Alignment.center,
            child: Text(_spaced(r.redemptionCode),
                style: const TextStyle(color: AdminColors.textPrimary, fontFamily: 'monospace',
                    fontWeight: FontWeight.w900, fontSize: 28, letterSpacing: 3)),
          ),
          if (expired) ...[
            const SizedBox(height: AppSpace.sm),
            Container(
              padding: const EdgeInsets.all(AppSpace.sm),
              decoration: BoxDecoration(color: AdminColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AdminColors.danger.withValues(alpha: 0.5))),
              child: Row(children: [
                const Icon(Icons.timer_off_rounded, color: AdminColors.danger, size: 18),
                const SizedBox(width: AppSpace.xs),
                Expanded(child: Text('This code expired on ${_formatDate(r.expiresAt)}.',
                    style: const TextStyle(color: AdminColors.danger, fontWeight: FontWeight.w600, fontSize: 13))),
              ]),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AdminColors.textSecondary))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark as Claimed')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _claiming.add(r.id!));
    try {
      await FirebaseService.claimRedemption(r.id!);
      await _loadRedemptions();
      if (mounted) _snack('"${r.rewardTitle}" marked as claimed');
    } catch (_) {
      if (mounted) _snack("Couldn't mark it as claimed. Check your connection and try again.", error: true);
    } finally {
      if (mounted) setState(() => _claiming.remove(r.id));
    }
  }

  /// "ABCD EFGH" for reading aloud; matching ignores spaces and case.
  String _spaced(String code) => code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;

  bool _matches(Redemption r) {
    final q = _codeQuery.replaceAll(' ', '').toUpperCase();
    if (q.isEmpty) return true;
    return r.redemptionCode.toUpperCase().contains(q) ||
        r.userEmail.toUpperCase().contains(q) ||
        r.rewardTitle.toUpperCase().contains(q);
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
            title: const Text('Rewards Manager', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                tooltip: 'Add reward',
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kGreen.withValues(alpha: 0.3))),
                  child: const Icon(Icons.add_rounded, color: kGreen, size: 20),
                ),
                onPressed: _showForm,
              ),
              const SizedBox(width: AppSpace.xs),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: kGreen,
              indicatorWeight: 3,
              labelColor: kGreen,
              unselectedLabelColor: AdminColors.textTertiary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: 'Rewards (${widget.rewards.length})'),
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Redemptions'),
                  if (pending > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AdminColors.orange, borderRadius: BorderRadius.circular(10)),
                      child: Text('$pending', style: const TextStyle(color: AdminColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
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
      return EmptyState(
        icon: Icons.card_giftcard_rounded,
        title: 'No rewards yet',
        message: 'Add the first reward customers can redeem.',
        actionLabel: 'Add First Reward',
        onAction: _showForm,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => widget.onChanged(),
      child: ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, 110),
      itemCount: _visibleRewards.length,
      itemBuilder: (_, i) {
        final r = _visibleRewards[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: r.isActive ? kGreen.withValues(alpha: 0.2) : kBorder),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpace.xs),
            leading: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: r.isActive ? kGreen.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: r.isActive ? kGreen.withValues(alpha: 0.3) : kBorder),
              ),
              child: Icon(_catIcon(r.category), color: r.isActive ? kGreen : AdminColors.textTertiary, size: 22),
            ),
            title: Row(children: [
              Expanded(child: Text(r.title, style: TextStyle(color: r.isActive ? AdminColors.textPrimary : AdminColors.textTertiary,
                  fontWeight: FontWeight.w600, fontSize: 14))),
              if (!r.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AdminColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Inactive', style: TextStyle(color: AdminColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ]),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 2),
              Text(r.description, style: const TextStyle(color: AdminColors.textTertiary, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpace.xxs),
              Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xxs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.stars_rounded, color: AdminColors.gold, size: 12),
                  const SizedBox(width: 3),
                  Text('${r.pointsCost} pts', style: const TextStyle(color: AdminColors.gold, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
                  child: Text(r.category, style: const TextStyle(color: AdminColors.textTertiary, fontSize: 11)),
                ),
              ]),
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Tap(
                label: 'Edit ${r.title}',
                tooltip: true,
                onTap: () => _showForm(reward: r),
                child: Container(padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: AdminColors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminColors.blue.withValues(alpha: 0.2))),
                    child: const Icon(Icons.edit_outlined, color: AdminColors.blue, size: 16)),
              ),
              const SizedBox(width: 6),
              Tap(
                label: 'Delete ${r.title}',
                tooltip: true,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: kCard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Delete Reward', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
                      content: Text('Delete "${r.title}"?', style: const TextStyle(color: AdminColors.textSecondary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel', style: TextStyle(color: AdminColors.textSecondary))),
                        ElevatedButton(onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.dangerFill, elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            child: const Text('Delete', style: TextStyle(color: AdminColors.textPrimary))),
                      ],
                    ),
                  );
                  if (confirm != true || !mounted) return;
                  // Hide it at once and offer Undo; the delete runs only when the snackbar closes.
                  setState(() => _hidden.add(r.id!));
                  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
                  final reason = await messenger.showSnackBar(SnackBar(
                    content: Text('"${r.title}" deleted', style: const TextStyle(color: AdminColors.textPrimary)),
                    backgroundColor: AdminColors.cardAlt,
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(label: 'Undo', textColor: AdminColors.accent, onPressed: () {}),
                  )).closed;
                  if (reason == SnackBarClosedReason.action) {
                    if (mounted) setState(() => _hidden.remove(r.id));
                    return;
                  }
                  try {
                    await FirebaseService.deleteReward(r.id!);
                    widget.onChanged();
                  } catch (_) {
                    if (mounted) {
                      setState(() => _hidden.remove(r.id));
                      _snack("Couldn't delete the reward. Check your connection and try again.", error: true);
                    }
                  }
                },
                child: Container(padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: AdminColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminColors.danger.withValues(alpha: 0.2))),
                    child: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: 16)),
              ),
            ]),
          ),
        );
      },
    ));
  }

  Widget _buildRedemptions() {
    if (_loadingRedemptions) return const SkeletonList(count: 5);
    if (_redemptionsError) {
      return ErrorState(
        title: "Couldn't load redemptions",
        message: 'Check your connection, then try again.',
        onRetry: () {
          setState(() { _loadingRedemptions = true; _redemptionsError = false; });
          _loadRedemptions();
        },
      );
    }
    if (_redemptions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRedemptions,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverFillRemaining(hasScrollBody: false, child: EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No redemptions yet',
            message: 'Codes appear here when customers redeem a reward.',
            actionLabel: 'Refresh',
            onAction: _loadRedemptions,
          )),
        ]),
      );
    }

    final now = DateTime.now();
    final shown = _redemptions.where(_matches).toList();
    final pending = shown.where((r) => r.status == 'pending' && !now.isAfter(r.expiresAt)).toList();
    final expired = shown.where((r) => r.status == 'pending' && now.isAfter(r.expiresAt)).toList();
    final claimed = shown.where((r) => r.status == 'claimed').toList();

    return RefreshIndicator(
      onRefresh: _loadRedemptions,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, 110),
      children: [
        // Staff type the code the customer shows (spaces and case ignored).
        TextField(
          onChanged: (v) => setState(() => _codeQuery = v),
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: AdminColors.textPrimary, fontFamily: 'monospace', letterSpacing: 2),
          decoration: InputDecoration(
            hintText: 'Find a code, email or reward',
            hintStyle: const TextStyle(color: AdminColors.textTertiary, letterSpacing: 0, fontFamily: 'Roboto'),
            prefixIcon: const Icon(Icons.search_rounded, color: AdminColors.textTertiary),
            filled: true,
            fillColor: kDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AdminColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AdminColors.border)),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        if (shown.isEmpty)
          EmptyState(icon: Icons.search_off_rounded, title: 'No match for "$_codeQuery"',
              message: 'Check the code on the customer\'s phone.', dense: true),
        if (pending.isNotEmpty) ...[
          _sectionHeader('Waiting for pickup', AdminColors.orange, pending.length),
          const SizedBox(height: AppSpace.sm - 2),
          ...pending.map((r) => _redemptionCard(r, isPending: true)),
          const SizedBox(height: AppSpace.lg),
        ],
        if (expired.isNotEmpty) ...[
          _sectionHeader('Expired, not picked up', AdminColors.danger, expired.length),
          const SizedBox(height: AppSpace.sm - 2),
          ...expired.map((r) => _redemptionCard(r, isPending: true, isExpired: true)),
          const SizedBox(height: AppSpace.lg),
        ],
        if (claimed.isNotEmpty) ...[
          _sectionHeader('Claimed', kGreen, claimed.length),
          const SizedBox(height: AppSpace.sm - 2),
          ...claimed.map((r) => _redemptionCard(r, isPending: false)),
        ],
      ],
    ));
  }

  Widget _sectionHeader(String title, Color color, int count) => Row(children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: AppSpace.xs),
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(width: AppSpace.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ]);

  Widget _redemptionCard(Redemption r, {required bool isPending, bool isExpired = false}) {
    final accent = isExpired ? AdminColors.danger : (isPending ? AdminColors.orange : kGreen);
    final busy = _claiming.contains(r.id);
    return _copyOnLongPress(r, Container(
      margin: const EdgeInsets.only(bottom: AppSpace.sm - 2),
      padding: const EdgeInsets.all(AppSpace.md - 2),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: isPending ? accent.withValues(alpha: 0.45) : kBorder, width: isExpired ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(isExpired ? Icons.timer_off_rounded : (isPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded),
                color: accent, size: 22),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.rewardTitle, style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(r.userEmail.isNotEmpty ? r.userEmail : r.userId.substring(0, 8),
                style: const TextStyle(color: AdminColors.textTertiary, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('-${r.pointsUsed} pts', style: const TextStyle(color: AdminColors.danger, fontWeight: FontWeight.bold, fontSize: 13)),
            if (isExpired)
              Container(
                margin: const EdgeInsets.only(top: AppSpace.xxs),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
                decoration: BoxDecoration(color: AdminColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Text('EXPIRED', style: TextStyle(color: AdminColors.danger, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
              ),
          ]),
        ]),
        const SizedBox(height: AppSpace.sm - 2),
        // Redemption code
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
          decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(AppRadius.sm + 2), border: Border.all(color: kBorder)),
          child: Row(children: [
            const Icon(Icons.confirmation_number_rounded, color: AdminColors.textTertiary, size: 16),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Text(_spaced(r.redemptionCode),
                  style: TextStyle(color: AdminColors.textPrimary, fontFamily: 'monospace', fontWeight: FontWeight.w800,
                      fontSize: 18, letterSpacing: 2,
                      decoration: isExpired ? TextDecoration.lineThrough : null,
                      decorationColor: AdminColors.danger)),
            ),
            Text(isPending ? (isExpired ? 'Expired ${_formatDate(r.expiresAt)}' : 'Until ${_formatDate(r.expiresAt)}')
                    : _formatDate(r.redeemedAt),
                style: TextStyle(color: isExpired ? AdminColors.danger : AdminColors.textTertiary, fontSize: 11)),
          ]),
        ),
        if (isPending) ...[
          const SizedBox(height: AppSpace.sm - 2),
          SizedBox(
            width: double.infinity, height: 48,
            child: isExpired
                ? OutlinedButton.icon(
                    onPressed: busy ? null : () => _markClaimed(r),
                    style: OutlinedButton.styleFrom(foregroundColor: AdminColors.danger,
                        side: BorderSide(color: AdminColors.danger.withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm + 2))),
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: const Text('Review expired code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  )
                : ElevatedButton.icon(
                    onPressed: busy ? null : () => _markClaimed(r),
                    style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm + 2))),
                    icon: busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.onAccent))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(busy ? 'Saving…' : 'Mark as Claimed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
          ),
        ],
      ]),
    ));
  }

  /// Long-press a redemption to copy its code (handy when typing it elsewhere).
  Widget _copyOnLongPress(Redemption r, Widget child) => Semantics(
        onLongPressHint: 'copy the code',
        onLongPress: () => _copyCode(r),
        child: GestureDetector(onLongPress: () => _copyCode(r), child: child),
      );

  void _copyCode(Redemption r) {
    AppHaptics.primary();
    Clipboard.setData(ClipboardData(text: r.redemptionCode));
    AppSnackbar.success(context, 'Code ${r.redemptionCode} copied');
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

  Widget _field(TextEditingController ctrl, String label, IconData icon,
          {TextInputType keyboardType = TextInputType.text, FormFieldValidator<String>? validator}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: AdminColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AdminColors.textSecondary),
          prefixIcon: Icon(icon, color: kGreen, size: 20),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        validator: validator ?? (v) => v!.trim().isEmpty ? 'Required' : null,
      );
}
