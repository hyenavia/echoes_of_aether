import 'equipment.dart';
import 'item_definition.dart';

/// Definisi set equipment Mythical (2-piece universal + 4-piece class-locked).
class MythicalSetDefinition {
  const MythicalSetDefinition({
    required this.id,
    required this.name,
    required this.signatureClassId,
    required this.twoPieceBonus,
    required this.twoPieceDescription,
    required this.fourPieceDescription,
  });

  final String id;
  final String name;
  final String signatureClassId;
  final EquipmentStats twoPieceBonus;
  final String twoPieceDescription;
  final String fourPieceDescription;
}

/// Resep penempaan equipment Mythical non-weapon di Blacksmith (Tempa Mythical).
class MythicalForgeRecipe {
  const MythicalForgeRecipe({
    required this.id,
    required this.targetItemId,
    required this.setId,
    required this.requiredCatalystWeaponId,
    this.sacrificeMinRarity = ItemRarity.legendary,
    required this.goldCost,
    required this.materials,
  });

  final String id;
  final String targetItemId;
  final String setId;
  final String requiredCatalystWeaponId;
  final ItemRarity sacrificeMinRarity;
  final int goldCost;
  final Map<String, int> materials;
}

/// Konfigurasi lengkap set equipment Mythical dan resep penempaannya.
class MythicalForgeConfig {
  const MythicalForgeConfig({this.sets = const {}, this.recipes = const {}});

  final Map<String, MythicalSetDefinition> sets;
  final Map<String, MythicalForgeRecipe> recipes;

  bool get isEmpty => sets.isEmpty && recipes.isEmpty;
}
