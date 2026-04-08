import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../login_screen.dart';

const kGreen = Color(0xFF4CAF50);
const kDarkGreen = Color(0xFF2E7D32);
const kBg = Color(0xFFF5F7FA);

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
  bool _saving = false;

  @override
  void dispose() { _userCtrl.dispose(); super.dispose(); }

  // Rank system
  Map<String, dynamic> get _rank {
    final pts = widget.user.points;
    if (pts >= 500) return {'label': 'Platinum', 'color': const Color(0xFF00B0FF), 'icon': '💎', 'next': null, 'nextPts': 500};
    if (pts >= 200) return {'label': 'Gold', 'color': Colors.amber, 'icon': '🥇', 'next': 'Platinum', 'nextPts': 500};
    if (pts >= 50)  return {'label': 'Silver', 'color': Colors.grey.shade400, 'icon': '🥈', 'next': 'Gold', 'nextPts': 200};
    return {'label': 'Bronze', 'color': const Color(0xFFCD7F32), 'icon': '🥉', 'next': 'Silver', 'nextPts': 50};
  }

  double get _rankProgress {
    final pts = widget.user.points;
    if (pts >= 500) return 1.0;
    if (pts >= 200) return (pts - 200) / (500 - 200);
    if (pts >= 50)  return (pts - 50) / (200 - 50);
    return pts / 50;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    widget.user.username = _userCtrl.text.trim();
    await FirebaseService.updateUser(widget.user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', widget.user.username);
    widget.onUpdated();
    if (mounted) {
      setState(() { _editing = false; _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Profile updated!'),
        backgroundColor: kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
    final totalPts = widget.logs.fold(0, (s, l) => s + l.pointsEarned);
    final bio = widget.logs.where((l) => l.wasteType == 'Biodegradable').length;
    final rec = widget.logs.where((l) => l.wasteType == 'Recyclable').length;
    final res = widget.logs.where((l) => l.wasteType == 'Residual').length;
    final rank = _rank;
    final rankColor = rank['color'] as Color;

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    children: [
                      // Top actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          Row(children: [
                            GestureDetector(
                              onTap: () => setState(() {
                                _editing = !_editing;
                                if (!_editing) _userCtrl.text = widget.user.username;
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                child: Icon(_editing ? Icons.close_rounded : Icons.edit_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _logout,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.logout_rounded, color: Colors.white70, size: 18),
                              ),
                            ),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Avatar
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 88, height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: Center(child: Text(
                              widget.user.username.isNotEmpty ? widget.user.username[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                            )),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: rankColor, shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2)),
                            child: Text(rank['icon'], style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(widget.user.username, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(widget.user.email, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                      const SizedBox(height: 10),

                      // Rank badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: rankColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: rankColor.withOpacity(0.5)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(rank['icon'], style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text('${rank['label']} Member', style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(children: [
                    Expanded(child: _statCard('${widget.user.points}', 'Points', Icons.stars_rounded, Colors.amber)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('${widget.logs.length}', 'Disposals', Icons.recycling_rounded, kGreen)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('$totalPts', 'Earned', Icons.emoji_events_rounded, Colors.orange)),
                  ]),
                  const SizedBox(height: 16),

                  // Rank progress card
                  if (rank['next'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.military_tech_rounded, color: rankColor, size: 20),
                          const SizedBox(width: 8),
                          Text('Progress to ${rank['next']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          Text('${widget.user.points} / ${rank['nextPts']} pts',
                              style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ]),
                        const SizedBox(height: 10),
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
                    const SizedBox(height: 16),
                  ],

                  // Waste breakdown
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Icon(Icons.pie_chart_rounded, color: kGreen, size: 18),
                        SizedBox(width: 8),
                        Text('Waste Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                      const SizedBox(height: 14),
                      _wasteBar('Biodegradable', bio, widget.logs.length, const Color(0xFF8BC34A), Icons.compost_rounded),
                      const SizedBox(height: 10),
                      _wasteBar('Recyclable', rec, widget.logs.length, const Color(0xFF29B6F6), Icons.recycling_rounded),
                      const SizedBox(height: 10),
                      _wasteBar('Residual', res, widget.logs.length, const Color(0xFFEF5350), Icons.delete_outline_rounded),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Account info / edit form
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(children: [
                            Container(padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.person_outline_rounded, color: kGreen, size: 18)),
                            const SizedBox(width: 10),
                            const Text('Account Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ]),
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),
                        TextFormField(
                          controller: _userCtrl,
                          enabled: _editing,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline_rounded, color: _editing ? kGreen : Colors.grey, size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            filled: _editing,
                            fillColor: _editing ? kGreen.withOpacity(0.04) : null,
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

                  if (_editing) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity, height: 54,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: kGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                        child: _saving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ]),
      );

  Widget _wasteBar(String label, int count, int total, Color color, IconData icon) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(children: [
      Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 14)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(color), minHeight: 6),
        ),
      ])),
    ]);
  }
}
