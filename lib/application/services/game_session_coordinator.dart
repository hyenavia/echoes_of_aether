import 'dart:async';
import 'dart:math' as math;

import '../../domain/entities/boss_event.dart';
import '../../domain/entities/boss_spire.dart';
import '../../domain/entities/clock_state.dart';
import '../../domain/entities/cycle_progress.dart';
import '../../domain/entities/dungeon_definition.dart';
import '../../domain/entities/enemy_definition.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/event_shop_purchase.dart';
import '../../domain/entities/gacha_config.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/offline_activity.dart';
import '../../domain/entities/periodic_quest_state.dart';
import '../../domain/entities/currency_config.dart';
import '../../domain/entities/player_character.dart';
import '../../domain/entities/player_save_snapshot.dart';
import '../../domain/entities/player_status.dart';
import '../../domain/repositories/game_settings_repository.dart';
import '../../domain/repositories/player_progress_repository.dart';
import '../../domain/services/altar_service.dart';
import '../../domain/services/bag_expansion_service.dart';
import '../../domain/services/boss_event_service.dart';
import '../../domain/services/boss_quest_service.dart';
import '../../domain/services/boss_spire_service.dart';
import '../../domain/services/clock_guard.dart';
import '../../domain/services/combat_simulation.dart';
import '../../domain/services/currency_service.dart';
import '../../domain/services/derived_stats_calculator.dart';
import '../../domain/services/difficulty_service.dart';
import '../../domain/services/dungeon_manager.dart';
import '../../domain/services/equipment_factory.dart';
import '../../domain/services/game_clock.dart';
import '../../domain/services/offline_equipment_cleanup_service.dart';
import '../../domain/services/offline_progression_service.dart';
import '../../domain/services/period_service.dart';
import '../../domain/services/reward_processor.dart';

class LoadedGameSession {
  const LoadedGameSession({
    required this.character,
    required this.inventory,
    required this.dungeon,
    this.dungeonProgresses = const {},
    this.cycleProgress = const CycleProgress(),
    required this.session,
    required this.claimedEventIds,
    required this.offlineResult,
    required this.rewardProcessor,
    this.activeDungeonSession,
    this.offlineActivity = const OfflineActivitySnapshot.paused(),
    this.recoveredHp,
    this.recoveredSkillCooldownTicks = const {},
    this.isFirstLaunch = false,
    this.loadError,
    this.shopPurchases = const {},
    this.eventShopPurchases = const [],
    this.currencies = const {},
    this.clockState = const ClockState(),
    this.periodicQuestStates = const [],
    this.gachaPityStates = const {},
    this.unlockedSpecializations = const {},
  });

  final PlayerCharacter character;
  final Inventory inventory;
  final DungeonProgressSnapshot dungeon;
  final Map<String, DungeonProgressSnapshot> dungeonProgresses;
  final CycleProgress cycleProgress;
  final GameSessionSnapshot session;
  final Set<String> claimedEventIds;
  final OfflineProgressionResult offlineResult;
  final RewardProcessor rewardProcessor;
  final ActiveDungeonSessionSnapshot? activeDungeonSession;
  final OfflineActivitySnapshot offlineActivity;
  final int? recoveredHp;
  final Map<String, int> recoveredSkillCooldownTicks;
  final bool isFirstLaunch;
  final Object? loadError;
  final Map<String, int> shopPurchases;
  final List<EventShopPurchaseRecord> eventShopPurchases;
  final Map<String, int> currencies;
  final ClockState clockState;
  final List<PeriodicQuestState> periodicQuestStates;
  final Map<String, GachaPityState> gachaPityStates;
  final Set<String> unlockedSpecializations;

  bool get hasRecoverableDungeonSession =>
      activeDungeonSession?.isRecoverable ?? false;

  bool get hasUnacknowledgedOfflineSummary =>
      offlineActivity.pendingSummary != null &&
      !offlineActivity.pendingSummary!.acknowledged;
}

/// Mengoordinasikan siklus load, Hybrid Offline Progression (checkpointed
/// batch atomic transactions), lifecycle resume, dan antrean penyimpanan
/// berurutan agar operasi save maupun trigger resume tidak saling menimpa.
class GameSessionCoordinator {
  GameSessionCoordinator({
    required this.repository,
    required this.config,
    this.offlineService = const OfflineProgressionService(),
    this.checkpointIterationsPerBatch = defaultCheckpointIterationsPerBatch,
    GameClock? clock,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? (() => (clock ?? const SystemGameClock()).nowMs),
       _clockGuard = ClockGuard(timeConfig: config.time);

  static const int defaultCheckpointIterationsPerBatch = 2500;
  static const int _maxCheckpointBatches = 256;

  final PlayerSaveRepository repository;
  final GameConfig config;
  final OfflineProgressionService offlineService;
  final int checkpointIterationsPerBatch;
  final int Function() _nowMs;
  final ClockGuard _clockGuard;

  Future<void> _saveQueue = Future<void>.value();
  Future<void> _offlineQueue = Future<void>.value();
  int _highWaterTimestampMs = 0;
  ClockState _clockState = const ClockState();
  int? _serverOffsetMs;
  bool _isServerClockOnline = false;
  Object? lastSaveError;

  ClockState get clockState => _clockState;

  int? get serverOffsetMs => _serverOffsetMs;

  bool get isUsingServerClock => ClockGuard.shouldUseServerTime(
    serverOffsetMs: _serverOffsetMs,
    isOnline: _isServerClockOnline,
    serverTimeToleranceMs: config.cloud.serverTimeToleranceMs,
  );

  /// Memperbarui offset jam server hasil kalibrasi `clock/ping` saat online
  /// (atau menandai mode offline agar jam perangkat dipakai dengan `ClockGuard`).
  void updateServerClock({int? serverOffsetMs, required bool isOnline}) {
    _isServerClockOnline = isOnline;
    if (serverOffsetMs != null) {
      _serverOffsetMs = serverOffsetMs;
    }
  }

  ClockReading _resolveClock({
    required ClockState current,
    required int rawNowMs,
  }) => _clockGuard.resolve(
    current: current,
    rawNowMs: rawNowMs,
    serverOffsetMs: _serverOffsetMs,
    isOnline: _isServerClockOnline,
    serverTimeToleranceMs: config.cloud.serverTimeToleranceMs,
  );

  /// Waktu efektif saat ini yang dijaga [ClockGuard] (memakai waktu server
  /// saat online dengan selisih melebihi toleransi, atau jam perangkat dengan
  /// proteksi mundur `lastSeenAtMs`) tanpa memutasi `_clockState`.
  int get effectiveClockMs => _resolveClock(
    current: _clockState,
    rawNowMs: math.max(0, _nowMs()),
  ).effectiveMs;

  /// Menjalankan boot load, memproses aktivitas offline secara eksklusif,
  /// lalu memangkas `ClaimedRewards` yang sudah kedaluwarsa secara aman.
  Future<LoadedGameSession> loadAndProcessOffline({int? maxBatches}) =>
      _runOfflineExclusive(() async {
        final session = await _processFromRepository(maxBatches: maxBatches);
        await _pruneExpiredClaimsIfSupported(session);
        return session;
      });

  /// Memproses aktivitas offline saat `AppLifecycleState.resumed`.
  /// Menunggu seluruh antrean save sebelum membaca snapshot agar pause save
  /// tidak tertinggal atau berpacu dengan pemrosesan resume ganda.
  Future<LoadedGameSession> processOfflineOnResume({int? maxBatches}) =>
      _runOfflineExclusive(
        () => _processFromRepository(maxBatches: maxBatches),
      );

  /// Menyimpan [cycleProgress] secara berurutan melalui `_saveQueue` tanpa
  /// menimpa data karakter, equipment, maupun inventory.
  Future<void> saveCycleProgress(CycleProgress cycleProgress) {
    return _runQueuedSave(() async {
      final repo = repository;
      if (repo is CycleProgressRepository) {
        await (repo as CycleProgressRepository).saveCycleProgress(
          cycleProgress,
        );
        return;
      }
      final existing = await repo.loadSnapshot();
      if (existing == null) return;
      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          playerId: existing.playerId,
          character: existing.character,
          inventory: existing.inventory,
          dungeon: existing.dungeon,
          dungeonProgresses: existing.dungeonProgresses,
          cycleProgress: cycleProgress,
          session: existing.session,
          claimedEventIds: existing.claimedEventIds,
          activeDungeonSession: existing.activeDungeonSession,
          offlineActivity: existing.offlineActivity,
          shopPurchases: existing.shopPurchases,
          eventShopPurchases: existing.eventShopPurchases,
          currencies: existing.currencies,
          clockState: existing.clockState,
        ),
      );
    });
  }

  /// Menyimpan transisi siklus Ascension (`cycleProgress`, reset
  /// `clearedInCycleRank`, serta kunci idempoten `ascension:{runId}`) secara
  /// atomik dan terurut melalui `_saveQueue`.
  Future<void> saveCycleTransition({
    required CycleProgress cycleProgress,
    required Map<String, DungeonProgressSnapshot> dungeonProgresses,
    String? claimEventId,
    int? updatedAtMs,
  }) {
    return _runQueuedSave(() async {
      final repo = repository;
      final resolvedAtMs = math.max(0, updatedAtMs ?? _nowMs());
      if (repo is CycleProgressRepository) {
        await (repo as CycleProgressRepository).saveCycleTransition(
          cycleProgress: cycleProgress,
          dungeonProgresses: dungeonProgresses,
          claimEventId: claimEventId,
          updatedAtMs: resolvedAtMs,
        );
        return;
      }
      final existing = await repo.loadSnapshot();
      if (existing == null) return;
      final nextClaimed = <String>{
        ...existing.claimedEventIds,
        if (claimEventId != null && claimEventId.trim().isNotEmpty)
          claimEventId.trim(),
      };
      final nextProgresses = Map<String, DungeonProgressSnapshot>.unmodifiable(
        dungeonProgresses,
      );
      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          playerId: existing.playerId,
          character: existing.character,
          inventory: existing.inventory,
          dungeon:
              nextProgresses[existing.dungeon.currentDungeonId] ??
              existing.dungeon,
          dungeonProgresses: nextProgresses,
          cycleProgress: cycleProgress,
          session: existing.session,
          claimedEventIds: Set<String>.unmodifiable(nextClaimed),
          activeDungeonSession: existing.activeDungeonSession,
          offlineActivity: existing.offlineActivity,
          shopPurchases: existing.shopPurchases,
          eventShopPurchases: existing.eventShopPurchases,
          currencies: existing.currencies,
          clockState: existing.clockState,
        ),
      );
    });
  }

  /// Menyimpan transaksi shop (perubahan gold, inventory, equipment, dan
  /// [shopPurchases]) secara atomik dan terurut melalui `_saveQueue`.
  Future<void> saveShopTransaction({
    required PlayerCharacter character,
    required Inventory inventory,
    required Map<String, int> shopPurchases,
    String? actionId,
    int? updatedAtMs,
  }) {
    return _runQueuedSave(() async {
      final repo = repository;
      final resolvedAtMs = math.max(0, updatedAtMs ?? _nowMs());
      final charSnap = character.toSnapshot();
      final invSnap = inventory.toSnapshot();
      if (repo is ShopPurchaseRepository) {
        await (repo as ShopPurchaseRepository).saveShopTransaction(
          progress: charSnap.progress,
          inventory: invSnap,
          equipped: charSnap.equipped,
          shopPurchases: shopPurchases,
          actionId: actionId,
          updatedAtMs: resolvedAtMs,
        );
        return;
      }
      final existing = await repo.loadSnapshot();
      if (existing == null) return;
      final normalizedActionId = actionId?.trim();
      final claimKey =
          (normalizedActionId != null && normalizedActionId.isNotEmpty)
          ? 'shop:$normalizedActionId'
          : null;
      if (claimKey != null && existing.claimedEventIds.contains(claimKey)) {
        return;
      }
      final nextClaimed = <String>{...existing.claimedEventIds, ?claimKey};
      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          playerId: existing.playerId,
          character: PlayerCharacterSnapshot(
            progress: charSnap.progress,
            specializationId: charSnap.specializationId,
            skillLevels: charSnap.skillLevels,
            skillCooldownTicks: charSnap.skillCooldownTicks,
            equipped: charSnap.equipped,
            currentHp: existing.character.currentHp,
          ),
          inventory: invSnap,
          dungeon: existing.dungeon,
          dungeonProgresses: existing.dungeonProgresses,
          cycleProgress: existing.cycleProgress,
          session: existing.session,
          claimedEventIds: Set<String>.unmodifiable(nextClaimed),
          activeDungeonSession: existing.activeDungeonSession,
          offlineActivity: existing.offlineActivity,
          shopPurchases: Map<String, int>.unmodifiable(shopPurchases),
          eventShopPurchases: existing.eventShopPurchases,
          currencies: existing.currencies,
          clockState: existing.clockState,
        ),
      );
    });
  }

  /// Menyimpan transaksi Event Shop (perubahan shard, inventory/equipment, dan
  /// [EventShopPurchases] untuk periode mingguan) secara atomik melalui `_saveQueue`.
  Future<void> saveEventShopTransaction({
    required PlayerCharacter character,
    required Inventory inventory,
    required CurrencyService currencyService,
    required EventShopPurchaseRecord purchase,
    String? actionId,
    int? updatedAtMs,
  }) {
    return _runQueuedSave(() async {
      final repo = repository;
      final resolvedAtMs = math.max(0, updatedAtMs ?? _nowMs());
      final charSnap = character.toSnapshot();
      final invSnap = inventory.toSnapshot();
      final currencySnapshot = currencyService.toSnapshot();
      if (repo is EventShopPurchaseRepository) {
        await (repo as EventShopPurchaseRepository).saveEventShopTransaction(
          progress: charSnap.progress,
          inventory: invSnap,
          equipped: charSnap.equipped,
          currencies: currencySnapshot,
          purchase: purchase,
          actionId: actionId,
          updatedAtMs: resolvedAtMs,
        );
        return;
      }
      final existing = await repo.loadSnapshot();
      if (existing == null) return;
      final normalizedActionId = actionId?.trim();
      final claimKey =
          (normalizedActionId != null && normalizedActionId.isNotEmpty)
          ? 'eventshop:$normalizedActionId:${purchase.periodKey}'
          : null;
      if (claimKey != null && existing.claimedEventIds.contains(claimKey)) {
        return;
      }
      final nextClaimed = <String>{...existing.claimedEventIds, ?claimKey};
      final mergedPurchases = <EventShopPurchaseRecord>[
        for (final p in existing.eventShopPurchases)
          if (!(p.entryId == purchase.entryId &&
              p.periodKey == purchase.periodKey))
            p,
        purchase,
      ];
      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          playerId: existing.playerId,
          character: PlayerCharacterSnapshot(
            progress: charSnap.progress,
            specializationId: charSnap.specializationId,
            skillLevels: charSnap.skillLevels,
            skillCooldownTicks: charSnap.skillCooldownTicks,
            equipped: charSnap.equipped,
            currentHp: existing.character.currentHp,
          ),
          inventory: invSnap,
          dungeon: existing.dungeon,
          dungeonProgresses: existing.dungeonProgresses,
          cycleProgress: existing.cycleProgress,
          session: existing.session,
          claimedEventIds: Set<String>.unmodifiable(nextClaimed),
          activeDungeonSession: existing.activeDungeonSession,
          offlineActivity: existing.offlineActivity,
          shopPurchases: existing.shopPurchases,
          eventShopPurchases: List<EventShopPurchaseRecord>.unmodifiable(
            mergedPurchases,
          ),
          currencies: currencySnapshot,
          clockState: existing.clockState,
          periodicQuestStates: existing.periodicQuestStates,
          gachaPityStates: existing.gachaPityStates,
          unlockedSpecializations: existing.unlockedSpecializations,
        ),
      );
    });
  }

  Future<T> _runQueuedSave<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        final value = await action();
        if (!completer.isCompleted) completer.complete(value);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<T> _runOfflineExclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _offlineQueue = _offlineQueue.then((_) async {
      try {
        await _saveQueue.catchError((_) {});
        final value = await action();
        if (!completer.isCompleted) completer.complete(value);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<LoadedGameSession> _processFromRepository({int? maxBatches}) async {
    final character = PlayerCharacter(
      config: config.progression,
      skillCatalog: config.skills,
      specializationConfig: config.specializations,
      itemCatalog: config.items,
      statsCalculator: DerivedStatsCalculator(
        pctCaps: config.equipment.pctCaps,
      ),
    );
    final inventory = Inventory(definitions: config.items);

    PlayerSaveSnapshot? loaded;
    Object? loadError;
    try {
      loaded = await repository.loadSnapshot();
    } catch (e) {
      loadError = e;
    }

    final now = math.max(0, _nowMs());
    if (loaded == null) {
      inventory.maxEquipmentCapacity = const BagExpansionService()
          .calculateCapacity(0);
      final firstClock = _resolveClock(current: _clockState, rawNowMs: now);
      _clockState = firstClock.state;
      final firstEffectiveNow = firstClock.effectiveMs;
      _highWaterTimestampMs = math.max(
        _highWaterTimestampMs,
        firstEffectiveNow,
      );
      final initialSession = GameSessionSnapshot(
        lastActiveAtMs: firstEffectiveNow,
        lastSavedAtMs: firstEffectiveNow,
        lastOfflineClaimAtMs: firstEffectiveNow,
        autoSkillEnabled: true,
      );
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      final offlineResult = OfflineProgressionResult.none(
        status: OfflineProgressionStatus.firstLaunch,
        claimAtMs: firstEffectiveNow,
      );
      final sortedNormals =
          config.dungeons.values.where((d) => d.isNormal).toList()
            ..sort((a, b) => a.order.compareTo(b.order));
      final firstNormal = sortedNormals.isNotEmpty
          ? sortedNormals.first
          : (config.dungeons.values.isNotEmpty
                ? config.dungeons.values.first
                : null);
      final initialDungeon = firstNormal != null
          ? DungeonProgressSnapshot(
              currentDungeonId: firstNormal.id,
              currentRoomId: firstNormal.startRoomId,
            )
          : const DungeonProgressSnapshot();
      final initialCycle = CycleProgress(lastNormalDungeonId: firstNormal?.id);
      return LoadedGameSession(
        character: character,
        inventory: inventory,
        dungeon: initialDungeon,
        dungeonProgresses: const {},
        cycleProgress: initialCycle,
        session: initialSession,
        claimedEventIds: <String>{},
        offlineResult: offlineResult,
        rewardProcessor: rewardProcessor,
        offlineActivity: const OfflineActivitySnapshot.paused(),
        isFirstLaunch: loadError == null,
        loadError: loadError,
        clockState: _clockState,
      );
    }

    final clockReading = _resolveClock(
      current: loaded.clockState,
      rawNowMs: now,
    );
    _clockState = clockReading.state;
    // Saat online dengan selisih jam server melampaui toleransi, offline
    // progression dihitung terhadap waktu server (`raw + offset`). Saat
    // offline, `raw` tetap diteruskan agar deteksi `invalidClock` terjaga.
    final effectiveNow = isUsingServerClock
        ? math.max(0, now + _serverOffsetMs!)
        : now;

    character.restoreSnapshot(loaded.character);
    inventory.restore(loaded.inventory);
    final bagLevel = loaded.currencies[kBagExpansionCurrencyId] ?? 0;
    inventory.maxEquipmentCapacity = const BagExpansionService()
        .calculateCapacity(bagLevel);
    const altarService = AltarService();
    character.updateAltarBonus(
      altarService.getAltarStatBonus(loaded.currencies),
    );
    final goldMultiplier =
        1.0 + altarService.getGoldBonusPercent(loaded.currencies);
    final claimedIds = {...loaded.claimedEventIds};
    final rewardProcessor = RewardProcessor(
      character: character,
      inventory: inventory,
      items: config.items,
      lootTables: config.lootTables,
      lootService: offlineService.lootService,
      equipmentFactory: EquipmentFactory(config.equipment),
      claimedEventIds: claimedIds,
      goldMultiplier: goldMultiplier,
    );

    final previousHighWater = math.max(
      loaded.session.lastSavedAtMs,
      loaded.session.lastOfflineClaimAtMs,
    );
    _highWaterTimestampMs = math.max(_highWaterTimestampMs, previousHighWater);

    final normalizedRecovery = _normalizeRecoveredSession(
      loaded: loaded,
      character: character,
    );

    var workingSession = loaded.session;
    var workingActivity = loaded.offlineActivity;
    var workingActiveSession = normalizedRecovery.activeSession;
    var workingDungeon = loaded.dungeon;
    final workingCycle = loaded.cycleProgress;
    final workingProgresses = Map<String, DungeonProgressSnapshot>.of(
      loaded.dungeonProgresses,
    );
    workingProgresses.putIfAbsent(
      workingDungeon.currentDungeonId,
      () => workingDungeon,
    );

    var simHp = workingActiveSession?.isRecoverable == true
        ? (normalizedRecovery.recoveredHp ?? loaded.character.currentHp)
        : null;
    var simSkillCooldowns = workingActiveSession?.isRecoverable == true
        ? Map<String, int>.of(loaded.character.skillCooldownTicks)
        : const <String, int>{};
    var simReviveTicks = workingActiveSession?.reviveCooldownTicks ?? 0;
    var attemptIndex = 1;

    final batchLimit = maxBatches == null
        ? _maxCheckpointBatches
        : math.max(1, maxBatches);
    final iterationsPerBatch = math.max(1, checkpointIterationsPerBatch);

    var firstResult = offlineService.process(
      character: character,
      inventory: inventory,
      config: config,
      session: workingSession,
      nowMs: effectiveNow,
      offlineActivity: workingActivity,
      activeDungeonSession: workingActiveSession,
      dungeonProgress: workingDungeon,
      dungeonProgresses: workingProgresses,
      cycleProgress: workingCycle,
      rewardProcessor: rewardProcessor,
      claimedEventIds: claimedIds,
      maxIterations: iterationsPerBatch,
      initialHp: simHp,
      initialSkillCooldownTicks: simSkillCooldowns,
      initialReviveCooldownTicks: simReviveTicks,
      startingAttemptIndex: attemptIndex,
    );

    var aggregatedResult = firstResult;
    var batchCount = 0;

    if (firstResult.status == OfflineProgressionStatus.applied ||
        firstResult.status == OfflineProgressionStatus.interrupted ||
        firstResult.status == OfflineProgressionStatus.failed ||
        firstResult.status == OfflineProgressionStatus.noEligibleEncounter) {
      var currentBatch = firstResult;

      while (true) {
        batchCount++;
        workingActivity =
            currentBatch.updatedOfflineActivity ?? workingActivity;
        workingActiveSession = currentBatch.updatedActiveDungeonSession;
        if (currentBatch.updatedDungeonProgress != null) {
          final updatedProg = currentBatch.updatedDungeonProgress!;
          workingProgresses[updatedProg.currentDungeonId] = updatedProg;
          if (workingDungeon.currentDungeonId == updatedProg.currentDungeonId) {
            workingDungeon = updatedProg;
          }
        }
        simHp = currentBatch.remainingHp;
        simSkillCooldowns = currentBatch.remainingSkillCooldownTicks;
        simReviveTicks = currentBatch.remainingReviveCooldownTicks;
        attemptIndex = currentBatch.nextAttemptIndex;
        claimedIds.addAll(rewardProcessor.claimedEventIds);

        final isBatchInterrupted =
            currentBatch.status == OfflineProgressionStatus.interrupted;

        final batchCheckpointMs = isBatchInterrupted
            ? math.max(previousHighWater, workingActivity.lastCheckpointAtMs)
            : math.max(effectiveNow, previousHighWater);

        final batchClaimAtMs = isBatchInterrupted
            ? math.max(
                workingSession.lastOfflineClaimAtMs,
                currentBatch.newLastOfflineClaimAtMs,
              )
            : math.max(
                workingSession.lastOfflineClaimAtMs,
                currentBatch.newLastOfflineClaimAtMs,
              );

        workingSession = loaded.session.copyWith(
          lastActiveAtMs: isBatchInterrupted
              ? batchCheckpointMs
              : math.max(effectiveNow, loaded.session.lastActiveAtMs),
          lastSavedAtMs: batchCheckpointMs,
          lastOfflineClaimAtMs: batchClaimAtMs,
        );

        final baseCharSnap = character.toSnapshot();
        final isRecoverable = workingActiveSession?.isRecoverable == true;
        final checkpointCharSnap = PlayerCharacterSnapshot(
          progress: baseCharSnap.progress,
          specializationId: baseCharSnap.specializationId,
          skillLevels: baseCharSnap.skillLevels,
          skillCooldownTicks: isRecoverable ? simSkillCooldowns : const {},
          equipped: baseCharSnap.equipped,
          currentHp: isRecoverable ? simHp : null,
        );

        await saveSnapshot(
          PlayerSaveSnapshot(
            playerId: loaded.playerId,
            character: checkpointCharSnap,
            inventory: inventory.toSnapshot(),
            dungeon: workingDungeon,
            dungeonProgresses: Map.unmodifiable(workingProgresses),
            cycleProgress: workingCycle,
            session: workingSession,
            claimedEventIds: claimedIds,
            activeDungeonSession: workingActiveSession,
            offlineActivity: workingActivity,
            shopPurchases: loaded.shopPurchases,
            eventShopPurchases: loaded.eventShopPurchases,
            currencies: loaded.currencies,
            clockState: _clockState,
          ),
        );

        if (!isBatchInterrupted || batchCount >= batchLimit) {
          break;
        }

        currentBatch = offlineService.process(
          character: character,
          inventory: inventory,
          config: config,
          session: workingSession,
          nowMs: now,
          offlineActivity: workingActivity,
          activeDungeonSession: workingActiveSession,
          dungeonProgress: workingDungeon,
          dungeonProgresses: workingProgresses,
          cycleProgress: workingCycle,
          rewardProcessor: rewardProcessor,
          claimedEventIds: claimedIds,
          maxIterations: iterationsPerBatch,
          initialHp: simHp,
          initialSkillCooldownTicks: simSkillCooldowns,
          initialReviveCooldownTicks: simReviveTicks,
          startingAttemptIndex: attemptIndex,
        );

        if (currentBatch.status != OfflineProgressionStatus.applied &&
            currentBatch.status != OfflineProgressionStatus.interrupted &&
            currentBatch.status != OfflineProgressionStatus.failed) {
          break;
        }
        aggregatedResult = _mergeResults(aggregatedResult, currentBatch);
      }

      if (repository is GameSettingsRepository) {
        final settings = await (repository as GameSettingsRepository)
            .loadSettings();
        if (settings.autoSalvageOfflineEquipment) {
          final cleanup = const OfflineEquipmentCleanupService()
              .cleanupAfterOffline(
                inventory: inventory,
                loadout: character.loadout,
                config: config,
              );
          if (cleanup.salvagedCount > 0) {
            final prevSummary = workingActivity.pendingSummary;
            if (prevSummary != null) {
              workingActivity = OfflineActivitySnapshot(
                mode: workingActivity.mode,
                state: workingActivity.state,
                selectedDungeonId: workingActivity.selectedDungeonId,
                activeRunId: workingActivity.activeRunId,
                lastCheckpointAtMs: workingActivity.lastCheckpointAtMs,
                processedOfflineDurationMs:
                    workingActivity.processedOfflineDurationMs,
                simulationSeed: workingActivity.simulationSeed,
                failurePolicy: workingActivity.failurePolicy,
                pendingSummary: OfflineSummarySnapshot(
                  eventId: prevSummary.eventId,
                  mode: prevSummary.mode,
                  finalState: prevSummary.finalState,
                  effectiveElapsedMs: prevSummary.effectiveElapsedMs,
                  cappedAtMaxDuration: prevSummary.cappedAtMaxDuration,
                  runsAttempted: prevSummary.runsAttempted,
                  runsCompleted: prevSummary.runsCompleted,
                  runsFailed: prevSummary.runsFailed,
                  roomsCleared: prevSummary.roomsCleared,
                  encountersCleared: prevSummary.encountersCleared,
                  expGained: prevSummary.expGained,
                  goldGained: prevSummary.goldGained,
                  levelsGained: prevSummary.levelsGained,
                  addedStacks: prevSummary.addedStacks,
                  overflowStacks: prevSummary.overflowStacks,
                  addedEquipmentCount: math.max(
                    0,
                    prevSummary.addedEquipmentCount - cleanup.salvagedCount,
                  ),
                  droppedEquipmentCount: prevSummary.droppedEquipmentCount,
                  autoSoldEquipmentCount: prevSummary.autoSoldEquipmentCount,
                  autoSoldEquipmentGold: prevSummary.autoSoldEquipmentGold,
                  autoSalvagedEquipmentCount:
                      prevSummary.autoSalvagedEquipmentCount +
                      cleanup.salvagedCount,
                  autoSalvagedScrapCount:
                      prevSummary.autoSalvagedScrapCount + cleanup.scrapGained,
                  acknowledged: prevSummary.acknowledged,
                  generatedAtMs: prevSummary.generatedAtMs,
                  cycleRank: prevSummary.cycleRank,
                  failureReason: prevSummary.failureReason,
                ),
              );
            }
            final baseCharSnap = character.toSnapshot();
            final isRecoverable = workingActiveSession?.isRecoverable == true;
            await saveSnapshot(
              PlayerSaveSnapshot(
                playerId: loaded.playerId,
                character: PlayerCharacterSnapshot(
                  progress: baseCharSnap.progress,
                  specializationId: baseCharSnap.specializationId,
                  skillLevels: baseCharSnap.skillLevels,
                  skillCooldownTicks: isRecoverable
                      ? simSkillCooldowns
                      : const {},
                  equipped: baseCharSnap.equipped,
                  currentHp: isRecoverable ? simHp : null,
                ),
                inventory: inventory.toSnapshot(),
                dungeon: workingDungeon,
                dungeonProgresses: Map.unmodifiable(workingProgresses),
                cycleProgress: workingCycle,
                session: workingSession,
                claimedEventIds: claimedIds,
                activeDungeonSession: workingActiveSession,
                offlineActivity: workingActivity,
                shopPurchases: loaded.shopPurchases,
                eventShopPurchases: loaded.eventShopPurchases,
                currencies: loaded.currencies,
                clockState: _clockState,
                periodicQuestStates: loaded.periodicQuestStates,
                gachaPityStates: loaded.gachaPityStates,
                unlockedSpecializations: loaded.unlockedSpecializations,
              ),
            );
          }
        }
      }
    } else {
      // Tidak menjalankan simulasi (paused / invalidClock / zeroElapsed /
      // alreadyClaimed / firstLaunch). Pertahankan high-water mark &
      // persistensikan normalisasi downed bila diperlukan.
      final isInvalidClock =
          firstResult.status == OfflineProgressionStatus.invalidClock;
      final effectiveSavedAtMs = isInvalidClock
          ? previousHighWater
          : math.max(now, previousHighWater);
      final effectiveActiveAtMs = isInvalidClock
          ? loaded.session.lastActiveAtMs
          : math.max(now, loaded.session.lastActiveAtMs);
      final effectiveClaimAtMs = math.max(
        loaded.session.lastOfflineClaimAtMs,
        firstResult.newLastOfflineClaimAtMs,
      );
      _highWaterTimestampMs = math.max(
        _highWaterTimestampMs,
        effectiveSavedAtMs,
      );

      workingSession = loaded.session.copyWith(
        lastActiveAtMs: effectiveActiveAtMs,
        lastSavedAtMs: effectiveSavedAtMs,
        lastOfflineClaimAtMs: effectiveClaimAtMs,
      );

      if (normalizedRecovery.normalized) {
        final baseCharSnap = character.toSnapshot();
        final isRecoverable = workingActiveSession?.isRecoverable == true;
        final persistedCharSnap = PlayerCharacterSnapshot(
          progress: baseCharSnap.progress,
          specializationId: baseCharSnap.specializationId,
          skillLevels: baseCharSnap.skillLevels,
          skillCooldownTicks: isRecoverable
              ? loaded.character.skillCooldownTicks
              : const {},
          equipped: baseCharSnap.equipped,
          currentHp: isRecoverable
              ? (normalizedRecovery.recoveredHp ?? loaded.character.currentHp)
              : null,
        );
        await saveSnapshot(
          PlayerSaveSnapshot(
            playerId: loaded.playerId,
            character: persistedCharSnap,
            inventory: inventory.toSnapshot(),
            dungeon: workingDungeon,
            dungeonProgresses: Map.unmodifiable(workingProgresses),
            cycleProgress: workingCycle,
            session: workingSession,
            claimedEventIds: claimedIds,
            activeDungeonSession: workingActiveSession,
            offlineActivity: workingActivity,
            shopPurchases: loaded.shopPurchases,
            eventShopPurchases: loaded.eventShopPurchases,
            currencies: loaded.currencies,
            clockState: _clockState,
          ),
        );
      }
    }
    if (_clockState != loaded.clockState &&
        repository is ClockStateRepository) {
      await (repository as ClockStateRepository).saveClockState(_clockState);
    }

    final finalRecoverable = workingActiveSession?.isRecoverable == true;
    return LoadedGameSession(
      character: character,
      inventory: inventory,
      dungeon: workingDungeon,
      dungeonProgresses: Map.unmodifiable(workingProgresses),
      cycleProgress: workingCycle,
      session: workingSession,
      claimedEventIds: claimedIds,
      offlineResult: aggregatedResult,
      rewardProcessor: rewardProcessor,
      activeDungeonSession: workingActiveSession,
      offlineActivity: workingActivity,
      recoveredHp: finalRecoverable ? simHp : null,
      recoveredSkillCooldownTicks: finalRecoverable
          ? Map.unmodifiable(simSkillCooldowns)
          : const {},
      shopPurchases: loaded.shopPurchases,
      eventShopPurchases: loaded.eventShopPurchases,
      currencies: loaded.currencies,
      clockState: _clockState,
      periodicQuestStates: loaded.periodicQuestStates,
      gachaPityStates: loaded.gachaPityStates,
      unlockedSpecializations: loaded.unlockedSpecializations,
    );
  }

  Future<void> _pruneExpiredClaimsIfSupported(LoadedGameSession session) async {
    if (session.isFirstLaunch || session.loadError != null) return;
    if (repository is! ClaimedRewardsPruningRepository) return;

    final effectiveNowMs = math.max(
      _clockState.lastSeenAtMs,
      _resolveClock(
        current: _clockState,
        rawNowMs: math.max(0, _nowMs()),
      ).effectiveMs,
    );
    final cutoffMs = effectiveNowMs - config.claimedRewards.retentionMs;
    if (cutoffMs <= 0) return;

    final periodService = PeriodService(config: config.time);
    final activePeriodKeys = <String>{
      periodService.keyFor(Period.daily, effectiveNowMs),
      periodService.keyFor(Period.weekly, effectiveNowMs),
    };
    final activeRunId = session.activeDungeonSession?.isRecoverable == true
        ? session.activeDungeonSession!.runId
        : null;

    await (repository as ClaimedRewardsPruningRepository).pruneClaimedRewards(
      cutoffMs: cutoffMs,
      activeRunId: activeRunId,
      activePeriodKeys: activePeriodKeys,
    );
  }

  OfflineProgressionResult _mergeResults(
    OfflineProgressionResult prev,
    OfflineProgressionResult next,
  ) {
    final addedStacks = <String, int>{...prev.addedStacks};
    for (final entry in next.addedStacks.entries) {
      addedStacks[entry.key] = (addedStacks[entry.key] ?? 0) + entry.value;
    }
    final overflowStacks = <String, int>{...prev.overflowStacks};
    for (final entry in next.overflowStacks.entries) {
      overflowStacks[entry.key] =
          (overflowStacks[entry.key] ?? 0) + entry.value;
    }
    final addedEquipment = <EquipmentInstance>[
      ...prev.addedEquipment,
      ...next.addedEquipment,
    ];
    final droppedEquipment = <EquipmentInstance>[
      ...prev.droppedEquipment,
      ...next.droppedEquipment,
    ];

    return OfflineProgressionResult(
      status: next.status,
      eventId: next.eventId.isNotEmpty ? next.eventId : prev.eventId,
      rawElapsed: prev.rawElapsed,
      effectiveElapsed: prev.effectiveElapsed + next.effectiveElapsed,
      cappedAtMaxDuration: prev.cappedAtMaxDuration || next.cappedAtMaxDuration,
      mode: next.mode,
      activityState: next.activityState,
      runsAttempted: prev.runsAttempted + next.runsAttempted,
      runsCompleted: prev.runsCompleted + next.runsCompleted,
      runsFailed: prev.runsFailed + next.runsFailed,
      roomsCleared: prev.roomsCleared + next.roomsCleared,
      encountersCleared: prev.encountersCleared + next.encountersCleared,
      expGained: prev.expGained + next.expGained,
      goldGained: prev.goldGained + next.goldGained,
      levelsGained: prev.levelsGained + next.levelsGained,
      addedStacks: Map.unmodifiable(addedStacks),
      overflowStacks: Map.unmodifiable(overflowStacks),
      addedEquipment: List.unmodifiable(addedEquipment),
      droppedEquipment: List.unmodifiable(droppedEquipment),
      newLastOfflineClaimAtMs: next.newLastOfflineClaimAtMs,
      stopReason: next.stopReason,
      updatedOfflineActivity: next.updatedOfflineActivity,
      updatedActiveDungeonSession: next.updatedActiveDungeonSession,
      updatedDungeonProgress: next.updatedDungeonProgress,
      remainingHp: next.remainingHp,
      remainingSkillCooldownTicks: next.remainingSkillCooldownTicks,
      remainingReviveCooldownTicks: next.remainingReviveCooldownTicks,
      processedDurationMs: prev.processedDurationMs + next.processedDurationMs,
      iterationsUsed: prev.iterationsUsed + next.iterationsUsed,
      nextAttemptIndex: next.nextAttemptIndex,
      failureReason: next.failureReason ?? prev.failureReason,
    );
  }

  ({
    ActiveDungeonSessionSnapshot? activeSession,
    int? recoveredHp,
    bool normalized,
  })
  _normalizeRecoveredSession({
    required PlayerSaveSnapshot loaded,
    required PlayerCharacter character,
  }) {
    final active = loaded.activeDungeonSession;
    if (active == null || !active.isRecoverable) {
      return (activeSession: active, recoveredHp: null, normalized: false);
    }

    final maxHp = character.stats.maxHp;
    var recoveredHp = loaded.character.currentHp;
    var reviveTicks = math.max(0, active.reviveCooldownTicks);
    var normalized = false;

    // Jika aplikasi ditutup ketika pemain sedang Downed, selesaikan konsekuensi
    // revive (30% Max HP + cooldown 90 detik) agar restart tidak memberi revive
    // ganda maupun memunculkan karakter dengan 0 HP.
    if (active.playerStatus == PlayerStatus.downed ||
        (recoveredHp != null && recoveredHp <= 0)) {
      normalized = true;
      recoveredHp = math.max(1, (maxHp * config.revive.hpPercent).round());
      if (reviveTicks == 0) {
        reviveTicks = math.max(
          1,
          (config.revive.cooldownSeconds * CombatSimulation.ticksPerSecond)
              .round(),
        );
      }
    } else if (recoveredHp != null) {
      final clamped = recoveredHp.clamp(1, maxHp);
      if (clamped != recoveredHp) {
        normalized = true;
      }
      recoveredHp = clamped;
    }

    return (
      activeSession: ActiveDungeonSessionSnapshot(
        runId: active.runId,
        dungeonId: active.dungeonId,
        currentRoomId: active.currentRoomId,
        currentRoomIndex: active.currentRoomIndex,
        status: active.status,
        clearedRoomIds: active.clearedRoomIds,
        completionRewardClaimed: active.completionRewardClaimed,
        reviveCooldownTicks: reviveTicks,
        playerStatus: PlayerStatus.alive,
        cycleRank: active.cycleRank,
        bossEventId: active.bossEventId,
        periodKeyAtStart: active.periodKeyAtStart,
      ),
      recoveredHp: recoveredHp,
      normalized: normalized,
    );
  }

  /// Menyimpan snapshot melalui antrean berurutan sehingga save berturut-turut
  /// selalu dijalankan satu per satu sesuai urutan pemanggilan.
  Future<void> saveSnapshot(PlayerSaveSnapshot snapshot) {
    _highWaterTimestampMs = math.max(
      _highWaterTimestampMs,
      math.max(
        snapshot.session.lastSavedAtMs,
        snapshot.session.lastOfflineClaimAtMs,
      ),
    );
    final completer = Completer<void>();
    _saveQueue = _saveQueue.then((_) async {
      try {
        await repository.saveSnapshot(snapshot);
        lastSaveError = null;
        if (!completer.isCompleted) completer.complete();
      } catch (e, st) {
        lastSaveError = e;
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> saveFromRuntime({
    required PlayerCharacter character,
    required Inventory inventory,
    required DungeonProgressSnapshot dungeon,
    required RewardProcessor rewardProcessor,
    required bool autoSkillEnabled,
    required int lastOfflineClaimAtMs,
    int? currentHp,
    Map<String, int> skillCooldownTicks = const {},
    ActiveDungeonSessionSnapshot? activeDungeonSession,
    Map<String, DungeonProgressSnapshot>? dungeonProgresses,
    CycleProgress cycleProgress = const CycleProgress(),
    OfflineActivitySnapshot? offlineActivity,
    Map<String, int> consecutiveDefeats = const {},
    String? lastFailedDungeonId,
    CurrencyService? currencyService,
    List<PeriodicQuestState> periodicQuestStates = const [],
    List<EventShopPurchaseRecord> eventShopPurchases = const [],
    Map<String, GachaPityState> gachaPityStates = const {},
    Set<String> unlockedSpecializations = const {},
    Set<String> extraClaimedEventIds = const {},
  }) {
    final now = math.max(0, _nowMs());
    final resolvedClock = _resolveClock(current: _clockState, rawNowMs: now);
    _clockState = resolvedClock.state;
    final monotonicSavedAtMs = math.max(
      resolvedClock.effectiveMs,
      _highWaterTimestampMs,
    );
    final charSnap = character.toSnapshot();
    final updatedCharSnap = PlayerCharacterSnapshot(
      progress: charSnap.progress,
      specializationId: charSnap.specializationId,
      skillLevels: charSnap.skillLevels,
      skillCooldownTicks: skillCooldownTicks,
      equipped: charSnap.equipped,
      currentHp: currentHp,
    );

    // Simpan event offline, per-kill offline, dungeon clear, room clear, serta
    // penyelesaian siklus Ascension agar klaim ulang dicegah lintas restart.
    final persistentClaimed = {
      for (final id in rewardProcessor.claimedEventIds)
        if (id.startsWith('offline:') ||
            id.startsWith('offline_kill:') ||
            id.startsWith('dungeon_clear:') ||
            id.startsWith('room_clear:') ||
            id.startsWith('ascension:') ||
            id.startsWith('bossquest:') ||
            id.startsWith('boss_spire:'))
          id,
      if (currencyService != null) ...currencyService.claimedIds,
      ...extraClaimedEventIds,
    };

    final mergedProgresses = <String, DungeonProgressSnapshot>{
      ...?dungeonProgresses,
      dungeon.currentDungeonId: dungeon,
    };

    return saveSnapshot(
      PlayerSaveSnapshot(
        character: updatedCharSnap,
        inventory: inventory.toSnapshot(),
        dungeon: dungeon,
        dungeonProgresses: Map.unmodifiable(mergedProgresses),
        cycleProgress: cycleProgress,
        session: GameSessionSnapshot(
          lastActiveAtMs: now >= _highWaterTimestampMs
              ? now
              : monotonicSavedAtMs,
          lastSavedAtMs: monotonicSavedAtMs,
          lastOfflineClaimAtMs: math.max(0, lastOfflineClaimAtMs),
          autoSkillEnabled: autoSkillEnabled,
          consecutiveDefeats: Map<String, int>.unmodifiable({
            for (final entry in consecutiveDefeats.entries)
              if (entry.key.trim().isNotEmpty && entry.value > 0)
                entry.key.trim(): entry.value,
          }),
          lastFailedDungeonId: lastFailedDungeonId,
        ),
        claimedEventIds: persistentClaimed,
        activeDungeonSession: activeDungeonSession,
        offlineActivity:
            offlineActivity ?? const OfflineActivitySnapshot.paused(),
        currencies: currencyService?.toSnapshot() ?? const {},
        clockState: _clockState,
        periodicQuestStates: periodicQuestStates,
        eventShopPurchases: eventShopPurchases,
        gachaPityStates: gachaPityStates,
        unlockedSpecializations: unlockedSpecializations,
      ),
    );
  }

  /// Menyiapkan definisi dungeon, monster boss, dan profil kesulitan untuk
  /// run Boss Event (Daily/Weekly) berdasarkan waktu efektif & progres siklus.
  PreparedBossRun prepareBossRun({
    required Period period,
    required CycleProgress cycleProgress,
    required Map<String, DungeonProgressSnapshot> dungeonProgresses,
  }) {
    final bossEvents = config.bossEvents;
    if (bossEvents == null) {
      throw StateError('Konfigurasi boss_events.json tidak tersedia.');
    }
    final arenaLayout = BossEventService.resolveArenaLayout(config);
    if (arenaLayout == null || arenaLayout.isEmpty) {
      throw StateError(
        'Layout arena boss "${bossEvents.arenaMapRef}" tidak ditemukan.',
      );
    }

    final rawNow = math.max(0, _nowMs());
    final effectiveNow = _resolveClock(
      current: _clockState,
      rawNowMs: rawNow,
    ).effectiveMs;
    final periodService = PeriodService(config: config.time);
    final periodKey = periodService.keyFor(period, effectiveNow);
    final periodIndex = period == Period.daily
        ? periodService.dayIndex(effectiveNow)
        : periodService.weekIndex(effectiveNow);

    final bossService = BossEventService(bossEvents);
    final boss = bossService.bossFor(period, periodIndex);
    final reference = bossService.resolveReference(
      cycleProgress,
      dungeonProgresses,
      config.dungeons,
    );
    final basePowerFactor = bossEvents.tierFor(period).powerFactor;
    final diffService = DifficultyService(config.difficulty);
    final powerFactor = diffService.computeBossPowerFactor(
      basePowerFactor,
      reference.cycleRank,
      period: period,
    );
    final difficultyProfile = diffService.profileForBoss(
      reference,
      powerFactor,
    );
    final bossDungeon = bossService.buildBossDungeon(
      boss: boss,
      period: period,
      reference: reference,
      arenaLayout: arenaLayout,
    );
    final bossMonster = boss.toEnemyDefinition(
      level: reference.dungeon.recommendedLevel,
      spriteTemplate: config.monsters[boss.spriteRef],
    );

    return PreparedBossRun(
      period: period,
      periodKey: periodKey,
      boss: boss,
      reference: reference,
      difficultyProfile: difficultyProfile,
      bossDungeon: bossDungeon,
      bossMonster: bossMonster,
    );
  }

  /// Membangun ulang context runtime untuk recovery sesi Boss Event yang
  /// tersimpan di [ActiveDungeonSessionSnapshot].
  PreparedBossRun? prepareBossRecovery(
    ActiveDungeonSessionSnapshot saved, {
    required CycleProgress cycleProgress,
    required Map<String, DungeonProgressSnapshot> dungeonProgresses,
  }) {
    final bossEventId = saved.bossEventId;
    final bossEvents = config.bossEvents;
    if (!saved.isBossEvent || bossEventId == null || bossEvents == null) {
      return null;
    }
    final boss = bossEvents.findBossById(bossEventId);
    final arenaLayout = BossEventService.resolveArenaLayout(config);
    if (boss == null || arenaLayout == null || arenaLayout.isEmpty) {
      return null;
    }

    final period = bossEvents.periodForSession(
      bossEventId: bossEventId,
      dungeonId: saved.dungeonId,
    );
    if (period == null) {
      return null;
    }
    final bossService = BossEventService(bossEvents);
    final recoveryCycle = CycleProgress(
      ascensionRank: math.max(0, saved.cycleRank),
      highestAscensionRank: cycleProgress.highestAscensionRank,
      lastNormalDungeonId: cycleProgress.lastNormalDungeonId,
    );
    final reference = bossService.resolveReference(
      recoveryCycle,
      dungeonProgresses,
      config.dungeons,
    );
    final basePowerFactor = bossEvents.tierFor(period).powerFactor;
    final diffService = DifficultyService(config.difficulty);
    final powerFactor = diffService.computeBossPowerFactor(
      basePowerFactor,
      reference.cycleRank,
      period: period,
    );
    final difficultyProfile = diffService.profileForBoss(
      reference,
      powerFactor,
    );
    final bossDungeon = bossService.buildBossDungeon(
      boss: boss,
      period: period,
      reference: reference,
      arenaLayout: arenaLayout,
      dungeonId: saved.dungeonId,
    );
    final bossMonster = boss.toEnemyDefinition(
      level: reference.dungeon.recommendedLevel,
      spriteTemplate: config.monsters[boss.spriteRef],
    );

    return PreparedBossRun(
      period: period,
      periodKey: saved.periodKeyAtStart ?? '',
      boss: boss,
      reference: reference,
      difficultyProfile: difficultyProfile,
      bossDungeon: bossDungeon,
      bossMonster: bossMonster,
    );
  }

  /// Memulai run Boss Event melalui [dungeonManager] dan langsung
  /// mempersistensikan `bossEventId` serta `periodKeyAtStart` ke snapshot sesi.
  Future<PreparedBossRun> startBossRun({
    required Period period,
    required DungeonManager dungeonManager,
    required PlayerCharacter character,
    required Inventory inventory,
    required DungeonProgressSnapshot dungeon,
    required Map<String, DungeonProgressSnapshot> dungeonProgresses,
    required CycleProgress cycleProgress,
    required RewardProcessor rewardProcessor,
    required bool autoSkillEnabled,
    required int lastOfflineClaimAtMs,
    CurrencyService? currencyService,
    int? currentHp,
    Map<String, int> skillCooldownTicks = const {},
    OfflineActivitySnapshot? offlineActivity,
    Map<String, int> consecutiveDefeats = const {},
    String? lastFailedDungeonId,
    String? runId,
    List<PeriodicQuestState> periodicQuestStates = const [],
  }) async {
    final prepared = prepareBossRun(
      period: period,
      cycleProgress: cycleProgress,
      dungeonProgresses: dungeonProgresses,
    );
    dungeonManager.startBossDungeon(
      bossDungeon: prepared.bossDungeon,
      bossMonster: prepared.bossMonster,
      difficultyProfile: prepared.difficultyProfile,
      bossEventId: prepared.boss.id,
      periodKeyAtStart: prepared.periodKey,
      cycleRank: prepared.reference.cycleRank,
      runId: runId,
    );
    await saveFromRuntime(
      character: character,
      inventory: inventory,
      dungeon: dungeon,
      dungeonProgresses: dungeonProgresses,
      cycleProgress: cycleProgress,
      rewardProcessor: rewardProcessor,
      autoSkillEnabled: autoSkillEnabled,
      lastOfflineClaimAtMs: lastOfflineClaimAtMs,
      currentHp: currentHp,
      skillCooldownTicks: skillCooldownTicks,
      activeDungeonSession: dungeonManager.toActiveSessionSnapshot(),
      offlineActivity: offlineActivity,
      consecutiveDefeats: consecutiveDefeats,
      lastFailedDungeonId: lastFailedDungeonId,
      currencyService: currencyService,
      periodicQuestStates: periodicQuestStates,
    );
    return prepared;
  }

  /// Menyelesaikan klaim hadiah Boss Quest (Daily/Weekly) secara atomik:
  /// - Waktu efektif diselesaikan lewat [ClockGuard] (jam mundur tidak membuka ulang quest).
  /// - Hadiah hanya diberikan jika `periodKeyAtStart == currentPeriodKey` & belum selesai.
  /// - Persistensi dilakukan dalam satu transaksi [saveSnapshot]; jika gagal,
  ///   seluruh mutasi in-memory di-rollback tanpa efek samping parsial.
  Future<BossQuestSettlementResult> settleBossQuestVictory({
    required Period period,
    required String periodKeyAtStart,
    required DifficultyProfile difficultyProfile,
    required PlayerCharacter character,
    required Inventory inventory,
    required DungeonProgressSnapshot dungeon,
    required Map<String, DungeonProgressSnapshot> dungeonProgresses,
    required CycleProgress cycleProgress,
    required RewardProcessor rewardProcessor,
    required CurrencyService currencyService,
    required BossQuestService bossQuestService,
    required bool autoSkillEnabled,
    required int lastOfflineClaimAtMs,
    int? currentHp,
    Map<String, int> skillCooldownTicks = const {},
    ActiveDungeonSessionSnapshot? activeDungeonSession,
    OfflineActivitySnapshot? offlineActivity,
    Map<String, int> consecutiveDefeats = const {},
    String? lastFailedDungeonId,
  }) async {
    final bossEvents = config.bossEvents;
    if (bossEvents == null) {
      throw StateError('Konfigurasi boss_events belum dimuat.');
    }
    final tier = bossEvents.tierFor(period);
    final rawNow = math.max(0, _nowMs());
    final resolved = _resolveClock(current: _clockState, rawNowMs: rawNow);
    final prevClockState = _clockState;
    _clockState = resolved.state;

    final periodService = PeriodService(config: config.time);
    final currentPeriodKey = periodService.keyFor(period, resolved.effectiveMs);

    final prevCharSnap = character.toSnapshot();
    final prevBalances = currencyService.toSnapshot();
    final prevCurrencyClaims = currencyService.claimedIds;
    final prevQuestStates = bossQuestService.toSnapshot();
    final workingClaimedIds = Set<String>.of(rewardProcessor.claimedEventIds);

    final result = bossQuestService.onBossDefeated(
      questId: tier.questId,
      periodKeyAtStart: periodKeyAtStart,
      currentPeriodKey: currentPeriodKey,
      reward: tier.reward,
      difficultyProfile: difficultyProfile,
      completedAtMs: resolved.effectiveMs,
      character: character,
      currencyService: currencyService,
      claimedEventIds: workingClaimedIds,
    );

    if (!result.rewardGranted) {
      return result;
    }

    try {
      await saveFromRuntime(
        character: character,
        inventory: inventory,
        dungeon: dungeon,
        dungeonProgresses: dungeonProgresses,
        cycleProgress: cycleProgress,
        rewardProcessor: rewardProcessor,
        autoSkillEnabled: autoSkillEnabled,
        lastOfflineClaimAtMs: lastOfflineClaimAtMs,
        currentHp: currentHp,
        skillCooldownTicks: skillCooldownTicks,
        activeDungeonSession: activeDungeonSession,
        offlineActivity: offlineActivity,
        consecutiveDefeats: consecutiveDefeats,
        lastFailedDungeonId: lastFailedDungeonId,
        currencyService: currencyService,
        periodicQuestStates: bossQuestService.toSnapshot(),
        extraClaimedEventIds: {result.claimId},
      );
      rewardProcessor.markClaimed(result.claimId);
      return result;
    } catch (_) {
      _clockState = prevClockState;
      character.restoreSnapshot(prevCharSnap);
      currencyService.restoreState(
        balances: prevBalances,
        claimedIds: prevCurrencyClaims,
      );
      bossQuestService.replaceStates(prevQuestStates);
      rethrow;
    }
  }

  /// Menyiapkan definisi dungeon, monster boss, dan arena untuk satu lantai Menara Bos.
  PreparedBossSpireRun prepareBossSpireRun({required int floorNumber}) {
    final spireConfig = config.bossSpire;
    if (spireConfig == null) {
      throw StateError('Konfigurasi boss_spire.json tidak tersedia.');
    }
    final floor = spireConfig.floorFor(floorNumber);
    if (floor == null) {
      throw ArgumentError.value(
        floorNumber,
        'floorNumber',
        'Lantai $floorNumber tidak terdaftar di Menara Bos.',
      );
    }
    final arenaLayout = BossSpireService.resolveArenaLayout(config);
    if (arenaLayout == null || arenaLayout.isEmpty) {
      throw StateError(
        'Layout arena Menara Bos "${spireConfig.arenaMapRef}" tidak ditemukan.',
      );
    }

    final spireService = BossSpireService(spireConfig);
    final bossDungeon = spireService.buildFloorDungeon(
      floor: floor,
      arenaLayout: arenaLayout,
    );
    final bossMonster = floor.toEnemyDefinition(
      spriteTemplate: config.monsters[floor.spriteRef],
    );

    return PreparedBossSpireRun(
      floor: floor,
      bossDungeon: bossDungeon,
      bossMonster: bossMonster,
      difficultyProfile: DifficultyProfile.identity,
    );
  }

  /// Memulai sesi combat untuk lantai Menara Bos (Boss Spire).
  Future<PreparedBossSpireRun> startBossSpireRun({
    required int floorNumber,
    required DungeonManager dungeonManager,
    required PlayerCharacter character,
    required Inventory inventory,
    required DungeonProgressSnapshot dungeon,
    required Map<String, DungeonProgressSnapshot> dungeonProgresses,
    required CycleProgress cycleProgress,
    required RewardProcessor rewardProcessor,
    required bool autoSkillEnabled,
    required int lastOfflineClaimAtMs,
    CurrencyService? currencyService,
    int? currentHp,
    Map<String, int> skillCooldownTicks = const {},
    OfflineActivitySnapshot? offlineActivity,
    Map<String, int> consecutiveDefeats = const {},
    String? lastFailedDungeonId,
    String? runId,
  }) async {
    final prepared = prepareBossSpireRun(floorNumber: floorNumber);
    dungeonManager.startBossDungeon(
      bossDungeon: prepared.bossDungeon,
      bossMonster: prepared.bossMonster,
      difficultyProfile: prepared.difficultyProfile,
      bossEventId: prepared.floor.bossId,
      periodKeyAtStart: 'spire_floor_${prepared.floor.floor}',
      cycleRank: cycleProgress.ascensionRank,
      runId: runId,
    );
    await saveFromRuntime(
      character: character,
      inventory: inventory,
      dungeon: dungeon,
      dungeonProgresses: dungeonProgresses,
      cycleProgress: cycleProgress,
      rewardProcessor: rewardProcessor,
      autoSkillEnabled: autoSkillEnabled,
      lastOfflineClaimAtMs: lastOfflineClaimAtMs,
      currentHp: currentHp,
      skillCooldownTicks: skillCooldownTicks,
      activeDungeonSession: dungeonManager.toActiveSessionSnapshot(),
      offlineActivity: offlineActivity,
      consecutiveDefeats: consecutiveDefeats,
      lastFailedDungeonId: lastFailedDungeonId,
      currencyService: currencyService,
    );
    return prepared;
  }

  /// Memproses kemenangan di lantai Menara Bos secara atomik dan idempoten.
  Future<BossSpireSettlementResult> settleBossSpireVictory({
    required int floorNumber,
    required PlayerCharacter character,
    required Inventory inventory,
    required DungeonProgressSnapshot dungeon,
    required Map<String, DungeonProgressSnapshot> dungeonProgresses,
    required CycleProgress cycleProgress,
    required RewardProcessor rewardProcessor,
    required CurrencyService currencyService,
    required bool autoSkillEnabled,
    required int lastOfflineClaimAtMs,
    int? currentHp,
    Map<String, int> skillCooldownTicks = const {},
    ActiveDungeonSessionSnapshot? activeDungeonSession,
    OfflineActivitySnapshot? offlineActivity,
    Map<String, int> consecutiveDefeats = const {},
    String? lastFailedDungeonId,
  }) async {
    final spireConfig = config.bossSpire;
    if (spireConfig == null) {
      throw StateError('Konfigurasi boss_spire belum dimuat.');
    }

    final prevCharSnap = character.toSnapshot();
    final prevBalances = currencyService.toSnapshot();
    final prevCurrencyClaims = currencyService.claimedIds;
    final workingClaimedIds = Set<String>.of(rewardProcessor.claimedEventIds);

    final resolvedClock = _resolveClock(
      current: _clockState,
      rawNowMs: _nowMs(),
    );
    final periodService = PeriodService(config: config.time);
    final cycleKey = periodService.biweeklyKey(resolvedClock.effectiveMs);

    final spireService = BossSpireService(spireConfig);
    final result = spireService.settleFloorVictory(
      floorNumber: floorNumber,
      character: character,
      currencyService: currencyService,
      claimedEventIds: workingClaimedIds,
      cycleKey: cycleKey,
    );
    final claimId =
        result.claimId ??
        spireConfig.floorFor(floorNumber)?.claimIdFor(cycleKey) ??
        spireConfig.floorFor(floorNumber)?.claimId ??
        'boss_spire:$cycleKey:floor_$floorNumber';

    try {
      await saveFromRuntime(
        character: character,
        inventory: inventory,
        dungeon: dungeon,
        dungeonProgresses: dungeonProgresses,
        cycleProgress: cycleProgress,
        rewardProcessor: rewardProcessor,
        autoSkillEnabled: autoSkillEnabled,
        lastOfflineClaimAtMs: lastOfflineClaimAtMs,
        currentHp: currentHp,
        skillCooldownTicks: skillCooldownTicks,
        activeDungeonSession: activeDungeonSession,
        offlineActivity: offlineActivity,
        consecutiveDefeats: consecutiveDefeats,
        lastFailedDungeonId: lastFailedDungeonId,
        currencyService: currencyService,
        extraClaimedEventIds: {claimId},
      );
      rewardProcessor.markClaimed(claimId);
      return result;
    } catch (_) {
      character.restoreSnapshot(prevCharSnap);
      currencyService.restoreState(
        balances: prevBalances,
        claimedIds: prevCurrencyClaims,
      );
      rethrow;
    }
  }
}

/// Paket data siap-pakai untuk memulai satu run di Menara Bos (Boss Spire).
class PreparedBossSpireRun {
  const PreparedBossSpireRun({
    required this.floor,
    required this.bossDungeon,
    required this.bossMonster,
    required this.difficultyProfile,
  });

  final BossSpireFloorConfig floor;
  final DungeonDefinition bossDungeon;
  final EnemyDefinition bossMonster;
  final DifficultyProfile difficultyProfile;
}

/// Paket data siap-pakai untuk memulai atau memulihkan satu run Boss Event.
class PreparedBossRun {
  const PreparedBossRun({
    required this.period,
    required this.periodKey,
    required this.boss,
    required this.reference,
    required this.difficultyProfile,
    required this.bossDungeon,
    required this.bossMonster,
  });

  final Period period;
  final String periodKey;
  final BossEvent boss;
  final BossReference reference;
  final DifficultyProfile difficultyProfile;
  final DungeonDefinition bossDungeon;
  final EnemyDefinition bossMonster;
}
