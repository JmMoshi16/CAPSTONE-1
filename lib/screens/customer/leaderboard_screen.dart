import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

class LeaderboardScreen extends StatefulWidget {
  final String currentUid;
  /// The signed-in customer, for the row pinned at the bottom when they are outside the top 20.
  final UserModel? me;
  const LeaderboardScreen({super.key, required this.currentUid, this.me});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with TickerProviderStateMixin {
  List<UserModel> _users = [];
  bool _loading = true;
  bool _error = false;
  bool _denied = false;   // Firestore refused the read (rules), not a connection problem
  /// Places gained (+) or lost (-) since the last visit on this phone. Display only.
  int? _rankDelta;
  bool _rankTracked = false;

  Future<void> _trackRankChange() async {
    if (_myRank <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'last_rank_${widget.currentUid}';
      final prev = prefs.getInt(key);
      await prefs.setInt(key, _myRank);
      if (mounted && prev != null && prev != _myRank) setState(() => _rankDelta = prev - _myRank);
    } catch (_) {
      // Purely decorative: no arrow if local storage is unavailable.
    }
  }
  int _myRank = 0;
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: AppMotion.slow);
    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: AppMotion.standard);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: AppMotion.standard));
    _headerCtrl.forward();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _headerCtrl.value = 1;
  }

  @override
  void dispose() { _headerCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; _denied = false; });
    try {
      // Never leave the user on an endless spinner: offline or a missing index ends in an error state.
      final results = await Future.wait([
        FirebaseService.getLeaderboard(limit: 20),
        FirebaseService.getUserRank(widget.currentUid),
      ]).timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _users   = results[0] as List<UserModel>;
          _myRank  = results[1] as int;
          _loading = false;
        });
        // Compare with the previous visit once per visit (not on every pull-to-refresh).
        if (!_rankTracked) {
          _rankTracked = true;
          _trackRankChange();
        }
      }
    } catch (e) {
      // The exact cause goes to the debug log (flutter run / logcat), never to the screen.
      debugPrint('Leaderboard load failed: ${e is FirebaseException ? '${e.code}: ${e.message}' : e}');
      final denied = e is FirebaseException && (e.code == 'permission-denied' || e.code == 'failed-precondition');
      if (mounted) setState(() { _loading = false; _error = true; _denied = denied; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final showPodium = _users.length >= 3;
    final listOffset = showPodium ? 3 : 0;

    final me = widget.me;
    final pinMe = !_loading && !_error && me != null && _myRank > 0 && !_users.any((u) => u.uid == me.uid);
    return Scaffold(
      // Outside the loaded top 20? Keep your own row visible at the bottom.
      bottomNavigationBar: pinMe ? _PinnedMe(me: me, rank: _myRank, delta: _rankDelta) : null,
      body: EcoRefresh(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _headerFade,
                child: SlideTransition(
                  position: _headerSlide,
                  child: Container(
                    decoration: heroDecoration(context,
                        radius: const BorderRadius.vertical(bottom: Radius.circular(AppSpace.xxl))),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.lg, AppSpace.xl + 4),
                        child: Column(children: [
                          Row(children: [
                            HeroBackButton(onTap: () => Navigator.pop(context)),
                            const SizedBox(width: AppSpace.xs),
                            Text('Leaderboard', style: t.headlineSmall!.copyWith(color: c.onHero, fontSize: 20)),
                          ]),
                          const SizedBox(height: AppSpace.lg),
                          if (_myRank > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm - 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: AppRadius.all(AppRadius.pill),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.emoji_events_rounded, color: AppPalette.coin[1], size: 20),
                                const SizedBox(width: AppSpace.xs),
                                Text('Your Rank: #$_myRank',
                                    style: t.titleSmall!.copyWith(color: c.onHero, fontWeight: FontWeight.w700, fontSize: 15)),
                                if (_rankDelta != null && _rankDelta != 0) _RankDelta(delta: _rankDelta!, onHero: true),
                              ]),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: LeaderboardSkeleton(),
              )
            else if (_error)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  title: "Couldn't load the leaderboard",
                  message: _denied
                      ? "The leaderboard isn't available right now. Please try again later."
                      : 'Check your connection, then try again.',
                  icon: _denied ? Icons.lock_clock_rounded : Icons.wifi_off_rounded,
                  onRetry: _load,
                ),
              )
            else if (_users.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  emoji: '🏆',
                  title: 'No one on the board yet',
                  message: 'Scan a bin QR code to be the first!',
                  actionLabel: 'Refresh',
                  onAction: _load,
                  dense: true,
                ),
              )
            else ...[
              if (showPodium)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.xs),
                    child: _Podium(users: _users.take(3).toList(), currentUid: widget.currentUid),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.navClearance),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final rank = i + listOffset + 1;
                      final user = _users[i + listOffset];
                      final isMe = user.uid == widget.currentUid;
                      final delay = AppMotion.stagger * i;
                      return _AnimatedLeaderRow(rank: rank, user: user, isMe: isMe,
                          delay: delay > AppMotion.slow ? AppMotion.slow : delay);
                    },
                    childCount: (_users.length - listOffset).clamp(0, _users.length),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Podium with staggered pop-in ──────────────────────────────────────────────
class _Podium extends StatefulWidget {
  final List<UserModel> users;
  final String currentUid;
  const _Podium({required this.users, required this.currentUid});
  @override
  State<_Podium> createState() => _PodiumState();
}

class _PodiumState extends State<_Podium> with TickerProviderStateMixin {
  final List<AnimationController> _ctrls = [];
  final List<Animation<double>> _scales = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final c = AnimationController(vsync: this, duration: AppMotion.slow);
      _ctrls.add(c);
      _scales.add(Tween<double>(begin: 0.6, end: 1).animate(CurvedAnimation(parent: c, curve: AppMotion.spring)));
      // Order on screen is silver, gold, bronze; they rise bronze -> silver -> gold.
      const delays = [250, 520, 120];
      Future.delayed(Duration(milliseconds: delays[i]), () { if (mounted) c.forward(); });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      for (final c in _ctrls) {
        c.value = 1;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only built when there are at least three users (see showPodium).
    const order   = [1, 0, 2];
    const heights = [80.0, 110.0, 60.0];
    const medals  = ['🥈', '🥇', '🥉'];
    final c = context.colors;
    final t = context.text;
    final colors  = [AppPalette.medalSilver, AppPalette.medalGold, AppPalette.medalBronze];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final idx  = order[i];
        final user = widget.users[idx];
        final isMe = user.uid == widget.currentUid;
        return Expanded(
          child: FadeTransition(
            opacity: _ctrls[i],
            child: Column(children: [
              if (idx == 0)
                // The leader's crown, with a shine now and then.
                const ShineSweep(every: Duration(seconds: 3), opacity: 0.6,
                    child: ExcludeSemantics(child: Text('👑', style: TextStyle(fontSize: 24)))),
              if (isMe)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpace.xxs),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs, vertical: 2),
                  decoration: BoxDecoration(color: c.primary, borderRadius: AppRadius.all(AppRadius.sm)),
                  child: Text('You', style: t.labelSmall!.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700)),
                ),
              Text(medals[i], style: const TextStyle(fontSize: 28)),
              const SizedBox(height: AppSpace.xxs),
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i].withValues(alpha: 0.15),
                  border: Border.all(color: colors[i], width: 2.5),
                ),
                child: Center(child: Text(
                  user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                  style: t.titleLarge!.copyWith(color: c.ink(colors[i]), fontSize: 20),
                )),
              ),
              const SizedBox(height: AppSpace.xs - 2),
              Text(user.username, style: t.labelMedium!.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${user.lifetimePoints} pts', style: t.labelSmall!.copyWith(color: c.ink(colors[i]), fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpace.xs - 2),
              AnimatedBuilder(
                animation: _scales[i],
                builder: (_, child) => SizedBox(
                  // The step grows from the floor with a spring (scale runs 0.6 -> 1).
                  height: heights[i] * ((_scales[i].value - 0.6) / 0.4).clamp(0.0, 1.15),
                  child: child,
                ),
                child: Container(
                decoration: BoxDecoration(
                  color: colors[i].withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sm + 2)),
                  border: Border.all(color: colors[i].withValues(alpha: 0.4)),
                ),
                child: Center(child: FittedBox(child: Text('#${idx + 1}',
                    style: t.titleMedium!.copyWith(color: c.ink(colors[i]))))),
              )),
            ]),
          ),
        );
      }),
    );
  }
}

// ── Animated Leader Row ───────────────────────────────────────────────────────
class _AnimatedLeaderRow extends StatefulWidget {
  final int rank;
  final Duration delay;
  final UserModel user;
  final bool isMe;
  const _AnimatedLeaderRow({required this.rank, required this.user, required this.isMe, required this.delay});
  @override
  State<_AnimatedLeaderRow> createState() => _AnimatedLeaderRowState();
}

class _AnimatedLeaderRowState extends State<_AnimatedLeaderRow> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: AppMotion.slow);
    _fade  = CurvedAnimation(parent: _c, curve: AppMotion.standard);
    _slide = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: AppMotion.standard));
    Future.delayed(widget.delay, () { if (mounted) _c.forward(); });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _c.value = 1;
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpace.xs),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md - 2, vertical: AppSpace.sm),
          decoration: cardDecoration(context, radius: AppRadius.lg,
              color: widget.isMe ? c.primaryContainer : null,
              borderColor: widget.isMe ? c.primary.withValues(alpha: 0.4) : null),
          child: Row(children: [
            SizedBox(width: 36,
              child: Text('#${widget.rank}', style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700,
                  color: widget.isMe ? c.primary : c.textSecondary))),
            Container(width: 38, height: 38,
              decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
              child: Center(child: Text(
                widget.user.username.isNotEmpty ? widget.user.username[0].toUpperCase() : '?',
                style: t.titleMedium!.copyWith(color: c.onPrimaryContainer),
              ))),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(widget.user.username, overflow: TextOverflow.ellipsis,
                    style: t.titleSmall!.copyWith(fontSize: 13))),
                if (widget.isMe) ...[
                  const SizedBox(width: AppSpace.xs - 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs - 2, vertical: 1),
                    decoration: BoxDecoration(color: c.primary, borderRadius: AppRadius.all(AppRadius.sm - 2)),
                    child: Text('You', style: t.labelSmall!.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              Text('${widget.user.badges.length} badge${widget.user.badges.length == 1 ? '' : 's'}',
                  style: t.labelSmall!.copyWith(fontWeight: FontWeight.w400)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${widget.user.lifetimePoints}', style: t.titleMedium!.copyWith(color: c.gold, fontSize: 15)),
              Text('lifetime pts', style: t.labelSmall!.copyWith(fontWeight: FontWeight.w400)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// "▲ 2" / "▼ 1": places gained or lost since the last visit on this phone.
class _RankDelta extends StatelessWidget {
  const _RankDelta({required this.delta, this.onHero = false});
  final int delta;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final up = delta > 0;
    final color = onHero ? (up ? c.heroAccent : c.onHeroMuted) : (up ? c.success : c.danger);
    return Semantics(
      label: up ? 'up $delta since your last visit' : 'down ${-delta} since your last visit',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpace.xs),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, color: color, size: 26),
          Text('${delta.abs()}', style: context.text.titleSmall!.copyWith(color: color, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

/// Your own row, pinned under the list when you are not in the loaded top 20.
class _PinnedMe extends StatelessWidget {
  const _PinnedMe({required this.me, required this.rank, this.delta});
  final UserModel me;
  final int rank;
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
        decoration: cardDecoration(context, color: c.primaryContainer, borderColor: c.primary.withValues(alpha: 0.5))
            .copyWith(boxShadow: AppShadows.of(context, AppShadows.e3)),
        child: Row(children: [
          Text('#$rank', style: t.titleMedium!.copyWith(color: c.primary, fontWeight: FontWeight.w800)),
          if (delta != null && delta != 0) _RankDelta(delta: delta!),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text('You · ${me.username}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: t.titleSmall!.copyWith(color: c.onPrimaryContainer))),
          Text('${me.lifetimePoints} pts', style: t.titleSmall!.copyWith(color: c.gold, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
