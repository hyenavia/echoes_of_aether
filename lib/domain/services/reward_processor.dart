import 'dart:math' as math;

import '../entities/dungeon_reward.dart';
import '../entities/enemy_definition.dart';
import '../entities/equipment.dart';
import '../entities/inventory.dart';
import '../entities/item_definition.dart';
import '../entities/loot_table.dart';
import '../entities/player_character.dart';
import 'difficulty_service.dart';
import 'equipment_factory.dart';
import 'loot_service.dart';

/// Hasil pemrosesan satu event reward (EXP, gold, level up, dan loot).
class GrantedReward {
  const GrantedReward({
    required this.eventId,
    required this.alreadyClaimed,
    this.expGranted = 0,
    this.goldGranted = 0,
    this.levelsGained = 0,
    this.addedStacks = const {},
    this.overflowStacks = const {},
    this.addedEquipment = const [],
    this.droppedEquipment = const [],
    this.displayParts = const [],
  });

  final String eventId;
  final bool alreadyClaimed;
  final int expGranted;
  final int goldGranted;
  final int levelsGained;
  final Map<String, int> addedStacks;
  final Map<String, int> overflowStacks;
  final List<EquipmentInstance> addedEquipment;

  /// Equipment yang tidak muat karena kapasitas tas penuh.
  final List<EquipmentInstance> droppedEquipment;

  /// Label ringkas item yang berhasil masuk inventory (untuk HUD/log).
  final List<String> displayParts;

  bool get hasLootChanges =>
      addedStacks.isNotEmpty || addedEquipment.isNotEmpty;
}

/// Coordinator domain untuk penyelesaian reward RPG:
/// EXP, gold, loot roll, masuknya item ke inventory, dan pencegahan klaim ganda.
/// Memisahkan logika progression/inventory dari `CombatSystem` (Flame).
class RewardProcessor {
  RewardProcessor({
    required this.character,
    required this.inventory,
    required this.items,
    required this.lootTables,
    this.lootService = const LootService(),
    required this.equipmentFactory,
    Set<String>? claimedEventIds,
  }) : _claimedEventIds = claimedEventIds != null ? {...claimedEventIds} : {};

  final PlayerCharacter character;
  final Inventory inventory;
  final Map<String, ItemDefinition> items;
  final Map<String, LootTable> lootTables;
  final LootService lootService;
  final EquipmentFactory equipmentFactory;
  final Set<String> _claimedEventIds;

  Set<String> get claimedEventIds => Set.unmodifiable(_claimedEventIds);

  bool isClaimed(String eventId) => _claimedEventIds.contains(eventId);

  bool markClaimed(String eventId) => _claimedEventIds.add(eventId);

  GrantedReward processEnemyDefeated({
    required String eventId,
    required EnemyDefinition definition,
    required math.Random random,
    DifficultyProfile difficultyProfile = DifficultyProfile.identity,
    DifficultyService difficultyService = const DifficultyService(),
  }) {
    return _process(
      eventId: eventId,
      expReward: difficultyService.scaleExp(
        definition.expReward,
        difficultyProfile,
      ),
      goldReward: difficultyService.scaleGold(
        definition.goldReward,
        difficultyProfile,
      ),
      lootTableId: definition.lootTableId,
      random: random,
      difficultyProfile: difficultyProfile,
    );
  }

  GrantedReward processDungeonCompletion({
    required String eventId,
    required DungeonCompletionReward reward,
    required math.Random random,
    DifficultyProfile difficultyProfile = DifficultyProfile.identity,
    DifficultyService difficultyService = const DifficultyService(),
  }) {
    return _process(
      eventId: eventId,
      expReward: difficultyService.scaleExp(
        reward.expReward,
        difficultyProfile,
      ),
      goldReward: difficultyService.scaleGold(
        reward.goldReward,
        difficultyProfile,
      ),
      lootTableId: reward.lootTableId,
      random: random,
      difficultyProfile: difficultyProfile,
    );
  }

  GrantedReward _process({
    required String eventId,
    required int expReward,
    required int goldReward,
    required String? lootTableId,
    required math.Random random,
    DifficultyProfile difficultyProfile = DifficultyProfile.identity,
  }) {
    if (!_claimedEventIds.add(eventId)) {
      return GrantedReward(eventId: eventId, alreadyClaimed: true);
    }

    final safeExp = math.max<int>(0, expReward);
    final safeGold = math.max<int>(0, goldReward);
    final levelsGained = character.receiveReward(exp: safeExp, gold: safeGold);

    final addedStacks = <String, int>{};
    final overflowStacks = <String, int>{};
    final addedEquipment = <EquipmentInstance>[];
    final droppedEquipment = <EquipmentInstance>[];
    final displayParts = <String>[];

    final table = lootTableId == null ? null : lootTables[lootTableId];
    if (table != null) {
      final drops = lootService.roll(
        table,
        random,
        items: items,
        rareDropChanceMultiplier: difficultyProfile.rareDropChanceMultiplier,
      );
      for (final drop in drops) {
        final item = items[drop.itemId];
        if (item == null) {
          throw StateError(
            'Loot table "${table.id}" merujuk item "${drop.itemId}" '
            'yang tidak ada di konfigurasi item.',
          );
        }
        if (item.isEquipment) {
          for (var i = 0; i < drop.quantity; i++) {
            final instance = equipmentFactory.create(
              instanceId: inventory.nextEquipmentId(),
              definition: item,
              random: random,
              rollBonus: difficultyProfile.equipmentRollBonus,
            );
            if (inventory.addEquipment(instance)) {
              addedEquipment.add(instance);
              displayParts.add(item.name);
            } else {
              droppedEquipment.add(instance);
            }
          }
        } else {
          final result = inventory.add(drop.itemId, drop.quantity);
          if (result.added > 0) {
            addedStacks[drop.itemId] =
                (addedStacks[drop.itemId] ?? 0) + result.added;
            displayParts.add('${item.name} x${result.added}');
          }
          if (result.overflow > 0) {
            overflowStacks[drop.itemId] =
                (overflowStacks[drop.itemId] ?? 0) + result.overflow;
          }
        }
      }
    }

    return GrantedReward(
      eventId: eventId,
      alreadyClaimed: false,
      expGranted: safeExp,
      goldGranted: safeGold,
      levelsGained: levelsGained,
      addedStacks: Map.unmodifiable(addedStacks),
      overflowStacks: Map.unmodifiable(overflowStacks),
      addedEquipment: List.unmodifiable(addedEquipment),
      droppedEquipment: List.unmodifiable(droppedEquipment),
      displayParts: List.unmodifiable(displayParts),
    );
  }
}
