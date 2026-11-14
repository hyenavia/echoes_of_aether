import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/providers/database_provider.dart';
import 'package:echoes_of_aether/application/providers/game_config_provider.dart';
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
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/damage_config.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/services/damage_calculator.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_status.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/dungeon_reward_settlement_service.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_completed_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/hud_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/components/enemies/enemy_component.dart';
import 'package:echoes_of_aether/game/echoes_game.dart';
import 'package:echoes_of_aether/game/world/debug_room_component.dart';
import 'package:flame/game.dart';
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
    damage: const DamageConfig(formula: DamageFormula.subtractive),
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
  group('Stage 6 QA — Map Navigability & Real Config Balance', () {
    test('seluruh 5 room Forgotten Forest dapat dinavigasi oleh A* (entry -> spawn & entry -> exit)', () {
      final config = _loadRealGameConfig();
      final dungeon = config.dungeons['forgotten_forest']!;
      const pathfinder = AStarPathfinder();

      expect(dungeon.roomOrder.length, 5);
      for (final roomId in dungeon.roomOrder) {
        final room = dungeon.roomById(roomId)!;
        final grid = NavigationGrid.fromAscii(room.layout);
        expect(
          grid.isWalkable(room.entryPosition.x, room.entryPosition.y),
          isTrue,
          reason: '${room.id} entryPosition harus walkable',
        );
        expect(
          grid.isWalkable(room.exitPosition.x, room.exitPosition.y),
          isTrue,
          reason: '${room.id} exitPosition harus walkable',
        );

        final pathToExit = pathfinder.findPath(
          grid,
          room.entryPosition,
          room.exitPosition,
        );
        expect(
          pathToExit,
          isNotNull,
          reason: '${room.id}: tidak ada path A* dari entry ke exit',
        );
        expect(pathToExit!.last, room.exitPosition);

        for (final spawn in room.spawns) {
          expect(
            grid.isWalkable(spawn.position.x, spawn.position.y),
            isTrue,
            reason: '${room.id} spawn ${spawn.id} harus walkable',
          );
          final pathToSpawn = pathfinder.findPath(
            grid,
            room.entryPosition,
            spawn.position,
          );
          expect(
            pathToSpawn,
            isNotNull,
            reason:
                '${room.id} spawn ${spawn.id} harus terjangkau dari entryPosition',
          );
        }
      }
    });

    test('simulasi balance nyata Forgotten Forest dengan config default (fresh Level 1 vs progres bertahap)', () {
      final config = _loadRealGameConfig();

      ({
        bool completed,
        int roomsCleared,
        int endLevel,
        int revivesUsed,
        int ticks,
        String? failedRoomId,
        int endHp,
      })
      simulateRun({required int startLevel, required int seed}) {
        final character = PlayerCharacter(
          config: config.progression,
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
        );
        for (var lv = 1; lv < startLevel; lv++) {
          character.receiveReward(exp: character.expToNext);
        }
        final inventory = Inventory(definitions: config.items);
        final rewardProcessor = RewardProcessor(
          character: character,
          inventory: inventory,
          items: config.items,
          lootTables: config.lootTables,
          equipmentFactory: EquipmentFactory(config.equipment),
        );
        const settlement = DungeonRewardSettlementService();
        final tracker = EncounterTracker(monsterCatalog: config.monsters);
        final manager = DungeonManager(
          dungeons: config.dungeons,
          encounterTracker: tracker,
        );
        final rng = math.Random(seed);

        manager.startDungeon('forgotten_forest');
        final startRoom = manager.activeRoom!;
        final grid = manager.activeGrid!;

        final sim =
            CombatSimulation(
              grid: grid,
              pathfinder: const AStarPathfinder(),
              player: Combatant(
                id: 'player',
                team: Team.player,
                stats: character.stats,
                cell: startRoom.entryPosition,
              ),
              reviveConfig: config.revive,
              damageCalculator: config.damage.createCalculator(),
              seed: seed,
            )..setPlayerSkills(
              character.activeSkills,
              runtimeStates: {
                for (final s in character.activeSkills)
                  s.id: character.skillRuntimeState(s.id),
              },
              skillAffinities: character.activeSkillAffinities,
            );

        tracker.onRoomLoaded(sim, grid: sim.grid);
        manager.activateRoom();
        tracker.onRoomActivated(sim, grid: sim.grid);

        var revives = 0;
        String? failedRoom;
        var appliedLevel = character.level;

        for (var i = 0; i < 6000; i++) {
          final curSession = manager.session!;
          if (curSession.isTerminal) break;

          if (curSession.roomLifecycle == RoomLifecycleState.completed) {
            manager.transitionToNextRoom();
            if (manager.hasActiveSession && manager.activeRoom != null) {
              final nextRoom = manager.activeRoom!;
              final nextGrid = manager.activeGrid!;
              sim.loadRoom(nextGrid, entryCell: nextRoom.entryPosition);
              tracker.onRoomLoaded(sim, grid: nextGrid);
              manager.activateRoom();
              tracker.onRoomActivated(sim, grid: nextGrid);
            }
            continue;
          }

          sim.tick();

          for (final ev in sim.drainEvents()) {
            if (ev is EnemyDefeatedEvent) {
              rewardProcessor.processEnemyDefeated(
                eventId: 'enemy:${ev.tick}:${ev.enemyId}',
                definition: ev.definition,
                random: rng,
              );
              tracker.onEnemyDefeated(
                ev.enemyId,
                simulation: sim,
                grid: sim.grid,
              );
            } else if (ev is PlayerRevivedEvent) {
              revives++;
            } else if (ev is RunEndedEvent) {
              failedRoom = manager.activeRoom?.id;
              tracker.onRunFailed();
              manager.endRun(
                finalStatus: DungeonSessionStatus.failed,
                reason: DungeonEndReason.defeated,
              );
            }
          }

          if (character.level != appliedLevel) {
            appliedLevel = character.level;
            sim.player.applyStats(character.stats);
            sim.setPlayerSkills(
              character.activeSkills,
              runtimeStates: {
                for (final s in character.activeSkills)
                  s.id: character.skillRuntimeState(s.id),
              },
              skillAffinities: character.activeSkillAffinities,
            );
          }

          if (manager.hasActiveSession &&
              manager.session!.roomLifecycle == RoomLifecycleState.active &&
              sim.playerStatus == PlayerStatus.alive) {
            final cell = sim.player.follower.currentCell;
            final eval = manager.evaluateCurrentRoom(playerCell: cell);
            if (eval.isCompleted) {
              final completedRoom = manager.activeRoom!;
              final completed = manager.tryCompleteActiveRoom(
                playerCell: cell,
                expectedRunId: curSession.runId,
                expectedRoomId: completedRoom.id,
              );
              if (completed) {
                settlement.settleRoomCompleted(
                  session: manager.session!,
                  room: completedRoom,
                  rewardProcessor: rewardProcessor,
                  random: rng,
                );
              }
            }
          }
        }

        return (
          completed: manager.session?.status == DungeonSessionStatus.completed,
          roomsCleared: manager.session?.clearedRoomIds.length ?? 0,
          endLevel: character.level,
          revivesUsed: revives,
          ticks: sim.currentTick,
          failedRoomId: failedRoom,
          endHp: sim.player.hp,
        );
      }

      // Audit progres nyata Level 1 -> Level 5 dengan config default:
      // - Fresh Level 1 tanpa gear konsisten menembus minimal Room 1–2 (mayoritas hingga Boss)
      //   tanpa error navigasi atau buntu di Room 1, sehingga meta loop EXP/loot berjalan alami.
      for (var s = 1; s <= 5; s++) {
        final lv1 = simulateRun(startLevel: 1, seed: s);
        expect(lv1.roomsCleared, greaterThanOrEqualTo(2));
        expect(lv1.endLevel, greaterThanOrEqualTo(3));
      }

      // Karakter dengan progres awal (Level >= 2 / hasil 1 run sebelumnya) mampu
      // menuntaskan seluruh Forgotten Forest (5/5 room).
      final lv2 = simulateRun(startLevel: 2, seed: 1);
      expect(lv2.completed, isTrue);
      expect(lv2.roomsCleared, 5);

      final lv4 = simulateRun(startLevel: 4, seed: 1);
      expect(lv4.completed, isTrue);
      expect(lv4.revivesUsed, 0);
    });
  });

  group('Stage 6 QA — Persistence Edge Cases & RNG Seed Isolation', () {
    testWidgets(
      '1) Keluar ke Town di tengah dungeon menandai run failed, menjaga progres room yang sudah selesai, dan restart tidak kembali ke run lama',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);

        final config = _loadRealGameConfig();

        Future<void> mount() async {
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
            if (find.byType(TownHubView).evaluate().isNotEmpty ||
                find.byType(HudOverlay).evaluate().isNotEmpty) {
              break;
            }
          }
          await tester.pump();
        }

        await mount();
        await tester.tap(find.text('Masuk Forgotten Forest'));
        await tester.pump();
        await tester.pump();

        final game = tester
            .widget<GameWidget<EchoesGame>>(find.byType(GameWidget<EchoesGame>))
            .game!;

        // Selesaikan Forest Entrance dan masuk ke Ancient Path.
        for (var i = 0; i < 150; i++) {
          game.update(0.2);
          await tester.pump();
          final pending = game.world.pendingRoomLoad;
          if (pending != null) {
            await pending;
            await tester.pump();
          }
          while (game.hasLifecycleEvents) {
            game.processLifecycleEvents();
          }
          if (game.world.mountedRoomId == 'ancient_path') {
            break;
          }
        }
        expect(game.world.mountedRoomId, 'ancient_path');

        // Tinggalkan dungeon melalui tombol 'Kembali ke Town' di menu kanan atas.
        await tester.tap(find.text('Kembali ke Town'));
        await tester.pump();
        await tester.runAsync(_flushAsyncDb);
        await tester.pump();

        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.text('Progres room tertinggi: 1 / 5'), findsOneWidget);
        expect(find.text('Total dungeon selesai: 0'), findsOneWidget);

        // Restart app -> tetap di Town, bukan masuk ke ancient_path yang sudah ditinggalkan.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await mount();

        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.text('Progres room tertinggi: 1 / 5'), findsOneWidget);
      },
    );

    testWidgets(
      '2) Aplikasi di-pause & ditutup di awal Room 1 (belum ada kill) memulihkan ke awal Room 1 dengan runId sama',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);

        final config = _loadRealGameConfig();

        Future<void> mount() async {
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
            if (find.byType(TownHubView).evaluate().isNotEmpty ||
                find.byType(HudOverlay).evaluate().isNotEmpty) {
              break;
            }
          }
          await tester.pump();
        }

        await mount();
        await tester.tap(find.text('Masuk Forgotten Forest'));
        await tester.pump();
        await tester.pump();

        final game1 = tester
            .widget<GameWidget<EchoesGame>>(find.byType(GameWidget<EchoesGame>))
            .game!;
        game1.update(0.2);
        await tester.pump();

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.runAsync(_flushAsyncDb);

        final snap1 = await tester.runAsync(
          () =>
              DriftPlayerSaveRepository(db: db, config: config).loadSnapshot(),
        );
        expect(snap1!.activeDungeonSession!.currentRoomId, 'forest_entrance');
        expect(
          snap1.activeDungeonSession!.status,
          DungeonSessionStatus.inProgress,
        );
        final runId = snap1.activeDungeonSession!.runId;

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await mount();

        expect(find.byType(GameWidget<EchoesGame>), findsOneWidget);
        expect(find.text('Forgotten Forest • Forest Entrance'), findsOneWidget);

        final game2 = tester
            .widget<GameWidget<EchoesGame>>(find.byType(GameWidget<EchoesGame>))
            .game!;
        expect(
          game2.world.simulation.player.follower.currentCell,
          const GridPoint(1, 5),
        );

        final snap2 = await tester.runAsync(
          () =>
              DriftPlayerSaveRepository(db: db, config: config).loadSnapshot(),
        );
        expect(snap2!.activeDungeonSession!.runId, runId);
      },
    );

    testWidgets(
      '3) Flame component cleanup tidak menggandakan DebugRoomComponent atau EnemyComponent di 5 transisi room Forgotten Forest',
      (tester) async {
        final base = _loadRealGameConfig();
        // Tingkatkan level karakter ke Lv 15 via reward progression agar run cepat menembus 5 room
        // sambil tetap memverifikasi cleanup komponen nyata & dungeon completion.
        final character = PlayerCharacter(
          config: base.progression,
          skillCatalog: base.skills,
          specializationConfig: base.specializations,
        )..receiveReward(exp: 50000);
        final manager = DungeonManager(
          dungeons: base.dungeons,
          encounterTracker: EncounterTracker(monsterCatalog: base.monsters),
        )..startDungeon('forgotten_forest');
        addTearDown(manager.dispose);

        final autoSkill = ValueNotifier<bool>(true);
        addTearDown(autoSkill.dispose);

        final game = EchoesGame(
          config: base,
          character: character,
          inventory: Inventory(definitions: base.items),
          autoSkill: autoSkill,
          dungeonManager: manager,
          roomTransitionDelaySeconds: 0.05,
          simulationSeed: 42,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: GameWidget<EchoesGame>(
              game: game,
              overlayBuilderMap: {
                'hud': (_, g) => HudOverlay(state: g.hud),
                'dungeon_completed': (_, _) => DungeonCompletedOverlay(
                  dungeonName: 'Forgotten Forest',
                  clearedRoomsCount: 5,
                  onRetry: () {},
                  onReturnToTown: () {},
                ),
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final visitedRooms = <String>{};
        for (var i = 0; i < 400; i++) {
          game.update(0.2);
          await tester.pump();
          final pending = game.world.pendingRoomLoad;
          if (pending != null) {
            await pending;
            await tester.pump();
          }
          while (game.hasLifecycleEvents) {
            game.processLifecycleEvents();
          }
          final mountedId = game.world.mountedRoomId;
          if (mountedId != null) {
            visitedRooms.add(mountedId);
            expect(
              game.world.children.whereType<DebugRoomComponent>().length,
              1,
              reason:
                  'Tidak boleh ada DebugRoomComponent duplikat pada room $mountedId',
            );
            expect(
              game.world.children.whereType<EnemyComponent>().length,
              lessThanOrEqualTo(game.world.simulation.aliveEnemies.length + 1),
            );
          }
          if (manager.session?.status == DungeonSessionStatus.completed) {
            break;
          }
        }

        expect(manager.session?.status, DungeonSessionStatus.completed);
        expect(visitedRooms, {
          'forest_entrance',
          'ancient_path',
          'ruined_shrine',
          'hidden_chamber',
          'ancient_heart',
        });
        while (game.hasLifecycleEvents) {
          game.processLifecycleEvents();
        }
        await tester.pump();
        expect(game.world.children.whereType<DebugRoomComponent>(), isEmpty);
        expect(game.world.children.whereType<EnemyComponent>(), isEmpty);
      },
    );

    testWidgets(
      '4) DungeonWorld mendukung simulationSeed deterministik untuk test dan berjalan normal tanpa seed di runtime',
      (tester) async {
        final base = _loadRealGameConfig();

        Future<List<int>> runTicksWithSeed(int? seed) async {
          final character = PlayerCharacter(
            config: base.progression,
            skillCatalog: base.skills,
            specializationConfig: base.specializations,
          );
          final manager = DungeonManager(
            dungeons: base.dungeons,
            encounterTracker: EncounterTracker(monsterCatalog: base.monsters),
          )..startDungeon('forgotten_forest');
          final autoSkill = ValueNotifier<bool>(false);
          final game = EchoesGame(
            config: base,
            character: character,
            inventory: Inventory(definitions: base.items),
            autoSkill: autoSkill,
            dungeonManager: manager,
            simulationSeed: seed,
          );

          await tester.pumpWidget(
            MaterialApp(
              home: GameWidget<EchoesGame>(
                game: game,
                overlayBuilderMap: {'hud': (_, g) => HudOverlay(state: g.hud)},
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          final damages = <int>[];
          for (var i = 0; i < 40; i++) {
            game.update(0.2);
            await tester.pump();
            for (final enemy in game.world.simulation.enemies) {
              damages.add(enemy.hp);
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          manager.dispose();
          autoSkill.dispose();
          return damages;
        }

        final seededA = await runTicksWithSeed(77);
        final seededB = await runTicksWithSeed(77);
        expect(seededA, seededB);

        final unseeded = await runTicksWithSeed(null);
        expect(unseeded, isNotEmpty);
      },
    );
  });
}
