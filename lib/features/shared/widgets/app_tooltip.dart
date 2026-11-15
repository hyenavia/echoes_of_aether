import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';

/// Tooltip terpusat dengan styling Living Aether Camp untuk ikon/stat.
class AppTooltip extends StatelessWidget {
  const AppTooltip({
    super.key,
    required this.message,
    required this.child,
    this.preferBelow = true,
  });

  final String message;
  final Widget child;
  final bool preferBelow;

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) return child;
    return Tooltip(
      message: message,
      preferBelow: preferBelow,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs + 2,
      ),
      child: child,
    );
  }
}
