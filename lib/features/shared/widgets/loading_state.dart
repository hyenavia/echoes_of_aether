import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import 'panel_frame.dart';

/// State loading bertema Living Aether Camp agar transisi muat konsisten.
class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.title = 'Memuat Aether...',
    this.subtitle,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: AppColors.aetherBlue,
          ),
        ),
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );

    if (compact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: body,
        ),
      );
    }

    return Center(
      child: PanelFrame(
        showCornerOrnaments: true,
        padding: const EdgeInsets.all(AppSpacing.lg),
        borderColor: AppColors.aetherBlue.withValues(alpha: 0.45),
        child: body,
      ),
    );
  }
}
