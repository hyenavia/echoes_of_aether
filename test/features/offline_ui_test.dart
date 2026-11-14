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
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/offline_summary_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealGameConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final config = GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
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
  group('M6 Stage 3 — Town Activity Selection & Offline Summary UI', () {
    testWidgets(
      'TownHubView mengunci Auto Farming sebelum dungeon selesai dan membuka setelah clearsCount > 0',
      (tester) async {
        final config = _loadRealGameConfig();
        final character = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 5, gold: 40),
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
        );
        final inventory = Inventory(definitions: config.items);
        final views = InventoryViews(
          inventory: inventory,
          character: character,
        );
        var selectedMode = OfflineActivityMode.pauseProgression;
        String? selectedAutoFarmId;

        Future<void> pumpTown({
          required int clearsCount,
          OfflineActivitySnapshot activity =
              const OfflineActivitySnapshot.paused(),
        }) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TownHubView(
                  character: character,
                  views: views,
                  items: config.items,
                  dungeonProgress: DungeonProgressSnapshot(
                    currentDungeonId: 'forgotten_forest',
                    clearsCount: clearsCount,
                    clearedInCycleRank: clearsCount > 0 ? 0 : -1,
                  ),
                  dungeonDefinition: config.dungeons['forgotten_forest'],
                  availableDungeons: config.dungeons,
                  dungeonProgresses: {
                    'forgotten_forest': DungeonProgressSnapshot(
                      currentDungeonId: 'forgotten_forest',
                      clearsCount: clearsCount,
                      clearedInCycleRank: clearsCount > 0 ? 0 : -1,
                    ),
                  },
                  offlineActivity: activity,
                  onEnterDungeon: () {},
                  onEquip: (_) {},
                  onUnequip: (_) {},
                  onChooseSpecialization: (_) {},
                  onSelectPauseOffline: () {
                    selectedMode = OfflineActivityMode.pauseProgression;
                    selectedAutoFarmId = null;
                  },
                  onSelectAutoFarming: (id) {
                    selectedMode = OfflineActivityMode.autoFarming;
                    selectedAutoFarmId = id;
                  },
                ),
              ),
            ),
          );
        }

        // Sebelum clear pertama, Auto Farming terkunci.
        await pumpTown(clearsCount: 0);
        expect(find.text('Aktivitas Offline'), findsOneWidget);
        expect(
          find.text('Mode aktif: Pause Progression (Default)'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Terkunci — selesaikan Forgotten Forest pada siklus ini untuk membuka Auto Farming.',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Auto Farming: Forgotten Forest'));
        await tester.tap(find.text('Auto Farming: Forgotten Forest'));
        await tester.pump();
        expect(selectedMode, OfflineActivityMode.pauseProgression);
        expect(selectedAutoFarmId, isNull);

        // Setelah clear >= 1, Auto Farming terbuka dan dapat dipilih.
        await pumpTown(clearsCount: 1);
        expect(
          find.text(
            'Terkunci — selesaikan Forgotten Forest pada siklus ini untuk membuka Auto Farming.',
          ),
          findsNothing,
        );
        await tester.ensureVisible(find.text('Auto Farming: Forgotten Forest'));
        await tester.tap(find.text('Auto Farming: Forgotten Forest'));
        await tester.pump();
        expect(selectedMode, OfflineActivityMode.autoFarming);
        expect(selectedAutoFarmId, 'forgotten_forest');

        // Saat mode aktif Auto Farming, memilih Pause mengembalikan default mode.
        await pumpTown(
          clearsCount: 1,
          activity: const OfflineActivitySnapshot(
            mode: OfflineActivityMode.autoFarming,
            state: OfflineActivityState.configured,
            selectedDungeonId: 'forgotten_forest',
          ),
        );
        expect(
          find.text('Mode aktif: Auto Farming — Forgotten Forest'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Pause Progression (Default)'));
        await tester.tap(find.text('Pause Progression (Default)'));
        await tester.pump();
        expect(selectedMode, OfflineActivityMode.pauseProgression);
      },
    );

    testWidgets(
      'OfflineSummaryOverlay menampilkan durasi, hadiah, alasan gagal, overflow, dan memicu onAcknowledge',
      (tester) async {
        var acknowledged = false;
        const items = <String, ItemDefinition>{
          'slime_gel': ItemDefinition(
            id: 'slime_gel',
            name: 'Slime Gel',
            category: ItemCategory.material,
          ),
        };
        const dungeons = <String, DungeonDefinition>{
          'forgotten_forest': DungeonDefinition(
            id: 'forgotten_forest',
            name: 'Forgotten Forest',
            biome: 'Forest',
            startRoomId: 'r1',
            rooms: {},
            roomOrder: ['r1'],
          ),
        };
        const summary = OfflineSummarySnapshot(
          eventId: 'offline:100:200',
          mode: OfflineActivityMode.autoFarming,
          finalState: OfflineActivityState.failed,
          effectiveElapsedMs: 28800000,
          cappedAtMaxDuration: true,
          runsAttempted: 4,
          runsCompleted: 3,
          runsFailed: 1,
          roomsCleared: 16,
          encountersCleared: 32,
          expGained: 1200,
          goldGained: 650,
          levelsGained: 2,
          addedStacks: {'slime_gel': 15},
          overflowStacks: {'slime_gel': 3},
          addedEquipmentCount: 2,
          droppedEquipmentCount: 1,
          failureReason: 'Kalah saat revive sedang cooldown.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  OfflineSummaryOverlay(
                    summary: summary,
                    items: items,
                    dungeons: dungeons,
                    selectedDungeonId: 'forgotten_forest',
                    onAcknowledge: () => acknowledged = true,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Ringkasan Offline'), findsOneWidget);
        expect(find.text('Auto Farming • Forgotten Forest'), findsOneWidget);
        expect(find.textContaining('8 jam'), findsOneWidget);
        expect(find.textContaining('(maks 8 jam)'), findsOneWidget);
        expect(find.text('Kalah saat revive sedang cooldown.'), findsOneWidget);
        expect(find.text('3/4 selesai (1 gagal)'), findsOneWidget);
        expect(find.text('+1.2K EXP • +650 Gold (+2 Lv)'), findsOneWidget);
        expect(find.text('• Slime Gel x15'), findsOneWidget);
        expect(find.text('Equipment masuk tas: +2'), findsOneWidget);
        expect(find.textContaining('1 equipment terlewat'), findsOneWidget);

        await tester.tap(find.text('Tutup & Simpan'));
        await tester.pump();
        expect(acknowledged, isTrue);
      },
    );

    testWidgets(
      'End-to-end DungeonScreen: pilih Auto Farming -> resume tampilkan Summary -> Tutup & Simpan -> restart tanpa ulang reward & Mode A reset saat keluar',
      (tester) async {
        final config = _loadRealGameConfig();
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);

        final repo = DriftPlayerSaveRepository(db: db, config: config);
        final pastMs =
            DateTime.now().millisecondsSinceEpoch -
            const Duration(minutes: 15).inMilliseconds;

        // Seed save awal: Forgotten Forest sudah pernah clear (clearsCount = 1).
        await tester.runAsync(() async {
          final char = PlayerCharacter(
            config: config.progression,
            progress: const PlayerProgress(level: 5, gold: 100),
          );
          final inv = Inventory(definitions: config.items);
          final setupCoord = GameSessionCoordinator(
            repository: repo,
            config: config,
            nowMs: () => pastMs,
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

        // Pilih Mode B Auto Farming langsung lewat UI Town Hub.
        await tester.ensureVisible(find.text('Auto Farming: Forgotten Forest'));
        await tester.tap(find.text('Auto Farming: Forgotten Forest'));
        await tester.pump();
        for (var i = 0; i < 5; i++) {
          await tester.pump();
          await tester.runAsync(_flushAsyncDb);
        }
        expect(
          find.text('Mode aktif: Auto Farming — Forgotten Forest'),
          findsOneWidget,
        );

        var saved = (await tester.runAsync(repo.loadSnapshot))!;
        expect(saved.offlineActivity.mode, OfflineActivityMode.autoFarming);
        expect(saved.offlineActivity.state, OfflineActivityState.configured);
        expect(saved.offlineActivity.selectedDungeonId, 'forgotten_forest');

        // Simulasikan keluar 15 menit lalu kembali (AppLifecycleState.paused -> resumed).
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        for (var i = 0; i < 5; i++) {
          await tester.pump();
          await tester.runAsync(_flushAsyncDb);
        }

        final fifteenMinAgo =
            DateTime.now().millisecondsSinceEpoch -
            const Duration(minutes: 15).inMilliseconds;
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
                lastActiveAtMs: fifteenMinAgo,
                lastSavedAtMs: fifteenMinAgo,
                lastOfflineClaimAtMs: fifteenMinAgo,
                autoSkillEnabled: current.session.autoSkillEnabled,
              ),
              claimedEventIds: current.claimedEventIds,
              activeDungeonSession: current.activeDungeonSession,
              offlineActivity: current.offlineActivity,
            ),
          );
        });

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump();
          await tester.runAsync(_flushAsyncDb);
          await tester.pump();
          if (find.byType(OfflineSummaryOverlay).evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.byType(OfflineSummaryOverlay), findsOneWidget);
        expect(find.text('Ringkasan Offline'), findsOneWidget);

        final beforeAckGold = (await tester.runAsync(repo.loadSnapshot))!
            .character
            .progress
            .gold;
        expect(beforeAckGold, greaterThan(100));

        // Tutup & ack Summary -> reset ke Pause Progression & persisten ke SQLite.
        await tester.tap(find.text('Tutup & Simpan'));
        for (var i = 0; i < 10; i++) {
          await tester.pump();
          await tester.runAsync(_flushAsyncDb);
        }
        expect(find.byType(OfflineSummaryOverlay), findsNothing);
        expect(
          find.text('Mode aktif: Pause Progression (Default)'),
          findsOneWidget,
        );

        final afterAck = (await tester.runAsync(repo.loadSnapshot))!;
        expect(
          afterAck.offlineActivity.mode,
          OfflineActivityMode.pauseProgression,
        );
        expect(afterAck.offlineActivity.state, OfflineActivityState.inactive);
        expect(afterAck.offlineActivity.pendingSummary?.acknowledged, isTrue);

        // Rebuild widget bersih (cold boot ulang) -> summary tidak muncul lagi dan gold tidak bertambah.
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
              key: ValueKey('reboot_2'),
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
        expect(find.byType(OfflineSummaryOverlay), findsNothing);
        final afterReboot = (await tester.runAsync(repo.loadSnapshot))!;
        expect(afterReboot.character.progress.gold, beforeAckGold);

        // Uji Mode A toggle saat berada di dalam dungeon + reset saat keluar ke Town.
        await tester.tap(find.text('Masuk Forgotten Forest'));
        for (var i = 0; i < 10; i++) {
          await tester.pump();
          await tester.runAsync(_flushAsyncDb);
        }
        expect(find.text('Offline: Pause'), findsOneWidget);

        await tester.tap(find.text('Offline: Pause'));
        for (var i = 0; i < 5; i++) {
          await tester.pump();
          await tester.runAsync(_flushAsyncDb);
        }
        expect(find.text('Offline: Lanjut'), findsOneWidget);
        final modeASaved = (await tester.runAsync(repo.loadSnapshot))!;
        expect(
          modeASaved.offlineActivity.mode,
          OfflineActivityMode.continueDungeon,
        );
        expect(modeASaved.offlineActivity.activeRunId, isNotEmpty);

        // Keluar ke Town membatalkan run sehingga Mode A harus reset aman ke Pause.
        await tester.tap(find.byKey(const Key('hud_menu_toggle_button')));
        await tester.pump();
        await tester.tap(find.text('Kembali ke Town'));
        for (var i = 0; i < 10; i++) {
          await tester.pump();
          await tester.runAsync(_flushAsyncDb);
        }
        expect(
          find.text('Mode aktif: Pause Progression (Default)'),
          findsOneWidget,
        );
      },
    );
  });
}
