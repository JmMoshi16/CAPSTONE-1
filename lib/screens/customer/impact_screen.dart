import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../core/theme.dart';

class ImpactScreen extends StatefulWidget {
  final List<WasteLog> logs;
  const ImpactScreen({super.key, required this.logs});
  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late AnimationController _bodyCtrl;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _bodyCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _bodyCtrl.forward(); });
  }

  @override
  void dispose() { _headerCtrl.dispose(); _bodyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bio      = widget.logs.where((l) => l.wasteType == 'Biodegradable').length;
    final rec      = widget.logs.where((l) => l.wasteType == 'Recyclable').length;
    final res      = widget.logs.where((l) => l.wasteType == 'Residual').length;
    final totalPts = widget.logs.fold(0, (s, l) => s + l.pointsEarned);

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: kGreen,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: FadeTransition(
                opacity: _headerFade,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kGreenLight, kGreen],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Personal Impact',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                        const SizedBox(height: 6),
                        const Text('Your recycling contribution',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          _CountUpStat(end: widget.logs.length, label: 'Total Logs', ctrl: _headerCtrl),
                          _CountUpStat(end: totalPts, label: 'Points Earned', ctrl: _headerCtrl),
                          _CountUpStat(end: rec, label: 'Recyclable', ctrl: _headerCtrl),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: _PopInCard(index: 0, ctrl: _bodyCtrl,
                      child: _typeCard('Biodegradable', bio, Icons.compost_rounded, kBioColor))),
                  const SizedBox(width: 10),
                  Expanded(child: _PopInCard(index: 1, ctrl: _bodyCtrl,
                      child: _typeCard('Recyclable', rec, Icons.recycling_rounded, kRecColor))),
                  const SizedBox(width: 10),
                  Expanded(child: _PopInCard(index: 2, ctrl: _bodyCtrl,
                      child: _typeCard('Residual', res, Icons.delete_outline_rounded, kResColor))),
                ]),
                const SizedBox(height: 20),
                const Text('Disposal History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kGreen)),
                const SizedBox(height: 12),
              ]),
            ),
          ),

          if (widget.logs.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.recycling_rounded, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text('No disposal history yet', style: TextStyle(color: Colors.grey, fontSize: 15)),
                Text('Scan a bin QR code to start!', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ])),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _FadeSlideItem(index: i, ctrl: _bodyCtrl, child: _logTile(widget.logs[i])),
                  childCount: widget.logs.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _typeCard(String label, int count, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(height: 6),
      Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9), textAlign: TextAlign.center),
    ]),
  );

  Widget _logTile(WasteLog log) {
    final color = wasteColor(log.wasteType);
    final icon  = wasteIcon(log.wasteType);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(log.wasteType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('EEE, MMM d yyyy · h:mm a').format(log.timestamp),
              style: const TextStyle(fontSize: 11)),
          Text('Bin: ${log.binId}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: kGreenLight.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('+${log.pointsEarned} pts',
              style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}

// ── Count-up stat widget ──────────────────────────────────────────────────────
class _CountUpStat extends StatelessWidget {
  final int end;
  final String label;
  final AnimationController ctrl;
  const _CountUpStat({required this.end, required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final anim = Tween<double>(begin: 0, end: end.toDouble())
        .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    return Column(children: [
      AnimatedBuilder(
        animation: anim,
        builder: (_, __) => Text('${anim.value.toInt()}',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}

// ── Pop-in card wrapper ───────────────────────────────────────────────────────
class _PopInCard extends StatefulWidget {
  final int index;
  final AnimationController ctrl;
  final Widget child;
  const _PopInCard({required this.index, required this.ctrl, required this.child});
  @override
  State<_PopInCard> createState() => _PopInCardState();
}

class _PopInCardState extends State<_PopInCard> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    Future.delayed(Duration(milliseconds: 100 + widget.index * 100), () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}

// ── Fade+slide list item ──────────────────────────────────────────────────────
class _FadeSlideItem extends StatefulWidget {
  final int index;
  final AnimationController ctrl;
  final Widget child;
  const _FadeSlideItem({required this.index, required this.ctrl, required this.child});
  @override
  State<_FadeSlideItem> createState() => _FadeSlideItemState();
}

class _FadeSlideItemState extends State<_FadeSlideItem> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade  = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    final delay = (widget.index * 50).clamp(0, 500);
    Future.delayed(Duration(milliseconds: 200 + delay), () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}
