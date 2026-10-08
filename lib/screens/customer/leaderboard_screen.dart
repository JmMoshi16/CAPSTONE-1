import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../core/theme.dart';

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
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _listCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
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
    final showPodium = _users.length >= 3;
    final listOffset = showPodium ? 3 : 0;

    return Scaffold(
      backgroundColor: kBg,
      body: RefreshIndicator(
        color: kGreenLight,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _headerFade,
                child: SlideTransition(
                  position: _headerSlide,
                  child: Container(
                    decoration: gradientHeader,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        child: Column(children: [
                          Row(children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Leaderboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                          ]),
                          const SizedBox(height: 20),
                          if (_myRank > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                Text('Your Rank: #$_myRank',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
                child: Center(child: CircularProgressIndicator(color: kGreenLight)),
              )
            else if (_users.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('🏆', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12),
                    Text('No users yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ]),
                ),
              )
            else ...[
              if (showPodium)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: _Podium(users: _users.take(3).toList(), currentUid: widget.currentUid, ctrl: _listCtrl),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final rank = i + listOffset + 1;
                      final user = _users[i + listOffset];
                      final isMe = user.uid == widget.currentUid;
                      final delay = (i * 60).clamp(0, 500);
                      return _AnimatedLeaderRow(rank: rank, user: user, isMe: isMe, ctrl: _listCtrl, delayMs: delay);
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
      final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
      _ctrls.add(c);
      _scales.add(CurvedAnimation(parent: c, curve: Curves.elasticOut));
      Future.delayed(Duration(milliseconds: 200 + i * 120), () { if (mounted) c.forward(); });
    }
  }

  @override
  void dispose() { for (final c in _ctrls) c.dispose(); super.dispose(); }

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
            ctrl: widget.ctrl, delayMs: i * 80,
          );
        }),
      );
    }
    const order   = [1, 0, 2];
    const heights = [80.0, 110.0, 60.0];
    const medals  = ['🥈', '🥇', '🥉'];
    final colors  = [Colors.grey.shade400, Colors.amber, const Color(0xFFCD7F32)];

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
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(8)),
                  child: const Text('You', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              Text(medals[i], style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i].withValues(alpha: 0.15),
                  border: Border.all(color: colors[i], width: 2.5),
                ),
                child: Center(child: Text(
                  user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                  style: TextStyle(color: colors[i], fontWeight: FontWeight.bold, fontSize: 20),
                )),
              ),
              const SizedBox(height: 6),
              Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${user.points} pts', style: TextStyle(color: colors[i], fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(height: 6),
              Container(
                height: heights[i],
                decoration: BoxDecoration(
                  color: colors[i].withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                  border: Border.all(color: colors[i].withValues(alpha: 0.4)),
                ),
                child: Center(child: Text('#${idx + 1}',
                    style: TextStyle(color: colors[i], fontWeight: FontWeight.bold, fontSize: 16))),
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
  final int rank, delayMs;
  final UserModel user;
  final bool isMe;
  final AnimationController ctrl;
  const _AnimatedLeaderRow({required this.rank, required this.user, required this.isMe, required this.ctrl, required this.delayMs});
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade  = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delayMs), () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(
      position: _slide,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: widget.isMe ? kGreen.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: widget.isMe ? Border.all(color: kGreen.withValues(alpha: 0.4)) : null,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          SizedBox(width: 32,
            child: Text('#${widget.rank}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                color: widget.isMe ? kGreen : Colors.grey))),
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: kGreenLight.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Center(child: Text(
              widget.user.username.isNotEmpty ? widget.user.username[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: kGreen, fontSize: 16),
            ))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(widget.user.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (widget.isMe) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(6)),
                  child: const Text('You', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
            Text('${widget.user.scanCount} scans  •  🔥 ${widget.user.streak} streak',
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${widget.user.points}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFB8860B))),
            const Text('pts', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ]),
        ]),
      ),
    ),
  );
}
