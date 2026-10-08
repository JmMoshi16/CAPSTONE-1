import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../core/theme.dart';
import '../login_screen.dart';
import 'leaderboard_screen.dart';
import 'badges_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  final UserModel user;
  final List<WasteLog> logs;
  final VoidCallback onUpdated;
  const CustomerProfileScreen({super.key, required this.user, required this.logs, required this.onUpdated});
  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _userCtrl = TextEditingController(text: widget.user.username);
  bool _editing = false;
  bool _saving  = false;
  int  _myRank  = 0;

  @override
  void initState() {
    super.initState();
    FirebaseService.getUserRank(widget.user.uid).then((r) {
      if (mounted) setState(() => _myRank = r);
    });
  }

  @override
  void dispose() { _userCtrl.dispose(); super.dispose(); }

  Map<String, dynamic> get _rank {
    final r = getRank(widget.user.points);
    return {'label': r.label, 'color': r.color, 'icon': r.icon, 'next': r.next, 'nextPts': r.nextPts};
  }

  double get _rankProgress => rankProgress(widget.user.points);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final newUsername = _userCtrl.text.trim();
    try {
      await FirebaseService.updateUsername(widget.user.uid, newUsername);
      widget.user.username = newUsername; // only after the write succeeded
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', newUsername);
      widget.onUpdated();
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile updated!'),
          backgroundColor: kGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not update your profile. Check your connection and try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await FirebaseService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bio = widget.logs.where((l) => l.wasteType == 'Biodegradable').length;
    final rec = widget.logs.where((l) => l.wasteType == 'Recyclable').length;
    final res = widget.logs.where((l) => l.wasteType == 'Residual').length;
    final rank      = _rank;
    final rankColor = rank['color'] as Color;

    // FIX 8: Use actual rank info instead of computed level
    final rankInfo   = getRank(widget.user.points);
    final winRate    = widget.logs.isEmpty ? 0 : ((rec + bio) / widget.logs.length * 100).round();
    final daysSince  = DateTime.now().difference(widget.user.createdAt).inDays;

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [

          // ── Top bar ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Points chip — taps to leaderboard
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => LeaderboardScreen(currentUid: widget.user.uid))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kGreenLight.withValues(alpha: 0.3)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(color: kGreenLight, shape: BoxShape.circle),
                            child: const Icon(Icons.stars_rounded, size: 13, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.user.points} pts',
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ]),
                      ),
                    ),
                    _iconBtn(Icons.logout_rounded, _logout, color: Colors.redAccent),
                  ],
                ),
              ),
            ),
          ),

          // ── Avatar + name ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(children: [
                _DashedAvatar(
                  initial: widget.user.username.isNotEmpty ? widget.user.username[0].toUpperCase() : 'U',
                  rankIcon: rank['icon'] as String,
                  rankColor: rankColor,
                ),
                const SizedBox(height: 14),
                Text(
                  widget.user.username,
                  style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                // FIX 3: spaces become underscores
                Text(
                  '@${widget.user.username.toLowerCase().replaceAll(' ', '_')}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                if (_myRank > 0) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => LeaderboardScreen(currentUid: widget.user.uid))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: kGreenLight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGreenLight.withValues(alpha: 0.3)),
                      ),
                      child: Text('🏆  Rank #$_myRank',
                          style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // ── Edit profile button ──
                GestureDetector(
                  onTap: () => setState(() {
                    _editing = !_editing;
                    if (!_editing) _userCtrl.text = widget.user.username;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: _editing ? Colors.red.withValues(alpha: 0.08) : kGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _editing ? Colors.red.withValues(alpha: 0.3) : kGreenLight.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        _editing ? Icons.close_rounded : Icons.edit_rounded,
                        color: _editing ? Colors.redAccent : kGreen,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _editing ? 'Cancel' : 'Edit Profile',
                        style: TextStyle(
                          color: _editing ? Colors.redAccent : kGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),

          // ── 3-stat row (Eco Rate · Rank · Days) ──────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: cardDecoration(),
                child: Row(children: [
                  Expanded(child: _statPill('$winRate%',  'Eco Rate', Icons.recycling_rounded,   kGreenLight)),
                  _divider(),
                  // FIX 8: Show rank (icon + label) with rank color
                  Expanded(child: _statPill(
                    '${rankInfo.icon} ${rankInfo.label}',
                    'Rank',
                    Icons.military_tech_rounded,
                    rankInfo.color,
                  )),
                  _divider(),
                  Expanded(child: _statPill('$daysSince', 'Days', Icons.calendar_today_rounded, const Color(0xFF64B5F6))),
                ]),
              ),
            ),
          ),

          // ── "Keep it up!" streak banner ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration(),
                child: Row(children: [
                  SizedBox(
                    width: 56,
                    height: 40,
                    child: Stack(
                      children: List.generate(3, (i) => Positioned(
                        left: i * 16.0,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: [kGreenLight, Colors.amber, const Color(0xFF64B5F6)][i].withValues(alpha: 0.2),
                            border: Border.all(color: kBg, width: 2),
                          ),
                          child: Center(child: Text(['♻', '🌿', '🔥'][i], style: const TextStyle(fontSize: 13))),
                        ),
                      )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      widget.user.streak > 0 ? 'Keep it up!' : 'Start your streak!',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.user.streak > 0
                          ? '${widget.user.streak} day${widget.user.streak > 1 ? 's' : ''} in a row — you\'re here!'
                          : 'Scan waste today to begin your streak',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(children: List.generate(7, (i) => Container(
                      width: 10, height: 10,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < widget.user.streak ? kGreenLight : Colors.grey.shade200,
                      ),
                    ))),
                  ])),
                  const SizedBox(width: 12),
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: kGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('🏆', style: TextStyle(fontSize: 26))),
                  ),
                ]),
              ),
            ),
          ),

          // ── "Complete new tasks" badges banner ────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BadgesScreen(user: widget.user))),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kGreen.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kGreenLight.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 56, height: 40,
                      child: Stack(
                        children: List.generate(2, (i) => Positioned(
                          left: i * 20.0,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: kGreenLight.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: kBg, width: 2),
                            ),
                            child: Center(child: Text(['🌱', '♻️'][i], style: const TextStyle(fontSize: 16))),
                          ),
                        )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Complete new tasks',
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        widget.user.badges.isEmpty
                            ? 'Earn badges by scanning waste!'
                            : '${widget.user.badges.length} badge${widget.user.badges.length > 1 ? 's' : ''} earned — tap to see all',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: kGreen),
                  ]),
                ),
              ),
            ),
          ),

          // ── Divider label ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(children: [
                Container(width: 4, height: 16, decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                const Text('Your Stats', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ),
          ),

          // ── Progress to next rank ─────────────────────────────────────────
          if (rank['next'] != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.military_tech_rounded, color: rankColor, size: 20),
                      const SizedBox(width: 8),
                      Text('Progress to ${rank['next']}',
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      Text('${widget.user.points} / ${rank['nextPts']} pts',
                          style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _rankProgress,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(rankColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${(rank['nextPts'] as int) - widget.user.points} more points to reach ${rank['next']}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ]),
                ),
              ),
            ),

          // ── Waste breakdown ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.pie_chart_rounded, color: kGreen, size: 18),
                    SizedBox(width: 8),
                    Text('Waste Breakdown', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                  const SizedBox(height: 14),
                  if (widget.logs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text('No scans yet — start recycling to see your breakdown!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                    )
                  else ...[
                    _wasteBar('Biodegradable', bio, widget.logs.length, kBioColor, Icons.compost_rounded),
                    const SizedBox(height: 10),
                    _wasteBar('Recyclable',    rec, widget.logs.length, kRecColor, Icons.recycling_rounded),
                    const SizedBox(height: 10),
                    _wasteBar('Residual',      res, widget.logs.length, kResColor, Icons.delete_outline_rounded),
                  ],
                ]),
              ),
            ),
          ),

          // ── Account info / edit form ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                decoration: cardDecoration(),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.person_outline_rounded, color: kGreen, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text('Account Info', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
                      ]),
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    TextFormField(
                      controller: _userCtrl,
                      enabled: _editing,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.person_outline_rounded,
                            color: _editing ? kGreen : Colors.grey, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        filled: _editing,
                        fillColor: _editing ? kGreen.withValues(alpha: 0.04) : null,
                      ),
                      validator: (v) => v!.trim().length < 3 ? 'Min 3 characters' : null,
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(children: [
                        const Icon(Icons.email_outlined, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Text(widget.user.email, style: const TextStyle(color: Colors.grey)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          if (_editing)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _iconBtn(IconData icon, VoidCallback onTap, {Color color = Colors.grey}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      );

  Widget _statPill(String value, String label, IconData icon, Color color) =>
      Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ]);

  Widget _divider() => Container(width: 1, height: 40, color: Colors.grey.shade100);

  Widget _wasteBar(String label, int count, int total, Color color, IconData icon) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 14),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
          Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ])),
    ]);
  }
}

// ── Dashed ring avatar ────────────────────────────────────────────────────────
class _DashedAvatar extends StatelessWidget {
  final String initial;
  final String rankIcon;
  final Color rankColor;
  const _DashedAvatar({required this.initial, required this.rankIcon, required this.rankColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CustomPaint(
          painter: _DashedCirclePainter(color: kGreenLight),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(color: kGreen, fontSize: 36, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: rankColor,
            shape: BoxShape.circle,
            border: Border.all(color: kBg, width: 2),
          ),
          child: Text(rankIcon, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    const dashCount = 24;
    const dashAngle = 3.14159 * 2 / dashCount;
    const gapFraction = 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
