import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';
import '../../../domain/entities/item_definition.dart';

/// Badge label rarity item dengan warna konsisten dari [EchoesThemeExtension].
class RarityLabel extends StatelessWidget {
  const RarityLabel({super.key, required this.rarity, this.compact = false});

  final ItemRarity rarity;
  final bool compact;

  static String labelOf(ItemRarity rarity) => switch (rarity) {
    ItemRarity.common => 'Common',
    ItemRarity.uncommon => 'Uncommon',
    ItemRarity.rare => 'Rare',
    ItemRarity.epic => 'Epic',
    ItemRarity.legendary => 'Legendary',
    ItemRarity.mythical => 'Mythical',
  };

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    final color = ext.colorForRarity(rarity);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs + 2 : AppSpacing.sm,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        labelOf(rarity),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
