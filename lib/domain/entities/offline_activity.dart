/// Mode aktivitas offline yang dipilih pemain (M6 Hybrid Offline Progression).
enum OfflineActivityMode {
  /// Default mode saat pemain belum memilih aktivitas offline.
  /// Tidak menjalankan simulasi dungeon maupun auto farming.
  pauseProgression,

  /// Mode A: Melanjutkan dungeon run aktif dari checkpoint room terakhir.
  continueDungeon,

  /// Mode B: Menjalankan auto farming berulang pada dungeon yang sudah
  /// terbuka dan pernah diselesaikan dari Town.
  autoFarming,
}

/// State machine siklus hidup aktivitas offline (M6 Stage 1).
enum OfflineActivityState {
  inactive,
  configured,
  pending,
  processing,
  completed,
  failed,
  interrupted,
}

/// Kebijakan lanjutan Auto Farming ketika satu run mengalami kekalahan.
enum OfflineFailurePolicy {
  /// Hentikan aktivitas Auto Farming segera setelah satu run kalah (defeated).
  /// Mencegah exploit death-farming room awal tanpa mampu menyelesaikan dungeon.
  stopOnDefeat,
}

/// Ringkasan hasil offline progression yang disimpan hingga dibaca/ditutup pemain.
class OfflineSummarySnapshot {
  const OfflineSummarySnapshot({
    required this.eventId,
    required this.mode,
    required this.finalState,
    required this.effectiveElapsedMs,
    this.cappedAtMaxDuration = false,
    this.runsAttempted = 0,
    this.runsCompleted = 0,
    this.runsFailed = 0,
    this.roomsCleared = 0,
    this.encountersCleared = 0,
    this.expGained = 0,
    this.goldGained = 0,
    this.levelsGained = 0,
    this.addedStacks = const {},
    this.overflowStacks = const {},
    this.addedEquipmentCount = 0,
    this.droppedEquipmentCount = 0,
    this.acknowledged = false,
    this.generatedAtMs = 0,
    this.cycleRank = 0,
    this.failureReason,
  });

  final String eventId;
  final OfflineActivityMode mode;
  final OfflineActivityState finalState;
  final int effectiveElapsedMs;
  final bool cappedAtMaxDuration;
  final int runsAttempted;
  final int runsCompleted;
  final int runsFailed;
  final int roomsCleared;
  final int encountersCleared;
  final int expGained;
  final int goldGained;
  final int levelsGained;
  final Map<String, int> addedStacks;
  final Map<String, int> overflowStacks;
  final int addedEquipmentCount;
  final int droppedEquipmentCount;
  final bool acknowledged;
  final int generatedAtMs;
  final int cycleRank;
  final String? failureReason;

  bool get hasRewards =>
      expGained > 0 ||
      goldGained > 0 ||
      addedStacks.isNotEmpty ||
      addedEquipmentCount > 0;

  OfflineSummarySnapshot markAcknowledged() => OfflineSummarySnapshot(
    eventId: eventId,
    mode: mode,
    finalState: finalState,
    effectiveElapsedMs: effectiveElapsedMs,
    cappedAtMaxDuration: cappedAtMaxDuration,
    runsAttempted: runsAttempted,
    runsCompleted: runsCompleted,
    runsFailed: runsFailed,
    roomsCleared: roomsCleared,
    encountersCleared: encountersCleared,
    expGained: expGained,
    goldGained: goldGained,
    levelsGained: levelsGained,
    addedStacks: addedStacks,
    overflowStacks: overflowStacks,
    addedEquipmentCount: addedEquipmentCount,
    droppedEquipmentCount: droppedEquipmentCount,
    acknowledged: true,
    generatedAtMs: generatedAtMs,
    cycleRank: cycleRank,
    failureReason: failureReason,
  );
}

/// Snapshot persistensi konfigurasi, state machine, dan checkpoint aktivitas
/// offline pada `GameSessions.sessionDataJson`.
class OfflineActivitySnapshot {
  const OfflineActivitySnapshot({
    this.mode = OfflineActivityMode.pauseProgression,
    this.state = OfflineActivityState.inactive,
    this.selectedDungeonId,
    this.activeRunId,
    this.lastCheckpointAtMs = 0,
    this.processedOfflineDurationMs = 0,
    this.simulationSeed,
    this.failurePolicy = OfflineFailurePolicy.stopOnDefeat,
    this.pendingSummary,
  });

  const OfflineActivitySnapshot.paused({
    this.lastCheckpointAtMs = 0,
    this.processedOfflineDurationMs = 0,
    this.pendingSummary,
  }) : mode = OfflineActivityMode.pauseProgression,
       state = OfflineActivityState.inactive,
       selectedDungeonId = null,
       activeRunId = null,
       simulationSeed = null,
       failurePolicy = OfflineFailurePolicy.stopOnDefeat;

  final OfflineActivityMode mode;
  final OfflineActivityState state;
  final String? selectedDungeonId;
  final String? activeRunId;
  final int lastCheckpointAtMs;
  final int processedOfflineDurationMs;
  final int? simulationSeed;
  final OfflineFailurePolicy failurePolicy;
  final OfflineSummarySnapshot? pendingSummary;

  bool get isPaused => mode == OfflineActivityMode.pauseProgression;

  /// Apakah aktivitas memenuhi syarat state machine untuk dipicu saat boot.
  bool get isRunnableOnResume =>
      !isPaused &&
      (state == OfflineActivityState.configured ||
          state == OfflineActivityState.interrupted ||
          state == OfflineActivityState.pending);

  /// Validasi transisi state machine aktivitas offline sesuai arsitektur M6.
  ///
  /// Aturan utama:
  /// - `completed` dan `failed` bersifat terminal untuk satu siklus dan hanya
  ///   boleh di-reset ke `inactive` (tidak pernah dijalankan ulang langsung).
  /// - `pauseProgression` hanya berada pada state `inactive`.
  static bool isValidTransition(
    OfflineActivityState from,
    OfflineActivityState to,
  ) {
    if (from == to) return false;
    switch (from) {
      case OfflineActivityState.inactive:
        return to == OfflineActivityState.configured;
      case OfflineActivityState.configured:
        return to == OfflineActivityState.inactive ||
            to == OfflineActivityState.pending;
      case OfflineActivityState.pending:
        return to == OfflineActivityState.processing ||
            to == OfflineActivityState.inactive ||
            to == OfflineActivityState.failed;
      case OfflineActivityState.processing:
        return to == OfflineActivityState.completed ||
            to == OfflineActivityState.failed ||
            to == OfflineActivityState.interrupted;
      case OfflineActivityState.interrupted:
        return to == OfflineActivityState.pending ||
            to == OfflineActivityState.configured ||
            to == OfflineActivityState.inactive;
      case OfflineActivityState.completed:
      case OfflineActivityState.failed:
        return to == OfflineActivityState.inactive;
    }
  }

  OfflineActivitySnapshot transitionTo(
    OfflineActivityState nextState, {
    OfflineActivityMode? mode,
    String? selectedDungeonId,
    bool clearSelectedDungeonId = false,
    String? activeRunId,
    bool clearActiveRunId = false,
    int? lastCheckpointAtMs,
    int? processedOfflineDurationMs,
    int? simulationSeed,
    bool clearSimulationSeed = false,
    OfflineSummarySnapshot? pendingSummary,
    bool clearPendingSummary = false,
  }) {
    if (!isValidTransition(state, nextState)) {
      throw StateError(
        'Transisi OfflineActivityState tidak valid: '
        '${state.name} -> ${nextState.name}.',
      );
    }

    final resolvedMode = nextState == OfflineActivityState.inactive
        ? (mode ?? OfflineActivityMode.pauseProgression)
        : (mode ?? this.mode);
    if (resolvedMode == OfflineActivityMode.pauseProgression &&
        nextState != OfflineActivityState.inactive) {
      throw StateError(
        'Pause Progression hanya boleh berada pada state inactive '
        '(diterima: ${nextState.name}).',
      );
    }

    final resolvedDungeonId = clearSelectedDungeonId
        ? null
        : (selectedDungeonId ?? this.selectedDungeonId);
    final resolvedRunId = clearActiveRunId
        ? null
        : (activeRunId ?? this.activeRunId);

    if (nextState == OfflineActivityState.configured ||
        nextState == OfflineActivityState.pending ||
        nextState == OfflineActivityState.processing) {
      if (resolvedMode == OfflineActivityMode.continueDungeon &&
          (resolvedRunId == null || resolvedRunId.trim().isEmpty)) {
        throw StateError(
          'Mode Continue Dungeon wajib memiliki activeRunId yang valid.',
        );
      }
      if (resolvedMode == OfflineActivityMode.autoFarming &&
          (resolvedDungeonId == null || resolvedDungeonId.trim().isEmpty)) {
        throw StateError(
          'Mode Auto Farming wajib memiliki selectedDungeonId yang valid.',
        );
      }
    }

    return OfflineActivitySnapshot(
      mode: resolvedMode,
      state: nextState,
      selectedDungeonId: resolvedDungeonId,
      activeRunId: resolvedRunId,
      lastCheckpointAtMs: lastCheckpointAtMs ?? this.lastCheckpointAtMs,
      processedOfflineDurationMs:
          processedOfflineDurationMs ?? this.processedOfflineDurationMs,
      simulationSeed: clearSimulationSeed
          ? null
          : (simulationSeed ?? this.simulationSeed),
      failurePolicy: failurePolicy,
      pendingSummary: clearPendingSummary
          ? null
          : (pendingSummary ?? this.pendingSummary),
    );
  }

  /// Mengubah aktivitas offline secara aman ke default [OfflineActivityMode.pauseProgression].
  OfflineActivitySnapshot withPauseProgression() {
    if (isPaused &&
        state == OfflineActivityState.inactive &&
        selectedDungeonId == null &&
        activeRunId == null &&
        simulationSeed == null &&
        processedOfflineDurationMs == 0) {
      return this;
    }
    if (state == OfflineActivityState.inactive) {
      return OfflineActivitySnapshot.paused(
        lastCheckpointAtMs: lastCheckpointAtMs,
        processedOfflineDurationMs: 0,
        pendingSummary: pendingSummary,
      );
    }
    return transitionTo(
      OfflineActivityState.inactive,
      mode: OfflineActivityMode.pauseProgression,
      clearSelectedDungeonId: true,
      clearActiveRunId: true,
      clearSimulationSeed: true,
      processedOfflineDurationMs: 0,
    );
  }

  /// Mengonfigurasi Mode A ([OfflineActivityMode.continueDungeon]) untuk run aktif.
  OfflineActivitySnapshot withContinueDungeon({
    required String dungeonId,
    required String activeRunId,
    int? checkpointAtMs,
    int? simulationSeed,
  }) {
    if (dungeonId.trim().isEmpty) {
      throw ArgumentError.value(dungeonId, 'dungeonId', 'tidak boleh kosong');
    }
    if (activeRunId.trim().isEmpty) {
      throw ArgumentError.value(
        activeRunId,
        'activeRunId',
        'tidak boleh kosong',
      );
    }
    final safeCheckpoint = (checkpointAtMs ?? lastCheckpointAtMs) < 0
        ? 0
        : (checkpointAtMs ?? lastCheckpointAtMs);
    final base = state == OfflineActivityState.inactive
        ? this
        : withPauseProgression();
    return base.transitionTo(
      OfflineActivityState.configured,
      mode: OfflineActivityMode.continueDungeon,
      selectedDungeonId: dungeonId,
      activeRunId: activeRunId,
      lastCheckpointAtMs: safeCheckpoint,
      processedOfflineDurationMs: 0,
      simulationSeed: simulationSeed,
      clearSimulationSeed: simulationSeed == null,
      clearPendingSummary: true,
    );
  }

  /// Mengonfigurasi Mode B ([OfflineActivityMode.autoFarming]) dari Town.
  OfflineActivitySnapshot withAutoFarming({
    required String dungeonId,
    int? checkpointAtMs,
    int? simulationSeed,
  }) {
    if (dungeonId.trim().isEmpty) {
      throw ArgumentError.value(dungeonId, 'dungeonId', 'tidak boleh kosong');
    }
    final safeCheckpoint = (checkpointAtMs ?? lastCheckpointAtMs) < 0
        ? 0
        : (checkpointAtMs ?? lastCheckpointAtMs);
    final base = state == OfflineActivityState.inactive
        ? this
        : withPauseProgression();
    return base.transitionTo(
      OfflineActivityState.configured,
      mode: OfflineActivityMode.autoFarming,
      selectedDungeonId: dungeonId,
      clearActiveRunId: true,
      lastCheckpointAtMs: safeCheckpoint,
      processedOfflineDurationMs: 0,
      simulationSeed: simulationSeed,
      clearSimulationSeed: simulationSeed == null,
      clearPendingSummary: true,
    );
  }

  /// Menandai [pendingSummary] telah dibaca pemain dan mereset state terminal
  /// (`completed` / `failed`) kembali ke [OfflineActivityMode.pauseProgression].
  OfflineActivitySnapshot acknowledgePendingSummary() {
    final summary = pendingSummary;
    final ackedSummary = summary?.markAcknowledged();

    if (state == OfflineActivityState.completed ||
        state == OfflineActivityState.failed) {
      return transitionTo(
        OfflineActivityState.inactive,
        mode: OfflineActivityMode.pauseProgression,
        clearSelectedDungeonId: true,
        clearActiveRunId: true,
        clearSimulationSeed: true,
        processedOfflineDurationMs: 0,
        pendingSummary: ackedSummary,
      );
    }

    if (summary == null || summary.acknowledged) {
      return this;
    }

    return OfflineActivitySnapshot(
      mode: mode,
      state: state,
      selectedDungeonId: selectedDungeonId,
      activeRunId: activeRunId,
      lastCheckpointAtMs: lastCheckpointAtMs,
      processedOfflineDurationMs: processedOfflineDurationMs,
      simulationSeed: simulationSeed,
      failurePolicy: failurePolicy,
      pendingSummary: ackedSummary,
    );
  }
}
