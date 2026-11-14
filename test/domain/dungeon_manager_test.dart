import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/skill_runtime_state.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const openLayout = <String>[
    '#######',
    '#.....#',
    '#.....#',
    '#.....#',
    '#######',
  ];

  const largerLayout = <String>[
    '#########',
    '#.......#',
    '#..#....#',
    '#.......#',
    '#.......#',
    '#########',
  ];

  DungeonDefinition makeDungeon() {
    const room1 = RoomDefinition(
      id: 'forest_entrance',
      dungeonId: 'forgotten_forest',
      name: 'Forest Entrance',
      type: RoomType.normal,
      mapRef: 'forest_entrance_map',
      layout: openLayout,
      entryPosition: GridPoint(1, 2),
      exitPosition: GridPoint(5, 2),
      spawns: [
        RoomSpawnConfig(
          id: 'spawn_1',
          monsterId: 'aether_slime',
          position: GridPoint(3, 2),
        ),
      ],
      completionCondition: RoomCompletionCondition(),
      nextRoomIds: ['ancient_path'],
    );
    const room2 = RoomDefinition(
      id: 'ancient_path',
      dungeonId: 'forgotten_forest',
      name: 'Ancient Path',
      type: RoomType.normal,
      mapRef: 'ancient_path_map',
      layout: largerLayout,
      entryPosition: GridPoint(1, 3),
      exitPosition: GridPoint(7, 3),
      spawns: [
        RoomSpawnConfig(
          id: 'spawn_2',
          monsterId: 'forest_wolf',
          position: GridPoint(5, 3),
        ),
      ],
      completionCondition: RoomCompletionCondition(),
      nextRoomIds: [],
    );

    return const DungeonDefinition(
      id: 'forgotten_forest',
      name: 'Forgotten Forest',
      biome: 'Forest',
      startRoomId: 'forest_entrance',
      rooms: {'forest_entrance': room1, 'ancient_path': room2},
      roomOrder: ['forest_entrance', 'ancient_path'],
    );
  }

  group('DungeonManager orchestration & room loading', () {
    test('startDungeon memulai sesi inProgress, memuat room awal, dan mengeluarkan event', () {
      final manager = DungeonManager(
        dungeons: {'forgotten_forest': makeDungeon()},
        runIdGenerator: () => 'run_1',
      );
      final events = <DungeonRuntimeEvent>[];
      manager.addListener(events.add);

      final session = manager.startDungeon('forgotten_forest');

      expect(session.runId, 'run_1');
      expect(session.dungeonId, 'forgotten_forest');
      expect(session.currentRoomId, 'forest_entrance');
      expect(session.currentRoomIndex, 0);
      expect(session.status, DungeonSessionStatus.inProgress);
      expect(session.roomLifecycle, RoomLifecycleState.ready);
      expect(manager.activeDungeon?.id, 'forgotten_forest');
      expect(manager.activeRoom?.id, 'forest_entrance');
      expect(manager.activeGrid?.columns, 7);
      expect(manager.activeGrid?.rows, 5);
      expect(manager.preparedSpawns, hasLength(1));

      expect(events.map((e) => e.runtimeType).toList(), [
        DungeonStartedEvent,
        RoomLoadingEvent,
        RoomLoadedEvent,
      ]);

      manager.activateRoom();
      expect(manager.session?.roomLifecycle, RoomLifecycleState.active);
      expect(events.last, isA<RoomActivatedEvent>());
    });

    test(
      'startDungeon menolak dungeon ID yang tidak ada dan mencegah sesi ganda',
      () {
        final manager = DungeonManager(
          dungeons: {'forgotten_forest': makeDungeon()},
        );

        expect(
          () => manager.startDungeon('unknown_dungeon'),
          throwsArgumentError,
        );
        expect(manager.session, isNull);

        manager.startDungeon('forgotten_forest');
        expect(
          () => manager.startDungeon('forgotten_forest'),
          throwsStateError,
        );
      },
    );

    test('loadRoom melepas room sebelumnya, memuat room berikutnya, dan idempotent jika room sama sudah dimuat', () {
      final manager = DungeonManager(
        dungeons: {'forgotten_forest': makeDungeon()},
      );
      manager.startDungeon('forgotten_forest');
      manager.activateRoom();

      final events = <DungeonRuntimeEvent>[];
      manager.addListener(events.add);

      // Panggilan ulang ke room aktif yang sama tidak memicu reload ganda.
      final sameRoom = manager.loadRoom('forest_entrance');
      expect(sameRoom.id, 'forest_entrance');
      expect(events, isEmpty);

      // Pindah ke ancient_path melepas forest_entrance terlebih dahulu.
      final nextRoom = manager.loadRoom('ancient_path');
      expect(nextRoom.id, 'ancient_path');
      expect(manager.session?.currentRoomId, 'ancient_path');
      expect(manager.session?.currentRoomIndex, 1);
      expect(manager.session?.roomLifecycle, RoomLifecycleState.ready);
      expect(manager.activeGrid?.columns, 9);
      expect(manager.activeGrid?.rows, 6);
      expect(manager.preparedSpawns.single.id, 'spawn_2');

      expect(events.map((e) => e.runtimeType).toList(), [
        RoomUnloadedEvent,
        RoomLoadingEvent,
        RoomLoadedEvent,
      ]);
      expect((events.first as RoomUnloadedEvent).roomId, 'forest_entrance');
    });

    test('loadRoom menangani room tidak dikenal dan entry point non-walkable secara aman', () {
      final brokenRoom = const RoomDefinition(
        id: 'broken_room',
        dungeonId: 'broken',
        name: 'Broken Room',
        type: RoomType.normal,
        mapRef: 'broken_map',
        layout: openLayout,
        entryPosition: GridPoint(0, 0), // wall!
        exitPosition: GridPoint(5, 2),
        spawns: [],
        completionCondition: RoomCompletionCondition(),
      );
      final brokenDungeon = DungeonDefinition(
        id: 'broken',
        name: 'Broken',
        biome: 'Forest',
        startRoomId: 'broken_room',
        rooms: {'broken_room': brokenRoom},
        roomOrder: const ['broken_room'],
      );

      final manager = DungeonManager(
        dungeons: {'forgotten_forest': makeDungeon(), 'broken': brokenDungeon},
      );
      manager.startDungeon('forgotten_forest');

      expect(() => manager.loadRoom('missing_room'), throwsArgumentError);
      expect(manager.activeRoom?.id, 'forest_entrance');

      manager.exitToTown();
      expect(() => manager.startDungeon('broken'), throwsStateError);
      expect(manager.activeRoom, isNull);
      expect(manager.activeGrid, isNull);
      expect(manager.session?.roomLifecycle, RoomLifecycleState.unloaded);
    });

    test('endRun dan exitToTown membersihkan resource serta listener aman saat dispose', () {
      final manager = DungeonManager(
        dungeons: {'forgotten_forest': makeDungeon()},
      );
      final events = <DungeonRuntimeEvent>[];
      manager.addListener(events.add);

      manager.startDungeon('forgotten_forest');
      final ended = manager.endRun(finalStatus: DungeonSessionStatus.failed);

      expect(ended.isTerminal, isTrue);
      expect(ended.status, DungeonSessionStatus.failed);
      expect(ended.roomLifecycle, RoomLifecycleState.unloaded);
      expect(manager.activeRoom, isNull);
      expect(events.whereType<RoomUnloadedEvent>(), hasLength(1));
      expect(events.whereType<DungeonEndedEvent>(), hasLength(1));

      // Idempotent pada sesi terminal.
      final endedAgain = manager.endRun(
        finalStatus: DungeonSessionStatus.failed,
      );
      expect(endedAgain.status, DungeonSessionStatus.failed);

      manager.dispose();
      expect(manager.session, isNull);
      expect(manager.activeDungeon, isNull);
    });
  });

  group('CombatSimulation.loadRoom state preservation', () {
    test('mempertahankan HP, stats, skill cooldown, dan revive cooldown sambil mereset navigasi & musuh', () {
      final gridA = NavigationGrid.fromAscii(openLayout);
      final gridB = NavigationGrid.fromAscii(largerLayout);

      const powerStrike = SkillDefinition(
        id: 'power_strike',
        name: 'Power Strike',
        type: SkillType.active,
        effect: SkillEffectType.damage,
        damageType: SkillDamageType.physical,
        cooldownSeconds: 5.0,
        baseValue: 1.5,
        valuePerLevel: 0.2,
        maxLevel: 5,
        unlockLevel: 1,
        targetType: SkillTarget.single,
      );

      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: const CombatStats(
          maxHp: 200,
          atk: 20,
          def: 5,
          attackSpeed: 1,
          moveSpeed: 4,
          attackRange: 1.5,
        ),
        cell: const GridPoint(1, 2),
      );

      final sim =
          CombatSimulation(
            grid: gridA,
            pathfinder: const AStarPathfinder(),
            player: player,
            seed: 7,
          )..setPlayerSkills(
            const [powerStrike],
            runtimeStates: const {
              'power_strike': SkillRuntimeState(
                skillId: 'power_strike',
                level: 3,
                unlocked: true,
                cooldownTicksRemaining: 42,
              ),
            },
          );

      const slime = EnemyDefinition(
        id: 'aether_slime',
        name: 'Aether Slime',
        level: 1,
        detectionRange: 6,
        stats: CombatStats(maxHp: 50, atk: 5, def: 0, attackRange: 1),
      );
      final enemy = sim.spawnEnemy(slime, const GridPoint(4, 2));
      player.hp = 123;
      player.invulnerableTicks = 10;
      player.targetId = enemy.id;
      player.plannedGoal = const GridPoint(3, 2);
      player.follower.setPath(const [
        GridPoint(1, 2),
        GridPoint(2, 2),
        GridPoint(3, 2),
      ]);
      sim.tick();
      expect(sim.currentTick, 1);

      sim.loadRoom(gridB, entryCell: const GridPoint(1, 3));

      expect(sim.grid, same(gridB));
      expect(sim.enemies, isEmpty);
      expect(sim.drainEvents(), isEmpty);
      expect(player.follower.currentCell, const GridPoint(1, 3));
      expect(player.follower.isMoving, isFalse);
      expect(player.targetId, isNull);
      expect(player.plannedGoal, isNull);

      // State lintas-room dipertahankan.
      expect(player.hp, 123);
      expect(player.stats.maxHp, 200);
      expect(player.invulnerableTicks, 9);
      expect(sim.skillState('power_strike')?.level, 3);
      expect(sim.skillCooldownTicks('power_strike'), 41);
      expect(sim.currentTick, 1);

      // Entry point tidak walkable ditolak tanpa merusak grid aktif.
      expect(
        () => sim.loadRoom(gridA, entryCell: const GridPoint(0, 0)),
        throwsArgumentError,
      );
      expect(sim.grid, same(gridB));
    });

    test(
      'reviveCooldownTicks dipertahankan saat berpindah room dalam satu run',
      () {
        final gridA = NavigationGrid.fromAscii(openLayout);
        final gridB = NavigationGrid.fromAscii(largerLayout);

        final player = Combatant(
          id: 'player',
          team: Team.player,
          stats: const CombatStats(
            maxHp: 10,
            atk: 0,
            def: 0,
            attackSpeed: 1,
            moveSpeed: 0,
            attackRange: 1,
          ),
          cell: const GridPoint(2, 2),
        );
        final sim = CombatSimulation(
          grid: gridA,
          pathfinder: const AStarPathfinder(),
          player: player,
          seed: 1,
        );
        const bossSlime = EnemyDefinition(
          id: 'lethal_slime',
          name: 'Lethal Slime',
          level: 1,
          detectionRange: 5,
          stats: CombatStats(
            maxHp: 100,
            atk: 50,
            def: 0,
            attackSpeed: 1,
            moveSpeed: 0,
            attackRange: 2,
          ),
        );
        sim.spawnEnemy(bossSlime, const GridPoint(3, 2));

        // Picu downed lalu tunggu auto-revive (3 detik = 60 tick) hingga cooldown 90s aktif.
        for (var i = 0; i < 65; i++) {
          sim.tick();
        }
        final cooldownBeforeMove = sim.reviveCooldownTicks;
        expect(cooldownBeforeMove, greaterThan(0));
        expect(sim.isReviveAvailable, isFalse);

        sim.loadRoom(gridB, entryCell: const GridPoint(1, 3));
        expect(sim.reviveCooldownTicks, cooldownBeforeMove);
        expect(sim.isReviveAvailable, isFalse);
      },
    );
  });
}
