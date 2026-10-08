import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';
import '../../core/theme.dart';

class BadgesScreen extends StatefulWidget {
  final UserModel user;
  const BadgesScreen({super.key, required this.user});
  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> with SingleTickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
    _headerCtrl.forward();
  }

  @override
  void dispose() { _headerCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final allDefs    = FirebaseService.getAllBadgeDefs();
    final earned     = widget.user.badges;
    final earnedDefs = allDefs.where((b) => earned.contains(b['id'])).toList();
    final lockedDefs = allDefs.where((b) => !earned.contains(b['id'])).toList();

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
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
                          const Text('My Badges', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                        ]),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _headerStat('${earnedDefs.length}', 'Earned'),
                            Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.3)),
                            _headerStat('${lockedDefs.length}', 'Locked'),
                            Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.3)),
                            _headerStat('${allDefs.length}', 'Total'),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (earnedDefs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(children: [
                  const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text('Earned (${earnedDefs.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _AnimatedBadgeCard(def: earnedDefs[i], earned: true, index: i),
                  childCount: earnedDefs.length,
                ),
              ),
            ),
          ],

          if (lockedDefs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(children: [
                  Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text('Locked (${lockedDefs.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _AnimatedBadgeCard(def: lockedDefs[i], earned: false, index: i + earnedDefs.length),
                  childCount: lockedDefs.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
  ]);
}

class _AnimatedBadgeCard extends StatefulWidget {
  final Map<String, dynamic> def;
  final bool earned;
  final int index;
  const _AnimatedBadgeCard({required this.def, required this.earned, required this.index});
  @override
  State<_AnimatedBadgeCard> createState() => _AnimatedBadgeCardState();
}

class _AnimatedBadgeCardState extends State<_AnimatedBadgeCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    final delay = (widget.index * 70).clamp(0, 600);
    Future.delayed(Duration(milliseconds: 100 + delay), () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.earned ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: widget.earned
              ? Border.all(color: Colors.amber.shade300, width: 1.5)
              : Border.all(color: Colors.grey.shade200),
          boxShadow: widget.earned
              ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          widget.earned
              ? Text(widget.def['icon'] as String, style: const TextStyle(fontSize: 36))
              : Stack(alignment: Alignment.center, children: [
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0,      0,      0,      0.4, 0,
                    ]),
                    child: Text(widget.def['icon'] as String, style: const TextStyle(fontSize: 36)),
                  ),
                  const Icon(Icons.lock_rounded, color: Colors.grey, size: 18),
                ]),
          const SizedBox(height: 8),
          Text(widget.def['label'] as String,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                  color: widget.earned ? Colors.black87 : Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(widget.def['desc'] as String,
              style: TextStyle(fontSize: 10, color: widget.earned ? Colors.grey : Colors.grey.shade400),
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (widget.earned) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text('✓ Earned', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
      ),
    ),
  );
}
