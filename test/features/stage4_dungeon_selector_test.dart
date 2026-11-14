import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/providers/database_provider.dart';
import 'package:echoes_of_aether/application/providers/game_config_provider.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _openLayout = <String>[
  '####################',
  '#..................#',
  '#..................#',
  '#..................#',
  '#..................#',
  '#..................#',
  '#..................#',
  '#..................#',
  '#..................#',
  '#..................#',
  '####################',
];

GameConfig _multiDungeonWidgetConfig() => GameConfig(
  monsters: const {
    'aether_slime': EnemyDefinition(
      id: 'aether_slime',
      name: 'Aether Slime',
      level: 1,
      expReward: 10,
      goldReward: 5,
      stats: CombatStats(
        maxHp: 35,
        atk: 5,
        def: 1,
        attackSpeed: 1,
        moveSpeed: 2,
        attackRange: 1.2,
      ),
    ),
  },
  revive: const ReviveConfig(),
  progression: const ProgressionConfig(
    maxLevel: 40,
    expBase: 50,
    expGrowth: 1.4,
    baseStats: CombatStats(
      maxHp: 120,
      atk: 15,
      def: 3,
      attackSpeed: 1.2,
      moveSpeed: 4,
      attackRange: 1.5,
    ),
    perLevel: LevelGrowth(hp: 15, atk: 3, def: 1),
  ),
  items: const {
    'slime_gel': ItemDefinition(
      id: 'slime_gel',
      name: 'Slime Gel',
      category: ItemCategory.material,
    ),
  },
  lootTables: const {},
  dungeons: const {
    'dungeon_1': DungeonDefinition(
      id: 'dungeon_1',
      name: 'Forest Alpha',
      biome: 'forest',
      kind: DungeonKind.normal,
      order: 1,
      recommendedLevel: 1,
      startRoomId: 'd1_r1',
      roomOrder: ['d1_r1'],
      completionReward: DungeonCompletionReward(expReward: 20, goldReward: 10),
      rooms: {
        'd1_r1': RoomDefinition(
          id: 'd1_r1',
          dungeonId: 'dungeon_1',
          name: 'Alpha Gate',
          type: RoomType.boss,
          mapRef: 'd1_r1',
          layout: _openLayout,
          entryPosition: GridPoint(2, 5),
          exitPosition: GridPoint(16, 5),
          completionCondition: RoomCompletionCondition(
            type: RoomCompletionConditionType.defeatBoss,
          ),
          spawns: [
            RoomSpawnConfig(
              id: 'b1',
              monsterId: 'aether_slime',
              position: GridPoint(8, 5),
              isBoss: true,
            ),
          ],
        ),
      },
    ),
    'dungeon_2': DungeonDefinition(
      id: 'dungeon_2',
      name: 'Cavern Beta',
      biome: 'cavern',
      kind: DungeonKind.normal,
      order: 2,
      recommendedLevel: 10,
      unlockRequiresDungeonId: 'dungeon_1',
      startRoomId: 'd2_r1',
      roomOrder: ['d2_r1'],
      completionReward: DungeonCompletionReward(expReward: 50, goldReward: 25),
      rooms: {
        'd2_r1': RoomDefinition(
          id: 'd2_r1',
          dungeonId: 'dungeon_2',
          name: 'Beta Hollow',
          type: RoomType.boss,
          mapRef: 'd2_r1',
          layout: _openLayout,
          entryPosition: GridPoint(2, 5),
          exitPosition: GridPoint(16, 5),
          completionCondition: RoomCompletionCondition(
            type: RoomCompletionConditionType.defeatBoss,
          ),
          spawns: [
            RoomSpawnConfig(
              id: 'b2',
              monsterId: 'aether_slime',
              position: GridPoint(8, 5),
              isBoss: true,
            ),
          ],
        ),
      },
    ),
    'ascension_trial': DungeonDefinition(
      id: 'ascension_trial',
      name: 'Ascension Trial',
      biome: 'sanctum',
      kind: DungeonKind.ascension,
      order: 3,
      recommendedLevel: 25,
      unlockRequiresDungeonId: 'dungeon_2',
      baseDungeonId: 'dungeon_1',
      startRoomId: 'a1_r1',
      roomOrder: ['a1_r1'],
      rooms: {
        'a1_r1': RoomDefinition(
          id: 'a1_r1',
          dungeonId: 'ascension_trial',
          name: 'Trial Hall',
          type: RoomType.boss,
          mapRef: 'a1_r1',
          layout: _openLayout,
          entryPosition: GridPoint(2, 5),
          exitPosition: GridPoint(16, 5),
          completionCondition: RoomCompletionCondition(
            type: RoomCompletionConditionType.defeatBoss,
          ),
          spawns: [
            RoomSpawnConfig(
              id: 'ba',
              monsterId: 'aether_slime',
              position: GridPoint(8, 5),
              isBoss: true,
            ),
          ],
        ),
      },
    ),
  },
);

Future<void> _flushDb() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('M8 Stage 4 — Multi-Dungeon Selector & TownHubView UI', () {
    testWidgets(
      'TownHubView menampilkan daftar dungeon, status terkunci/terbuka/selesai, recommended level, dan peringatan under-level',
      (tester) async {
        final config = _multiDungeonWidgetConfig();
        final character = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 1),
        );
        final inventory = Inventory(definitions: config.items);
        final views = InventoryViews(
          inventory: inventory,
          character: character,
        );
        String? enteredId;

        Future<void> pumpTown({
          required Map<String, DungeonProgressSnapshot> progresses,
          String selectedId = 'dungeon_1',
          PlayerCharacter? overrideCharacter,
        }) async {
          final activeChar = overrideCharacter ?? character;
          final activeViews = overrideCharacter == null
              ? views
              : InventoryViews(inventory: inventory, character: activeChar);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TownHubView(
                  character: activeChar,
                  views: activeViews,
                  items: config.items,
                  dungeonProgress:
                      progresses[selectedId] ??
                      DungeonProgressSnapshot(currentDungeonId: selectedId),
                  dungeonDefinition: config.dungeons[selectedId],
                  availableDungeons: config.dungeons,
                  dungeonProgresses: progresses,
                  cycleProgress: CycleProgress(
                    ascensionRank: 0,
                    lastNormalDungeonId: selectedId,
                  ),
                  difficultyConfig: config.difficulty,
                  selectedDungeonId: selectedId,
                  onEnterDungeon: () => enteredId = selectedId,
                  onEnterDungeonById: (id) => enteredId = id,
                  onEquip: (_) {},
                  onUnequip: (_) {},
                  onChooseSpecialization: (_) {},
                ),
              ),
            ),
          );
        }

        // Kondisi awal: hanya dungeon_1 terbuka, dungeon_2 & ascension_trial terkunci.
        await pumpTown(progresses: const {});
        expect(find.text('Daftar Dungeon'), findsOneWidget);
        expect(find.text('1. Forest Alpha'), findsOneWidget);
        expect(find.text('2. Cavern Beta'), findsOneWidget);
        expect(find.text('3. Ascension Trial'), findsOneWidget);
        expect(find.text('Terbuka'), findsOneWidget);
        expect(find.text('Terkunci'), findsNWidgets(2));
        expect(
          find.byKey(const Key('dungeon_enter_dungeon_1')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('dungeon_enter_dungeon_2')), findsNothing);
        expect(
          find.byKey(const Key('dungeon_enter_ascension_trial')),
          findsNothing,
        );
        expect(
          find.textContaining('Hanya manual (Ascension Dungeon'),
          findsOneWidget,
        );

        // Setelah dungeon_1 selesai tapi Lv masih 1 (< Rec Lv 10):
        // dungeon_2 terkunci oleh Hard Lock & menampilkan minimal Lv 10.
        await pumpTown(
          progresses: const {
            'dungeon_1': DungeonProgressSnapshot(
              currentDungeonId: 'dungeon_1',
              clearsCount: 1,
              clearedInCycleRank: 0,
            ),
          },
          selectedId: 'dungeon_2',
        );
        expect(find.text('Selesai'), findsOneWidget);
        expect(find.text('Terkunci'), findsNWidgets(2));
        expect(find.byKey(const Key('dungeon_enter_dungeon_2')), findsNothing);
        expect(
          find.textContaining('Rekomendasi Lv 10'),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.textContaining('butuh minimal Lv 10'),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.text('Target default Auto Farming: Forest Alpha'),
          findsOneWidget,
        );

        // Saat Lv sudah >= 10: dungeon_2 terbuka & tombol masuk aktif.
        final level10Char = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 10),
        );
        await pumpTown(
          progresses: const {
            'dungeon_1': DungeonProgressSnapshot(
              currentDungeonId: 'dungeon_1',
              clearsCount: 1,
              clearedInCycleRank: 0,
            ),
          },
          selectedId: 'dungeon_2',
          overrideCharacter: level10Char,
        );
        expect(find.text('Terbuka'), findsOneWidget);
        expect(find.text('Terkunci'), findsOneWidget);
        expect(
          find.byKey(const Key('dungeon_enter_dungeon_2')),
          findsOneWidget,
        );

        // Masuk dungeon kedua langsung lewat tombol masuk di row dungeon_2.
        await tester.ensureVisible(
          find.byKey(const Key('dungeon_enter_dungeon_2')),
        );
        await tester.tap(find.byKey(const Key('dungeon_enter_dungeon_2')));
        await tester.pump();
        expect(enteredId, 'dungeon_2');
      },
    );

    testWidgets(
      'DungeonScreen dapat memilih & memasuki dungeon kedua, menjaga progres per-dungeon terpisah, dan memulihkan sesi aktif non-default',
      (tester) async {
        final config = _multiDungeonWidgetConfig();
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);

        final repo = DriftPlayerSaveRepository(db: db, config: config);
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await tester.runAsync(() async {
          final char = PlayerCharacter(
            config: config.progression,
            progress: const PlayerProgress(level: 10, gold: 100),
          );
          final inv = Inventory(definitions: config.items);
          final setup = GameSessionCoordinator(
            repository: repo,
            config: config,
            nowMs: () => nowMs,
          );
          await setup.saveFromRuntime(
            character: char,
            inventory: inv,
            dungeon: const DungeonProgressSnapshot(
              currentDungeonId: 'dungeon_1',
              currentRoomId: 'd1_r1',
              currentRoomIndex: 0,
              highestClearedRoomIndex: 0,
              clearsCount: 1,
              clearedInCycleRank: 0,
            ),
            cycleProgress: const CycleProgress(
              ascensionRank: 0,
              lastNormalDungeonId: 'dungeon_1',
            ),
            rewardProcessor: RewardProcessor(
              character: char,
              inventory: inv,
              items: config.items,
              lootTables: config.lootTables,
              equipmentFactory: const EquipmentFactory(EquipmentConfig()),
            ),
            autoSkillEnabled: true,
            lastOfflineClaimAtMs: nowMs,
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
              home: DungeonScreen(roomTransitionDelaySeconds: 0.05),
            ),
          ),
        );

        for (var i = 0; i < 20; i++) {
          await tester.pump();
          await tester.runAsync(_flushDb);
          await tester.pump();
          if (find.byType(TownHubView).evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.text('Forest Alpha'), findsOneWidget);

        // Pilih dungeon_2 sebagai target aktif lalu verifikasi persistensi lastNormalDungeonId.
        await tester.ensureVisible(
          find.byKey(const Key('dungeon_select_dungeon_2')),
        );
        await tester.tap(find.byKey(const Key('dungeon_select_dungeon_2')));
        await tester.pump();
        for (var i = 0; i < 5; i++) {
          await tester.pump();
          await tester.runAsync(_flushDb);
        }

        expect(find.text('Cavern Beta'), findsOneWidget);
        expect(find.text('Total dungeon selesai: 0'), findsOneWidget);
        var saved = (await tester.runAsync<PlayerSaveSnapshot?>(
          repo.loadSnapshot,
        ))!;
        expect(saved.cycleProgress.lastNormalDungeonId, 'dungeon_2');
        expect(saved.dungeonProgresses['dungeon_1']?.clearsCount, 1);

        // Masuk Cavern Beta dan pastikan room & dungeon_1 tetap terisolasi.
        await tester.ensureVisible(find.text('Masuk Cavern Beta'));
        await tester.tap(find.text('Masuk Cavern Beta'));
        await tester.pump();
        await tester.pump();
        for (var i = 0; i < 5; i++) {
          await tester.pump();
          await tester.runAsync(_flushDb);
        }

        expect(find.text('Cavern Beta • Beta Hollow'), findsOneWidget);
        saved = (await tester.runAsync<PlayerSaveSnapshot?>(
          repo.loadSnapshot,
        ))!;
        expect(saved.activeDungeonSession?.dungeonId, 'dungeon_2');
        expect(saved.activeDungeonSession?.currentRoomId, 'd2_r1');
        expect(
          saved.activeDungeonSession?.status,
          DungeonSessionStatus.inProgress,
        );
        expect(saved.dungeonProgresses['dungeon_1']?.clearsCount, 1);
        expect(saved.dungeonProgresses['dungeon_2']?.clearsCount, 0);

        // Cold restart: buka DungeonScreen baru dengan DB sama, harus langsung pulih ke Cavern Beta.
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
              home: DungeonScreen(
                key: ValueKey('restarted_dungeon_screen'),
                roomTransitionDelaySeconds: 0.05,
              ),
            ),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump();
          await tester.runAsync(_flushDb);
          await tester.pump();
          if (find.text('Cavern Beta • Beta Hollow').evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.text('Cavern Beta • Beta Hollow'), findsOneWidget);
        expect(find.text('Town / Camp'), findsNothing);
      },
    );
  });
}
