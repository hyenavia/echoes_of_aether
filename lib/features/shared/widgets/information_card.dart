import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import 'panel_frame.dart';

/// Kartu informasi ringkas untuk statistik, status fitur, atau catatan RPG.
class InformationCard extends StatelessWidget {
  const InformationCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = accentColor ?? AppColors.aetherBlue;

    final content = PanelFrame(
      padding: padding,
      borderColor: tint.withValues(alpha: 0.45),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: tint.withValues(alpha: 0.45)),
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.numeric(
                    theme.textTheme.titleMedium,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
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

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: content,
    );
  }
}
