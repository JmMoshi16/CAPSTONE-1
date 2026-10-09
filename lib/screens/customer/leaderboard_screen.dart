import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

class LeaderboardScreen extends StatefulWidget {
  final String currentUid;
  const LeaderboardScreen({super.key, required this.currentUid});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with TickerProviderStateMixin {
  List<UserModel> _users = [];
  bool _loading = true;
  int _myRank = 0;
  late AnimationController _headerCtrl;
  late AnimationController _listCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: AppMotion.slow);
    _listCtrl   = AnimationController(vsync: this, duration: AppMotion.slow * 2);
    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: AppMotion.standard);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: AppMotion.standard));
    _headerCtrl.forward();
    _load();
  }

  @override
  void dispose() { _headerCtrl.dispose(); _listCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _listCtrl.reset();
    final results = await Future.wait([
      FirebaseService.getLeaderboard(limit: 20),
      FirebaseService.getUserRank(widget.currentUid),
    ]);
    if (mounted) {
      setState(() {
        _users   = results[0] as List<UserModel>;
        _myRank  = results[1] as int;
        _loading = false;
      });
      _listCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final showPodium = _users.length >= 3;
    final listOffset = showPodium ? 3 : 0;

    return Scaffold(
      body: RefreshIndicator(
        color: c.primary,
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
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_users.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(emoji: '🏆', title: 'No users yet', dense: true),
              )
            else ...[
              if (showPodium)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.xs),
                    child: _Podium(users: _users.take(3).toList(), currentUid: widget.currentUid, ctrl: _listCtrl),
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
                      return _AnimatedLeaderRow(rank: rank, user: user, isMe: isMe, ctrl: _listCtrl,
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
  final AnimationController ctrl;
  const _Podium({required this.users, required this.currentUid, required this.ctrl});
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
      Future.delayed(AppMotion.medium + AppMotion.stagger * (i * 2), () { if (mounted) c.forward(); });
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
    if (widget.users.length < 3) return const SizedBox.shrink();
    // show partial podium for 1-2 users
    final count = widget.users.length;
    if (count < 3) {
      return Column(
        children: List.generate(count, (i) {
          final user = widget.users[i];
          final isMe = user.uid == widget.currentUid;
          return _AnimatedLeaderRow(
            rank: i + 1, user: user, isMe: isMe,
            ctrl: widget.ctrl, delay: AppMotion.stagger * i,
          );
        }),
      );
    }
    const order   = [1, 0, 2];
    const heights = [80.0, 110.0, 60.0];
    const medals  = ['🥈', '🥇', '🥉'];
    final c = context.colors;
    final t = context.text;
    final colors  = [const Color(0xFF9E9E9E), const Color(0xFFFFC107), const Color(0xFFCD7F32)];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final idx  = order[i];
        final user = widget.users[idx];
        final isMe = user.uid == widget.currentUid;
        return Expanded(
          child: ScaleTransition(
            scale: _scales[i],
            child: Column(children: [
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
              Container(
                height: heights[i],
                decoration: BoxDecoration(
                  color: colors[i].withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sm + 2)),
                  border: Border.all(color: colors[i].withValues(alpha: 0.4)),
                ),
                child: Center(child: Text('#${idx + 1}',
                    style: t.titleMedium!.copyWith(color: c.ink(colors[i])))),
              ),
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
  final AnimationController ctrl;
  const _AnimatedLeaderRow({required this.rank, required this.user, required this.isMe, required this.ctrl, required this.delay});
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
