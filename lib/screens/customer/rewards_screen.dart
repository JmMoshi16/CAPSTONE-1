import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';
import '../../widgets/eco_animations.dart';
import 'dart:async';
import 'account_sheets.dart';
import 'reward_detail_screen.dart';
import 'reward_row.dart';

class RewardsScreen extends StatefulWidget {
  final UserModel user;
  final List<Reward> rewards;
  final VoidCallback onRedeemed;
  /// The customer's codes, live; defaults to Firestore (tests pass their own).
  final Stream<List<Redemption>>? codes;
  const RewardsScreen({super.key, required this.user, required this.rewards, required this.onRedeemed, this.codes});
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

  /// Which way the menu slides when the category changes (towards the chip that was tapped).
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

  /// Home reloads rewards after every scan and redemption; show its fresh list (stock, prices).
  @override
  void didUpdateWidget(RewardsScreen old) {
    super.didUpdateWidget(old);
    if (!identical(old.rewards, widget.rewards) && widget.rewards.isNotEmpty) _rewards = widget.rewards;
  }

  @override
  void dispose() {
    _codesSub?.cancel();
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

  StreamSubscription<List<Redemption>>? _codesSub;

  /// Listens to the customer's codes (a claim on the console shows up here live). Completes on the first answer, so
  /// pull-to-refresh and Retry can await it.
  Future<void> _loadHistory() {
    final first = Completer<void>();
    void fail(Object _) {
      if (mounted) setState(() { _loadingHistory = false; _historyError = true; });
      if (!first.isCompleted) first.complete();
    }
    _codesSub?.cancel();
    try {
      final stream = widget.codes ?? switch (FirebaseService.currentUid) {
        final String uid => FirebaseService.watchUserRedemptions(uid),
        null => Stream<List<Redemption>>.error(StateError('signed out')),
      };
      _codesSub = stream.listen((r) {
        if (mounted) setState(() { _redemptions = r; _loadingHistory = false; _historyError = false; });
        if (!first.isCompleted) first.complete();
      }, onError: fail);
    } catch (e) {
      fail(e);
    }
    return first.future.timeout(const Duration(seconds: 10), onTimeout: () {
      if (_loadingHistory) fail(TimeoutException('codes'));
    });
  }

  List<Reward> get _filteredRewards {
    if (_selectedCategory == 'All') return _rewards;
    return _rewards.where((r) => r.category == _selectedCategory).toList();
  }

  /// All first, then the café's own order (drinks, food, deals), whatever order the rewards arrived in.
  List<String> get _categories {
    const order = ['Coffee', 'Food', 'Discount', 'Other'];
    final present = _rewards.map((r) => r.category).toSet();
    return ['All', ...order.where(present.contains), ...present.difference(order.toSet())];
  }

  Future<void> _redeem(Reward reward) async {
    // FIX 10: Block sold-out rewards at UI level too
    if (reward.stock == 0) return;

    // The detail page explains cost vs balance and asks for a press-and-hold to confirm
    // (it also shows how many points are missing, instead of a snackbar).
    final confirm = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => RewardDetailScreen(reward: reward, user: widget.user, heroTag: _rewardHeroTag(reward)),
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

  Future<void> _showRedemptionCode(Redemption r) async {
    final c = context.colors;
    final t = context.text;
    final showStaff = await showAppDialog(context,
        icon: Icons.check_circle_rounded,
        iconColor: c.success,
        title: 'Reward redeemed',
        message: r.rewardTitle,
        confirmLabel: 'Show to staff',
        confirmIcon: Icons.fullscreen_rounded,
        cancelLabel: 'Got it',
        content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Your code', style: t.labelSmall),
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
                    child: RedemptionCode(r.redemptionCode,
                        style: TextStyle(fontSize: t.headlineSmall!.fontSize, letterSpacing: 3, color: c.primary)),
                  ),
                  const SizedBox(width: AppSpace.sm - 2),
                  Icon(Icons.copy_rounded, color: c.primary, size: 18),
                ]),
              ),
            )),
            const SizedBox(height: AppSpace.sm - 2),
            Text('Show this code to the staff to claim your reward',
                style: t.bodySmall, textAlign: TextAlign.center),
          ]));
    if (showStaff == true && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => StaffCodeScreen(redemption: r, updates: FirebaseService.watchRedemption(r.id!))));
    }
  }

  void _showSnack(String msg, Color color) {
    final c = context.colors;
    AppSnackbar.show(context, msg,
        kind: color == c.danger ? SnackKind.error : color == c.success ? SnackKind.success : SnackKind.info);
  }

  /// Codes that can still be shown at the counter (the My codes tab counts these, not the history).
  int get _usableCodes {
    final now = DateTime.now();
    return _redemptions.where((r) => r.status == 'pending' && !now.isAfter(r.expiresAt)).length;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final codes = _usableCodes;
    return Scaffold(
      body: Stack(children: [
      NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: AppLayout.headerHeight(context, 140, perScale: 100),
            pinned: true,
            backgroundColor: c.hero[1],
            surfaceTintColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            automaticallyImplyLeading: false,
            flexibleSpace: HeroHeaderSpace(
              title: 'Rewards',
              background: AuroraBackground(
                child: SafeArea(
                  child: Padding(
                    // Bottom padding = the tab bar, which sits on top of this background.
                    padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.xs, kTextTabBarHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text('Rewards', style: t.headlineMedium!.copyWith(color: AppPalette.cream))),
                          IconButton(
                            tooltip: 'How rewards work',
                            onPressed: () => showHowItWorksSheet(context),
                            icon: Icon(Icons.help_outline_rounded, color: c.onHeroMuted),
                          ),
                        ]),
                        Semantics(
                          label: 'You have ${widget.user.points} points to spend',
                          excludeSemantics: true,
                          child: Row(children: [
                            const EcoCoin(size: 26),
                            const SizedBox(width: AppSpace.xs),
                            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                              AnimatedCount(widget.user.points,
                                  format: formatCount,
                                  style: AppType.tabular(t.headlineSmall!).copyWith(color: AppPalette.cream)),
                              Flexible(child: Text(' pts to spend', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: t.bodyMedium!.copyWith(color: c.onHeroMuted))),
                            ])),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: c.accent,
              indicatorWeight: 3,
              labelColor: AppPalette.cream,
              unselectedLabelColor: c.onHeroMuted,
              dividerColor: Colors.transparent,
              tabs: [
                const Tab(text: 'Available'),
                Tab(text: codes > 0 ? 'My codes ($codes)' : 'My codes'),
              ],
            ),
          ),
        ],
        // Swipe between Available and My codes like any tab bar; categories change with the chips.
        body: TabBarView(
          controller: _tabController,
          children: [_buildAvailable(), _buildHistory()],
        ),
      ),
      if (_redeeming) const _RedeemingOverlay(),
      ]),
    );
  }

  Widget _buildAvailable() {
    if (_loadingRewards) return const _RewardsListSkeleton();
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

    final groups = groupRewards(_filteredRewards, widget.user.points);
    final menu = _filteredRewards.isEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: AppSpace.xxl),
            child: EmptyState(
              icon: rewardIconData('', _selectedCategory),
              title: 'No ${rewardCategoryLabel(_selectedCategory).toLowerCase()} rewards yet',
              actionLabel: 'Show all rewards',
              onAction: () => setState(() => _selectedCategory = 'All'),
              dense: true,
            ),
          )
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (groups.ready.isNotEmpty) _menuSection('Ready to redeem', groups.ready),
            if (groups.saving.isNotEmpty)
              _menuSection(groups.ready.isEmpty ? 'Rewards to work towards' : 'Keep saving', groups.saving),
            if (groups.soldOut.isNotEmpty) _menuSection('Sold out', groups.soldOut),
          ]);

    return EcoRefresh(
        onRefresh: _loadRewards,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: AppLayout.bottomClearance(context)),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xxs),
                  child: _CraveBand(),
                ),
              ),
            ),
            SizedBox(
              height: 56,
              // Centred when the chips fit; when they don't (narrow phone, large text) they scroll from the left.
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: box.maxWidth - AppSpace.lg * 2),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (final (i, cat) in _categories.indexed) ...[
                        if (i > 0) const SizedBox(width: AppSpace.xs),
                        Builder(builder: (context) {
                          final label = rewardCategoryLabel(cat);
                          final count =
                              cat == 'All' ? _rewards.length : _rewards.where((r) => r.category == cat).length;
                          return AppChip(
                            label: label,
                            count: count,
                            semanticLabel: '$label rewards, $count',
                            icon: cat == 'All' ? null : rewardIconData('', cat),
                            selected: _selectedCategory == cat,
                            onTap: () => setState(() {
                              _swipeForward = _categories.indexOf(cat) >= _categories.indexOf(_selectedCategory);
                              _selectedCategory = cat;
                            }),
                          );
                        }),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  // First visit: the menu rises in once. A category change slides it from the side you moved to.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: _animateCards ? 0 : 1, end: 1),
                    duration: AppMotion.of(context, AppMotion.slow),
                    curve: AppMotion.standard,
                    builder: (_, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child),
                    ),
                    child: AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.medium),
                      layoutBuilder: (current, previous) =>
                          Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(begin: Offset(_swipeForward ? 0.06 : -0.06, 0), end: Offset.zero).animate(a),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(key: ValueKey(_selectedCategory), child: menu),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }

  /// One group of the menu: a heading, then its rewards as photo tiles, two per row on a phone, three on a tablet.
  Widget _menuSection(String title, List<Reward> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.xxs, AppSpace.lg, AppSpace.xxs, AppSpace.sm),
        child: Semantics(header: true, child: Text(title, style: context.text.titleMedium)),
      ),
      LayoutBuilder(builder: (context, box) {
        final perRow = box.maxWidth >= 560 ? 3 : 2;
        return Column(children: [
          for (var i = 0; i < items.length; i += perRow)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var j = i; j < i + perRow; j++) ...[
                  if (j > i) const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: j < items.length
                        ? RewardTile(
                            reward: items[j],
                            points: widget.user.points,
                            heroTag: _rewardHeroTag(items[j]),
                            onTap: () => _redeem(items[j]),
                            onLongPress: () => _peekReward(items[j]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ]),
            ),
        ]);
      }),
    ]);
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
      padding: EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppLayout.bottomClearance(context)),
      children: [
        if (pending.isNotEmpty) ...[
          _sectionHeader('Pending codes', Icons.hourglass_top_rounded, c.warning, pending.length),
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
          // A live ticket is the raised material (lit from above, like AppSurface); an expired one lies flat.
          decoration: ShapeDecoration(
            color: isExpired ? c.surfaceAlt : null,
            gradient: isExpired
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: c.isDark
                        ? [Color.lerp(c.surface, Colors.white, 0.08)!, c.surface]
                        : [Colors.white, Color.lerp(c.surface, c.background, 0.7)!],
                  ),
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
                    RewardTicketArt(
                      title: r.rewardTitle,
                      icon: isExpired ? Icons.timer_off_rounded : (isPending ? Icons.confirmation_number_rounded : Icons.check_circle_rounded),
                      color: statusColor,
                      muted: isExpired,
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
                              child: RedemptionCode(r.redemptionCode,
                                  style: TextStyle(fontSize: t.labelMedium!.fontSize, color: c.primary)),
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

  String _formatDate(DateTime dt) => AppDates.dayYear(dt);

  String _rewardHeroTag(Reward r) => 'reward-${r.id ?? r.title}';

  /// Long-press on a reward card: what it costs and whether you can redeem, without leaving.
  void _peekReward(Reward reward) {
    final c = context.colors;
    final t = context.text;
    final soldOut = reward.stock == 0;
    final missing = reward.pointsCost - widget.user.points;
    AppSheet.showContent<void>(
      context,
      padding: EdgeInsets.zero,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.md),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              RewardArt(title: reward.title, category: reward.category, size: 52),
              const SizedBox(width: AppSpace.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reward.title, style: t.titleLarge),
                Text(rewardPrice(reward.pointsCost), style: t.titleSmall!.copyWith(color: c.primary)),
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
    AppSheet.showContent<void>(
      context,
      padding: EdgeInsets.zero,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xs),
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
              Navigator.push(context, MaterialPageRoute(builder: (_) => StaffCodeScreen(redemption: r, updates: FirebaseService.watchRedemption(r.id!))));
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
          Center(child: RedemptionCode(r.redemptionCode,
              style: TextStyle(fontSize: t.headlineSmall!.fontSize, letterSpacing: 3,
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
}

// ── Rewards list skeleton ─────────────────────────────────────────────────────
/// Whose menu this is, said quietly: "Rewards from" and Crave's wordmark, small, in Crave's navy (cream on dark,
/// where navy would vanish). No box, so the page keeps the app's navy and cream.
class _CraveBand extends StatelessWidget {
  const _CraveBand();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      label: 'Rewards from Crave',
      excludeSemantics: true,
      // Centred, like the chips beneath it; with very large text the line shrinks to fit rather than overflow.
      child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Rewards from', style: context.text.titleSmall!.copyWith(color: c.textSecondary)),
        const SizedBox(width: AppSpace.xs),
        // Sits on the text's baseline: the wordmark's foot lines up with "from".
        Padding(
          padding: const EdgeInsets.only(top: 2),
          // Sized up front (the lettering is 723 x 153 px), so the line is laid out before the image decodes.
          child: Image.asset('assets/brand/crave_logo.png',
              height: 20, width: 20 * 723 / 153, color: c.isDark ? c.textPrimary : AppPalette.navy),
        ),
      ])),
    );
  }
}

/// The menu's silhouette: chips, a heading, then a grid of tiles (photo, name, price).
class _RewardsListSkeleton extends StatelessWidget {
  const _RewardsListSkeleton();

  @override
  Widget build(BuildContext context) => Skeleton(
        label: 'Loading rewards',
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
          children: [
            const Row(children: [
              SkeletonBox(width: 56, height: 34, radius: AppRadius.pill),
              SizedBox(width: AppSpace.xs),
              SkeletonBox(width: 92, height: 34, radius: AppRadius.pill),
              SizedBox(width: AppSpace.xs),
              SkeletonBox(width: 76, height: 34, radius: AppRadius.pill),
            ]),
            const SizedBox(height: AppSpace.xl),
            const SkeletonBox(width: 140, height: 16),
            const SizedBox(height: AppSpace.sm),
            for (var i = 0; i < 2; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Row(children: [
                  for (var j = 0; j < 2; j++) ...[
                    if (j > 0) const SizedBox(width: AppSpace.sm),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AspectRatio(aspectRatio: 1, child: SkeletonBox(height: double.infinity, radius: AppRadius.lg)),
                      SizedBox(height: AppSpace.sm),
                      SkeletonBox(width: 110, height: 14),
                      SizedBox(height: AppSpace.xs),
                      SkeletonBox(width: 60, height: 18),
                    ])),
                  ],
                ]),
              ),
          ],
        ),
      );
}

// ── Staff view of a redemption code ───────────────────────────────────────────
/// Full-screen, maximum-contrast code for the counter: black on white in every theme,
/// very large monospaced characters, the reward name and the expiry date.
/// Live: the moment staff mark it claimed on the console, the code gives way to "Handed out".
class StaffCodeScreen extends StatelessWidget {
  const StaffCodeScreen({super.key, required this.redemption, this.updates});

  final Redemption redemption;
  /// This code, live (FirebaseService.watchRedemption); null shows it as it was opened.
  final Stream<Redemption?>? updates;

  @override
  Widget build(BuildContext context) => StreamBuilder<Redemption?>(
        stream: updates,
        builder: (context, snap) => _build(context, handedOut: (snap.data ?? redemption).status == 'claimed'),
      );

  Widget _build(BuildContext context, {required bool handedOut}) {
    final t = context.text;
    const ink = Color(0xFF000000);
    final e = redemption.expiresAt;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        title: const Text('Show this to staff'),
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - AppSpace.xl * 2),
          child: IntrinsicHeight(child: Column(children: [
            const Spacer(),
            Text(redemption.rewardTitle, textAlign: TextAlign.center,
                style: t.headlineSmall!.copyWith(color: ink)),
            const SizedBox(height: AppSpace.xl),
            if (handedOut) ...[
              Semantics(liveRegion: true, child: Column(children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF1B7F3B), size: 96),
                const SizedBox(height: AppSpace.md),
                Text('Handed out', style: t.headlineMedium!.copyWith(color: ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpace.xs),
                Text('Enjoy your ${redemption.rewardTitle}.', textAlign: TextAlign.center,
                    style: t.titleSmall!.copyWith(color: const Color(0xFF333333))),
              ])),
            ] else ...[
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
                child: Center(
                  child: RedemptionCode(redemption.redemptionCode,
                      style: TextStyle(fontSize: AppType.balance.fontSize, fontWeight: FontWeight.w800, letterSpacing: 4, color: ink)),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text('${redemption.pointsUsed} pts · valid until ${AppDates.dayYear(e)}',
                style: t.titleSmall!.copyWith(color: const Color(0xFF333333))),
            ],
            const Spacer(),
            if (!handedOut) OutlinedButton.icon(
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
          ])),
        ),
        )),
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
