import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/providers/database_provider.dart';
import 'package:echoes_of_aether/application/providers/game_config_provider.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/core/utils/number_formatter.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/difficulty_config.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loot_table.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/dungeon_reward_settlement_service.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/loot_service.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_completed_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/hud_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/echoes_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig({
  CombatStats? baseStatsOverride,
  int? expBaseOverride,
}) {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  final baseProg = parser.parseProgression(settings);
  final progression = (baseStatsOverride == null && expBaseOverride == null)
      ? baseProg
      : ProgressionConfig(
          maxLevel: baseProg.maxLevel,
          expCurve: expBaseOverride != null
              ? ExpCurveConfig.polynomial(
                  base: expBaseOverride.toDouble(),
                  exponent: 1.8,
                )
              : baseProg.expCurve,
          baseStats: baseStatsOverride ?? baseProg.baseStats,
          perLevel: baseProg.perLevel,
        );
  final config = GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: progression,
    equipment: parser.parseEquipment(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(
      _readAsset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
  );
  const GameConfigValidator().validate(config);
  return config;
}

const _parityLayout = <String>[
  '########',
  '#......#',
  '#......#',
  '#......#',
  '########',
];

GameConfig _buildParityConfig(DifficultyConfig difficulty) {
  final monsters = <String, EnemyDefinition>{
    'slime': const EnemyDefinition(
      id: 'slime',
      name: 'Slime',
      level: 1,
      expReward: 20,
      goldReward: 10,
      lootTableId: 'mob_drop',
      stats: CombatStats(
        maxHp: 25,
        atk: 3,
        def: 0,
        attackSpeed: 1.0,
        moveSpeed: 2.0,
      ),
    ),
    'boss': const EnemyDefinition(
      id: 'boss',
      name: 'Guardian',
      level: 5,
      isBoss: true,
      expReward: 60,
      goldReward: 30,
      lootTableId: 'boss_drop',
      stats: CombatStats(
        maxHp: 40,
        atk: 4,
        def: 0,
        attackSpeed: 1.0,
        moveSpeed: 2.0,
      ),
    ),
  };
  final items = <String, ItemDefinition>{
    'small_potion': const ItemDefinition(
      id: 'small_potion',
      name: 'Small Potion',
      category: ItemCategory.consumable,
      rarity: ItemRarity.common,
      maxStack: 99,
    ),
    'ancient_fragment': const ItemDefinition(
      id: 'ancient_fragment',
      name: 'Ancient Fragment',
      category: ItemCategory.material,
      rarity: ItemRarity.uncommon,
      maxStack: 999,
    ),
    'ranger_blade': const ItemDefinition(
      id: 'ranger_blade',
      name: 'Ranger Blade',
      category: ItemCategory.equipment,
      rarity: ItemRarity.rare,
      equipment: EquipmentData(
        slot: EquipmentSlot.weapon,
        weaponType: 'sword',
        baseStats: EquipmentStats(
          atk: 20,
          critRate: 0.1,
          attackSpeed: 0.2,
          skillHaste: 0.05,
        ),
      ),
    ),
    'heart_of_aether': const ItemDefinition(
      id: 'heart_of_aether',
      name: 'Heart of Aether',
      category: ItemCategory.equipment,
      rarity: ItemRarity.legendary,
      equipment: EquipmentData(
        slot: EquipmentSlot.accessory,
        baseStats: EquipmentStats(
          hp: 100,
          atk: 25,
          def: 15,
          critDamage: 0.4,
          skillHaste: 0.15,
        ),
      ),
    ),
  };
  final lootTables = <String, LootTable>{
    'mob_drop': const LootTable(
      id: 'mob_drop',
      entries: [
        LootEntry(
          itemId: 'small_potion',
          chance: 0.4,
          minQuantity: 1,
          maxQuantity: 2,
        ),
        LootEntry(itemId: 'ancient_fragment', chance: 0.25),
        LootEntry(itemId: 'ranger_blade', chance: 0.35),
      ],
    ),
    'boss_drop': const LootTable(
      id: 'boss_drop',
      entries: [
        LootEntry(itemId: 'ranger_blade', chance: 0.4),
        LootEntry(itemId: 'heart_of_aether', chance: 0.2),
      ],
    ),
    'clear_drop': const LootTable(
      id: 'clear_drop',
      entries: [
        LootEntry(
          itemId: 'ancient_fragment',
          chance: 0.5,
          minQuantity: 2,
          maxQuantity: 3,
        ),
        LootEntry(itemId: 'heart_of_aether', chance: 0.3),
      ],
    ),
  };
  final dungeon = DungeonDefinition(
    id: 'parity_forest',
    name: 'Parity Forest',
    biome: 'forest',
    kind: DungeonKind.normal,
    order: 1,
    difficultyScale: 1.5,
    startRoomId: 'r1',
    roomOrder: const ['r1', 'r2'],
    completionReward: const DungeonCompletionReward(
      expReward: 100,
      goldReward: 50,
      lootTableId: 'clear_drop',
    ),
    rooms: const {
      'r1': RoomDefinition(
        id: 'r1',
        dungeonId: 'parity_forest',
        name: 'Room 1',
        type: RoomType.normal,
        mapRef: 'r1',
        layout: _parityLayout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(6, 2),
        nextRoomIds: ['r2'],
        completionCondition: RoomCompletionCondition(
          type: RoomCompletionConditionType.defeatRequiredEnemies,
        ),
        reward: RoomRewardConfig(expReward: 25, goldReward: 15),
        spawns: [
          RoomSpawnConfig(
            id: 's1',
            monsterId: 'slime',
            position: GridPoint(5, 2),
          ),
        ],
      ),
      'r2': RoomDefinition(
        id: 'r2',
        dungeonId: 'parity_forest',
        name: 'Room 2 Boss',
        type: RoomType.boss,
        mapRef: 'r2',
        layout: _parityLayout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(6, 2),
        completionCondition: RoomCompletionCondition(
          type: RoomCompletionConditionType.defeatBoss,
        ),
        reward: RoomRewardConfig(expReward: 35, goldReward: 20),
        spawns: [
          RoomSpawnConfig(
            id: 'b1',
            monsterId: 'boss',
            position: GridPoint(6, 2),
            isBoss: true,
          ),
        ],
      ),
    },
  );
  return GameConfig(
    monsters: monsters,
    difficulty: difficulty,
    revive: const ReviveConfig(),
    progression: const ProgressionConfig(
      maxLevel: 50,
      expBase: 100000,
      expGrowth: 1.4,
      baseStats: CombatStats(
        maxHp: 50000,
        atk: 50000,
        def: 10000,
        attackSpeed: 4.0,
        critRate: 0.0,
        critDamage: 1.5,
        moveSpeed: 1.5,
        attackRange: 1.0,
      ),
      perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
    ),
    equipment: const EquipmentConfig(rollVariance: 0.15),
    items: items,
    lootTables: lootTables,
    dungeons: {'parity_forest': dungeon},
  );
}

void _expectStatsEqual(EquipmentStats a, EquipmentStats b) {
  expect(a.hp, b.hp);
  expect(a.atk, b.atk);
  expect(a.def, b.def);
  expect(a.attackSpeed, b.attackSpeed);
  expect(a.critRate, b.critRate);
  expect(a.critDamage, b.critDamage);
  expect(a.moveSpeed, b.moveSpeed);
  expect(a.attackRange, b.attackRange);
  expect(a.skillHaste, b.skillHaste);
}

({int exp, int gold}) _analyticalDungeonTotals(
  GameConfig config,
  DungeonDefinition dungeon,
  DifficultyProfile profile,
  DifficultyService diffService,
) {
  var exp = 0;
  var gold = 0;
  for (final roomId in dungeon.roomOrder) {
    final room = dungeon.rooms[roomId]!;
    for (final spawn in room.spawns) {
      final monster = config.monsters[spawn.monsterId]!;
      exp += diffService.scaleExp(monster.expReward, profile);
      gold += diffService.scaleGold(monster.goldReward, profile);
    }
    final roomReward = room.reward;
    if (roomReward != null) {
      exp += diffService.scaleExp(roomReward.expReward, profile);
      gold += diffService.scaleGold(roomReward.goldReward, profile);
    }
  }
  final completion = dungeon.completionReward ?? config.dungeonCompletion;
  exp += diffService.scaleExp(completion.expReward, profile);
  gold += diffService.scaleGold(completion.goldReward, profile);
  return (exp: exp, gold: gold);
}

Future<void> _flushDb() =>
    Future<void>.delayed(const Duration(milliseconds: 25));

Future<void> _mountDungeonApp(
  WidgetTester tester,
  AppDatabase db,
  GameConfig config, {
  Key? screenKey,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: screenKey != null ? ValueKey('scope_$screenKey') : UniqueKey(),
      overrides: [
        gameConfigProvider.overrideWith((ref) async => config),
        playerSaveRepositoryProvider.overrideWith(
          (ref) async => DriftPlayerSaveRepository(db: db, config: config),
        ),
      ],
      child: MaterialApp(
        home: DungeonScreen(key: screenKey, roomTransitionDelaySeconds: 0.05),
      ),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump();
    await tester.runAsync(_flushDb);
    await tester.pump();
    if (find.byType(TownHubView).evaluate().isNotEmpty ||
        find.byType(HudOverlay).evaluate().isNotEmpty) {
      break;
    }
  }
  await tester.pump();
}

Future<void> _runGameUntilOverlay<T extends Widget>(
  WidgetTester tester, {
  int maxSteps = 500,
}) async {
  final game = tester
      .widget<GameWidget<EchoesGame>>(find.byType(GameWidget<EchoesGame>))
      .game!;
  for (var i = 0; i < maxSteps; i++) {
    game.update(0.1);
    await tester.pump();
    final pending = game.world.pendingRoomLoad;
    if (pending != null) {
      await pending;
      await tester.pump();
    }
    if (find.byType(T).evaluate().isNotEmpty) {
      await tester.pump();
      return;
    }
  }
  await tester.pump();
  if (find.byType(T).evaluate().isEmpty) {
    final manager = game.world.dungeonManager;
    final sim = game.world.simulation;
    fail(
      'Overlay $T tidak muncul setelah $maxSteps langkah '
      '(dungeon=${manager?.activeDungeon?.id}, room=${manager?.activeRoom?.id}, '
      'session=${manager?.session?.status}/${manager?.session?.roomLifecycle}, '
      'enemies=${sim.aliveEnemies.length}/${sim.enemies.length}, '
      'overlays=${game.overlays.activeOverlays}).',
    );
  }
}

void main() {
  late GameConfig realConfig;
  late DifficultyService diffService;

  setUpAll(() {
    realConfig = _loadRealConfig();
    diffService = DifficultyService(realConfig.difficulty);
  });

  group('M9 Stage 4 — Skala Reward, Drop & Kualitas Equipment per Rank', () {
    test('Rank 0 menghasilkan reward (Forgotten Forest 1x), drop loot, dan roll stat equipment yang identik dengan baseline', () {
      const lootService = LootService();
      final eqFactory = EquipmentFactory(realConfig.equipment);

      final forest = realConfig.dungeons['forgotten_forest']!;
      final aether = realConfig.dungeons['aether_sanctum']!;
      final ascension = realConfig.dungeons['ascension_sanctum']!;

      final pForest0 = diffService.profileFor(forest, 0);
      final pAether0 = diffService.profileFor(aether, 0);
      final pAsc0 = diffService.profileFor(ascension, 0);

      expect(pForest0.isIdentity, isTrue);
      expect(pForest0.rewardMultiplier, 1.0);
      expect(diffService.scaleExp(120, pForest0), 120);
      expect(diffService.scaleGold(50, pForest0), 50);

      // Semua dungeon pada Rank 0 tidak mengubah drop chance maupun roll bonus.
      for (final p in [pForest0, pAether0, pAsc0]) {
        expect(p.rareDropChanceMultiplier, 1.0);
        expect(p.equipmentRollBonus, 0.0);
      }

      // Bandingkan stream drop loot pada Rank 0 melawan panggilan default unscaled.
      for (final table in realConfig.lootTables.values) {
        for (var seed = 0; seed < 50; seed++) {
          final baseline = lootService.roll(table, math.Random(seed));
          final atRank0 = lootService.roll(
            table,
            math.Random(seed),
            items: realConfig.items,
            rareDropChanceMultiplier: pAsc0.rareDropChanceMultiplier,
          );
          expect(atRank0.length, baseline.length);
          for (var i = 0; i < baseline.length; i++) {
            expect(atRank0[i].itemId, baseline[i].itemId);
            expect(atRank0[i].quantity, baseline[i].quantity);
          }
        }
      }

      // Bandingkan stat hasil roll equipment pada Rank 0 melawan default (rollBonus=0.0).
      final equipmentItems = realConfig.items.values
          .where((item) => item.isEquipment)
          .toList();
      expect(equipmentItems, isNotEmpty);
      for (final item in equipmentItems) {
        for (var seed = 0; seed < 30; seed++) {
          final baseline = eqFactory.create(
            instanceId: 'base_${item.id}_$seed',
            definition: item,
            random: math.Random(seed),
          );
          final atRank0 = eqFactory.create(
            instanceId: 'r0_${item.id}_$seed',
            definition: item,
            random: math.Random(seed),
            rollBonus: pAsc0.equipmentRollBonus,
          );
          _expectStatsEqual(atRank0.rolledStats, baseline.rolledStats);
        }
      }
    });

    test('Rank 1, 5, 10, 25, dan 1000 mengikuti formula reward_exponent dan batas atas drop/roll', () {
      final forest = realConfig.dungeons['forgotten_forest']!;
      final aether = realConfig.dungeons['aether_sanctum']!;
      final ascension = realConfig.dungeons['ascension_sanctum']!;
      final rewardExponent = realConfig.difficulty.rewardExponent;
      final cyclePerRank = realConfig.difficulty.cyclePerRank;
      final maxMult = realConfig.difficulty.maxMultiplier;

      expect(rewardExponent, closeTo(0.85, 1e-9));
      expect(realConfig.difficulty.drop.rareChancePerRank, closeTo(0.1, 1e-9));
      expect(
        realConfig.difficulty.drop.maxChanceMultiplier,
        closeTo(3.0, 1e-9),
      );
      expect(realConfig.difficulty.drop.rollBonusPerRank, closeTo(0.02, 1e-9));
      expect(realConfig.difficulty.drop.maxRollBonus, closeTo(0.5, 1e-9));

      final expectedDropMult = <int, double>{
        0: 1.0,
        1: 1.1,
        5: 1.5,
        10: 2.0,
        25: 3.0,
        1000: 3.0,
      };
      final expectedRollBonus = <int, double>{
        0: 0.0,
        1: 0.02,
        5: 0.10,
        10: 0.20,
        25: 0.50,
        1000: 0.50,
      };

      for (final rank in [0, 1, 5, 10, 25, 1000]) {
        for (final d in [forest, aether, ascension]) {
          final p = diffService.profileFor(d, rank);
          final rawM = d.difficultyScale * (1.0 + cyclePerRank * rank);
          final clampedM = math.min(rawM, maxMult);
          final expectedRewardMult = math
              .pow(clampedM, rewardExponent)
              .toDouble();

          expect(p.multiplier, closeTo(clampedM, 1e-9));
          expect(p.rewardMultiplier, closeTo(expectedRewardMult, 1e-9));
          expect(
            p.rareDropChanceMultiplier,
            closeTo(expectedDropMult[rank]!, 1e-9),
          );
          expect(p.equipmentRollBonus, closeTo(expectedRollBonus[rank]!, 1e-9));
          expect(
            diffService.scaleExp(100, p),
            (100 * expectedRewardMult).round(),
          );
          expect(
            diffService.scaleGold(50, p),
            (50 * expectedRewardMult).round(),
          );
        }
      }
    });

    test('LootService.roll: item < Rare tidak terskala, Rare/Epic/Legendary/questItem Rare terskala dan ter-cap <= 1.0 serta deterministik', () {
      const lootService = LootService();
      const table = LootTable(
        id: 'test_rarity_scaling',
        entries: [
          LootEntry(itemId: 'small_potion', chance: 0.3), // common
          LootEntry(itemId: 'ancient_fragment', chance: 0.25), // uncommon
          LootEntry(itemId: 'aether_sigil', chance: 0.2), // questItem rare
          LootEntry(
            itemId: 'ranger_blade',
            chance: 0.5,
          ), // rare -> cap 1.0 at r10+
          LootEntry(itemId: 'aether_blade', chance: 0.25), // epic
          LootEntry(itemId: 'heart_of_aether', chance: 0.15), // legendary
        ],
      );

      final forest = realConfig.dungeons['forgotten_forest']!;
      const trials = 6000;

      Map<String, int> countDrops(int rank, int seed) {
        final profile = diffService.profileFor(forest, rank);
        final rng = math.Random(seed);
        final counts = <String, int>{};
        for (var i = 0; i < trials; i++) {
          final drops = lootService.roll(
            table,
            rng,
            items: realConfig.items,
            rareDropChanceMultiplier: profile.rareDropChanceMultiplier,
          );
          for (final d in drops) {
            counts[d.itemId] = (counts[d.itemId] ?? 0) + 1;
          }
        }
        return counts;
      }

      // Common & Uncommon harus identik (secara hitungan maupun urutan RNG) pada semua rank.
      for (final rank in [1, 5, 10, 1000]) {
        final p = diffService.profileFor(forest, rank);
        for (var i = 0; i < 200; i++) {
          const nonRareOnly = LootTable(
            id: 'non_rare',
            entries: [
              LootEntry(itemId: 'small_potion', chance: 0.3),
              LootEntry(itemId: 'ancient_fragment', chance: 0.25),
            ],
          );
          final r0 = lootService.roll(
            nonRareOnly,
            math.Random(900 + i),
            items: realConfig.items,
            rareDropChanceMultiplier: 1.0,
          );
          final rHigh = lootService.roll(
            nonRareOnly,
            math.Random(900 + i),
            items: realConfig.items,
            rareDropChanceMultiplier: p.rareDropChanceMultiplier,
          );
          expect(
            rHigh.map((e) => e.itemId).toList(),
            r0.map((e) => e.itemId).toList(),
          );
        }
      }

      final c0 = countDrops(0, 12345);
      final c5 = countDrops(5, 12345);
      final c10 = countDrops(10, 12345);
      final c1000 = countDrops(1000, 12345);

      // Item di bawah Rare tetap ~base chance di semua rank.
      for (final counts in [c0, c5, c10, c1000]) {
        expect(counts['small_potion']! / trials, closeTo(0.30, 0.025));
        expect(counts['ancient_fragment']! / trials, closeTo(0.25, 0.025));
      }

      // Rank 5 (1.5x): aether_sigil 0.30, ranger_blade 0.75, aether_blade 0.375, heart 0.225
      expect(c5['aether_sigil']! / trials, closeTo(0.30, 0.025));
      expect(c5['ranger_blade']! / trials, closeTo(0.75, 0.025));
      expect(c5['aether_blade']! / trials, closeTo(0.375, 0.025));
      expect(c5['heart_of_aether']! / trials, closeTo(0.225, 0.025));

      // Rank 10 (2.0x): ranger_blade 0.5*2 = 1.0 (100% pasti drop, tidak > 1.0)
      expect(c10['ranger_blade'], trials);
      expect(c10['aether_blade']! / trials, closeTo(0.50, 0.025));
      expect(c10['heart_of_aether']! / trials, closeTo(0.30, 0.025));

      // Rank 1000 (ter-cap 3.0x): ranger_blade ter-clamp 1.0 (100%), aether_blade 0.75, heart 0.45
      expect(c1000['ranger_blade'], trials);
      expect(c1000['aether_blade']! / trials, closeTo(0.75, 0.025));
      expect(c1000['heart_of_aether']! / trials, closeTo(0.45, 0.025));

      // Fallback tanpa peta `items`: multiplier > 1.0 tidak crash dan memperlakukan entri sebagai non-scaled.
      final noItems = lootService.roll(
        table,
        math.Random(77),
        items: null,
        rareDropChanceMultiplier: 3.0,
      );
      final unscaled = lootService.roll(table, math.Random(77));
      expect(
        noItems.map((e) => e.itemId).toList(),
        unscaled.map((e) => e.itemId).toList(),
      );

      // Deterministik untuk seed sama pada Rank tinggi.
      final detA = lootService.roll(
        table,
        math.Random(4242),
        items: realConfig.items,
        rareDropChanceMultiplier: 3.0,
      );
      final detB = lootService.roll(
        table,
        math.Random(4242),
        items: realConfig.items,
        rareDropChanceMultiplier: 3.0,
      );
      expect(
        detA.map((e) => '${e.itemId}:${e.quantity}').toList(),
        detB.map((e) => '${e.itemId}:${e.quantity}').toList(),
      );
    });

    test('EquipmentFactory & EquipmentStats.roll: rollBonus menggeser rentang [1 - v + bonus, 1 + v + bonus] tanpa mendistorsi lebar roll_variance dan deterministik', () {
      final variance = realConfig.equipment.rollVariance; // 0.15
      final eqFactory = EquipmentFactory(realConfig.equipment);
      final forest = realConfig.dungeons['forgotten_forest']!;

      const syntheticWeapon = ItemDefinition(
        id: 'synthetic_blade',
        name: 'Synthetic Blade',
        category: ItemCategory.equipment,
        rarity: ItemRarity.legendary,
        equipment: EquipmentData(
          slot: EquipmentSlot.weapon,
          weaponType: 'sword',
          baseStats: EquipmentStats(
            hp: 100,
            atk: 50,
            def: 0, // nol harus tetap 0 meski ada rollBonus
            critRate: 0.2,
            critDamage: 0.4,
            attackSpeed: 0.5,
            moveSpeed: 1.0,
            attackRange: 0.5,
            skillHaste: 0.1,
          ),
        ),
      );

      const samples = 2000;
      const eps = 1e-9;

      for (final rank in [0, 1, 5, 10, 25, 1000]) {
        final bonus = diffService.profileFor(forest, rank).equipmentRollBonus;
        final expectedMinFactor = 1.0 - variance + bonus;
        final expectedMaxFactor = 1.0 + variance + bonus;

        var minAtkRatio = double.infinity;
        var maxAtkRatio = double.negativeInfinity;
        var sumAtkRatio = 0.0;
        var minHasteRatio = double.infinity;
        var maxHasteRatio = double.negativeInfinity;

        for (var i = 0; i < samples; i++) {
          final inst = eqFactory.create(
            instanceId: 'eq_${rank}_$i',
            definition: syntheticWeapon,
            random: math.Random(10000 + i),
            rollBonus: bonus,
          );
          final r = inst.rolledStats;

          // Stat bernilai 0 wajib tetap 0 meski bonus > 0.
          expect(r.def, 0.0);

          void checkStat(double rolled, double base) {
            final ratio = rolled / base;
            expect(
              ratio,
              inInclusiveRange(
                expectedMinFactor - eps,
                expectedMaxFactor + eps,
              ),
              reason:
                  'rank=$rank ratio=$ratio outside [$expectedMinFactor, $expectedMaxFactor]',
            );
          }

          checkStat(r.hp, 100);
          checkStat(r.atk, 50);
          checkStat(r.critRate, 0.2);
          checkStat(r.critDamage, 0.4);
          checkStat(r.attackSpeed, 0.5);
          checkStat(r.moveSpeed, 1.0);
          checkStat(r.attackRange, 0.5);
          checkStat(r.skillHaste, 0.1);

          final atkRatio = r.atk / 50.0;
          final hasteRatio = r.skillHaste / 0.1;
          minAtkRatio = math.min(minAtkRatio, atkRatio);
          maxAtkRatio = math.max(maxAtkRatio, atkRatio);
          sumAtkRatio += atkRatio;
          minHasteRatio = math.min(minHasteRatio, hasteRatio);
          maxHasteRatio = math.max(maxHasteRatio, hasteRatio);
        }

        // Lebar sebaran tetap 2 * variance (tidak ikut melebar sebesar *(1+bonus)).
        expect(maxAtkRatio - minAtkRatio, closeTo(2 * variance, 0.015));
        expect(maxHasteRatio - minHasteRatio, closeTo(2 * variance, 0.015));
        // Mean bergeser tepat +bonus di sekitar 1.0.
        expect(sumAtkRatio / samples, closeTo(1.0 + bonus, 0.015));

        // Determinisme seed sama pada rank tersebut.
        final det1 = eqFactory.create(
          instanceId: 'det_1',
          definition: syntheticWeapon,
          random: math.Random(999),
          rollBonus: bonus,
        );
        final det2 = eqFactory.create(
          instanceId: 'det_2',
          definition: syntheticWeapon,
          random: math.Random(999),
          rollBonus: bonus,
        );
        _expectStatsEqual(det1.rolledStats, det2.rolledStats);
      }

      // rollBonus negatif diamankan menjadi 0.0 (rentang tetap [1 - variance, 1 + variance]).
      final safeNegative = const EquipmentStats(atk: 10)
          .roll(math.Random(1), 0.15, rollBonus: -2.0);
      expect(safeNegative.atk, inInclusiveRange(8.5, 11.5));
    });

    test('Paritas Online vs Offline Mode A & Mode B pada Rank 1, 5, 10, 1000: EXP, Gold, Loot Rare+, Roll Equipment & Determinisme', () {
      const offlineRunner = OfflineDungeonRunner();
      const timeCalc = OfflineTimeCalculator();
      final difficulty = realConfig.difficulty;
      final config = _buildParityConfig(difficulty);
      final dService = DifficultyService(config.difficulty);
      final dungeon = config.dungeons['parity_forest']!;

      for (final rank in [1, 5, 10, 1000]) {
        final profile = dService.profileFor(dungeon, rank);
        final expectedTotals = _analyticalDungeonTotals(
          config,
          dungeon,
          profile,
          dService,
        );

        // 1) Jalur Headless Online (DungeonManager + CombatSimulation + EncounterTracker + Settlement).
        final onlineChar = PlayerCharacter(config: config.progression);
        final onlineInv = Inventory(definitions: config.items);
        final eqFactory = EquipmentFactory(config.equipment);
        final onlineRp = RewardProcessor(
          character: onlineChar,
          inventory: onlineInv,
          items: config.items,
          lootTables: config.lootTables,
          equipmentFactory: eqFactory,
        );
        final tracker = EncounterTracker(monsterCatalog: config.monsters);
        final manager = DungeonManager(
          dungeons: config.dungeons,
          encounterTracker: tracker,
          difficultyService: dService,
        );
        const settlement = DungeonRewardSettlementService();

        DungeonEndedEvent? endedEvent;
        manager.addListener((ev) {
          if (ev is DungeonEndedEvent &&
              ev.finalStatus == DungeonSessionStatus.completed) {
            endedEvent = ev;
          }
        });

        final session = manager.startDungeon(
          dungeon.id,
          runId: 'online_rank_$rank',
          cycleRank: rank,
        );
        expect(
          manager.activeDifficultyProfile.rewardMultiplier,
          profile.rewardMultiplier,
        );

        final onlineRewardRng = math.Random(5050 + rank);
        var onlineTotalTicks = 0;

        for (var rIdx = 0; rIdx < dungeon.roomOrder.length; rIdx++) {
          final room = manager.activeRoom!;
          final grid = manager.activeGrid!;
          final player = Combatant(
            id: 'player',
            team: Team.player,
            stats: onlineChar.stats,
            cell: room.entryPosition,
          );
          final sim = CombatSimulation(
            grid: grid,
            pathfinder: const AStarPathfinder(),
            player: player,
            reviveConfig: config.revive,
            damageCalculator: config.damage.createCalculator(),
            seed: 100 + rIdx,
          );
          tracker.onRoomLoaded(sim, grid: grid);
          manager.activateRoom();
          tracker.onRoomActivated(sim, grid: grid);

          for (var t = 0; t < 400; t++) {
            sim.tick();
            onlineTotalTicks++;
            for (final ev in sim.drainEvents()) {
              if (ev is EnemyDefeatedEvent) {
                onlineRp.processEnemyDefeated(
                  eventId: 'kill:${session.runId}:${ev.tick}:${ev.enemyId}',
                  definition: ev.definition,
                  random: onlineRewardRng,
                  difficultyProfile: manager.activeDifficultyProfile,
                  difficultyService: dService,
                );
                tracker.onEnemyDefeated(
                  ev.enemyId,
                  simulation: sim,
                  grid: grid,
                );
              }
            }
            manager.updatePlayerCell(player.follower.currentCell);
            final completed = manager.tryCompleteActiveRoom(
              playerCell: player.follower.currentCell,
            );
            if (completed) {
              settlement.settleRoomCompleted(
                session: manager.session!,
                room: room,
                rewardProcessor: onlineRp,
                random: onlineRewardRng,
                difficultyProfile: manager.activeDifficultyProfile,
                difficultyService: dService,
              );
            }
            if (manager.session?.roomLifecycle ==
                    RoomLifecycleState.completed ||
                manager.session?.status == DungeonSessionStatus.completed) {
              break;
            }
          }
          if (rIdx < dungeon.roomOrder.length - 1) {
            expect(manager.transitionToNextRoom(), isTrue);
          }
        }

        expect(endedEvent, isNotNull);
        settlement.settleDungeonCompleted(
          event: endedEvent!,
          config: config,
          rewardProcessor: onlineRp,
          random: onlineRewardRng,
          dungeonManager: manager,
          difficultyProfile: manager.activeDifficultyProfile,
          difficultyService: dService,
        );

        expect(onlineTotalTicks, greaterThan(0));
        var totalOnlineExp = onlineChar.currentExp;
        for (var lv = 1; lv < onlineChar.level; lv++) {
          totalOnlineExp += config.progression.expToNext(lv);
        }
        expect(totalOnlineExp, expectedTotals.exp);
        expect(onlineChar.gold, expectedTotals.gold);

        // 2) Jalur Offline Mode A (continueDungeon, tepat 1 run).
        final offAChar = PlayerCharacter(config: config.progression);
        final offAInv = Inventory(definitions: config.items);
        final offARp = RewardProcessor(
          character: offAChar,
          inventory: offAInv,
          items: config.items,
          lootTables: config.lootTables,
          equipmentFactory: eqFactory,
        );
        final offARes = offlineRunner.runBatch(
          OfflineDungeonRunRequest(
            mode: OfflineActivityMode.continueDungeon,
            character: offAChar,
            inventory: offAInv,
            config: config,
            rewardProcessor: offARp,
            dungeonId: dungeon.id,
            dungeonProgress: DungeonProgressSnapshot(
              currentDungeonId: dungeon.id,
            ),
            activeDungeonSession: ActiveDungeonSessionSnapshot(
              runId: 'offline_a_rank_$rank',
              dungeonId: dungeon.id,
              currentRoomId: 'r1',
              currentRoomIndex: 0,
              status: DungeonSessionStatus.inProgress,
              cycleRank: rank,
            ),
            timeWindow: timeCalc.calculate(
              session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
              nowMs: 1000000 + const Duration(minutes: 5).inMilliseconds,
            ),
            simulationSeed: 777 + rank,
            cycleRank: rank,
          ),
        );
        expect(offARes.stopReason, OfflineDungeonStopReason.dungeonCompleted);
        expect(offARes.runsCompleted, 1);
        expect(offARes.expGained, expectedTotals.exp);
        expect(offARes.goldGained, expectedTotals.gold);
        expect(offAChar.currentExp, onlineChar.currentExp);
        expect(offAChar.gold, onlineChar.gold);

        // 3) Jalur Offline Mode B (autoFarming, window tepat 1 clear + multi-run).
        final exactWindowMs = offARes.processedDurationMs + 50;
        final offBChar = PlayerCharacter(config: config.progression);
        final offBInv = Inventory(definitions: config.items);
        final offBRp = RewardProcessor(
          character: offBChar,
          inventory: offBInv,
          items: config.items,
          lootTables: config.lootTables,
          equipmentFactory: eqFactory,
        );
        final offBRes = offlineRunner.runBatch(
          OfflineDungeonRunRequest(
            mode: OfflineActivityMode.autoFarming,
            character: offBChar,
            inventory: offBInv,
            config: config,
            rewardProcessor: offBRp,
            dungeonId: dungeon.id,
            dungeonProgress: DungeonProgressSnapshot(
              currentDungeonId: dungeon.id,
              clearsCount: 1,
              clearedInCycleRank: rank,
            ),
            timeWindow: timeCalc.calculate(
              session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
              nowMs: 1000000 + exactWindowMs,
            ),
            simulationSeed: 777 + rank,
            cycleRank: rank,
          ),
        );
        expect(offBRes.runsCompleted, 1);
        expect(offBRes.expGained, expectedTotals.exp);
        expect(offBRes.goldGained, expectedTotals.gold);

        // Mode B multi-run & determinisme seed sama:
        OfflineDungeonRunOutcome runMultiModeB() {
          final c = PlayerCharacter(config: config.progression);
          final i = Inventory(definitions: config.items);
          return offlineRunner.runBatch(
            OfflineDungeonRunRequest(
              mode: OfflineActivityMode.autoFarming,
              character: c,
              inventory: i,
              config: config,
              rewardProcessor: RewardProcessor(
                character: c,
                inventory: i,
                items: config.items,
                lootTables: config.lootTables,
                equipmentFactory: eqFactory,
              ),
              dungeonId: dungeon.id,
              dungeonProgress: DungeonProgressSnapshot(
                currentDungeonId: dungeon.id,
                clearsCount: 1,
                clearedInCycleRank: rank,
              ),
              timeWindow: timeCalc.calculate(
                session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
                nowMs: 1000000 + const Duration(minutes: 5).inMilliseconds,
              ),
              simulationSeed: 888 + rank,
              cycleRank: rank,
            ),
          );
        }

        final run1 = runMultiModeB();
        final run2 = runMultiModeB();
        expect(run1.runsCompleted, greaterThan(1));
        expect(run1.expGained, run2.expGained);
        expect(run1.goldGained, run2.goldGained);
        expect(run1.addedStacks, run2.addedStacks);
        expect(run1.addedEquipment.length, run2.addedEquipment.length);
        for (var i = 0; i < run1.addedEquipment.length; i++) {
          final e1 = run1.addedEquipment[i];
          final e2 = run2.addedEquipment[i];
          expect(e1.definitionId, e2.definitionId);
          _expectStatsEqual(e1.rolledStats, e2.rolledStats);
          // Setiap roll equipment tetap berada dalam rentang [1 - v + bonus, 1 + v + bonus].
          final baseStats = config.items[e1.definitionId]!.equipment!.baseStats;
          if (baseStats.atk > 0) {
            final ratio = e1.rolledStats.atk / baseStats.atk;
            expect(
              ratio,
              inInclusiveRange(
                1.0 - 0.15 + profile.equipmentRollBonus - 1e-9,
                1.0 + 0.15 + profile.equipmentRollBonus + 1e-9,
              ),
            );
          }
        }

        // 4) Paritas RewardProcessor langsung (drop stacks & rolled stats identik untuk seed identik).
        GrantedReward runRewardSequence(RewardProcessor rp, int seed) {
          final rng = math.Random(seed);
          final g1 = rp.processEnemyDefeated(
            eventId: 'seq_1_$seed',
            definition: config.monsters['slime']!,
            random: rng,
            difficultyProfile: profile,
            difficultyService: dService,
          );
          final g2 = rp.processEnemyDefeated(
            eventId: 'seq_2_$seed',
            definition: config.monsters['boss']!,
            random: rng,
            difficultyProfile: profile,
            difficultyService: dService,
          );
          final g3 = rp.processDungeonCompletion(
            eventId: 'seq_3_$seed',
            reward: dungeon.completionReward!,
            random: rng,
            difficultyProfile: profile,
            difficultyService: dService,
          );
          return GrantedReward(
            eventId: 'seq_sum_$seed',
            alreadyClaimed: false,
            expGranted: g1.expGranted + g2.expGranted + g3.expGranted,
            goldGranted: g1.goldGranted + g2.goldGranted + g3.goldGranted,
          );
        }

        final seqOnlineChar = PlayerCharacter(config: config.progression);
        final seqOnlineInv = Inventory(definitions: config.items);
        final seqOfflineChar = PlayerCharacter(config: config.progression);
        final seqOfflineInv = Inventory(definitions: config.items);

        final sumA = runRewardSequence(
          RewardProcessor(
            character: seqOnlineChar,
            inventory: seqOnlineInv,
            items: config.items,
            lootTables: config.lootTables,
            equipmentFactory: eqFactory,
          ),
          2026 + rank,
        );
        final sumB = runRewardSequence(
          RewardProcessor(
            character: seqOfflineChar,
            inventory: seqOfflineInv,
            items: config.items,
            lootTables: config.lootTables,
            equipmentFactory: eqFactory,
          ),
          2026 + rank,
        );

        expect(sumA.expGranted, sumB.expGranted);
        expect(sumA.goldGranted, sumB.goldGranted);
        expect(
          seqOnlineInv.toSnapshot().stacks,
          seqOfflineInv.toSnapshot().stacks,
        );
        final onlineBag = seqOnlineInv.equipmentSnapshot();
        final offlineBag = seqOfflineInv.equipmentSnapshot();
        expect(onlineBag.length, offlineBag.length);
        for (var i = 0; i < onlineBag.length; i++) {
          expect(onlineBag[i].definitionId, offlineBag[i].definitionId);
          _expectStatsEqual(
            onlineBag[i].rolledStats,
            offlineBag[i].rolledStats,
          );
        }
      }
    });

    test('OfflineProgressionService pada Forgotten Forest (aset asli) di Rank 5 & Rank 1000 selaras dengan OfflineDungeonRunner dan batas aman', () {
      const offlineService = OfflineProgressionService();
      final forestConfig = _loadRealConfig(
        baseStatsOverride: const CombatStats(
          maxHp: 80000,
          atk: 80000,
          def: 20000,
          attackSpeed: 4.0,
          moveSpeed: 8.0,
          attackRange: 6.0,
        ),
        expBaseOverride: 100000000,
      );
      final dService = DifficultyService(forestConfig.difficulty);
      final forest = forestConfig.dungeons['forgotten_forest']!;
      const startMs = 2000000;
      final endMs = startMs + const Duration(minutes: 5).inMilliseconds;

      for (final rank in [5, 1000]) {
        final profile = dService.profileFor(forest, rank);
        final singleRunExpected = _analyticalDungeonTotals(
          forestConfig,
          forest,
          profile,
          dService,
        );

        final char = PlayerCharacter(config: forestConfig.progression);
        final inv = Inventory(definitions: forestConfig.items);
        final res = offlineService.process(
          character: char,
          inventory: inv,
          config: forestConfig,
          session: const GameSessionSnapshot(lastSavedAtMs: startMs),
          nowMs: endMs,
          cycleProgress: CycleProgress(ascensionRank: rank),
          offlineActivity: const OfflineActivitySnapshot(
            mode: OfflineActivityMode.autoFarming,
            state: OfflineActivityState.configured,
            selectedDungeonId: 'forgotten_forest',
            simulationSeed: 31337,
          ),
          dungeonProgresses: {
            'forgotten_forest': DungeonProgressSnapshot(
              currentDungeonId: 'forgotten_forest',
              clearsCount: 1,
              clearedInCycleRank: rank,
            ),
          },
        );

        expect(res.status, OfflineProgressionStatus.applied);
        expect(res.updatedOfflineActivity?.pendingSummary?.cycleRank, rank);
        expect(res.runsCompleted, greaterThanOrEqualTo(1));
        // Offline Farming harus minimal memperoleh reward penuh tiap clear + kill parsial jika sempat.
        expect(
          res.expGained,
          greaterThanOrEqualTo(res.runsCompleted * singleRunExpected.exp),
        );
        expect(
          res.goldGained,
          greaterThanOrEqualTo(res.runsCompleted * singleRunExpected.gold),
        );
        expect(char.currentExp, res.expGained);
        expect(char.gold, res.goldGained);

        // Verifikasi setiap drop equipment di Offline memiliki stat dalam [1 - v + bonus, 1 + v + bonus].
        final eqItems = <EquipmentInstance>[
          ...inv.equipmentSnapshot(),
          ...res.droppedEquipment,
        ];
        for (final eq in eqItems) {
          final base =
              forestConfig.items[eq.definitionId]!.equipment!.baseStats;
          if (base.atk > 0) {
            final ratio = eq.rolledStats.atk / base.atk;
            expect(
              ratio,
              inInclusiveRange(
                1.0 - 0.15 + profile.equipmentRollBonus - 1e-9,
                1.0 + 0.15 + profile.equipmentRollBonus + 1e-9,
              ),
            );
          }
        }
      }
    });

    testWidgets(
      'Flame EchoesGame Online pada Rank 5 (Forgotten Forest): profil Rank, overlay ter-skala, dan total EXP/Gold akurat',
      (tester) async {
        final strongConfig = _loadRealConfig(
          baseStatsOverride: const CombatStats(
            maxHp: 50000,
            atk: 50000,
            def: 10000,
            attackSpeed: 5.0,
            moveSpeed: 10.0,
            attackRange: 6.0,
          ),
          expBaseOverride: 100000000,
        );
        final dService = DifficultyService(strongConfig.difficulty);

        // Bagian A: Forgotten Forest di Rank 5 -> cek paritas total EXP & Gold melawan analitik.
        final dbForest = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(dbForest.close));
        await tester.runAsync(dbForest.initialize);

        final forest = strongConfig.dungeons['forgotten_forest']!;
        final rank5ForestProfile = dService.profileFor(forest, 5);
        final expectedForestTotals = _analyticalDungeonTotals(
          strongConfig,
          forest,
          rank5ForestProfile,
          dService,
        );
        final forestCompletion =
            forest.completionReward ?? strongConfig.dungeonCompletion;
        final expectedForestClearExp = dService.scaleExp(
          forestCompletion.expReward,
          rank5ForestProfile,
        );
        final expectedForestClearGold = dService.scaleGold(
          forestCompletion.goldReward,
          rank5ForestProfile,
        );

        await tester.runAsync(() async {
          final repo = DriftPlayerSaveRepository(
            db: dbForest,
            config: strongConfig,
          );
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final char = PlayerCharacter(
            config: strongConfig.progression,
            progress: const PlayerProgress(level: 269, currentExp: 0, gold: 0),
            skillCatalog: strongConfig.skills,
            specializationConfig: strongConfig.specializations,
            initialSpecializationId: null,
          );
          final inv = Inventory(definitions: strongConfig.items);
          final coord = GameSessionCoordinator(
            repository: repo,
            config: strongConfig,
            nowMs: () => nowMs,
          );
          await coord.saveFromRuntime(
            character: char,
            inventory: inv,
            dungeon: const DungeonProgressSnapshot(
              currentDungeonId: 'forgotten_forest',
              clearsCount: 1,
              clearedInCycleRank: -1,
            ),
            dungeonProgresses: const {
              'forgotten_forest': DungeonProgressSnapshot(
                currentDungeonId: 'forgotten_forest',
                clearsCount: 1,
                clearedInCycleRank: -1,
              ),
            },
            cycleProgress: const CycleProgress(
              ascensionRank: 5,
              lastNormalDungeonId: 'forgotten_forest',
            ),
            rewardProcessor: RewardProcessor(
              character: char,
              inventory: inv,
              items: strongConfig.items,
              lootTables: strongConfig.lootTables,
              equipmentFactory: EquipmentFactory(strongConfig.equipment),
            ),
            autoSkillEnabled: false,
            lastOfflineClaimAtMs: nowMs,
          );
        });

        await _mountDungeonApp(
          tester,
          dbForest,
          strongConfig,
          screenKey: const ValueKey('stage4_forest_rank5'),
        );
        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.textContaining('Siklus Rank 5'), findsAtLeastNWidgets(1));

        await tester.tap(find.text('Masuk Forgotten Forest'));
        await tester.pump();
        await tester.pump();

        await _runGameUntilOverlay<DungeonCompletedOverlay>(tester);
        final forestGame = tester
            .widget<GameWidget<EchoesGame>>(find.byType(GameWidget<EchoesGame>))
            .game!;

        expect(
          forestGame
              .world
              .dungeonManager
              ?.activeDifficultyProfile
              .rareDropChanceMultiplier,
          closeTo(1.5, 1e-9),
        );
        expect(
          forestGame
              .world
              .dungeonManager
              ?.activeDifficultyProfile
              .equipmentRollBonus,
          closeTo(0.10, 1e-9),
        );
        expect(
          find.textContaining(
            '+${NumberFormatter.format(expectedForestClearExp)} EXP',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            '+${NumberFormatter.format(expectedForestClearGold)} Gold',
          ),
          findsOneWidget,
        );
        expect(forestGame.character.currentExp, expectedForestTotals.exp);
        expect(forestGame.character.gold, expectedForestTotals.gold);
      },
    );

    testWidgets(
      'Flame EchoesGame Online pada Rank 5 (Ascension Sanctum): profil Rank run terjaga saat Ascension tamat ke Rank 6',
      (tester) async {
        final strongConfig = _loadRealConfig(
          baseStatsOverride: const CombatStats(
            maxHp: 50000,
            atk: 50000,
            def: 10000,
            attackSpeed: 5.0,
            moveSpeed: 10.0,
            attackRange: 6.0,
          ),
          expBaseOverride: 100000000,
        );
        final dService = DifficultyService(strongConfig.difficulty);

        final dbAsc = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(dbAsc.close));
        await tester.runAsync(dbAsc.initialize);

        final asc = strongConfig.dungeons['ascension_sanctum']!;
        final rank5AscProfile = dService.profileFor(asc, 5);
        final expectedAscTotals = _analyticalDungeonTotals(
          strongConfig,
          asc,
          rank5AscProfile,
          dService,
        );
        final expectedAscClearExp = dService.scaleExp(
          asc.completionReward!.expReward,
          rank5AscProfile,
        );
        final expectedAscClearGold = dService.scaleGold(
          asc.completionReward!.goldReward,
          rank5AscProfile,
        );

        await tester.runAsync(() async {
          final repo = DriftPlayerSaveRepository(
            db: dbAsc,
            config: strongConfig,
          );
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final char = PlayerCharacter(
            config: strongConfig.progression,
            progress: const PlayerProgress(level: 269, currentExp: 0, gold: 0),
            skillCatalog: strongConfig.skills,
            specializationConfig: strongConfig.specializations,
            initialSpecializationId: null,
          );
          final inv = Inventory(definitions: strongConfig.items);
          final coord = GameSessionCoordinator(
            repository: repo,
            config: strongConfig,
            nowMs: () => nowMs,
          );
          final progresses = <String, DungeonProgressSnapshot>{
            for (final d in strongConfig.dungeons.values.where(
              (d) => d.isNormal,
            ))
              d.id: DungeonProgressSnapshot(
                currentDungeonId: d.id,
                clearsCount: 1,
                clearedInCycleRank: 5,
                highestClearedRoomIndex: 4,
              ),
          };
          await coord.saveFromRuntime(
            character: char,
            inventory: inv,
            dungeon: progresses['aether_sanctum']!,
            dungeonProgresses: progresses,
            cycleProgress: const CycleProgress(
              ascensionRank: 5,
              lastNormalDungeonId: 'aether_sanctum',
            ),
            rewardProcessor: RewardProcessor(
              character: char,
              inventory: inv,
              items: strongConfig.items,
              lootTables: strongConfig.lootTables,
              equipmentFactory: EquipmentFactory(strongConfig.equipment),
            ),
            autoSkillEnabled: false,
            lastOfflineClaimAtMs: nowMs,
          );
        });

        await _mountDungeonApp(
          tester,
          dbAsc,
          strongConfig,
          screenKey: const ValueKey('stage4_asc_rank5'),
        );
        await tester.ensureVisible(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
        );
        await tester.tap(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
        );
        await tester.pump();
        await tester.pump();

        await _runGameUntilOverlay<DungeonCompletedOverlay>(tester);
        final ascGame = tester
            .widget<GameWidget<EchoesGame>>(find.byType(GameWidget<EchoesGame>))
            .game!;

        expect(find.text('Ascension Rank 5 → Rank 6'), findsOneWidget);
        expect(
          find.textContaining(
            '+${NumberFormatter.format(expectedAscClearExp)} EXP',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            '+${NumberFormatter.format(expectedAscClearGold)} Gold',
          ),
          findsOneWidget,
        );
        expect(ascGame.character.currentExp, expectedAscTotals.exp);
        expect(ascGame.character.gold, expectedAscTotals.gold);

        // Semua equipment drop dari run Ascension Rank 5 tetap mematuhi bonus roll Rank 5 (+0.10), bukan Rank 6 (+0.12).
        for (final eq in ascGame.views.inventory.equipmentSnapshot()) {
          final base =
              strongConfig.items[eq.definitionId]!.equipment!.baseStats;
          if (base.atk > 0) {
            final ratio = eq.rolledStats.atk / base.atk;
            expect(
              ratio,
              inInclusiveRange(
                1.0 - 0.15 + 0.10 - 1e-9,
                1.0 + 0.15 + 0.10 + 1e-9,
              ),
            );
          } else if (base.hp > 0) {
            final ratio = eq.rolledStats.hp / base.hp;
            expect(
              ratio,
              inInclusiveRange(
                1.0 - 0.15 + 0.10 - 1e-9,
                1.0 + 0.15 + 0.10 + 1e-9,
              ),
            );
          }
        }
      },
    );
  });
}
