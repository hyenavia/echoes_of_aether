import 'dart:math' as math;

import '../entities/boss_spire.dart';
import '../entities/dungeon_definition.dart';
import '../entities/dungeon_reward.dart';
import '../entities/game_config.dart';
import '../entities/grid_point.dart';
import '../entities/player_character.dart';
import 'currency_service.dart';

/// Layanan manajemen tantangan Menara Bos (Boss Spire).
class BossSpireService {
  const BossSpireService(this.config);

  final BossSpireConfig config;

  static const String aetherShardCurrencyId = 'aether_shard';

  /// Menghitung progres lantai pemain berdasarkan set [claimedEventIds] pada siklus [cycleKey].
  BossSpireProgress getProgress(
    Set<String> claimedEventIds, {
    String? cycleKey,
  }) {
    return BossSpireProgress.fromClaimedEventIds(
      claimedEventIds,
      maxFloor: config.maxFloor,
      cycleKey: cycleKey,
    );
  }

  /// Membangun [DungeonDefinition] satu ruangan (arena boss lantai spire) saat runtime.
  DungeonDefinition buildFloorDungeon({
    required BossSpireFloorConfig floor,
    required List<String> arenaLayout,
  }) {
    if (arenaLayout.isEmpty) {
      throw ArgumentError.value(
        arenaLayout,
        'arenaLayout',
        'Layout arena Menara Bos tidak boleh kosong.',
      );
    }

    final roomId = 'spire_floor_${floor.floor}_room';
    final room = RoomDefinition(
      id: roomId,
      dungeonId: floor.dungeonId,
      name: floor.name,
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
          id: 'spire_boss_spawn_${floor.floor}',
          monsterId: floor.bossId,
          position: const GridPoint(17, 6),
          quantity: 1,
          spawnGroup: 'boss_spire',
          isBoss: true,
          required: true,
        ),
      ],
    );

    return DungeonDefinition(
      id: floor.dungeonId,
      name: floor.name,
      biome: 'ancient_heart',
      kind: DungeonKind.bossSpire,
      order: floor.floor,
      recommendedLevel: floor.recommendedLevel,
      difficultyScale: 1.0,
      startRoomId: roomId,
      roomOrder: [roomId],
      rooms: {roomId: room},
      completionReward: const DungeonCompletionReward(),
    );
  }

  /// Memproses klaim hadiah kemenangan di lantai Menara Bos secara atomik dan idempoten.
  BossSpireSettlementResult settleFloorVictory({
    required int floorNumber,
    required PlayerCharacter character,
    required CurrencyService currencyService,
    required Set<String> claimedEventIds,
    String? cycleKey,
  }) {
    final floorConfig = config.floorFor(floorNumber);
    if (floorConfig == null) {
      throw ArgumentError.value(
        floorNumber,
        'floorNumber',
        'Lantai $floorNumber tidak terdaftar di Menara Bos.',
      );
    }

    final cid = cycleKey != null
        ? floorConfig.claimIdFor(cycleKey)
        : floorConfig.claimId;
    final alreadyClaimed =
        claimedEventIds.contains(cid) ||
        (cycleKey == '2026-11-16' &&
            claimedEventIds.contains(floorConfig.claimId));

    if (alreadyClaimed) {
      return BossSpireSettlementResult(
        floor: floorNumber,
        isFirstClear: false,
        reward: floorConfig.firstClearReward,
        userMessage:
            'Lantai $floorNumber telah diselesaikan! (Hadiah siklus ini telah diklaim)',
        claimId: cid,
      );
    }

    final reward = floorConfig.firstClearReward;

    // 1. Berikan mata uang khusus (misal Aether Shard).
    final shards = reward.currency[aetherShardCurrencyId] ?? 0;
    if (shards > 0) {
      currencyService.grant(aetherShardCurrencyId, shards, claimId: cid);
    }

    // 2. Berikan EXP & Gold ke karakter.
    character.receiveReward(
      exp: math.max(0, reward.exp),
      gold: math.max(0, reward.gold),
    );

    // 3. Catat ID klaim di riwayat pemain.
    claimedEventIds.add(cid);

    final shardMsg = shards > 0 ? ', +$shards Aether Shard' : '';
    return BossSpireSettlementResult(
      floor: floorNumber,
      isFirstClear: true,
      reward: reward,
      userMessage:
          'Lantai $floorNumber Selesai!\nHadiah Pertama: +${reward.exp} EXP, +${reward.gold} Gold$shardMsg',
      claimId: cid,
    );
  }

  /// Mengambil layout arena dari `config.mapLayouts` atau fallback ke ruangan `ancient_heart_map`.
  static List<String>? resolveArenaLayout(GameConfig gameConfig) {
    final mapRef =
        gameConfig.bossSpire?.arenaMapRef ??
        gameConfig.bossEvents?.arenaMapRef ??
        'ancient_heart_map';

    if (mapRef.trim().isEmpty) return null;
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
