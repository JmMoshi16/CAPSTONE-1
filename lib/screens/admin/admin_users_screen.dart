import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../core/admin_theme.dart';

const kGreen = kAdminGreen;
const kDarkGreen = kAdminDGreen;
const kBlue = kAdminBlue;
const kDark = kAdminDark;
const kCard = kAdminCard;
const kBorder = kAdminBorder;


class AdminUsersScreen extends StatefulWidget {
  final List<UserModel> customers;
  final List<WasteLog> logs;
  const AdminUsersScreen({super.key, required this.customers, required this.logs});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _search = '';
  String _sortBy = 'points'; // 'points' | 'disposals' | 'name'

  List<UserModel> get _filtered {
    var list = widget.customers.where((u) =>
        u.username.toLowerCase().contains(_search.toLowerCase()) ||
        u.email.toLowerCase().contains(_search.toLowerCase())).toList();

    if (_sortBy == 'points') {
      list.sort((a, b) => b.points.compareTo(a.points));
    } else if (_sortBy == 'disposals') {
      list.sort((a, b) => _logCount(b.uid).compareTo(_logCount(a.uid)));
    } else {
      list.sort((a, b) => a.username.compareTo(b.username));
    }
    return list;
  }

  int _logCount(String uid) => widget.logs.where((l) => l.userId == uid).length;

  int _totalPoints() => widget.customers.fold(0, (s, u) => s + u.points);

  void _showUserDetail(UserModel u) {
    final userLogs = widget.logs.where((l) => l.userId == u.uid).toList();
    final bio = userLogs.where((l) => l.wasteType == 'Biodegradable').length;
    final rec = userLogs.where((l) => l.wasteType == 'Recyclable').length;
    final res = userLogs.where((l) => l.wasteType == 'Residual').length;
    final totalPts = userLogs.fold(0, (s, l) => s + l.pointsEarned);

    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),

              // User header
              Row(children: [
                _avatar(u, size: 60, fontSize: 26),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(u.email, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 6),
                  _rankBadge(u.points),
                ])),
              ]),
              const SizedBox(height: 24),

              // Stats row
              Row(children: [
                Expanded(child: _detailStat('${u.points}', 'Points', Icons.stars_rounded, Colors.amber)),
                const SizedBox(width: 10),
                Expanded(child: _detailStat('${userLogs.length}', 'Disposals', Icons.recycling_rounded, kGreen)),
                const SizedBox(width: 10),
                Expanded(child: _detailStat('$totalPts', 'Pts Earned', Icons.emoji_events_rounded, Colors.orange)),
              ]),
              const SizedBox(height: 20),

              // Waste breakdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorder)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Waste Breakdown', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 14),
                  _wasteBar('Biodegradable', bio, userLogs.length, const Color(0xFF8BC34A)),
                  const SizedBox(height: 10),
                  _wasteBar('Recyclable', rec, userLogs.length, kBlue),
                  const SizedBox(height: 10),
                  _wasteBar('Residual', res, userLogs.length, const Color(0xFFEF5350)),
                ]),
              ),

              // Recent logs
              if (userLogs.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Recent Activity', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 10),
                ...userLogs.take(3).map((log) {
                  final colors = {'Biodegradable': const Color(0xFF8BC34A), 'Recyclable': kBlue, 'Residual': const Color(0xFFEF5350)};
                  final icons = {'Biodegradable': Icons.compost_rounded, 'Recyclable': Icons.recycling_rounded, 'Residual': Icons.delete_outline_rounded};
                  final c = colors[log.wasteType] ?? kGreen;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
                    child: Row(children: [
                      Icon(icons[log.wasteType] ?? Icons.recycling_rounded, color: c, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(log.wasteType, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                      Text('+${log.pointsEarned} pts', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _wasteBar(String label, int count, int total, Color color) {
    final pct = total == 0 ? 0.0 : count / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: pct, backgroundColor: Colors.white.withValues(alpha: 0.06),
            valueColor: AlwaysStoppedAnimation(color), minHeight: 6),
      ),
    ]);
  }

  Widget _detailStat(String v, String l, IconData icon, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.2))),
        child: Column(children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(l, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalPts = _totalPoints();

    return Scaffold(
      backgroundColor: kDark,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(color: kCard,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
                  border: const Border(bottom: BorderSide(color: kBorder))),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(color: kBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kBlue.withValues(alpha: 0.3))),
                            child: const Icon(Icons.people_rounded, color: kBlue, size: 20)),
                        const SizedBox(width: 12),
                        const Text('Customers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kGreen.withValues(alpha: 0.3))),
                          child: Text('${widget.customers.length} users',
                              style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Summary stats
                      Row(children: [
                        Expanded(child: _headerStat('${widget.customers.length}', 'Total Users', Icons.person_rounded, kBlue)),
                        const SizedBox(width: 10),
                        Expanded(child: _headerStat('${widget.logs.length}', 'Disposals', Icons.recycling_rounded, kGreen)),
                        const SizedBox(width: 10),
                        Expanded(child: _headerStat('$totalPts', 'Pts Given', Icons.stars_rounded, Colors.amber)),
                      ]),
                      const SizedBox(height: 16),

                      // Search bar
                      Container(
                        decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kBorder)),
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'Search by name or email...',
                            hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded, color: Colors.white24, size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Sort chips
                      Row(children: [
                        const Text('Sort:', style: TextStyle(color: Colors.white38, fontSize: 12)),
                        const SizedBox(width: 8),
                        _sortChip('Points', 'points'),
                        const SizedBox(width: 6),
                        _sortChip('Disposals', 'disposals'),
                        const SizedBox(width: 6),
                        _sortChip('Name', 'name'),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // User list
          filtered.isEmpty
              ? SliverFillRemaining(
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_search_rounded, color: Colors.white24, size: 56),
                    const SizedBox(height: 12),
                    Text(_search.isEmpty ? 'No customers yet' : 'No results for "$_search"',
                        style: const TextStyle(color: Colors.white38, fontSize: 14)),
                  ])),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        // Top 3 get rank medals
                        final rank = _sortBy == 'points' || _sortBy == 'disposals' ? i : -1;
                        return _userCard(filtered[i], rank);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _userCard(UserModel u, int rank) {
    final userLogs = _logCount(u.uid);
    final medalColors = [Colors.amber, Colors.grey.shade400, const Color(0xFFCD7F32)];
    final medalIcons = ['🥇', '🥈', '🥉'];

    return GestureDetector(
      onTap: () => _showUserDetail(u),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: rank < 3 ? medalColors[rank].withValues(alpha: 0.3) : kBorder),
        ),
        child: Row(children: [
          // Rank number
          SizedBox(
            width: 28,
            child: rank < 3
                ? Text(medalIcons[rank], style: const TextStyle(fontSize: 20))
                : Text('${rank + 1}', style: const TextStyle(color: Colors.white24, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          _avatar(u, size: 46, fontSize: 18),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(u.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 6),
              _rankBadge(u.points, small: true),
            ]),
            const SizedBox(height: 2),
            Text(u.email, style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 13),
              const SizedBox(width: 3),
              Text('${u.points}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.recycling_rounded, color: Colors.white24, size: 12),
              const SizedBox(width: 3),
              Text('$userLogs', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ]),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
        ]),
      ),
    );
  }

  Widget _avatar(UserModel u, {required double size, required double fontSize}) {
    final colors = [
      [const Color(0xFF00E676), const Color(0xFF00C853)],
      [const Color(0xFF00B0FF), const Color(0xFF0081CB)],
      [const Color(0xFFFF6D00), const Color(0xFFE65100)],
      [const Color(0xFFD500F9), const Color(0xFF9C00D4)],
    ];
    final colorIdx = u.username.isNotEmpty ? u.username.codeUnitAt(0) % colors.length : 0;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors[colorIdx].cast<Color>()),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(child: Text(
        u.username.isNotEmpty ? u.username[0].toUpperCase() : 'U',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize),
      )),
    );
  }

  Widget _rankBadge(int points, {bool small = false}) {
    String label; Color color;
    if (points >= 500) { label = 'Platinum'; color = const Color(0xFF00B0FF); }
    else if (points >= 200) { label = 'Gold'; color = Colors.amber; }
    else if (points >= 50) { label = 'Silver'; color = Colors.grey.shade400; }
    else { label = 'Bronze'; color = const Color(0xFFCD7F32); }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(label, style: TextStyle(color: color, fontSize: small ? 9 : 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _headerStat(String v, String l, IconData icon, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.2))),
        child: Column(children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(l, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      );

  Widget _sortChip(String label, String value) {
    final selected = _sortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? kGreen.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kGreen.withValues(alpha: 0.5) : kBorder),
        ),
        child: Text(label, style: TextStyle(color: selected ? kGreen : Colors.white38,
            fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}
