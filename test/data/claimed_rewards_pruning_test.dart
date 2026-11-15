import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide ClockState;
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/clock_state.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/time_config.dart';
import 'package:echoes_of_aether/domain/services/ascension_service.dart';
import 'package:echoes_of_aether/domain/services/game_clock.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedClock implements GameClock {
  const _FixedClock(this.nowMs);
  @override
  final int nowMs;
}

GameConfig _pruningTestConfig() {
  const layout = <String>['#####', '#...#', '#####'];
  return GameConfig(
    monsters: const {
      'slime': EnemyDefinition(
        id: 'slime',
        name: 'Slime',
        level: 1,
        stats: CombatStats(maxHp: 30, atk: 5, def: 1),
        expReward: 10,
        goldReward: 5,
      ),
    },
    revive: const ReviveConfig(),
    progression: const ProgressionConfig(
      baseStats: CombatStats(maxHp: 100, atk: 12, def: 2),
      perLevel: LevelGrowth(hp: 15, atk: 2, def: 0.5),
    ),
    items: const {},
    lootTables: const {},
    claimedRewards: const ClaimedRewardsConfig(retentionDays: 14),
    dungeons: {
      'forgotten_forest': const DungeonDefinition(
        id: 'forgotten_forest',
        name: 'Forgotten Forest',
        biome: 'forest',
        kind: DungeonKind.normal,
        order: 1,
        recommendedLevel: 1,
        startRoomId: 'r1',
        roomOrder: ['r1'],
        completionReward: DungeonCompletionReward(
          expReward: 20,
          goldReward: 10,
        ),
        rooms: {
          'r1': RoomDefinition(
            id: 'r1',
            dungeonId: 'forgotten_forest',
            name: 'Entrance',
            type: RoomType.normal,
            mapRef: 'r1',
            layout: layout,
            entryPosition: GridPoint(1, 1),
            exitPosition: GridPoint(3, 1),
            completionCondition: RoomCompletionCondition(
              type: RoomCompletionConditionType.reachExit,
            ),
            spawns: [],
          ),
        },
      ),
    },
  );
}

void main() {
  group('ClaimedRewards Pruning', () {
    test(
      'tidak menghapus ID run aktif, ascension, shop, atau periode berjalan; '
      'dan tidak ada reward ganda lintas skenario',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final config = _pruningTestConfig();
        const nowMs = 1_795_000_000_000;
        const oldMs = nowMs - 20 * Duration.millisecondsPerDay;
        const recentMs = nowMs - 2 * Duration.millisecondsPerDay;

        final repo = DriftPlayerSaveRepository(
          db: db,
          config: config,
          clock: const _FixedClock(oldMs),
        );

        // 1. Siapkan snapshot dengan run aktif `run_active`, ascension, shop,
        //    serta data lama (>14 hari).
        await repo.saveSnapshot(
          PlayerSaveSnapshot(
            character: const PlayerCharacterSnapshot(
              progress: PlayerProgress(level: 10, gold: 500),
            ),
            inventory: const InventorySnapshot(),
            cycleProgress: const CycleProgress(
              ascensionRank: 1,
              highestAscensionRank: 1,
              lastNormalDungeonId: 'forgotten_forest',
            ),
            session: const GameSessionSnapshot(
              lastActiveAtMs: oldMs,
              lastSavedAtMs: oldMs,
              lastOfflineClaimAtMs: oldMs,
            ),
            activeDungeonSession: const ActiveDungeonSessionSnapshot(
              runId: 'run_active',
              dungeonId: 'forgotten_forest',
              currentRoomId: 'r1',
              currentRoomIndex: 0,
              status: DungeonSessionStatus.inProgress,
              clearedRoomIds: {},
            ),
            claimedEventIds: const {
              // Run selesai lama (boleh dipangkas)
              'offline_kill:run_old:enemy_1',
              'room_clear:run_old:r1',
              'dungeon_clear:run_old',
              'offline:1000:2000',
              // Run aktif yang masih bisa dipulihkan (TIDAK boleh dipangkas)
              'offline_kill:run_active:enemy_1',
              'room_clear:run_active:r1',
              // Permanen (TIDAK boleh dipangkas)
              'ascension:run_asc_1',
              'shop:buy_old_1',
              // Periode berjalan (TIDAK boleh dipangkas)
              'bossquest:daily_boss:2026-11-15',
              'eventshop:evt_1:2026-11-09',
              // Periode lama (boleh dipangkas)
              'bossquest:daily_boss:2026-10-01',
            },
            clockState: const ClockState(lastSeenAtMs: oldMs),
          ),
        );

        // Tambah satu ID baru (< 14 hari) untuk memastikan yang baru tidak disentuh.
        await db
            .into(db.claimedRewards)
            .insert(
              ClaimedRewardsCompanion.insert(
                playerId: GameSessionSnapshot.defaultPlayerId,
                eventId: 'offline_kill:run_recent:enemy_1',
                claimedAtMs: recentMs,
              ),
            );

        final deleted = await repo.pruneClaimedRewards(
          cutoffMs: nowMs - config.claimedRewards.retentionMs,
          activeRunId: 'run_active',
          activePeriodKeys: const {'2026-11-15', '2026-11-09'},
        );
        expect(deleted, 5);

        final remainingRows = await db.select(db.claimedRewards).get();
        final remainingIds = remainingRows.map((r) => r.eventId).toSet();
        expect(
          remainingIds,
          equals({
            'offline_kill:run_active:enemy_1',
            'room_clear:run_active:r1',
            'ascension:run_asc_1',
            'shop:buy_old_1',
            'bossquest:daily_boss:2026-11-15',
            'eventshop:evt_1:2026-11-09',
            'offline_kill:run_recent:enemy_1',
          }),
        );

        // Skenario 1: Recovery sesi run aktif -> ID masih ada, tidak double-claim.
        final loadedAfterPrune = await repo.loadSnapshot();
        expect(
          loadedAfterPrune!.claimedEventIds,
          containsAll([
            'offline_kill:run_active:enemy_1',
            'room_clear:run_active:r1',
          ]),
        );

        // Skenario 2: Masuk ulang offline pada waktu yang sama -> status zeroElapsed
        // atau alreadyClaimed (tidak ada reward offline ganda).
        final coordinator = GameSessionCoordinator(
          repository: repo,
          config: config,
          clock: const _FixedClock(oldMs),
        );
        final resumed = await coordinator.loadAndProcessOffline();
        expect(resumed.offlineResult.expGained, 0);
        expect(resumed.offlineResult.goldGained, 0);

        // Skenario 3: Ascension dua kali setelah pemangkasan -> tetap ditolak.
        const ascensionService = AscensionService();
        final character = PlayerCharacter(config: config.progression);
        final rewardProcessor = RewardProcessor(
          character: character,
          inventory: resumed.inventory,
          items: config.items,
          lootTables: config.lootTables,
          equipmentFactory: resumed.rewardProcessor.equipmentFactory,
          claimedEventIds: loadedAfterPrune.claimedEventIds,
        );
        final ascResult = ascensionService.complete(
          runId: 'run_asc_1',
          cycleProgress: loadedAfterPrune.cycleProgress,
          dungeonProgresses: loadedAfterPrune.dungeonProgresses,
          dungeons: config.dungeons.values,
          rewardProcessor: rewardProcessor,
        );
        expect(ascResult.alreadyCompleted, isTrue);
        expect(ascResult.cycleProgress.ascensionRank, 1);

        // Skenario 4: Pembelian shop ulang dengan actionId yang sama -> idempoten.
        await repo.saveShopTransaction(
          progress: const PlayerProgress(level: 10, gold: 400),
          inventory: const InventorySnapshot(),
          equipped: const {},
          shopPurchases: const {'shop_rusty_sword': 1},
          actionId: 'buy_old_1',
          updatedAtMs: nowMs,
        );
        final afterDupShop = await repo.loadSnapshot();
        // Gold tetap 500 karena claimKey 'shop:buy_old_1' masih ada!
        expect(afterDupShop!.character.progress.gold, 500);
      },
    );

    test('mengukur pemangkasan pada 100.000 baris ClaimedRewards', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final config = _pruningTestConfig();
      const nowMs = 1_795_000_000_000;
      const oldMs = nowMs - 30 * Duration.millisecondsPerDay;

      final repo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: const _FixedClock(oldMs),
      );
      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          character: const PlayerCharacterSnapshot(
            progress: PlayerProgress(level: 10),
          ),
          inventory: const InventorySnapshot(),
          session: const GameSessionSnapshot(
            lastActiveAtMs: oldMs,
            lastSavedAtMs: oldMs,
            lastOfflineClaimAtMs: oldMs,
          ),
          claimedEventIds: const {
            'ascension:run_keep',
            'shop:buy_keep',
            'offline_kill:run_active:e0',
          },
        ),
      );

      const totalOldKills = 100000;
      const chunkSize = 2000;
      for (var start = 0; start < totalOldKills; start += chunkSize) {
        final end = start + chunkSize;
        await db.batch((b) {
          b.insertAll(db.claimedRewards, [
            for (var i = start; i < end; i++)
              ClaimedRewardsCompanion.insert(
                playerId: GameSessionSnapshot.defaultPlayerId,
                eventId: 'offline_kill:run_old_$i:e1',
                claimedAtMs: oldMs,
              ),
          ]);
        });
      }

      final beforeCount = (await db.select(db.claimedRewards).get()).length;
      expect(beforeCount, 100003);

      final deleted = await repo.pruneClaimedRewards(
        cutoffMs: nowMs - config.claimedRewards.retentionMs,
        activeRunId: 'run_active',
        activePeriodKeys: const {'2026-11-15'},
      );
      expect(deleted, 100000);

      final afterRows = await db.select(db.claimedRewards).get();
      expect(afterRows.length, 3);
    });
  });
}
