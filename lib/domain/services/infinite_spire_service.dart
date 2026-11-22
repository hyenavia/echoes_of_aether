import 'dart:math' as math;

import '../entities/dungeon_definition.dart';
import '../entities/dungeon_reward.dart';
import '../entities/game_config.dart';
import '../entities/grid_point.dart';
import '../entities/infinite_spire.dart';
import '../entities/inventory.dart';
import '../entities/player_character.dart';
import 'currency_service.dart';
import 'period_service.dart';

/// Info tantangan mingguan (Weekly Spire Boss Rush) berbasis [PeriodService].
class WeeklySpireBossRushInfo {
  const WeeklySpireBossRushInfo({
    required this.isUnlocked,
    required this.periodKey,
    required this.nextResetMs,
    required this.claimId,
    required this.isCompletedThisWeek,
    required this.reward,
    this.featuredFloor,
  });

  final bool isUnlocked;
  final String periodKey;
  final int nextResetMs;
  final String claimId;
  final bool isCompletedThisWeek;
  final InfiniteSpireReward reward;
  final InfiniteSpireFloorDefinition? featuredFloor;
}

/// Hasil klaim bonus Tantangan Bos Mingguan di The Infinite Spire.
class WeeklySpireBossRushSettlement {
  const WeeklySpireBossRushSettlement({
    required this.claimed,
    required this.claimId,
    required this.periodKey,
    required this.reward,
  });

  final bool claimed;
  final String claimId;
  final String periodKey;
  final InfiniteSpireReward reward;
}

/// Hasil eksekusi penyelesaian lantai The Infinite Spire.
class InfiniteSpireSettlementResult {
  const InfiniteSpireSettlementResult({
    required this.floor,
    required this.isFirstClear,
    required this.reward,
    required this.updatedProgress,
    required this.userMessage,
    required this.claimId,
    this.weeklyBonusClaimed = false,
    this.weeklyBonusClaimId,
    this.weeklyBonusReward,
  });

  final int floor;
  final bool isFirstClear;
  final InfiniteSpireReward reward;
  final InfiniteSpireProgressSnapshot updatedProgress;
  final String userMessage;
  final String claimId;
  final bool weeklyBonusClaimed;
  final String? weeklyBonusClaimId;
  final InfiniteSpireReward? weeklyBonusReward;
}

/// Layanan domain untuk mengelola arena tantangan The Infinite Spire (Lantai 1 s/d 100+).
class InfiniteSpireService {
  const InfiniteSpireService(this.config);

  final InfiniteSpireConfig config;

  static const String aetherShardCurrencyId = 'aether_shard';
  static const String soulPrismCurrencyId = 'soul_prism';
  static const String aetherScrapItemId = 'aether_scrap';
  static const String weeklyBossRushClaimPrefix =
      'infinite_spire:weekly_boss_rush:';

  /// Memeriksa apakah karakter diizinkan menantang [floorNumber].
  ///
  /// - [floorNumber] harus berada dalam rentang `1..totalFloors`.
  /// - Karakter dapat menantang lantai jika lantai tersebut $\le$ `highestFloorCleared + 1`.
  /// - Lantai yang sudah selesai dapat ditantang kembali untuk latihan/laga arena.
  bool canChallengeFloor(
    int floorNumber,
    InfiniteSpireProgressSnapshot progress,
  ) {
    if (floorNumber < 1 || floorNumber > config.totalFloors) return false;
    return floorNumber <= progress.highestFloorCleared + 1;
  }

  /// Membangun [DungeonDefinition] satu ruangan (arena pertempuran lantai spire) saat runtime.
  DungeonDefinition buildFloorDungeon({
    required int floorNumber,
    required List<String> arenaLayout,
    String arenaMapRef = 'ancient_heart_map',
  }) {
    final floor = config.floor(floorNumber);
    if (floor == null) {
      throw ArgumentError.value(
        floorNumber,
        'floorNumber',
        'Lantai $floorNumber tidak terdaftar di The Infinite Spire.',
      );
    }
    if (arenaLayout.isEmpty) {
      throw ArgumentError.value(
        arenaLayout,
        'arenaLayout',
        'Layout arena The Infinite Spire tidak boleh kosong.',
      );
    }

    final roomId = 'infinite_spire_f${floorNumber}_room';
    final dungeonId = 'infinite_spire_f$floorNumber';

    final spawns = <RoomSpawnConfig>[];

    if (floor.isBossFloor) {
      // 1. Bos utama di tengah arena
      final bossId = floor.bossId ?? 'aether_sovereign';
      spawns.add(
        RoomSpawnConfig(
          id: 'spire_boss_${floorNumber}_$bossId',
          monsterId: bossId,
          position: const GridPoint(17, 6),
          quantity: 1,
          spawnGroup: 'infinite_spire_boss',
          isBoss: true,
          required: true,
        ),
      );

      // 2. Minion pendamping (jika ada)
      const minionPositions = [
        GridPoint(15, 3),
        GridPoint(15, 9),
        GridPoint(13, 6),
        GridPoint(18, 3),
        GridPoint(18, 9),
      ];

      for (var i = 0; i < floor.enemyIds.length; i++) {
        final pos = minionPositions[i % minionPositions.length];
        spawns.add(
          RoomSpawnConfig(
            id: 'spire_minion_${floorNumber}_${floor.enemyIds[i]}_$i',
            monsterId: floor.enemyIds[i],
            position: pos,
            quantity: 1,
            spawnGroup: 'infinite_spire_minion',
            isBoss: false,
            required: false,
          ),
        );
      }
    } else {
      // Normal floor: musuh tersebar di posisi walkable arena
      const enemyPositions = [
        GridPoint(16, 6),
        GridPoint(14, 4),
        GridPoint(14, 8),
        GridPoint(18, 4),
        GridPoint(18, 8),
        GridPoint(12, 6),
      ];

      for (var i = 0; i < floor.enemyIds.length; i++) {
        final pos = enemyPositions[i % enemyPositions.length];
        spawns.add(
          RoomSpawnConfig(
            id: 'spire_enemy_${floorNumber}_${floor.enemyIds[i]}_$i',
            monsterId: floor.enemyIds[i],
            position: pos,
            quantity: 1,
            spawnGroup: 'infinite_spire_mobs',
            isBoss: false,
            required: true,
          ),
        );
      }
    }

    final room = RoomDefinition(
      id: roomId,
      dungeonId: dungeonId,
      name: floor.name,
      type: floor.isBossFloor ? RoomType.boss : RoomType.normal,
      mapRef: arenaMapRef,
      layout: arenaLayout,
      entryPosition: const GridPoint(1, 6),
      exitPosition: const GridPoint(22, 6),
      completionCondition: RoomCompletionCondition(
        type: floor.isBossFloor
            ? RoomCompletionConditionType.defeatBoss
            : RoomCompletionConditionType.defeatRequiredEnemies,
      ),
      spawns: spawns,
    );

    return DungeonDefinition(
      id: dungeonId,
      name: floor.name,
      biome: floorNumber == 100 ? 'abyssal_rift' : 'ancient_heart',
      kind: DungeonKind.infiniteSpire,
      order: floorNumber,
      recommendedLevel: floor.recommendedLevel,
      difficultyScale: 1.0,
      startRoomId: roomId,
      roomOrder: [roomId],
      rooms: {roomId: room},
      completionReward: const DungeonCompletionReward(),
    );
  }

  /// Memproses klaim hadiah kemenangan di lantai The Infinite Spire secara atomik dan idempoten.
  ///
  /// - Menghasilkan hadiah first-clear seumur hidup (*once-in-a-lifetime*).
  /// - Lantai yang sudah pernah diklaim sebelumnya tidak akan menggandakan hadiah.
  /// - Progres `highestFloorCleared` selalu dinaikkan jika `floorNumber > progress.highestFloorCleared`.
  InfiniteSpireSettlementResult settleFloorVictory({
    required int floorNumber,
    required PlayerCharacter character,
    required Inventory inventory,
    required CurrencyService currencyService,
    required InfiniteSpireProgressSnapshot progress,
  }) {
    final floorDef = config.floor(floorNumber);
    if (floorDef == null) {
      throw ArgumentError.value(
        floorNumber,
        'floorNumber',
        'Lantai $floorNumber tidak terdaftar di The Infinite Spire.',
      );
    }

    final claimId = 'infinite_spire_floor_$floorNumber';
    final isFirstClear = !progress.isRewardClaimed(floorNumber);
    final reward = floorDef.reward;

    if (isFirstClear) {
      // 1. Berikan EXP dan Gold ke karakter
      if (reward.exp > 0 || reward.gold > 0) {
        character.receiveReward(
          exp: math.max(0, reward.exp),
          gold: math.max(0, reward.gold),
        );
      }

      // 2. Berikan Items (misal Aether Scrap, Boss Remnant) ke Inventory
      for (final entry in reward.items.entries) {
        if (entry.value > 0) {
          inventory.add(entry.key, entry.value);
        }
      }

      // 3. Berikan Currencies (misal Aether Shard, Soul Prism) via CurrencyService
      for (final entry in reward.currencies.entries) {
        if (entry.value > 0) {
          currencyService.grant(
            entry.key,
            entry.value,
            claimId: '$claimId:${entry.key}',
          );
        }
      }
    }

    final updatedHighest = math.max(progress.highestFloorCleared, floorNumber);
    final updatedClaimed = isFirstClear
        ? {...progress.claimedFloorRewards, floorNumber}
        : progress.claimedFloorRewards;

    final updatedProgress = progress.copyWith(
      highestFloorCleared: updatedHighest,
      claimedFloorRewards: updatedClaimed,
    );

    final userMessage = isFirstClear
        ? 'Lantai $floorNumber Selesai!\nHadiah Pertama: +${reward.exp} EXP, +${reward.gold} Gold${_formatExtras(reward)}'
        : 'Lantai $floorNumber telah diselesaikan! (Hadiah lantai ini telah diklaim)';

    return InfiniteSpireSettlementResult(
      floor: floorNumber,
      isFirstClear: isFirstClear,
      reward: reward,
      updatedProgress: updatedProgress,
      userMessage: userMessage,
      claimId: claimId,
    );
  }

  /// Menentukan tantangan bos mingguan Spire untuk periode aktif via [periodService].
  /// Terbuka setelah pemain menamatkan minimal 1 lantai bos (Lantai 10).
  /// Memutar di antara maksimal 5 lantai bos tertinggi yang sudah ditamatkan.
  WeeklySpireBossRushInfo resolveWeeklyBossRush({
    required InfiniteSpireProgressSnapshot progress,
    required PeriodService periodService,
    required int nowMs,
    Set<String> claimedEventIds = const {},
  }) {
    final periodKey = periodService.keyFor(Period.weekly, nowMs);
    final nextResetMs = periodService.nextResetMs(Period.weekly, nowMs);
    final claimId = '$weeklyBossRushClaimPrefix$periodKey';

    final eligibleBossFloors = [
      for (final floor in config.floors)
        if (floor.isBossFloor && floor.floor <= progress.highestFloorCleared)
          floor,
    ]..sort((a, b) => a.floor.compareTo(b.floor));

    if (eligibleBossFloors.isEmpty) {
      return WeeklySpireBossRushInfo(
        isUnlocked: false,
        periodKey: periodKey,
        nextResetMs: nextResetMs,
        claimId: claimId,
        isCompletedThisWeek: false,
        reward: const InfiniteSpireReward(),
      );
    }

    final pool = eligibleBossFloors.length > 5
        ? eligibleBossFloors.sublist(eligibleBossFloors.length - 5)
        : eligibleBossFloors;
    final weekIdx = periodService.weekIndex(nowMs).abs();
    final featured = pool[weekIdx % pool.length];
    final tier = math.max(1, featured.floor ~/ 10);

    final weeklyReward = InfiniteSpireReward(
      gold: 10000 + featured.floor * 200,
      items: {aetherScrapItemId: 15 + tier * 3},
      currencies: {aetherShardCurrencyId: 15 + tier * 2},
    );

    return WeeklySpireBossRushInfo(
      isUnlocked: true,
      periodKey: periodKey,
      nextResetMs: nextResetMs,
      claimId: claimId,
      isCompletedThisWeek: claimedEventIds.contains(claimId),
      reward: weeklyReward,
      featuredFloor: featured,
    );
  }

  /// Memberikan hadiah bonus Tantangan Bos Mingguan secara atomik dan idempoten
  /// apabila [floorNumber] merupakan lantai unggulan minggu ini dan belum diklaim.
  WeeklySpireBossRushSettlement? trySettleWeeklyBossRush({
    required int floorNumber,
    required PlayerCharacter character,
    required Inventory inventory,
    required CurrencyService currencyService,
    required InfiniteSpireProgressSnapshot progress,
    required PeriodService periodService,
    required int nowMs,
    required Set<String> claimedEventIds,
  }) {
    final info = resolveWeeklyBossRush(
      progress: progress,
      periodService: periodService,
      nowMs: nowMs,
      claimedEventIds: claimedEventIds,
    );
    if (!info.isUnlocked ||
        info.isCompletedThisWeek ||
        info.featuredFloor?.floor != floorNumber) {
      return null;
    }

    final reward = info.reward;
    if (reward.gold > 0) {
      character.receiveReward(gold: reward.gold);
    }
    for (final entry in reward.items.entries) {
      if (entry.value > 0 && inventory.definitionOf(entry.key) != null) {
        inventory.add(entry.key, entry.value);
      }
    }
    for (final entry in reward.currencies.entries) {
      if (entry.value > 0) {
        currencyService.grant(
          entry.key,
          entry.value,
          claimId: '${info.claimId}:${entry.key}',
        );
      }
    }

    return WeeklySpireBossRushSettlement(
      claimed: true,
      claimId: info.claimId,
      periodKey: info.periodKey,
      reward: reward,
    );
  }

  String _formatExtras(InfiniteSpireReward reward) {
    final extras = <String>[];
    for (final entry in reward.items.entries) {
      if (entry.value > 0) extras.add('+${entry.value} ${entry.key}');
    }
    for (final entry in reward.currencies.entries) {
      if (entry.value > 0) extras.add('+${entry.value} ${entry.key}');
    }
    if (extras.isEmpty) return '';
    return ', ${extras.join(', ')}';
  }

  /// Mengambil layout arena dari `gameConfig.mapLayouts` atau fallback ke ruangan `ancient_heart_map`.
  static List<String>? resolveArenaLayout(GameConfig gameConfig) {
    const mapRef = 'ancient_heart_map';
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
