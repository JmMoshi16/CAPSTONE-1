part of 'customer_home_screen.dart';

// ── Hero Header Card ──────────────────────────────────────────────────────────
class _HeroHeaderCard extends StatelessWidget {
  final UserModel user;
  final int myRank, pendingRedemptions, lifetimePoints, streak;
  final Animation<double> pointsAnim;   // animates the spendable balance
  final VoidCallback onBell, onProfile;
  const _HeroHeaderCard({
    required this.user, required this.myRank, required this.pendingRedemptions,
    required this.lifetimePoints, required this.pointsAnim, required this.streak,
    required this.onBell, required this.onProfile,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final lv = getLevel(lifetimePoints);
    final rk = getRank(lifetimePoints);
    final multiplier = streakMultiplier(streak);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Stack(children: [
        Positioned(top: -40, right: -40,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05)))),
        Positioned(bottom: 20, left: -30,
          child: Container(width: 110, height: 110,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04)))),

        SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
          child: Column(children: [

            // ── Top row: avatar / name / bell ──────────────────────────────
            Row(children: [
              Tap(label: 'Open profile', tooltip: true, 
                onTap: onProfile,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(child: Text(
                    user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  )),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting, style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 11)),
                Text(user.username, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ])),
              Tap(label: pendingRedemptions > 0 ? 'Notifications, $pendingRedemptions pending' : 'Notifications', tooltip: true, 
                onTap: onBell,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 19),
                  ),
                  if (pendingRedemptions > 0)
                    Positioned(top: -2, right: -2,
                      child: Container(
                        width: 15, height: 15,
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: Center(child: Text('$pendingRedemptions',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                      )),
                ]),
              ),
            ]),

            const SizedBox(height: 24),

            // ── Points display (centered, no box) ──────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFE566), Color(0xFFFFD700), Color(0xFFB8860B)],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.stars_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedBuilder(
                  animation: pointsAnim,
                  builder: (_, __) => Text(
                    NumberFormat('#,###').format(pointsAnim.value.toInt()),
                    style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -2, height: 1.0),
                  ),
                ),
                Row(children: [
                  Text('eco credits', style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12)),
                  if (multiplier > 1.0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        streak >= 7 ? '🔥 2× Bonus' : '🔥 1.5× Bonus',
                        style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ]),
              ]),
            ]),

            const SizedBox(height: 20),

            // ── Rank + Level pills ─────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _pill('${lv.emoji} Lv ${lv.level} ${lv.title}'),
              const SizedBox(width: 8),
              _pill('${rk.icon} ${rk.label}'),
              if (myRank > 0) ...[
                const SizedBox(width: 8),
                _pill('🏆 #$myRank'),
              ],
            ]),
          ]),
        )),
      ]),
    );
  }

  Widget _pill(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}



// ── Progress Bar Row (labeled) ────────────────────────────────────────────────

class _ProgressBarRow extends StatelessWidget {
  final String leftLabel, rightLabel;
  final double progress;
  final Color color, labelColor;
  const _ProgressBarRow({
    required this.leftLabel, required this.rightLabel,
    required this.progress, required this.color, required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(leftLabel,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: labelColor)),
        Text(rightLabel,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]),
      const SizedBox(height: 6),
      _AnimatedProgressBar(progress: progress, color: color),
    ]);
  }
}

// ── Animated Progress Bar ─────────────────────────────────────────────────────
class _AnimatedProgressBar extends StatefulWidget {
  final double progress;
  final Color color;
  const _AnimatedProgressBar({required this.progress, required this.color});
  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _anim = Tween<double>(begin: 0, end: widget.progress)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 400), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: _anim.value,
        backgroundColor: Colors.grey.shade100,
        valueColor: AlwaysStoppedAnimation(widget.color),
        minHeight: 8,
      ),
    ),
  );
}

// ── Stat Card with staggered pop-in ──────────────────────────────────────────
class _StatCard extends StatefulWidget {
  final String emoji, value, label;
  final Color valueColor;
  final Color accentColor;
  final int delay;
  final AnimationController ctrl;
  final VoidCallback onTap;
  const _StatCard({required this.emoji, required this.value, required this.label,
      required this.valueColor, required this.accentColor,
      required this.delay, required this.ctrl, required this.onTap});
  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> with SingleTickerProviderStateMixin {
  late AnimationController _popCtrl;
  late Animation<double> _pop;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _popCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pop = CurvedAnimation(parent: _popCtrl, curve: Curves.elasticOut);
    Future.delayed(Duration(milliseconds: 300 + widget.delay), () { if (mounted) _popCtrl.forward(); });
  }

  @override
  void dispose() { _popCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Expanded(
    child: ScaleTransition(
      scale: _pop,
      child: Semantics(button: true, label: '${widget.value} ${widget.label}', excludeSemantics: true,
        onTap: widget.onTap,
        child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Colored accent line at top
              Container(
                height: 3,
                width: 24,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Text(widget.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(widget.value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: widget.valueColor)),
              Text(widget.label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ]),
          ),
        ),
      )),
    ),
  );
}

// ── Weekly Goal Bar ───────────────────────────────────────────────────────────
class _WeeklyGoalBar extends StatelessWidget {
  final int scanCount;
  final int weeklyGoal;
  const _WeeklyGoalBar({required this.scanCount, required this.weeklyGoal});

  @override
  Widget build(BuildContext context) {
    final progress = (scanCount / weeklyGoal).clamp(0.0, 1.0);
    final done = scanCount >= weeklyGoal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Row(children: [
            Text('🎯', style: TextStyle(fontSize: 13)),
            SizedBox(width: 6),
            Text('Weekly Goal · last 7 days', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black87)),
          ]),
          Text(
            done ? '✅ Goal reached!' : '$scanCount / $weeklyGoal scans',
            style: TextStyle(
              fontSize: 11,
              color: done ? kGreen : Colors.grey,
              fontWeight: done ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(done ? kGreen : kGreenLight),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }
}

// ── Scale-on-tap wrapper ──────────────────────────────────────────────────────
class _ScaleTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleTapButton({required this.child, required this.onTap});
  @override
  State<_ScaleTapButton> createState() => _ScaleTapButtonState();
}

class _ScaleTapButtonState extends State<_ScaleTapButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100), lowerBound: 0.93, upperBound: 1.0, value: 1.0);
    _scale = _ctrl;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  // The action fires on onTapUp (for the press animation), so give screen readers an explicit tap.
  Widget build(BuildContext context) => Semantics(button: true, onTap: widget.onTap, child: GestureDetector(
    onTapDown: (_) => _ctrl.reverse(),
    onTapUp: (_) { _ctrl.forward(); widget.onTap(); },
    onTapCancel: () => _ctrl.forward(),
    child: ScaleTransition(scale: _scale, child: widget.child),
  ));
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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, Icons.home_outlined, 'Home', 0),
              _navItem(Icons.card_giftcard_rounded, Icons.card_giftcard_outlined, 'Rewards', 1),
              Tap(label: 'Scan QR code', tooltip: true, 
                onTap: onScan,
                child: Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: kGreen,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: kGreen.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
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
    return Tap(label: label, selected: selected, 
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kGreenLight.withValues(alpha: 0.1) : Colors.transparent,
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

// ── Notification item data model ──────────────────────────────────────────────
class _NotifItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;
  final VoidCallback? onTap;

  const _NotifItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
    required this.onTap,
  });
}

