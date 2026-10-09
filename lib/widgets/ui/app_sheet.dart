import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// Bottom sheet scaffold: drag handle, title row, divider, then scrollable content.
class AppSheet {
  /// Draggable sheet; [builder] receives the scroll controller for its list.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    Widget? trailing,
    double initialSize = 0.6,
    double minSize = 0.35,
    double maxSize = 0.9,
    required Widget Function(BuildContext, ScrollController) builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: initialSize,
        minChildSize: minSize,
        maxChildSize: maxSize,
        expand: false,
        builder: (ctx, scroll) => Column(children: [
          const _Handle(),
          _Header(title: title, trailing: trailing),
          const Divider(height: 1),
          Expanded(child: builder(ctx, scroll)),
        ]),
      ),
    );
  }

  /// Sheet sized to its content that moves above the keyboard (forms).
  static Future<T?> showForm<T>(
    BuildContext context, {
    required String title,
    required Widget Function(BuildContext) builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Handle(),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            ),
            builder(ctx),
          ]),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpace.sm),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outline,
            borderRadius: AppRadius.all(2),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (trailing != null) trailing!,
        ]),
      );
}
