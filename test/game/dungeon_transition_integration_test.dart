import 'dart:io';

import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_completed_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/hud_overlay.dart';
import 'package:echoes_of_aether/game/components/enemies/enemy_component.dart';
import 'package:echoes_of_aether/game/echoes_game.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:echoes_of_aether/game/overlays.dart';
import 'package:echoes_of_aether/game/world/debug_room_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadStrongRealConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final base = GameConfig(
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
  const GameConfigValidator().validate(base);
  return GameConfig(
    monsters: base.monsters,
    revive: base.revive,
    progression: const ProgressionConfig(
      maxLevel: 30,
      expBase: 50000, // hindari efek samping level-up di tengah assert cepat
      expGrowth: 1.4,
      baseStats: CombatStats(
        maxHp: 2000,
        atk: 450,
        def: 50,
        attackSpeed: 4.0,
        moveSpeed: 10,
        attackRange: 3.0,
      ),
      perLevel: LevelGrowth(hp: 20, atk: 5, def: 2),
    ),
    equipment: base.equipment,
    dungeonCompletion: base.dungeonCompletion,
    items: base.items,
    lootTables: base.lootTables,
    skills: base.skills,
    specializations: base.specializations,
    dungeons: base.dungeons,
  );
}

void main() {
  group('Stage 4 Integration — Automatic Room Transition & Dungeon Completion', () {
    testWidgets(
      'Forgotten Forest berjalan otomatis dari Forest Entrance ke Ancient Heart hingga Dungeon Selesai',
      (tester) async {
        final config = _loadStrongRealConfig();
        final character = PlayerCharacter(
          config: config.progression,
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
        );
        final inventory = Inventory(definitions: config.items);
        final tracker = EncounterTracker(monsterCatalog: config.monsters);
        final manager = DungeonManager(
          dungeons: config.dungeons,
          encounterTracker: tracker,
          runIdGenerator: () => 'run_ff_full',
        );
        final events = <DungeonRuntimeEvent>[];
        manager.addListener(events.add);

        manager.startDungeon('forgotten_forest');

        final game = EchoesGame(
          config: config,
          character: character,
          inventory: inventory,
          autoSkill: ValueNotifier(true),
          dungeonManager: manager,
          roomTransitionDelaySeconds: 0.4,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GameWidget<EchoesGame>(
                game: game,
                overlayBuilderMap: {
                  GameOverlays.dungeonCompleted: (_, _) =>
                      DungeonCompletedOverlay(
                        dungeonName: 'Forgotten Forest',
                        clearedRoomsCount:
                            manager.session?.clearedRoomIds.length ?? 0,
                        onRetry: () {},
                        onReturnToTown: () {},
                      ),
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final visitedRooms = <String>[manager.activeRoom!.id];
        // Jalankan simulasi + frame pump hingga dungeon selesai atau batas aman tercapai.
        for (var i = 0; i < 400; i++) {
          game.update(0.2);
          await tester.pump();
          final pending = game.world.pendingRoomLoad;
          if (pending != null) {
            await pending;
            await tester.pump();
          }
          final activeId = manager.activeRoom?.id;
          if (activeId != null && visitedRooms.last != activeId) {
            visitedRooms.add(activeId);
          }
          if (manager.session?.status == DungeonSessionStatus.completed) {
            break;
          }
        }

        expect(visitedRooms, const [
          'forest_entrance',
          'ancient_path',
          'ruined_shrine',
          'hidden_chamber',
          'ancient_heart',
        ]);
        expect(manager.session?.status, DungeonSessionStatus.completed);
        expect(manager.session?.clearedRoomIds, {
          'forest_entrance',
          'ancient_path',
          'ruined_shrine',
          'hidden_chamber',
          'ancient_heart',
        });
        expect(manager.activeRoom, isNull);
        expect(events.whereType<RoomCompletedEvent>(), hasLength(5));
        expect(events.whereType<RoomTransitioningEvent>(), hasLength(4));
        expect(events.whereType<DungeonEndedEvent>(), hasLength(1));

        // Komponen musuh bersih setelah selesai dan overlay completion tampil.
        expect(game.world.children.whereType<EnemyComponent>(), isEmpty);
        expect(game.world.children.whereType<DebugRoomComponent>(), isEmpty);
        expect(game.overlays.isActive(GameOverlays.dungeonCompleted), isTrue);
        expect(find.text('Dungeon Selesai!'), findsOneWidget);
        expect(
          find.text('Forgotten Forest ditaklukkan (5 room selesai).'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'exit interaction wajib mengalahkan musuh dahulu sebelum membuka exit lalu pathfinding otomatis ke exitPosition',
      (tester) async {
        const walledLayout = <String>[
          '###########',
          '#....#....#',
          '#....#....#',
          '#.........#',
          '###########',
        ];
        final base = _loadStrongRealConfig();
        const r1 = RoomDefinition(
          id: 'gate_room',
          dungeonId: 'exit_test',
          name: 'Gate Room',
          type: RoomType.normal,
          mapRef: 'walled',
          layout: walledLayout,
          entryPosition: GridPoint(1, 1),
          exitPosition: GridPoint(9, 1),
          spawns: [
            RoomSpawnConfig(
              id: 'guard_1',
              monsterId: 'aether_slime',
              position: GridPoint(3, 1),
              required: true,
              statModifier: SpawnStatModifier(hpMultiplier: 20.0),
            ),
          ],
          completionCondition: RoomCompletionCondition(
            type: RoomCompletionConditionType.defeatRequiredEnemies,
            requireExit: true,
          ),
          nextRoomIds: ['end_room'],
        );
        const r2 = RoomDefinition(
          id: 'end_room',
          dungeonId: 'exit_test',
          name: 'End Room',
          type: RoomType.normal,
          mapRef: 'walled',
          layout: walledLayout,
          entryPosition: GridPoint(1, 1),
          exitPosition: GridPoint(9, 1),
          spawns: [],
          completionCondition: RoomCompletionCondition(
            type: RoomCompletionConditionType.reachExit,
          ),
          nextRoomIds: [],
        );
        final testDungeon = DungeonDefinition(
          id: 'exit_test',
          name: 'Exit Trial',
          biome: 'forest',
          startRoomId: 'gate_room',
          rooms: const {'gate_room': r1, 'end_room': r2},
          roomOrder: const ['gate_room', 'end_room'],
        );
        final cfg = GameConfig(
          monsters: base.monsters,
          revive: base.revive,
          progression: base.progression,
          items: base.items,
          lootTables: base.lootTables,
          skills: base.skills,
          specializations: base.specializations,
          dungeons: {'exit_test': testDungeon},
        );

        final character = PlayerCharacter(
          config: cfg.progression,
          skillCatalog: cfg.skills,
          specializationConfig: cfg.specializations,
        );
        final tracker = EncounterTracker(monsterCatalog: cfg.monsters);
        final manager = DungeonManager(
          dungeons: cfg.dungeons,
          encounterTracker: tracker,
        );
        manager.startDungeon('exit_test');

        final game = EchoesGame(
          config: cfg,
          character: character,
          inventory: Inventory(definitions: cfg.items),
          autoSkill: ValueNotifier(true),
          dungeonManager: manager,
          roomTransitionDelaySeconds: 0.2,
        );

        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump();
        await tester.pump();

        // Awalnya guard_1 masih hidup -> exit terkunci.
        game.update(0.05);
        await tester.pump();
        expect(game.hud.value.exitRequired, isTrue);
        expect(game.hud.value.exitUnlocked, isFalse);

        // Mencoba menempatkan player tepat di exitPosition saat musuh hidup
        // TIDAK boleh melewati syarat combat.
        game.world.simulation.player.follower.resetTo(r1.exitPosition);
        game.update(0.05);
        await tester.pump();
        expect(manager.activeRoom?.id, 'gate_room');
        expect(manager.session?.roomLifecycle, RoomLifecycleState.active);

        // Kembalikan ke posisi awal agar player bertarung lalu menavigasi
        // otomatis lewat celah bawah (# wall di kolom 5) menuju exit (9, 1).
        game.world.simulation.player.follower.resetTo(r1.entryPosition);
        for (var i = 0; i < 120; i++) {
          game.update(0.2);
          await tester.pump();
          final pending = game.world.pendingRoomLoad;
          if (pending != null) {
            await pending;
            await tester.pump();
          }
          if (manager.activeRoom?.id == 'end_room') break;
        }

        // Gate room selesai -> pindah ke end_room, lalu di end_room (reach_exit
        // tanpa musuh) player berjalan ke exitPosition -> dungeon completed!
        expect(manager.session?.clearedRoomIds, contains('gate_room'));

        for (var i = 0; i < 120; i++) {
          game.update(0.2);
          await tester.pump();
          final pending = game.world.pendingRoomLoad;
          if (pending != null) {
            await pending;
            await tester.pump();
          }
          if (manager.session?.status == DungeonSessionStatus.completed) break;
        }

        expect(manager.session?.status, DungeonSessionStatus.completed);
        expect(manager.session?.clearedRoomIds, {'gate_room', 'end_room'});
      },
    );

    testWidgets(
      'HudOverlay menampilkan status room, indikator exit, dan pesan transisi dengan rapi',
      (tester) async {
        final hud = ValueNotifier<HudState>(
          const HudState(
            level: 1,
            currentExp: 0,
            expToNext: 50,
            gold: 10,
            hp: 100,
            maxHp: 100,
            dungeonName: 'Forgotten Forest',
            roomName: 'Forest Entrance',
            roomStatus: 'Menuju Exit',
            exitRequired: true,
            exitUnlocked: true,
            transitionMessage: 'Room selesai! Menuju Ancient Path...',
            activeEnemies: 0,
            totalEnemies: 3,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: HudOverlay(state: hud)),
          ),
        );

        expect(find.text('Forgotten Forest • Forest Entrance'), findsOneWidget);
        expect(find.text('Musuh: 0/3'), findsOneWidget);
        expect(find.text('Status: Menuju Exit'), findsOneWidget);
        expect(find.text('Exit: Terbuka'), findsOneWidget);
        expect(
          find.text('Room selesai! Menuju Ancient Path...'),
          findsOneWidget,
        );
      },
    );
  });
}
