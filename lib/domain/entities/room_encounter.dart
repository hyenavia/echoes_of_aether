import 'dungeon_definition.dart';
import 'grid_point.dart';

/// Kategori encounter dalam satu titik spawn room.
enum EncounterType { normal, elite, boss }

/// Siklus hidup satu encounter pada room aktif.
enum EncounterStatus { pending, active, completed, failed }

/// Rekam hasil spawn satu instance musuh ke dalam `CombatSimulation`.
class SpawnedEnemyRecord {
  const SpawnedEnemyRecord({
    required this.encounterId,
    required this.enemyId,
    required this.monsterId,
    required this.type,
    required this.spawnCell,
  });

  final String encounterId;
  final String enemyId;
  final String monsterId;
  final EncounterType type;
  final GridPoint spawnCell;
}

/// State runtime satu encounter di dalam room (sumber kebenaran terpisah dari
/// komponen visual Flame).
class RoomEncounterState {
  const RoomEncounterState({
    required this.encounterId,
    required this.roomId,
    required this.spawnConfigId,
    required this.spawnGroup,
    required this.monsterId,
    required this.type,
    required this.requiredForCompletion,
    required this.activationState,
    this.activationTriggerGroup,
    required this.plannedCount,
    this.spawnedCount = 0,
    this.activeCount = 0,
    this.defeatedCount = 0,
    this.status = EncounterStatus.pending,
    this.spawnedEnemyIds = const [],
    this.lastError,
  });

  final String encounterId;
  final String roomId;
  final String spawnConfigId;
  final String spawnGroup;
  final String monsterId;
  final EncounterType type;
  final bool requiredForCompletion;
  final SpawnActivationState activationState;
  final String? activationTriggerGroup;
  final int plannedCount;
  final int spawnedCount;
  final int activeCount;
  final int defeatedCount;
  final EncounterStatus status;
  final List<String> spawnedEnemyIds;
  final String? lastError;

  bool get isElite => type == EncounterType.elite;
  bool get isBoss => type == EncounterType.boss;
  bool get isCompleted => status == EncounterStatus.completed;
  bool get isFailed => status == EncounterStatus.failed;
  bool get isPending => status == EncounterStatus.pending;
  bool get isActive => status == EncounterStatus.active;

  RoomEncounterState copyWith({
    int? spawnedCount,
    int? activeCount,
    int? defeatedCount,
    EncounterStatus? status,
    List<String>? spawnedEnemyIds,
    String? lastError,
  }) {
    return RoomEncounterState(
      encounterId: encounterId,
      roomId: roomId,
      spawnConfigId: spawnConfigId,
      spawnGroup: spawnGroup,
      monsterId: monsterId,
      type: type,
      requiredForCompletion: requiredForCompletion,
      activationState: activationState,
      activationTriggerGroup: activationTriggerGroup,
      plannedCount: plannedCount,
      spawnedCount: spawnedCount ?? this.spawnedCount,
      activeCount: activeCount ?? this.activeCount,
      defeatedCount: defeatedCount ?? this.defeatedCount,
      status: status ?? this.status,
      spawnedEnemyIds: spawnedEnemyIds ?? this.spawnedEnemyIds,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Event domain untuk perubahan state encounter (dipakai HUD dan Stage 4).
sealed class EncounterEvent {
  const EncounterEvent(this.roomId);

  final String roomId;
}

class EncounterSpawnedEvent extends EncounterEvent {
  const EncounterSpawnedEvent(
    super.roomId,
    this.encounter,
    this.spawnedEnemies,
  );

  final RoomEncounterState encounter;
  final List<SpawnedEnemyRecord> spawnedEnemies;
}

class EncounterUpdatedEvent extends EncounterEvent {
  const EncounterUpdatedEvent(super.roomId, this.encounter);

  final RoomEncounterState encounter;
}

class EncounterCompletedEvent extends EncounterEvent {
  const EncounterCompletedEvent(super.roomId, this.encounter);

  final RoomEncounterState encounter;
}

class SpawnGroupCompletedEvent extends EncounterEvent {
  const SpawnGroupCompletedEvent(super.roomId, this.spawnGroup);

  final String spawnGroup;
}

/// Sinyal untuk Stage 4 bahwa seluruh encounter wajib di room telah selesai.
/// Stage 3 tidak mengeksekusi room completion atau transisi secara otomatis.
class RoomEncountersCompletedEvent extends EncounterEvent {
  const RoomEncountersCompletedEvent(super.roomId, this.encounters);

  final List<RoomEncounterState> encounters;
}

class EncounterSpawnFailedEvent extends EncounterEvent {
  const EncounterSpawnFailedEvent(super.roomId, this.encounter, this.reason);

  final RoomEncounterState encounter;
  final String reason;
}
