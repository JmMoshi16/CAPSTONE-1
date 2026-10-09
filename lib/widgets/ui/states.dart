import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import 'app_button.dart';

/// Friendly "nothing here yet" message with an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.emoji,
    this.actionLabel,
    this.onAction,
    this.dense = false,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final String? emoji;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final circle = dense ? 64.0 : 88.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl, vertical: AppSpace.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: circle,
            height: circle,
            decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: emoji != null
                ? ExcludeSemantics(child: Text(emoji!, style: TextStyle(fontSize: circle * 0.45)))
                : Icon(icon ?? Icons.inbox_rounded, size: circle * 0.45, color: c.textTertiary),
          ),
          const SizedBox(height: AppSpace.md),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: AppSpace.xxs),
            Text(message!, style: context.text.bodyMedium!.copyWith(color: c.textSecondary),
                textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpace.md),
            AppButton.secondary(label: actionLabel!, onPressed: onAction, expand: false),
          ],
        ]),
      ),
    );
  }
}

/// Failure message with a Retry button. Never shows raw exception text.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Check your connection and try again.',
    this.icon = Icons.wifi_off_rounded,
    required this.onRetry,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl, vertical: AppSpace.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: c.dangerContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: c.danger),
          ),
          const SizedBox(height: AppSpace.md),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.xxs),
          Text(message, style: context.text.bodyMedium!.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.lg),
          AppButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: onRetry, expand: false),
        ]),
      ),
    );
  }
}
