import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';

const _kGreen = Color(0xFF2E7D32);
const _kGreenLight = Color(0xFF4CAF50);

class ScanHistoryScreen extends StatefulWidget {
  final List<WasteLog> logs;
  const ScanHistoryScreen({super.key, required this.logs});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  String _filter = 'All';

  static const _types = ['All', 'Biodegradable', 'Recyclable', 'Residual'];

  static const _colors = {
    'Biodegradable': Color(0xFF8BC34A),
    'Recyclable': Color(0xFF29B6F6),
    'Residual': Color(0xFFEF5350),
  };

  static const _icons = {
    'Biodegradable': Icons.compost_rounded,
    'Recyclable': Icons.recycling_rounded,
    'Residual': Icons.delete_outline_rounded,
  };

  List<WasteLog> get _filtered =>
      _filter == 'All' ? widget.logs : widget.logs.where((l) => l.wasteType == _filter).toList();

  int get _totalPoints => widget.logs.fold(0, (s, l) => s + l.pointsEarned);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: _kGreen,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        const Text('Scan History',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                        const SizedBox(height: 4),
                        Text('${widget.logs.length} scans · $_totalPoints pts total',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 16),
                        // Summary chips
                        Row(children: [
                          _summaryChip('🌿', '${widget.logs.where((l) => l.wasteType == 'Biodegradable').length}', 'Bio'),
                          const SizedBox(width: 8),
                          _summaryChip('♻️', '${widget.logs.where((l) => l.wasteType == 'Recyclable').length}', 'Rec'),
                          const SizedBox(width: 8),
                          _summaryChip('🗑️', '${widget.logs.where((l) => l.wasteType == 'Residual').length}', 'Res'),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            // Filter chips
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _types.length,
                itemBuilder: (_, i) {
                  final t = _types[i];
                  final selected = _filter == t;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? _kGreenLight : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? _kGreenLight : Colors.grey.shade200),
                      ),
                      child: Text(t,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.grey,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          )),
                    ),
                  );
                },
              ),
            ),

            // List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          _filter == 'All' ? 'No scans yet' : 'No $_filter scans',
                          style: const TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _logTile(filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String emoji, String count, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text('$count $label', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _logTile(WasteLog log) {
    final color = _colors[log.wasteType] ?? _kGreenLight;
    final icon = _icons[log.wasteType] ?? Icons.recycling_rounded;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(log.wasteType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              DateFormat('MMM d, yyyy · h:mm a').format(log.timestamp),
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kGreenLight.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('+${log.pointsEarned} pts',
              style: const TextStyle(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ]),
    );
  }
}
