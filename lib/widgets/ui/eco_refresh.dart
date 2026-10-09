import 'package:flutter/material.dart';
import '../../core/haptics.dart';
import '../../core/tokens.dart';
import '../eco_animations.dart';

/// Pull-to-refresh with the brand's own feedback instead of the Material spinner:
/// a leaf appears as you pull, turns green with "Release to refresh" (and a click) once
/// far enough, shows the brand loader while refreshing, then "Up to date". The pull
/// mechanics are Flutter's own (RefreshIndicator.noSpinner), so scrolling feels standard.
class EcoRefresh extends StatefulWidget {
  const EcoRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.edgeOffset = 0,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  /// Space above the pill (e.g. a header's height) so it appears below it.
  final double edgeOffset;
  final ScrollNotificationPredicate notificationPredicate;

  @override
  State<EcoRefresh> createState() => _EcoRefreshState();
}

class _EcoRefreshState extends State<EcoRefresh> {
  RefreshIndicatorStatus? _status;
  bool _done = false;

  void _onStatus(RefreshIndicatorStatus? s) {
    if (s == RefreshIndicatorStatus.armed && _status != RefreshIndicatorStatus.armed) AppHaptics.tap();
    setState(() => _status = s);
  }

  Future<void> _run() async {
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _done = true);
        Future.delayed(const Duration(milliseconds: 900), () { if (mounted) setState(() => _done = false); });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final s = _status;
    final refreshing = s == RefreshIndicatorStatus.refresh;
    final visible = _done || s == RefreshIndicatorStatus.drag || s == RefreshIndicatorStatus.armed || refreshing;

    final (Widget icon, String? label) = _done && !refreshing
        ? (Icon(Icons.check_circle_rounded, color: c.success, size: 22), 'Up to date')
        : refreshing
            ? (const EcoLoader(size: 30, semanticLabel: 'Refreshing'), 'Refreshing…')
            : s == RefreshIndicatorStatus.armed
                ? (Icon(Icons.eco_rounded, color: c.primary, size: 24), 'Release to refresh')
                : (Icon(Icons.eco_outlined, color: c.textSecondary, size: 22), null);

    return Stack(children: [
      RefreshIndicator.noSpinner(
        onRefresh: _run,
        onStatusChange: _onStatus,
        notificationPredicate: widget.notificationPredicate,
        child: widget.child,
      ),
      Positioned(
        top: widget.edgeOffset + MediaQuery.paddingOf(context).top + AppSpace.sm,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, -1.5),
              duration: AppMotion.of(context, AppMotion.medium),
              curve: AppMotion.spring,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: AppMotion.of(context, AppMotion.fast),
                child: Semantics(
                  liveRegion: true,
                  label: label,
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.medium),
                    padding: EdgeInsets.symmetric(horizontal: label == null ? AppSpace.xs : AppSpace.md, vertical: AppSpace.xs),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: AppRadius.all(AppRadius.pill),
                      border: Border.all(color: s == RefreshIndicatorStatus.armed ? c.primary : c.border),
                      boxShadow: AppShadows.e2,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedScale(
                        scale: s == RefreshIndicatorStatus.armed ? 1.15 : 1,
                        duration: AppMotion.of(context, AppMotion.fast),
                        child: SizedBox(width: 30, height: 30, child: Center(child: icon)),
                      ),
                      if (label != null) ...[
                        const SizedBox(width: AppSpace.xs),
                        Text(label, style: t.labelMedium),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
