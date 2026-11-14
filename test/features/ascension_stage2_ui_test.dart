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
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/echoes_game.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  final config = GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
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
    dungeons: const DungeonConfigParser().parse(
      _readAsset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
  );
  const GameConfigValidator().validate(config);
  return config;
}

Future<void> _flushDb() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late GameConfig config;

  setUpAll(() {
    config = _loadRealConfig();
  });

  group('M9 Stage 2 — UI Ascension Dungeon', () {
    testWidgets(
      'TownHubView menampilkan level rekomendasi Ascension (Rank 0 & Rank 1), mengunci sebelum D5 selesai, dan menolak Auto Farming',
      (tester) async {
        final character = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 50, gold: 100),
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
        );
        final inventory = Inventory(definitions: config.items);
        final views = InventoryViews(
          inventory: inventory,
          character: character,
        );

        String? enteredId;

        Future<void> pumpTown({
          required CycleProgress cycleProgress,
          required Map<String, DungeonProgressSnapshot> progresses,
          String selectedId = 'ascension_sanctum',
          PlayerCharacter? overrideCharacter,
        }) async {
          final activeChar = overrideCharacter ?? character;
          final activeViews = overrideCharacter == null
              ? views
              : InventoryViews(inventory: inventory, character: activeChar);
          enteredId = null;
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
                  cycleProgress: cycleProgress,
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
          await tester.pump();
        }

        // Rank 0, D5 belum selesai -> Lv 49 tampil tapi terkunci & tidak ada tombol masuk.
        await pumpTown(
          cycleProgress: const CycleProgress(ascensionRank: 0),
          progresses: const {},
        );
        expect(find.text('Ascension: Aether Sanctum'), findsAtLeastNWidgets(1));
        expect(
          find.textContaining('Rekomendasi Lv 49'),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
          findsNothing,
        );
        expect(
          find.textContaining('Hanya manual (Ascension Dungeon'),
          findsOneWidget,
        );

        // Rank 1, D5 selesai di Rank 1 -> rekomendasi naik ke Lv 93.
        // Dengan Lv 50 (kurang dari Lv 93), tombol masuk terkunci oleh Hard Lock.
        await pumpTown(
          cycleProgress: const CycleProgress(ascensionRank: 1),
          progresses: const {
            'aether_sanctum': DungeonProgressSnapshot(
              currentDungeonId: 'aether_sanctum',
              clearsCount: 2,
              clearedInCycleRank: 1,
            ),
          },
        );
        expect(
          find.textContaining('Rekomendasi Lv 93'),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.textContaining('butuh minimal Lv 93'),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
          findsNothing,
        );

        // Dengan Lv 93, tombol masuk Ascension aktif.
        final rank1ReadyChar = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 93, gold: 100),
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
        );
        await pumpTown(
          cycleProgress: const CycleProgress(ascensionRank: 1),
          progresses: const {
            'aether_sanctum': DungeonProgressSnapshot(
              currentDungeonId: 'aether_sanctum',
              clearsCount: 2,
              clearedInCycleRank: 1,
            ),
          },
          overrideCharacter: rank1ReadyChar,
        );
        expect(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
        );
        await tester.tap(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
        );
        await tester.pump();
        expect(enteredId, 'ascension_sanctum');
      },
    );

    testWidgets(
      'DungeonScreen memulihkan sesi aktif Ascension dengan cycleRank tersimpan dan memblokir masuk sebelum D5 selesai',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);

        final repo = DriftPlayerSaveRepository(db: db, config: config);
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await tester.runAsync(() async {
          final char = PlayerCharacter(
            config: config.progression,
            progress: const PlayerProgress(level: 50, gold: 250),
            skillCatalog: config.skills,
            specializationConfig: config.specializations,
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
              currentDungeonId: 'forgotten_forest',
              clearsCount: 1,
              clearedInCycleRank: 0,
            ),
            cycleProgress: const CycleProgress(
              ascensionRank: 0,
              lastNormalDungeonId: 'forgotten_forest',
            ),
            rewardProcessor: RewardProcessor(
              character: char,
              inventory: inv,
              items: config.items,
              lootTables: config.lootTables,
              equipmentFactory: EquipmentFactory(config.equipment),
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
          if (find.byType(TownHubView).evaluate().isNotEmpty) break;
        }
        expect(find.byType(TownHubView), findsOneWidget);

        // Sebelum D5 selesai: Ascension tetap terlihat dengan Rekomendasi Lv 49, namun terkunci
        // (tombol pilih & masuk belum aktif).
        expect(find.text('6. Ascension: Aether Sanctum'), findsOneWidget);
        expect(
          find.byKey(const Key('dungeon_select_ascension_sanctum')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
          findsNothing,
        );
        expect(
          find.textContaining('Rekomendasi Lv 49'),
          findsAtLeastNWidgets(1),
        );

        // Simpan activeDungeonSession Ascension yang dimulai pada cycleRank: 1,
        // sementara DB cycleProgress berada di ascensionRank: 3 -> recovery wajib memakai rank 1.
        await tester.runAsync(() async {
          final current = (await repo.loadSnapshot())!;
          await repo.saveSnapshot(
            PlayerSaveSnapshot(
              character: current.character,
              inventory: current.inventory,
              dungeon: const DungeonProgressSnapshot(
                currentDungeonId: 'ascension_sanctum',
                currentRoomId: 'as_arcane_bridge',
                currentRoomIndex: 1,
              ),
              dungeonProgresses: {
                ...current.dungeonProgresses,
                'aether_sanctum': const DungeonProgressSnapshot(
                  currentDungeonId: 'aether_sanctum',
                  clearsCount: 2,
                  clearedInCycleRank: 1,
                ),
              },
              cycleProgress: const CycleProgress(
                ascensionRank: 3,
                lastNormalDungeonId: 'aether_sanctum',
              ),
              session: GameSessionSnapshot(
                lastActiveAtMs: nowMs,
                lastSavedAtMs: nowMs,
                lastOfflineClaimAtMs: nowMs,
              ),
              activeDungeonSession: const ActiveDungeonSessionSnapshot(
                runId: 'asc_ui_recover_1',
                dungeonId: 'ascension_sanctum',
                currentRoomId: 'as_arcane_bridge',
                currentRoomIndex: 1,
                status: DungeonSessionStatus.inProgress,
                clearedRoomIds: {'as_outer_sanctum'},
                cycleRank: 1,
              ),
              offlineActivity: const OfflineActivitySnapshot.paused(),
            ),
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
              home: DungeonScreen(
                key: ValueKey('asc_recovered_screen'),
                roomTransitionDelaySeconds: 0.05,
              ),
            ),
          ),
        );

        for (var i = 0; i < 20; i++) {
          await tester.pump();
          await tester.runAsync(_flushDb);
          await tester.pump();
          if (find.byType(GameWidget<EchoesGame>).evaluate().isNotEmpty) {
            break;
          }
        }

        final gameWidget = tester.widget<GameWidget<EchoesGame>>(
          find.byType(GameWidget<EchoesGame>),
        );
        final manager = gameWidget.game!.world.dungeonManager!;
        expect(manager.session?.dungeonId, 'ascension_sanctum');
        expect(manager.session?.cycleRank, 1);
        expect(
          manager.activeDifficultyProfile.multiplier,
          closeTo(6.834375 * (1.0 + config.difficulty.cyclePerRank), 1e-9),
        );

        // Verifikasi enemy di Flame simulation memakai multiplier Rank 1, bukan Rank 3.
        final sim = gameWidget.game!.world.simulation;
        expect(sim.enemies, isNotEmpty);
        final diffService = DifficultyService(config.difficulty);
        final ascDef = config.dungeons['ascension_sanctum']!;
        final rank1Profile = diffService.profileFor(ascDef, 1);
        final rank3Profile = diffService.profileFor(ascDef, 3);
        final firstEnemy = sim.enemies.first;
        final roomSpawn = ascDef
            .roomById('as_arcane_bridge')!
            .spawns
            .firstWhere((s) => firstEnemy.id.contains(s.id));
        final baseMonster = config.monsters[roomSpawn.monsterId]!;
        expect(
          firstEnemy.stats.maxHp,
          diffService.scaleMonsterStats(baseMonster.stats, rank1Profile).maxHp,
        );
        expect(
          firstEnemy.stats.maxHp,
          isNot(
            diffService
                .scaleMonsterStats(baseMonster.stats, rank3Profile)
                .maxHp,
          ),
        );
      },
    );

    testWidgets(
      'TownHubView menampilkan Rank Switcher saat highestAscensionRank >= 1 dan memungkinkan turun ke Rank 0 untuk farming Lv 44',
      (tester) async {
        final character = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 44, gold: 100),
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
        );
        final inventory = Inventory(definitions: config.items);
        final views = InventoryViews(
          inventory: inventory,
          character: character,
        );

        int? switchedTo;
        Future<void> pumpWithCycle(CycleProgress cycle) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: TownHubView(
                  character: character,
                  views: views,
                  items: config.items,
                  dungeonProgress: const DungeonProgressSnapshot(
                    currentDungeonId: 'forgotten_forest',
                  ),
                  dungeonDefinition: config.dungeons['forgotten_forest'],
                  availableDungeons: config.dungeons,
                  dungeonProgresses: const {},
                  cycleProgress: cycle,
                  difficultyConfig: config.difficulty,
                  selectedDungeonId: 'forgotten_forest',
                  onEnterDungeon: () {},
                  onSwitchCycleRank: (rank) => switchedTo = rank,
                  onEquip: (_) {},
                  onUnequip: (_) {},
                  onChooseSpecialization: (_) {},
                ),
              ),
            ),
          );
          await tester.pump();
        }

        // Rank 1 / Highest 1 -> tombol turun aktif, D1 tetap terbuka di Lv 44 (Opsi 3).
        await pumpWithCycle(
          const CycleProgress(ascensionRank: 1, highestAscensionRank: 1),
        );
        expect(find.byKey(const Key('cycle_rank_switcher')), findsOneWidget);
        expect(find.text('Siklus Rank 1 / 1'), findsOneWidget);
        expect(
          find.byKey(const Key('dungeon_enter_forgotten_forest')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('cycle_rank_decrease_button')));
        await tester.pump();
        expect(switchedTo, 0);

        // Setelah turun ke Rank 0 (highest 1) -> D5 Rank 0 (min Lv 35) terbuka di Lv 44!
        await pumpWithCycle(
          const CycleProgress(ascensionRank: 0, highestAscensionRank: 1),
        );
        expect(find.text('Siklus Rank 0 / 1'), findsOneWidget);
        expect(find.textContaining('Mode farming rank bawah'), findsOneWidget);
        expect(
          find.byKey(const Key('dungeon_enter_aether_sanctum')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('cycle_rank_increase_button')));
        await tester.pump();
        expect(switchedTo, 1);
      },
    );
  });
}
