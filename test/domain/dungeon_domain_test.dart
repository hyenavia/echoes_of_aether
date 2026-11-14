import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DungeonSession state transitions', () {
    test('mengizinkan transisi sesi yang valid secara berurutan', () {
      var session = const DungeonSession(
        runId: 'run_1',
        dungeonId: 'forgotten_forest',
        currentRoomId: 'forest_entrance',
        currentRoomIndex: 0,
      );
      expect(session.status, DungeonSessionStatus.notStarted);
      expect(session.isTerminal, isFalse);

      session = session.transitionSession(DungeonSessionStatus.inProgress);
      expect(session.status, DungeonSessionStatus.inProgress);

      session = session.transitionSession(
        DungeonSessionStatus.roomCompleted,
        clearedRoomIds: {'forest_entrance'},
      );
      expect(session.status, DungeonSessionStatus.roomCompleted);
      expect(session.isRoomCleared('forest_entrance'), isTrue);

      session = session.transitionSession(
        DungeonSessionStatus.inProgress,
        currentRoomId: 'ancient_path',
        currentRoomIndex: 1,
      );
      expect(session.currentRoomId, 'ancient_path');

      session = session.transitionSession(
        DungeonSessionStatus.completed,
        completionRewardClaimed: true,
      );
      expect(session.isTerminal, isTrue);
      expect(session.completionRewardClaimed, isTrue);
    });

    test('menolak transisi sesi yang tidak valid', () {
      const notStarted = DungeonSession(
        runId: 'run_1',
        dungeonId: 'forgotten_forest',
        currentRoomId: 'forest_entrance',
        currentRoomIndex: 0,
      );
      expect(
        () => notStarted.transitionSession(DungeonSessionStatus.completed),
        throwsStateError,
      );

      final completed = notStarted
          .transitionSession(DungeonSessionStatus.inProgress)
          .transitionSession(DungeonSessionStatus.completed);
      expect(
        () => completed.transitionSession(DungeonSessionStatus.inProgress),
        throwsStateError,
      );

      final failed = notStarted
          .transitionSession(DungeonSessionStatus.inProgress)
          .transitionSession(DungeonSessionStatus.failed);
      expect(
        () => failed.transitionSession(DungeonSessionStatus.completed),
        throwsStateError,
      );
    });
  });

  group('RoomLifecycleState transitions', () {
    test('mengikuti siklus notLoaded -> loading -> ready -> active -> completing -> completed -> transitioning -> unloaded', () {
      var session = const DungeonSession(
        runId: 'run_1',
        dungeonId: 'forgotten_forest',
        currentRoomId: 'forest_entrance',
        currentRoomIndex: 0,
      );

      for (final next in [
        RoomLifecycleState.loading,
        RoomLifecycleState.ready,
        RoomLifecycleState.active,
        RoomLifecycleState.completing,
        RoomLifecycleState.completed,
        RoomLifecycleState.transitioning,
        RoomLifecycleState.unloaded,
      ]) {
        session = session.transitionRoom(next);
        expect(session.roomLifecycle, next);
      }

      // Dapat dimuat kembali untuk room berikutnya dari unloaded -> loading
      session = session.transitionRoom(RoomLifecycleState.loading);
      expect(session.roomLifecycle, RoomLifecycleState.loading);
    });

    test('menolak lompatan lifecycle ilegal', () {
      const session = DungeonSession(
        runId: 'run_1',
        dungeonId: 'forgotten_forest',
        currentRoomId: 'forest_entrance',
        currentRoomIndex: 0,
      );
      expect(
        () => session.transitionRoom(RoomLifecycleState.active),
        throwsStateError,
      );
      final ready = session
          .transitionRoom(RoomLifecycleState.loading)
          .transitionRoom(RoomLifecycleState.ready);
      expect(
        () => ready.transitionRoom(RoomLifecycleState.completed),
        throwsStateError,
      );
    });
  });

  group('SpawnStatModifier & DungeonDefinition helpers', () {
    test(
      'SpawnStatModifier menghitung multiplier dan bonus dengan batas aman',
      () {
        const base = CombatStats(maxHp: 100, atk: 10, def: 4, attackSpeed: 1.2);
        const mod = SpawnStatModifier(
          hpMultiplier: 1.5,
          atkMultiplier: 1.2,
          defBonus: 3,
        );
        final modified = mod.applyTo(base);
        expect(modified.maxHp, 150);
        expect(modified.atk, 12);
        expect(modified.def, 7);
        expect(modified.attackSpeed, 1.2);

        const identity = SpawnStatModifier();
        expect(identical(identity.applyTo(base), base), isTrue);
      },
    );

    test('RoomDefinition dan DungeonDefinition helper bekerja konsisten', () {
      const r1 = RoomDefinition(
        id: 'r1',
        dungeonId: 'd1',
        name: 'R1',
        type: RoomType.normal,
        mapRef: 'm1',
        layout: ['###', '#.#', '###'],
        entryPosition: GridPoint(1, 1),
        exitPosition: GridPoint(1, 1),
        spawns: [],
        completionCondition: RoomCompletionCondition(),
        nextRoomIds: ['r2'],
      );
      const r2 = RoomDefinition(
        id: 'r2',
        dungeonId: 'd1',
        name: 'R2',
        type: RoomType.boss,
        mapRef: 'm2',
        layout: ['###', '#.#', '###'],
        entryPosition: GridPoint(1, 1),
        exitPosition: GridPoint(1, 1),
        spawns: [],
        completionCondition: RoomCompletionCondition(
          type: RoomCompletionConditionType.defeatBoss,
        ),
      );
      const d = DungeonDefinition(
        id: 'd1',
        name: 'D1',
        biome: 'forest',
        startRoomId: 'r1',
        rooms: {'r1': r1, 'r2': r2},
        roomOrder: ['r1', 'r2'],
      );

      expect(r1.isFinalRoom, isFalse);
      expect(r1.primaryNextRoomId, 'r2');
      expect(r2.isFinalRoom, isTrue);
      expect(r2.primaryNextRoomId, isNull);
      expect(d.indexOfRoom('r1'), 0);
      expect(d.indexOfRoom('r2'), 1);
      expect(d.roomById('missing'), isNull);
      expect(r1.createNavigationGrid().isWalkable(1, 1), isTrue);
    });
  });
}
