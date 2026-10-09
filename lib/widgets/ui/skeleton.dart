import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// Shimmer loading placeholder. One animation drives every [SkeletonBox] inside it;
/// with "Remove animations" on, the boxes are shown without the moving highlight.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child, this.label = 'Loading'});

  final Widget child;
  final String label;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: AppMotion.ambient);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = c.surfaceAlt;
    final highlight = c.isDark ? c.border : c.surface;
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _ctrl,
          child: widget.child,
          builder: (_, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) {
              final dx = (_ctrl.value * 2 - 1) * rect.width;
              return LinearGradient(
                colors: [base, highlight, base],
                stops: const [0.35, 0.5, 0.65],
                transform: _Slide(dx),
              ).createShader(rect);
            },
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(dx, 0, 0);
}

/// A grey block inside a [Skeleton].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = AppRadius.md});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: context.colors.surfaceAlt, borderRadius: AppRadius.all(radius)),
      );
}

/// Placeholder for a list of card rows (icon, two lines of text, trailing pill).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.padding = const EdgeInsets.all(AppSpace.md)});

  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Skeleton(
        child: ListView.separated(
          padding: padding,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
          itemBuilder: (_, __) => const Row(children: [
            SkeletonBox(width: 44, height: 44, radius: AppRadius.md),
            SizedBox(width: AppSpace.sm),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(width: 140, height: 14),
              SizedBox(height: AppSpace.xs),
              SkeletonBox(width: 90, height: 12),
            ])),
            SkeletonBox(width: 56, height: 24, radius: AppRadius.pill),
          ]),
        ),
      );
}

/// Home while the first data loads: header block, two progress bars, the main button,
/// four stat tiles and the quick-access grid, in the real layout.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key, this.center});

  /// Shown in the middle of the header block (e.g. the brand loader).
  final Widget? center;

  @override
  Widget build(BuildContext context) => Stack(children: [
        Skeleton(
          label: 'Loading your home screen',
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              const SkeletonBox(height: 260, radius: 0),
              Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SkeletonBox(width: 180, height: 12),
                  const SizedBox(height: AppSpace.xs),
                  const SkeletonBox(height: 8),
                  const SizedBox(height: AppSpace.md),
                  const SkeletonBox(width: 150, height: 12),
                  const SizedBox(height: AppSpace.xs),
                  const SkeletonBox(height: 8),
                  const SizedBox(height: AppSpace.lg),
                  const SkeletonBox(height: 56, radius: AppRadius.lg),
                  const SizedBox(height: AppSpace.sm),
                  const SkeletonBox(height: 52, radius: AppRadius.lg),
                  const SizedBox(height: AppSpace.lg),
                  Row(children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpace.sm - 2),
                      const Expanded(child: SkeletonBox(height: 92, radius: AppRadius.lg)),
                    ],
                  ]),
                  const SizedBox(height: AppSpace.lg),
                  const Row(children: [
                    Expanded(child: SkeletonBox(height: 110, radius: AppRadius.xl)),
                    SizedBox(width: AppSpace.sm),
                    Expanded(child: SkeletonBox(height: 110, radius: AppRadius.xl)),
                  ]),
                ]),
              ),
            ],
          ),
        ),
        if (center != null) Positioned(left: 0, right: 0, top: 0, height: 260, child: Center(child: center)),
      ]);
}

/// Leaderboard while loading: a three-step podium, then rows.
class LeaderboardSkeleton extends StatelessWidget {
  const LeaderboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Skeleton(
        label: 'Loading the leaderboard',
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, 0),
          children: [
            const Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: _PodiumStep(height: 80)),
              SizedBox(width: AppSpace.sm),
              Expanded(child: _PodiumStep(height: 110)),
              SizedBox(width: AppSpace.sm),
              Expanded(child: _PodiumStep(height: 60)),
            ]),
            const SizedBox(height: AppSpace.lg),
            for (var i = 0; i < 5; i++) ...[
              const SkeletonBox(height: 62, radius: AppRadius.lg),
              const SizedBox(height: AppSpace.xs),
            ],
          ],
        ),
      );
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Column(children: [
        const SkeletonBox(width: 52, height: 52, radius: 26),
        const SizedBox(height: AppSpace.xs),
        const SkeletonBox(width: 60, height: 10),
        const SizedBox(height: AppSpace.xs),
        SkeletonBox(height: height, radius: AppRadius.sm),
      ]);
}

/// Admin dashboard while loading: three KPI tiles, the chart card, the analytics grid.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Skeleton(
        label: 'Loading the dashboard',
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpace.md),
          children: const [
            SizedBox(height: AppSpace.xl),
            Row(children: [
              Expanded(child: SkeletonBox(height: 72, radius: AppRadius.md)),
              SizedBox(width: AppSpace.sm - 2),
              Expanded(child: SkeletonBox(height: 72, radius: AppRadius.md)),
              SizedBox(width: AppSpace.sm - 2),
              Expanded(child: SkeletonBox(height: 72, radius: AppRadius.md)),
            ]),
            SizedBox(height: AppSpace.lg),
            SkeletonBox(height: 280, radius: AppRadius.xl),
            SizedBox(height: AppSpace.md),
            Row(children: [
              Expanded(child: SkeletonBox(height: 120, radius: AppRadius.xl)),
              SizedBox(width: AppSpace.sm),
              Expanded(child: SkeletonBox(height: 120, radius: AppRadius.xl)),
            ]),
          ],
        ),
      );
}
