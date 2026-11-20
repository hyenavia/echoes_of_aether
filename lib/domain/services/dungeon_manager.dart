import 'dart:math' as math;

import '../entities/dungeon_definition.dart';
import '../entities/dungeon_session.dart';
import '../entities/enemy_definition.dart';
import '../entities/grid_point.dart';
import '../entities/player_save_snapshot.dart';
import '../entities/player_status.dart';
import '../entities/room_encounter.dart';
import 'difficulty_service.dart';
import 'encounter_tracker.dart';
import 'game_clock.dart';
import 'navigation_grid.dart';
import 'room_completion_evaluator.dart';

/// Alasan berakhirnya sesi dungeon.
enum DungeonEndReason { completed, defeated, abandoned, transitionFailed }

/// Event siklus hidup runtime dungeon untuk sinkronisasi antara domain/runtime
/// dengan Flame world maupun UI tanpa polling setiap frame.
sealed class DungeonRuntimeEvent {
  const DungeonRuntimeEvent(this.session);

  final DungeonSession session;
}

class DungeonStartedEvent extends DungeonRuntimeEvent {
  const DungeonStartedEvent(super.session, this.dungeon);

  final DungeonDefinition dungeon;
}

class RoomLoadingEvent extends DungeonRuntimeEvent {
  const RoomLoadingEvent(super.session, this.room);

  final RoomDefinition room;
}

class RoomLoadedEvent extends DungeonRuntimeEvent {
  const RoomLoadedEvent(
    super.session,
    this.room,
    this.grid,
    this.preparedSpawns,
  );

  final RoomDefinition room;
  final NavigationGrid grid;
  final List<RoomSpawnConfig> preparedSpawns;
}

class RoomActivatedEvent extends DungeonRuntimeEvent {
  const RoomActivatedEvent(super.session, this.room);

  final RoomDefinition room;
}

class RoomCompletedEvent extends DungeonRuntimeEvent {
  const RoomCompletedEvent(
    super.session,
    this.room,
    this.evaluation, {
    this.nextRoomId,
  });

  final RoomDefinition room;
  final RoomCompletionEvaluation evaluation;
  final String? nextRoomId;
}

class RoomTransitioningEvent extends DungeonRuntimeEvent {
  const RoomTransitioningEvent(super.session, this.fromRoomId, this.toRoomId);

  final String fromRoomId;
  final String toRoomId;
}

class RoomTransitionFailedEvent extends DungeonRuntimeEvent {
  const RoomTransitionFailedEvent(
    super.session,
    this.fromRoomId,
    this.targetRoomId,
    this.reason,
  );

  final String fromRoomId;
  final String? targetRoomId;
  final String reason;
}

class RoomUnloadedEvent extends DungeonRuntimeEvent {
  const RoomUnloadedEvent(super.session, this.roomId);

  final String roomId;
}

class DungeonEndedEvent extends DungeonRuntimeEvent {
  const DungeonEndedEvent(
    super.session,
    this.finalStatus, {
    this.reason,
    this.dungeon,
  });

  final DungeonSessionStatus finalStatus;
  final DungeonEndReason? reason;
  final DungeonDefinition? dungeon;

  DungeonEndReason get effectiveReason =>
      reason ??
      (finalStatus == DungeonSessionStatus.completed
          ? DungeonEndReason.completed
          : DungeonEndReason.defeated);
}

typedef DungeonEventListener = void Function(DungeonRuntimeEvent event);

/// Orkestrator runtime dungeon di layer domain (bebas Flutter & Flame).
///
/// Mengelola lifecycle `DungeonSession`, pemuatan & pembersihan room aktif,
/// evaluasi penyelesaian room, transisi antar-room berbasis konfigurasi graph,
/// validasi map/entry/exit, serta notifikasi event ke layer world/UI.
///
/// Tidak menangani perhitungan damage, AI monster, generator loot, derived
/// stats, atau persistensi database secara langsung.
class DungeonManager {
  DungeonManager({
    required Map<String, DungeonDefinition> dungeons,
    this.encounterTracker,
    this.completionEvaluator = const RoomCompletionEvaluator(),
    this.autoCompleteOnEncounter = false,
    String Function()? runIdGenerator,
    GameClock clock = const SystemGameClock(),
    this.difficultyService,
  }) : _dungeons = Map.unmodifiable(dungeons),
       _runIdGenerator = runIdGenerator ?? (() => _defaultRunId(clock)) {
    if (autoCompleteOnEncounter) {
      encounterTracker?.addListener(handleEncounterEvent);
    }
  }

  static int _runSequence = 0;

  static String _defaultRunId(GameClock clock) =>
      'run_${clock.nowMs}_${++_runSequence}';

  final Map<String, DungeonDefinition> _dungeons;
  final EncounterTracker? encounterTracker;
  final RoomCompletionEvaluator completionEvaluator;
  final bool autoCompleteOnEncounter;
  final String Function() _runIdGenerator;
  final DifficultyService? difficultyService;
  final List<DungeonEventListener> _listeners = [];

  DungeonSession? _session;
  DungeonDefinition? _activeDungeon;
  RoomDefinition? _activeRoom;
  NavigationGrid? _activeGrid;
  List<RoomSpawnConfig> _preparedSpawns = const [];
  GridPoint? _lastPlayerCell;
  RoomCompletionEvaluation? _lastEvaluation;
  bool _transitionInProgress = false;
  DifficultyProfile? _activeDifficultyProfile;

  DungeonSession? get session => _session;
  DungeonDefinition? get activeDungeon => _activeDungeon;
  RoomDefinition? get activeRoom => _activeRoom;
  NavigationGrid? get activeGrid => _activeGrid;
  List<RoomSpawnConfig> get preparedSpawns => _preparedSpawns;
  RoomCompletionEvaluation? get lastEvaluation => _lastEvaluation;
  bool get isTransitionInProgress => _transitionInProgress;
  DifficultyProfile get activeDifficultyProfile =>
      _activeDifficultyProfile ??
      encounterTracker?.difficultyProfile ??
      DifficultyProfile.identity;

  bool get hasActiveSession => _session != null && !_session!.isTerminal;

  void addListener(DungeonEventListener listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(DungeonEventListener listener) {
    _listeners.remove(listener);
  }

  /// Memperbarui sel terakhir player di room aktif (dipakai untuk evaluasi
  /// syarat `reach_exit` maupun event async dari `EncounterTracker`).
  void updatePlayerCell(GridPoint cell) {
    if (_session == null || _activeRoom == null || _session!.isTerminal) {
      return;
    }
    _lastPlayerCell = cell;
  }

  /// Memilih ID room berikutnya berdasarkan konfigurasi `next_room_ids` dan
  /// kebijakan deterministik MVP.
  String? selectNextRoomId([RoomDefinition? room, DungeonSession? session]) {
    final targetRoom = room ?? _activeRoom;
    final targetSession = session ?? _session;
    if (targetRoom == null) return null;
    return targetRoom.selectNextRoomId(
      clearedRoomIds: targetSession?.clearedRoomIds ?? const {},
    );
  }

  /// Memulai run dungeon baru untuk [dungeonId] dan langsung memuat room awal.
  ///
  /// Melempar [StateError] bila masih ada sesi aktif yang belum diakhiri, atau
  /// [ArgumentError] bila [dungeonId] / room awal tidak ditemukan.
  DungeonSession startDungeon(
    String dungeonId, {
    String? runId,
    String? startRoomId,
    int cycleRank = 0,
    DifficultyProfile? difficultyProfileOverride,
  }) {
    if (hasActiveSession) {
      throw StateError(
        'Sesi dungeon "${_session!.dungeonId}" (${_session!.runId}) masih aktif.',
      );
    }

    final dungeon = _dungeons[dungeonId];
    if (dungeon == null) {
      throw ArgumentError.value(
        dungeonId,
        'dungeonId',
        'Definisi dungeon tidak ditemukan.',
      );
    }

    final initialRoomId = startRoomId ?? dungeon.startRoomId;
    final initialRoom = dungeon.roomById(initialRoomId);
    final initialIndex = dungeon.indexOfRoom(initialRoomId);
    if (initialRoom == null || initialIndex < 0) {
      throw ArgumentError.value(
        initialRoomId,
        'startRoomId',
        'Room awal tidak valid untuk dungeon "$dungeonId".',
      );
    }

    final resolvedRunId = (runId != null && runId.trim().isNotEmpty)
        ? runId
        : _runIdGenerator();

    _activeDungeon = dungeon;
    _activeRoom = null;
    _activeGrid = null;
    _preparedSpawns = const [];
    _lastPlayerCell = null;
    _lastEvaluation = null;
    final effectiveRank = cycleRank < 0 ? 0 : cycleRank;
    if (difficultyProfileOverride != null) {
      _activeDifficultyProfile = difficultyProfileOverride;
      encounterTracker?.setDifficultyProfile(difficultyProfileOverride);
    } else {
      _applyDifficultyForRun(dungeon, effectiveRank);
    }
    _session = DungeonSession(
      runId: resolvedRunId,
      dungeonId: dungeon.id,
      currentRoomId: initialRoomId,
      currentRoomIndex: initialIndex,
      cycleRank: effectiveRank,
      status: DungeonSessionStatus.notStarted,
      roomLifecycle: RoomLifecycleState.notLoaded,
    ).transitionSession(DungeonSessionStatus.inProgress);

    _emit(DungeonStartedEvent(_session!, dungeon));
    loadRoom(initialRoomId);
    return _session!;
  }

  /// Memulai run dungeon dari [DungeonDefinition] runtime (misalnya The Infinite Spire arena).
  DungeonSession startRuntimeDungeon(
    DungeonDefinition dungeon, {
    String? runId,
    String? startRoomId,
    int cycleRank = 0,
    DifficultyProfile? difficultyProfileOverride,
  }) {
    if (hasActiveSession) {
      throw StateError(
        'Sesi dungeon "${_session!.dungeonId}" (${_session!.runId}) masih aktif.',
      );
    }

    final initialRoomId = startRoomId ?? dungeon.startRoomId;
    final initialRoom = dungeon.roomById(initialRoomId);
    final initialIndex = dungeon.indexOfRoom(initialRoomId);
    if (initialRoom == null || initialIndex < 0) {
      throw ArgumentError.value(
        initialRoomId,
        'startRoomId',
        'Room awal tidak valid untuk dungeon "${dungeon.id}".',
      );
    }

    final resolvedRunId = (runId != null && runId.trim().isNotEmpty)
        ? runId
        : _runIdGenerator();

    _activeDungeon = dungeon;
    _activeRoom = null;
    _activeGrid = null;
    _preparedSpawns = const [];
    _lastPlayerCell = null;
    _lastEvaluation = null;
    final effectiveRank = cycleRank < 0 ? 0 : cycleRank;
    if (difficultyProfileOverride != null) {
      _activeDifficultyProfile = difficultyProfileOverride;
      encounterTracker?.setDifficultyProfile(difficultyProfileOverride);
    } else {
      _applyDifficultyForRun(dungeon, effectiveRank);
    }
    _session = DungeonSession(
      runId: resolvedRunId,
      dungeonId: dungeon.id,
      currentRoomId: initialRoomId,
      currentRoomIndex: initialIndex,
      cycleRank: effectiveRank,
      status: DungeonSessionStatus.notStarted,
      roomLifecycle: RoomLifecycleState.notLoaded,
    ).transitionSession(DungeonSessionStatus.inProgress);

    _emit(DungeonStartedEvent(_session!, dungeon));
    loadRoom(initialRoomId);
    return _session!;
  }

  /// Memulai run Boss Event (Daily/Weekly) dari [DungeonDefinition] runtime,
  /// mendaftarkan monster boss ke [encounterTracker], serta menerapkan
  /// [difficultyProfile] boss.
  DungeonSession startBossDungeon({
    required DungeonDefinition bossDungeon,
    required EnemyDefinition bossMonster,
    required DifficultyProfile difficultyProfile,
    required String bossEventId,
    required String periodKeyAtStart,
    int cycleRank = 0,
    String? runId,
  }) {
    if (hasActiveSession) {
      throw StateError(
        'Sesi dungeon "${_session!.dungeonId}" (${_session!.runId}) masih aktif.',
      );
    }
    if (!bossDungeon.isBossEvent && !bossDungeon.isBossSpire) {
      throw ArgumentError.value(
        bossDungeon.kind,
        'bossDungeon.kind',
        'Harus bertipe bossDaily, bossWeekly, atau bossSpire.',
      );
    }

    final initialRoomId = bossDungeon.startRoomId;
    final initialRoom = bossDungeon.roomById(initialRoomId);
    final initialIndex = bossDungeon.indexOfRoom(initialRoomId);
    if (initialRoom == null || initialIndex < 0) {
      throw ArgumentError.value(
        initialRoomId,
        'startRoomId',
        'Room awal tidak valid untuk boss dungeon "${bossDungeon.id}".',
      );
    }

    final resolvedRunId = (runId != null && runId.trim().isNotEmpty)
        ? runId
        : _runIdGenerator();

    encounterTracker?.registerRuntimeMonster(bossMonster);
    _activeDungeon = bossDungeon;
    _activeRoom = null;
    _activeGrid = null;
    _preparedSpawns = const [];
    _lastPlayerCell = null;
    _lastEvaluation = null;
    final effectiveRank = cycleRank < 0 ? 0 : cycleRank;
    _activeDifficultyProfile = difficultyProfile;
    encounterTracker?.setDifficultyProfile(difficultyProfile);

    _session = DungeonSession(
      runId: resolvedRunId,
      dungeonId: bossDungeon.id,
      currentRoomId: initialRoomId,
      currentRoomIndex: initialIndex,
      cycleRank: effectiveRank,
      status: DungeonSessionStatus.notStarted,
      roomLifecycle: RoomLifecycleState.notLoaded,
      bossEventId: bossEventId,
      periodKeyAtStart: periodKeyAtStart,
    ).transitionSession(DungeonSessionStatus.inProgress);

    _emit(DungeonStartedEvent(_session!, bossDungeon));
    loadRoom(initialRoomId);
    return _session!;
  }

  /// Memulihkan sesi dungeon `inProgress` (atau `roomCompleted` ke room
  /// berikutnya yang belum selesai) ke awal room terakhir yang tersimpan.
  ///
  /// Mengembalikan `null` bila sesi terminal (`completed`/`failed`), `runId`
  /// kosong, definisi dungeon/room tidak ditemukan, atau tidak ada lagi room
  /// belum selesai yang dapat dimainkan (sehingga caller dapat mengarahkan
  /// pemain kembali ke Town dengan aman).
  DungeonSession? restoreSession(
    ActiveDungeonSessionSnapshot saved, {
    int? cycleRank,
    DungeonDefinition? runtimeDungeon,
    EnemyDefinition? runtimeBossMonster,
    DifficultyProfile? runtimeDifficultyProfile,
  }) {
    if (hasActiveSession) {
      throw StateError(
        'Sesi dungeon "${_session!.dungeonId}" (${_session!.runId}) masih aktif.',
      );
    }
    if (!saved.isRecoverable || saved.runId.trim().isEmpty) {
      return null;
    }

    final dungeon = runtimeDungeon ?? _dungeons[saved.dungeonId];
    if (dungeon == null) {
      return null;
    }

    var targetRoom = dungeon.roomById(saved.currentRoomId);
    if (targetRoom == null) {
      return null;
    }

    // Pastikan room yang sudah selesai tidak pernah dimainkan ulang untuk
    // mencegah duplikasi reward atau pengulangan progres yang sudah sah.
    final visited = <String>{};
    while (saved.clearedRoomIds.contains(targetRoom!.id) ||
        (saved.status == DungeonSessionStatus.roomCompleted &&
            targetRoom.id == saved.currentRoomId)) {
      if (!visited.add(targetRoom.id)) {
        return null;
      }
      final nextId = targetRoom.selectNextRoomId(
        clearedRoomIds: saved.clearedRoomIds,
      );
      if (nextId == null) {
        return null;
      }
      final nextRoom = dungeon.roomById(nextId);
      if (nextRoom == null || saved.clearedRoomIds.contains(nextRoom.id)) {
        return null;
      }
      targetRoom = nextRoom;
    }

    final targetIndex = dungeon.indexOfRoom(targetRoom.id);
    if (targetIndex < 0) {
      return null;
    }

    _activeDungeon = dungeon;
    _activeRoom = null;
    _activeGrid = null;
    _preparedSpawns = const [];
    _lastPlayerCell = null;
    _lastEvaluation = null;
    _transitionInProgress = false;
    final rawRank = cycleRank ?? saved.cycleRank;
    final effectiveRank = rawRank < 0 ? 0 : rawRank;
    if (runtimeBossMonster != null) {
      encounterTracker?.registerRuntimeMonster(runtimeBossMonster);
    }
    if (runtimeDifficultyProfile != null) {
      _activeDifficultyProfile = runtimeDifficultyProfile;
      encounterTracker?.setDifficultyProfile(runtimeDifficultyProfile);
    } else {
      _applyDifficultyForRun(dungeon, effectiveRank);
    }

    _session = DungeonSession(
      runId: saved.runId,
      dungeonId: dungeon.id,
      currentRoomId: targetRoom.id,
      currentRoomIndex: targetIndex,
      cycleRank: effectiveRank,
      status: DungeonSessionStatus.inProgress,
      roomLifecycle: RoomLifecycleState.notLoaded,
      clearedRoomIds: Set<String>.unmodifiable(saved.clearedRoomIds),
      completionRewardClaimed: saved.completionRewardClaimed,
      bossEventId: saved.bossEventId,
      periodKeyAtStart: saved.periodKeyAtStart,
    );

    _emit(DungeonStartedEvent(_session!, dungeon));
    loadRoom(targetRoom.id);
    return _session!;
  }

  /// Menandai completion reward dungeon untuk sesi aktif/terminal saat ini
  /// sebagai sudah diklaim agar tidak pernah diproses ganda.
  void markCompletionRewardClaimed() {
    final current = _session;
    if (current == null || current.completionRewardClaimed) return;
    _session = current.copyWith(completionRewardClaimed: true);
  }

  /// Mengekspor snapshot sesi saat ini untuk persistensi recovery Drift/SQLite.
  ActiveDungeonSessionSnapshot? toActiveSessionSnapshot({
    int reviveCooldownTicks = 0,
    PlayerStatus playerStatus = PlayerStatus.alive,
  }) {
    final current = _session;
    if (current == null) return null;
    return ActiveDungeonSessionSnapshot(
      runId: current.runId,
      dungeonId: current.dungeonId,
      currentRoomId: current.currentRoomId,
      currentRoomIndex: current.currentRoomIndex,
      status: current.status,
      clearedRoomIds: current.clearedRoomIds,
      completionRewardClaimed: current.completionRewardClaimed,
      reviveCooldownTicks: reviveCooldownTicks < 0 ? 0 : reviveCooldownTicks,
      playerStatus: playerStatus,
      cycleRank: current.cycleRank < 0 ? 0 : current.cycleRank,
      bossEventId: current.bossEventId,
      periodKeyAtStart: current.periodKeyAtStart,
    );
  }

  /// Memuat [roomId] pada sesi dungeon aktif.
  ///
  /// - Idempotent bila [roomId] sudah dalam state `loading`, `ready`, atau `active`.
  /// - Melepas room sebelumnya terlebih dahulu sebelum room baru dimuat.
  /// - Memvalidasi `layout`, `entryPosition`, dan `exitPosition` sebelum
  ///   menandai room sebagai `ready`.
  RoomDefinition loadRoom(String roomId) {
    final currentSession = _session;
    final dungeon = _activeDungeon;
    if (currentSession == null ||
        dungeon == null ||
        currentSession.isTerminal) {
      throw StateError('Tidak ada sesi dungeon aktif untuk memuat room.');
    }

    if (currentSession.currentRoomId == roomId &&
        (currentSession.roomLifecycle == RoomLifecycleState.loading ||
            currentSession.roomLifecycle == RoomLifecycleState.ready ||
            currentSession.roomLifecycle == RoomLifecycleState.active)) {
      if (_activeRoom != null) {
        return _activeRoom!;
      }
    }

    final room = dungeon.roomById(roomId);
    if (room == null) {
      throw ArgumentError.value(
        roomId,
        'roomId',
        'Room tidak ditemukan di dungeon "${dungeon.id}".',
      );
    }

    final roomIndex = dungeon.indexOfRoom(roomId);
    if (roomIndex < 0) {
      throw StateError(
        'Room "$roomId" tidak terdaftar di roomOrder dungeon "${dungeon.id}".',
      );
    }

    unloadCurrentRoom();

    var nextSession = _session!;
    if (nextSession.status == DungeonSessionStatus.roomCompleted) {
      nextSession = nextSession.transitionSession(
        DungeonSessionStatus.inProgress,
      );
    }
    _session = nextSession
        .copyWith(currentRoomId: room.id, currentRoomIndex: roomIndex)
        .transitionRoom(RoomLifecycleState.loading);
    _emit(RoomLoadingEvent(_session!, room));

    try {
      final grid = room.createNavigationGrid();
      if (!grid.isWalkable(room.entryPosition.x, room.entryPosition.y)) {
        throw StateError(
          'Entry position ${room.entryPosition} pada room "${room.id}" tidak walkable.',
        );
      }
      if (!grid.isWalkable(room.exitPosition.x, room.exitPosition.y)) {
        throw StateError(
          'Exit position ${room.exitPosition} pada room "${room.id}" tidak walkable.',
        );
      }

      final spawns = resolveRoomSpawns(
        room: room,
        cycleRank: _session?.cycleRank ?? 0,
        grid: grid,
        dungeon: dungeon,
      );
      _activeRoom = room;
      _activeGrid = grid;
      _preparedSpawns = spawns;
      _lastPlayerCell = room.entryPosition;
      _lastEvaluation = null;
      encounterTracker?.prepareRoom(room, spawns: spawns);
      _session = _session!.transitionRoom(RoomLifecycleState.ready);
      _emit(RoomLoadedEvent(_session!, room, grid, spawns));
      return room;
    } catch (_) {
      encounterTracker?.clearRoom();
      _activeRoom = null;
      _activeGrid = null;
      _preparedSpawns = const [];
      _lastPlayerCell = null;
      _lastEvaluation = null;
      if (_session != null &&
          DungeonSession.isValidRoomTransition(
            _session!.roomLifecycle,
            RoomLifecycleState.unloaded,
          )) {
        _session = _session!.transitionRoom(RoomLifecycleState.unloaded);
      }
      rethrow;
    }
  }

  /// Menandai room yang sudah `ready` menjadi `active` (setelah komponen world
  /// selesai dipasang dan siap disimulasikan). Idempotent bila sudah `active`.
  void activateRoom() {
    final currentSession = _session;
    final room = _activeRoom;
    if (currentSession == null || room == null || currentSession.isTerminal) {
      throw StateError('Tidak ada room siap untuk diaktifkan.');
    }
    if (currentSession.roomLifecycle == RoomLifecycleState.active) {
      return;
    }
    if (currentSession.roomLifecycle != RoomLifecycleState.ready) {
      throw StateError(
        'Room "${room.id}" belum siap diaktifkan '
        '(state: ${currentSession.roomLifecycle.name}).',
      );
    }
    _session = currentSession.transitionRoom(RoomLifecycleState.active);
    _emit(RoomActivatedEvent(_session!, room));
  }

  /// Mengevaluasi kondisi penyelesaian room aktif secara domain tanpa mengubah
  /// state lifecycle.
  RoomCompletionEvaluation evaluateCurrentRoom({GridPoint? playerCell}) {
    final currentSession = _session;
    final room = _activeRoom;
    if (currentSession == null || room == null) {
      throw StateError('Tidak ada room aktif untuk dievaluasi.');
    }
    if (playerCell != null) {
      _lastPlayerCell = playerCell;
    }
    final evaluation = completionEvaluator.evaluate(
      room: room,
      roomLifecycle: currentSession.roomLifecycle,
      encounters: encounterTracker?.encounters ?? const [],
      playerCell: _lastPlayerCell,
    );
    _lastEvaluation = evaluation;
    return evaluation;
  }

  /// Mencoba menyelesaikan room aktif jika seluruh `completionCondition`
  /// terpenuhi. Idempotent dan menolak event usang/duplikat atau room yang
  /// belum berstatus `active`.
  ///
  /// - Untuk room non-final: menandai room `completed` dan sesi `roomCompleted`,
  ///   lalu memancarkan `RoomCompletedEvent`.
  /// - Untuk room final (`nextRoomIds` kosong): memancarkan `RoomCompletedEvent`,
  ///   lalu mengakhiri dungeon dengan `DungeonSessionStatus.completed` dan
  ///   memancarkan `DungeonEndedEvent` satu kali.
  bool tryCompleteActiveRoom({
    GridPoint? playerCell,
    String? expectedRunId,
    String? expectedRoomId,
  }) {
    if (_transitionInProgress) return false;
    final currentSession = _session;
    final room = _activeRoom;
    if (currentSession == null || room == null || currentSession.isTerminal) {
      return false;
    }
    if (expectedRunId != null && expectedRunId != currentSession.runId) {
      return false;
    }
    if (expectedRoomId != null && expectedRoomId != room.id) {
      return false;
    }
    if (currentSession.roomLifecycle != RoomLifecycleState.active) {
      return false;
    }
    if (currentSession.isRoomCleared(room.id)) {
      return false;
    }

    final evaluation = evaluateCurrentRoom(playerCell: playerCell);
    if (!evaluation.isCompleted) {
      return false;
    }

    _session = currentSession.transitionRoom(RoomLifecycleState.completing);
    final updatedCleared = Set<String>.unmodifiable({
      ..._session!.clearedRoomIds,
      room.id,
    });
    final nextRoomId = selectNextRoomId(room, _session);

    _session = _session!
        .transitionRoom(RoomLifecycleState.completed)
        .transitionSession(
          DungeonSessionStatus.roomCompleted,
          clearedRoomIds: updatedCleared,
        );
    _emit(
      RoomCompletedEvent(_session!, room, evaluation, nextRoomId: nextRoomId),
    );

    if (nextRoomId == null) {
      endRun(
        finalStatus: DungeonSessionStatus.completed,
        reason: DungeonEndReason.completed,
      );
    }
    return true;
  }

  /// Menjalankan transisi dari room yang sudah berstatus `completed` ke room
  /// berikutnya berdasarkan `next_room_ids`.
  ///
  /// Menolak panggilan ulang saat transisi masih berlangsung, saat room belum
  /// `completed`, atau saat sesi sudah terminal. Kegagalan lookup/load room
  /// berikutnya ditangani secara aman dengan `RoomTransitionFailedEvent` dan
  /// membersihkan state room tanpa menyisakan state setengah aktif.
  bool transitionToNextRoom() {
    if (_transitionInProgress) return false;
    final currentSession = _session;
    final dungeon = _activeDungeon;
    final currentRoom = _activeRoom;
    if (currentSession == null ||
        dungeon == null ||
        currentRoom == null ||
        currentSession.isTerminal) {
      return false;
    }
    if (currentSession.roomLifecycle != RoomLifecycleState.completed) {
      return false;
    }

    final nextRoomId = selectNextRoomId(currentRoom, currentSession);
    if (nextRoomId == null) {
      endRun(
        finalStatus: DungeonSessionStatus.completed,
        reason: DungeonEndReason.completed,
      );
      return true;
    }

    final targetRoom = dungeon.roomById(nextRoomId);
    final targetIndex = dungeon.indexOfRoom(nextRoomId);
    if (targetRoom == null || targetIndex < 0) {
      _failTransition(
        currentRoom.id,
        nextRoomId,
        'Next room "$nextRoomId" tidak ditemukan pada konfigurasi dungeon "${dungeon.id}".',
      );
      return false;
    }

    _transitionInProgress = true;
    try {
      _session = _session!.transitionRoom(RoomLifecycleState.transitioning);
      _emit(RoomTransitioningEvent(_session!, currentRoom.id, nextRoomId));
      unloadCurrentRoom();
      loadRoom(nextRoomId);
      return true;
    } catch (e) {
      _failTransition(currentRoom.id, nextRoomId, e.toString());
      return false;
    } finally {
      _transitionInProgress = false;
    }
  }

  /// Pembantu satu langkah untuk skenario sinkron: mengevaluasi room aktif,
  /// menandainya selesai jika memenuhi syarat, lalu langsung bertransisi ke
  /// room berikutnya (atau menyelesaikan dungeon jika room final).
  bool advanceRoomIfCompleted({GridPoint? playerCell}) {
    final completed = tryCompleteActiveRoom(playerCell: playerCell);
    if (!completed) return false;
    final currentSession = _session;
    if (currentSession == null || currentSession.isTerminal) {
      return true;
    }
    return transitionToNextRoom();
  }

  /// Melepas room aktif dan membersihkan referensi map/spawn runtime.
  /// Aman dipanggil berulang kali dan tidak pernah dihitung sebagai completion.
  void unloadCurrentRoom() {
    final currentSession = _session;
    if (currentSession == null) return;

    final lifecycle = currentSession.roomLifecycle;
    final hadRuntimeRoom =
        _activeRoom != null ||
        _activeGrid != null ||
        (lifecycle != RoomLifecycleState.notLoaded &&
            lifecycle != RoomLifecycleState.unloaded);
    if (!hadRuntimeRoom) return;

    final unloadedRoomId = _activeRoom?.id ?? currentSession.currentRoomId;
    Object? cleanupError;
    try {
      encounterTracker?.clearRoom();
    } catch (e) {
      cleanupError = e;
    } finally {
      _activeRoom = null;
      _activeGrid = null;
      _preparedSpawns = const [];
      _lastPlayerCell = null;
      _lastEvaluation = null;

      if (DungeonSession.isValidRoomTransition(
        lifecycle,
        RoomLifecycleState.unloaded,
      )) {
        _session = currentSession.transitionRoom(RoomLifecycleState.unloaded);
      }
    }
    try {
      _emit(RoomUnloadedEvent(_session!, unloadedRoomId));
    } catch (e) {
      cleanupError ??= e;
    }
    if (cleanupError != null) {
      // Tetap pastikan referensi bersih walau listener/tracker melempar error.
      Error.throwWithStackTrace(cleanupError, StackTrace.current);
    }
  }

  /// Mengakhiri dungeon run secara terkendali (`completed` atau `failed`) dan
  /// melepas room yang masih dimuat. Idempotent bila sesi sudah terminal.
  DungeonSession endRun({
    DungeonSessionStatus finalStatus = DungeonSessionStatus.failed,
    DungeonEndReason? reason,
  }) {
    if (finalStatus != DungeonSessionStatus.completed &&
        finalStatus != DungeonSessionStatus.failed) {
      throw ArgumentError.value(
        finalStatus,
        'finalStatus',
        'Status akhir harus completed atau failed.',
      );
    }

    final currentSession = _session;
    if (currentSession == null) {
      throw StateError('Tidak ada sesi dungeon yang sedang berjalan.');
    }
    if (currentSession.isTerminal) {
      _safeUnload();
      return currentSession;
    }

    _safeUnload();
    _session = _session!.transitionSession(finalStatus);
    _emit(
      DungeonEndedEvent(
        _session!,
        finalStatus,
        reason: reason,
        dungeon: _activeDungeon,
      ),
    );
    return _session!;
  }

  /// Mengakhiri sesi aktif bila masih berjalan lalu membersihkan seluruh state
  /// runtime saat pemain kembali ke Town.
  void exitToTown() {
    if (_session != null && !_session!.isTerminal) {
      endRun(
        finalStatus: DungeonSessionStatus.failed,
        reason: DungeonEndReason.abandoned,
      );
    } else {
      _safeUnload();
    }
    _session = null;
    _activeDungeon = null;
    _activeRoom = null;
    _activeGrid = null;
    _preparedSpawns = const [];
    _lastPlayerCell = null;
    _lastEvaluation = null;
    _transitionInProgress = false;
    _activeDifficultyProfile = null;
  }

  void _applyDifficultyForRun(DungeonDefinition dungeon, int cycleRank) {
    final service = difficultyService;
    if (service != null) {
      final profile = service.profileFor(dungeon, cycleRank);
      _activeDifficultyProfile = profile;
      encounterTracker?.setDifficultyProfile(profile);
      return;
    }
    if (dungeon.difficultyScale != 1.0 || cycleRank != 0) {
      final profile = const DifficultyService().profileFor(dungeon, cycleRank);
      _activeDifficultyProfile = profile;
      encounterTracker?.setDifficultyProfile(profile);
      return;
    }
    _activeDifficultyProfile = encounterTracker?.difficultyProfile;
  }

  /// Membersihkan seluruh resource runtime dan listener.
  void dispose() {
    if (autoCompleteOnEncounter) {
      encounterTracker?.removeListener(handleEncounterEvent);
    }
    exitToTown();
    encounterTracker?.dispose();
    _listeners.clear();
  }

  /// Memproses event [EncounterEvent] secara aman terhadap stale room/session.
  /// Mengembalikan `true` jika event berhasil memicu penyelesaian room aktif.
  bool handleEncounterEvent(EncounterEvent event) {
    if (event is! RoomEncountersCompletedEvent) return false;
    final currentSession = _session;
    final room = _activeRoom;
    if (currentSession == null ||
        room == null ||
        currentSession.isTerminal ||
        currentSession.roomLifecycle != RoomLifecycleState.active) {
      return false;
    }
    if (event.roomId != room.id) {
      return false;
    }
    return tryCompleteActiveRoom(
      playerCell: _lastPlayerCell,
      expectedRunId: currentSession.runId,
      expectedRoomId: room.id,
    );
  }

  void _failTransition(String fromRoomId, String? targetRoomId, String reason) {
    _safeUnload();
    final session = _session;
    if (session != null && !session.isTerminal) {
      _emit(
        RoomTransitionFailedEvent(session, fromRoomId, targetRoomId, reason),
      );
      endRun(
        finalStatus: DungeonSessionStatus.failed,
        reason: DungeonEndReason.transitionFailed,
      );
    }
  }

  void _safeUnload() {
    try {
      unloadCurrentRoom();
    } catch (_) {
      // Pastikan state manager bersih walau callback/cleanup eksternal gagal.
      _activeRoom = null;
      _activeGrid = null;
      _preparedSpawns = const [];
      _lastPlayerCell = null;
      _lastEvaluation = null;
    }
  }

  static List<RoomSpawnConfig> resolveRoomSpawns({
    required RoomDefinition room,
    required int cycleRank,
    required NavigationGrid grid,
    DungeonDefinition? dungeon,
  }) {
    if (cycleRank <= 0 || room.spawns.isEmpty) {
      return List<RoomSpawnConfig>.unmodifiable(room.spawns);
    }

    if (room.completionCondition.type !=
        RoomCompletionConditionType.defeatRequiredEnemies) {
      return List<RoomSpawnConfig>.unmodifiable(room.spawns);
    }

    final isEliteRoom =
        room.type == RoomType.elite || room.spawns.any((s) => s.isElite);
    final isBossRoom =
        room.type == RoomType.boss || room.spawns.any((s) => s.isBoss);
    if (!isEliteRoom && !isBossRoom) {
      return List<RoomSpawnConfig>.unmodifiable(room.spawns);
    }

    final primarySpawn = room.spawns.firstWhere(
      (s) => s.isBoss || s.isElite,
      orElse: () => room.spawns.first,
    );

    if (dungeon?.isAscension == true && isBossRoom) {
      return List<RoomSpawnConfig>.unmodifiable(room.spawns);
    }

    final guardCount = isBossRoom
        ? math.min(3, 1 + cycleRank ~/ 2)
        : math.min(2, 1 + (cycleRank - 1) ~/ 2);

    if (guardCount <= 0) {
      return List<RoomSpawnConfig>.unmodifiable(room.spawns);
    }

    final guardMonsterId = _findGuardMonsterId(room, dungeon);
    if (guardMonsterId == null) {
      return List<RoomSpawnConfig>.unmodifiable(room.spawns);
    }

    final occupied = <GridPoint>{
      room.entryPosition,
      room.exitPosition,
      for (final sp in room.spawns) sp.position,
    };

    const candidateOffsets = [
      GridPoint(-2, 0),
      GridPoint(2, 0),
      GridPoint(0, -2),
      GridPoint(0, 2),
      GridPoint(-1, -1),
      GridPoint(1, -1),
      GridPoint(-1, 1),
      GridPoint(1, 1),
      GridPoint(-2, -1),
      GridPoint(2, -1),
      GridPoint(-2, 1),
      GridPoint(2, 1),
      GridPoint(-3, 0),
      GridPoint(3, 0),
      GridPoint(0, -3),
      GridPoint(0, 3),
    ];

    final dynamicGuards = <RoomSpawnConfig>[];
    var guardIndex = 0;
    for (final offset in candidateOffsets) {
      if (dynamicGuards.length >= guardCount) break;
      final cell = GridPoint(
        primarySpawn.position.x + offset.x,
        primarySpawn.position.y + offset.y,
      );
      if (!grid.inBounds(cell.x, cell.y) || !grid.isWalkable(cell.x, cell.y)) {
        continue;
      }
      if (occupied.contains(cell)) continue;

      occupied.add(cell);
      dynamicGuards.add(
        RoomSpawnConfig(
          id: 'guard_${room.id}_${guardIndex++}',
          monsterId: guardMonsterId,
          position: cell,
          quantity: 1,
          required: true,
          spawnGroup: primarySpawn.spawnGroup,
          statModifier: const SpawnStatModifier(
            hpMultiplier: 0.6,
            atkMultiplier: 0.7,
          ),
        ),
      );
    }

    return List<RoomSpawnConfig>.unmodifiable([
      ...room.spawns,
      ...dynamicGuards,
    ]);
  }

  static String? _findGuardMonsterId(
    RoomDefinition room,
    DungeonDefinition? dungeon,
  ) {
    if (dungeon == null) return null;
    for (final r in dungeon.rooms.values) {
      if (r.id == room.id ||
          r.type == RoomType.boss ||
          r.type == RoomType.elite) {
        continue;
      }
      for (final sp in r.spawns) {
        if (!sp.isElite && !sp.isBoss) {
          return sp.monsterId;
        }
      }
    }
    return null;
  }

  void _emit(DungeonRuntimeEvent event) {
    for (final listener in List<DungeonEventListener>.of(_listeners)) {
      listener(event);
    }
  }
}
