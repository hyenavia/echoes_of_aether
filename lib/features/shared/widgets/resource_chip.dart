import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';
import '../../../core/utils/number_formatter.dart';

enum ResourceChipKind { gold, rank, neutral }

/// Chip ringkas untuk menampilkan resource (Gold, Ascension Rank, atau metrik).
class ResourceChip extends StatelessWidget {
  const ResourceChip({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.kind = ResourceChipKind.neutral,
    this.accentColor,
  });

  factory ResourceChip.gold(int amount, {Key? key}) => ResourceChip(
    key: key,
    label: 'Gold',
    value: NumberFormatter.format(amount),
    icon: Icons.monetization_on_outlined,
    kind: ResourceChipKind.gold,
  );

  factory ResourceChip.rank(int rank, {Key? key}) => ResourceChip(
    key: key,
    label: 'Rank',
    value: NumberFormatter.format(rank),
    icon: Icons.auto_awesome_outlined,
    kind: ResourceChipKind.rank,
  );

  final String label;
  final String value;
  final IconData? icon;
  final ResourceChipKind kind;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    final color =
        accentColor ??
        switch (kind) {
          ResourceChipKind.gold => ext.gold,
          ResourceChipKind.rank => ext.rank,
          ResourceChipKind.neutral => Theme.of(context).colorScheme.primary,
        };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              '$label $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
