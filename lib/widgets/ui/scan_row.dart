import 'package:flutter/material.dart';
import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart' show wasteIcon;
import '../../core/tokens.dart';
import '../../models/models.dart';
import 'marks.dart';
import 'surfaces.dart';

/// One disposal in a list: the bin's mark, the waste type, when, and the points credited.
/// Standalone it is its own card; [grouped] rows sit inside one card, separated by dividers (Home).
class AppScanRow extends StatelessWidget {
  const AppScanRow({super.key, required this.log, required this.onTap, this.grouped = false});

  final WasteLog log;
  final VoidCallback onTap;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final when = AppDates.moment(log.timestamp);
    final label = '${log.wasteType} scan, +${log.pointsAwarded} points, $when, details';
    final mark = Medallion(icon: wasteIcon(log.wasteType), color: c.waste(log.wasteType), size: 40);
    final points = PointsPill('+${log.pointsAwarded} pts');
    final whenText = Text(when, style: context.text.bodySmall);
    if (!grouped) {
      return AppListTile(
        margin: const EdgeInsets.only(bottom: AppSpace.sm - 2),
        leading: mark,
        title: log.wasteType,
        subtitle: whenText,
        trailing: points,
        onTap: onTap,
        semanticLabel: label,
      );
    }
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () {
          AppHaptics.tap();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
          child: Row(children: [
            mark,
            const SizedBox(width: AppSpace.sm),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(log.wasteType, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              whenText,
            ])),
            const SizedBox(width: AppSpace.xs),
            points,
          ]),
        ),
      ),
    );
  }
}
