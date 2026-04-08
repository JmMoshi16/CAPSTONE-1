import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';

const kGreen = Color(0xFF4CAF50);
const kDarkGreen = Color(0xFF2E7D32);

class ImpactScreen extends StatelessWidget {
  final List<WasteLog> logs;
  const ImpactScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final bio = logs.where((l) => l.wasteType == 'Biodegradable').length;
    final rec = logs.where((l) => l.wasteType == 'Recyclable').length;
    final res = logs.where((l) => l.wasteType == 'Residual').length;
    final totalPts = logs.fold(0, (s, l) => s + l.pointsEarned);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: kDarkGreen,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [kGreen, kDarkGreen], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Personal Impact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                        const SizedBox(height: 6),
                        const Text('Your recycling contribution', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _headerStat('${logs.length}', 'Total Logs'),
                            _headerStat('$totalPts', 'Points Earned'),
                            _headerStat('$rec', 'Recyclable'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Breakdown cards
                  Row(
                    children: [
                      Expanded(child: _typeCard('Biodegradable', bio, Icons.compost_rounded, const Color(0xFF8BC34A))),
                      const SizedBox(width: 10),
                      Expanded(child: _typeCard('Recyclable', rec, Icons.recycling_rounded, const Color(0xFF29B6F6))),
                      const SizedBox(width: 10),
                      Expanded(child: _typeCard('Residual', res, Icons.delete_outline_rounded, const Color(0xFFEF5350))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Disposal History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kDarkGreen)),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (logs.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.recycling_rounded, size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No disposal history yet', style: TextStyle(color: Colors.grey, fontSize: 15)),
                    Text('Scan a bin QR code to start!', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _logTile(logs[i]),
                  childCount: logs.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) => Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      );

  Widget _typeCard(String label, int count, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9), textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _logTile(WasteLog log) {
    final colors = {'Biodegradable': const Color(0xFF8BC34A), 'Recyclable': const Color(0xFF29B6F6), 'Residual': const Color(0xFFEF5350)};
    final icons = {'Biodegradable': Icons.compost_rounded, 'Recyclable': Icons.recycling_rounded, 'Residual': Icons.delete_outline_rounded};
    final color = colors[log.wasteType] ?? kGreen;
    final icon = icons[log.wasteType] ?? Icons.recycling_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.7), color]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(log.wasteType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEE, MMM d yyyy · h:mm a').format(log.timestamp), style: const TextStyle(fontSize: 11)),
            Text('Bin: ${log.binId}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('+${log.pointsEarned} pts', style: const TextStyle(color: kDarkGreen, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}
