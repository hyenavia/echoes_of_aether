import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

import '../../core/perf/perf_tracer.dart';
import '../../domain/entities/clock_state.dart';
import '../../domain/entities/combat_stats.dart';
import '../../domain/entities/cycle_progress.dart';
import '../../domain/entities/dungeon_session.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/event_shop_purchase.dart';
import '../../domain/entities/gacha_config.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/entities/game_settings.dart';
import '../../domain/entities/infinite_spire.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/offline_activity.dart';
import '../../domain/entities/periodic_quest_state.dart';
import '../../domain/entities/player_progress.dart';
import '../../domain/entities/player_save_snapshot.dart';
import '../../domain/entities/player_status.dart';
import '../../domain/entities/progression_config.dart';
import '../../domain/repositories/game_settings_repository.dart';
import '../../domain/repositories/player_progress_repository.dart';
import '../../domain/services/claimed_rewards_pruner.dart';
import '../../domain/services/game_clock.dart';
import '../../domain/services/save_snapshot_codec.dart';
import '../database/app_database.dart' hide ClockState, PeriodicQuestState;

typedef RecoveryWarningLogger = void Function(String message);

/// Implementasi Drift/SQLite untuk [PlayerSaveRepository],
/// [PlayerProgressRepository], dan [GameSettingsRepository]. Seluruh write
/// berjalan atomik dalam satu transaction, dan seluruh data hasil load
/// divalidasi terhadap [GameConfig].
class DriftPlayerSaveRepository
    implements
        PlayerSaveRepository,
        SnapshotReplaceRepository,
        PlayerProgressRepository,
        GameSettingsRepository,
        CycleProgressRepository,
        ShopPurchaseRepository,
        EventShopPurchaseRepository,
        ClockStateRepository,
        ClaimedRewardsPruningRepository {
  DriftPlayerSaveRepository({
    required this.db,
    required this.config,
    this.playerId = GameSessionSnapshot.defaultPlayerId,
    this.clock = const SystemGameClock(),
    RecoveryWarningLogger? onRecoveryWarning,
  }) : _warn = onRecoveryWarning ?? _defaultWarn;

  final AppDatabase db;
  final GameConfig config;
  final String playerId;
  final GameClock clock;
  final RecoveryWarningLogger _warn;

  PlayerSaveSnapshot? _lastSavedSnapshot;
  List<EquipmentInstance>? _lastSavedAllEquipment;
  String? _lastSavedPid;

  void _invalidateSaveDiffCache() {
    _lastSavedSnapshot = null;
    _lastSavedAllEquipment = null;
    _lastSavedPid = null;
  }

  void _recordSavedBaseline(
    PlayerSaveSnapshot snapshot,
    List<EquipmentInstance> allEquipment,
    String pid,
  ) {
    _lastSavedSnapshot = snapshot;
    _lastSavedAllEquipment = allEquipment;
    _lastSavedPid = pid;
  }

  static void _defaultWarn(String message) =>
      debugPrint('[SaveRecovery] $message');

  static const String _keyBgmEnabled = 'audio.bgm_enabled';
  static const String _keySfxEnabled = 'audio.sfx_enabled';
  static const String _keyBgmVolume = 'audio.bgm_volume';
  static const String _keySfxVolume = 'audio.sfx_volume';
  static const String _keyNotifyAutoFarm = 'notifications.auto_farming_full';
  static const String _keyNotifyDailyBoss = 'notifications.daily_boss_reminder';
  static const String _keyNotifyWeeklyBoss =
      'notifications.weekly_boss_reminder';
  static const String _keyNotifyAbyssalSpireReset =
      'notifications.abyssal_spire_reset';
  static const String _keyNotifyEventShop = 'notifications.event_shop_ending';
  static const String _keyOfflineAutoSalvage = 'offline.auto_salvage_equipment';
  static const String _keyLastSeenUpdateNoticeVersion =
      'app.last_seen_update_notice_version';

  @override
  Future<GameSettingsData> loadSettings() async {
    final rows = await db.select(db.gameSettings).get();
    final map = <String, String>{for (final r in rows) r.key: r.value};
    const defaults = GameSettingsData();

    bool parseBool(String key, bool fallback) {
      final raw = map[key];
      if (raw == 'true') return true;
      if (raw == 'false') return false;
      return fallback;
    }

    double parseVol(String key, double fallback) {
      final raw = map[key];
      if (raw == null) return fallback;
      final parsed = double.tryParse(raw);
      if (parsed == null || parsed.isNaN || parsed.isInfinite) return fallback;
      return parsed.clamp(0.0, 1.0);
    }

    int parseNonNegInt(String key, int fallback) {
      final raw = map[key];
      if (raw == null) return fallback;
      final parsed = int.tryParse(raw);
      if (parsed == null || parsed < 0) return fallback;
      return parsed;
    }

    return GameSettingsData(
      bgmEnabled: parseBool(_keyBgmEnabled, defaults.bgmEnabled),
      sfxEnabled: parseBool(_keySfxEnabled, defaults.sfxEnabled),
      bgmVolume: parseVol(_keyBgmVolume, defaults.bgmVolume),
      sfxVolume: parseVol(_keySfxVolume, defaults.sfxVolume),
      notifyAutoFarmingFull: parseBool(
        _keyNotifyAutoFarm,
        defaults.notifyAutoFarmingFull,
      ),
      notifyDailyBossReminder: parseBool(
        _keyNotifyDailyBoss,
        defaults.notifyDailyBossReminder,
      ),
      notifyWeeklyBossReminder: parseBool(
        _keyNotifyWeeklyBoss,
        defaults.notifyWeeklyBossReminder,
      ),
      notifyAbyssalSpireReset: parseBool(
        _keyNotifyAbyssalSpireReset,
        defaults.notifyAbyssalSpireReset,
      ),
      notifyEventShopEnding: parseBool(
        _keyNotifyEventShop,
        defaults.notifyEventShopEnding,
      ),
      autoSalvageOfflineEquipment: parseBool(
        _keyOfflineAutoSalvage,
        defaults.autoSalvageOfflineEquipment,
      ),
      lastSeenUpdateNoticeVersion: parseNonNegInt(
        _keyLastSeenUpdateNoticeVersion,
        defaults.lastSeenUpdateNoticeVersion,
      ),
    );
  }

  @override
  Future<void> saveSettings(GameSettingsData settings) async {
    final normalized = settings.copyWith();
    await db.transaction(() async {
      await db.batch((b) {
        b.insertAll(db.gameSettings, [
          GameSettingsCompanion.insert(
            key: _keyBgmEnabled,
            value: normalized.bgmEnabled ? 'true' : 'false',
          ),
          GameSettingsCompanion.insert(
            key: _keySfxEnabled,
            value: normalized.sfxEnabled ? 'true' : 'false',
          ),
          GameSettingsCompanion.insert(
            key: _keyBgmVolume,
            value: normalized.bgmVolume.toStringAsFixed(3),
          ),
          GameSettingsCompanion.insert(
            key: _keySfxVolume,
            value: normalized.sfxVolume.toStringAsFixed(3),
          ),
          GameSettingsCompanion.insert(
            key: _keyNotifyAutoFarm,
            value: normalized.notifyAutoFarmingFull ? 'true' : 'false',
          ),
          GameSettingsCompanion.insert(
            key: _keyNotifyDailyBoss,
            value: normalized.notifyDailyBossReminder ? 'true' : 'false',
          ),
          GameSettingsCompanion.insert(
            key: _keyNotifyWeeklyBoss,
            value: normalized.notifyWeeklyBossReminder ? 'true' : 'false',
          ),
          GameSettingsCompanion.insert(
            key: _keyNotifyAbyssalSpireReset,
            value: normalized.notifyAbyssalSpireReset ? 'true' : 'false',
          ),
          GameSettingsCompanion.insert(
            key: _keyNotifyEventShop,
            value: normalized.notifyEventShopEnding ? 'true' : 'false',
          ),
          GameSettingsCompanion.insert(
            key: _keyOfflineAutoSalvage,
            value: normalized.autoSalvageOfflineEquipment ? 'true' : 'false',
          ),
          GameSettingsCompanion.insert(
            key: _keyLastSeenUpdateNoticeVersion,
            value: '${math.max(0, normalized.lastSeenUpdateNoticeVersion)}',
          ),
        ], mode: InsertMode.insertOrReplace);
      });
    });
  }

  // ---- PlayerProgressRepository (ringkas) ----

  @override
  Future<PlayerProgress?> load() async {
    final row = await (db.select(
      db.players,
    )..where((t) => t.id.equals(playerId))).getSingleOrNull();
    if (row == null) return null;
    final maxLvl =
        config.progression.maxLevel ?? ProgressionConfig.kTechnicalMaxLevel;
    final safeLevel = math.min(maxLvl, math.max(1, row.level));
    final safeExp =
        (config.progression.maxLevel != null &&
            safeLevel >= config.progression.maxLevel!)
        ? 0
        : math.max(0, row.currentExp);
    return PlayerProgress(
      level: safeLevel,
      currentExp: safeExp,
      gold: math.max(0, row.gold),
      ascensionPhase: row.ascensionPhase,
    );
  }

  @override
  Future<void> save(PlayerProgress progress) async {
    _invalidateSaveDiffCache();
    _validateProgress(progress);
    final nowMs = clock.nowMs;
    final baseStats = config.progression.statsAt(progress.level);
    await db.transaction(() async {
      await db
          .into(db.players)
          .insertOnConflictUpdate(
            PlayersCompanion.insert(
              id: playerId,
              level: progress.level,
              currentExp: progress.currentExp,
              gold: progress.gold,
              ascensionPhase: Value(progress.ascensionPhase),
              baseStatsJson: jsonEncode(_encodeCombatStats(baseStats)),
              lastSavedAtMs: nowMs,
            ),
          );
    });
  }

  // ---- PlayerSaveRepository (penuh & atomik) ----

  @override
  Future<void> saveSnapshot(PlayerSaveSnapshot snapshot) =>
      PerfTracer.traceAsync('Drift.saveSnapshot', () async {
        final prepared = PerfTracer.traceSync(
          'Drift.validateAndPrepare',
          () => _validateAndPrepareSnapshot(snapshot),
        );
        final savedAtMs = snapshot.session.lastSavedAtMs > 0
            ? snapshot.session.lastSavedAtMs
            : clock.nowMs;
        final activeAtMs = snapshot.session.lastActiveAtMs > 0
            ? snapshot.session.lastActiveAtMs
            : savedAtMs;

        await PerfTracer.traceAsync('Drift.saveTransaction', () {
          return db.transaction(() async {
            await _writePreparedSnapshot(
              prepared,
              savedAtMs: savedAtMs,
              activeAtMs: activeAtMs,
              lastOfflineClaimAtMs: math.max(
                0,
                snapshot.session.lastOfflineClaimAtMs,
              ),
              clockState: snapshot.clockState,
              deleteAllPlayerRowsFirst: false,
            );
          });
        });
        _recordSavedBaseline(snapshot, prepared.allEquipment, prepared.pid);
      });

  /// Mengganti seluruh data pemain dalam satu transaksi atomik tanpa menyentuh
  /// `GameSettings`. Mengosongkan sesi dungeon aktif, menyetel jangkar offline
  /// ke [restoredAtMs] dengan mode pause, serta menjaga `ClockState.lastSeenAtMs`
  /// minimal sebesar nilai lokal sebelumnya.
  @override
  Future<void> replaceSnapshot(
    PlayerSaveSnapshot snapshot, {
    required int restoredAtMs,
    @visibleForTesting void Function()? beforeCommitHook,
  }) async {
    _invalidateSaveDiffCache();
    final safeRestoredAt = math.max(0, restoredAtMs);
    final sanitizedSnapshot = PlayerSaveSnapshot(
      playerId: snapshot.playerId,
      character: snapshot.character,
      inventory: snapshot.inventory,
      dungeon: snapshot.dungeon,
      dungeonProgresses: snapshot.dungeonProgresses,
      cycleProgress: snapshot.cycleProgress,
      session: snapshot.session.copyWith(
        lastActiveAtMs: safeRestoredAt,
        lastSavedAtMs: safeRestoredAt,
        lastOfflineClaimAtMs: safeRestoredAt,
      ),
      claimedEventIds: snapshot.claimedEventIds,
      activeDungeonSession: null,
      offlineActivity: const OfflineActivitySnapshot.paused(),
      shopPurchases: snapshot.shopPurchases,
      eventShopPurchases: snapshot.eventShopPurchases,
      currencies: snapshot.currencies,
      clockState: snapshot.clockState,
      periodicQuestStates: snapshot.periodicQuestStates,
      gachaPityStates: snapshot.gachaPityStates,
      unlockedSpecializations: snapshot.unlockedSpecializations,
      infiniteSpireProgress: snapshot.infiniteSpireProgress,
    );
    final prepared = _validateAndPrepareSnapshot(sanitizedSnapshot);

    await db.transaction(() async {
      final existingClock = await (db.select(
        db.clockStates,
      )..where((t) => t.playerId.equals(prepared.pid))).getSingleOrNull();
      final mergedClockState = ClockState(
        lastSeenAtMs: math.max(
          0,
          math.max(
            snapshot.clockState.lastSeenAtMs,
            existingClock?.lastSeenAtMs ?? 0,
          ),
        ),
        forwardJumpCount: math.max(0, snapshot.clockState.forwardJumpCount),
        maxForwardJumpMs: math.max(0, snapshot.clockState.maxForwardJumpMs),
      );

      await _writePreparedSnapshot(
        prepared,
        savedAtMs: safeRestoredAt,
        activeAtMs: safeRestoredAt,
        lastOfflineClaimAtMs: safeRestoredAt,
        clockState: mergedClockState,
        deleteAllPlayerRowsFirst: true,
      );

      beforeCommitHook?.call();
    });
  }

  _PreparedSnapshotWrite _validateAndPrepareSnapshot(
    PlayerSaveSnapshot snapshot,
  ) {
    final pid = snapshot.playerId;
    final progress = snapshot.character.progress;
    _validateProgress(progress);

    // Kumpulkan seluruh equipment (tas + terpasang) dan validasi tidak ada id duplikat.
    final allEquipment = <EquipmentInstance>[];
    final seenIds = <String>{};
    void collect(EquipmentInstance item) {
      if (!seenIds.add(item.id)) {
        throw StateError('Duplicate equipment instance id "${item.id}".');
      }
      if (!config.items.containsKey(item.definitionId)) {
        throw StateError(
          'Unknown item definition "${item.definitionId}" on "${item.id}".',
        );
      }
      allEquipment.add(item);
    }

    for (final item in snapshot.inventory.equipment) {
      collect(item);
    }
    for (final entry in snapshot.character.equipped.entries) {
      if (entry.value.slot != entry.key) {
        throw StateError(
          'Equipment "${entry.value.id}" slot mismatch '
          '(${entry.value.slot.name} vs ${entry.key.name}).',
        );
      }
      collect(entry.value);
    }

    for (final stack in snapshot.inventory.stacks.entries) {
      if (stack.value < 0) {
        throw StateError(
          'Negative quantity (${stack.value}) for "${stack.key}".',
        );
      }
      if (!config.items.containsKey(stack.key)) {
        throw StateError('Unknown stack item "${stack.key}".');
      }
    }

    for (final currency in snapshot.currencies.entries) {
      final cid = currency.key.trim();
      if (cid.isEmpty) {
        throw StateError('Empty currency id in snapshot.');
      }
      if (currency.value < 0) {
        throw StateError(
          'Negative currency amount (${currency.value}) for "$cid".',
        );
      }
      if (config.currencies.isNotEmpty && !config.currencies.containsKey(cid)) {
        throw StateError('Unknown currency "$cid".');
      }
    }
    for (final q in snapshot.periodicQuestStates) {
      if (q.questId.trim().isEmpty || q.periodKey.trim().isEmpty) {
        throw StateError('Empty questId/periodKey in periodicQuestStates.');
      }
      if (q.completedAtMs < 0) {
        throw StateError(
          'Negative completedAtMs (${q.completedAtMs}) for quest "${q.questId}".',
        );
      }
    }
    for (final p in snapshot.eventShopPurchases) {
      if (p.entryId.trim().isEmpty || p.periodKey.trim().isEmpty) {
        throw StateError('Empty entryId/periodKey in eventShopPurchases.');
      }
      if (p.purchasedCount < 0) {
        throw StateError(
          'Negative purchasedCount (${p.purchasedCount}) for "${p.entryId}".',
        );
      }
    }

    final specId = snapshot.character.specializationId;
    if (specId != null &&
        !config.specializations.definitions.containsKey(specId)) {
      throw StateError('Unknown specialization "$specId".');
    }

    final rawLastNormalId = snapshot.cycleProgress.lastNormalDungeonId?.trim();
    final safeLastNormalId =
        (rawLastNormalId == null || rawLastNormalId.isEmpty)
        ? null
        : rawLastNormalId;
    if (safeLastNormalId != null && config.dungeons.isNotEmpty) {
      final def = config.dungeons[safeLastNormalId];
      if (def == null || !def.isNormal) {
        throw StateError(
          'Invalid lastNormalDungeonId "$safeLastNormalId" in CycleProgress.',
        );
      }
    }
    final safeAscensionRank = math.max(0, snapshot.cycleProgress.ascensionRank);
    final safeHighestAscensionRank = math.max(
      safeAscensionRank,
      snapshot.cycleProgress.highestAscensionRank,
    );

    return _PreparedSnapshotWrite(
      snapshot: snapshot,
      pid: pid,
      progress: progress,
      allEquipment: allEquipment,
      specId: specId,
      safeLastNormalId: safeLastNormalId,
      safeAscensionRank: safeAscensionRank,
      safeHighestAscensionRank: safeHighestAscensionRank,
    );
  }

  Future<void> _writePreparedSnapshot(
    _PreparedSnapshotWrite prepared, {
    required int savedAtMs,
    required int activeAtMs,
    required int lastOfflineClaimAtMs,
    required ClockState clockState,
    required bool deleteAllPlayerRowsFirst,
  }) async {
    final snapshot = prepared.snapshot;
    final pid = prepared.pid;
    final progress = prepared.progress;
    final specId = prepared.specId;
    final baseStats = config.progression.statsAt(progress.level);

    final prev = (!deleteAllPlayerRowsFirst && _lastSavedPid == pid)
        ? _lastSavedSnapshot
        : null;
    final prevEquipment = prev != null ? _lastSavedAllEquipment : null;

    final skillsChanged =
        prev == null ||
        prev.character.progress.level != progress.level ||
        prev.character.specializationId != specId ||
        !_intMapEquals(
          prev.character.skillLevels,
          snapshot.character.skillLevels,
        ) ||
        !_intMapEquals(
          prev.character.skillCooldownTicks,
          snapshot.character.skillCooldownTicks,
        );
    final stacksChanged =
        prev == null ||
        !_intMapEquals(prev.inventory.stacks, snapshot.inventory.stacks);
    final equipmentChanged =
        prev == null ||
        prevEquipment == null ||
        !_equipmentListEquals(prevEquipment, prepared.allEquipment);
    final equippedChanged =
        prev == null ||
        !_equippedMapEquals(
          prev.character.equipped,
          snapshot.character.equipped,
        );
    // Foreign key equippedItems -> equipmentInstances: jika equipmentInstances
    // ditulis ulang, equippedItems juga harus dihapus lebih dulu & ditulis ulang.
    final rewriteEquipped = equippedChanged || equipmentChanged;

    if (deleteAllPlayerRowsFirst) {
      // Hapus seluruh baris milik pemain (kecuali GameSettings, CloudSyncStates,
      // LocalSaveBackups) sebelum menulis ulang data terpulihkan.
      await (db.delete(
        db.equippedItems,
      )..where((t) => t.playerId.equals(pid))).go();
      await (db.delete(
        db.equipmentInstances,
      )..where((t) => t.playerId.equals(pid))).go();
      await (db.delete(
        db.inventoryEntries,
      )..where((t) => t.playerId.equals(pid))).go();
      await (db.delete(
        db.skillProgresses,
      )..where((t) => t.playerId.equals(pid))).go();
      await (db.delete(
        db.dungeonProgresses,
      )..where((t) => t.playerId.equals(pid))).go();
      await (db.delete(
        db.cycleProgresses,
      )..where((t) => t.playerId.equals(pid))).go();
      await (db.delete(
        db.gameSessions,
      )..where((t) => t.playerId.equals(pid))).go();
      await (db.delete(
        db.claimedRewards,
      )..where((t) => t.playerId.equals(pid))).go();
      await (db.delete(
        db.shopPurchases,
      )..where((t) => t.playerId.equals(pid))).go();
      await (db.delete(
        db.currencies,
      )..where((t) => t.playerId.equals(pid))).go();
      await (db.delete(
        db.clockStates,
      )..where((t) => t.playerId.equals(pid))).go();
      await (db.delete(
        db.periodicQuestStates,
      )..where((t) => t.playerId.equals(pid))).go();
      await (db.delete(
        db.eventShopPurchases,
      )..where((t) => t.playerId.equals(pid))).go();
      await db.delete(db.gachaPityStates).go();
      await db.delete(db.unlockedSpecializations).go();
      await (db.delete(
        db.infiniteSpireProgresses,
      )..where((t) => t.playerId.equals(pid))).go();
    } else {
      if (rewriteEquipped) {
        await (db.delete(
          db.equippedItems,
        )..where((t) => t.playerId.equals(pid))).go();
      }
      if (equipmentChanged) {
        await (db.delete(
          db.equipmentInstances,
        )..where((t) => t.playerId.equals(pid))).go();
      }
      if (stacksChanged) {
        await (db.delete(
          db.inventoryEntries,
        )..where((t) => t.playerId.equals(pid))).go();
      }
      if (skillsChanged) {
        await (db.delete(
          db.skillProgresses,
        )..where((t) => t.playerId.equals(pid))).go();
      }
    }

    await db
        .into(db.players)
        .insertOnConflictUpdate(
          PlayersCompanion.insert(
            id: pid,
            level: progress.level,
            currentExp: progress.currentExp,
            gold: progress.gold,
            ascensionPhase: Value(progress.ascensionPhase),
            currentHp: Value(snapshot.character.currentHp),
            activeSpecializationId: Value(specId),
            baseStatsJson: jsonEncode(_encodeCombatStats(baseStats)),
            equipmentCounter: Value(snapshot.inventory.equipmentCounter),
            lastSavedAtMs: savedAtMs,
          ),
        );

    if (skillsChanged && config.skills.isNotEmpty) {
      final skillRows = <SkillProgressesCompanion>[];
      for (final skill in config.skills.values) {
        final level = math.min(
          skill.maxLevel,
          math.max(1, snapshot.character.skillLevels[skill.id] ?? 1),
        );
        final unlocked =
            progress.level >= skill.unlockLevel &&
            (skill.specializationId == null ||
                skill.specializationId == specId);
        final cooldown = math.max(
          0,
          snapshot.character.skillCooldownTicks[skill.id] ?? 0,
        );
        skillRows.add(
          SkillProgressesCompanion.insert(
            playerId: pid,
            skillId: skill.id,
            skillLevel: level,
            unlocked: unlocked,
            cooldownTicksRemaining: Value(cooldown),
          ),
        );
      }
      await db.batch((b) => b.insertAll(db.skillProgresses, skillRows));
    }

    if (stacksChanged) {
      final stackRows = [
        for (final entry in snapshot.inventory.stacks.entries)
          if (entry.value > 0)
            InventoryEntriesCompanion.insert(
              playerId: pid,
              itemId: entry.key,
              quantity: entry.value,
            ),
      ];
      if (stackRows.isNotEmpty) {
        await db.batch((b) => b.insertAll(db.inventoryEntries, stackRows));
      }
    }

    if (equipmentChanged && prepared.allEquipment.isNotEmpty) {
      final instanceRows = [
        for (final item in prepared.allEquipment)
          EquipmentInstancesCompanion.insert(
            playerId: pid,
            instanceId: item.id,
            definitionId: item.definitionId,
            slot: item.slot.name,
            rarity: item.rarity.name,
            rolledStatsJson: jsonEncode(
              _encodeEquipmentStats(item.rolledStats),
            ),
            enhancementLevel: Value(item.enhancementLevel),
            isFavorite: Value(item.isFavorite),
          ),
      ];
      await db.batch((b) => b.insertAll(db.equipmentInstances, instanceRows));
    }

    if (rewriteEquipped && snapshot.character.equipped.isNotEmpty) {
      final equippedRows = [
        for (final entry in snapshot.character.equipped.entries)
          EquippedItemsCompanion.insert(
            playerId: pid,
            slot: entry.key.name,
            equipmentInstanceId: entry.value.id,
          ),
      ];
      await db.batch((b) => b.insertAll(db.equippedItems, equippedRows));
    }

    final allDungeonProgresses = <String, DungeonProgressSnapshot>{
      ...snapshot.dungeonProgresses,
      snapshot.dungeon.currentDungeonId: snapshot.dungeon,
    };
    final prevDungeons = prev == null
        ? null
        : <String, DungeonProgressSnapshot>{
            ...prev.dungeonProgresses,
            prev.dungeon.currentDungeonId: prev.dungeon,
          };
    final changedDungeons = [
      for (final dungeon in allDungeonProgresses.values)
        if (prevDungeons == null ||
            !_dungeonProgressEquals(
              prevDungeons[dungeon.currentDungeonId],
              dungeon,
            ))
          dungeon,
    ];
    if (changedDungeons.isNotEmpty) {
      await db.batch((b) {
        b.insertAllOnConflictUpdate(db.dungeonProgresses, [
          for (final dungeon in changedDungeons)
            DungeonProgressesCompanion.insert(
              playerId: pid,
              dungeonId: dungeon.currentDungeonId,
              currentRoomId: dungeon.currentRoomId,
              currentRoomIndex: math.max(0, dungeon.currentRoomIndex),
              highestClearedRoomIndex: math.max(
                -1,
                dungeon.highestClearedRoomIndex,
              ),
              clearsCount: math.max(0, dungeon.clearsCount),
              clearedInCycleRank: Value(
                math.max(-1, dungeon.clearedInCycleRank),
              ),
              rewardStateJson: Value(
                jsonEncode(_encodeRewardState(dungeon.rewardState)),
              ),
            ),
        ]);
      });
    }

    if (prev == null ||
        prev.cycleProgress.ascensionRank != prepared.safeAscensionRank ||
        prev.cycleProgress.highestAscensionRank !=
            prepared.safeHighestAscensionRank ||
        prev.cycleProgress.lastNormalDungeonId != prepared.safeLastNormalId) {
      await db
          .into(db.cycleProgresses)
          .insertOnConflictUpdate(
            CycleProgressesCompanion.insert(
              playerId: pid,
              ascensionRank: Value(prepared.safeAscensionRank),
              highestAscensionRank: Value(prepared.safeHighestAscensionRank),
              lastNormalDungeonId: Value(prepared.safeLastNormalId),
              updatedAtMs: savedAtMs,
            ),
          );
    }

    if (prev == null ||
        !_intMapEquals(prev.shopPurchases, snapshot.shopPurchases)) {
      final shopPurchaseRows = [
        for (final purchase in snapshot.shopPurchases.entries)
          if (purchase.key.trim().isNotEmpty && purchase.value >= 0)
            ShopPurchasesCompanion.insert(
              playerId: pid,
              entryId: purchase.key.trim(),
              purchasedCount: Value(purchase.value),
            ),
      ];
      if (shopPurchaseRows.isNotEmpty) {
        await db.batch(
          (b) =>
              b.insertAllOnConflictUpdate(db.shopPurchases, shopPurchaseRows),
        );
      }
    }

    if (prev == null || !_intMapEquals(prev.currencies, snapshot.currencies)) {
      await _replaceCurrencies(pid: pid, currencies: snapshot.currencies);
    }

    if (prev == null ||
        !_gachaPityMapEquals(prev.gachaPityStates, snapshot.gachaPityStates)) {
      final pityRows = [
        for (final pity in snapshot.gachaPityStates.values)
          GachaPityStatesCompanion.insert(
            bannerType: pity.bannerType,
            pullCount: Value(pity.pullCount),
            isGuaranteed: Value(pity.isGuaranteed),
          ),
      ];
      if (pityRows.isNotEmpty) {
        await db.batch(
          (b) => b.insertAllOnConflictUpdate(db.gachaPityStates, pityRows),
        );
      }
    }

    if (prev == null ||
        !_stringSetEquals(
          prev.unlockedSpecializations,
          snapshot.unlockedSpecializations,
        )) {
      final specRows = [
        for (final specId in snapshot.unlockedSpecializations)
          UnlockedSpecializationsCompanion.insert(
            specializationId: specId,
            unlockedAtMs: savedAtMs,
          ),
      ];
      if (specRows.isNotEmpty) {
        await db.batch(
          (b) =>
              b.insertAllOnConflictUpdate(db.unlockedSpecializations, specRows),
        );
      }
    }

    await db
        .into(db.gameSessions)
        .insertOnConflictUpdate(
          GameSessionsCompanion.insert(
            id: pid,
            playerId: pid,
            lastActiveAtMs: math.max(0, activeAtMs),
            lastSavedAtMs: math.max(0, savedAtMs),
            lastOfflineClaimAtMs: math.max(0, lastOfflineClaimAtMs),
            autoSkillEnabled: snapshot.session.autoSkillEnabled,
            sessionDataJson: Value(
              jsonEncode(
                _encodeSessionData(
                  active: snapshot.activeDungeonSession,
                  offlineActivity: snapshot.offlineActivity,
                  consecutiveDefeats: snapshot.session.consecutiveDefeats,
                  lastFailedDungeonId: snapshot.session.lastFailedDungeonId,
                ),
              ),
            ),
          ),
        );

    final newClaimedIds = prev == null
        ? snapshot.claimedEventIds
        : snapshot.claimedEventIds.difference(prev.claimedEventIds);
    if (newClaimedIds.isNotEmpty) {
      await db.batch((b) {
        b.insertAll(db.claimedRewards, [
          for (final eventId in newClaimedIds)
            ClaimedRewardsCompanion.insert(
              playerId: pid,
              eventId: eventId,
              claimedAtMs: savedAtMs,
            ),
        ], mode: InsertMode.insertOrIgnore);
      });
    }

    if (clockState.lastSeenAtMs > 0 ||
        clockState.forwardJumpCount > 0 ||
        clockState.maxForwardJumpMs > 0) {
      await db
          .into(db.clockStates)
          .insertOnConflictUpdate(
            ClockStatesCompanion.insert(
              playerId: pid,
              lastSeenAtMs: Value(math.max(0, clockState.lastSeenAtMs)),
              forwardJumpCount: Value(math.max(0, clockState.forwardJumpCount)),
              maxForwardJumpMs: Value(math.max(0, clockState.maxForwardJumpMs)),
            ),
          );
    }

    if (prev == null ||
        !_periodicQuestListEquals(
          prev.periodicQuestStates,
          snapshot.periodicQuestStates,
        )) {
      final periodicQuestRows = [
        for (final q in snapshot.periodicQuestStates)
          if (q.questId.trim().isNotEmpty && q.periodKey.trim().isNotEmpty)
            PeriodicQuestStatesCompanion.insert(
              playerId: pid,
              questId: q.questId.trim(),
              periodKey: q.periodKey.trim(),
              completedAtMs: math.max(0, q.completedAtMs),
            ),
      ];
      if (periodicQuestRows.isNotEmpty) {
        await db.batch(
          (b) => b.insertAllOnConflictUpdate(
            db.periodicQuestStates,
            periodicQuestRows,
          ),
        );
      }
    }

    if (prev == null ||
        !_eventShopListEquals(
          prev.eventShopPurchases,
          snapshot.eventShopPurchases,
        )) {
      final eventShopPurchaseRows = [
        for (final p in snapshot.eventShopPurchases)
          if (p.entryId.trim().isNotEmpty &&
              p.periodKey.trim().isNotEmpty &&
              p.purchasedCount >= 0)
            EventShopPurchasesCompanion.insert(
              playerId: pid,
              entryId: p.entryId.trim(),
              periodKey: p.periodKey.trim(),
              purchasedCount: Value(p.purchasedCount),
            ),
      ];
      if (eventShopPurchaseRows.isNotEmpty) {
        await db.batch(
          (b) => b.insertAllOnConflictUpdate(
            db.eventShopPurchases,
            eventShopPurchaseRows,
          ),
        );
      }
    }

    await db
        .into(db.infiniteSpireProgresses)
        .insertOnConflictUpdate(
          InfiniteSpireProgressesCompanion.insert(
            playerId: pid,
            highestFloorCleared: Value(
              snapshot.infiniteSpireProgress.highestFloorCleared,
            ),
            claimedRewardsBlob: Value(
              jsonEncode(
                snapshot.infiniteSpireProgress.claimedFloorRewards.toList()
                  ..sort(),
              ),
            ),
          ),
        );
  }

  @override
  Future<PlayerSaveSnapshot?>
  loadSnapshot() => PerfTracer.traceAsync('Drift.loadSnapshot', () async {
    return db.transaction(() async {
      final playerRow = await (db.select(
        db.players,
      )..where((t) => t.id.equals(playerId))).getSingleOrNull();
      if (playerRow == null) return null;

      final maxLvl =
          config.progression.maxLevel ?? ProgressionConfig.kTechnicalMaxLevel;
      final safeLevel = math.min(maxLvl, math.max(1, playerRow.level));
      if (safeLevel != playerRow.level) {
        _warn('Level ${playerRow.level} dijepit ke batas $safeLevel.');
      }
      final safeExp =
          (config.progression.maxLevel != null &&
              safeLevel >= config.progression.maxLevel!)
          ? 0
          : math.max(0, playerRow.currentExp);
      final safeGold = math.max(0, playerRow.gold);

      String? specId = playerRow.activeSpecializationId;
      if (specId != null) {
        final specExists = config.specializations.definitions.containsKey(
          specId,
        );
        final specUnlocked =
            safeLevel >= config.specializations.unlockLevelFor(specId);
        if (!specExists || !specUnlocked) {
          _warn(
            'Specialization "$specId" tidak valid/terkunci; direset ke null.',
          );
          specId = null;
        }
      }

      // Skills
      final skillRows = await (db.select(
        db.skillProgresses,
      )..where((t) => t.playerId.equals(playerId))).get();
      final skillLevels = <String, int>{};
      final skillCooldownTicks = <String, int>{};
      for (final row in skillRows) {
        final def = config.skills[row.skillId];
        if (def == null) {
          _warn(
            'Skill tersimpan "${row.skillId}" tidak ada di skills.json; diabaikan.',
          );
          continue;
        }
        skillLevels[row.skillId] = math.min(
          def.maxLevel,
          math.max(1, row.skillLevel),
        );
        if (row.cooldownTicksRemaining > 0) {
          skillCooldownTicks[row.skillId] = row.cooldownTicksRemaining;
        }
      }

      // Inventory stacks
      final stackRows = await (db.select(
        db.inventoryEntries,
      )..where((t) => t.playerId.equals(playerId))).get();
      final stacks = <String, int>{};
      for (final row in stackRows) {
        final def = config.items[row.itemId];
        if (def == null || def.isEquipment) {
          _warn(
            'Item stack "${row.itemId}" tidak dikenal/equipment; diabaikan.',
          );
          continue;
        }
        if (row.quantity <= 0) continue;
        stacks[row.itemId] = math.min(def.maxStack, row.quantity);
      }

      // Equipment instances & equipped pointers
      final instanceRows = await (db.select(
        db.equipmentInstances,
      )..where((t) => t.playerId.equals(playerId))).get();
      final instancesById = <String, EquipmentInstance>{};
      for (final row in instanceRows) {
        final def = config.items[row.definitionId];
        if (def == null || !def.isEquipment || def.equipment == null) {
          _warn(
            'Equipment "${row.instanceId}" merujuk item "${row.definitionId}" tidak valid; diabaikan.',
          );
          continue;
        }
        final slot = _parseSlot(row.slot) ?? def.equipment!.slot;
        if (slot != def.equipment!.slot) {
          _warn(
            'Slot "${row.slot}" pada "${row.instanceId}" tidak cocok definisi; memakai ${def.equipment!.slot.name}.',
          );
        }
        final rarity = _parseRarity(row.rarity) ?? def.rarity;
        final stats = _decodeEquipmentStats(
          row.rolledStatsJson,
          fallback: def.equipment!.baseStats,
          instanceId: row.instanceId,
        );
        instancesById[row.instanceId] = EquipmentInstance(
          id: row.instanceId,
          definitionId: row.definitionId,
          slot: def.equipment!.slot,
          rarity: rarity,
          rolledStats: stats,
          enhancementLevel: math.max(0, row.enhancementLevel),
          isFavorite: row.isFavorite,
        );
      }

      final equippedRows = await (db.select(
        db.equippedItems,
      )..where((t) => t.playerId.equals(playerId))).get();
      final equipped = <EquipmentSlot, EquipmentInstance>{};
      final equippedIds = <String>{};
      for (final row in equippedRows) {
        final slot = _parseSlot(row.slot);
        final instance = instancesById[row.equipmentInstanceId];
        if (slot == null || instance == null || instance.slot != slot) {
          _warn(
            'Referensi equipped "${row.equipmentInstanceId}" untuk slot "${row.slot}" tidak valid; dilepas.',
          );
          continue;
        }
        equipped[slot] = instance;
        equippedIds.add(instance.id);
      }

      final bagEquipment = [
        for (final entry in instancesById.entries)
          if (!equippedIds.contains(entry.key)) entry.value,
      ];

      final dungeonRows =
          await (db.select(db.dungeonProgresses)
                ..where((t) => t.playerId.equals(playerId))
                ..orderBy([(t) => OrderingTerm.asc(t.dungeonId)]))
              .get();
      final dungeonProgresses = <String, DungeonProgressSnapshot>{};
      for (final row in dungeonRows) {
        if (row.highestClearedRoomIndex < -1) {
          _warn(
            'highestClearedRoomIndex (${row.highestClearedRoomIndex}) '
            'pada "${row.dungeonId}" tidak valid; dijepit ke -1.',
          );
        }
        if (row.clearedInCycleRank < -1) {
          _warn(
            'clearedInCycleRank (${row.clearedInCycleRank}) '
            'pada "${row.dungeonId}" tidak valid; dijepit ke -1.',
          );
        }
        dungeonProgresses[row.dungeonId] = DungeonProgressSnapshot(
          currentDungeonId: row.dungeonId,
          currentRoomId: row.currentRoomId,
          currentRoomIndex: math.max(0, row.currentRoomIndex),
          highestClearedRoomIndex: math.max(-1, row.highestClearedRoomIndex),
          clearsCount: math.max(0, row.clearsCount),
          clearedInCycleRank: math.max(-1, row.clearedInCycleRank),
          rewardState: _decodeRewardState(row.rewardStateJson),
        );
      }

      final cycleRow = await (db.select(
        db.cycleProgresses,
      )..where((t) => t.playerId.equals(playerId))).getSingleOrNull();
      final CycleProgress cycleProgress;
      if (cycleRow == null) {
        cycleProgress = const CycleProgress();
      } else {
        if (cycleRow.ascensionRank < 0) {
          _warn(
            'ascensionRank negatif (${cycleRow.ascensionRank}); dijepit ke 0.',
          );
        }
        var lastNormalId = cycleRow.lastNormalDungeonId?.trim();
        if (lastNormalId != null && lastNormalId.isEmpty) {
          lastNormalId = null;
        }
        if (lastNormalId != null && config.dungeons.isNotEmpty) {
          final def = config.dungeons[lastNormalId];
          if (def == null || !def.isNormal) {
            _warn(
              'lastNormalDungeonId "$lastNormalId" tidak dikenal/bukan normal; '
              'direset ke null.',
            );
            lastNormalId = null;
          }
        }
        final safeRank = math.max(0, cycleRow.ascensionRank);
        final safeHighest = math.max(safeRank, cycleRow.highestAscensionRank);
        cycleProgress = CycleProgress(
          ascensionRank: safeRank,
          highestAscensionRank: safeHighest,
          lastNormalDungeonId: lastNormalId,
        );
      }

      final sessionRow = await (db.select(
        db.gameSessions,
      )..where((t) => t.id.equals(playerId))).getSingleOrNull();
      final decodedSessionData = sessionRow == null
          ? const (
              active: null,
              offlineActivity: OfflineActivitySnapshot.paused(),
              consecutiveDefeats: <String, int>{},
              lastFailedDungeonId: null,
            )
          : _decodeSessionData(sessionRow.sessionDataJson);
      final session = sessionRow == null
          ? GameSessionSnapshot(
              playerId: playerId,
              lastSavedAtMs: math.max(0, playerRow.lastSavedAtMs),
            )
          : GameSessionSnapshot(
              playerId: playerId,
              lastActiveAtMs: _sanitizeTimestampMs(
                sessionRow.lastActiveAtMs,
                field: 'lastActiveAtMs',
              ),
              lastSavedAtMs: _sanitizeTimestampMs(
                sessionRow.lastSavedAtMs,
                field: 'lastSavedAtMs',
              ),
              lastOfflineClaimAtMs: _sanitizeTimestampMs(
                sessionRow.lastOfflineClaimAtMs,
                field: 'lastOfflineClaimAtMs',
              ),
              autoSkillEnabled: sessionRow.autoSkillEnabled,
              consecutiveDefeats: decodedSessionData.consecutiveDefeats,
              lastFailedDungeonId: decodedSessionData.lastFailedDungeonId,
            );
      final activeDungeonSession = decodedSessionData.active;

      final DungeonProgressSnapshot primaryDungeon;
      if (activeDungeonSession != null &&
          dungeonProgresses.containsKey(activeDungeonSession.dungeonId)) {
        primaryDungeon = dungeonProgresses[activeDungeonSession.dungeonId]!;
      } else if (cycleProgress.lastNormalDungeonId != null &&
          dungeonProgresses.containsKey(cycleProgress.lastNormalDungeonId)) {
        primaryDungeon = dungeonProgresses[cycleProgress.lastNormalDungeonId]!;
      } else if (dungeonProgresses.isNotEmpty) {
        final orderedMatch =
            (config.dungeons.values.toList()
                  ..sort((a, b) => a.order.compareTo(b.order)))
                .where((d) => dungeonProgresses.containsKey(d.id))
                .firstOrNull;
        if (orderedMatch != null) {
          primaryDungeon = dungeonProgresses[orderedMatch.id]!;
        } else {
          final ranked = dungeonProgresses.values.toList()
            ..sort((a, b) {
              final clearCmp = b.clearsCount.compareTo(a.clearsCount);
              if (clearCmp != 0) return clearCmp;
              return b.highestClearedRoomIndex.compareTo(
                a.highestClearedRoomIndex,
              );
            });
          primaryDungeon = ranked.first;
        }
      } else if (config.dungeons.isNotEmpty) {
        final orderedFirst =
            (config.dungeons.values.toList()
                  ..sort((a, b) => a.order.compareTo(b.order)))
                .first;
        primaryDungeon = DungeonProgressSnapshot(
          currentDungeonId: orderedFirst.id,
          currentRoomId: orderedFirst.startRoomId,
        );
      } else {
        primaryDungeon = const DungeonProgressSnapshot();
      }

      int? safeCurrentHp = playerRow.currentHp;
      if (safeCurrentHp != null && safeCurrentHp < 0) {
        _warn('currentHp negatif ($safeCurrentHp); dijepit ke 0.');
        safeCurrentHp = 0;
      }

      final claimedRows = await (db.select(
        db.claimedRewards,
      )..where((t) => t.playerId.equals(playerId))).get();
      final claimedIds = {for (final r in claimedRows) r.eventId};

      final shopPurchaseRows = await (db.select(
        db.shopPurchases,
      )..where((t) => t.playerId.equals(playerId))).get();
      final shopPurchases = <String, int>{
        for (final r in shopPurchaseRows)
          if (r.purchasedCount > 0) r.entryId: r.purchasedCount,
      };

      final currencyRows = await (db.select(
        db.currencies,
      )..where((t) => t.playerId.equals(playerId))).get();
      final currencies = <String, int>{};
      for (final r in currencyRows) {
        if (r.amount < 0) {
          _warn(
            'Saldo currency "${r.currencyId}" negatif (${r.amount}); dijepit ke 0.',
          );
          continue;
        }
        if (r.amount > 0) {
          final maxAmount = config.currencies[r.currencyId]?.maxAmount;
          currencies[r.currencyId] = maxAmount != null
              ? math.min(r.amount, maxAmount)
              : r.amount;
        }
      }

      final clockRow = await (db.select(
        db.clockStates,
      )..where((t) => t.playerId.equals(playerId))).getSingleOrNull();
      final clockState = clockRow == null
          ? const ClockState()
          : ClockState(
              lastSeenAtMs: math.max(0, clockRow.lastSeenAtMs),
              forwardJumpCount: math.max(0, clockRow.forwardJumpCount),
              maxForwardJumpMs: math.max(0, clockRow.maxForwardJumpMs),
            );

      final questRows = await (db.select(
        db.periodicQuestStates,
      )..where((t) => t.playerId.equals(playerId))).get();
      final periodicQuestStates = <PeriodicQuestState>[
        for (final r in questRows)
          if (r.questId.trim().isNotEmpty && r.periodKey.trim().isNotEmpty)
            PeriodicQuestState(
              questId: r.questId.trim(),
              periodKey: r.periodKey.trim(),
              completedAtMs: math.max(0, r.completedAtMs),
            ),
      ];

      final eventPurchaseRows = await (db.select(
        db.eventShopPurchases,
      )..where((t) => t.playerId.equals(playerId))).get();
      final eventShopPurchases = <EventShopPurchaseRecord>[
        for (final r in eventPurchaseRows)
          if (r.entryId.trim().isNotEmpty &&
              r.periodKey.trim().isNotEmpty &&
              r.purchasedCount > 0)
            EventShopPurchaseRecord(
              entryId: r.entryId.trim(),
              periodKey: r.periodKey.trim(),
              purchasedCount: r.purchasedCount,
            ),
      ];

      final pityRows = await db.select(db.gachaPityStates).get();
      final gachaPityStates = <String, GachaPityState>{
        for (final r in pityRows)
          r.bannerType: GachaPityState(
            bannerType: r.bannerType,
            pullCount: math.max(0, r.pullCount),
            isGuaranteed: r.isGuaranteed,
          ),
      };

      final unlockedSpecRows = await db
          .select(db.unlockedSpecializations)
          .get();
      final unlockedSpecializations = <String>{
        for (final r in unlockedSpecRows)
          if (r.specializationId.trim().isNotEmpty) r.specializationId.trim(),
      };
      if (unlockedSpecializations.isEmpty) {
        unlockedSpecializations.addAll(['vanguard', 'arcanist', 'ranger']);
      }

      final spireRow = await (db.select(
        db.infiniteSpireProgresses,
      )..where((t) => t.playerId.equals(playerId))).getSingleOrNull();
      final InfiniteSpireProgressSnapshot infiniteSpire;
      if (spireRow != null) {
        Set<int> claimed = {};
        try {
          final decoded = jsonDecode(spireRow.claimedRewardsBlob);
          if (decoded is List) {
            claimed = decoded.map((e) => (e as num).toInt()).toSet();
          }
        } catch (_) {}
        infiniteSpire = InfiniteSpireProgressSnapshot(
          highestFloorCleared: math.max(0, spireRow.highestFloorCleared),
          claimedFloorRewards: claimed,
        );
      } else {
        infiniteSpire = const InfiniteSpireProgressSnapshot();
      }

      final loaded = PlayerSaveSnapshot(
        playerId: playerId,
        character: PlayerCharacterSnapshot(
          progress: PlayerProgress(
            level: safeLevel,
            currentExp: safeExp,
            gold: safeGold,
            ascensionPhase: playerRow.ascensionPhase,
          ),
          specializationId: specId,
          skillLevels: skillLevels,
          skillCooldownTicks: skillCooldownTicks,
          equipped: equipped,
          currentHp: safeCurrentHp,
        ),
        inventory: InventorySnapshot(
          stacks: stacks,
          equipment: bagEquipment,
          equipmentCounter: math.max(0, playerRow.equipmentCounter),
        ),
        dungeon: primaryDungeon,
        dungeonProgresses: Map.unmodifiable(dungeonProgresses),
        cycleProgress: cycleProgress,
        session: session,
        claimedEventIds: claimedIds,
        activeDungeonSession: activeDungeonSession,
        offlineActivity: decodedSessionData.offlineActivity,
        shopPurchases: Map.unmodifiable(shopPurchases),
        eventShopPurchases: List<EventShopPurchaseRecord>.unmodifiable(
          eventShopPurchases,
        ),
        currencies: Map.unmodifiable(currencies),
        clockState: clockState,
        periodicQuestStates: List<PeriodicQuestState>.unmodifiable(
          periodicQuestStates,
        ),
        gachaPityStates: Map.unmodifiable(gachaPityStates),
        unlockedSpecializations: Set.unmodifiable(unlockedSpecializations),
        infiniteSpireProgress: infiniteSpire,
      );
      _recordSavedBaseline(loaded, [
        ...loaded.character.equipped.values,
        ...loaded.inventory.equipment,
      ], playerId);
      return loaded;
    });
  });

  // ---- CycleProgressRepository (siklus Ascension & transisi atomik) ----

  @override
  Future<CycleProgress> loadCycleProgress() async {
    final row = await (db.select(
      db.cycleProgresses,
    )..where((t) => t.playerId.equals(playerId))).getSingleOrNull();
    if (row == null) return const CycleProgress();
    return _sanitizeCycleProgress(
      row.ascensionRank,
      row.lastNormalDungeonId,
      rawHighestRank: row.highestAscensionRank,
    );
  }

  @override
  Future<void> saveCycleProgress(CycleProgress cycleProgress) async {
    _invalidateSaveDiffCache();
    final sanitized = _sanitizeCycleProgress(
      cycleProgress.ascensionRank,
      cycleProgress.lastNormalDungeonId,
      rawHighestRank: cycleProgress.highestAscensionRank,
    );
    final nowMs = math.max(0, clock.nowMs);
    await db.transaction(() async {
      await _ensurePlayerRowExists(nowMs);
      await db
          .into(db.cycleProgresses)
          .insertOnConflictUpdate(
            CycleProgressesCompanion.insert(
              playerId: playerId,
              ascensionRank: Value(sanitized.ascensionRank),
              highestAscensionRank: Value(sanitized.highestAscensionRank),
              lastNormalDungeonId: Value(sanitized.lastNormalDungeonId),
              updatedAtMs: nowMs,
            ),
          );
    });
  }

  @override
  Future<void> saveCycleTransition({
    required CycleProgress cycleProgress,
    required Map<String, DungeonProgressSnapshot> dungeonProgresses,
    String? claimEventId,
    int? updatedAtMs,
  }) async {
    _invalidateSaveDiffCache();
    final sanitized = _sanitizeCycleProgress(
      cycleProgress.ascensionRank,
      cycleProgress.lastNormalDungeonId,
      rawHighestRank: cycleProgress.highestAscensionRank,
    );
    final safeUpdatedAtMs = math.max(0, updatedAtMs ?? clock.nowMs);
    final normalizedClaimId = claimEventId?.trim();

    await db.transaction(() async {
      await _ensurePlayerRowExists(safeUpdatedAtMs);

      await db
          .into(db.cycleProgresses)
          .insertOnConflictUpdate(
            CycleProgressesCompanion.insert(
              playerId: playerId,
              ascensionRank: Value(sanitized.ascensionRank),
              highestAscensionRank: Value(sanitized.highestAscensionRank),
              lastNormalDungeonId: Value(sanitized.lastNormalDungeonId),
              updatedAtMs: safeUpdatedAtMs,
            ),
          );

      for (final entry in dungeonProgresses.entries) {
        final dSnapshot = entry.value;
        await db
            .into(db.dungeonProgresses)
            .insertOnConflictUpdate(
              DungeonProgressesCompanion.insert(
                playerId: playerId,
                dungeonId: entry.key,
                currentRoomId: dSnapshot.currentRoomId,
                currentRoomIndex: math.max(0, dSnapshot.currentRoomIndex),
                highestClearedRoomIndex: dSnapshot.highestClearedRoomIndex,
                clearsCount: math.max(0, dSnapshot.clearsCount),
                clearedInCycleRank: Value(
                  dSnapshot.clearedInCycleRank < 0
                      ? -1
                      : dSnapshot.clearedInCycleRank,
                ),
                rewardStateJson: Value(
                  jsonEncode(_encodeRewardState(dSnapshot.rewardState)),
                ),
              ),
            );
      }

      if (normalizedClaimId != null && normalizedClaimId.isNotEmpty) {
        await db
            .into(db.claimedRewards)
            .insert(
              ClaimedRewardsCompanion.insert(
                playerId: playerId,
                eventId: normalizedClaimId,
                claimedAtMs: safeUpdatedAtMs,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  // ---- ShopPurchaseRepository (transaksi beli/jual atomik) ----

  @override
  Future<Map<String, int>> loadShopPurchases() async {
    final rows = await (db.select(
      db.shopPurchases,
    )..where((t) => t.playerId.equals(playerId))).get();
    return Map<String, int>.unmodifiable({
      for (final row in rows)
        if (row.purchasedCount > 0) row.entryId: row.purchasedCount,
    });
  }

  @override
  Future<void> saveShopTransaction({
    required PlayerProgress progress,
    required InventorySnapshot inventory,
    required Map<EquipmentSlot, EquipmentInstance> equipped,
    required Map<String, int> shopPurchases,
    String? actionId,
    int? updatedAtMs,
  }) async {
    _invalidateSaveDiffCache();
    _validateProgress(progress);
    final allEquipment = _collectAndValidateEquipment(
      bagEquipment: inventory.equipment,
      equipped: equipped,
      stacks: inventory.stacks,
    );
    final safeUpdatedAtMs = math.max(0, updatedAtMs ?? clock.nowMs);
    final normalizedActionId = actionId?.trim();
    final claimKey =
        (normalizedActionId != null && normalizedActionId.isNotEmpty)
        ? 'shop:$normalizedActionId'
        : null;

    await db.transaction(() async {
      await _ensurePlayerRowExists(safeUpdatedAtMs);

      if (claimKey != null) {
        final existingClaim =
            await (db.select(db.claimedRewards)..where(
                  (t) =>
                      t.playerId.equals(playerId) & t.eventId.equals(claimKey),
                ))
                .getSingleOrNull();
        if (existingClaim != null) {
          return;
        }
        await db
            .into(db.claimedRewards)
            .insert(
              ClaimedRewardsCompanion.insert(
                playerId: playerId,
                eventId: claimKey,
                claimedAtMs: safeUpdatedAtMs,
              ),
            );
      }

      await (db.update(db.players)..where((t) => t.id.equals(playerId))).write(
        PlayersCompanion(
          level: Value(progress.level),
          currentExp: Value(progress.currentExp),
          gold: Value(progress.gold),
          equipmentCounter: Value(math.max(0, inventory.equipmentCounter)),
          lastSavedAtMs: Value(safeUpdatedAtMs),
        ),
      );

      await _replaceInventoryAndEquipmentRows(
        pid: playerId,
        stacks: inventory.stacks,
        allEquipment: allEquipment,
        equipped: equipped,
      );

      for (final entry in shopPurchases.entries) {
        final entryId = entry.key.trim();
        if (entryId.isEmpty || entry.value < 0) continue;
        await db
            .into(db.shopPurchases)
            .insertOnConflictUpdate(
              ShopPurchasesCompanion.insert(
                playerId: playerId,
                entryId: entryId,
                purchasedCount: Value(entry.value),
              ),
            );
      }
    });
  }

  // ---- EventShopPurchaseRepository (pembelian Event Shop atomik) ----

  @override
  Future<List<EventShopPurchaseRecord>> loadEventShopPurchases() async {
    final rows = await (db.select(
      db.eventShopPurchases,
    )..where((t) => t.playerId.equals(playerId))).get();
    return List<EventShopPurchaseRecord>.unmodifiable([
      for (final row in rows)
        if (row.entryId.trim().isNotEmpty &&
            row.periodKey.trim().isNotEmpty &&
            row.purchasedCount > 0)
          EventShopPurchaseRecord(
            entryId: row.entryId.trim(),
            periodKey: row.periodKey.trim(),
            purchasedCount: row.purchasedCount,
          ),
    ]);
  }

  @override
  Future<void> saveEventShopTransaction({
    required PlayerProgress progress,
    required InventorySnapshot inventory,
    required Map<EquipmentSlot, EquipmentInstance> equipped,
    required Map<String, int> currencies,
    required EventShopPurchaseRecord purchase,
    String? actionId,
    int? updatedAtMs,
  }) async {
    _invalidateSaveDiffCache();
    _validateProgress(progress);
    final entryId = purchase.entryId.trim();
    final periodKey = purchase.periodKey.trim();
    if (entryId.isEmpty || periodKey.isEmpty || purchase.purchasedCount < 0) {
      throw StateError('Data EventShopPurchaseRecord tidak valid.');
    }
    for (final c in currencies.entries) {
      final cid = c.key.trim();
      if (cid.isEmpty || c.value < 0) {
        throw StateError('Saldo currency "$cid" tidak valid (${c.value}).');
      }
      if (config.currencies.isNotEmpty && !config.currencies.containsKey(cid)) {
        throw StateError('Unknown currency "$cid".');
      }
    }
    final allEquipment = _collectAndValidateEquipment(
      bagEquipment: inventory.equipment,
      equipped: equipped,
      stacks: inventory.stacks,
    );
    final safeUpdatedAtMs = math.max(0, updatedAtMs ?? clock.nowMs);
    final normalizedActionId = actionId?.trim();
    final claimKey =
        (normalizedActionId != null && normalizedActionId.isNotEmpty)
        ? 'eventshop:$normalizedActionId:$periodKey'
        : null;

    await db.transaction(() async {
      await _ensurePlayerRowExists(safeUpdatedAtMs);

      if (claimKey != null) {
        final existingClaim =
            await (db.select(db.claimedRewards)..where(
                  (t) =>
                      t.playerId.equals(playerId) & t.eventId.equals(claimKey),
                ))
                .getSingleOrNull();
        if (existingClaim != null) {
          return;
        }
        await db
            .into(db.claimedRewards)
            .insert(
              ClaimedRewardsCompanion.insert(
                playerId: playerId,
                eventId: claimKey,
                claimedAtMs: safeUpdatedAtMs,
              ),
            );
      }

      await (db.update(db.players)..where((t) => t.id.equals(playerId))).write(
        PlayersCompanion(
          gold: Value(progress.gold),
          equipmentCounter: Value(math.max(0, inventory.equipmentCounter)),
          lastSavedAtMs: Value(safeUpdatedAtMs),
        ),
      );

      await _replaceInventoryAndEquipmentRows(
        pid: playerId,
        stacks: inventory.stacks,
        allEquipment: allEquipment,
        equipped: equipped,
      );

      await _replaceCurrencies(pid: playerId, currencies: currencies);

      await db
          .into(db.eventShopPurchases)
          .insertOnConflictUpdate(
            EventShopPurchasesCompanion.insert(
              playerId: playerId,
              entryId: entryId,
              periodKey: periodKey,
              purchasedCount: Value(purchase.purchasedCount),
            ),
          );
    });
  }

  Future<void> _replaceCurrencies({
    required String pid,
    required Map<String, int> currencies,
  }) async {
    await (db.delete(db.currencies)..where((t) => t.playerId.equals(pid))).go();
    for (final currency in currencies.entries) {
      final cid = currency.key.trim();
      if (cid.isEmpty || currency.value <= 0) continue;
      final maxAmount = config.currencies[cid]?.maxAmount;
      final clamped = maxAmount != null
          ? math.min(currency.value, maxAmount)
          : currency.value;
      if (clamped <= 0) continue;
      await db
          .into(db.currencies)
          .insertOnConflictUpdate(
            CurrenciesCompanion.insert(
              playerId: pid,
              currencyId: cid,
              amount: Value(clamped),
            ),
          );
    }
  }

  // ---- ClockStateRepository & ClaimedRewardsPruningRepository ----

  @override
  Future<ClockState> loadClockState() async {
    final row = await (db.select(
      db.clockStates,
    )..where((t) => t.playerId.equals(playerId))).getSingleOrNull();
    if (row == null) return const ClockState();
    return ClockState(
      lastSeenAtMs: math.max(0, row.lastSeenAtMs),
      forwardJumpCount: math.max(0, row.forwardJumpCount),
      maxForwardJumpMs: math.max(0, row.maxForwardJumpMs),
    );
  }

  @override
  Future<void> saveClockState(ClockState state) async {
    _invalidateSaveDiffCache();
    final safeLastSeen = math.max(0, state.lastSeenAtMs);
    await db.transaction(() async {
      await _ensurePlayerRowExists(safeLastSeen);
      await db
          .into(db.clockStates)
          .insertOnConflictUpdate(
            ClockStatesCompanion.insert(
              playerId: playerId,
              lastSeenAtMs: Value(safeLastSeen),
              forwardJumpCount: Value(math.max(0, state.forwardJumpCount)),
              maxForwardJumpMs: Value(math.max(0, state.maxForwardJumpMs)),
            ),
          );
    });
  }

  @override
  Future<int> pruneClaimedRewards({
    required int cutoffMs,
    String? activeRunId,
    Set<String> activePeriodKeys = const {},
  }) async {
    _invalidateSaveDiffCache();
    const pruner = ClaimedRewardsPruner();
    final candidates =
        await (db.select(db.claimedRewards)..where(
              (t) =>
                  t.playerId.equals(playerId) &
                  t.claimedAtMs.isSmallerThanValue(cutoffMs),
            ))
            .get();
    final toDelete = <String>[
      for (final row in candidates)
        if (pruner.shouldPrune(
          eventId: row.eventId,
          claimedAtMs: row.claimedAtMs,
          cutoffMs: cutoffMs,
          activeRunId: activeRunId,
          activePeriodKeys: activePeriodKeys,
        ))
          row.eventId,
    ];
    if (toDelete.isEmpty) return 0;

    const batchSize = 500;
    await db.transaction(() async {
      for (var i = 0; i < toDelete.length; i += batchSize) {
        final end = math.min(i + batchSize, toDelete.length);
        final chunk = toDelete.sublist(i, end);
        await (db.delete(db.claimedRewards)..where(
              (t) => t.playerId.equals(playerId) & t.eventId.isIn(chunk),
            ))
            .go();
      }
    });
    return toDelete.length;
  }

  List<EquipmentInstance> _collectAndValidateEquipment({
    required List<EquipmentInstance> bagEquipment,
    required Map<EquipmentSlot, EquipmentInstance> equipped,
    required Map<String, int> stacks,
  }) {
    final allEquipment = <EquipmentInstance>[];
    final seenIds = <String>{};
    void collect(EquipmentInstance item) {
      if (!seenIds.add(item.id)) {
        throw StateError('Duplicate equipment instance id "${item.id}".');
      }
      if (!config.items.containsKey(item.definitionId)) {
        throw StateError(
          'Unknown item definition "${item.definitionId}" on "${item.id}".',
        );
      }
      allEquipment.add(item);
    }

    for (final item in bagEquipment) {
      collect(item);
    }
    for (final entry in equipped.entries) {
      if (entry.value.slot != entry.key) {
        throw StateError(
          'Equipment "${entry.value.id}" slot mismatch '
          '(${entry.value.slot.name} vs ${entry.key.name}).',
        );
      }
      collect(entry.value);
    }

    for (final stack in stacks.entries) {
      if (stack.value < 0) {
        throw StateError(
          'Negative quantity (${stack.value}) for "${stack.key}".',
        );
      }
      if (!config.items.containsKey(stack.key)) {
        throw StateError('Unknown stack item "${stack.key}".');
      }
    }
    return allEquipment;
  }

  Future<void> _replaceInventoryAndEquipmentRows({
    required String pid,
    required Map<String, int> stacks,
    required List<EquipmentInstance> allEquipment,
    required Map<EquipmentSlot, EquipmentInstance> equipped,
  }) async {
    await (db.delete(
      db.equippedItems,
    )..where((t) => t.playerId.equals(pid))).go();
    await (db.delete(
      db.equipmentInstances,
    )..where((t) => t.playerId.equals(pid))).go();
    await (db.delete(
      db.inventoryEntries,
    )..where((t) => t.playerId.equals(pid))).go();

    final stackRows = [
      for (final entry in stacks.entries)
        if (entry.value > 0)
          InventoryEntriesCompanion.insert(
            playerId: pid,
            itemId: entry.key,
            quantity: entry.value,
          ),
    ];
    if (stackRows.isNotEmpty) {
      await db.batch((b) => b.insertAll(db.inventoryEntries, stackRows));
    }

    if (allEquipment.isNotEmpty) {
      final instanceRows = [
        for (final item in allEquipment)
          EquipmentInstancesCompanion.insert(
            playerId: pid,
            instanceId: item.id,
            definitionId: item.definitionId,
            slot: item.slot.name,
            rarity: item.rarity.name,
            rolledStatsJson: jsonEncode(
              _encodeEquipmentStats(item.rolledStats),
            ),
            enhancementLevel: Value(item.enhancementLevel),
            isFavorite: Value(item.isFavorite),
          ),
      ];
      await db.batch((b) => b.insertAll(db.equipmentInstances, instanceRows));
    }

    if (equipped.isNotEmpty) {
      final equippedRows = [
        for (final entry in equipped.entries)
          EquippedItemsCompanion.insert(
            playerId: pid,
            slot: entry.key.name,
            equipmentInstanceId: entry.value.id,
          ),
      ];
      await db.batch((b) => b.insertAll(db.equippedItems, equippedRows));
    }
  }

  Future<void> _ensurePlayerRowExists(int savedAtMs) async {
    final existing = await (db.select(
      db.players,
    )..where((t) => t.id.equals(playerId))).getSingleOrNull();
    if (existing != null) return;
    final baseStats = config.progression.statsAt(1);
    await db
        .into(db.players)
        .insert(
          PlayersCompanion.insert(
            id: playerId,
            level: 1,
            currentExp: 0,
            gold: 0,
            baseStatsJson: jsonEncode(_encodeCombatStats(baseStats)),
            lastSavedAtMs: savedAtMs,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  CycleProgress _sanitizeCycleProgress(
    int rawRank,
    String? rawLastNormalDungeonId, {
    int? rawHighestRank,
  }) {
    var safeRank = rawRank;
    if (safeRank < 0) {
      _warn('ascensionRank negatif ($safeRank); dijepit ke 0.');
      safeRank = 0;
    }
    final safeHighest = math.max(safeRank, rawHighestRank ?? safeRank);

    var safeLastNormalId = rawLastNormalDungeonId?.trim();
    if (safeLastNormalId != null && safeLastNormalId.isEmpty) {
      safeLastNormalId = null;
    }
    if (safeLastNormalId != null && config.dungeons.isNotEmpty) {
      final def = config.dungeons[safeLastNormalId];
      if (def == null || !def.isNormal) {
        _warn(
          'lastNormalDungeonId "$safeLastNormalId" tidak valid/bukan normal; '
          'diabaikan.',
        );
        safeLastNormalId = null;
      }
    }

    return CycleProgress(
      ascensionRank: safeRank,
      highestAscensionRank: safeHighest,
      lastNormalDungeonId: safeLastNormalId,
    );
  }

  void _validateProgress(PlayerProgress progress) {
    if (progress.level < 1) {
      throw ArgumentError.value(progress.level, 'level', 'harus >= 1');
    }
    if (progress.currentExp < 0) {
      throw ArgumentError.value(
        progress.currentExp,
        'currentExp',
        'harus >= 0',
      );
    }
    if (progress.gold < 0) {
      throw ArgumentError.value(progress.gold, 'gold', 'harus >= 0');
    }
  }

  EquipmentSlot? _parseSlot(String raw) {
    for (final v in EquipmentSlot.values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  ItemRarity? _parseRarity(String raw) {
    for (final v in ItemRarity.values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  Map<String, dynamic> _encodeCombatStats(CombatStats s) => {
    'maxHp': s.maxHp,
    'atk': s.atk,
    'def': s.def,
    'attackSpeed': s.attackSpeed,
    'critRate': s.critRate,
    'critDamage': s.critDamage,
    'moveSpeed': s.moveSpeed,
    'attackRange': s.attackRange,
    'skillHaste': s.skillHaste,
    'lifesteal': s.lifesteal,
    'spellVamp': s.spellVamp,
  };

  Map<String, dynamic> _encodeEquipmentStats(EquipmentStats s) => {
    'hp': s.hp,
    'atk': s.atk,
    'def': s.def,
    'hpPct': s.hpPct,
    'atkPct': s.atkPct,
    'defPct': s.defPct,
    'critRate': s.critRate,
    'critDamage': s.critDamage,
    'attackSpeed': s.attackSpeed,
    'moveSpeed': s.moveSpeed,
    'attackRange': s.attackRange,
    'skillHaste': s.skillHaste,
    'lifesteal': s.lifesteal,
    'spellVamp': s.spellVamp,
  };

  EquipmentStats _decodeEquipmentStats(
    String raw, {
    required EquipmentStats fallback,
    required String instanceId,
  }) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) {
        _warn('Stats JSON tidak valid pada "$instanceId"; memakai stat dasar.');
        return fallback;
      }
      double numOr(String key, double def) {
        final v = map[key];
        return v is num && v.isFinite ? v.toDouble() : def;
      }

      return EquipmentStats(
        hp: numOr('hp', 0),
        atk: numOr('atk', 0),
        def: numOr('def', 0),
        hpPct: numOr('hpPct', 0),
        atkPct: numOr('atkPct', 0),
        defPct: numOr('defPct', 0),
        critRate: numOr('critRate', 0),
        critDamage: numOr('critDamage', 0),
        attackSpeed: numOr('attackSpeed', 0),
        moveSpeed: numOr('moveSpeed', 0),
        attackRange: numOr('attackRange', 0),
        skillHaste: numOr('skillHaste', 0),
        lifesteal: numOr('lifesteal', 0),
        spellVamp: numOr('spellVamp', 0),
      );
    } on FormatException {
      _warn('Stats JSON rusak pada "$instanceId"; memakai stat dasar.');
      return fallback;
    }
  }

  Map<String, dynamic> _encodeRewardState(DungeonRewardStateSnapshot state) => {
    'lastRunId': state.lastRunId,
    'completionRewardClaimed': state.completionRewardClaimed,
    'claimedRoomRewardIds': state.claimedRoomRewardIds.toList()..sort(),
  };

  DungeonRewardStateSnapshot _decodeRewardState(String raw) {
    if (raw.trim().isEmpty || raw.trim() == '{}') {
      return const DungeonRewardStateSnapshot();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _warn('rewardStateJson bukan objek JSON; memakai default.');
        return const DungeonRewardStateSnapshot();
      }
      final lastRunId = decoded['lastRunId'];
      final claimed = decoded['completionRewardClaimed'];
      final rawRooms = decoded['claimedRoomRewardIds'];
      final claimedRooms = <String>{};
      if (rawRooms is List) {
        for (final entry in rawRooms) {
          if (entry is String && entry.isNotEmpty) {
            claimedRooms.add(entry);
          }
        }
      }
      return DungeonRewardStateSnapshot(
        lastRunId: lastRunId is String && lastRunId.isNotEmpty
            ? lastRunId
            : null,
        completionRewardClaimed: claimed is bool ? claimed : false,
        claimedRoomRewardIds: Set.unmodifiable(claimedRooms),
      );
    } on FormatException {
      _warn('rewardStateJson rusak; memakai default.');
      return const DungeonRewardStateSnapshot();
    }
  }

  int _sanitizeTimestampMs(int raw, {required String field}) {
    if (raw < 0) {
      _warn('$field negatif ($raw); dijepit ke 0.');
      return 0;
    }
    return raw;
  }

  T? _parseEnum<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) return null;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  Map<String, dynamic> _encodeSessionData({
    ActiveDungeonSessionSnapshot? active,
    OfflineActivitySnapshot offlineActivity =
        const OfflineActivitySnapshot.paused(),
    Map<String, int> consecutiveDefeats = const {},
    String? lastFailedDungeonId,
  }) {
    final root = <String, dynamic>{};
    if (active != null) {
      root['activeDungeonSession'] = {
        'runId': active.runId,
        'dungeonId': active.dungeonId,
        'currentRoomId': active.currentRoomId,
        'currentRoomIndex': active.currentRoomIndex,
        'status': active.status.name,
        'clearedRoomIds': active.clearedRoomIds.toList()..sort(),
        'completionRewardClaimed': active.completionRewardClaimed,
        'reviveCooldownTicks': math.max(0, active.reviveCooldownTicks),
        'playerStatus': active.playerStatus.name,
        'cycleRank': math.max(0, active.cycleRank),
        if (active.bossEventId != null && active.bossEventId!.trim().isNotEmpty)
          'bossEventId': active.bossEventId!.trim(),
        if (active.periodKeyAtStart != null &&
            active.periodKeyAtStart!.trim().isNotEmpty)
          'periodKeyAtStart': active.periodKeyAtStart!.trim(),
      };
    }

    final hasOfflineData =
        !offlineActivity.isPaused ||
        offlineActivity.state != OfflineActivityState.inactive ||
        offlineActivity.lastCheckpointAtMs > 0 ||
        offlineActivity.processedOfflineDurationMs > 0 ||
        offlineActivity.pendingSummary != null;
    if (hasOfflineData) {
      root['offlineActivity'] = _encodeOfflineActivity(offlineActivity);
    }

    final validDefeats = <String, int>{
      for (final entry in consecutiveDefeats.entries)
        if (entry.key.trim().isNotEmpty && entry.value > 0)
          entry.key.trim(): entry.value,
    };
    if (validDefeats.isNotEmpty) {
      root['consecutiveDefeats'] = validDefeats;
    }

    final normalizedFailedId = lastFailedDungeonId?.trim();
    if (normalizedFailedId != null && normalizedFailedId.isNotEmpty) {
      root['lastFailedDungeonId'] = normalizedFailedId;
    }
    return root;
  }

  Map<String, dynamic> _encodeOfflineActivity(OfflineActivitySnapshot a) => {
    'mode': a.mode.name,
    'state': a.state.name,
    if (a.selectedDungeonId != null) 'selectedDungeonId': a.selectedDungeonId,
    if (a.activeRunId != null) 'activeRunId': a.activeRunId,
    'lastCheckpointAtMs': math.max(0, a.lastCheckpointAtMs),
    'processedOfflineDurationMs': math.max(0, a.processedOfflineDurationMs),
    if (a.simulationSeed != null) 'simulationSeed': a.simulationSeed,
    'failurePolicy': a.failurePolicy.name,
    if (a.pendingSummary != null)
      'pendingSummary': _encodeOfflineSummary(a.pendingSummary!),
  };

  Map<String, dynamic> _encodeOfflineSummary(OfflineSummarySnapshot s) => {
    'eventId': s.eventId,
    'mode': s.mode.name,
    'finalState': s.finalState.name,
    'effectiveElapsedMs': math.max(0, s.effectiveElapsedMs),
    'cappedAtMaxDuration': s.cappedAtMaxDuration,
    'runsAttempted': math.max(0, s.runsAttempted),
    'runsCompleted': math.max(0, s.runsCompleted),
    'runsFailed': math.max(0, s.runsFailed),
    'roomsCleared': math.max(0, s.roomsCleared),
    'encountersCleared': math.max(0, s.encountersCleared),
    'expGained': math.max(0, s.expGained),
    'goldGained': math.max(0, s.goldGained),
    'levelsGained': math.max(0, s.levelsGained),
    'addedStacks': s.addedStacks,
    'overflowStacks': s.overflowStacks,
    'addedEquipmentCount': math.max(0, s.addedEquipmentCount),
    'droppedEquipmentCount': math.max(0, s.droppedEquipmentCount),
    'autoSoldEquipmentCount': math.max(0, s.autoSoldEquipmentCount),
    'autoSoldEquipmentGold': math.max(0, s.autoSoldEquipmentGold),
    'autoSalvagedEquipmentCount': math.max(0, s.autoSalvagedEquipmentCount),
    'autoSalvagedScrapCount': math.max(0, s.autoSalvagedScrapCount),
    'acknowledged': s.acknowledged,
    'generatedAtMs': math.max(0, s.generatedAtMs),
    'cycleRank': math.max(0, s.cycleRank),
    if (s.failureReason != null) 'failureReason': s.failureReason,
  };

  ({
    ActiveDungeonSessionSnapshot? active,
    OfflineActivitySnapshot offlineActivity,
    Map<String, int> consecutiveDefeats,
    String? lastFailedDungeonId,
  })
  _decodeSessionData(String raw) {
    if (raw.trim().isEmpty || raw.trim() == '{}') {
      return const (
        active: null,
        offlineActivity: OfflineActivitySnapshot.paused(),
        consecutiveDefeats: <String, int>{},
        lastFailedDungeonId: null,
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _warn(
          'sessionDataJson bukan objek JSON; sesi dan offline activity direset.',
        );
        return const (
          active: null,
          offlineActivity: OfflineActivitySnapshot.paused(),
          consecutiveDefeats: <String, int>{},
          lastFailedDungeonId: null,
        );
      }
      final active = _decodeActiveSessionMap(decoded['activeDungeonSession']);
      final offlineActivity = _decodeOfflineActivityMap(
        decoded['offlineActivity'],
      );
      final consecutiveDefeats = _decodeConsecutiveDefeats(
        decoded['consecutiveDefeats'],
      );
      final rawFailedId = decoded['lastFailedDungeonId'];
      var lastFailedDungeonId = rawFailedId is String
          ? rawFailedId.trim()
          : null;
      if (lastFailedDungeonId != null &&
          (lastFailedDungeonId.isEmpty ||
              (config.dungeons.isNotEmpty &&
                  !SaveSnapshotCodec.isValidDungeonId(
                    lastFailedDungeonId,
                    config,
                  )))) {
        lastFailedDungeonId = null;
      }
      return (
        active: active,
        offlineActivity: offlineActivity,
        consecutiveDefeats: consecutiveDefeats,
        lastFailedDungeonId: lastFailedDungeonId,
      );
    } on FormatException {
      _warn('sessionDataJson rusak; diarahkan ke Town dengan aman.');
      return const (
        active: null,
        offlineActivity: OfflineActivitySnapshot.paused(),
        consecutiveDefeats: <String, int>{},
        lastFailedDungeonId: null,
      );
    }
  }

  Map<String, int> _decodeConsecutiveDefeats(Object? raw) {
    if (raw == null) return const {};
    if (raw is! Map<String, dynamic>) {
      _warn('consecutiveDefeats tidak valid; diabaikan.');
      return const {};
    }
    final result = <String, int>{};
    for (final entry in raw.entries) {
      final id = entry.key.trim();
      final val = entry.value;
      if (id.isEmpty || val is! int || val <= 0) continue;
      if (config.dungeons.isNotEmpty &&
          !SaveSnapshotCodec.isValidDungeonId(id, config)) {
        continue;
      }
      result[id] = val;
    }
    return Map<String, int>.unmodifiable(result);
  }

  ActiveDungeonSessionSnapshot? _decodeActiveSessionMap(Object? inner) {
    if (inner == null) return null;
    if (inner is! Map<String, dynamic>) {
      _warn('activeDungeonSession tidak valid; sesi dungeon diabaikan.');
      return null;
    }

    final runId = inner['runId'];
    final dungeonId = inner['dungeonId'];
    final currentRoomId = inner['currentRoomId'];
    final currentRoomIndex = inner['currentRoomIndex'];
    final rawStatus = inner['status'];

    if (runId is! String ||
        runId.trim().isEmpty ||
        dungeonId is! String ||
        currentRoomId is! String ||
        currentRoomIndex is! int ||
        rawStatus is! String) {
      _warn('Field wajib activeDungeonSession tidak lengkap; diabaikan.');
      return null;
    }

    final status = _parseEnum(DungeonSessionStatus.values, rawStatus);
    if (status == null) {
      _warn('Status sesi "$rawStatus" tidak dikenal; sesi diabaikan.');
      return null;
    }

    final rawBossEventId = inner['bossEventId'];
    final bossEventId =
        rawBossEventId is String && rawBossEventId.trim().isNotEmpty
        ? rawBossEventId.trim()
        : null;
    final rawPeriodKeyAtStart = inner['periodKeyAtStart'];
    final periodKeyAtStart =
        rawPeriodKeyAtStart is String && rawPeriodKeyAtStart.trim().isNotEmpty
        ? rawPeriodKeyAtStart.trim()
        : null;

    // Validasi silang terhadap config.dungeons atau config.bossEvents.
    if (bossEventId != null) {
      if (config.bossEvents != null &&
          config.bossEvents!.findBossById(bossEventId) == null) {
        _warn(
          'Sesi merujuk bossEventId tidak dikenal ("$bossEventId"); diarahkan ke Town.',
        );
        return null;
      }
    } else if (config.dungeons.isNotEmpty) {
      final dungeon = config.dungeons[dungeonId];
      final room = dungeon?.roomById(currentRoomId);
      if (dungeon == null || room == null) {
        _warn(
          'Sesi merujuk dungeon/room tidak dikenal '
          '("$dungeonId"/"$currentRoomId"); diarahkan ke Town.',
        );
        return null;
      }
    }

    final cleared = <String>{};
    final rawCleared = inner['clearedRoomIds'];
    if (rawCleared is List) {
      for (final id in rawCleared) {
        if (id is String && id.isNotEmpty) {
          cleared.add(id);
        }
      }
    }

    final rawReviveTicks = inner['reviveCooldownTicks'];
    var reviveTicks = 0;
    if (rawReviveTicks is int) {
      if (rawReviveTicks < 0) {
        _warn('reviveCooldownTicks negatif ($rawReviveTicks); dijepit ke 0.');
      }
      reviveTicks = math.max(0, rawReviveTicks);
    }

    final playerStatus =
        _parseEnum(PlayerStatus.values, inner['playerStatus']) ??
        PlayerStatus.alive;

    final rewardClaimed = inner['completionRewardClaimed'];
    final rawCycleRank = inner['cycleRank'];
    final sessionCycleRank = rawCycleRank is num
        ? math.max(0, rawCycleRank.toInt())
        : 0;
    return ActiveDungeonSessionSnapshot(
      runId: runId,
      dungeonId: dungeonId,
      currentRoomId: currentRoomId,
      currentRoomIndex: math.max(0, currentRoomIndex),
      status: status,
      clearedRoomIds: Set.unmodifiable(cleared),
      completionRewardClaimed: rewardClaimed is bool ? rewardClaimed : false,
      reviveCooldownTicks: reviveTicks,
      playerStatus: playerStatus,
      cycleRank: sessionCycleRank,
      bossEventId: bossEventId,
      periodKeyAtStart: periodKeyAtStart,
    );
  }

  OfflineActivitySnapshot _decodeOfflineActivityMap(Object? inner) {
    if (inner == null) return const OfflineActivitySnapshot.paused();
    if (inner is! Map<String, dynamic>) {
      _warn('offlineActivity tidak valid; direset ke Pause Progression.');
      return const OfflineActivitySnapshot.paused();
    }

    final mode = _parseEnum(OfflineActivityMode.values, inner['mode']);
    final state = _parseEnum(OfflineActivityState.values, inner['state']);
    if (mode == null || state == null) {
      _warn(
        'Mode/state offlineActivity tidak dikenal; direset ke Pause Progression.',
      );
      return const OfflineActivitySnapshot.paused();
    }

    final selectedDungeonId = inner['selectedDungeonId'] is String
        ? (inner['selectedDungeonId'] as String).trim()
        : null;
    if (config.dungeons.isNotEmpty &&
        selectedDungeonId != null &&
        selectedDungeonId.isNotEmpty &&
        !config.dungeons.containsKey(selectedDungeonId)) {
      _warn(
        'offlineActivity merujuk dungeon "$selectedDungeonId" yang tidak ada; '
        'direset ke Pause Progression.',
      );
      return const OfflineActivitySnapshot.paused();
    }

    final activeRunId = inner['activeRunId'] is String
        ? (inner['activeRunId'] as String).trim()
        : null;

    if (mode == OfflineActivityMode.pauseProgression &&
        state != OfflineActivityState.inactive) {
      _warn(
        'pauseProgression berada di state ${state.name}; '
        'dinormalisasi ke inactive.',
      );
      return const OfflineActivitySnapshot.paused();
    }

    if (state != OfflineActivityState.inactive &&
        state != OfflineActivityState.completed &&
        state != OfflineActivityState.failed) {
      if (mode == OfflineActivityMode.continueDungeon &&
          (activeRunId == null || activeRunId.isEmpty)) {
        _warn(
          'continueDungeon tidak memiliki activeRunId; '
          'direset ke Pause Progression.',
        );
        return const OfflineActivitySnapshot.paused();
      }
      if (mode == OfflineActivityMode.autoFarming &&
          (selectedDungeonId == null || selectedDungeonId.isEmpty)) {
        _warn(
          'autoFarming tidak memiliki selectedDungeonId; '
          'direset ke Pause Progression.',
        );
        return const OfflineActivitySnapshot.paused();
      }
    }

    final rawCheckpoint = inner['lastCheckpointAtMs'];
    final checkpointMs = rawCheckpoint is int ? math.max(0, rawCheckpoint) : 0;
    final rawProcessed = inner['processedOfflineDurationMs'];
    final processedMs = rawProcessed is int ? math.max(0, rawProcessed) : 0;
    final seed = inner['simulationSeed'] is int
        ? inner['simulationSeed'] as int
        : null;
    final policy =
        _parseEnum(OfflineFailurePolicy.values, inner['failurePolicy']) ??
        OfflineFailurePolicy.stopOnDefeat;
    final summary = _decodeOfflineSummaryMap(inner['pendingSummary']);

    return OfflineActivitySnapshot(
      mode: mode,
      state: state,
      selectedDungeonId:
          (selectedDungeonId != null && selectedDungeonId.isNotEmpty)
          ? selectedDungeonId
          : null,
      activeRunId: (activeRunId != null && activeRunId.isNotEmpty)
          ? activeRunId
          : null,
      lastCheckpointAtMs: checkpointMs,
      processedOfflineDurationMs: processedMs,
      simulationSeed: seed,
      failurePolicy: policy,
      pendingSummary: summary,
    );
  }

  OfflineSummarySnapshot? _decodeOfflineSummaryMap(Object? inner) {
    if (inner == null) return null;
    if (inner is! Map<String, dynamic>) {
      _warn('pendingSummary offline tidak valid; diabaikan.');
      return null;
    }
    final eventId = inner['eventId'];
    final mode = _parseEnum(OfflineActivityMode.values, inner['mode']);
    final finalState = _parseEnum(
      OfflineActivityState.values,
      inner['finalState'],
    );
    if (eventId is! String ||
        eventId.trim().isEmpty ||
        mode == null ||
        finalState == null) {
      _warn('Field wajib pendingSummary tidak valid; diabaikan.');
      return null;
    }

    int nonNegInt(String key) {
      final v = inner[key];
      return v is int ? math.max(0, v) : 0;
    }

    Map<String, int> decodeStacks(Object? raw) {
      final out = <String, int>{};
      if (raw is Map) {
        for (final entry in raw.entries) {
          if (entry.key is String &&
              entry.value is int &&
              (entry.value as int) > 0) {
            out[entry.key as String] = entry.value as int;
          }
        }
      }
      return Map.unmodifiable(out);
    }

    return OfflineSummarySnapshot(
      eventId: eventId,
      mode: mode,
      finalState: finalState,
      effectiveElapsedMs: nonNegInt('effectiveElapsedMs'),
      cappedAtMaxDuration: inner['cappedAtMaxDuration'] is bool
          ? inner['cappedAtMaxDuration'] as bool
          : false,
      runsAttempted: nonNegInt('runsAttempted'),
      runsCompleted: nonNegInt('runsCompleted'),
      runsFailed: nonNegInt('runsFailed'),
      roomsCleared: nonNegInt('roomsCleared'),
      encountersCleared: nonNegInt('encountersCleared'),
      expGained: nonNegInt('expGained'),
      goldGained: nonNegInt('goldGained'),
      levelsGained: nonNegInt('levelsGained'),
      addedStacks: decodeStacks(inner['addedStacks']),
      overflowStacks: decodeStacks(inner['overflowStacks']),
      addedEquipmentCount: nonNegInt('addedEquipmentCount'),
      droppedEquipmentCount: nonNegInt('droppedEquipmentCount'),
      autoSoldEquipmentCount: nonNegInt('autoSoldEquipmentCount'),
      autoSoldEquipmentGold: nonNegInt('autoSoldEquipmentGold'),
      autoSalvagedEquipmentCount: nonNegInt('autoSalvagedEquipmentCount'),
      autoSalvagedScrapCount: nonNegInt('autoSalvagedScrapCount'),
      acknowledged: inner['acknowledged'] is bool
          ? inner['acknowledged'] as bool
          : false,
      generatedAtMs: nonNegInt('generatedAtMs'),
      cycleRank: nonNegInt('cycleRank'),
      failureReason: inner['failureReason'] is String
          ? inner['failureReason'] as String
          : null,
    );
  }

  static bool _intMapEquals(Map<String, int> a, Map<String, int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static bool _stringSetEquals(Set<String> a, Set<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  static bool _equipmentStatsEquals(EquipmentStats a, EquipmentStats b) =>
      identical(a, b) ||
      (a.hp == b.hp &&
          a.atk == b.atk &&
          a.def == b.def &&
          a.hpPct == b.hpPct &&
          a.atkPct == b.atkPct &&
          a.defPct == b.defPct &&
          a.critRate == b.critRate &&
          a.critDamage == b.critDamage &&
          a.attackSpeed == b.attackSpeed &&
          a.moveSpeed == b.moveSpeed &&
          a.attackRange == b.attackRange &&
          a.skillHaste == b.skillHaste &&
          a.lifesteal == b.lifesteal &&
          a.spellVamp == b.spellVamp);

  static bool _equipmentEquals(EquipmentInstance a, EquipmentInstance b) =>
      identical(a, b) ||
      (a.id == b.id &&
          a.definitionId == b.definitionId &&
          a.slot == b.slot &&
          a.rarity == b.rarity &&
          a.enhancementLevel == b.enhancementLevel &&
          a.isFavorite == b.isFavorite &&
          _equipmentStatsEquals(a.rolledStats, b.rolledStats));

  static bool _equipmentListEquals(
    List<EquipmentInstance> a,
    List<EquipmentInstance> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_equipmentEquals(a[i], b[i])) return false;
    }
    return true;
  }

  static bool _equippedMapEquals(
    Map<EquipmentSlot, EquipmentInstance> a,
    Map<EquipmentSlot, EquipmentInstance> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || other.id != entry.value.id) return false;
    }
    return true;
  }

  static bool _dungeonProgressEquals(
    DungeonProgressSnapshot? a,
    DungeonProgressSnapshot b,
  ) {
    if (a == null) return false;
    if (identical(a, b)) return true;
    return a.currentDungeonId == b.currentDungeonId &&
        a.currentRoomId == b.currentRoomId &&
        a.currentRoomIndex == b.currentRoomIndex &&
        a.highestClearedRoomIndex == b.highestClearedRoomIndex &&
        a.clearsCount == b.clearsCount &&
        a.clearedInCycleRank == b.clearedInCycleRank &&
        a.rewardState.lastRunId == b.rewardState.lastRunId &&
        a.rewardState.completionRewardClaimed ==
            b.rewardState.completionRewardClaimed &&
        _stringSetEquals(
          a.rewardState.claimedRoomRewardIds,
          b.rewardState.claimedRoomRewardIds,
        );
  }

  static bool _gachaPityMapEquals(
    Map<String, GachaPityState> a,
    Map<String, GachaPityState> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null ||
          other.pullCount != entry.value.pullCount ||
          other.isGuaranteed != entry.value.isGuaranteed) {
        return false;
      }
    }
    return true;
  }

  static bool _periodicQuestListEquals(
    List<PeriodicQuestState> a,
    List<PeriodicQuestState> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].questId != b[i].questId ||
          a[i].periodKey != b[i].periodKey ||
          a[i].completedAtMs != b[i].completedAtMs) {
        return false;
      }
    }
    return true;
  }

  static bool _eventShopListEquals(
    List<EventShopPurchaseRecord> a,
    List<EventShopPurchaseRecord> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].entryId != b[i].entryId ||
          a[i].periodKey != b[i].periodKey ||
          a[i].purchasedCount != b[i].purchasedCount) {
        return false;
      }
    }
    return true;
  }
}

class _PreparedSnapshotWrite {
  const _PreparedSnapshotWrite({
    required this.snapshot,
    required this.pid,
    required this.progress,
    required this.allEquipment,
    required this.specId,
    required this.safeLastNormalId,
    required this.safeAscensionRank,
    required this.safeHighestAscensionRank,
  });

  final PlayerSaveSnapshot snapshot;
  final String pid;
  final PlayerProgress progress;
  final List<EquipmentInstance> allEquipment;
  final String? specId;
  final String? safeLastNormalId;
  final int safeAscensionRank;
  final int safeHighestAscensionRank;
}
