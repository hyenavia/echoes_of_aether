import 'dart:math' as math;

import '../entities/boss_event.dart';
import '../entities/cycle_progress.dart';
import '../entities/dungeon_definition.dart';
import '../entities/dungeon_reward.dart';
import '../entities/game_config.dart';
import '../entities/grid_point.dart';
import '../entities/player_save_snapshot.dart';
import 'period_service.dart';

/// Layanan domain murni untuk rotasi Daily/Weekly Boss Event, resolusi dungeon
/// acuan kesulitan, dan pembangunan [DungeonDefinition] satu ruangan saat
/// runtime.
class BossEventService {
  const BossEventService(this.config);

  final BossEventsConfig config;

  static const String bossArenaRoomId = 'boss_arena';

  static String bossDungeonId(Period period, String bossId) =>
      'boss_${period.name}:$bossId';

  /// Memilih boss secara deterministik dari pool berdasarkan `periodIndex`.
  BossEvent bossFor(Period period, int periodIndex) {
    final pool = config.tierFor(period).pool;
    if (pool.isEmpty) {
      throw StateError(
        'Pool boss untuk periode ${period.name} tidak boleh kosong.',
      );
    }
    final index = ((periodIndex % pool.length) + pool.length) % pool.length;
    return pool[index];
  }

  /// Menyelesaikan dungeon acuan kekuatan boss:
  /// dungeon normal dengan `order` tertinggi yang `clearedInCycleRank` sama
  /// dengan `cycle.ascensionRank` terpilih (default Dungeon 1 bila belum ada).
  BossReference resolveReference(
    CycleProgress cycle,
    Map<String, DungeonProgressSnapshot> progresses,
    Map<String, DungeonDefinition> dungeons,
  ) {
    final selectedRank = math.max(0, cycle.ascensionRank);
    final normals = dungeons.values.where((d) => d.isNormal).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    if (normals.isEmpty) {
      throw StateError('Tidak ada dungeon normal untuk acuan Boss Event.');
    }

    var resolved = normals.first;
    for (final dungeon in normals) {
      final clearedRank = progresses[dungeon.id]?.clearedInCycleRank ?? -1;
      if (clearedRank == selectedRank) {
        resolved = dungeon;
      }
    }

    return BossReference(dungeon: resolved, cycleRank: selectedRank);
  }

  /// Membangun [DungeonDefinition] satu ruangan (arena boss) saat runtime
  /// tanpa mengubah `dungeons.json`.
  DungeonDefinition buildBossDungeon({
    required BossEvent boss,
    required Period period,
    required BossReference reference,
    required List<String> arenaLayout,
    String? dungeonId,
  }) {
    if (arenaLayout.isEmpty) {
      throw ArgumentError.value(
        arenaLayout,
        'arenaLayout',
        'Layout arena boss tidak boleh kosong.',
      );
    }

    final resolvedId = dungeonId ?? bossDungeonId(period, boss.id);
    final kind = period == Period.daily
        ? DungeonKind.bossDaily
        : DungeonKind.bossWeekly;

    final room = RoomDefinition(
      id: bossArenaRoomId,
      dungeonId: resolvedId,
      name: boss.name,
      type: RoomType.boss,
      mapRef: config.arenaMapRef,
      layout: arenaLayout,
      entryPosition: const GridPoint(1, 6),
      exitPosition: const GridPoint(22, 6),
      completionCondition: const RoomCompletionCondition(
        type: RoomCompletionConditionType.defeatBoss,
      ),
      spawns: [
        RoomSpawnConfig(
          id: 'boss_spawn_${boss.id}',
          monsterId: boss.id,
          position: const GridPoint(17, 6),
          quantity: 1,
          spawnGroup: 'boss_event',
          isBoss: true,
          required: true,
        ),
      ],
    );

    return DungeonDefinition(
      id: resolvedId,
      name: boss.name,
      biome: reference.dungeon.biome,
      kind: kind,
      order: 1,
      recommendedLevel: reference.dungeon.recommendedLevel,
      difficultyScale: reference.dungeon.difficultyScale,
      startRoomId: bossArenaRoomId,
      roomOrder: const [bossArenaRoomId],
      rooms: {bossArenaRoomId: room},
      completionReward: const DungeonCompletionReward(),
    );
  }

  /// Mengambil layout arena boss dari `config.mapLayouts`, atau fallback ke
  /// ruangan di `config.dungeons` yang memakai `arenaMapRef`.
  static List<String>? resolveArenaLayout(GameConfig gameConfig) {
    final mapRef = gameConfig.bossEvents?.arenaMapRef;
    if (mapRef == null || mapRef.trim().isEmpty) return null;
    final fromMaps = gameConfig.mapLayouts[mapRef];
    if (fromMaps != null && fromMaps.isNotEmpty) return fromMaps;

    for (final dungeon in gameConfig.dungeons.values) {
      for (final room in dungeon.rooms.values) {
        if (room.mapRef == mapRef && room.layout.isNotEmpty) {
          return room.layout;
        }
      }
    }
    return null;
  }
}
