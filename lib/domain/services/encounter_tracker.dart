import 'dart:collection';
import 'dart:math' as math;

import '../entities/dungeon_definition.dart';
import '../entities/enemy_definition.dart';
import '../entities/grid_point.dart';
import '../entities/room_encounter.dart';
import 'combat_simulation.dart';
import 'difficulty_service.dart';
import 'navigation_grid.dart';
import 'room_completion_evaluator.dart';

/// Kapan spawn bertipe `SpawnActivationState.immediate` dijalankan.
enum ImmediateSpawnPhase { onRoomLoaded, onRoomActivated }

typedef EncounterEventListener = void Function(EncounterEvent event);

/// Pelacak encounter dan orkestrator spawn musuh berbasis konfigurasi room di
/// layer domain (bebas Flutter, Flame, dan `EnemyComponent`).
class EncounterTracker {
  EncounterTracker({
    required Map<String, EnemyDefinition> monsterCatalog,
    this.immediateSpawnPhase = ImmediateSpawnPhase.onRoomActivated,
    DifficultyProfile difficultyProfile = DifficultyProfile.identity,
    this.difficultyService = const DifficultyService(),
  }) : _monsterCatalog = Map.unmodifiable(monsterCatalog),
       _activeDifficultyProfile = difficultyProfile;

  final Map<String, EnemyDefinition> _monsterCatalog;
  final ImmediateSpawnPhase immediateSpawnPhase;
  final DifficultyService difficultyService;
  DifficultyProfile _activeDifficultyProfile;

  DifficultyProfile get difficultyProfile => _activeDifficultyProfile;

  void setDifficultyProfile(DifficultyProfile profile) {
    _activeDifficultyProfile = profile;
  }

  final List<EncounterEventListener> _listeners = [];
  final List<String> _orderedEncounterIds = [];
  final Map<String, RoomEncounterState> _encountersById = {};
  final Map<String, RoomSpawnConfig> _configsById = {};
  final Map<String, String> _enemyIdToEncounterId = {};
  final Set<String> _processedDeathIds = {};
  final Set<String> _activatedSpawnConfigIds = {};
  final Set<String> _completedGroups = {};

  RoomDefinition? _currentRoom;
  bool _roomEncountersCompletedEmitted = false;

  String? get currentRoomId => _currentRoom?.id;

  List<RoomEncounterState> get encounters => List.unmodifiable([
    for (final id in _orderedEncounterIds) _encountersById[id]!,
  ]);

  RoomEncounterState? encounterById(String encounterId) =>
      _encountersById[encounterId];

  RoomEncounterState? encounterForSpawnConfig(String spawnConfigId) {
    final roomId = _currentRoom?.id;
    if (roomId == null) return null;
    return _encountersById[_encounterIdFor(roomId, spawnConfigId)];
  }

  List<RoomEncounterState> encountersInGroup(String spawnGroup) => encounters
      .where((e) => e.spawnGroup == spawnGroup)
      .toList(growable: false);

  List<RoomEncounterState> get eliteEncounters =>
      encounters.where((e) => e.isElite).toList(growable: false);

  List<RoomEncounterState> get bossEncounters =>
      encounters.where((e) => e.isBoss).toList(growable: false);

  RoomEncounterState? get primaryBossEncounter {
    for (final encounter in encounters) {
      if (encounter.isBoss) return encounter;
    }
    return null;
  }

  bool get hasBossEncounter => encounters.any((e) => e.isBoss);
  bool get hasEliteEncounter => encounters.any((e) => e.isElite);

  int get totalPlannedEnemies =>
      encounters.fold(0, (sum, e) => sum + e.plannedCount);

  int get totalSpawnedEnemies =>
      encounters.fold(0, (sum, e) => sum + e.spawnedCount);

  int get totalActiveEnemies =>
      encounters.fold(0, (sum, e) => sum + e.activeCount);

  int get totalDefeatedEnemies =>
      encounters.fold(0, (sum, e) => sum + e.defeatedCount);

  bool get allEncountersCompleted =>
      encounters.isNotEmpty && encounters.every((e) => e.isCompleted);

  bool get allRequiredEncountersCompleted {
    final room = _currentRoom;
    if (room == null) return false;
    return _areRoomCompletionTargetsDefeated(room);
  }

  bool get allRequiredElitesDefeated {
    final requiredElites = encounters
        .where((e) => e.isElite && e.requiredForCompletion)
        .toList();
    return requiredElites.isNotEmpty &&
        requiredElites.every((e) => e.isCompleted);
  }

  bool get allRequiredBossesDefeated {
    final requiredBosses = encounters
        .where((e) => e.isBoss && e.requiredForCompletion)
        .toList();
    return requiredBosses.isNotEmpty &&
        requiredBosses.every((e) => e.isCompleted);
  }

  bool isGroupCompleted(String spawnGroup) =>
      _completedGroups.contains(spawnGroup);

  bool hasSpawnActivated(String spawnConfigId) =>
      _activatedSpawnConfigIds.contains(spawnConfigId);

  void addListener(EncounterEventListener listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(EncounterEventListener listener) {
    _listeners.remove(listener);
  }

  /// Menyiapkan state encounter awal (`pending`) untuk [room].
  /// Membersihkan tracking room sebelumnya tanpa menghitung kematian palsu.
  void prepareRoom(RoomDefinition room, {List<RoomSpawnConfig>? spawns}) {
    clearRoom();
    _currentRoom = room;

    final effectiveSpawns = spawns ?? room.spawns;
    for (final config in effectiveSpawns) {
      final encounterId = _encounterIdFor(room.id, config.id);
      if (_encountersById.containsKey(encounterId)) {
        throw ArgumentError.value(
          config.id,
          'spawns',
          'ID spawn ganda "${config.id}" pada room "${room.id}".',
        );
      }

      final definition = _monsterCatalog[config.monsterId];
      final type = _resolveEncounterType(config, definition);

      _orderedEncounterIds.add(encounterId);
      _configsById[encounterId] = config;
      _encountersById[encounterId] = RoomEncounterState(
        encounterId: encounterId,
        roomId: room.id,
        spawnConfigId: config.id,
        spawnGroup: config.spawnGroup,
        monsterId: config.monsterId,
        type: type,
        requiredForCompletion: config.required,
        activationState: config.activationState,
        activationTriggerGroup: config.activationTriggerGroup,
        plannedCount: config.quantity,
      );
    }
  }

  /// Dipanggil saat room selesai dimuat (sebelum/saat mounting).
  List<SpawnedEnemyRecord> onRoomLoaded(
    CombatSimulation simulation, {
    required NavigationGrid grid,
  }) {
    if (immediateSpawnPhase != ImmediateSpawnPhase.onRoomLoaded) {
      return const [];
    }
    return _activateImmediateSpawns(simulation: simulation, grid: grid);
  }

  /// Dipanggil saat room berstatus `RoomLifecycleState.active`.
  List<SpawnedEnemyRecord> onRoomActivated(
    CombatSimulation simulation, {
    required NavigationGrid grid,
  }) {
    if (immediateSpawnPhase != ImmediateSpawnPhase.onRoomActivated) {
      return const [];
    }
    return _activateImmediateSpawns(simulation: simulation, grid: grid);
  }

  /// Memicu spawn bertipe `SpawnActivationState.manual` secara idempotent.
  List<SpawnedEnemyRecord> triggerManualSpawn(
    String spawnConfigId, {
    required CombatSimulation simulation,
    required NavigationGrid grid,
  }) {
    final room = _currentRoom;
    if (room == null) return const [];
    final encounterId = _encounterIdFor(room.id, spawnConfigId);
    final encounter = _encountersById[encounterId];
    final config = _configsById[encounterId];
    if (encounter == null ||
        config == null ||
        config.activationState != SpawnActivationState.manual) {
      return const [];
    }
    return _activateSingleEncounter(
      encounterId,
      simulation: simulation,
      grid: grid,
    );
  }

  /// Memicu seluruh spawn manual di dalam [spawnGroup] secara idempotent.
  List<SpawnedEnemyRecord> triggerManualGroup(
    String spawnGroup, {
    required CombatSimulation simulation,
    required NavigationGrid grid,
  }) {
    final spawned = <SpawnedEnemyRecord>[];
    for (final encounterId in List<String>.of(_orderedEncounterIds)) {
      final config = _configsById[encounterId];
      if (config != null &&
          config.spawnGroup == spawnGroup &&
          config.activationState == SpawnActivationState.manual) {
        spawned.addAll(
          _activateSingleEncounter(
            encounterId,
            simulation: simulation,
            grid: grid,
          ),
        );
      }
    }
    return List.unmodifiable(spawned);
  }

  /// Memperbarui encounter tracking saat `EnemyDefeatedEvent` terjadi di
  /// `CombatSimulation`. Event duplikat atau musuh yang tidak dikenal/belum
  /// di-spawn diabaikan secara aman.
  List<SpawnedEnemyRecord> onEnemyDefeated(
    String enemyId, {
    CombatSimulation? simulation,
    NavigationGrid? grid,
  }) {
    final encounterId = _enemyIdToEncounterId[enemyId];
    if (encounterId == null) return const [];
    if (!_processedDeathIds.add(enemyId)) return const [];

    final current = _encountersById[encounterId];
    if (current == null || current.isFailed) return const [];

    final nextDefeated = math.min(
      current.spawnedCount,
      current.defeatedCount + 1,
    );
    final nextActive = math.max(0, current.spawnedCount - nextDefeated);
    final reachedCompletion =
        current.spawnedCount == current.plannedCount &&
        nextDefeated >= current.spawnedCount;
    final nextStatus = reachedCompletion
        ? EncounterStatus.completed
        : current.status;

    final updated = current.copyWith(
      activeCount: nextActive,
      defeatedCount: nextDefeated,
      status: nextStatus,
    );
    _encountersById[encounterId] = updated;
    _emit(EncounterUpdatedEvent(updated.roomId, updated));

    final triggeredSpawns = <SpawnedEnemyRecord>[];
    if (reachedCompletion && !current.isCompleted) {
      _emit(EncounterCompletedEvent(updated.roomId, updated));
      triggeredSpawns.addAll(
        _onGroupProgressed(
          updated.spawnGroup,
          simulation: simulation,
          grid: grid,
        ),
      );
      _checkRoomEncountersCompleted();
    }

    return List.unmodifiable(triggeredSpawns);
  }

  /// Menandai encounter yang belum selesai sebagai `failed` ketika dungeon run
  /// berakhir karena kekalahan player (tanpa menambah defeatedCount).
  void onRunFailed() {
    for (final id in _orderedEncounterIds) {
      final current = _encountersById[id]!;
      if (current.isPending || current.isActive) {
        final failed = current.copyWith(status: EncounterStatus.failed);
        _encountersById[id] = failed;
        _emit(EncounterUpdatedEvent(failed.roomId, failed));
      }
    }
  }

  /// Membersihkan seluruh tracking room tanpa menghitung cleanup sebagai kematian
  /// monster maupun penyelesaian encounter.
  void clearRoom() {
    _currentRoom = null;
    _orderedEncounterIds.clear();
    _encountersById.clear();
    _configsById.clear();
    _enemyIdToEncounterId.clear();
    _processedDeathIds.clear();
    _activatedSpawnConfigIds.clear();
    _completedGroups.clear();
    _roomEncountersCompletedEmitted = false;
  }

  void dispose() {
    clearRoom();
    _listeners.clear();
  }

  List<SpawnedEnemyRecord> _activateImmediateSpawns({
    required CombatSimulation simulation,
    required NavigationGrid grid,
  }) {
    final spawned = <SpawnedEnemyRecord>[];
    for (final encounterId in List<String>.of(_orderedEncounterIds)) {
      final config = _configsById[encounterId];
      if (config != null &&
          config.activationState == SpawnActivationState.immediate) {
        spawned.addAll(
          _activateSingleEncounter(
            encounterId,
            simulation: simulation,
            grid: grid,
          ),
        );
      }
    }
    return List.unmodifiable(spawned);
  }

  List<SpawnedEnemyRecord> _activateSingleEncounter(
    String encounterId, {
    required CombatSimulation simulation,
    required NavigationGrid grid,
  }) {
    final room = _currentRoom;
    final encounter = _encountersById[encounterId];
    final config = _configsById[encounterId];
    if (room == null || encounter == null || config == null) {
      return const [];
    }
    if (!encounter.isPending || !_activatedSpawnConfigIds.add(config.id)) {
      return const [];
    }

    final definition = _monsterCatalog[config.monsterId];
    if (definition == null) {
      return _failEncounter(
        encounter,
        'Monster "${config.monsterId}" tidak ditemukan di katalog.',
      );
    }

    if ((config.isElite && config.isBoss) ||
        (definition.isElite && definition.isBoss) ||
        (config.isBoss && definition.isElite) ||
        (config.isElite && definition.isBoss)) {
      return _failEncounter(
        encounter,
        'Konflik role elite/boss pada spawn "${config.id}" (${config.monsterId}).',
      );
    }

    if (!grid.inBounds(config.position.x, config.position.y) ||
        !grid.isWalkable(config.position.x, config.position.y)) {
      return _failEncounter(
        encounter,
        'Posisi spawn ${config.position} pada room "${room.id}" tidak walkable.',
      );
    }

    final modifiedStats = config.statModifier.applyTo(definition.stats);
    final effectiveStats = difficultyService.scaleMonsterStats(
      modifiedStats,
      _activeDifficultyProfile,
    );
    final isBoss = config.isBoss || definition.isBoss;
    final isElite = !isBoss && (config.isElite || definition.isElite);
    final cells = _resolveSpawnCells(
      grid: grid,
      origin: config.position,
      quantity: config.quantity,
      simulation: simulation,
    );

    final spawnedRecords = <SpawnedEnemyRecord>[];
    final spawnedIds = <String>[];
    try {
      for (var i = 0; i < config.quantity; i++) {
        final enemyId = '${room.id}__${config.id}__$i';
        final cell = cells[i];
        final combatant = simulation.spawnEnemy(
          definition,
          cell,
          id: enemyId,
          statsOverride: effectiveStats,
          isEliteOverride: isElite,
          isBossOverride: isBoss,
        );
        _enemyIdToEncounterId[combatant.id] = encounterId;
        spawnedIds.add(combatant.id);
        spawnedRecords.add(
          SpawnedEnemyRecord(
            encounterId: encounterId,
            enemyId: combatant.id,
            monsterId: definition.id,
            type: encounter.type,
            spawnCell: cell,
          ),
        );
      }
    } catch (e) {
      for (final enemyId in spawnedIds) {
        _enemyIdToEncounterId.remove(enemyId);
      }
      return _failEncounter(encounter, e.toString());
    }

    final updated = encounter.copyWith(
      spawnedCount: spawnedRecords.length,
      activeCount: spawnedRecords.length,
      status: EncounterStatus.active,
      spawnedEnemyIds: List.unmodifiable(spawnedIds),
    );
    _encountersById[encounterId] = updated;
    _emit(EncounterSpawnedEvent(room.id, updated, spawnedRecords));
    _emit(EncounterUpdatedEvent(room.id, updated));
    return List.unmodifiable(spawnedRecords);
  }

  List<SpawnedEnemyRecord> _failEncounter(
    RoomEncounterState encounter,
    String reason,
  ) {
    final failed = encounter.copyWith(
      spawnedCount: 0,
      activeCount: 0,
      defeatedCount: 0,
      status: EncounterStatus.failed,
      lastError: reason,
    );
    _encountersById[encounter.encounterId] = failed;
    _emit(EncounterSpawnFailedEvent(encounter.roomId, failed, reason));
    _emit(EncounterUpdatedEvent(encounter.roomId, failed));
    return const [];
  }

  List<SpawnedEnemyRecord> _onGroupProgressed(
    String spawnGroup, {
    CombatSimulation? simulation,
    NavigationGrid? grid,
  }) {
    final room = _currentRoom;
    if (room == null) return const [];
    final groupEncounters = encountersInGroup(spawnGroup);
    if (groupEncounters.isEmpty ||
        !groupEncounters.every((e) => e.isCompleted) ||
        !_completedGroups.add(spawnGroup)) {
      return const [];
    }

    _emit(SpawnGroupCompletedEvent(room.id, spawnGroup));

    if (simulation == null || grid == null) return const [];

    final spawned = <SpawnedEnemyRecord>[];
    for (final encounterId in List<String>.of(_orderedEncounterIds)) {
      final config = _configsById[encounterId];
      if (config != null &&
          config.activationState == SpawnActivationState.onGroupCleared &&
          config.activationTriggerGroup == spawnGroup) {
        spawned.addAll(
          _activateSingleEncounter(
            encounterId,
            simulation: simulation,
            grid: grid,
          ),
        );
      }
    }
    return spawned;
  }

  void _checkRoomEncountersCompleted() {
    final room = _currentRoom;
    if (room == null || _roomEncountersCompletedEmitted) return;
    if (_areRoomCompletionTargetsDefeated(room)) {
      _roomEncountersCompletedEmitted = true;
      _emit(RoomEncountersCompletedEvent(room.id, encounters));
    }
  }

  bool _areRoomCompletionTargetsDefeated(RoomDefinition room) =>
      const RoomCompletionEvaluator().areCombatRequirementsSatisfied(
        room,
        encounters,
      );

  List<GridPoint> _resolveSpawnCells({
    required NavigationGrid grid,
    required GridPoint origin,
    required int quantity,
    required CombatSimulation simulation,
  }) {
    if (quantity == 1) return [origin];

    final occupied = <GridPoint>{
      simulation.player.follower.currentCell,
      for (final enemy in simulation.aliveEnemies) enemy.follower.currentCell,
    };

    final selected = <GridPoint>[origin];
    final batchUsed = <GridPoint>{origin};

    // Cari sel walkable terdekat secara deterministik (BFS 4-arah lalu 8-arah)
    // untuk unit tambahan agar tidak menumpuk bila ruang sekitar tersedia.
    final queue = Queue<GridPoint>()..add(origin);
    final visited = <GridPoint>{origin};
    const offsets = <GridPoint>[
      GridPoint(1, 0),
      GridPoint(-1, 0),
      GridPoint(0, 1),
      GridPoint(0, -1),
      GridPoint(1, 1),
      GridPoint(1, -1),
      GridPoint(-1, 1),
      GridPoint(-1, -1),
    ];

    while (selected.length < quantity && queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final delta in offsets) {
        final candidate = GridPoint(current.x + delta.x, current.y + delta.y);
        if (!grid.inBounds(candidate.x, candidate.y) ||
            !grid.isWalkable(candidate.x, candidate.y) ||
            !visited.add(candidate)) {
          continue;
        }
        queue.add(candidate);
        if (!occupied.contains(candidate) && !batchUsed.contains(candidate)) {
          selected.add(candidate);
          batchUsed.add(candidate);
          if (selected.length == quantity) break;
        }
      }
    }

    while (selected.length < quantity) {
      selected.add(origin);
    }
    return selected;
  }

  static String _encounterIdFor(String roomId, String spawnConfigId) =>
      '$roomId:$spawnConfigId';

  static EncounterType _resolveEncounterType(
    RoomSpawnConfig config,
    EnemyDefinition? definition,
  ) {
    if (config.isBoss || (definition?.isBoss ?? false)) {
      return EncounterType.boss;
    }
    if (config.isElite || (definition?.isElite ?? false)) {
      return EncounterType.elite;
    }
    return EncounterType.normal;
  }

  void _emit(EncounterEvent event) {
    for (final listener in List<EncounterEventListener>.of(_listeners)) {
      listener(event);
    }
  }
}
