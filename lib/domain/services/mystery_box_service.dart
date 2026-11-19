import 'dart:math' as math;

import '../entities/equipment.dart';
import '../entities/inventory.dart';
import '../entities/item_definition.dart';
import '../entities/mystery_box.dart';
import '../entities/player_character.dart';
import 'equipment_factory.dart';

/// Status hasil pembukaan Peti Misteri.
enum MysteryBoxOpenStatus {
  success,
  insufficientGold,
  inventoryFull,
  underLevel,
  unknownTier,
  noEligibleItems,
}

/// Hasil dari pembukaan satu atau beberapa Peti Misteri.
class MysteryBoxOpenResult {
  const MysteryBoxOpenResult({
    required this.status,
    this.tier,
    this.count = 0,
    this.itemsObtained = const [],
    this.goldSpent = 0,
    this.remainingGold = 0,
  });

  final MysteryBoxOpenStatus status;
  final MysteryBoxTier? tier;
  final int count;
  final List<EquipmentInstance> itemsObtained;
  final int goldSpent;
  final int remainingGold;

  bool get isSuccess => status == MysteryBoxOpenStatus.success;
}

/// Service domain murni untuk mengelola pembelian dan pembukaan Peti Misteri.
class MysteryBoxService {
  const MysteryBoxService({
    required this.items,
    required this.equipmentFactory,
    this.definitions = MysteryBoxDefinition.defaults,
  });

  final Map<String, ItemDefinition> items;
  final EquipmentFactory equipmentFactory;
  final Map<MysteryBoxTier, MysteryBoxDefinition> definitions;

  /// Membuka [count] buah peti misteri dari tingkat [tier].
  ///
  /// Menjalankan validasi atomik:
  /// 1. Tingkat peti valid dan syarat level karakter terpenuhi.
  /// 2. Saldo gold mencukupi untuk seluruh peti (`totalCost = goldCost * count`).
  /// 3. Kapasitas tas perlengkapan cukup (`freeSlots >= count`).
  /// 4. Pool equipment tersedia untuk rarity yang di-roll.
  MysteryBoxOpenResult openBox({
    required PlayerCharacter character,
    required Inventory inventory,
    required MysteryBoxTier tier,
    int count = 1,
    required math.Random random,
  }) {
    if (count <= 0) {
      return MysteryBoxOpenResult(
        status: MysteryBoxOpenStatus.success,
        tier: tier,
        remainingGold: character.gold,
      );
    }

    final def = definitions[tier];
    if (def == null) {
      return MysteryBoxOpenResult(
        status: MysteryBoxOpenStatus.unknownTier,
        tier: tier,
        remainingGold: character.gold,
      );
    }

    if (character.level < def.minLevel) {
      return MysteryBoxOpenResult(
        status: MysteryBoxOpenStatus.underLevel,
        tier: tier,
        remainingGold: character.gold,
      );
    }

    final totalCost = def.goldCost * count;
    if (!character.canAfford(totalCost)) {
      return MysteryBoxOpenResult(
        status: MysteryBoxOpenStatus.insufficientGold,
        tier: tier,
        remainingGold: character.gold,
      );
    }

    // Periksa kapasitas tas equipment
    if (inventory.maxEquipmentCapacity != null) {
      final freeSlots =
          inventory.maxEquipmentCapacity! - inventory.equipmentCount;
      if (freeSlots < count) {
        return MysteryBoxOpenResult(
          status: MysteryBoxOpenStatus.inventoryFull,
          tier: tier,
          remainingGold: character.gold,
        );
      }
    }

    // Ambil daftar pool equipment yang boleh diundi (equipment reguler yang bisa dijual)
    final eligibleEquipment = items.values
        .where((item) => item.isEquipment && item.sellable)
        .toList();

    if (eligibleEquipment.isEmpty) {
      return MysteryBoxOpenResult(
        status: MysteryBoxOpenStatus.noEligibleItems,
        tier: tier,
        remainingGold: character.gold,
      );
    }

    // Eksekusi potong gold
    final deducted = character.spendGold(totalCost);
    if (!deducted) {
      return MysteryBoxOpenResult(
        status: MysteryBoxOpenStatus.insufficientGold,
        tier: tier,
        remainingGold: character.gold,
      );
    }

    final obtainedList = <EquipmentInstance>[];

    for (var i = 0; i < count; i++) {
      final rolledRarity = def.rollRarity(random);

      // Cari item di pool yang cocok dengan rarity rolled
      var poolForRarity = eligibleEquipment
          .where((item) => item.rarity == rolledRarity)
          .toList();

      // Fallback jika tidak ada item dengan rarity tersebut di pool
      if (poolForRarity.isEmpty) {
        poolForRarity = eligibleEquipment;
      }

      final chosenDef = poolForRarity[random.nextInt(poolForRarity.length)];
      final instance = equipmentFactory.create(
        instanceId: inventory.nextEquipmentId(),
        definition: chosenDef,
        random: random,
      );

      inventory.addEquipment(instance);
      obtainedList.add(instance);
    }

    return MysteryBoxOpenResult(
      status: MysteryBoxOpenStatus.success,
      tier: tier,
      count: count,
      itemsObtained: List.unmodifiable(obtainedList),
      goldSpent: totalCost,
      remainingGold: character.gold,
    );
  }
}
