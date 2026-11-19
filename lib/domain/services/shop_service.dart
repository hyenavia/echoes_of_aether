import 'dart:math' as math;

import '../entities/equipment.dart';
import '../entities/inventory.dart';
import '../entities/item_definition.dart';
import '../entities/player_character.dart';
import '../entities/shop_config.dart';
import 'equipment_factory.dart';
import 'requirement_evaluator.dart';

export 'requirement_evaluator.dart'
    show RequirementCheck, RequirementEvaluator, ShopPlayerContext;

sealed class ShopBuyResult {
  const ShopBuyResult();
}

final class ShopBuySuccess extends ShopBuyResult {
  const ShopBuySuccess({
    required this.goldSpent,
    required this.remainingGold,
    required this.newPurchaseCount,
    required this.itemId,
    this.purchasedEquipment,
    this.quantity = 1,
    this.wasDuplicate = false,
  });

  final int goldSpent;
  final int remainingGold;
  final int newPurchaseCount;
  final String itemId;
  final EquipmentInstance? purchasedEquipment;
  final int quantity;
  final bool wasDuplicate;
}

final class ShopBuyInsufficientGold extends ShopBuyResult {
  const ShopBuyInsufficientGold({
    required this.requiredGold,
    required this.currentGold,
  });

  final int requiredGold;
  final int currentGold;
}

final class ShopBuyRequirementNotMet extends ShopBuyResult {
  const ShopBuyRequirementNotMet({required this.failedRequirements});

  final List<PurchaseRequirement> failedRequirements;
}

final class ShopBuyInventoryFull extends ShopBuyResult {
  const ShopBuyInventoryFull();
}

final class ShopBuyLimitReached extends ShopBuyResult {
  const ShopBuyLimitReached({
    required this.limit,
    required this.purchasedCount,
  });

  final int limit;
  final int purchasedCount;
}

final class ShopBuyNotFound extends ShopBuyResult {
  const ShopBuyNotFound({required this.entryId});

  final String entryId;
}

sealed class ShopSellResult {
  const ShopSellResult();
}

final class ShopSellSuccess extends ShopSellResult {
  const ShopSellSuccess({
    required this.goldEarned,
    required this.remainingGold,
    required this.quantitySold,
    required this.itemId,
    this.equipmentInstanceId,
    this.wasDuplicate = false,
  });

  final int goldEarned;
  final int remainingGold;
  final int quantitySold;
  final String itemId;
  final String? equipmentInstanceId;
  final bool wasDuplicate;
}

final class ShopSellNotFound extends ShopSellResult {
  const ShopSellNotFound({required this.targetId});

  final String targetId;
}

final class ShopSellNotSellable extends ShopSellResult {
  const ShopSellNotSellable({required this.targetId, required this.reason});

  final String targetId;
  final String reason;
}

/// Layanan domain murni untuk mengevaluasi requirement shop, pembelian, dan
/// penjualan item/equipment secara atomik (validasi seluruh kondisi sebelum
/// mengubah state apa pun).
class ShopService {
  ShopService({
    required this.catalog,
    required this.items,
    required this.equipmentFactory,
  });

  final ShopCatalog catalog;
  final Map<String, ItemDefinition> items;
  final EquipmentFactory equipmentFactory;

  final Set<String> _internalProcessedActions = {};

  /// Mengevaluasi seluruh [PurchaseRequirement] pada [entry] untuk [context].
  RequirementCheck check(ShopEntry entry, ShopPlayerContext context) =>
      RequirementEvaluator.evaluate(entry.requirements, context);

  /// Menghitung harga jual satuan yang aman terhadap exploit beli-jual:
  /// mengembalikan `0` untuk item `sellable: false`, dan tidak pernah melebihi
  /// `floor(price * maxSellRatio)` bila item dijual di shop.
  int effectiveSellUnitPrice(ItemDefinition definition) {
    if (!definition.sellable) return 0;
    var safePrice = math.max(0, definition.sellValue);
    for (final entry in catalog.entries) {
      if (entry.itemId == definition.id) {
        final capped = (entry.price * catalog.sell.maxSellRatio).floor();
        if (capped < safePrice) {
          safePrice = math.max(0, capped);
        }
      }
    }
    return safePrice;
  }

  /// Membeli satu entri shop. Seluruh syarat divalidasi sebelum mengubah
  /// gold, inventory, maupun hitungan pembelian.
  ShopBuyResult buy({
    required String entryId,
    required PlayerCharacter character,
    required Inventory inventory,
    required ShopPlayerContext context,
    required math.Random random,
    Map<String, int>? purchaseCounts,
    String? actionId,
    Set<String>? processedActionIds,
  }) {
    final normalizedActionId = _normalizeActionId(actionId);
    final tracker = processedActionIds ?? _internalProcessedActions;
    final entry = catalog.byId(entryId);
    final currentPurchases =
        purchaseCounts?[entryId] ?? context.purchasedCountFor(entryId);

    if (normalizedActionId != null && tracker.contains(normalizedActionId)) {
      return ShopBuySuccess(
        goldSpent: 0,
        remainingGold: character.gold,
        newPurchaseCount: currentPurchases,
        itemId: entry?.itemId ?? entryId,
        quantity: 0,
        wasDuplicate: true,
      );
    }

    if (entry == null) {
      return ShopBuyNotFound(entryId: entryId);
    }

    final itemDef = items[entry.itemId];
    if (itemDef == null || itemDef.category == ItemCategory.consumable) {
      return ShopBuyNotFound(entryId: entryId);
    }

    if (entry.purchaseLimit != null &&
        currentPurchases >= entry.purchaseLimit!) {
      return ShopBuyLimitReached(
        limit: entry.purchaseLimit!,
        purchasedCount: currentPurchases,
      );
    }

    final reqCheck = check(entry, context);
    if (!reqCheck.isMet) {
      return ShopBuyRequirementNotMet(
        failedRequirements: reqCheck.failedRequirements,
      );
    }

    if (!character.canAfford(entry.price)) {
      return ShopBuyInsufficientGold(
        requiredGold: entry.price,
        currentGold: character.gold,
      );
    }

    if (!_hasSpaceForPurchase(inventory, itemDef, quantity: 1)) {
      return const ShopBuyInventoryFull();
    }

    // Semua validasi lolos; lakukan mutasi sebagai satu unit logis.
    EquipmentInstance? createdEquipment;
    if (itemDef.isEquipment) {
      final instanceId = inventory.nextEquipmentId();
      final candidate = equipmentFactory.create(
        instanceId: instanceId,
        definition: itemDef,
        random: random,
      );
      if (!character.spendGold(entry.price)) {
        return ShopBuyInsufficientGold(
          requiredGold: entry.price,
          currentGold: character.gold,
        );
      }
      final added = inventory.addEquipment(candidate);
      if (!added) {
        // Seharusnya tidak terjadi karena sudah divalidasi, namun pulihkan gold.
        character.addGold(entry.price);
        return const ShopBuyInventoryFull();
      }
      createdEquipment = candidate;
    } else {
      if (!character.spendGold(entry.price)) {
        return ShopBuyInsufficientGold(
          requiredGold: entry.price,
          currentGold: character.gold,
        );
      }
      final addResult = inventory.add(itemDef.id, 1);
      if (addResult.added != 1 || addResult.overflow > 0) {
        if (addResult.added > 0) {
          inventory.remove(itemDef.id, addResult.added);
        }
        character.addGold(entry.price);
        return const ShopBuyInventoryFull();
      }
    }

    final nextPurchaseCount = currentPurchases + 1;
    if (purchaseCounts != null) {
      purchaseCounts[entry.id] = nextPurchaseCount;
    }
    if (normalizedActionId != null) {
      tracker.add(normalizedActionId);
    }

    return ShopBuySuccess(
      goldSpent: entry.price,
      remainingGold: character.gold,
      newPurchaseCount: nextPurchaseCount,
      itemId: itemDef.id,
      purchasedEquipment: createdEquipment,
      quantity: 1,
    );
  }

  /// Menjual satu instance equipment dari tas pemain. Equipment yang sedang
  /// dipakai di [PlayerCharacter.loadout] ditolak.
  ShopSellResult sellEquipment({
    required String instanceId,
    required PlayerCharacter character,
    required Inventory inventory,
    String? actionId,
    Set<String>? processedActionIds,
  }) {
    final normalizedActionId = _normalizeActionId(actionId);
    final tracker = processedActionIds ?? _internalProcessedActions;
    if (normalizedActionId != null && tracker.contains(normalizedActionId)) {
      return ShopSellSuccess(
        goldEarned: 0,
        remainingGold: character.gold,
        quantitySold: 0,
        itemId: '',
        equipmentInstanceId: instanceId,
        wasDuplicate: true,
      );
    }

    final isEquipped = character.loadout.equipped.values.any(
      (equipped) => equipped.id == instanceId,
    );
    if (isEquipped && !catalog.sell.equippedSellable) {
      return ShopSellNotSellable(
        targetId: instanceId,
        reason: 'Equipment yang sedang dipakai tidak dapat dijual.',
      );
    }

    final instance = inventory.equipmentById(instanceId);
    if (instance == null) {
      return ShopSellNotFound(targetId: instanceId);
    }
    if (instance.isFavorite) {
      return ShopSellNotSellable(
        targetId: instanceId,
        reason: 'Equipment favorit tidak dapat dijual.',
      );
    }

    final itemDef = items[instance.definitionId];
    if (itemDef == null) {
      return ShopSellNotFound(targetId: instance.definitionId);
    }
    if (!itemDef.sellable) {
      return ShopSellNotSellable(
        targetId: instanceId,
        reason: 'Item tidak dapat dijual.',
      );
    }

    final sellPrice = effectiveSellUnitPrice(itemDef);
    if (sellPrice <= 0) {
      return ShopSellNotSellable(
        targetId: instanceId,
        reason: 'Item tidak memiliki nilai jual.',
      );
    }

    final removed = inventory.removeEquipment(instanceId);
    if (!removed) {
      return ShopSellNotFound(targetId: instanceId);
    }

    final earned = character.addGold(sellPrice);
    if (normalizedActionId != null) {
      tracker.add(normalizedActionId);
    }

    return ShopSellSuccess(
      goldEarned: earned,
      remainingGold: character.gold,
      quantitySold: 1,
      itemId: itemDef.id,
      equipmentInstanceId: instanceId,
    );
  }

  /// Menjual material/stack item secara massal ([quantity] unit sekaligus).
  ShopSellResult sellMaterialBulk({
    required String itemId,
    required int quantity,
    required PlayerCharacter character,
    required Inventory inventory,
    String? actionId,
    Set<String>? processedActionIds,
  }) {
    final normalizedActionId = _normalizeActionId(actionId);
    final tracker = processedActionIds ?? _internalProcessedActions;
    if (normalizedActionId != null && tracker.contains(normalizedActionId)) {
      return ShopSellSuccess(
        goldEarned: 0,
        remainingGold: character.gold,
        quantitySold: 0,
        itemId: itemId,
        wasDuplicate: true,
      );
    }

    if (quantity <= 0) {
      return ShopSellNotSellable(
        targetId: itemId,
        reason: 'Jumlah penjualan harus lebih dari 0.',
      );
    }

    final itemDef = items[itemId];
    if (itemDef == null) {
      return ShopSellNotFound(targetId: itemId);
    }
    if (!itemDef.sellable) {
      return ShopSellNotSellable(
        targetId: itemId,
        reason: 'Item tidak dapat dijual.',
      );
    }

    if (itemDef.isEquipment ||
        itemDef.category == ItemCategory.questItem ||
        !catalog.sell.sellableCategories.contains(itemDef.category)) {
      return ShopSellNotSellable(
        targetId: itemId,
        reason:
            'Item bertipe ${itemDef.category.name} tidak dapat dijual massal.',
      );
    }

    final owned = inventory.quantityOf(itemId);
    if (owned <= 0) {
      return ShopSellNotFound(targetId: itemId);
    }
    if (owned < quantity) {
      return ShopSellNotSellable(
        targetId: itemId,
        reason: 'Jumlah item di tas tidak mencukupi ($owned < $quantity).',
      );
    }

    final unitPrice = effectiveSellUnitPrice(itemDef);
    if (unitPrice <= 0) {
      return ShopSellNotSellable(
        targetId: itemId,
        reason: 'Item tidak memiliki nilai jual.',
      );
    }

    final totalGold = unitPrice * quantity;
    final removed = inventory.remove(itemId, quantity);
    if (!removed) {
      return ShopSellNotSellable(
        targetId: itemId,
        reason: 'Gagal mengurangi item dari tas.',
      );
    }

    final earned = character.addGold(totalGold);
    if (normalizedActionId != null) {
      tracker.add(normalizedActionId);
    }

    return ShopSellSuccess(
      goldEarned: earned,
      remainingGold: character.gold,
      quantitySold: quantity,
      itemId: itemId,
    );
  }

  /// Pintu masuk umum untuk menjual equipment (bila [equipmentInstanceId]
  /// diberikan) atau stack material ([itemId], [quantity]).
  ShopSellResult sell({
    required String itemId,
    int quantity = 1,
    String? equipmentInstanceId,
    required PlayerCharacter character,
    required Inventory inventory,
    String? actionId,
    Set<String>? processedActionIds,
  }) {
    if (equipmentInstanceId != null) {
      return sellEquipment(
        instanceId: equipmentInstanceId,
        character: character,
        inventory: inventory,
        actionId: actionId,
        processedActionIds: processedActionIds,
      );
    }
    return sellMaterialBulk(
      itemId: itemId,
      quantity: quantity,
      character: character,
      inventory: inventory,
      actionId: actionId,
      processedActionIds: processedActionIds,
    );
  }

  /// Menjual banyak equipment dan/atau material sekaligus dalam satu operasi
  /// atomik (validasi seluruh item terlebih dahulu sebelum memutasi state).
  ShopSellResult sellBatch({
    List<String> equipmentInstanceIds = const [],
    Map<String, int> materialQuantities = const {},
    required PlayerCharacter character,
    required Inventory inventory,
    String? actionId,
    Set<String>? processedActionIds,
  }) {
    final normalizedActionId = _normalizeActionId(actionId);
    final tracker = processedActionIds ?? _internalProcessedActions;
    if (normalizedActionId != null && tracker.contains(normalizedActionId)) {
      return ShopSellSuccess(
        goldEarned: 0,
        remainingGold: character.gold,
        quantitySold: 0,
        itemId: 'batch',
        wasDuplicate: true,
      );
    }

    final uniqueEquipmentIds = equipmentInstanceIds.toSet().toList();
    final filteredMaterials = <String, int>{
      for (final entry in materialQuantities.entries)
        if (entry.value > 0) entry.key: entry.value,
    };

    if (uniqueEquipmentIds.isEmpty && filteredMaterials.isEmpty) {
      return const ShopSellNotSellable(
        targetId: 'batch',
        reason: 'Pilih minimal satu item untuk dijual.',
      );
    }

    var totalGold = 0;
    var totalUnits = 0;

    for (final instanceId in uniqueEquipmentIds) {
      final isEquipped = character.loadout.equipped.values.any(
        (equipped) => equipped.id == instanceId,
      );
      if (isEquipped && !catalog.sell.equippedSellable) {
        return ShopSellNotSellable(
          targetId: instanceId,
          reason: 'Equipment yang sedang dipakai tidak dapat dijual.',
        );
      }
      final instance = inventory.equipmentById(instanceId);
      if (instance == null) {
        return ShopSellNotFound(targetId: instanceId);
      }
      if (instance.isFavorite) {
        return ShopSellNotSellable(
          targetId: instanceId,
          reason: 'Equipment favorit tidak dapat dijual.',
        );
      }
      final itemDef = items[instance.definitionId];
      if (itemDef == null) {
        return ShopSellNotFound(targetId: instance.definitionId);
      }
      if (!itemDef.sellable) {
        return ShopSellNotSellable(
          targetId: instanceId,
          reason: 'Item tidak dapat dijual.',
        );
      }
      final sellPrice = effectiveSellUnitPrice(itemDef);
      if (sellPrice <= 0) {
        return ShopSellNotSellable(
          targetId: instanceId,
          reason: 'Item tidak memiliki nilai jual.',
        );
      }
      totalGold += sellPrice;
      totalUnits += 1;
    }

    for (final entry in filteredMaterials.entries) {
      final itemId = entry.key;
      final quantity = entry.value;
      final itemDef = items[itemId];
      if (itemDef == null) {
        return ShopSellNotFound(targetId: itemId);
      }
      if (!itemDef.sellable) {
        return ShopSellNotSellable(
          targetId: itemId,
          reason: 'Item tidak dapat dijual.',
        );
      }
      if (itemDef.isEquipment ||
          itemDef.category == ItemCategory.questItem ||
          !catalog.sell.sellableCategories.contains(itemDef.category)) {
        return ShopSellNotSellable(
          targetId: itemId,
          reason:
              'Item bertipe ${itemDef.category.name} tidak dapat dijual massal.',
        );
      }
      final owned = inventory.quantityOf(itemId);
      if (owned <= 0) {
        return ShopSellNotFound(targetId: itemId);
      }
      if (owned < quantity) {
        return ShopSellNotSellable(
          targetId: itemId,
          reason: 'Jumlah item di tas tidak mencukupi ($owned < $quantity).',
        );
      }
      final unitPrice = effectiveSellUnitPrice(itemDef);
      if (unitPrice <= 0) {
        return ShopSellNotSellable(
          targetId: itemId,
          reason: 'Item tidak memiliki nilai jual.',
        );
      }
      totalGold += unitPrice * quantity;
      totalUnits += quantity;
    }

    for (final instanceId in uniqueEquipmentIds) {
      inventory.removeEquipment(instanceId);
    }
    for (final entry in filteredMaterials.entries) {
      inventory.remove(entry.key, entry.value);
    }

    final earned = character.addGold(totalGold);
    if (normalizedActionId != null) {
      tracker.add(normalizedActionId);
    }

    return ShopSellSuccess(
      goldEarned: earned,
      remainingGold: character.gold,
      quantitySold: totalUnits,
      itemId: 'batch',
    );
  }

  bool _hasSpaceForPurchase(
    Inventory inventory,
    ItemDefinition definition, {
    required int quantity,
  }) {
    if (definition.isEquipment) {
      return inventory.hasEquipmentSpace;
    }
    final currentQty = inventory.quantityOf(definition.id);
    if (currentQty == 0 &&
        inventory.maxStackSlots != null &&
        inventory.stackSlotCount >= inventory.maxStackSlots!) {
      return false;
    }
    return currentQty + quantity <= definition.maxStack;
  }

  String? _normalizeActionId(String? actionId) {
    final trimmed = actionId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
