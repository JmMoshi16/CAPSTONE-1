import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';
import '../../widgets/eco_animations.dart';
import 'dart:async';
import 'reward_detail_screen.dart';

/// Category accent colours (decorative; text drawn in them goes through `colors.ink`).
const _catColors = AppPalette.categories;

class RewardsScreen extends StatefulWidget {
  final UserModel user;
  final List<Reward> rewards;
  final VoidCallback onRedeemed;
  const RewardsScreen({super.key, required this.user, required this.rewards, required this.onRedeemed});
  @override
  State<RewardsScreen> createState() => RewardsScreenState();
}

/// Public so Home can open the tab on a category (Quick Access) or on My Codes (notifications).
class RewardsScreenState extends State<RewardsScreen> with SingleTickerProviderStateMixin {
  void showCategory(String category) {
    _tabController.animateTo(0);
    setState(() => _selectedCategory = category);
  }

  void showMyCodes() => _tabController.animateTo(1);

  /// From Home's reward strip: the same detail-and-redeem flow as tapping the reward here.
  void openReward(Reward reward) => _redeem(reward);

  /// Swipe left / right on the grid: next / previous category.
  void _swipeCategory(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 250) return;
    final cats = _categories;
    final i = cats.indexOf(_selectedCategory);
    final next = (i + (v < 0 ? 1 : -1)).clamp(0, cats.length - 1);
    if (next == i) return;
    AppHaptics.tap();
    setState(() {
      _swipeForward = v < 0;
      _selectedCategory = cats[next];
    });
  }

  bool _swipeForward = true;

  /// Refreshes the live countdowns on My Codes (cheap: only while that tab shows).
  Timer? _countdown;

  late TabController _tabController;
  List<Redemption> _redemptions = [];
  // Start from what Home already loaded; a fresh copy is fetched in the background.
  late List<Reward> _rewards = widget.rewards;
  bool _loadingHistory = true;
  late bool _loadingRewards = widget.rewards.isEmpty;
  bool _rewardsError = false;
  bool _historyError = false;
  String _selectedCategory = 'All';
  /// Card entrance plays on the first visit of the session only.
  late final bool _animateCards = AppMotion.firstTime('rewards');
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _countdown = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _tabController.index == 1) setState(() {});
    });
    _loadRewards();
    _loadHistory();
  }

  Future<void> _loadRewards() async {
    try {
      final r = await FirebaseService.getRewards().timeout(const Duration(seconds: 10));
      if (mounted) setState(() { _rewards = r; _loadingRewards = false; _rewardsError = false; });
    } catch (_) {
      // A failed background refresh keeps the rewards already on screen.
      if (mounted) setState(() { _loadingRewards = false; _rewardsError = _rewards.isEmpty; });
    }
  }

  void _retryRewards() {
    setState(() { _loadingRewards = true; _rewardsError = false; });
    _loadRewards();
  }

  void _retryHistory() {
    setState(() { _loadingHistory = true; _historyError = false; });
    _loadHistory();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// "6d 4h left", "5h 12m left", "8m left".
  String _timeLeft(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h left';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m left';
    return '${d.inMinutes.clamp(1, 59)}m left';
  }

  Future<void> _loadHistory() async {
    try {
      final uid = FirebaseService.currentUid;
      if (uid == null) throw StateError('signed out');
      final r = await FirebaseService.getUserRedemptions(uid).timeout(const Duration(seconds: 10));
      if (mounted) setState(() { _redemptions = r; _loadingHistory = false; _historyError = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingHistory = false; _historyError = true; });
    }
  }

  List<Reward> get _filteredRewards {
    if (_selectedCategory == 'All') return _rewards;
    return _rewards.where((r) => r.category == _selectedCategory).toList();
  }

  List<String> get _categories => ['All', ..._rewards.map((r) => r.category).toSet()];

  Future<void> _redeem(Reward reward) async {
    // FIX 10: Block sold-out rewards at UI level too
    if (reward.stock == 0) return;

    // The detail page explains cost vs balance and asks for a press-and-hold to confirm
    // (it also shows how many points are missing, instead of a snackbar).
    final confirm = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => RewardDetailScreen(
        reward: reward,
        user: widget.user,
        heroTag: _rewardHeroTag(reward),
        icon: _catIcon(reward.category),
        color: _catColors[reward.category] ?? AppPalette.forest,
      ),
    ));

    if (confirm != true) return;
    // Busy overlay while the transaction runs (it used to happen invisibly, and a
    // network error was not caught at all).
    setState(() => _redeeming = true);
    try {
      final success = await FirebaseService.redeemReward(widget.user, reward).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (success) {
        AppHaptics.success();
        widget.onRedeemed();
        await _loadHistory();
        if (!mounted) return;
        setState(() => _redeeming = false);
        _tabController.animateTo(1);
        final latest = _redemptions.isNotEmpty ? _redemptions.first : null;
        if (latest != null) _showRedemptionCode(latest);
      } else {
        _showSnack("This reward just sold out, or you no longer have enough points.", context.colors.danger);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack("We couldn't confirm the redemption. Check your connection, then look in My Codes before trying again.",
          context.colors.danger);
    } finally {
      if (mounted && _redeeming) setState(() => _redeeming = false);
    }
  }

  void _showRedemptionCode(Redemption r) {
    showDialog(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        final t = ctx.text;
        return AlertDialog(
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.check_circle_rounded, color: c.success, size: 44),
            ),
            const SizedBox(height: AppSpace.md),
            Text('Reward redeemed', style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.xs - 2),
            Text(r.rewardTitle, style: t.bodyMedium!.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.lg),
            Text('Your Redemption Code', style: t.labelSmall),
            const SizedBox(height: AppSpace.xs),
            FlipReveal(delay: const Duration(milliseconds: 250), child: Tap(label: 'Copy redemption code ${r.redemptionCode}',
              onTap: () {
                Clipboard.setData(ClipboardData(text: r.redemptionCode));
                _showSnack('Code copied!', c.success);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md - 2),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: AppRadius.all(AppRadius.lg - 2),
                  border: Border.all(color: c.primary.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(spacedCode(r.redemptionCode),
                          style: t.headlineSmall!.copyWith(fontFamily: 'monospace', letterSpacing: 3, color: c.primary)),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm - 2),
                  Icon(Icons.copy_rounded, color: c.primary, size: 18),
                ]),
              ),
            )),
            const SizedBox(height: AppSpace.sm - 2),
            Text('Show this code to the staff to claim your reward',
                style: t.bodySmall, textAlign: TextAlign.center),
          ]),
          actions: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              AppButton(
                label: 'Show to staff',
                icon: Icons.fullscreen_rounded,
                height: 48,
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => StaffCodeScreen(redemption: r)));
                },
              ),
              const SizedBox(height: AppSpace.xs),
              AppButton.secondary(label: 'Got it!', height: 48, onPressed: () => Navigator.pop(ctx)),
            ]),
          ],
        );
      },
    );
  }

  void _showSnack(String msg, Color color) {
    final c = context.colors;
    AppSnackbar.show(context, msg,
        kind: color == c.danger ? SnackKind.error : color == c.success ? SnackKind.success : SnackKind.info);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      body: Stack(children: [
      NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: AppLayout.headerHeight(context, 184, perScale: 130),
            pinned: true,
            backgroundColor: c.background,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: c.background,
                child: SafeArea(
                  child: Padding(
                    // Bottom padding = the tab bar, which sits on top of this background.
                    padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, kTextTabBarHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rewards', style: t.headlineMedium),
                        const SizedBox(height: AppSpace.xxs),
                        Text('Spend your points at the counter', style: t.bodyMedium!.copyWith(color: c.textSecondary)),
                        const SizedBox(height: AppSpace.md - 2),
                        Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
                          _headerPill(Icons.stars_rounded, c.ink(c.gold), widget.user.points, bold: true),
                          Tap(
                            label: '${_redemptions.length} redeemed, open My Codes',
                            onTap: showMyCodes,
                            child: _headerPill(Icons.receipt_long_rounded, c.textSecondary, _redemptions.length),
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
              indicatorColor: c.primary,
              indicatorWeight: 3,
              labelColor: c.textPrimary,
              unselectedLabelColor: c.textSecondary,
              dividerColor: c.border,
              tabs: [
                Tab(text: 'Available (${_rewards.length})'),
                Tab(text: 'My Codes (${_redemptions.length})'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          // Horizontal swipes on the Available tab browse categories instead.
          physics: const NeverScrollableScrollPhysics(),
          children: [_buildAvailable(), _buildHistory()],
        ),
      ),
      if (_redeeming) const _RedeemingOverlay(),
      ]),
    );
  }

  /// [count] animates when it changes (e.g. after redeeming); bold = the points pill.
  Widget _headerPill(IconData icon, Color iconColor, int count, {bool bold = false}) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: bold ? 0 : AppSpace.md - 2, vertical: AppSpace.xs),
      decoration: bold
          ? null
          : BoxDecoration(
              color: c.surface,
              borderRadius: AppRadius.all(AppRadius.pill),
              border: Border.all(color: c.border),
            ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: AppSpace.xs - 2),
        AnimatedCount(count, suffix: bold ? ' pts available' : ' redeemed', style: context.text.labelMedium!.copyWith(
            color: bold ? c.textPrimary : c.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      ]),
    );
  }

  Widget _buildAvailable() {
    if (_loadingRewards) return const _RewardsGridSkeleton();
    if (_rewardsError) {
      return _refreshable(_loadRewards, ErrorState(
        title: "Couldn't load rewards",
        message: 'Check your connection, then try again.',
        onRetry: _retryRewards,
      ));
    }
    if (_rewards.isEmpty) {
      return _refreshable(_loadRewards, EmptyState(
        icon: Icons.card_giftcard_rounded,
        title: 'No rewards available yet',
        message: 'New rewards appear here as the café adds them.',
        actionLabel: 'Refresh',
        onAction: _retryRewards,
      ));
    }

    // Taller cards when the user enlarges text, so nothing is clipped.
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

    return GestureDetector(
      onHorizontalDragEnd: _swipeCategory,
      child: EcoRefresh(
      onRefresh: _loadRewards,
      child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Category filter chips
        SliverToBoxAdapter(
          child: SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xxs),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpace.xs),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                return AppChip(
                  label: cat,
                  semanticLabel: '$cat rewards',
                  icon: cat == 'All' ? null : _catIcon(cat),
                  selected: _selectedCategory == cat,
                  onTap: () => setState(() {
                    _swipeForward = _categories.indexOf(cat) >= _categories.indexOf(_selectedCategory);
                    _selectedCategory = cat;
                  }),
                );
              },
            ),
          ),
        ),

        // Rewards grid or empty state
        if (_filteredRewards.isEmpty)
          SliverFillRemaining(
            child: EmptyState(
              icon: _catIcon(_selectedCategory),
              title: 'No $_selectedCategory rewards yet',
              actionLabel: 'Show all rewards',
              onAction: () => setState(() => _selectedCategory = 'All'),
              dense: true,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xxs, AppSpace.md, AppSpace.navClearance),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppLayout.columns(context), crossAxisSpacing: AppSpace.sm, mainAxisSpacing: AppSpace.sm,
                childAspectRatio: 0.74 / textScale,
              ),
              delegate: SliverChildBuilderDelegate(
                // A category change slides the cards in from the swipe direction.
                (_, i) => TweenAnimationBuilder<double>(
                  key: ValueKey('$_selectedCategory#$i'),
                  tween: Tween(begin: 0, end: 1),
                  duration: AppMotion.of(context, AppMotion.medium),
                  curve: AppMotion.standard,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(offset: Offset((1 - v) * (_swipeForward ? 40 : -40), 0), child: child),
                  ),
                  child: _AnimatedRewardCard(
                    reward: _filteredRewards[i],
                    index: i,
                    onTap: () => _redeem(_filteredRewards[i]),
                    onPeek: () => _peekReward(_filteredRewards[i]),
                    user: widget.user,
                    catIcon: _catIcon,
                    animate: _animateCards,
                    heroTag: _rewardHeroTag(_filteredRewards[i]),
                  ),
                ),
                childCount: _filteredRewards.length,
              ),
            ),
          ),
      ],
    )));
  }

  /// Makes a centred state (empty / error) pull-to-refresh-able.
  Widget _refreshable(Future<void> Function() onRefresh, Widget child) => EcoRefresh(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
        ),
      );

  Widget _buildHistory() {
    final c = context.colors;
    if (_loadingHistory) {
      return const SkeletonList(count: 4, padding: EdgeInsets.all(AppSpace.md));
    }
    if (_historyError) {
      return _refreshable(_loadHistory, ErrorState(
        title: "Couldn't load your codes",
        message: 'Check your connection, then try again.',
        onRetry: _retryHistory,
      ));
    }
    if (_redemptions.isEmpty) {
      return _refreshable(_loadHistory, EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No redemptions yet',
        message: 'Redeem a reward to get your code',
        actionLabel: 'Browse rewards',
        onAction: () => _tabController.animateTo(0),
      ));
    }

    final pending = _redemptions.where((r) => r.status == 'pending').toList();
    final claimed = _redemptions.where((r) => r.status == 'claimed').toList();

    return EcoRefresh(
      onRefresh: _loadHistory,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.navClearance),
      children: [
        if (pending.isNotEmpty) ...[
          _sectionHeader('Pending Codes', Icons.hourglass_top_rounded, c.warning, pending.length),
          const SizedBox(height: AppSpace.sm - 2),
          ...pending.map((r) => _redemptionCard(r, isPending: true)),
          const SizedBox(height: AppSpace.lg),
        ],
        if (claimed.isNotEmpty) ...[
          _sectionHeader('Claimed', Icons.check_circle_rounded, c.success, claimed.length),
          const SizedBox(height: AppSpace.sm - 2),
          ...claimed.map((r) => _redemptionCard(r, isPending: false)),
        ],
      ],
    ));
  }

  Widget _sectionHeader(String title, IconData icon, Color color, int count) => Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: AppSpace.xs - 2),
        Text(title, style: context.text.titleSmall!.copyWith(color: color, fontWeight: FontWeight.w700)),
        const SizedBox(width: AppSpace.xs - 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppRadius.all(AppRadius.sm + 2)),
          child: Text('$count', style: context.text.labelSmall!.copyWith(color: color, fontWeight: FontWeight.w700)),
        ),
      ]);

  // FIX 9: Expiry countdown for pending redemptions
  /// My Codes entry as a ticket: a perforated stub on the right holds the points and status.
  Widget _redemptionCard(Redemption r, {required bool isPending}) {
    final c = context.colors;
    final t = context.text;
    final now = DateTime.now();
    final isExpired = isPending && now.isAfter(r.expiresAt);
    final left = r.expiresAt.difference(now);
    final urgent = isPending && !isExpired && left.inHours < 72;
    final statusColor = isExpired ? c.danger : (isPending ? c.warning : c.success);
    const stub = 92.0;

    return Tap(label: '${r.rewardTitle}, ${isPending && !isExpired ? 'show redemption code, ${_timeLeft(left)}' : 'details'}',
      onTap: (isPending && !isExpired) ? () => _showRedemptionCode(r) : () => _showCodeDetails(r, expired: isExpired),
      onLongPress: (isPending && !isExpired) ? () => _codeQuickActions(r) : null,
      longPressHint: 'quick actions',
      child: AnimatedOpacity(
        duration: AppMotion.of(context, AppMotion.medium),
        opacity: isExpired ? 0.6 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpace.sm),
          decoration: ShapeDecoration(
            color: isExpired ? c.surfaceAlt : c.surface,
            shape: TicketBorder(
              radius: AppRadius.lg + 2,
              stubFromRight: stub,
              side: BorderSide(color: isPending ? statusColor.withValues(alpha: 0.45) : c.border, width: 1.2),
            ),
            shadows: AppShadows.of(context, AppShadows.e1),
          ),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.md - 2, AppSpace.md - 2, AppSpace.sm, AppSpace.md - 2),
                  child: Row(children: [
                    IconBadge(
                      icon: isExpired ? Icons.timer_off_rounded : (isPending ? Icons.confirmation_number_rounded : Icons.check_circle_rounded),
                      color: statusColor,
                      size: 44,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.rewardTitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      if (isPending && !isExpired)
                        Row(children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
                              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: AppRadius.all(AppRadius.sm - 2)),
                              child: Text(spacedCode(r.redemptionCode),
                                  overflow: TextOverflow.ellipsis,
                                  style: t.labelMedium!.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w700,
                                      letterSpacing: 2, color: c.primary)),
                            ),
                          ),
                          Tap(label: 'Copy code', tooltip: true,
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: r.redemptionCode));
                              _showSnack('Code copied!', c.success);
                            },
                            child: Icon(Icons.copy_rounded, color: c.textSecondary, size: 18),
                          ),
                        ])
                      else
                        Text(isExpired ? 'Expired ${_formatDate(r.expiresAt)}' : 'Claimed · ${_formatDate(r.redeemedAt)}',
                            style: t.labelSmall!.copyWith(color: isExpired ? c.danger : c.textSecondary,
                                fontWeight: isExpired ? FontWeight.w700 : FontWeight.w600)),
                      // Live countdown (refreshed every 30 s while this tab is open).
                      if (isPending && !isExpired)
                        Row(children: [
                          Icon(Icons.schedule_rounded, size: 14, color: urgent ? c.warning : c.textTertiary),
                          const SizedBox(width: 3),
                          Flexible(child: Text(_timeLeft(left),
                              style: t.labelSmall!.copyWith(color: urgent ? c.warning : c.textSecondary,
                                  fontWeight: urgent ? FontWeight.w800 : FontWeight.w600))),
                        ]),
                    ])),
                  ]),
                ),
              ),
              // Stub
              SizedBox(
                width: stub,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: AppSpace.sm),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('-${r.pointsUsed}',
                          style: t.titleLarge!.copyWith(fontFamily: AppType.displayFamily, color: c.danger)),
                    ),
                    Text('pts', style: t.labelSmall),
                    const SizedBox(height: AppSpace.xxs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: AppRadius.all(AppRadius.sm)),
                      child: Text(
                        isExpired ? 'Expired' : (isPending ? 'Ready' : 'Claimed'),
                        style: t.labelSmall!.copyWith(color: statusColor, fontWeight: FontWeight.w700),
                      ),
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

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _rewardHeroTag(Reward r) => 'reward-${r.id ?? r.title}';

  /// Long-press on a reward card: what it costs and whether you can redeem, without leaving.
  void _peekReward(Reward reward) {
    final c = context.colors;
    final t = context.text;
    final soldOut = reward.stock == 0;
    final missing = reward.pointsCost - widget.user.points;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.md),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconBadge(icon: _catIcon(reward.category), color: _catColors[reward.category] ?? c.primary, size: 52, filled: true),
              const SizedBox(width: AppSpace.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reward.title, style: t.titleLarge),
                Text('${reward.pointsCost} pts', style: t.titleSmall!.copyWith(color: c.primary)),
              ])),
            ]),
            const SizedBox(height: AppSpace.sm),
            Text(reward.description, style: t.bodyMedium!.copyWith(color: c.textSecondary)),
            const SizedBox(height: AppSpace.sm),
            PointsPill(
              soldOut ? 'Sold out' : missing <= 0 ? 'You can redeem this' : '$missing more points needed',
              color: soldOut ? c.danger : missing <= 0 ? c.success : c.warning,
            ),
            const SizedBox(height: AppSpace.lg),
            if (!soldOut)
              AppButton(label: 'Open', trailingIcon: Icons.arrow_forward_rounded, onPressed: () {
                Navigator.pop(ctx);
                _redeem(reward);
              }),
          ]),
        ),
      ),
    );
  }

  /// Long-press on a ready code: the three things people do with it.
  void _codeQuickActions(Redemption r) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xs),
            child: Text(r.rewardTitle, style: ctx.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Copy code'),
            subtitle: Text(spacedCode(r.redemptionCode)),
            onTap: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: r.redemptionCode));
              AppSnackbar.success(context, 'Code copied');
            },
          ),
          ListTile(
            leading: const Icon(Icons.fullscreen_rounded),
            title: const Text('Show to staff'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => StaffCodeScreen(redemption: r)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.confirmation_number_outlined),
            title: const Text('Open code'),
            onTap: () {
              Navigator.pop(ctx);
              _showRedemptionCode(r);
            },
          ),
          const SizedBox(height: AppSpace.sm),
        ]),
      ),
    );
  }

  /// Read-only details for a claimed or expired code (these cards used to do nothing).
  void _showCodeDetails(Redemption r, {required bool expired}) {
    final c = context.colors;
    final t = context.text;
    AppSheet.show(
      context,
      title: r.rewardTitle,
      initialSize: 0.45,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xl),
        children: [
          Center(child: PointsPill(expired ? 'Expired' : 'Claimed', color: expired ? c.danger : c.success)),
          const SizedBox(height: AppSpace.md),
          Center(child: Text(spacedCode(r.redemptionCode),
              style: t.headlineSmall!.copyWith(fontFamily: 'monospace', letterSpacing: 3,
                  color: c.textTertiary, decoration: TextDecoration.lineThrough))),
          const SizedBox(height: AppSpace.lg),
          _detailRow(ctx, 'Redeemed', _formatDate(r.redeemedAt)),
          _detailRow(ctx, expired ? 'Expired' : 'Valid until', _formatDate(r.expiresAt)),
          _detailRow(ctx, 'Points used', '${r.pointsUsed} pts'),
          const SizedBox(height: AppSpace.md),
          Text(expired
              ? "This code wasn't picked up in time, so it can no longer be used."
              : 'Staff have already handed this reward over.', style: t.bodySmall),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext ctx, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Row(children: [
          Expanded(child: Text(k, style: ctx.text.bodyMedium!.copyWith(color: ctx.colors.textSecondary))),
          Text(v, style: ctx.text.titleSmall),
        ]),
      );

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
  /// Long-press: a quick peek without leaving the grid.
  final VoidCallback onPeek;
  final UserModel user;
  final IconData Function(String) catIcon;
  final bool animate;
  final String heroTag;
  const _AnimatedRewardCard({required this.reward, required this.index, required this.onTap, required this.user,
      required this.catIcon, required this.animate, required this.heroTag, required this.onPeek});
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
    _ctrl  = AnimationController(vsync: this, duration: AppMotion.slow);
    _scale = Tween<double>(begin: 0.9, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: AppMotion.spring));
    _fade  = CurvedAnimation(parent: _ctrl, curve: AppMotion.standard);
    if (!widget.animate) {
      _ctrl.value = 1;
      return;
    }
    final delay = AppMotion.stagger * widget.index;
    Future.delayed(AppMotion.fast + (delay > AppMotion.slow ? AppMotion.slow : delay), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _ctrl.value = 1;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Widget _maybeShine({required bool locked, required Widget child}) => child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final isSoldOut = widget.reward.stock == 0;
    final isLowStock = widget.reward.stock > 0 && widget.reward.stock <= 5;
    final canAfford = widget.user.points >= widget.reward.pointsCost && !isSoldOut;
    final progress  = (widget.user.points / widget.reward.pointsCost).clamp(0.0, 1.0);
    final catColor = _catColors[widget.reward.category] ?? c.primary;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: PressScale(
          label: '${widget.reward.title}, ${widget.reward.pointsCost} points${isSoldOut ? ', sold out' : ''}',
          // FIX 10: Disable tap for sold-out rewards
          onTap: isSoldOut ? null : widget.onTap,
          onLongPress: widget.onPeek,
          longPressHint: 'peek at this reward',
          scale: 0.97,
          child: Container(
            clipBehavior: Clip.antiAlias,
            // Affordable rewards get a brand-coloured hairline.
            decoration: cardDecoration(context, borderColor: canAfford ? c.primary.withValues(alpha: 0.5) : null),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // FIX 10: Image area with sold-out overlay
              _maybeShine(locked: !canAfford && !isSoldOut, child: Stack(children: [
                Container(
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: (canAfford || isLowStock)
                          ? [catColor.withValues(alpha: 0.8), catColor]
                          : [c.surfaceAlt, c.border],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(children: [
                    Center(child: HeroMode(
                      enabled: !AppMotion.reduced(context),
                      child: Hero(
                        tag: widget.heroTag,
                        flightShuttleBuilder: heroMaterialFlight,
                        child: Icon(widget.catIcon(widget.reward.category),
                            color: (canAfford || isLowStock) ? Colors.white : c.textTertiary, size: 40),
                      ),
                    )),
                    if (canAfford)
                      Positioned(top: AppSpace.xs, right: AppSpace.xs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.all(AppRadius.sm + 2)),
                          child: Text('Redeem', style: t.labelSmall!.copyWith(color: AppPalette.forest, fontWeight: FontWeight.w700)),
                        )),
                    Positioned(bottom: AppSpace.xs, left: AppSpace.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: AppRadius.all(AppRadius.sm)),
                        child: Text(widget.reward.category, style: t.labelSmall!.copyWith(color: Colors.white)),
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
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs - 2),
                        decoration: BoxDecoration(color: AppPalette.soldOut, borderRadius: AppRadius.all(AppRadius.sm)),
                        child: Text('SOLD OUT',
                            style: t.labelMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                      ),
                    ),
                  ),
              ])),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.sm - 2),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.reward.title,
                        style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700,
                            color: isSoldOut ? c.textTertiary : c.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(widget.reward.description, style: t.labelSmall!.copyWith(fontWeight: FontWeight.w400),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    // FIX 10: Low stock warning label
                    if (isLowStock)
                      Text('Only ${widget.reward.stock} left!',
                          style: t.labelSmall!.copyWith(color: c.warning, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (!canAfford && !isSoldOut) ...[
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Flexible(child: Text('${widget.user.points}/${widget.reward.pointsCost}', style: t.labelSmall,
                            maxLines: 1, overflow: TextOverflow.fade, softWrap: false)),
                        const SizedBox(width: AppSpace.xxs),
                        Flexible(child: Text('${((1 - progress) * widget.reward.pointsCost).round()} more', style: t.labelSmall,
                            maxLines: 1, overflow: TextOverflow.fade, softWrap: false)),
                      ]),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: AppRadius.all(4),
                        child: LinearProgressIndicator(value: progress, backgroundColor: c.surfaceAlt,
                            valueColor: AlwaysStoppedAnimation(catColor), minHeight: 4),
                      ),
                      const SizedBox(height: AppSpace.xs - 2),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                      decoration: BoxDecoration(
                        color: canAfford ? c.primary : c.surfaceAlt,
                        borderRadius: AppRadius.all(AppRadius.sm + 2),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(
                          isSoldOut ? Icons.block_rounded : Icons.stars_rounded,
                          color: canAfford ? AppPalette.coin[1] : c.textTertiary,
                          size: 14,
                        ),
                        const SizedBox(width: AppSpace.xxs),
                        Flexible(child: Text(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          isSoldOut ? 'Sold Out' : '${widget.reward.pointsCost} pts',
                          style: t.labelMedium!.copyWith(
                            color: canAfford ? c.onPrimary : c.textSecondary,
                            fontWeight: FontWeight.w700,
                          )),
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

/// Redemption code shown as two groups of four ("ABCD EFGH") so staff can read it aloud.
/// Display only: the stored and copied code is unchanged.
String spacedCode(String code) =>
    code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;

// ── Rewards grid skeleton ─────────────────────────────────────────────────────
class _RewardsGridSkeleton extends StatelessWidget {
  const _RewardsGridSkeleton();

  @override
  Widget build(BuildContext context) => Skeleton(
        label: 'Loading rewards',
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(children: [
            const Row(children: [
              SkeletonBox(width: 56, height: 32, radius: AppRadius.pill),
              SizedBox(width: AppSpace.xs),
              SkeletonBox(width: 88, height: 32, radius: AppRadius.pill),
              SizedBox(width: AppSpace.xs),
              SkeletonBox(width: 72, height: 32, radius: AppRadius.pill),
            ]),
            const SizedBox(height: AppSpace.md),
            Expanded(
              child: GridView.count(
                crossAxisCount: AppLayout.columns(context),
                crossAxisSpacing: AppSpace.sm,
                mainAxisSpacing: AppSpace.sm,
                childAspectRatio: 0.74,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(4, (_) => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SkeletonBox(height: 88, radius: AppRadius.xl),
                  SizedBox(height: AppSpace.sm),
                  SkeletonBox(width: 110, height: 14),
                  SizedBox(height: AppSpace.xs),
                  SkeletonBox(width: 80, height: 12),
                  Spacer(),
                  SkeletonBox(height: 32, radius: AppRadius.sm + 2),
                ])),
              ),
            ),
          ]),
        ),
      );
}

// ── Staff view of a redemption code ───────────────────────────────────────────
/// Full-screen, maximum-contrast code for the counter: black on white in every theme,
/// very large monospaced characters, the reward name and the expiry date.
class StaffCodeScreen extends StatelessWidget {
  const StaffCodeScreen({super.key, required this.redemption});

  final Redemption redemption;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    const ink = Color(0xFF000000);
    final e = redemption.expiresAt;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        title: const Text('Show this to staff'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(children: [
            const Spacer(),
            Text(redemption.rewardTitle, textAlign: TextAlign.center,
                style: t.headlineSmall!.copyWith(color: ink)),
            const SizedBox(height: AppSpace.xl),
            Semantics(
              label: 'Redemption code ${redemption.redemptionCode.split('').join(' ')}',
              excludeSemantics: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xl, horizontal: AppSpace.md),
                decoration: BoxDecoration(
                  border: Border.all(color: ink, width: 3),
                  borderRadius: AppRadius.all(AppRadius.xl),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(spacedCode(redemption.redemptionCode),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 56, fontWeight: FontWeight.w900,
                          letterSpacing: 4, color: ink)),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text('${redemption.pointsUsed} pts · valid until ${months[e.month - 1]} ${e.day}, ${e.year}',
                style: t.titleSmall!.copyWith(color: const Color(0xFF333333))),
            const Spacer(),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                side: const BorderSide(color: ink, width: 1.5),
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: redemption.redemptionCode));
                AppSnackbar.success(context, 'Code copied');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy code'),
            ),
            const SizedBox(height: AppSpace.sm),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ink, foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Blocks the screen with a calm "Redeeming…" card while the redemption is written.
class _RedeemingOverlay extends StatelessWidget {
  const _RedeemingOverlay();

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Stack(children: [
          const ModalBarrier(dismissible: false, color: Colors.black45),
          Center(
            child: Semantics(
              liveRegion: true,
              label: 'Redeeming your reward',
              child: Container(
                padding: const EdgeInsets.all(AppSpace.xl),
                decoration: cardDecoration(context),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const EcoLoader(size: 72, semanticLabel: 'Redeeming'),
                  const SizedBox(height: AppSpace.sm),
                  Text('Redeeming…', style: context.text.titleMedium),
                ]),
              ),
            ),
          ),
        ]),
      );
}
