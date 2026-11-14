import 'dart:math' as math;

import '../services/navigation_grid.dart';
import 'combat_stats.dart';
import 'dungeon_reward.dart';
import 'grid_point.dart';

/// Tipe ruangan dungeon (M5).
enum RoomType { normal, elite, boss }

/// Jenis kondisi penyelesaian ruangan.
enum RoomCompletionConditionType {
  defeatRequiredEnemies,
  defeatElite,
  defeatBoss,
  reachExit,
}

/// Konfigurasi kondisi penyelesaian satu ruangan.
class RoomCompletionCondition {
  const RoomCompletionCondition({
    this.type = RoomCompletionConditionType.defeatRequiredEnemies,
    this.requiredSpawnGroup,
    this.targetCount,
    this.requireExit = false,
    this.additionalConditions = const [],
  });

  final RoomCompletionConditionType type;

  /// Jika diisi, hanya spawn dalam grup ini yang dihitung sebagai syarat.
  final String? requiredSpawnGroup;

  /// Jumlah target spesifik yang harus dikalahkan (null = semua target wajib).
  final int? targetCount;

  /// Jika true, pemain juga wajib mencapai `exitPosition` setelah syarat
  /// combat terpenuhi (multi-kondisi eksplisit).
  final bool requireExit;

  /// Daftar syarat tambahan opsional; seluruh syarat wajib terpenuhi agar room
  /// dianggap selesai.
  final List<RoomCompletionCondition> additionalConditions;

  bool get requiresExit =>
      requireExit ||
      type == RoomCompletionConditionType.reachExit ||
      additionalConditions.any((c) => c.requiresExit);
}

/// Kapan titik spawn diaktifkan di dalam lifecycle room.
enum SpawnActivationState { immediate, onGroupCleared, manual }

/// Modifier stat opsional pada konfigurasi spawn (mis. elite/boss scaling).
class SpawnStatModifier {
  const SpawnStatModifier({
    this.hpMultiplier = 1.0,
    this.atkMultiplier = 1.0,
    this.defMultiplier = 1.0,
    this.hpBonus = 0,
    this.atkBonus = 0,
    this.defBonus = 0,
  });

  final double hpMultiplier;
  final double atkMultiplier;
  final double defMultiplier;
  final int hpBonus;
  final int atkBonus;
  final int defBonus;

  bool get isIdentity =>
      hpMultiplier == 1.0 &&
      atkMultiplier == 1.0 &&
      defMultiplier == 1.0 &&
      hpBonus == 0 &&
      atkBonus == 0 &&
      defBonus == 0;

  CombatStats applyTo(CombatStats base) {
    if (isIdentity) return base;
    return CombatStats(
      maxHp: math.max(1, (base.maxHp * hpMultiplier).round() + hpBonus),
      atk: math.max(0, (base.atk * atkMultiplier).round() + atkBonus),
      def: math.max(0, (base.def * defMultiplier).round() + defBonus),
      attackSpeed: base.attackSpeed,
      critRate: base.critRate,
      critDamage: base.critDamage,
      moveSpeed: base.moveSpeed,
      attackRange: base.attackRange,
      skillHaste: base.skillHaste,
    );
  }
}

/// Konfigurasi satu titik/grup spawn monster di dalam room.
class RoomSpawnConfig {
  const RoomSpawnConfig({
    required this.id,
    required this.monsterId,
    required this.position,
    this.quantity = 1,
    this.spawnGroup = 'default',
    this.isElite = false,
    this.isBoss = false,
    this.required = true,
    this.activationState = SpawnActivationState.immediate,
    this.activationTriggerGroup,
    this.statModifier = const SpawnStatModifier(),
  });

  final String id;
  final String monsterId;
  final GridPoint position;
  final int quantity;
  final String spawnGroup;
  final bool isElite;
  final bool isBoss;

  /// Apakah musuh dari spawn ini wajib dikalahkan untuk menyelesaikan room.
  final bool required;

  final SpawnActivationState activationState;
  final String? activationTriggerGroup;
  final SpawnStatModifier statModifier;
}

/// Konfigurasi reward opsional saat satu ruangan diselesaikan.
class RoomRewardConfig {
  const RoomRewardConfig({
    this.expReward = 0,
    this.goldReward = 0,
    this.lootTableId,
  });

  final int expReward;
  final int goldReward;
  final String? lootTableId;

  bool get isEmpty => expReward <= 0 && goldReward <= 0 && lootTableId == null;
}

/// Definisi statis satu ruangan di dalam dungeon.
class RoomDefinition {
  const RoomDefinition({
    required this.id,
    required this.dungeonId,
    required this.name,
    required this.type,
    required this.mapRef,
    required this.layout,
    required this.entryPosition,
    required this.exitPosition,
    required this.spawns,
    required this.completionCondition,
    this.nextRoomIds = const [],
    this.reward,
  });

  final String id;
  final String dungeonId;
  final String name;
  final RoomType type;
  final String mapRef;
  final List<String> layout;
  final GridPoint entryPosition;
  final GridPoint exitPosition;
  final List<RoomSpawnConfig> spawns;
  final RoomCompletionCondition completionCondition;

  /// Daftar ID ruangan berikutnya. MVP memakai 0 (final) atau 1 (linear),
  /// namun struktur list disiapkan untuk percabangan graph di masa depan.
  final List<String> nextRoomIds;

  final RoomRewardConfig? reward;

  bool get isFinalRoom => nextRoomIds.isEmpty;

  String? get primaryNextRoomId =>
      nextRoomIds.isEmpty ? null : nextRoomIds.first;

  /// Kebijakan deterministik MVP untuk memilih room berikutnya dari
  /// [nextRoomIds]:
  /// - 0 room -> null (room akhir).
  /// - 1 room -> langsung memakai satu-satunya target.
  /// - >1 room -> memilih room pertama dalam `nextRoomIds` yang belum berada
  ///   di [clearedRoomIds], dengan fallback ke elemen pertama.
  String? selectNextRoomId({Set<String> clearedRoomIds = const {}}) {
    if (nextRoomIds.isEmpty) return null;
    if (nextRoomIds.length == 1) return nextRoomIds.first;
    for (final candidate in nextRoomIds) {
      if (!clearedRoomIds.contains(candidate)) {
        return candidate;
      }
    }
    return nextRoomIds.first;
  }

  NavigationGrid createNavigationGrid() => NavigationGrid.fromAscii(layout);

  RoomDefinition copyWith({String? dungeonId}) => RoomDefinition(
    id: id,
    dungeonId: dungeonId ?? this.dungeonId,
    name: name,
    type: type,
    mapRef: mapRef,
    layout: layout,
    entryPosition: entryPosition,
    exitPosition: exitPosition,
    spawns: spawns,
    completionCondition: completionCondition,
    nextRoomIds: nextRoomIds,
    reward: reward,
  );
}

/// Jenis dungeon pada progresi.
enum DungeonKind { normal, ascension }

/// Definisi statis satu dungeon lengkap (mis. Forgotten Forest).
class DungeonDefinition {
  const DungeonDefinition({
    required this.id,
    required this.name,
    required this.biome,
    required this.startRoomId,
    required this.rooms,
    required this.roomOrder,
    this.kind = DungeonKind.normal,
    this.order = 1,
    this.recommendedLevel = 1,
    this.unlockRequiresDungeonId,
    this.baseDungeonId,
    this.difficultyScale = 1.0,
    this.completionReward,
  });

  final String id;
  final String name;
  final String biome;
  final String startRoomId;
  final Map<String, RoomDefinition> rooms;

  /// Urutan kanonik room IDs (untuk indexing & progres MVP linear).
  final List<String> roomOrder;

  final DungeonKind kind;

  /// Urutan dungeon pada katalog (`1..N`).
  final int order;

  /// Level rekomendasi pada siklus awal (rank 0).
  final int recommendedLevel;

  /// ID dungeon prasyarat agar dungeon ini terbuka pada siklus saat ini.
  final String? unlockRequiresDungeonId;

  /// ID dungeon dasar untuk dungeon bertipe [DungeonKind.ascension].
  final String? baseDungeonId;

  final double difficultyScale;

  /// Reward penyelesaian dungeon khusus dungeon ini (opsional; fallback ke
  /// `GameConfig.dungeonCompletion` bila null).
  final DungeonCompletionReward? completionReward;

  bool get isNormal => kind == DungeonKind.normal;
  bool get isAscension => kind == DungeonKind.ascension;

  RoomDefinition? roomById(String roomId) => rooms[roomId];

  int indexOfRoom(String roomId) => roomOrder.indexOf(roomId);
}
