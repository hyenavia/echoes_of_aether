import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';
import '../../../domain/entities/equipment.dart';
import '../../../domain/entities/item_definition.dart';
import 'locked_badge.dart';
import 'rarity_border.dart';
import 'rarity_label.dart';

/// Kartu item bersama dengan warna rarity, ikon slot/kategori, nama, stat
/// ringkas, dan dukungan state terkunci atau aksi trailing.
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.name,
    required this.rarity,
    this.slot,
    this.category,
    this.statsSummary,
    this.subtitle,
    this.quantity,
    this.isLocked = false,
    this.lockedReason,
    this.isSelected = false,
    this.useRarityGlow = false,
    this.trailing,
    this.onTap,
  });

  final String name;
  final ItemRarity rarity;
  final EquipmentSlot? slot;
  final ItemCategory? category;
  final String? statsSummary;
  final String? subtitle;
  final int? quantity;
  final bool isLocked;
  final String? lockedReason;
  final bool isSelected;
  final bool useRarityGlow;
  final Widget? trailing;
  final VoidCallback? onTap;

  IconData _resolveIcon() {
    if (slot != null) {
      return switch (slot!) {
        EquipmentSlot.weapon => Icons.hardware_outlined,
        EquipmentSlot.head => Icons.psychology_alt_outlined,
        EquipmentSlot.body => Icons.shield_outlined,
        EquipmentSlot.accessory => Icons.diamond_outlined,
      };
    }
    return switch (category) {
      ItemCategory.material => Icons.category_outlined,
      ItemCategory.consumable => Icons.local_drink_outlined,
      ItemCategory.questItem => Icons.auto_stories_outlined,
      _ => Icons.inventory_2_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final rarityColor = ext.colorForRarity(rarity);

    final cardContent = LayoutBuilder(
      builder: (context, constraints) {
        final stackTrailingBelow =
            trailing != null && constraints.maxWidth < 300;
        final bodyColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: AppSpacing.xs + 2,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  quantity != null ? '$name (x$quantity)' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                RarityLabel(rarity: rarity, compact: true),
              ],
            ),
            if (statsSummary != null && statsSummary!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                statsSummary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
            if (isLocked) ...[
              const SizedBox(height: AppSpacing.xs),
              LockedBadge(label: lockedReason ?? 'Terkunci'),
            ],
            if (stackTrailingBelow) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          ],
        );

        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: RarityBorder.decoration(
            context,
            rarity: rarity,
            isSelected: isSelected,
            isLocked: isLocked,
            useGlow: useRarityGlow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: rarityColor.withValues(alpha: 0.5)),
                ),
                child: Icon(_resolveIcon(), size: 20, color: rarityColor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: bodyColumn),
              if (trailing != null && !stackTrailingBelow) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        );
      },
    );

    if (onTap == null) return cardContent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: cardContent,
    );
  }
}
