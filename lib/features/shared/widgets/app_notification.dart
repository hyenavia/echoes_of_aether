import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';

enum AppNotificationKind { info, success, warning, danger }

/// Banner notifikasi in-app yang konsisten untuk info, hadiah, dan peringatan.
class AppNotificationBanner extends StatelessWidget {
  const AppNotificationBanner({
    super.key,
    required this.message,
    this.kind = AppNotificationKind.info,
    this.title,
    this.trailing,
  });

  final String message;
  final AppNotificationKind kind;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon) = switch (kind) {
      AppNotificationKind.info => (AppColors.aetherBlue, Icons.auto_awesome),
      AppNotificationKind.success => (
        AppColors.success,
        Icons.check_circle_outline,
      ),
      AppNotificationKind.warning => (
        AppColors.antiqueGold,
        Icons.warning_amber_rounded,
      ),
      AppNotificationKind.danger => (AppColors.emberRed, Icons.error_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.panelElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: color.withValues(alpha: 0.65),
          width: AppBorders.standard,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null && title!.isNotEmpty)
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Helper snackbar terpadu bertema Living Aether Camp.
void showAppNotification(
  BuildContext context, {
  required String message,
  AppNotificationKind kind = AppNotificationKind.info,
  String? title,
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: duration,
        padding: EdgeInsets.zero,
        content: AppNotificationBanner(
          message: message,
          kind: kind,
          title: title,
        ),
      ),
    );
}
