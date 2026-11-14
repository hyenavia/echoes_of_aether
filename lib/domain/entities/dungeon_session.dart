/// Status tingkat sesi untuk satu dungeon run.
enum DungeonSessionStatus {
  notStarted,
  inProgress,
  roomCompleted,
  completed,
  failed,
}

/// Siklus hidup ruangan aktif di dalam dungeon run.
enum RoomLifecycleState {
  notLoaded,
  loading,
  ready,
  active,
  completing,
  completed,
  transitioning,
  unloaded,
}

/// State runtime satu sesi dungeon. Dipisahkan dari konfigurasi statis
/// (`DungeonDefinition`) serta komponen visual Flame.
class DungeonSession {
  const DungeonSession({
    required this.runId,
    required this.dungeonId,
    required this.currentRoomId,
    required this.currentRoomIndex,
    this.cycleRank = 0,
    this.status = DungeonSessionStatus.notStarted,
    this.roomLifecycle = RoomLifecycleState.notLoaded,
    this.clearedRoomIds = const {},
    this.completionRewardClaimed = false,
  });

  final String runId;
  final String dungeonId;
  final String currentRoomId;
  final int currentRoomIndex;
  final int cycleRank;
  final DungeonSessionStatus status;
  final RoomLifecycleState roomLifecycle;
  final Set<String> clearedRoomIds;
  final bool completionRewardClaimed;

  bool get isTerminal =>
      status == DungeonSessionStatus.completed ||
      status == DungeonSessionStatus.failed;

  bool isRoomCleared(String roomId) => clearedRoomIds.contains(roomId);

  static bool isValidSessionTransition(
    DungeonSessionStatus from,
    DungeonSessionStatus to,
  ) {
    if (from == to) return false;
    switch (from) {
      case DungeonSessionStatus.notStarted:
        return to == DungeonSessionStatus.inProgress;
      case DungeonSessionStatus.inProgress:
        return to == DungeonSessionStatus.roomCompleted ||
            to == DungeonSessionStatus.completed ||
            to == DungeonSessionStatus.failed;
      case DungeonSessionStatus.roomCompleted:
        return to == DungeonSessionStatus.inProgress ||
            to == DungeonSessionStatus.completed ||
            to == DungeonSessionStatus.failed;
      case DungeonSessionStatus.completed:
      case DungeonSessionStatus.failed:
        return false;
    }
  }

  static bool isValidRoomTransition(
    RoomLifecycleState from,
    RoomLifecycleState to,
  ) {
    if (from == to) return false;
    switch (from) {
      case RoomLifecycleState.notLoaded:
      case RoomLifecycleState.unloaded:
        return to == RoomLifecycleState.loading;
      case RoomLifecycleState.loading:
        return to == RoomLifecycleState.ready ||
            to == RoomLifecycleState.unloaded;
      case RoomLifecycleState.ready:
        return to == RoomLifecycleState.active ||
            to == RoomLifecycleState.unloaded;
      case RoomLifecycleState.active:
        return to == RoomLifecycleState.completing ||
            to == RoomLifecycleState.unloaded;
      case RoomLifecycleState.completing:
        return to == RoomLifecycleState.completed ||
            to == RoomLifecycleState.unloaded;
      case RoomLifecycleState.completed:
        return to == RoomLifecycleState.transitioning ||
            to == RoomLifecycleState.unloaded;
      case RoomLifecycleState.transitioning:
        return to == RoomLifecycleState.unloaded;
    }
  }

  DungeonSession transitionSession(
    DungeonSessionStatus next, {
    String? currentRoomId,
    int? currentRoomIndex,
    Set<String>? clearedRoomIds,
    bool? completionRewardClaimed,
  }) {
    if (!isValidSessionTransition(status, next)) {
      throw StateError(
        'Transisi DungeonSessionStatus tidak valid: ${status.name} -> ${next.name}.',
      );
    }
    return DungeonSession(
      runId: runId,
      dungeonId: dungeonId,
      currentRoomId: currentRoomId ?? this.currentRoomId,
      currentRoomIndex: currentRoomIndex ?? this.currentRoomIndex,
      cycleRank: cycleRank,
      status: next,
      roomLifecycle: roomLifecycle,
      clearedRoomIds: clearedRoomIds ?? this.clearedRoomIds,
      completionRewardClaimed:
          completionRewardClaimed ?? this.completionRewardClaimed,
    );
  }

  DungeonSession transitionRoom(RoomLifecycleState next) {
    if (!isValidRoomTransition(roomLifecycle, next)) {
      throw StateError(
        'Transisi RoomLifecycleState tidak valid: '
        '${roomLifecycle.name} -> ${next.name}.',
      );
    }
    return DungeonSession(
      runId: runId,
      dungeonId: dungeonId,
      currentRoomId: currentRoomId,
      currentRoomIndex: currentRoomIndex,
      cycleRank: cycleRank,
      status: status,
      roomLifecycle: next,
      clearedRoomIds: clearedRoomIds,
      completionRewardClaimed: completionRewardClaimed,
    );
  }

  DungeonSession copyWith({
    String? currentRoomId,
    int? currentRoomIndex,
    int? cycleRank,
    DungeonSessionStatus? status,
    RoomLifecycleState? roomLifecycle,
    Set<String>? clearedRoomIds,
    bool? completionRewardClaimed,
  }) {
    return DungeonSession(
      runId: runId,
      dungeonId: dungeonId,
      currentRoomId: currentRoomId ?? this.currentRoomId,
      currentRoomIndex: currentRoomIndex ?? this.currentRoomIndex,
      cycleRank: cycleRank ?? this.cycleRank,
      status: status ?? this.status,
      roomLifecycle: roomLifecycle ?? this.roomLifecycle,
      clearedRoomIds: clearedRoomIds ?? this.clearedRoomIds,
      completionRewardClaimed:
          completionRewardClaimed ?? this.completionRewardClaimed,
    );
  }
}
