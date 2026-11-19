import 'dart:math' as math;

import '../entities/equipment.dart';
import '../entities/equipment_config.dart';
import '../entities/equipment_loadout.dart';
import '../entities/inventory.dart';
import '../entities/item_definition.dart';
import '../entities/player_character.dart';

/// Status hasil percobaan upgrade (enhance) equipment.
enum BlacksmithEnhanceStatus {
  success,
  itemNotFound,
  maxLevelReached,
  insufficientGold,
  insufficientMaterials,
}

/// Hasil eksekusi peningkatan (enhance) equipment oleh [BlacksmithService].
class BlacksmithEnhanceResult {
  const BlacksmithEnhanceResult({
    required this.status,
    this.updatedInstance,
    this.goldSpent = 0,
    this.materialsSpent = const {},
  });

  final BlacksmithEnhanceStatus status;
  final EquipmentInstance? updatedInstance;
  final int goldSpent;
  final Map<String, int> materialsSpent;

  bool get isSuccess => status == BlacksmithEnhanceStatus.success;
}

/// Prasyarat biaya gold dan material untuk meningkatkan equipment ke tingkat tertentu.
class BlacksmithEnhanceRequirement {
  const BlacksmithEnhanceRequirement({
    required this.targetLevel,
    required this.goldCost,
    required this.requiredMaterials,
  });

  final int targetLevel;
  final int goldCost;
  final Map<String, int> requiredMaterials;
}

/// Status hasil perombakan ulang (reforge) sub-stat equipment.
enum BlacksmithReforgeStatus {
  success,
  itemNotFound,
  definitionNotFound,
  ineligibleRarity,
  fixedStatsNotReforgeable,
  insufficientGold,
}

/// Hasil eksekusi reforge sub-stat equipment oleh [BlacksmithService].
class BlacksmithReforgeResult {
  const BlacksmithReforgeResult({
    required this.status,
    this.updatedInstance,
    this.goldSpent = 0,
    this.oldStats,
    this.newStats,
  });

  final BlacksmithReforgeStatus status;
  final EquipmentInstance? updatedInstance;
  final int goldSpent;
  final EquipmentStats? oldStats;
  final EquipmentStats? newStats;

  bool get isSuccess => status == BlacksmithReforgeStatus.success;
}

/// Status hasil pembongkaran (salvage) equipment menjadi Aether Scrap.
enum BlacksmithSalvageStatus {
  success,
  itemNotFound,
  cannotSalvageEquipped,
  cannotSalvageMythical,
  definitionNotFound,
  inventoryFull,
}

/// Hasil eksekusi salvage equipment oleh [BlacksmithService].
class BlacksmithSalvageResult {
  const BlacksmithSalvageResult({
    required this.status,
    this.salvagedInstance,
    this.aetherScrapGained = 0,
  });

  final BlacksmithSalvageStatus status;
  final EquipmentInstance? salvagedInstance;
  final int aetherScrapGained;

  bool get isSuccess => status == BlacksmithSalvageStatus.success;
}

/// Service domain murni untuk pandai besi (Blacksmith):
/// 1. Equipment Enhancement (+1 s/d +10) menggunakan Gold dan Material Monster.
/// 2. Sub-stat Reforge untuk equipment Rare, Epic, dan Legendary menggunakan Gold.
/// 3. Equipment Salvage untuk membongkar perlengkapan menjadi Aether Scrap.
class BlacksmithService {
  const BlacksmithService({this.equipmentConfig = const EquipmentConfig()});

  static const String aetherScrapItemId = 'aether_scrap';

  final EquipmentConfig equipmentConfig;

  /// Batas level enhancement maksimum pada equipment.
  static const int maxEnhancementLevel = 10;

  /// Rasio peningkatan stat flat (HP, ATK, DEF) per level enhancement (+5% per level).
  static const double statBonusPerLevel = 0.05;

  /// Tabel biaya gold dan kebutuhan material per target level enhancement (+1..+10).
  static const Map<int, BlacksmithEnhanceRequirement> _enhanceRequirements = {
    1: BlacksmithEnhanceRequirement(
      targetLevel: 1,
      goldCost: 5000,
      requiredMaterials: {'slime_gel': 3},
    ),
    2: BlacksmithEnhanceRequirement(
      targetLevel: 2,
      goldCost: 12000,
      requiredMaterials: {'slime_gel': 5},
    ),
    3: BlacksmithEnhanceRequirement(
      targetLevel: 3,
      goldCost: 25000,
      requiredMaterials: {'wolf_fang': 5},
    ),
    4: BlacksmithEnhanceRequirement(
      targetLevel: 4,
      goldCost: 50000,
      requiredMaterials: {'corrupted_bark': 3},
    ),
    5: BlacksmithEnhanceRequirement(
      targetLevel: 5,
      goldCost: 100000,
      requiredMaterials: {'corrupted_bark': 5},
    ),
    6: BlacksmithEnhanceRequirement(
      targetLevel: 6,
      goldCost: 250000,
      requiredMaterials: {'corrupted_bark': 8},
    ),
    7: BlacksmithEnhanceRequirement(
      targetLevel: 7,
      goldCost: 500000,
      requiredMaterials: {'ancient_fragment': 3},
    ),
    8: BlacksmithEnhanceRequirement(
      targetLevel: 8,
      goldCost: 1000000,
      requiredMaterials: {'ancient_fragment': 5},
    ),
    9: BlacksmithEnhanceRequirement(
      targetLevel: 9,
      goldCost: 2000000,
      requiredMaterials: {'ancient_fragment': 8},
    ),
    10: BlacksmithEnhanceRequirement(
      targetLevel: 10,
      goldCost: 4000000,
      requiredMaterials: {'ancient_fragment': 12},
    ),
  };

  /// Mengambil kebutuhan biaya untuk meningkatkan equipment dari [currentLevel] ke level berikutnya.
  /// Mengembalikan `null` jika [currentLevel] sudah mencapai atau melebihi [maxEnhancementLevel],
  /// atau jika [currentLevel] negatif.
  BlacksmithEnhanceRequirement? getEnhanceRequirement(int currentLevel) {
    if (currentLevel < 0 || currentLevel >= maxEnhancementLevel) return null;
    return _enhanceRequirements[currentLevel + 1];
  }

  /// Menentukan biaya gold untuk me-reforge sub-stat equipment berdasarkan rarity.
  /// Rarity Common dan Uncommon tidak dapat di-reforge (mengembalikan `null`).
  int? getReforgeCost(ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.rare:
        return 50000;
      case ItemRarity.epic:
        return 150000;
      case ItemRarity.legendary:
        return 500000;
      case ItemRarity.mythical:
        return 1500000;
      case ItemRarity.common:
      case ItemRarity.uncommon:
        return null;
    }
  }

  /// Mencari instance equipment di dalam [loadout] (bila dipakai) atau di dalam [inventory].
  ({EquipmentInstance instance, bool isEquipped, EquipmentSlot? slot})?
  findEquipment({
    required String instanceId,
    required Inventory inventory,
    EquipmentLoadout? loadout,
  }) {
    if (loadout != null) {
      for (final entry in loadout.equipped.entries) {
        if (entry.value.id == instanceId) {
          return (instance: entry.value, isEquipped: true, slot: entry.key);
        }
      }
    }
    final inInventory = inventory.equipmentById(instanceId);
    if (inInventory != null) {
      return (instance: inInventory, isEquipped: false, slot: null);
    }
    return null;
  }

  /// Meningkatkan tingkat enhancement equipment sebesar +1.
  /// Mengurangi gold dari [character] dan material dari [inventory] secara atomik.
  /// Jika item sedang dipakai di [loadout], instance di [loadout] langsung diperbarui.
  BlacksmithEnhanceResult enhanceEquipment({
    required PlayerCharacter character,
    required Inventory inventory,
    required String instanceId,
    EquipmentLoadout? loadout,
  }) {
    final found = findEquipment(
      instanceId: instanceId,
      inventory: inventory,
      loadout: loadout,
    );
    if (found == null) {
      return const BlacksmithEnhanceResult(
        status: BlacksmithEnhanceStatus.itemNotFound,
      );
    }

    final target = found.instance;
    if (target.enhancementLevel >= maxEnhancementLevel) {
      return const BlacksmithEnhanceResult(
        status: BlacksmithEnhanceStatus.maxLevelReached,
      );
    }

    final requirement = getEnhanceRequirement(target.enhancementLevel);
    if (requirement == null) {
      return const BlacksmithEnhanceResult(
        status: BlacksmithEnhanceStatus.maxLevelReached,
      );
    }

    if (!character.canAfford(requirement.goldCost)) {
      return const BlacksmithEnhanceResult(
        status: BlacksmithEnhanceStatus.insufficientGold,
      );
    }

    for (final entry in requirement.requiredMaterials.entries) {
      if (inventory.quantityOf(entry.key) < entry.value) {
        return const BlacksmithEnhanceResult(
          status: BlacksmithEnhanceStatus.insufficientMaterials,
        );
      }
    }

    // Eksekusi atomik: kurangi gold dan material
    final spentGoldOk = character.spendGold(requirement.goldCost);
    if (!spentGoldOk) {
      return const BlacksmithEnhanceResult(
        status: BlacksmithEnhanceStatus.insufficientGold,
      );
    }

    for (final entry in requirement.requiredMaterials.entries) {
      inventory.remove(entry.key, entry.value);
    }

    final updated = target.copyWith(
      enhancementLevel: target.enhancementLevel + 1,
    );

    if (found.isEquipped && loadout != null) {
      loadout.equip(updated);
    } else {
      inventory.updateEquipment(updated);
    }

    return BlacksmithEnhanceResult(
      status: BlacksmithEnhanceStatus.success,
      updatedInstance: updated,
      goldSpent: requirement.goldCost,
      materialsSpent: requirement.requiredMaterials,
    );
  }

  /// Me-reforge sub-stat equipment langka (Rare, Epic, Legendary).
  /// Mempertahankan level enhancement yang ada sambil mengacak ulang stat dasar
  /// berdasarkan rentang varians konfigurasi equipment.
  BlacksmithReforgeResult reforgeEquipment({
    required PlayerCharacter character,
    required Inventory inventory,
    required String instanceId,
    Map<String, ItemDefinition>? itemDefinitions,
    EquipmentLoadout? loadout,
    math.Random? random,
    double rollBonus = 0.0,
  }) {
    final found = findEquipment(
      instanceId: instanceId,
      inventory: inventory,
      loadout: loadout,
    );
    if (found == null) {
      return const BlacksmithReforgeResult(
        status: BlacksmithReforgeStatus.itemNotFound,
      );
    }

    final target = found.instance;
    final definition =
        inventory.definitionOf(target.definitionId) ??
        itemDefinitions?[target.definitionId];
    if (definition == null || definition.equipment == null) {
      return const BlacksmithReforgeResult(
        status: BlacksmithReforgeStatus.definitionNotFound,
      );
    }

    final cost = getReforgeCost(target.rarity);
    if (cost == null) {
      return const BlacksmithReforgeResult(
        status: BlacksmithReforgeStatus.ineligibleRarity,
      );
    }

    if (definition.equipment!.fixedStats) {
      return const BlacksmithReforgeResult(
        status: BlacksmithReforgeStatus.fixedStatsNotReforgeable,
      );
    }

    if (!character.canAfford(cost)) {
      return const BlacksmithReforgeResult(
        status: BlacksmithReforgeStatus.insufficientGold,
      );
    }

    final spentGoldOk = character.spendGold(cost);
    if (!spentGoldOk) {
      return const BlacksmithReforgeResult(
        status: BlacksmithReforgeStatus.insufficientGold,
      );
    }

    final rnd = random ?? math.Random();
    final newStats = definition.equipment!.baseStats.roll(
      rnd,
      equipmentConfig.rollVariance,
      rollBonus: rollBonus,
    );

    final updated = target.copyWith(rolledStats: newStats);

    if (found.isEquipped && loadout != null) {
      loadout.equip(updated);
    } else {
      inventory.updateEquipment(updated);
    }

    return BlacksmithReforgeResult(
      status: BlacksmithReforgeStatus.success,
      updatedInstance: updated,
      goldSpent: cost,
      oldStats: target.rolledStats,
      newStats: newStats,
    );
  }

  /// Menghitung jumlah `aether_scrap` yang dihasilkan dari salvage sebuah equipment.
  /// Mengembalikan 0 untuk rarity Mythical (tidak dapat dibongkar).
  int getSalvageScrapYield(EquipmentInstance item) {
    final baseYield = switch (item.rarity) {
      ItemRarity.common => 2,
      ItemRarity.uncommon => 5,
      ItemRarity.rare => 12,
      ItemRarity.epic => 25,
      ItemRarity.legendary => 50,
      ItemRarity.mythical => 0,
    };
    if (baseYield == 0) return 0;
    return baseYield + (math.max(0, item.enhancementLevel) * 2);
  }

  /// Membongkar (salvage) satu equipment di dalam [inventory] menjadi `aether_scrap`.
  /// Equipment yang sedang dipakai di [loadout] atau ber-rarity Mythical ditolak.
  BlacksmithSalvageResult salvageEquipment({
    required Inventory inventory,
    required String instanceId,
    EquipmentLoadout? loadout,
  }) {
    if (loadout != null) {
      for (final equipped in loadout.equipped.values) {
        if (equipped.id == instanceId) {
          return const BlacksmithSalvageResult(
            status: BlacksmithSalvageStatus.cannotSalvageEquipped,
          );
        }
      }
    }

    final target = inventory.equipmentById(instanceId);
    if (target == null) {
      return const BlacksmithSalvageResult(
        status: BlacksmithSalvageStatus.itemNotFound,
      );
    }

    if (target.rarity == ItemRarity.mythical) {
      return const BlacksmithSalvageResult(
        status: BlacksmithSalvageStatus.cannotSalvageMythical,
      );
    }

    final scrapDef = inventory.definitionOf(aetherScrapItemId);
    if (scrapDef == null) {
      return const BlacksmithSalvageResult(
        status: BlacksmithSalvageStatus.definitionNotFound,
      );
    }

    final scrapYield = getSalvageScrapYield(target);
    final currentScrap = inventory.quantityOf(aetherScrapItemId);
    final needsNewSlot = currentScrap == 0;
    if (needsNewSlot &&
        inventory.maxStackSlots != null &&
        inventory.stackSlotCount >= inventory.maxStackSlots!) {
      return const BlacksmithSalvageResult(
        status: BlacksmithSalvageStatus.inventoryFull,
      );
    }
    if (currentScrap + scrapYield > scrapDef.maxStack) {
      return const BlacksmithSalvageResult(
        status: BlacksmithSalvageStatus.inventoryFull,
      );
    }

    final removed = inventory.removeEquipment(instanceId);
    if (!removed) {
      return const BlacksmithSalvageResult(
        status: BlacksmithSalvageStatus.itemNotFound,
      );
    }
    inventory.add(aetherScrapItemId, scrapYield);

    return BlacksmithSalvageResult(
      status: BlacksmithSalvageStatus.success,
      salvagedInstance: target,
      aetherScrapGained: scrapYield,
    );
  }
}
