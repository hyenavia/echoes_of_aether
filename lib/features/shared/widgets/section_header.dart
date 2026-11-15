import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';

/// Header seksi dengan aksen bar RPG dan widget trailing opsional.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.useSerif = false,
  });

  final String title;
  final Widget? trailing;
  final bool useSerif;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final baseStyle = theme.textTheme.labelLarge?.copyWith(
      color: ext.gold,
      letterSpacing: 0.4,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: ext.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: useSerif
                  ? AppTypography.headingSerif(baseStyle, color: ext.gold)
                  : baseStyle,
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
