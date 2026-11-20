import 'clock_state.dart';
import 'cycle_progress.dart';
import 'dungeon_session.dart';
import 'equipment.dart';
import 'event_shop_purchase.dart';
import 'gacha_config.dart';
import 'infinite_spire.dart';
import 'offline_activity.dart';
import 'periodic_quest_state.dart';
import 'player_progress.dart';
import 'player_status.dart';

/// Snapshot state [PlayerCharacter] yang siap dipersistensikan.
class PlayerCharacterSnapshot {
  const PlayerCharacterSnapshot({
    required this.progress,
    this.specializationId,
    this.skillLevels = const {},
    this.skillCooldownTicks = const {},
    this.equipped = const {},
    this.currentHp,
  });

  final PlayerProgress progress;
  final String? specializationId;
  final Map<String, int> skillLevels;

  /// Sisa cooldown skill dalam satuan tick (50 ms/tick) saat sesi disimpan.
  final Map<String, int> skillCooldownTicks;

  final Map<EquipmentSlot, EquipmentInstance> equipped;

  /// HP terakhir saat sesi disimpan; null berarti mulai dengan max HP.
  final int? currentHp;

  PlayerCharacterSnapshot copyWith({
    PlayerProgress? progress,
    String? specializationId,
    bool clearSpecializationId = false,
    Map<String, int>? skillLevels,
    Map<String, int>? skillCooldownTicks,
    Map<EquipmentSlot, EquipmentInstance>? equipped,
    int? currentHp,
    bool clearCurrentHp = false,
  }) {
    return PlayerCharacterSnapshot(
      progress: progress ?? this.progress,
      specializationId: clearSpecializationId
          ? null
          : (specializationId ?? this.specializationId),
      skillLevels: skillLevels ?? this.skillLevels,
      skillCooldownTicks: skillCooldownTicks ?? this.skillCooldownTicks,
      equipped: equipped ?? this.equipped,
      currentHp: clearCurrentHp ? null : (currentHp ?? this.currentHp),
    );
  }
}

/// Snapshot isi [Inventory] (stack + equipment bag + counter id) untuk persistensi.
class InventorySnapshot {
  const InventorySnapshot({
    this.stacks = const {},
    this.equipment = const [],
    this.equipmentCounter = 0,
  });

  final Map<String, int> stacks;
  final List<EquipmentInstance> equipment;
  final int equipmentCounter;

  InventorySnapshot copyWith({
    Map<String, int>? stacks,
    List<EquipmentInstance>? equipment,
    int? equipmentCounter,
  }) {
    return InventorySnapshot(
      stacks: stacks ?? this.stacks,
      equipment: equipment ?? this.equipment,
      equipmentCounter: equipmentCounter ?? this.equipmentCounter,
    );
  }
}

/// Snapshot status klaim reward tingkat dungeon (`DungeonProgresses.rewardStateJson`).
class DungeonRewardStateSnapshot {
  const DungeonRewardStateSnapshot({
    this.lastRunId,
    this.completionRewardClaimed = false,
    this.claimedRoomRewardIds = const {},
  });

  final String? lastRunId;
  final bool completionRewardClaimed;
  final Set<String> claimedRoomRewardIds;
}

/// Snapshot progres dungeon pemain (current dungeon, room, status penyelesaian).
class DungeonProgressSnapshot {
  const DungeonProgressSnapshot({
    this.currentDungeonId = 'forgotten_forest',
    this.currentRoomId = 'forest_entrance',
    this.currentRoomIndex = 0,
    this.highestClearedRoomIndex = -1,
    this.clearsCount = 0,
    this.clearedInCycleRank = -1,
    this.rewardState = const DungeonRewardStateSnapshot(),
  });

  final String currentDungeonId;
  final String currentRoomId;
  final int currentRoomIndex;
  final int highestClearedRoomIndex;
  final int clearsCount;

  /// Rank siklus tempat dungeon ini terakhir diselesaikan (`-1` bila belum
  /// pernah selesai pada siklus mana pun / pra-migrasi).
  final int clearedInCycleRank;
  final DungeonRewardStateSnapshot rewardState;
}

/// Snapshot sesi dungeon aktif/terakhir untuk session persistence & recovery
/// (`GameSessions.sessionDataJson`, Stage 5).
class ActiveDungeonSessionSnapshot {
  const ActiveDungeonSessionSnapshot({
    required this.runId,
    required this.dungeonId,
    required this.currentRoomId,
    required this.currentRoomIndex,
    required this.status,
    this.clearedRoomIds = const {},
    this.completionRewardClaimed = false,
    this.reviveCooldownTicks = 0,
    this.playerStatus = PlayerStatus.alive,
    this.cycleRank = 0,
    this.bossEventId,
    this.periodKeyAtStart,
  });

  final String runId;
  final String dungeonId;
  final String currentRoomId;
  final int currentRoomIndex;
  final DungeonSessionStatus status;
  final Set<String> clearedRoomIds;
  final bool completionRewardClaimed;

  /// Sisa cooldown revive dalam tick agar restart tidak memberi revive ekstra.
  final int reviveCooldownTicks;

  /// Status player saat save (`alive`, `downed`, `runEnded`).
  final PlayerStatus playerStatus;

  /// Cycle rank Ascension saat run dimulai agar session recovery memakai
  /// tingkat kesulitan yang konsisten dengan awal run.
  final int cycleRank;

  /// ID boss event bila sesi ini merupakan run Daily/Weekly Boss.
  final String? bossEventId;

  /// Kunci periode (`YYYY-MM-DD`) saat run boss dimulai.
  final String? periodKeyAtStart;

  bool get isBossEvent => bossEventId != null && bossEventId!.trim().isNotEmpty;

  /// Sesi hanya dipulihkan ke dungeon bila belum terminal dan sudah dimulai.
  bool get isRecoverable =>
      status == DungeonSessionStatus.inProgress ||
      status == DungeonSessionStatus.roomCompleted;
}

/// Snapshot metadata sesi untuk recovery, perlindungan death loop, dan batas waktu offline progression.
class GameSessionSnapshot {
  const GameSessionSnapshot({
    this.playerId = defaultPlayerId,
    this.lastActiveAtMs = 0,
    this.lastSavedAtMs = 0,
    this.lastOfflineClaimAtMs = 0,
    this.autoSkillEnabled = true,
    this.consecutiveDefeats = const {},
    this.lastFailedDungeonId,
  });

  static const String defaultPlayerId = 'default_player';

  final String playerId;
  final int lastActiveAtMs;
  final int lastSavedAtMs;
  final int lastOfflineClaimAtMs;
  final bool autoSkillEnabled;

  /// Jumlah kekalahan beruntun per `dungeonId` untuk perlindungan death loop.
  final Map<String, int> consecutiveDefeats;

  /// ID dungeon terakhir yang berakhir kalah (`DungeonEndReason.defeated`)
  /// untuk menampilkan saran di Town pasca-respawn (terutama setelah Ascension).
  final String? lastFailedDungeonId;

  GameSessionSnapshot copyWith({
    String? playerId,
    int? lastActiveAtMs,
    int? lastSavedAtMs,
    int? lastOfflineClaimAtMs,
    bool? autoSkillEnabled,
    Map<String, int>? consecutiveDefeats,
    String? lastFailedDungeonId,
    bool clearLastFailedDungeonId = false,
  }) {
    return GameSessionSnapshot(
      playerId: playerId ?? this.playerId,
      lastActiveAtMs: lastActiveAtMs ?? this.lastActiveAtMs,
      lastSavedAtMs: lastSavedAtMs ?? this.lastSavedAtMs,
      lastOfflineClaimAtMs: lastOfflineClaimAtMs ?? this.lastOfflineClaimAtMs,
      autoSkillEnabled: autoSkillEnabled ?? this.autoSkillEnabled,
      consecutiveDefeats: consecutiveDefeats ?? this.consecutiveDefeats,
      lastFailedDungeonId: clearLastFailedDungeonId
          ? null
          : (lastFailedDungeonId ?? this.lastFailedDungeonId),
    );
  }
}

/// Gabungan snapshot progres karakter, inventory, dungeon, dan sesi untuk
/// operasi save/load atomik.
class PlayerSaveSnapshot {
  const PlayerSaveSnapshot({
    this.playerId = GameSessionSnapshot.defaultPlayerId,
    required this.character,
    required this.inventory,
    this.dungeon = const DungeonProgressSnapshot(),
    this.dungeonProgresses = const {},
    this.cycleProgress = const CycleProgress(),
    this.session = const GameSessionSnapshot(),
    this.claimedEventIds = const {},
    this.activeDungeonSession,
    this.offlineActivity = const OfflineActivitySnapshot.paused(),
    this.shopPurchases = const {},
    this.eventShopPurchases = const [],
    this.currencies = const {},
    this.clockState = const ClockState(),
    this.periodicQuestStates = const [],
    this.gachaPityStates = const {},
    this.unlockedSpecializations = const {'vanguard', 'arcanist', 'ranger'},
    this.infiniteSpireProgress = const InfiniteSpireProgressSnapshot(),
  });

  final String playerId;
  final PlayerCharacterSnapshot character;
  final InventorySnapshot inventory;
  final DungeonProgressSnapshot dungeon;

  /// Peta progres seluruh dungeon berdasarkan `dungeonId` untuk mendukung
  /// verifikasi eligibilitas Auto Farming lintas-dungeon tanpa query acak.
  final Map<String, DungeonProgressSnapshot> dungeonProgresses;

  /// State siklus ascension dan dungeon normal terakhir terpilih.
  final CycleProgress cycleProgress;

  final GameSessionSnapshot session;
  final Set<String> claimedEventIds;
  final ActiveDungeonSessionSnapshot? activeDungeonSession;
  final OfflineActivitySnapshot offlineActivity;

  /// Jumlah pembelian per `entryId` shop (`ShopPurchases`).
  final Map<String, int> shopPurchases;

  /// Riwayat pembelian Event Shop per `(entryId, periodKey)` (`EventShopPurchases`).
  final List<EventShopPurchaseRecord> eventShopPurchases;

  /// Saldo mata uang khusus non-gold (`Currencies`).
  final Map<String, int> currencies;

  /// State pengaman jam perangkat (`ClockStates`).
  final ClockState clockState;

  /// State penyelesaian quest periodik (`PeriodicQuestStates`).
  final List<PeriodicQuestState> periodicQuestStates;

  /// State pity gacha per tipe banner (`GachaPityStates`).
  final Map<String, GachaPityState> gachaPityStates;

  /// ID class specialization yang telah dibuka pemain (`UnlockedSpecializations`).
  final Set<String> unlockedSpecializations;

  /// Progres tantangan The Infinite Spire (`InfiniteSpireProgresses`).
  final InfiniteSpireProgressSnapshot infiniteSpireProgress;

  PlayerSaveSnapshot copyWith({
    String? playerId,
    PlayerCharacterSnapshot? character,
    InventorySnapshot? inventory,
    DungeonProgressSnapshot? dungeon,
    Map<String, DungeonProgressSnapshot>? dungeonProgresses,
    CycleProgress? cycleProgress,
    GameSessionSnapshot? session,
    Set<String>? claimedEventIds,
    ActiveDungeonSessionSnapshot? activeDungeonSession,
    bool clearActiveDungeonSession = false,
    OfflineActivitySnapshot? offlineActivity,
    Map<String, int>? shopPurchases,
    List<EventShopPurchaseRecord>? eventShopPurchases,
    Map<String, int>? currencies,
    ClockState? clockState,
    List<PeriodicQuestState>? periodicQuestStates,
    Map<String, GachaPityState>? gachaPityStates,
    Set<String>? unlockedSpecializations,
    InfiniteSpireProgressSnapshot? infiniteSpireProgress,
  }) {
    return PlayerSaveSnapshot(
      playerId: playerId ?? this.playerId,
      character: character ?? this.character,
      inventory: inventory ?? this.inventory,
      dungeon: dungeon ?? this.dungeon,
      dungeonProgresses: dungeonProgresses ?? this.dungeonProgresses,
      cycleProgress: cycleProgress ?? this.cycleProgress,
      session: session ?? this.session,
      claimedEventIds: claimedEventIds ?? this.claimedEventIds,
      activeDungeonSession: clearActiveDungeonSession
          ? null
          : (activeDungeonSession ?? this.activeDungeonSession),
      offlineActivity: offlineActivity ?? this.offlineActivity,
      shopPurchases: shopPurchases ?? this.shopPurchases,
      eventShopPurchases: eventShopPurchases ?? this.eventShopPurchases,
      currencies: currencies ?? this.currencies,
      clockState: clockState ?? this.clockState,
      periodicQuestStates: periodicQuestStates ?? this.periodicQuestStates,
      gachaPityStates: gachaPityStates ?? this.gachaPityStates,
      unlockedSpecializations:
          unlockedSpecializations ?? this.unlockedSpecializations,
      infiniteSpireProgress:
          infiniteSpireProgress ?? this.infiniteSpireProgress,
    );
  }

  /// Mengambil snapshot progres untuk [dungeonId] dengan fallback ke [dungeon]
  /// bila peta belum terisi.
  DungeonProgressSnapshot? progressForDungeon(String dungeonId) =>
      dungeonProgresses[dungeonId] ??
      (dungeon.currentDungeonId == dungeonId ? dungeon : null);

  /// Menentukan apakah [dungeonId] pernah diselesaikan seumur hidup
  /// (`clearsCount > 0`). Untuk eligibilitas siklus saat ini gunakan
  /// [isClearedInCurrentCycle].
  bool hasClearedDungeon(String dungeonId) =>
      (progressForDungeon(dungeonId)?.clearsCount ?? 0) > 0;

  /// Menentukan apakah [dungeonId] sudah diselesaikan pada siklus
  /// (`cycleProgress.ascensionRank`) saat ini.
  bool isClearedInCurrentCycle(String dungeonId) =>
      (progressForDungeon(dungeonId)?.clearedInCycleRank ?? -1) ==
      cycleProgress.ascensionRank;
}
