import 'dart:io';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/infinite_spire_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/infinite_spire.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/repositories/player_progress_repository.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/infinite_spire_service.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);

  return GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    time: parser.parseTime(settings),
    currencies: parser.parseCurrencies(settings),
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
    heroAscension: parser.parseHeroAscension(settings),
    infiniteSpire: const InfiniteSpireConfigParser().parse(
      _readAsset('infinite_spire.json'),
    ),
  );
}

class _FailingInfiniteSpireRepository implements PlayerSaveRepository {
  @override
  Future<PlayerSaveSnapshot?> loadSnapshot() async => null;

  @override
  Future<void> saveSnapshot(PlayerSaveSnapshot snapshot) async {
    throw StateError(
      'Simulated persistence failure during Infinite Spire settlement',
    );
  }
}

void main() {
  late GameConfig config;
  late InfiniteSpireService spireService;
  final arenaLayout = [
    '########################',
    '#......................#',
    '#......................#',
    '#......................#',
    '#......................#',
    '#......................#',
    '#......................#',
    '#......................#',
    '#......................#',
    '#......................#',
    '#......................#',
    '#......................#',
    '########################',
  ];

  setUpAll(() {
    config = _loadRealConfig();
    expect(config.infiniteSpire, isNotNull);
    spireService = InfiniteSpireService(config.infiniteSpire!);
  });

  group('M16 Stage 4 — Structure & Floor Navigation (1..100 Floors)', () {
    test('100 lantai terdefinisi lengkap dan valid tanpa celah', () {
      final spire = config.infiniteSpire!;
      expect(spire.totalFloors, 100);
      expect(spire.floors, hasLength(100));

      for (var f = 1; f <= 100; f++) {
        final floor = spire.floor(f);
        expect(floor, isNotNull, reason: 'Lantai $f harus ada.');
        expect(floor!.floor, f);
        expect(floor.recommendedLevel, inInclusiveRange(20, 90));
        expect(floor.enemyIds, isNotEmpty);

        if (f % 10 == 0) {
          expect(
            floor.isBossFloor,
            isTrue,
            reason: 'Lantai $f adalah boss floor.',
          );
          expect(floor.bossId, isNotNull);
          expect(floor.bossName, isNotNull);
          expect(floor.affixDescription, isNotNull);
          expect(config.monsters.containsKey(floor.bossId), isTrue);
        } else {
          expect(floor.isBossFloor, isFalse);
        }
      }
    });

    test(
      'canChallengeFloor menegakkan progresi sekuensial dan akses latihan',
      () {
        // Progres awal: Lantai 0 clear
        const freshProgress = InfiniteSpireProgressSnapshot();
        expect(spireService.canChallengeFloor(1, freshProgress), isTrue);
        expect(spireService.canChallengeFloor(2, freshProgress), isFalse);
        expect(spireService.canChallengeFloor(10, freshProgress), isFalse);
        expect(spireService.canChallengeFloor(0, freshProgress), isFalse);
        expect(spireService.canChallengeFloor(101, freshProgress), isFalse);

        // Setelah Lantai 5 clear
        const midProgress = InfiniteSpireProgressSnapshot(
          highestFloorCleared: 5,
          claimedFloorRewards: {1, 2, 3, 4, 5},
        );
        // Lantai 1..5 bisa dimainkan kembali (latihan/tantangan)
        for (var f = 1; f <= 5; f++) {
          expect(spireService.canChallengeFloor(f, midProgress), isTrue);
        }
        // Lantai 6 terbuka untuk ditantang
        expect(spireService.canChallengeFloor(6, midProgress), isTrue);
        // Lantai 7 masih terkunci
        expect(spireService.canChallengeFloor(7, midProgress), isFalse);
      },
    );
  });

  group('M16 Stage 4 — Runtime Arena Generation (buildFloorDungeon)', () {
    test('Normal floor membangun arena 1 ruangan dengan musuh regular dan condition defeatRequiredEnemies', () {
      final dungeon = spireService.buildFloorDungeon(
        floorNumber: 1,
        arenaLayout: arenaLayout,
      );

      expect(dungeon.id, 'infinite_spire_f1');
      expect(dungeon.kind, DungeonKind.infiniteSpire);
      expect(dungeon.order, 1);
      expect(dungeon.recommendedLevel, 20);
      expect(dungeon.roomOrder, hasLength(1));

      final room = dungeon.rooms[dungeon.startRoomId]!;
      expect(room.type, RoomType.normal);
      expect(
        room.completionCondition.type,
        RoomCompletionConditionType.defeatRequiredEnemies,
      );
      expect(room.spawns, isNotEmpty);
      expect(room.spawns.any((s) => s.isBoss), isFalse);
    });

    test('Boss floor membangun arena dengan boss utama di (17, 6), minion pendamping, dan condition defeatBoss', () {
      final dungeon = spireService.buildFloorDungeon(
        floorNumber: 10,
        arenaLayout: arenaLayout,
      );

      expect(dungeon.id, 'infinite_spire_f10');
      expect(dungeon.kind, DungeonKind.infiniteSpire);
      expect(dungeon.order, 10);
      expect(dungeon.recommendedLevel, 26);

      final room = dungeon.rooms[dungeon.startRoomId]!;
      expect(room.type, RoomType.boss);
      expect(
        room.completionCondition.type,
        RoomCompletionConditionType.defeatBoss,
      );

      final bossSpawn = room.spawns.firstWhere((s) => s.isBoss);
      expect(bossSpawn.monsterId, 'corrupted_guardian');
      expect(bossSpawn.position, const GridPoint(17, 6));
      expect(bossSpawn.required, isTrue);

      // Minion pendamping
      final minionSpawns = room.spawns.where((s) => !s.isBoss).toList();
      expect(minionSpawns, isNotEmpty);
    });

    test('Lantai 100 menggunakan biome abyssal_rift dan bos puncak', () {
      final dungeon = spireService.buildFloorDungeon(
        floorNumber: 100,
        arenaLayout: arenaLayout,
      );
      expect(dungeon.biome, 'abyssal_rift');
      expect(dungeon.order, 100);
      expect(dungeon.recommendedLevel, 90);
    });

    test('Parameter tidak valid melempar ArgumentError', () {
      expect(
        () => spireService.buildFloorDungeon(
          floorNumber: 0,
          arenaLayout: arenaLayout,
        ),
        throwsArgumentError,
      );
      expect(
        () => spireService.buildFloorDungeon(
          floorNumber: 101,
          arenaLayout: arenaLayout,
        ),
        throwsArgumentError,
      );
      expect(
        () => spireService.buildFloorDungeon(
          floorNumber: 1,
          arenaLayout: const [],
        ),
        throwsArgumentError,
      );
    });
  });

  group('M16 Stage 4 — Atomic & Idempotent First-Clear Rewards (settleFloorVictory)', () {
    test('Kemenangan first-clear memberikan exp, gold, item, currency, dan menaikkan progres', () {
      final character = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 25, gold: 1000),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final inventory = Inventory(definitions: config.items);
      final currencyService = CurrencyService(definitions: config.currencies);

      const initialProgress = InfiniteSpireProgressSnapshot();

      // Lantai 10 reward: 600 EXP, 1500 Gold, 4 aether_scrap, 1 boss_remnant, 25 aether_shard, 1 soul_prism
      final result = spireService.settleFloorVictory(
        floorNumber: 10,
        character: character,
        inventory: inventory,
        currencyService: currencyService,
        progress: initialProgress,
      );

      expect(result.isFirstClear, isTrue);
      expect(result.floor, 10);
      expect(result.claimId, 'infinite_spire_floor_10');

      // Progres diperbarui
      expect(result.updatedProgress.highestFloorCleared, 10);
      expect(result.updatedProgress.isFloorCleared(10), isTrue);
      expect(result.updatedProgress.isRewardClaimed(10), isTrue);

      // Gold & EXP
      expect(character.gold, 1000 + 1500);
      expect(character.currentExp, 600);

      // Items
      expect(inventory.quantityOf('aether_scrap'), 4);
      expect(inventory.quantityOf('boss_remnant'), 1);

      // Currencies
      expect(currencyService.balance('aether_shard'), 25);
      expect(currencyService.balance('soul_prism'), 1);
    });

    test('Kemenangan kedua kali pada lantai yang sama bersifat idempoten (hadiah tidak dobel)', () {
      final character = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 25, currentExp: 600, gold: 2500),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final inventory = Inventory(definitions: config.items);
      inventory.add('aether_scrap', 4);
      inventory.add('boss_remnant', 1);

      final currencyService = CurrencyService(
        definitions: config.currencies,
        initialBalances: {'aether_shard': 25, 'soul_prism': 1},
        claimedIds: {'infinite_spire_floor_10'},
      );

      const alreadyClearedProgress = InfiniteSpireProgressSnapshot(
        highestFloorCleared: 10,
        claimedFloorRewards: {10},
      );

      final result = spireService.settleFloorVictory(
        floorNumber: 10,
        character: character,
        inventory: inventory,
        currencyService: currencyService,
        progress: alreadyClearedProgress,
      );

      expect(result.isFirstClear, isFalse);
      expect(result.userMessage, contains('telah diselesaikan'));

      // Nilai tidak berubah sama sekali
      expect(character.gold, 2500);
      expect(character.currentExp, 600);
      expect(inventory.quantityOf('aether_scrap'), 4);
      expect(inventory.quantityOf('boss_remnant'), 1);
      expect(currencyService.balance('aether_shard'), 25);
      expect(currencyService.balance('soul_prism'), 1);

      // Progres tetap
      expect(result.updatedProgress.highestFloorCleared, 10);
      expect(result.updatedProgress.claimedFloorRewards, {10});
    });
  });

  group('M16 Stage 4 — Coordinator Integration & Rollback Safety', () {
    test('settleInfiniteSpireVictory rollback secara bersih jika terjadi error persistensi', () async {
      final failingRepo = _FailingInfiniteSpireRepository();
      final coordinator = GameSessionCoordinator(
        repository: failingRepo,
        config: config,
      );

      final character = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 30, gold: 5000),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final inventory = Inventory(definitions: config.items);
      final currencyService = CurrencyService(definitions: config.currencies);
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      await expectLater(
        coordinator.settleInfiniteSpireVictory(
          floorNumber: 1,
          character: character,
          inventory: inventory,
          dungeon: const DungeonProgressSnapshot(),
          dungeonProgresses: const {},
          cycleProgress: const CycleProgress(),
          rewardProcessor: rewardProcessor,
          currencyService: currencyService,
          autoSkillEnabled: true,
          lastOfflineClaimAtMs: 1000000,
          infiniteSpireProgress: const InfiniteSpireProgressSnapshot(),
        ),
        throwsA(isA<StateError>()),
      );

      // State harus kembali persis seperti semula (rollback berhasil)
      expect(character.gold, 5000);
      expect(character.currentExp, 0);
      expect(inventory.quantityOf('aether_scrap'), 0);
      expect(currencyService.balance('aether_shard'), 0);
      expect(rewardProcessor.isClaimed('infinite_spire_floor_1'), isFalse);
    });

    test('settleInfiniteSpireVictory sukses menyimpan ke Drift SQLite dan data persisten saat reload', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final repo = DriftPlayerSaveRepository(db: db, config: config);
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: config,
      );

      final character = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 40, gold: 10000),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final inventory = Inventory(definitions: config.items);
      final currencyService = CurrencyService(definitions: config.currencies);
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      // Jalankan kemenangan lantai 10
      final result = await coordinator.settleInfiniteSpireVictory(
        floorNumber: 10,
        character: character,
        inventory: inventory,
        dungeon: const DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
        ),
        dungeonProgresses: const {},
        cycleProgress: const CycleProgress(),
        rewardProcessor: rewardProcessor,
        currencyService: currencyService,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: 1000000,
        infiniteSpireProgress: const InfiniteSpireProgressSnapshot(),
      );

      expect(result.isFirstClear, isTrue);
      expect(rewardProcessor.isClaimed('infinite_spire_floor_10'), isTrue);

      // Reload snapshot dari SQLite
      final reloaded = await repo.loadSnapshot();
      expect(reloaded, isNotNull);
      expect(reloaded!.infiniteSpireProgress.highestFloorCleared, 10);
      expect(reloaded.infiniteSpireProgress.isFloorCleared(10), isTrue);
      expect(reloaded.infiniteSpireProgress.isRewardClaimed(10), isTrue);
      expect(reloaded.character.progress.gold, 10000 + 1500);
      expect(reloaded.currencies['aether_shard'], 25);
      expect(reloaded.currencies['soul_prism'], 1);
    });
  });

  group('M16 Stage 4 — Offline Farming Guard (Spire Independence)', () {
    test('OfflineDungeonRunner menolak Auto Farming dan Continue Dungeon pada Infinite Spire', () {
      const runner = OfflineDungeonRunner();
      final factory = EquipmentFactory(config.equipment);
      final character = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 50),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final inventory = Inventory(definitions: config.items);
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: factory,
      );

      final spireDungeon = spireService.buildFloorDungeon(
        floorNumber: 10,
        arenaLayout: arenaLayout,
      );

      final extendedConfig = GameConfig(
        monsters: config.monsters,
        damage: config.damage,
        difficulty: config.difficulty,
        farming: config.farming,
        revive: config.revive,
        progression: config.progression,
        equipment: config.equipment,
        dungeonCompletion: config.dungeonCompletion,
        time: config.time,
        currencies: config.currencies,
        skills: config.skills,
        specializations: config.specializations,
        items: config.items,
        lootTables: config.lootTables,
        dungeons: {...config.dungeons, spireDungeon.id: spireDungeon},
        heroAscension: config.heroAscension,
        infiniteSpire: config.infiniteSpire,
      );

      final timeWindow = const OfflineTimeCalculator().calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(hours: 1).inMilliseconds,
      );

      // 1. Auto Farming ditolak
      final autoFarmOutcome = runner.runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.autoFarming,
          character: character,
          inventory: inventory,
          config: extendedConfig,
          rewardProcessor: rewardProcessor,
          dungeonId: spireDungeon.id,
          dungeonProgress: const DungeonProgressSnapshot(),
          timeWindow: timeWindow,
          simulationSeed: 42,
        ),
      );

      expect(autoFarmOutcome.stopReason, OfflineDungeonStopReason.invalidSetup);
      expect(
        autoFarmOutcome.failureReason,
        contains('Auto Farming menolak Boss Event / Spire'),
      );

      // 2. OfflineProgressionService juga menolak target dungeon infiniteSpire
      const offlineService = OfflineProgressionService();
      final progResult = offlineService.process(
        character: character,
        inventory: inventory,
        config: extendedConfig,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(hours: 1).inMilliseconds,
        offlineActivity: OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.pending,
          selectedDungeonId: spireDungeon.id,
        ),
        dungeonProgress: const DungeonProgressSnapshot(),
        rewardProcessor: rewardProcessor,
        claimedEventIds: {},
      );

      expect(progResult.status, OfflineProgressionStatus.noEligibleEncounter);
      expect(
        progResult.failureReason,
        contains('Auto Farming ditolak: Boss Event / Spire'),
      );
    });

    test('lantai bos Infinite Spire (Lantai 10 corrupted_guardian) berhasil spawn dan menyelesaikan dungeon saat bos dikalahkan', () {
      final layout = InfiniteSpireService.resolveArenaLayout(config)!;
      final floor10 = spireService.buildFloorDungeon(
        floorNumber: 10,
        arenaLayout: layout,
      );
      final tracker = EncounterTracker(monsterCatalog: config.monsters);
      final manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: tracker,
      );

      manager.startRuntimeDungeon(floor10, cycleRank: 0);
      final room = manager.activeRoom!;
      final grid = room.createNavigationGrid();
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: const CombatStats(
          maxHp: 1000,
          atk: 200,
          def: 20,
          attackSpeed: 2,
          moveSpeed: 5,
          attackRange: 1.5,
        ),
        cell: room.entryPosition,
      );
      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
        seed: 1,
      );

      manager.activateRoom();
      final spawned = tracker.onRoomActivated(sim, grid: grid);
      final bossRecord = spawned
          .where((e) => e.monsterId == 'corrupted_guardian')
          .toList();
      expect(bossRecord, hasLength(1));
      expect(tracker.primaryBossEncounter?.isFailed, isFalse);
      expect(
        sim.enemies.any((e) => e.id == bossRecord.first.enemyId && e.isBoss),
        isTrue,
      );

      // Kalahkan bos Lantai 10 (meski minion masih ada) -> room & dungeon selesai.
      tracker.onEnemyDefeated(
        bossRecord.first.enemyId,
        simulation: sim,
        grid: grid,
      );
      final eval = manager.evaluateCurrentRoom(playerCell: room.entryPosition);
      expect(eval.isCompleted, isTrue);
      expect(
        manager.tryCompleteActiveRoom(playerCell: room.entryPosition),
        isTrue,
      );
      expect(manager.session?.isTerminal, isTrue);
    });
  });
}
