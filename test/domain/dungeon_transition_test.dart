import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/room_encounter.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const layout = <String>[
    '###########',
    '#.........#',
    '#.........#',
    '###########',
  ];

  const monsters = <String, EnemyDefinition>{
    'aether_slime': EnemyDefinition(
      id: 'aether_slime',
      name: 'Aether Slime',
      level: 1,
      stats: CombatStats(maxHp: 40, atk: 4, def: 1),
    ),
    'ancient_heart_guardian': EnemyDefinition(
      id: 'ancient_heart_guardian',
      name: 'Ancient Heart Guardian',
      level: 6,
      isBoss: true,
      stats: CombatStats(maxHp: 300, atk: 15, def: 4),
    ),
  };

  CombatSimulation makeSim(RoomDefinition room) {
    final player = Combatant(
      id: 'player',
      team: Team.player,
      stats: const CombatStats(maxHp: 200, atk: 30, def: 5, moveSpeed: 4),
      cell: room.entryPosition,
    );
    return CombatSimulation(
      grid: room.createNavigationGrid(),
      pathfinder: const AStarPathfinder(),
      player: player,
    );
  }

  DungeonDefinition makeLinearThreeRoomDungeon({
    String nextAfterOne = 'room_2',
    GridPoint? room2Entry,
  }) {
    const r1 = RoomDefinition(
      id: 'room_1',
      dungeonId: 'd1',
      name: 'Room 1',
      type: RoomType.normal,
      mapRef: 'm',
      layout: layout,
      entryPosition: GridPoint(1, 1),
      exitPosition: GridPoint(9, 1),
      spawns: [
        RoomSpawnConfig(
          id: 's1',
          monsterId: 'aether_slime',
          position: GridPoint(5, 1),
        ),
      ],
      completionCondition: RoomCompletionCondition(),
      nextRoomIds: [],
    );
    final r1WithNext = RoomDefinition(
      id: r1.id,
      dungeonId: r1.dungeonId,
      name: r1.name,
      type: r1.type,
      mapRef: r1.mapRef,
      layout: r1.layout,
      entryPosition: r1.entryPosition,
      exitPosition: r1.exitPosition,
      spawns: r1.spawns,
      completionCondition: r1.completionCondition,
      nextRoomIds: [nextAfterOne],
    );
    final r2 = RoomDefinition(
      id: 'room_2',
      dungeonId: 'd1',
      name: 'Room 2',
      type: RoomType.normal,
      mapRef: 'm',
      layout: layout,
      entryPosition: room2Entry ?? const GridPoint(1, 2),
      exitPosition: const GridPoint(9, 2),
      spawns: const [
        RoomSpawnConfig(
          id: 's2',
          monsterId: 'aether_slime',
          position: GridPoint(5, 2),
        ),
      ],
      completionCondition: const RoomCompletionCondition(
        type: RoomCompletionConditionType.defeatRequiredEnemies,
        requireExit: true,
      ),
      nextRoomIds: const ['room_3'],
    );
    const r3 = RoomDefinition(
      id: 'room_3',
      dungeonId: 'd1',
      name: 'Room 3 Boss',
      type: RoomType.boss,
      mapRef: 'm',
      layout: layout,
      entryPosition: GridPoint(1, 1),
      exitPosition: GridPoint(9, 1),
      spawns: [
        RoomSpawnConfig(
          id: 's3',
          monsterId: 'ancient_heart_guardian',
          position: GridPoint(7, 1),
          isBoss: true,
        ),
      ],
      completionCondition: RoomCompletionCondition(
        type: RoomCompletionConditionType.defeatBoss,
      ),
      nextRoomIds: [],
    );
    return DungeonDefinition(
      id: 'd1',
      name: 'Test Dungeon',
      biome: 'forest',
      startRoomId: 'room_1',
      rooms: {'room_1': r1WithNext, 'room_2': r2, 'room_3': r3},
      roomOrder: const ['room_1', 'room_2', 'room_3'],
    );
  }

  group('Room Lifecycle & Invalid Transitions', () {
    test('lifecycle loading -> ready -> active -> completing -> completed -> transitioning -> unloaded & menolak invalid transitions', () {
      const session = DungeonSession(
        runId: 'run_1',
        dungeonId: 'd1',
        currentRoomId: 'room_1',
        currentRoomIndex: 0,
        status: DungeonSessionStatus.inProgress,
        roomLifecycle: RoomLifecycleState.loading,
      );

      // Tidak bisa langsung dari loading -> active atau loading -> completed.
      expect(
        () => session.transitionRoom(RoomLifecycleState.active),
        throwsStateError,
      );
      expect(
        () => session.transitionRoom(RoomLifecycleState.completed),
        throwsStateError,
      );

      final ready = session.transitionRoom(RoomLifecycleState.ready);
      final active = ready.transitionRoom(RoomLifecycleState.active);
      final completing = active.transitionRoom(RoomLifecycleState.completing);
      final completed = completing.transitionRoom(RoomLifecycleState.completed);

      // Room completed tidak dapat kembali ke active.
      expect(
        () => completed.transitionRoom(RoomLifecycleState.active),
        throwsStateError,
      );

      final transitioning = completed.transitionRoom(
        RoomLifecycleState.transitioning,
      );
      final unloaded = transitioning.transitionRoom(
        RoomLifecycleState.unloaded,
      );
      expect(unloaded.roomLifecycle, RoomLifecycleState.unloaded);
    });

    test('cleanup (unloadCurrentRoom) tidak dihitung sebagai completion & room gagal aktivasi sebelum ready ditolak', () {
      final dungeon = makeLinearThreeRoomDungeon();
      final tracker = EncounterTracker(monsterCatalog: monsters);
      final manager = DungeonManager(
        dungeons: {'d1': dungeon},
        encounterTracker: tracker,
      );
      final events = <DungeonRuntimeEvent>[];
      manager.addListener(events.add);

      manager.startDungeon('d1');
      manager.unloadCurrentRoom();
      // Room belum aktif / baru dilepas tidak dapat diaktifkan maupun diselesaikan.
      expect(() => manager.activateRoom(), throwsStateError);
      expect(manager.tryCompleteActiveRoom(), isFalse);
      expect(manager.session?.clearedRoomIds, isEmpty);
      expect(events.whereType<RoomCompletedEvent>(), isEmpty);
      expect(events.whereType<DungeonEndedEvent>(), isEmpty);
    });
  });

  group(
    'Room Transition, Duplicate & Stale Event Guards, & Dungeon Completion',
    () {
      test('transisi linear antar-room, multi next_room_ids deterministik, serta guard duplikasi completion/transition', () {
        final dungeon = makeLinearThreeRoomDungeon();
        final tracker = EncounterTracker(monsterCatalog: monsters);
        final manager = DungeonManager(
          dungeons: {'d1': dungeon},
          encounterTracker: tracker,
          runIdGenerator: () => 'run_fixed',
        );
        final events = <DungeonRuntimeEvent>[];
        manager.addListener(events.add);

        manager.startDungeon('d1');
        final sim = makeSim(manager.activeRoom!);
        manager.activateRoom();
        tracker.onRoomActivated(sim, grid: manager.activeGrid!);

        // Belum kalah -> tidak bisa selesai atau transisi.
        expect(manager.tryCompleteActiveRoom(), isFalse);
        expect(manager.transitionToNextRoom(), isFalse);

        // Kalahkan musuh room_1.
        tracker.onEnemyDefeated(sim.enemies.single.id);
        expect(manager.tryCompleteActiveRoom(), isTrue);
        // Panggilan completion ganda diabaikan.
        expect(manager.tryCompleteActiveRoom(), isFalse);
        expect(manager.session?.roomLifecycle, RoomLifecycleState.completed);
        expect(manager.session?.status, DungeonSessionStatus.roomCompleted);
        expect(manager.session?.clearedRoomIds, {'room_1'});
        expect(events.whereType<RoomCompletedEvent>(), hasLength(1));

        // Transisi ke room_2.
        expect(manager.transitionToNextRoom(), isTrue);
        // Panggilan transisi ulang saat room_2 masih ready ditolak.
        expect(manager.transitionToNextRoom(), isFalse);
        expect(manager.activeRoom?.id, 'room_2');
        expect(manager.session?.status, DungeonSessionStatus.inProgress);
        expect(manager.session?.roomLifecycle, RoomLifecycleState.ready);

        // Stale event dari room_1 atau run lain ditolak pada room_2.
        expect(
          manager.handleEncounterEvent(
            const RoomEncountersCompletedEvent('room_1', []),
          ),
          isFalse,
        );
        expect(
          manager.tryCompleteActiveRoom(
            expectedRunId: 'old_run',
            expectedRoomId: 'room_2',
          ),
          isFalse,
        );

        // Aktifkan room_2 dan selesaikan combat + reach_exit.
        sim.loadRoom(
          manager.activeGrid!,
          entryCell: manager.activeRoom!.entryPosition,
        );
        manager.activateRoom();
        tracker.onRoomActivated(sim, grid: manager.activeGrid!);
        tracker.onEnemyDefeated(sim.enemies.single.id);

        // Combat selesai tetapi belum di exit -> belum selesai.
        expect(
          manager.tryCompleteActiveRoom(playerCell: const GridPoint(2, 2)),
          isFalse,
        );
        // Tiba di exitPosition -> selesai!
        expect(
          manager.tryCompleteActiveRoom(
            playerCell: manager.activeRoom!.exitPosition,
          ),
          isTrue,
        );
        expect(manager.transitionToNextRoom(), isTrue);
        expect(manager.activeRoom?.id, 'room_3');

        // Aktifkan room_3 (Boss final).
        sim.loadRoom(
          manager.activeGrid!,
          entryCell: manager.activeRoom!.entryPosition,
        );
        manager.activateRoom();
        tracker.onRoomActivated(sim, grid: manager.activeGrid!);
        tracker.onEnemyDefeated(sim.enemies.single.id);
        expect(manager.tryCompleteActiveRoom(), isTrue);

        // Dungeon selesai 1 kali tanpa mencoba memuat room berikutnya.
        expect(manager.session?.status, DungeonSessionStatus.completed);
        expect(manager.session?.clearedRoomIds, {'room_1', 'room_2', 'room_3'});
        expect(manager.activeRoom, isNull);
        final endedEvents = events.whereType<DungeonEndedEvent>().toList();
        expect(endedEvents, hasLength(1));
        expect(endedEvents.single.finalStatus, DungeonSessionStatus.completed);
        expect(endedEvents.single.effectiveReason, DungeonEndReason.completed);
        expect(endedEvents.single.dungeon?.id, 'd1');

        // Panggilan completion / transition setelah terminal diabaikan.
        expect(manager.tryCompleteActiveRoom(), isFalse);
        expect(manager.transitionToNextRoom(), isFalse);
        expect(events.whereType<DungeonEndedEvent>(), hasLength(1));
      });

      test('kebijakan multiple next_room_ids memilih room pertama yang belum dibersihkan secara deterministik', () {
        const multiBranchRoom = RoomDefinition(
          id: 'hub',
          dungeonId: 'd',
          name: 'Hub',
          type: RoomType.normal,
          mapRef: 'm',
          layout: layout,
          entryPosition: GridPoint(1, 1),
          exitPosition: GridPoint(9, 1),
          spawns: [],
          completionCondition: RoomCompletionCondition(
            type: RoomCompletionConditionType.reachExit,
          ),
          nextRoomIds: ['branch_a', 'branch_b'],
        );

        expect(
          multiBranchRoom.selectNextRoomId(clearedRoomIds: const {}),
          'branch_a',
        );
        expect(
          multiBranchRoom.selectNextRoomId(clearedRoomIds: const {'branch_a'}),
          'branch_b',
        );
        expect(
          multiBranchRoom.selectNextRoomId(
            clearedRoomIds: const {'branch_a', 'branch_b'},
          ),
          'branch_a',
        );
      });

      test('next room tidak ditemukan atau gagal load ditangani aman tanpa half-active state', () {
        final missingNext = makeLinearThreeRoomDungeon(
          nextAfterOne: 'ghost_room',
        );
        final tracker = EncounterTracker(monsterCatalog: monsters);
        final manager = DungeonManager(
          dungeons: {'d1': missingNext},
          encounterTracker: tracker,
        );
        final events = <DungeonRuntimeEvent>[];
        manager.addListener(events.add);

        manager.startDungeon('d1');
        final sim = makeSim(manager.activeRoom!);
        manager.activateRoom();
        tracker.onRoomActivated(sim, grid: manager.activeGrid!);
        tracker.onEnemyDefeated(sim.enemies.single.id);
        expect(manager.tryCompleteActiveRoom(), isTrue);

        expect(manager.transitionToNextRoom(), isFalse);
        expect(manager.activeRoom, isNull);
        expect(manager.session?.status, DungeonSessionStatus.failed);
        expect(events.whereType<RoomTransitionFailedEvent>(), hasLength(1));
        expect(
          events.whereType<DungeonEndedEvent>().single.finalStatus,
          DungeonSessionStatus.failed,
        );

        // Kasus gagal load room_2 (entry_position di wall (0, 0)).
        final brokenNext = makeLinearThreeRoomDungeon(
          room2Entry: const GridPoint(0, 0),
        );
        final tracker2 = EncounterTracker(monsterCatalog: monsters);
        final manager2 = DungeonManager(
          dungeons: {'d1': brokenNext},
          encounterTracker: tracker2,
        );
        final events2 = <DungeonRuntimeEvent>[];
        manager2.addListener(events2.add);

        manager2.startDungeon('d1');
        final sim2 = makeSim(manager2.activeRoom!);
        manager2.activateRoom();
        tracker2.onRoomActivated(sim2, grid: manager2.activeGrid!);
        tracker2.onEnemyDefeated(sim2.enemies.single.id);
        manager2.tryCompleteActiveRoom();

        expect(manager2.transitionToNextRoom(), isFalse);
        expect(manager2.activeRoom, isNull);
        expect(manager2.session?.roomLifecycle, RoomLifecycleState.unloaded);
        expect(manager2.session?.status, DungeonSessionStatus.failed);
        expect(events2.whereType<RoomTransitionFailedEvent>(), hasLength(1));
      });
    },
  );
}
