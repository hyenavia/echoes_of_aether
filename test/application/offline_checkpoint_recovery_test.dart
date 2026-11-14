import 'dart:io';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/providers/database_provider.dart';
import 'package:echoes_of_aether/application/providers/game_config_provider.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
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
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealGameConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final baseProg = parser.parseProgression(settings);
  final config = GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    revive: parser.parseRevive(settings),
    progression: ProgressionConfig(
      maxLevel: 30,
      expBase: 50,
      expGrowth: 1.4,
      baseStats: baseProg.baseStats,
      perLevel: baseProg.perLevel,
    ),
    equipment: parser.parseEquipment(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(_readAsset('dungeons.json')),
  );
  const GameConfigValidator().validate(config);
  return config;
}

Future<void> _flushAsyncDb() async {
  await Future<void>.delayed(const Duration(milliseconds: 60));
}

void main() {
  group('M6 Stage 2 — Checkpoint, Recovery, Concurrency & Lifecycle Resume', () {
    test('Mode B multi-batch checkpoint + crash recovery menuntaskan sisa waktu tanpa duplicate reward', () async {
      final config = _loadRealGameConfig();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final repo = DriftPlayerSaveRepository(db: db, config: config);
      var clockMs = 1000000;

      // Setup karakter level 5 yang sudah pernah menamatkan Forgotten Forest (clearsCount = 1).
      final setupCoord = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => clockMs,
      );
      final char = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 5, currentExp: 0, gold: 100),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      )..chooseSpecialization('vanguard');
      final inv = Inventory(definitions: config.items);
      final rp = RewardProcessor(
        character: char,
        inventory: inv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      await setupCoord.saveFromRuntime(
        character: char,
        inventory: inv,
        dungeon: const DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          clearsCount: 1,
          clearedInCycleRank: 0,
          highestClearedRoomIndex: 4,
        ),
        rewardProcessor: rp,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: clockMs,
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.configured,
          selectedDungeonId: 'forgotten_forest',
          simulationSeed: 2026,
        ),
      );

      // Pemain kembali setelah 30 menit, namun koordinat crash setelah batch pertama (maxBatches: 1).
      clockMs += const Duration(minutes: 30).inMilliseconds;
      final coordBeforeCrash = GameSessionCoordinator(
        repository: repo,
        config: config,
        checkpointIterationsPerBatch: 120,
        nowMs: () => clockMs,
      );
      final interruptedBoot = await coordBeforeCrash.loadAndProcessOffline(
        maxBatches: 1,
      );

      expect(
        interruptedBoot.offlineResult.status,
        OfflineProgressionStatus.interrupted,
      );
      expect(
        interruptedBoot.offlineActivity.state,
        OfflineActivityState.interrupted,
      );
      expect(
        interruptedBoot.offlineActivity.processedOfflineDurationMs,
        greaterThan(0),
      );
      expect(
        interruptedBoot.offlineActivity.lastCheckpointAtMs,
        greaterThan(1000000),
      );
      expect(
        interruptedBoot.claimedEventIds.any(
          (id) => id.startsWith('offline_kill:'),
        ),
        isTrue,
      );

      // Boot ulang aplikasi (fresh coordinator) di timestamp yang sama -> melanjutkan dari checkpoint.
      final recoveredCoord = GameSessionCoordinator(
        repository: DriftPlayerSaveRepository(db: db, config: config),
        config: config,
        checkpointIterationsPerBatch: 120,
        nowMs: () => clockMs,
      );
      final recoveredBoot = await recoveredCoord.loadAndProcessOffline();

      expect(
        recoveredBoot.offlineResult.status,
        OfflineProgressionStatus.applied,
      );
      expect(
        recoveredBoot.offlineActivity.state,
        OfflineActivityState.completed,
      );
      expect(recoveredBoot.offlineActivity.pendingSummary, isNotNull);
      expect(
        recoveredBoot.offlineActivity.pendingSummary!.finalState,
        OfflineActivityState.completed,
      );
      expect(
        recoveredBoot.offlineActivity.processedOfflineDurationMs,
        const Duration(minutes: 30).inMilliseconds,
      );
      expect(recoveredBoot.dungeon.clearsCount, greaterThan(1));
      expect(recoveredBoot.character.gold, greaterThan(100));

      // Replay segera tidak memberi reward ganda.
      final goldAfterRecovery = recoveredBoot.character.gold;
      final clearsAfterRecovery = recoveredBoot.dungeon.clearsCount;
      final replay = await recoveredCoord.loadAndProcessOffline();
      expect(
        replay.offlineResult.status,
        OfflineProgressionStatus.alreadyClaimed,
      );
      expect(replay.character.gold, goldAfterRecovery);
      expect(replay.dungeon.clearsCount, clearsAfterRecovery);
    });

    test('Mode A multi-batch interruption menjaga activeRunId yang sama dan tidak menduplikasi kill', () async {
      final config = _loadRealGameConfig();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final repo = DriftPlayerSaveRepository(db: db, config: config);
      var clockMs = 1000000;
      final setupCoord = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => clockMs,
      );

      final char = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 5),
      );
      final inv = Inventory(definitions: config.items);
      final rp = RewardProcessor(
        character: char,
        inventory: inv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      await setupCoord.saveFromRuntime(
        character: char,
        inventory: inv,
        dungeon: const DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          currentRoomId: 'forest_entrance',
          currentRoomIndex: 0,
        ),
        rewardProcessor: rp,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: clockMs,
        currentHp: char.stats.maxHp,
        activeDungeonSession: const ActiveDungeonSessionSnapshot(
          runId: 'mode_a_persistent_run',
          dungeonId: 'forgotten_forest',
          currentRoomId: 'forest_entrance',
          currentRoomIndex: 0,
          status: DungeonSessionStatus.inProgress,
        ),
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.continueDungeon,
          state: OfflineActivityState.configured,
          activeRunId: 'mode_a_persistent_run',
          selectedDungeonId: 'forgotten_forest',
          simulationSeed: 55,
        ),
      );

      clockMs += const Duration(minutes: 20).inMilliseconds;
      final interrupted = await GameSessionCoordinator(
        repository: repo,
        config: config,
        checkpointIterationsPerBatch: 80,
        nowMs: () => clockMs,
      ).loadAndProcessOffline(maxBatches: 1);

      expect(
        interrupted.offlineResult.status,
        OfflineProgressionStatus.interrupted,
      );
      expect(interrupted.offlineActivity.activeRunId, 'mode_a_persistent_run');

      final finished = await GameSessionCoordinator(
        repository: repo,
        config: config,
        checkpointIterationsPerBatch: 80,
        nowMs: () => clockMs,
      ).loadAndProcessOffline();

      expect(finished.offlineResult.status, OfflineProgressionStatus.applied);
      expect(
        finished.offlineResult.stopReason,
        OfflineDungeonStopReason.dungeonCompleted,
      );
      expect(finished.activeDungeonSession?.runId, 'mode_a_persistent_run');
      expect(finished.activeDungeonSession?.isRecoverable, isFalse);
      expect(finished.dungeon.clearsCount, 1);

      // Pastikan setiap enemy key pada runId hanya muncul sekali dalam claimedIds.
      final runKills = finished.claimedEventIds
          .where((id) => id.startsWith('offline_kill:mode_a_persistent_run:'))
          .toList();
      expect(runKills.toSet().length, runKills.length);
      expect(runKills, isNotEmpty);
    });

    test('korupsi offline_activity_json di SQLite fallback aman ke Pause Progression', () async {
      final config = _loadRealGameConfig();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final repo = DriftPlayerSaveRepository(db: db, config: config);
      var clockMs = 1000000;
      final coord = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => clockMs,
      );
      final boot1 = await coord.loadAndProcessOffline();
      await coord.saveFromRuntime(
        character: boot1.character,
        inventory: boot1.inventory,
        dungeon: const DungeonProgressSnapshot(clearsCount: 1),
        rewardProcessor: boot1.rewardProcessor,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: clockMs,
      );

      // Suntikkan JSON rusak ke kolom session_data_json secara langsung.
      await db.customStatement(
        "UPDATE game_sessions SET session_data_json = '{corrupt_json' WHERE player_id = 'default'",
      );

      clockMs += const Duration(hours: 2).inMilliseconds;
      final boot2 = await coord.loadAndProcessOffline();
      expect(boot2.offlineResult.status, OfflineProgressionStatus.paused);
      expect(boot2.offlineActivity.mode, OfflineActivityMode.pauseProgression);
      expect(boot2.offlineResult.hasRewards, isFalse);
    });

    test('pemanggilan konkuren loadAndProcessOffline dan processOfflineOnResume diserialisasi tanpa double claim', () async {
      final config = _loadRealGameConfig();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final repo = DriftPlayerSaveRepository(db: db, config: config);
      var clockMs = 1000000;
      final setupCoord = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => clockMs,
      );

      final char = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 5),
      );
      final inv = Inventory(definitions: config.items);
      final rp = RewardProcessor(
        character: char,
        inventory: inv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      await setupCoord.saveFromRuntime(
        character: char,
        inventory: inv,
        dungeon: const DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
        rewardProcessor: rp,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: clockMs,
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.configured,
          selectedDungeonId: 'forgotten_forest',
          simulationSeed: 88,
        ),
      );

      clockMs += const Duration(minutes: 15).inMilliseconds;
      final resumeCoord = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => clockMs,
      );

      final results = await Future.wait([
        resumeCoord.loadAndProcessOffline(),
        resumeCoord.processOfflineOnResume(),
        resumeCoord.processOfflineOnResume(),
      ]);

      final appliedCount = results
          .where(
            (r) => r.offlineResult.status == OfflineProgressionStatus.applied,
          )
          .length;
      final alreadyClaimedCount = results
          .where(
            (r) =>
                r.offlineResult.status ==
                OfflineProgressionStatus.alreadyClaimed,
          )
          .length;

      expect(appliedCount, 1);
      expect(alreadyClaimedCount, 2);
      expect(results[2].character.gold, results[0].character.gold);
    });

    testWidgets(
      'AppLifecycleState.resumed di DungeonScreen aman untuk Pause Progression & memicu resume Mode B',
      (tester) async {
        final config = _loadRealGameConfig();
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);

        // Siapkan DB dengan saved snapshot 10 menit lalu dalam Mode B Auto Farming.
        final repo = DriftPlayerSaveRepository(db: db, config: config);
        final pastMs =
            DateTime.now().millisecondsSinceEpoch -
            const Duration(minutes: 10).inMilliseconds;
        await tester.runAsync(() async {
          final char = PlayerCharacter(
            config: config.progression,
            progress: const PlayerProgress(level: 5, gold: 50),
          );
          final inv = Inventory(definitions: config.items);
          final setup = GameSessionCoordinator(
            repository: repo,
            config: config,
            nowMs: () => pastMs,
          );
          await setup.saveFromRuntime(
            character: char,
            inventory: inv,
            dungeon: const DungeonProgressSnapshot(
              currentDungeonId: 'forgotten_forest',
              clearsCount: 1,
              clearedInCycleRank: 0,
              highestClearedRoomIndex: 4,
            ),
            rewardProcessor: RewardProcessor(
              character: char,
              inventory: inv,
              items: config.items,
              lootTables: config.lootTables,
              equipmentFactory: EquipmentFactory(config.equipment),
            ),
            autoSkillEnabled: true,
            lastOfflineClaimAtMs: pastMs,
          );
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gameConfigProvider.overrideWith((ref) async => config),
              playerSaveRepositoryProvider.overrideWith(
                (ref) async =>
                    DriftPlayerSaveRepository(db: db, config: config),
              ),
            ],
            child: const MaterialApp(
              home: DungeonScreen(roomTransitionDelaySeconds: 0.1),
            ),
          ),
        );

        for (var i = 0; i < 20; i++) {
          await tester.pump();
          await tester.runAsync(_flushAsyncDb);
          await tester.pump();
          if (find.byType(TownHubView).evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.byType(TownHubView), findsOneWidget);

        // Saat mode masih Pause Progression, paused -> resumed tidak memberi reward.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await tester.runAsync(_flushAsyncDb);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.runAsync(_flushAsyncDb);
        await tester.pump();

        var snap = await tester.runAsync(repo.loadSnapshot);
        expect(snap!.character.progress.gold, 50);

        // Transisi ke paused dan flush save online terlebih dahulu, lalu simpan
        // snapshot Mode B configured dengan lastSavedAtMs 10 menit lalu ke repo,
        // kemudian picu paused -> resumed (simulasi wakeup setelah idle/background).
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        for (var i = 0; i < 5; i++) {
          await tester.pump();
          await tester.runAsync(_flushAsyncDb);
        }

        final tenMinAgo =
            DateTime.now().millisecondsSinceEpoch -
            const Duration(minutes: 10).inMilliseconds;
        await tester.runAsync(() async {
          final current = (await repo.loadSnapshot())!;
          await repo.saveSnapshot(
            PlayerSaveSnapshot(
              playerId: current.playerId,
              character: current.character,
              inventory: current.inventory,
              dungeon: current.dungeon,
              dungeonProgresses: current.dungeonProgresses,
              cycleProgress: current.cycleProgress,
              session: GameSessionSnapshot(
                playerId: current.session.playerId,
                lastActiveAtMs: tenMinAgo,
                lastSavedAtMs: tenMinAgo,
                lastOfflineClaimAtMs: tenMinAgo,
                autoSkillEnabled: current.session.autoSkillEnabled,
              ),
              claimedEventIds: current.claimedEventIds,
              activeDungeonSession: current.activeDungeonSession,
              offlineActivity: const OfflineActivitySnapshot(
                mode: OfflineActivityMode.autoFarming,
                state: OfflineActivityState.configured,
                selectedDungeonId: 'forgotten_forest',
                simulationSeed: 17,
              ),
            ),
          );
        });
        final afterSql = await tester.runAsync(repo.loadSnapshot);
        expect(
          afterSql!.offlineActivity.state,
          OfflineActivityState.configured,
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump();
          await tester.runAsync(_flushAsyncDb);
          await tester.pump();
          final check = await tester.runAsync(repo.loadSnapshot);
          if (check != null &&
              check.offlineActivity.state != OfflineActivityState.configured) {
            break;
          }
        }
        final finalSnap = (await tester.runAsync(repo.loadSnapshot))!;
        expect(
          finalSnap.offlineActivity.state,
          OfflineActivityState.completed,
          reason:
              'Summary=${finalSnap.offlineActivity.pendingSummary?.failureReason}',
        );
        expect(finalSnap.character.progress.gold, greaterThan(50));
        expect(finalSnap.dungeon.clearsCount, greaterThan(1));
      },
    );
  });
}
