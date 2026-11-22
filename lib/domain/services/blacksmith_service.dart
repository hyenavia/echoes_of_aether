import 'dart:math' as math;

import '../entities/equipment.dart';
import '../entities/equipment_config.dart';
import '../entities/equipment_loadout.dart';
import '../entities/inventory.dart';
import '../entities/item_definition.dart';
import '../entities/mythical_forge_config.dart';
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

/// Hasil eksekusi pembongkaran massal (bulk salvage) oleh [BlacksmithService].
class BlacksmithBulkSalvageResult {
  const BlacksmithBulkSalvageResult({
    required this.salvagedCount,
    required this.skippedCount,
    required this.aetherScrapGained,
    this.stoppedByInventoryFull = false,
    this.salvagedIds = const [],
  });

  final int salvagedCount;
  final int skippedCount;
  final int aetherScrapGained;
  final bool stoppedByInventoryFull;
  final List<String> salvagedIds;

  bool get hasSalvaged => salvagedCount > 0;
}

/// Status hasil penempaan equipment Mythical non-weapon (Tempa Mythical).
enum BlacksmithCraftMythicalStatus {
  success,
  recipeNotFound,
  targetDefinitionNotFound,
  missingCatalystWeapon,
  sacrificeNotFound,
  cannotSacrificeEquipped,
  cannotSacrificeFavorite,
  sacrificeSlotMismatch,
  sacrificeRarityTooLow,
  cannotSacrificeMythical,
  insufficientGold,
  insufficientMaterials,
}

/// Hasil eksekusi penempaan equipment Mythical oleh [BlacksmithService].
class BlacksmithCraftMythicalResult {
  const BlacksmithCraftMythicalResult({
    required this.status,
    this.craftedInstance,
    this.consumedSacrificeInstance,
    this.goldSpent = 0,
    this.materialsSpent = const {},
  });

  final BlacksmithCraftMythicalStatus status;
  final EquipmentInstance? craftedInstance;
  final EquipmentInstance? consumedSacrificeInstance;
  final int goldSpent;
  final Map<String, int> materialsSpent;

  bool get isSuccess => status == BlacksmithCraftMythicalStatus.success;
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

  /// Menentukan apakah sebuah equipment memenuhi syarat untuk dibongkar massal.
  bool isBulkSalvageCandidate(
    EquipmentInstance item, {
    required Set<ItemRarity> targetRarities,
    Set<String> equippedIds = const {},
    bool skipFavorited = true,
    bool skipEnhanced = true,
  }) {
    if (!targetRarities.contains(item.rarity)) return false;
    if (item.rarity == ItemRarity.mythical) return false;
    if (equippedIds.contains(item.id)) return false;
    if (skipFavorited && item.isFavorite) return false;
    if (skipEnhanced && item.enhancementLevel > 0) return false;
    return getSalvageScrapYield(item) > 0;
  }

  /// Mengembalikan daftar equipment di [inventory] yang memenuhi syarat
  /// untuk pembongkaran massal berdasarkan [targetRarities] dan opsi proteksi.
  List<EquipmentInstance> findBulkSalvageCandidates({
    required Inventory inventory,
    required Set<ItemRarity> targetRarities,
    EquipmentLoadout? loadout,
    bool skipFavorited = true,
    bool skipEnhanced = true,
  }) {
    final equippedIds = loadout == null
        ? const <String>{}
        : {for (final eq in loadout.equipped.values) eq.id};
    return [
      for (final item in inventory.equipmentSnapshot())
        if (isBulkSalvageCandidate(
          item,
          targetRarities: targetRarities,
          equippedIds: equippedIds,
          skipFavorited: skipFavorited,
          skipEnhanced: skipEnhanced,
        ))
          item,
    ];
  }

  /// Membongkar banyak equipment yang memenuhi syarat menjadi `aether_scrap`.
  /// Secara default melindungi item terpasang, Mythical, favorit, dan `+1` ke atas.
  /// Berhenti aman jika slot tas atau batas tumpukan `aether_scrap` penuh.
  BlacksmithBulkSalvageResult salvageEquipmentBulk({
    required Inventory inventory,
    required Set<ItemRarity> targetRarities,
    EquipmentLoadout? loadout,
    bool skipFavorited = true,
    bool skipEnhanced = true,
  }) {
    if (inventory.definitionOf(aetherScrapItemId) == null) {
      return const BlacksmithBulkSalvageResult(
        salvagedCount: 0,
        skippedCount: 0,
        aetherScrapGained: 0,
      );
    }

    final candidates = findBulkSalvageCandidates(
      inventory: inventory,
      targetRarities: targetRarities,
      loadout: loadout,
      skipFavorited: skipFavorited,
      skipEnhanced: skipEnhanced,
    );
    final allMatchingCount = inventory
        .equipmentSnapshot()
        .where((e) => targetRarities.contains(e.rarity))
        .length;
    var skippedCount = allMatchingCount - candidates.length;
    var salvagedCount = 0;
    var totalScrap = 0;
    var stoppedByInventoryFull = false;
    final salvagedIds = <String>[];

    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final res = salvageEquipment(
        inventory: inventory,
        instanceId: candidate.id,
        loadout: loadout,
      );
      if (res.isSuccess) {
        salvagedCount++;
        totalScrap += res.aetherScrapGained;
        salvagedIds.add(candidate.id);
      } else if (res.status == BlacksmithSalvageStatus.inventoryFull) {
        stoppedByInventoryFull = true;
        skippedCount += candidates.length - i;
        break;
      } else {
        skippedCount++;
      }
    }

    return BlacksmithBulkSalvageResult(
      salvagedCount: salvagedCount,
      skippedCount: skippedCount,
      aetherScrapGained: totalScrap,
      stoppedByInventoryFull: stoppedByInventoryFull,
      salvagedIds: List.unmodifiable(salvagedIds),
    );
  }

  /// Memeriksa apakah pemain memiliki senjata katalis [weaponDefinitionId]
  /// di dalam tas ([inventory]) atau sedang terpasang di [loadout].
  bool hasCatalystWeapon({
    required String weaponDefinitionId,
    required Inventory inventory,
    EquipmentLoadout? loadout,
  }) {
    final equippedWeapon = loadout?.instanceIn(EquipmentSlot.weapon);
    if (equippedWeapon != null &&
        equippedWeapon.definitionId == weaponDefinitionId) {
      return true;
    }
    return inventory.equipmentSnapshot().any(
      (item) => item.definitionId == weaponDefinitionId,
    );
  }

  /// Mengembalikan daftar equipment di [inventory] yang sah dijadikan tumbal
  /// untuk resep [recipe] dengan [targetSlot] (non-equipped, bukan favorit,
  /// non-Mythical, slot sama, dan rarity >= `recipe.sacrificeMinRarity`).
  List<EquipmentInstance> findEligibleSacrificeCandidates({
    required MythicalForgeRecipe recipe,
    required EquipmentSlot targetSlot,
    required Inventory inventory,
    EquipmentLoadout? loadout,
  }) {
    final equippedIds = loadout == null
        ? const <String>{}
        : {for (final eq in loadout.equipped.values) eq.id};
    return [
      for (final item in inventory.equipmentSnapshot())
        if (!equippedIds.contains(item.id) &&
            !item.isFavorite &&
            item.rarity != ItemRarity.mythical &&
            item.slot == targetSlot &&
            item.rarity.index >= recipe.sacrificeMinRarity.index)
          item,
    ];
  }

  /// Menempa equipment Mythical non-weapon berdasarkan [recipeId] dan
  /// mengorbankan [sacrificeInstanceId].
  ///
  /// Senjata katalis hanya menjadi prasyarat kepemilikan dan TIDAK dikonsumsi.
  /// Seluruh validasi dijalankan sebelum mutasi sehingga kegagalan bersifat
  /// atomik (tidak ada gold, material, atau tumbal yang berkurang).
  BlacksmithCraftMythicalResult craftMythicalEquipment({
    required PlayerCharacter character,
    required Inventory inventory,
    required MythicalForgeConfig forgeConfig,
    required String recipeId,
    required String sacrificeInstanceId,
    EquipmentLoadout? loadout,
  }) {
    final recipe = forgeConfig.recipes[recipeId];
    if (recipe == null) {
      return const BlacksmithCraftMythicalResult(
        status: BlacksmithCraftMythicalStatus.recipeNotFound,
      );
    }

    final targetDef = inventory.definitionOf(recipe.targetItemId);
    final targetEq = targetDef?.equipment;
    if (targetDef == null || !targetDef.isEquipment || targetEq == null) {
      return const BlacksmithCraftMythicalResult(
        status: BlacksmithCraftMythicalStatus.targetDefinitionNotFound,
      );
    }

    if (!hasCatalystWeapon(
      weaponDefinitionId: recipe.requiredCatalystWeaponId,
      inventory: inventory,
      loadout: loadout,
    )) {
      return const BlacksmithCraftMythicalResult(
        status: BlacksmithCraftMythicalStatus.missingCatalystWeapon,
      );
    }

    final foundSacrifice = findEquipment(
      instanceId: sacrificeInstanceId,
      inventory: inventory,
      loadout: loadout,
    );
    if (foundSacrifice == null) {
      return const BlacksmithCraftMythicalResult(
        status: BlacksmithCraftMythicalStatus.sacrificeNotFound,
      );
    }
    if (foundSacrifice.isEquipped) {
      return const BlacksmithCraftMythicalResult(
        status: BlacksmithCraftMythicalStatus.cannotSacrificeEquipped,
      );
    }

    final sacrifice = foundSacrifice.instance;
    if (sacrifice.isFavorite) {
      return const BlacksmithCraftMythicalResult(
        status: BlacksmithCraftMythicalStatus.cannotSacrificeFavorite,
      );
    }
    if (sacrifice.rarity == ItemRarity.mythical) {
      return const BlacksmithCraftMythicalResult(
        status: BlacksmithCraftMythicalStatus.cannotSacrificeMythical,
      );
    }
    if (sacrifice.slot != targetEq.slot) {
      return const BlacksmithCraftMythicalResult(
        status: BlacksmithCraftMythicalStatus.sacrificeSlotMismatch,
      );
    }
    if (sacrifice.rarity.index < recipe.sacrificeMinRarity.index) {
      return const BlacksmithCraftMythicalResult(
        status: BlacksmithCraftMythicalStatus.sacrificeRarityTooLow,
      );
    }

    if (!character.canAfford(recipe.goldCost)) {
      return const BlacksmithCraftMythicalResult(
        status: BlacksmithCraftMythicalStatus.insufficientGold,
      );
    }

    for (final entry in recipe.materials.entries) {
      if (inventory.quantityOf(entry.key) < entry.value) {
        return const BlacksmithCraftMythicalResult(
          status: BlacksmithCraftMythicalStatus.insufficientMaterials,
        );
      }
    }

    // Mutasi atomik setelah seluruh prasyarat tervalidasi.
    if (recipe.goldCost > 0) {
      character.spendGold(recipe.goldCost);
    }
    for (final entry in recipe.materials.entries) {
      inventory.remove(entry.key, entry.value);
    }
    inventory.removeEquipment(sacrifice.id);

    final crafted = EquipmentInstance(
      id: inventory.nextEquipmentId(),
      definitionId: targetDef.id,
      slot: targetEq.slot,
      rarity: targetDef.rarity,
      rolledStats: targetEq.baseStats,
      enhancementLevel: 0,
    );
    inventory.addEquipment(crafted);

    return BlacksmithCraftMythicalResult(
      status: BlacksmithCraftMythicalStatus.success,
      craftedInstance: crafted,
      consumedSacrificeInstance: sacrifice,
      goldSpent: recipe.goldCost,
      materialsSpent: Map<String, int>.unmodifiable(recipe.materials),
    );
  }
}
