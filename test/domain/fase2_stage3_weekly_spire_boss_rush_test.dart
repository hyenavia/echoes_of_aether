import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/currency_config.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/infinite_spire.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/infinite_spire_service.dart';
import 'package:echoes_of_aether/domain/services/period_service.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const progression = ProgressionConfig(
    maxLevel: 90,
    expBase: 100,
    expGrowth: 2.0,
    baseStats: CombatStats(maxHp: 100, atk: 10, def: 5),
    perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
  );

  final spireConfig = InfiniteSpireConfig(
    totalFloors: 100,
    floors: [
      for (var f = 1; f <= 100; f++)
        InfiniteSpireFloorDefinition(
          floor: f,
          name: f % 10 == 0 ? 'Boss Floor $f' : 'Floor $f',
          recommendedLevel: f,
          isBossFloor: f % 10 == 0,
          bossName: f % 10 == 0 ? 'Spire Boss $f' : null,
        ),
    ],
  );

  final config = GameConfig(
    monsters: const {},
    revive: const ReviveConfig(),
    progression: progression,
    lootTables: const {},
    items: const {
      InfiniteSpireService.aetherScrapItemId: ItemDefinition(
        id: InfiniteSpireService.aetherScrapItemId,
        name: 'Aether Scrap',
        category: ItemCategory.material,
        maxStack: 9999,
      ),
    },
    dungeons: const {
      'forgotten_forest': DungeonDefinition(
        id: 'forgotten_forest',
        name: 'Forgotten Forest',
        biome: 'forest',
        startRoomId: 'forest_entrance',
        roomOrder: ['forest_entrance'],
        rooms: {
          'forest_entrance': RoomDefinition(
            id: 'forest_entrance',
            dungeonId: 'forgotten_forest',
            name: 'Forest Entrance',
            type: RoomType.normal,
            mapRef: 'ancient_heart_map',
            layout: ['###', '#.#', '###'],
            entryPosition: GridPoint(1, 1),
            exitPosition: GridPoint(1, 1),
            spawns: [],
            completionCondition: RoomCompletionCondition(),
          ),
        },
      ),
    },
    infiniteSpire: spireConfig,
  );

  final service = InfiniteSpireService(spireConfig);
  const periodService = PeriodService(timeZoneOffset: _utcOffset);

  group('Fase 2 Stage 3 — Weekly Spire Boss Rush', () {
    test('remains locked until highestFloorCleared >= 10', () {
      final nowMs = DateTime.utc(2026, 11, 23, 10).millisecondsSinceEpoch;
      final locked = service.resolveWeeklyBossRush(
        progress: const InfiniteSpireProgressSnapshot(highestFloorCleared: 9),
        periodService: periodService,
        nowMs: nowMs,
      );
      expect(locked.isUnlocked, isFalse);
      expect(locked.featuredFloor, isNull);
    });

    test('rotates among top 5 cleared boss floors across weeks and stays deterministic within the same week', () {
      final week1Ms = DateTime.utc(2026, 11, 23, 10).millisecondsSinceEpoch;
      final week1LaterMs = DateTime.utc(
        2026,
        11,
        25,
        14,
      ).millisecondsSinceEpoch;
      final week2Ms = DateTime.utc(2026, 11, 30, 10).millisecondsSinceEpoch;
      const progress = InfiniteSpireProgressSnapshot(highestFloorCleared: 100);

      final info1 = service.resolveWeeklyBossRush(
        progress: progress,
        periodService: periodService,
        nowMs: week1Ms,
      );
      final info1Later = service.resolveWeeklyBossRush(
        progress: progress,
        periodService: periodService,
        nowMs: week1LaterMs,
      );
      final info2 = service.resolveWeeklyBossRush(
        progress: progress,
        periodService: periodService,
        nowMs: week2Ms,
      );

      expect(info1.isUnlocked, isTrue);
      expect(info1.periodKey, info1Later.periodKey);
      expect(info1.featuredFloor!.floor, info1Later.featuredFloor!.floor);
      expect(info1.featuredFloor!.floor, greaterThanOrEqualTo(60));
      expect(info2.periodKey, isNot(info1.periodKey));
      expect(info2.featuredFloor!.floor, isNot(info1.featuredFloor!.floor));
    });

    test('trySettleWeeklyBossRush grants reward once per week and resets on next week', () {
      final week1Ms = DateTime.utc(2026, 11, 23, 10).millisecondsSinceEpoch;
      final week2Ms = DateTime.utc(2026, 11, 30, 10).millisecondsSinceEpoch;
      const progress = InfiniteSpireProgressSnapshot(
        highestFloorCleared: 30,
        claimedFloorRewards: {10, 20, 30},
      );
      final infoWeek1 = service.resolveWeeklyBossRush(
        progress: progress,
        periodService: periodService,
        nowMs: week1Ms,
      );
      final targetFloor = infoWeek1.featuredFloor!.floor;

      final char = PlayerCharacter(config: progression);
      final inv = Inventory(definitions: config.items);
      final currency = CurrencyService(
        definitions: CurrencyDefinition.defaults,
      );
      final claimed = <String>{};

      // 1. Klaim pertama minggu ini berhasil
      final first = service.trySettleWeeklyBossRush(
        floorNumber: targetFloor,
        character: char,
        inventory: inv,
        currencyService: currency,
        progress: progress,
        periodService: periodService,
        nowMs: week1Ms,
        claimedEventIds: claimed,
      );
      expect(first, isNotNull);
      expect(first!.claimed, isTrue);
      expect(char.gold, first.reward.gold);
      expect(
        inv.quantityOf(InfiniteSpireService.aetherScrapItemId),
        first.reward.items[InfiniteSpireService.aetherScrapItemId],
      );
      expect(
        currency.balance(InfiniteSpireService.aetherShardCurrencyId),
        first.reward.currencies[InfiniteSpireService.aetherShardCurrencyId],
      );
      claimed.add(first.claimId);

      // 2. Klaim kedua di minggu yang sama -> null (idempoten)
      final duplicate = service.trySettleWeeklyBossRush(
        floorNumber: targetFloor,
        character: char,
        inventory: inv,
        currencyService: currency,
        progress: progress,
        periodService: periodService,
        nowMs: week1Ms,
        claimedEventIds: claimed,
      );
      expect(duplicate, isNull);

      // 3. Minggu berikutnya -> terbuka lagi untuk lantai unggulan minggu 2
      final infoWeek2 = service.resolveWeeklyBossRush(
        progress: progress,
        periodService: periodService,
        nowMs: week2Ms,
        claimedEventIds: claimed,
      );
      expect(infoWeek2.isCompletedThisWeek, isFalse);
      final nextWeek = service.trySettleWeeklyBossRush(
        floorNumber: infoWeek2.featuredFloor!.floor,
        character: char,
        inventory: inv,
        currencyService: currency,
        progress: progress,
        periodService: periodService,
        nowMs: week2Ms,
        claimedEventIds: claimed,
      );
      expect(nextWeek, isNotNull);
      expect(nextWeek!.claimed, isTrue);
    });

    test('GameSessionCoordinator.settleInfiniteSpireVictory persists weekly claim across DB reload', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftPlayerSaveRepository(db: db, config: config);
      final fixedNowMs = DateTime.utc(2026, 11, 23, 10).millisecondsSinceEpoch;
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => fixedNowMs,
      );

      const progress = InfiniteSpireProgressSnapshot(
        highestFloorCleared: 20,
        claimedFloorRewards: {10, 20},
      );
      final info = service.resolveWeeklyBossRush(
        progress: progress,
        periodService: const PeriodService(),
        nowMs: fixedNowMs,
      );
      final featuredFloor = info.featuredFloor!.floor;

      final char = PlayerCharacter(config: progression);
      final inv = Inventory(definitions: config.items);
      final currency = CurrencyService(
        definitions: CurrencyDefinition.defaults,
      );
      final rewardProcessor = RewardProcessor(
        character: char,
        inventory: inv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      final first = await coordinator.settleInfiniteSpireVictory(
        floorNumber: featuredFloor,
        character: char,
        inventory: inv,
        dungeon: const DungeonProgressSnapshot(),
        dungeonProgresses: const {},
        cycleProgress: const CycleProgress(),
        rewardProcessor: rewardProcessor,
        currencyService: currency,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: fixedNowMs,
        infiniteSpireProgress: progress,
      );
      expect(first.weeklyBonusClaimed, isTrue);
      expect(first.weeklyBonusClaimId, info.claimId);

      // Reload dari Drift SQLite: klaim mingguan tersimpan, menang lagi tidak menggandakan hadiah
      final reloaded = await repo.loadSnapshot();
      expect(reloaded, isNotNull);
      expect(reloaded!.claimedEventIds, contains(info.claimId));

      final rewardProcessor2 = RewardProcessor(
        character: char,
        inventory: inv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
        claimedEventIds: reloaded.claimedEventIds,
      );
      final second = await coordinator.settleInfiniteSpireVictory(
        floorNumber: featuredFloor,
        character: char,
        inventory: inv,
        dungeon: reloaded.dungeon,
        dungeonProgresses: reloaded.dungeonProgresses,
        cycleProgress: reloaded.cycleProgress,
        rewardProcessor: rewardProcessor2,
        currencyService: currency,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: fixedNowMs,
        infiniteSpireProgress: reloaded.infiniteSpireProgress,
      );
      expect(second.weeklyBonusClaimed, isFalse);
    });
  });
}

Duration _utcOffset() => Duration.zero;
