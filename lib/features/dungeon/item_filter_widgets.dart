import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/item_definition.dart';

enum ItemCategoryFilter {
  all,
  weapon,
  armor,
  accessory,
  material,
  consumable,
  quest,
}

String itemCategoryFilterLabel(ItemCategoryFilter filter) => switch (filter) {
  ItemCategoryFilter.all => 'Semua',
  ItemCategoryFilter.weapon => 'Senjata',
  ItemCategoryFilter.armor => 'Armor',
  ItemCategoryFilter.accessory => 'Aksesori',
  ItemCategoryFilter.material => 'Material',
  ItemCategoryFilter.consumable => 'Consumable',
  ItemCategoryFilter.quest => 'Quest',
};

String equipmentSlotCategoryLabel(EquipmentSlot slot) => switch (slot) {
  EquipmentSlot.weapon => 'Senjata',
  EquipmentSlot.head => 'Armor • Kepala',
  EquipmentSlot.body => 'Armor • Badan',
  EquipmentSlot.accessory => 'Aksesori',
};

String itemCategoryBadgeLabel(ItemDefinition def) {
  final slot = def.equipment?.slot;
  if (slot != null) {
    return equipmentSlotCategoryLabel(slot);
  }
  return switch (def.category) {
    ItemCategory.material => 'Material',
    ItemCategory.consumable => 'Consumable',
    ItemCategory.questItem => 'Quest',
    ItemCategory.equipment => 'Perlengkapan',
  };
}

String itemRarityLabel(ItemRarity rarity) => switch (rarity) {
  ItemRarity.common => 'Common',
  ItemRarity.uncommon => 'Uncommon',
  ItemRarity.rare => 'Rare',
  ItemRarity.epic => 'Epic',
  ItemRarity.legendary => 'Legendary',
};

Color itemRarityColor(ItemRarity rarity) => AppColors.colorForRarity(rarity);

bool matchesEquipmentFilter(
  EquipmentSlot slot,
  ItemRarity itemRarity,
  ItemCategoryFilter categoryFilter,
  ItemRarity? rarityFilter,
) {
  if (rarityFilter != null && itemRarity != rarityFilter) {
    return false;
  }
  return switch (categoryFilter) {
    ItemCategoryFilter.all => true,
    ItemCategoryFilter.weapon => slot == EquipmentSlot.weapon,
    ItemCategoryFilter.armor =>
      slot == EquipmentSlot.head || slot == EquipmentSlot.body,
    ItemCategoryFilter.accessory => slot == EquipmentSlot.accessory,
    _ => false,
  };
}

bool matchesItemFilters(
  ItemDefinition def,
  ItemCategoryFilter categoryFilter,
  ItemRarity? rarityFilter,
) {
  if (rarityFilter != null && def.rarity != rarityFilter) {
    return false;
  }
  return switch (categoryFilter) {
    ItemCategoryFilter.all => true,
    ItemCategoryFilter.weapon => def.equipment?.slot == EquipmentSlot.weapon,
    ItemCategoryFilter.armor =>
      def.equipment?.slot == EquipmentSlot.head ||
          def.equipment?.slot == EquipmentSlot.body,
    ItemCategoryFilter.accessory =>
      def.equipment?.slot == EquipmentSlot.accessory,
    ItemCategoryFilter.material => def.category == ItemCategory.material,
    ItemCategoryFilter.consumable => def.category == ItemCategory.consumable,
    ItemCategoryFilter.quest => def.category == ItemCategory.questItem,
  };
}

Widget buildItemCategoryBadge(ThemeData theme, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: theme.textTheme.labelSmall),
  );
}

Widget buildItemRarityBadge(ThemeData theme, ItemRarity rarity) {
  final color = itemRarityColor(rarity);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      itemRarityLabel(rarity),
      style: theme.textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget buildItemFilterBar({
  required List<ItemCategoryFilter> categories,
  required ItemCategoryFilter categoryFilter,
  required ItemRarity? rarityFilter,
  required ValueChanged<ItemCategoryFilter> onCategoryChanged,
  required ValueChanged<ItemRarity?> onRarityChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final cat in categories) ...[
              ChoiceChip(
                label: Text(itemCategoryFilterLabel(cat)),
                selected: categoryFilter == cat,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                onSelected: (_) => onCategoryChanged(cat),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
      const SizedBox(height: 4),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('Semua Rarity'),
              selected: rarityFilter == null,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              onSelected: (_) => onRarityChanged(null),
            ),
            const SizedBox(width: 6),
            for (final rarity in ItemRarity.values) ...[
              ChoiceChip(
                label: Text(
                  itemRarityLabel(rarity),
                  style: TextStyle(color: itemRarityColor(rarity)),
                ),
                selected: rarityFilter == rarity,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                onSelected: (_) =>
                    onRarityChanged(rarityFilter == rarity ? null : rarity),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    ],
  );
}
