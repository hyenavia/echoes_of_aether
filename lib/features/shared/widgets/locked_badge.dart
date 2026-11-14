import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';

/// Badge penanda item/fitur/dungeon yang masih terkunci beserta alasannya.
class LockedBadge extends StatelessWidget {
  const LockedBadge({super.key, this.label = 'Terkunci'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: ext.locked.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: ext.locked.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 13, color: ext.locked),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: ext.locked, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
