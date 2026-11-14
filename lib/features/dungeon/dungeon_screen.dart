import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/database_provider.dart';
import '../../application/providers/game_config_provider.dart';
import '../../application/services/game_session_coordinator.dart';
import '../../domain/entities/cycle_progress.dart';
import '../../domain/entities/difficulty_config.dart';
import '../../domain/entities/dungeon_session.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/entities/game_settings.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/offline_activity.dart';
import '../../domain/entities/player_character.dart';
import '../../domain/entities/player_save_snapshot.dart';
import '../../domain/entities/player_status.dart';
import '../../domain/repositories/game_settings_repository.dart';
import '../../domain/services/ascension_service.dart';
import '../../domain/services/difficulty_service.dart';
import '../../domain/services/dungeon_manager.dart';
import '../../domain/services/dungeon_progression_service.dart';
import '../../domain/services/encounter_tracker.dart';
import '../../domain/services/equipment_factory.dart';
import '../../domain/services/equipment_service.dart';
import '../../domain/services/offline_progression_service.dart';
import '../../domain/services/reward_processor.dart';
import '../../domain/services/shop_service.dart';
import '../../game/audio/audio_service.dart';
import '../../game/echoes_game.dart';
import '../../game/hud/inventory_views.dart';
import '../../game/overlays.dart';
import 'character_overlay.dart';
import 'dungeon_completed_overlay.dart';
import 'equipment_overlay.dart';
import 'hud_overlay.dart';
import 'inventory_overlay.dart';
import 'offline_summary_overlay.dart';
import 'run_ended_overlay.dart';
import 'settings_overlay.dart';
import 'town_hub_view.dart';

/// Layar utama gameplay: memuat konfigurasi & save data, menampilkan Town Hub,
/// lalu menjalankan game Flame saat pemain memasuki dungeon.
class DungeonScreen extends ConsumerStatefulWidget {
  const DungeonScreen({super.key, this.roomTransitionDelaySeconds = 1.0});

  final double roomTransitionDelaySeconds;

  @override
  ConsumerState<DungeonScreen> createState() => _DungeonScreenState();
}

class _DungeonScreenState extends ConsumerState<DungeonScreen>
    with WidgetsBindingObserver {
  // Karakter, inventory, dan pengaturan hidup lebih lama daripada satu run:
  // level, EXP, gold, item, equipment, specialization tetap ada ketika pemain
  // memulai run baru dan dipersistensikan lewat Drift/SQLite.
  PlayerCharacter? _character;
  Inventory? _inventory;
  InventoryViews? _views;
  EquipmentService? _equipmentService;
  RewardProcessor? _rewardProcessor;
  DungeonManager? _dungeonManager;
  DungeonProgressSnapshot _dungeon = const DungeonProgressSnapshot();
  Map<String, DungeonProgressSnapshot> _dungeonProgresses = const {};
  CycleProgress _cycleProgress = const CycleProgress();
  String? _selectedDungeonId;
  ActiveDungeonSessionSnapshot? _lastSessionSnapshot;
  OfflineActivitySnapshot _offlineActivity =
      const OfflineActivitySnapshot.paused();
  int? _pendingRecoveredHp;
  Map<String, int> _pendingRecoveredSkillCooldowns = const {};
  GrantedReward? _lastCompletionReward;
  AscensionResult? _lastAscensionResult;
  Map<String, int> _consecutiveDefeats = const {};
  String? _lastFailedDungeonId;
  Map<String, int> _shopPurchases = {};
  int _shopActionCounter = 0;
  final math.Random _shopRandom = math.Random();
  DungeonEventListener? _managerListener;
  GameSessionCoordinator? _coordinator;
  GameSettingsRepository? _settingsRepo;
  final AudioService _audioService = AudioService();
  GameConfig? _config;
  int _lastOfflineClaimAtMs = 0;

  final ValueNotifier<bool> _autoSkill = ValueNotifier<bool>(true);
  EchoesGame? _game;
  bool _inDungeon = false;
  Timer? _saveDebounce;
  bool _dirty = false;
  bool _initialized = false;
  Future<void>? _initFuture;
  Future<void>? _resumeFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    if (_dirty) {
      unawaited(_flushSaveNow());
    }
    unawaited(_audioService.dispose());
    _audioService.settingsNotifier.dispose();
    if (_managerListener != null) {
      _dungeonManager?.removeListener(_managerListener!);
      _managerListener = null;
    }
    _game?.detachSessionListeners();
    _dungeonManager?.dispose();
    _autoSkill.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_audioService.pauseBgm());
      unawaited(_flushSaveNow());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_audioService.resumeBgm());
      unawaited(_handleAppResumed());
    }
  }

  Future<void> _handleAppResumed() {
    if (!_initialized || !mounted) return Future<void>.value();
    if (_resumeFuture != null) return _resumeFuture!;

    final coordinator = _coordinator;
    final config = _config;
    if (coordinator == null || config == null) return Future<void>.value();

    final future = () async {
      try {
        final loaded = await coordinator.processOfflineOnResume();
        if (!mounted) return;

        final status = loaded.offlineResult.status;
        final executedOffline =
            status == OfflineProgressionStatus.applied ||
            status == OfflineProgressionStatus.interrupted ||
            status == OfflineProgressionStatus.failed ||
            status == OfflineProgressionStatus.noEligibleEncounter;

        _lastOfflineClaimAtMs = math.max(
          _lastOfflineClaimAtMs,
          loaded.offlineResult.newLastOfflineClaimAtMs,
        );

        if (!executedOffline) {
          return;
        }

        _offlineActivity = loaded.offlineActivity;
        _character = loaded.character;
        _inventory = loaded.inventory;
        _views = InventoryViews(
          inventory: loaded.inventory,
          character: loaded.character,
        );
        _equipmentService = EquipmentService(
          inventory: loaded.inventory,
          loadout: loaded.character.loadout,
        );
        _dungeon = loaded.dungeon;
        _dungeonProgresses = Map.of(loaded.dungeonProgresses);
        _cycleProgress = loaded.cycleProgress;
        _shopPurchases = Map.of(loaded.shopPurchases);
        _consecutiveDefeats = Map.of(loaded.session.consecutiveDefeats);
        _lastFailedDungeonId = loaded.session.lastFailedDungeonId;
        _lastSessionSnapshot = loaded.activeDungeonSession;
        _rewardProcessor = loaded.rewardProcessor;
        _autoSkill.value = loaded.session.autoSkillEnabled;

        final manager = _dungeonManager;
        setState(() {
          if (manager != null && loaded.hasRecoverableDungeonSession) {
            _game?.detachSessionListeners();
            manager.exitToTown();
            final restored = manager.restoreSession(
              loaded.activeDungeonSession!,
            );
            if (restored != null) {
              final prev = _progressFor(restored.dungeonId);
              _selectedDungeonId = restored.dungeonId;
              _dungeon = DungeonProgressSnapshot(
                currentDungeonId: restored.dungeonId,
                currentRoomId: restored.currentRoomId,
                currentRoomIndex: restored.currentRoomIndex,
                highestClearedRoomIndex: prev.highestClearedRoomIndex,
                clearsCount: prev.clearsCount,
                clearedInCycleRank: prev.clearedInCycleRank,
                rewardState: prev.rewardState,
              );
              _dungeonProgresses[restored.dungeonId] = _dungeon;
              _pendingRecoveredHp = loaded.recoveredHp;
              _pendingRecoveredSkillCooldowns =
                  loaded.recoveredSkillCooldownTicks;
              _game = _newGame(
                config,
                initialPlayerHp: loaded.recoveredHp,
                initialReviveCooldownTicks:
                    loaded.activeDungeonSession!.reviveCooldownTicks,
                initialSkillCooldownTicks: loaded.recoveredSkillCooldownTicks,
              );
              if (loaded.hasUnacknowledgedOfflineSummary) {
                _game?.paused = true;
              }
              _inDungeon = true;
            } else {
              final nextId = _resolveSelectedDungeonId(
                config,
                exitedDungeonId: loaded.activeDungeonSession?.dungeonId,
              );
              _selectedDungeonId = nextId;
              if (nextId != null) {
                _dungeon = _progressFor(nextId);
              }
              _pendingRecoveredHp = null;
              _pendingRecoveredSkillCooldowns = const {};
              _lastSessionSnapshot = null;
              _game = null;
              _inDungeon = false;
            }
          } else {
            _game?.detachSessionListeners();
            manager?.exitToTown();
            final nextId = _resolveSelectedDungeonId(
              config,
              exitedDungeonId: loaded.activeDungeonSession?.dungeonId,
            );
            _selectedDungeonId = nextId;
            if (nextId != null) {
              _dungeon = _progressFor(nextId);
            }
            _pendingRecoveredHp = null;
            _pendingRecoveredSkillCooldowns = const {};
            _lastSessionSnapshot = null;
            _game = null;
            _inDungeon = false;
          }
        });

        if (status == OfflineProgressionStatus.noEligibleEncounter &&
            loaded.offlineResult.failureReason != null) {
          _showMessage(loaded.offlineResult.failureReason!);
        }
      } finally {
        _resumeFuture = null;
      }
    }();
    _resumeFuture = future;
    return future;
  }

  Future<void> _ensureInitialized(GameConfig config) {
    _config = config;
    return _initFuture ??= () async {
      final repo = await ref.read(playerSaveRepositoryProvider.future);
      if (repo is GameSettingsRepository) {
        _settingsRepo = repo as GameSettingsRepository;
        final loadedSettings = await _settingsRepo!.loadSettings();
        await _audioService.applySettings(loadedSettings);
      }
      unawaited(_audioService.preload());
      unawaited(_audioService.startBgm());
      final offlineService = ref.read(offlineProgressionServiceProvider);
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: config,
        offlineService: offlineService,
      );
      final loaded = await coordinator.loadAndProcessOffline();
      if (!mounted) return;

      _coordinator = coordinator;
      _character = loaded.character;
      _inventory = loaded.inventory;
      _views = InventoryViews(
        inventory: loaded.inventory,
        character: loaded.character,
      );
      _equipmentService = EquipmentService(
        inventory: loaded.inventory,
        loadout: loaded.character.loadout,
      );
      _dungeon = loaded.dungeon;
      _dungeonProgresses = Map.of(loaded.dungeonProgresses);
      _cycleProgress = loaded.cycleProgress;
      _shopPurchases = Map.of(loaded.shopPurchases);
      _consecutiveDefeats = Map.of(loaded.session.consecutiveDefeats);
      _lastFailedDungeonId = loaded.session.lastFailedDungeonId;
      _lastSessionSnapshot = loaded.activeDungeonSession;
      _offlineActivity = loaded.offlineActivity;
      _rewardProcessor = loaded.rewardProcessor;
      _lastOfflineClaimAtMs = loaded.offlineResult.newLastOfflineClaimAtMs;
      _autoSkill.value = loaded.session.autoSkillEnabled;
      final manager = config.dungeons.isNotEmpty
          ? DungeonManager(
              dungeons: config.dungeons,
              encounterTracker: EncounterTracker(
                monsterCatalog: config.monsters,
              ),
              difficultyService: DifficultyService(config.difficulty),
            )
          : null;
      _dungeonManager = manager;
      if (manager != null) {
        _attachManagerListener(manager);
      }

      if (manager != null && loaded.hasRecoverableDungeonSession) {
        final restored = manager.restoreSession(loaded.activeDungeonSession!);
        if (restored != null) {
          final prev = _progressFor(restored.dungeonId);
          _selectedDungeonId = restored.dungeonId;
          _dungeon = DungeonProgressSnapshot(
            currentDungeonId: restored.dungeonId,
            currentRoomId: restored.currentRoomId,
            currentRoomIndex: restored.currentRoomIndex,
            highestClearedRoomIndex: prev.highestClearedRoomIndex,
            clearsCount: prev.clearsCount,
            clearedInCycleRank: prev.clearedInCycleRank,
            rewardState: prev.rewardState,
          );
          _dungeonProgresses[restored.dungeonId] = _dungeon;
          _pendingRecoveredHp = loaded.recoveredHp;
          _pendingRecoveredSkillCooldowns = loaded.recoveredSkillCooldownTicks;
          _game = _newGame(
            config,
            initialPlayerHp: loaded.recoveredHp,
            initialReviveCooldownTicks:
                loaded.activeDungeonSession!.reviveCooldownTicks,
            initialSkillCooldownTicks: loaded.recoveredSkillCooldownTicks,
          );
          if (loaded.hasUnacknowledgedOfflineSummary) {
            _game?.paused = true;
          }
          _inDungeon = true;
          unawaited(_flushSaveNow());
        } else {
          // Sesi recovery tidak memiliki room belum selesai / tidak valid:
          // arahkan kembali ke Town secara aman.
          final nextId = _resolveSelectedDungeonId(
            config,
            exitedDungeonId: loaded.activeDungeonSession?.dungeonId,
          );
          _selectedDungeonId = nextId;
          if (nextId != null) {
            _dungeon = _progressFor(nextId);
          }
          _pendingRecoveredHp = null;
          _pendingRecoveredSkillCooldowns = const {};
          _lastSessionSnapshot = null;
          _inDungeon = false;
          unawaited(_flushSaveNow());
        }
      } else {
        final nextId = _resolveSelectedDungeonId(
          config,
          exitedDungeonId: loaded.activeDungeonSession?.dungeonId,
        );
        _selectedDungeonId = nextId;
        if (nextId != null) {
          _dungeon = _progressFor(nextId);
        }
        _lastSessionSnapshot = null;
        _inDungeon = false;
      }

      _initialized = true;

      if (loaded.isFirstLaunch) {
        unawaited(_flushSaveNow());
      }
      if (loaded.loadError != null) {
        _showMessage(
          'Gagal membaca save data; memulai sesi aman (${loaded.loadError}).',
        );
      } else if (loaded.offlineResult.status ==
              OfflineProgressionStatus.noEligibleEncounter &&
          loaded.offlineResult.failureReason != null) {
        _showMessage(loaded.offlineResult.failureReason!);
      }
    }();
  }

  DungeonProgressionService _progressionService(GameConfig? config) =>
      DungeonProgressionService(config?.difficulty ?? const DifficultyConfig());

  DungeonProgressSnapshot _progressFor(String dungeonId) {
    final stored = _dungeonProgresses[dungeonId];
    if (stored != null) return stored;
    if (_dungeon.currentDungeonId == dungeonId) return _dungeon;
    return DungeonProgressSnapshot(currentDungeonId: dungeonId);
  }

  Map<String, DungeonProgressSnapshot> _progressMapWithCurrent() {
    if (_dungeon.currentDungeonId.isEmpty) {
      return _dungeonProgresses;
    }
    return {..._dungeonProgresses, _dungeon.currentDungeonId: _dungeon};
  }

  String? _resolveSelectedDungeonId(
    GameConfig config, {
    String? exitedDungeonId,
  }) {
    if (config.dungeons.isEmpty) return null;
    final progressMap = _progressMapWithCurrent();
    final progression = _progressionService(config);

    if (exitedDungeonId != null) {
      final respawnId = progression.resolveRespawnDungeonId(
        dungeons: config.dungeons.values,
        cycle: _cycleProgress,
        progresses: progressMap,
        exitedDungeonId: exitedDungeonId,
      );
      if (respawnId != null) return respawnId;
    }

    final currentSelected = _selectedDungeonId;
    if (currentSelected != null) {
      final def = config.dungeons[currentSelected];
      if (def != null &&
          progression.isUnlocked(
            def,
            _cycleProgress,
            progressMap,
            allDungeons: config.dungeons.values,
          )) {
        return def.id;
      }
    }

    return progression.resolveRespawnDungeonId(
      dungeons: config.dungeons.values,
      cycle: _cycleProgress,
      progresses: progressMap,
    );
  }

  void _selectDungeon(GameConfig config, String dungeonId) {
    final def = config.dungeons[dungeonId];
    if (def == null) {
      _showMessage('Konfigurasi dungeon "$dungeonId" tidak ditemukan.');
      return;
    }
    final progressMap = _progressMapWithCurrent();
    final unlocked = _progressionService(config).isUnlocked(
      def,
      _cycleProgress,
      progressMap,
      allDungeons: config.dungeons.values,
      playerLevel: _character?.level,
    );
    if (!unlocked) {
      final reqLv = _progressionService(config)
          .requiredLevel(def, _cycleProgress.ascensionRank);
      _showMessage(
        '${def.name} masih terkunci (butuh selesai sebelumnya & Lv $reqLv).',
      );
      return;
    }
    setState(() {
      _selectedDungeonId = def.id;
      _lastFailedDungeonId = null;
      _cycleProgress = _progressionService(config)
          .recordDungeonEntered(_cycleProgress, def);
    });
    unawaited(_flushSaveNow());
  }

  void _selectPauseOffline() {
    setState(() {
      _offlineActivity = _offlineActivity.withPauseProgression();
    });
    unawaited(_flushSaveNow());
  }

  void _selectAutoFarming(String dungeonId) {
    final config = _config;
    final dungeonDef = config?.dungeons[dungeonId];
    if (config != null && dungeonDef == null) {
      _showMessage('Konfigurasi dungeon "$dungeonId" tidak ditemukan.');
      return;
    }
    if (dungeonDef != null && !dungeonDef.isNormal) {
      _showMessage(
        'Ascension Dungeon tidak dapat dijadikan target Auto Farming.',
      );
      return;
    }
    final progressMap = _progressMapWithCurrent();
    final progression = _progressionService(config);
    if (!progression.isClearedInCurrentCycle(
      dungeonId,
      _cycleProgress,
      progressMap,
    )) {
      _showMessage(
        'Selesaikan dungeon pada siklus saat ini (Rank ${_cycleProgress.ascensionRank}) untuk membuka Auto Farming.',
      );
      return;
    }
    setState(() {
      _offlineActivity = _offlineActivity.withAutoFarming(
        dungeonId: dungeonId,
        checkpointAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    });
    unawaited(_flushSaveNow());
  }

  void _selectContinueDungeon() {
    final session = _dungeonManager?.session;
    if (!_inDungeon || session == null || session.isTerminal) {
      _showMessage('Tidak ada dungeon run aktif untuk Continue Dungeon.');
      return;
    }
    final activeDungeon = _dungeonManager?.activeDungeon;
    if (activeDungeon != null && !activeDungeon.isNormal) {
      _showMessage('Ascension Dungeon tidak dapat dijalankan secara offline.');
      return;
    }
    setState(() {
      _offlineActivity = _offlineActivity.withContinueDungeon(
        dungeonId: session.dungeonId,
        activeRunId: session.runId,
        checkpointAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    });
    unawaited(_flushSaveNow());
  }

  void _acknowledgeOfflineSummary() {
    setState(() {
      _offlineActivity = _offlineActivity.acknowledgePendingSummary();
      _game?.paused = false;
    });
    unawaited(_flushSaveNow());
  }

  void _showMessage(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
    );
  }

  void _scheduleSave() {
    _dirty = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(_flushSaveNow());
    });
  }

  Future<void> _flushSaveNow() async {
    _saveDebounce?.cancel();
    final coordinator = _coordinator;
    final character = _character;
    final inventory = _inventory;
    final rewardProcessor = _rewardProcessor;
    if (coordinator == null ||
        character == null ||
        inventory == null ||
        rewardProcessor == null) {
      return;
    }
    _dirty = false;
    try {
      final manager = _dungeonManager;
      final worldLoaded = _inDungeon && (_game?.world.isLoaded ?? false);
      final sim = worldLoaded ? _game?.world.simulation : null;
      if (sim != null) {
        _pendingRecoveredHp = null;
        _pendingRecoveredSkillCooldowns = const {};
      }
      final hasActiveSession =
          _inDungeon && (manager?.hasActiveSession ?? false);
      final liveSession =
          _inDungeon && manager != null && manager.session != null
          ? manager.toActiveSessionSnapshot(
              reviveCooldownTicks:
                  sim?.reviveCooldownTicks ??
                  _lastSessionSnapshot?.reviveCooldownTicks ??
                  0,
              playerStatus:
                  sim?.playerStatus ??
                  _lastSessionSnapshot?.playerStatus ??
                  PlayerStatus.alive,
            )
          : _lastSessionSnapshot;

      final cooldowns = <String, int>{
        if (hasActiveSession && sim != null)
          for (final entry in sim.skillStates.entries)
            if (entry.value.cooldownTicksRemaining > 0)
              entry.key: entry.value.cooldownTicksRemaining
            else if (hasActiveSession)
              ..._pendingRecoveredSkillCooldowns,
      };

      final mergedDungeonProgresses = <String, DungeonProgressSnapshot>{
        ..._dungeonProgresses,
        if (_dungeon.currentDungeonId.isNotEmpty)
          _dungeon.currentDungeonId: _dungeon,
      };
      _dungeonProgresses = mergedDungeonProgresses;

      await coordinator.saveFromRuntime(
        character: character,
        inventory: inventory,
        dungeon: _dungeon,
        dungeonProgresses: mergedDungeonProgresses,
        cycleProgress: _cycleProgress,
        rewardProcessor: rewardProcessor,
        autoSkillEnabled: _autoSkill.value,
        lastOfflineClaimAtMs: _lastOfflineClaimAtMs,
        currentHp: hasActiveSession
            ? (sim?.player.hp ?? _pendingRecoveredHp)
            : null,
        skillCooldownTicks: cooldowns,
        activeDungeonSession: liveSession,
        offlineActivity: _offlineActivity,
        consecutiveDefeats: _consecutiveDefeats,
        lastFailedDungeonId: _lastFailedDungeonId,
      );
    } catch (e) {
      _dirty = true;
      if (mounted) _showMessage('Gagal menyimpan progres: $e');
    }
  }

  void _attachManagerListener(DungeonManager manager) {
    if (_managerListener != null) {
      manager.removeListener(_managerListener!);
    }
    _managerListener = (event) {
      if (event is RoomLoadedEvent) {
        final dungeon = manager.activeDungeon;
        final roomIndex = dungeon?.indexOfRoom(event.room.id) ?? 0;
        final prev = _progressFor(event.session.dungeonId);
        final updated = DungeonProgressSnapshot(
          currentDungeonId: event.session.dungeonId,
          currentRoomId: event.room.id,
          currentRoomIndex: math.max(0, roomIndex),
          highestClearedRoomIndex: prev.highestClearedRoomIndex,
          clearsCount: prev.clearsCount,
          clearedInCycleRank: prev.clearedInCycleRank,
          rewardState: prev.rewardState,
        );
        _dungeon = updated;
        _dungeonProgresses = {
          ..._dungeonProgresses,
          event.session.dungeonId: updated,
        };
        _lastSessionSnapshot = manager.toActiveSessionSnapshot();
      } else if (event is RoomCompletedEvent) {
        final dungeon = manager.activeDungeon;
        final clearedIdx = dungeon?.indexOfRoom(event.room.id) ?? -1;
        final prev = _progressFor(event.session.dungeonId);
        final nextHighest = math.max(prev.highestClearedRoomIndex, clearedIdx);
        final updatedRoomClaims = Set<String>.unmodifiable({
          ...prev.rewardState.claimedRoomRewardIds,
          if (event.room.reward != null && !event.room.reward!.isEmpty)
            event.room.id,
        });
        final updated = DungeonProgressSnapshot(
          currentDungeonId: event.session.dungeonId,
          currentRoomId: event.session.currentRoomId,
          currentRoomIndex: event.session.currentRoomIndex,
          highestClearedRoomIndex: nextHighest,
          clearsCount: prev.clearsCount,
          clearedInCycleRank: prev.clearedInCycleRank,
          rewardState: DungeonRewardStateSnapshot(
            lastRunId: event.session.runId,
            completionRewardClaimed: prev.rewardState.completionRewardClaimed,
            claimedRoomRewardIds: updatedRoomClaims,
          ),
        );
        _dungeon = updated;
        _dungeonProgresses = {
          ..._dungeonProgresses,
          event.session.dungeonId: updated,
        };
        _lastSessionSnapshot = manager.toActiveSessionSnapshot();
      } else if (event is DungeonEndedEvent) {
        final cfg = _config;
        final progression = _progressionService(cfg);
        final dungeonDef =
            event.dungeon ?? cfg?.dungeons[event.session.dungeonId];
        if (event.finalStatus == DungeonSessionStatus.completed) {
          _consecutiveDefeats = progression.recordDungeonVictory(
            _consecutiveDefeats,
            event.session.dungeonId,
          );
          if (_lastFailedDungeonId == event.session.dungeonId) {
            _lastFailedDungeonId = null;
          }
          final prev = _progressFor(event.session.dungeonId);
          final alreadyRecorded =
              prev.rewardState.lastRunId == event.session.runId &&
              prev.rewardState.completionRewardClaimed;
          final isNormal = dungeonDef?.isNormal ?? false;
          final nextClearedInCycleRank = isNormal
              ? math.max(prev.clearedInCycleRank, _cycleProgress.ascensionRank)
              : prev.clearedInCycleRank;
          final updated = DungeonProgressSnapshot(
            currentDungeonId: event.session.dungeonId,
            currentRoomId: event.session.currentRoomId,
            currentRoomIndex: event.session.currentRoomIndex,
            highestClearedRoomIndex: prev.highestClearedRoomIndex,
            clearsCount: alreadyRecorded
                ? prev.clearsCount
                : prev.clearsCount + 1,
            clearedInCycleRank: nextClearedInCycleRank,
            rewardState: DungeonRewardStateSnapshot(
              lastRunId: event.session.runId,
              completionRewardClaimed: true,
              claimedRoomRewardIds: prev.rewardState.claimedRoomRewardIds,
            ),
          );
          final nextProgressMap = <String, DungeonProgressSnapshot>{
            ..._progressMapWithCurrent(),
            event.session.dungeonId: updated,
          };

          if (dungeonDef != null && dungeonDef.isAscension && cfg != null) {
            final ascResult = AscensionService(progressionService: progression)
                .complete(
                  runId: event.session.runId,
                  dungeons: cfg.dungeons.values,
                  cycleProgress: _cycleProgress,
                  dungeonProgresses: nextProgressMap,
                  rewardProcessor: _rewardProcessor,
                  claimedEventIds: _rewardProcessor?.claimedEventIds,
                );
            _lastAscensionResult = ascResult;
            _cycleProgress = ascResult.cycleProgress;
            _dungeonProgresses = Map.of(ascResult.dungeonProgresses);
            _dungeon = _dungeonProgresses[event.session.dungeonId] ?? updated;
          } else {
            _dungeon = updated;
            _dungeonProgresses = nextProgressMap;
          }
        } else if (event.finalStatus == DungeonSessionStatus.failed &&
            event.effectiveReason == DungeonEndReason.defeated) {
          _consecutiveDefeats = progression.recordDungeonDefeat(
            _consecutiveDefeats,
            event.session.dungeonId,
          );
          _lastFailedDungeonId = event.session.dungeonId;
        }
        _lastSessionSnapshot = ActiveDungeonSessionSnapshot(
          runId: event.session.runId,
          dungeonId: event.session.dungeonId,
          currentRoomId: event.session.currentRoomId,
          currentRoomIndex: event.session.currentRoomIndex,
          status: event.finalStatus,
          clearedRoomIds: event.session.clearedRoomIds,
          completionRewardClaimed:
              event.finalStatus == DungeonSessionStatus.completed ||
              event.session.completionRewardClaimed,
          reviveCooldownTicks: 0,
          cycleRank: event.session.cycleRank,
          playerStatus: event.finalStatus == DungeonSessionStatus.failed
              ? PlayerStatus.runEnded
              : PlayerStatus.alive,
        );
        if (_offlineActivity.mode == OfflineActivityMode.continueDungeon) {
          _offlineActivity = _offlineActivity.withPauseProgression();
        }
      }
    };
    manager.addListener(_managerListener!);
  }

  void _equip(String instanceId) {
    final service = _equipmentService;
    if (service != null && service.equip(instanceId)) {
      _views?.refresh();
      unawaited(_flushSaveNow());
    }
  }

  ShopService _shopServiceFor(GameConfig cfg) => ShopService(
    catalog: cfg.shop,
    items: cfg.items,
    equipmentFactory: EquipmentFactory(cfg.equipment),
  );

  ShopPlayerContext _shopContextFor() => ShopPlayerContext(
    playerLevel: _character?.level ?? 1,
    cycleProgress: _cycleProgress,
    dungeonProgresses: _dungeonProgresses,
    shopPurchases: Map.unmodifiable(_shopPurchases),
  );

  String _nextShopActionId(String kind) =>
      '${kind}_${DateTime.now().microsecondsSinceEpoch}_${++_shopActionCounter}';

  Future<ShopBuyResult> _buyFromShop(GameConfig cfg, String entryId) async {
    final character = _character;
    final inventory = _inventory;
    if (character == null || inventory == null) {
      return ShopBuyNotFound(entryId: entryId);
    }
    final actionId = _nextShopActionId('buy');
    final result = _shopServiceFor(cfg).buy(
      entryId: entryId,
      character: character,
      inventory: inventory,
      context: _shopContextFor(),
      random: _shopRandom,
      purchaseCounts: _shopPurchases,
      actionId: actionId,
    );
    if (result is ShopBuySuccess && !result.wasDuplicate) {
      _views?.refresh();
      setState(() {});
      await _coordinator?.saveShopTransaction(
        character: character,
        inventory: inventory,
        shopPurchases: Map.unmodifiable(_shopPurchases),
        actionId: actionId,
      );
    }
    return result;
  }

  Future<ShopSellResult> _sellEquipmentFromShop(
    GameConfig cfg,
    String instanceId,
  ) async {
    final character = _character;
    final inventory = _inventory;
    if (character == null || inventory == null) {
      return ShopSellNotFound(targetId: instanceId);
    }
    final actionId = _nextShopActionId('sell_eq');
    final result = _shopServiceFor(cfg).sellEquipment(
      instanceId: instanceId,
      character: character,
      inventory: inventory,
      actionId: actionId,
    );
    if (result is ShopSellSuccess && !result.wasDuplicate) {
      _views?.refresh();
      setState(() {});
      await _coordinator?.saveShopTransaction(
        character: character,
        inventory: inventory,
        shopPurchases: Map.unmodifiable(_shopPurchases),
        actionId: actionId,
      );
    }
    return result;
  }

  Future<ShopSellResult> _sellMaterialBulkFromShop(
    GameConfig cfg,
    String itemId,
    int quantity,
  ) async {
    final character = _character;
    final inventory = _inventory;
    if (character == null || inventory == null) {
      return ShopSellNotFound(targetId: itemId);
    }
    final actionId = _nextShopActionId('sell_mat');
    final result = _shopServiceFor(cfg).sellMaterialBulk(
      itemId: itemId,
      quantity: quantity,
      character: character,
      inventory: inventory,
      actionId: actionId,
    );
    if (result is ShopSellSuccess && !result.wasDuplicate) {
      _views?.refresh();
      setState(() {});
      await _coordinator?.saveShopTransaction(
        character: character,
        inventory: inventory,
        shopPurchases: Map.unmodifiable(_shopPurchases),
        actionId: actionId,
      );
    }
    return result;
  }

  Future<ShopSellResult> _sellBatchFromShop(
    GameConfig cfg,
    List<String> equipmentInstanceIds,
    Map<String, int> materialQuantities,
  ) async {
    final character = _character;
    final inventory = _inventory;
    if (character == null || inventory == null) {
      return const ShopSellNotFound(targetId: 'batch');
    }
    final actionId = _nextShopActionId('sell_batch');
    final result = _shopServiceFor(cfg).sellBatch(
      equipmentInstanceIds: equipmentInstanceIds,
      materialQuantities: materialQuantities,
      character: character,
      inventory: inventory,
      actionId: actionId,
    );
    if (result is ShopSellSuccess && !result.wasDuplicate) {
      _views?.refresh();
      setState(() {});
      await _coordinator?.saveShopTransaction(
        character: character,
        inventory: inventory,
        shopPurchases: Map.unmodifiable(_shopPurchases),
        actionId: actionId,
      );
    }
    return result;
  }

  void _unequip(EquipmentSlot slot) {
    final service = _equipmentService;
    if (service != null && service.unequip(slot)) {
      _views?.refresh();
      unawaited(_flushSaveNow());
    }
  }

  void _chooseSpecialization(String id) {
    final character = _character;
    if (character != null && character.chooseSpecialization(id)) {
      _views?.refresh();
      unawaited(_flushSaveNow());
    }
  }

  void _upgradeSkill(String skillId) {
    final character = _character;
    if (character == null) return;
    final result = character.upgradeSkill(skillId);
    if (result.status == SkillUpgradeStatus.upgraded) {
      unawaited(_audioService.playSfx(AudioCue.levelUp));
      _views?.refresh();
      unawaited(_flushSaveNow());
    }
  }

  void _updateSettings(GameSettingsData next) {
    unawaited(_audioService.applySettings(next));
    unawaited(_settingsRepo?.saveSettings(next));
  }

  void _switchCycleRank(GameConfig config, int targetRank) {
    final highest = _cycleProgress.highestAscensionRank;
    final clamped = targetRank.clamp(0, highest);
    if (clamped == _cycleProgress.ascensionRank) return;
    final nextCycle = _cycleProgress.copyWith(ascensionRank: clamped);
    final progression = _progressionService(config);
    final progressMap = _progressMapWithCurrent();
    final currentSelected = _resolveSelectedDungeonId(config);
    var nextSelected = currentSelected;
    if (currentSelected != null) {
      final def = config.dungeons[currentSelected];
      if (def == null ||
          !progression.isUnlocked(
            def,
            nextCycle,
            progressMap,
            allDungeons: config.dungeons.values,
            playerLevel: _character?.level,
          )) {
        nextSelected = progression.resolveRespawnDungeonId(
          dungeons: config.dungeons.values,
          cycle: nextCycle,
          progresses: progressMap,
          exitedDungeonId: currentSelected,
        );
      }
    }
    setState(() {
      _cycleProgress = nextCycle;
      if (nextSelected != null) {
        _selectedDungeonId = nextSelected;
        _dungeon = _progressFor(nextSelected);
      }
    });
    unawaited(_flushSaveNow());
  }

  void _enterDungeon(GameConfig config, {String? dungeonId}) {
    final targetId = dungeonId ?? _resolveSelectedDungeonId(config);
    final dungeonDef = targetId != null ? config.dungeons[targetId] : null;
    if (dungeonDef == null) {
      _showMessage('Konfigurasi dungeon tidak ditemukan.');
      return;
    }
    final playerLevel = _character?.level;
    final progressMap = _progressMapWithCurrent();
    final progression = _progressionService(config);
    final unlockedByProgress = dungeonDef.isAscension
        ? AscensionService(progressionService: progression).canEnterAscension(
            dungeons: config.dungeons.values,
            cycleProgress: _cycleProgress,
            dungeonProgresses: progressMap,
          )
        : progression.isUnlocked(
            dungeonDef,
            _cycleProgress,
            progressMap,
            allDungeons: config.dungeons.values,
          );
    if (!unlockedByProgress) {
      _showMessage('${dungeonDef.name} masih terkunci pada siklus ini.');
      return;
    }
    if (playerLevel != null &&
        !progression.meetsLevelRequirement(
          dungeonDef,
          _cycleProgress.ascensionRank,
          playerLevel,
        )) {
      final reqLv = progression.requiredLevel(
        dungeonDef,
        _cycleProgress.ascensionRank,
      );
      _showMessage('${dungeonDef.name} terkunci — butuh minimal Lv $reqLv.');
      return;
    }
    var manager = _dungeonManager;
    if (manager == null) {
      manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: EncounterTracker(monsterCatalog: config.monsters),
        difficultyService: DifficultyService(config.difficulty),
      );
      _dungeonManager = manager;
      _attachManagerListener(manager);
    }
    _game?.detachSessionListeners();
    manager.exitToTown();
    _lastCompletionReward = null;
    _lastAscensionResult = null;
    _lastSessionSnapshot = null;
    _pendingRecoveredHp = null;
    _pendingRecoveredSkillCooldowns = const {};
    if (_offlineActivity.mode == OfflineActivityMode.autoFarming ||
        _offlineActivity.mode == OfflineActivityMode.continueDungeon) {
      _offlineActivity = _offlineActivity.withPauseProgression();
    }
    _selectedDungeonId = dungeonDef.id;
    _cycleProgress = progression.recordDungeonEntered(
      _cycleProgress,
      dungeonDef,
    );
    final prev = _progressFor(dungeonDef.id);
    final session = manager.startDungeon(
      dungeonDef.id,
      cycleRank: _cycleProgress.ascensionRank,
    );
    _dungeon = DungeonProgressSnapshot(
      currentDungeonId: session.dungeonId,
      currentRoomId: session.currentRoomId,
      currentRoomIndex: session.currentRoomIndex,
      highestClearedRoomIndex: prev.highestClearedRoomIndex,
      clearsCount: prev.clearsCount,
      clearedInCycleRank: prev.clearedInCycleRank,
      rewardState: DungeonRewardStateSnapshot(
        lastRunId: session.runId,
        completionRewardClaimed: false,
      ),
    );
    _dungeonProgresses = {..._dungeonProgresses, dungeonDef.id: _dungeon};
    _lastSessionSnapshot = manager.toActiveSessionSnapshot();
    setState(() {
      _game = _newGame(config);
      _inDungeon = true;
    });
    unawaited(_flushSaveNow());
  }

  void _returnToTown() {
    final exitedDungeonId =
        _dungeonManager?.activeDungeon?.id ?? _lastSessionSnapshot?.dungeonId;
    _game?.detachSessionListeners();
    _dungeonManager?.exitToTown();
    final cfg = _config;
    final respawnId = cfg != null
        ? _resolveSelectedDungeonId(cfg, exitedDungeonId: exitedDungeonId)
        : null;
    _pendingRecoveredHp = null;
    _pendingRecoveredSkillCooldowns = const {};
    _views?.refresh();
    setState(() {
      if (respawnId != null) {
        _selectedDungeonId = respawnId;
        _dungeon = _progressFor(respawnId);
      }
      if (_lastSessionSnapshot?.isRecoverable ?? false) {
        _lastSessionSnapshot = null;
      }
      _lastCompletionReward = null;
      _lastAscensionResult = null;
      if (_offlineActivity.mode == OfflineActivityMode.continueDungeon) {
        _offlineActivity = _offlineActivity.withPauseProgression();
      }
      _game = null;
      _inDungeon = false;
    });
    unawaited(_flushSaveNow());
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gameConfigProvider);
    return Scaffold(
      body: SafeArea(
        child: config.when(
          data: (cfg) => FutureBuilder<void>(
            future: _ensureInitialized(cfg),
            builder: (context, snapshot) {
              if (!_initialized &&
                  snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError && !_initialized) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Gagal menginisialisasi data progres:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final activeSelectedId = _resolveSelectedDungeonId(cfg);
              final selectedProgress = activeSelectedId != null
                  ? _progressFor(activeSelectedId)
                  : _dungeon;
              final selectedDef = activeSelectedId != null
                  ? cfg.dungeons[activeSelectedId]
                  : null;
              final content = !_inDungeon
                  ? TownHubView(
                      character: _character!,
                      views: _views!,
                      items: cfg.items,
                      dungeonProgress: selectedProgress,
                      dungeonDefinition: selectedDef,
                      cycleProgress: _cycleProgress,
                      difficultyConfig: cfg.difficulty,
                      farmingConfig: cfg.farming,
                      consecutiveDefeats: _consecutiveDefeats,
                      lastFailedDungeonId: _lastFailedDungeonId,
                      selectedDungeonId: activeSelectedId,
                      onSelectDungeon: (id) => _selectDungeon(cfg, id),
                      onEnterDungeon: () => _enterDungeon(cfg),
                      onEnterDungeonById: (id) =>
                          _enterDungeon(cfg, dungeonId: id),
                      onSwitchCycleRank: (rank) => _switchCycleRank(cfg, rank),
                      onEquip: _equip,
                      onUnequip: _unequip,
                      onChooseSpecialization: _chooseSpecialization,
                      onUpgradeSkill: _upgradeSkill,
                      settings: _audioService.settingsNotifier,
                      onSettingsChanged: _updateSettings,
                      onTestSfx: () =>
                          unawaited(_audioService.playSfx(AudioCue.loot)),
                      offlineActivity: _offlineActivity,
                      availableDungeons: cfg.dungeons,
                      dungeonProgresses: _dungeonProgresses,
                      onSelectPauseOffline: _selectPauseOffline,
                      onSelectAutoFarming: _selectAutoFarming,
                      shopCatalog: cfg.shop,
                      shopService: _shopServiceFor(cfg),
                      shopContext: _shopContextFor(),
                      onShopBuy: (entryId) => _buyFromShop(cfg, entryId),
                      onShopSellEquipment: (instanceId) =>
                          _sellEquipmentFromShop(cfg, instanceId),
                      onShopSellMaterialBulk: (itemId, qty) =>
                          _sellMaterialBulkFromShop(cfg, itemId, qty),
                      onShopSellBatch: (eqIds, matQtys) =>
                          _sellBatchFromShop(cfg, eqIds, matQtys),
                    )
                  : _buildGame(cfg);
              final pendingSummary = _offlineActivity.pendingSummary;
              final showOfflineSummary =
                  pendingSummary != null && !pendingSummary.acknowledged;
              return Stack(
                children: [
                  content,
                  if (showOfflineSummary)
                    OfflineSummaryOverlay(
                      summary: pendingSummary,
                      items: cfg.items,
                      dungeons: cfg.dungeons,
                      selectedDungeonId: _offlineActivity.selectedDungeonId,
                      onAcknowledge: _acknowledgeOfflineSummary,
                    ),
                ],
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Gagal memuat konfigurasi game:\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  EchoesGame _newGame(
    GameConfig config, {
    int? initialPlayerHp,
    int initialReviveCooldownTicks = 0,
    Map<String, int> initialSkillCooldownTicks = const {},
  }) => EchoesGame(
    config: config,
    character: _character!,
    inventory: _inventory!,
    autoSkill: _autoSkill,
    dungeonManager: _dungeonManager,
    roomTransitionDelaySeconds: widget.roomTransitionDelaySeconds,
    views: _views,
    equipmentService: _equipmentService,
    rewardProcessor: _rewardProcessor,
    initialPlayerHp: initialPlayerHp,
    initialReviveCooldownTicks: initialReviveCooldownTicks,
    initialSkillCooldownTicks: initialSkillCooldownTicks,
    audioService: _audioService,
    onProgressionChanged: _scheduleSave,
    onBuildChanged: () => unawaited(_flushSaveNow()),
    onCriticalSaveRequired: () => unawaited(_flushSaveNow()),
    onDungeonRewardSettled: (reward) {
      _lastCompletionReward = reward;
    },
  );

  /// Membuka panel [name] dan menutup panel lain agar tidak saling menumpuk.
  void _togglePanel(EchoesGame g, String name) {
    if (g.overlays.isActive(name)) {
      g.overlays.remove(name);
      return;
    }
    for (final other in GameOverlays.panels) {
      if (other != name) g.overlays.remove(other);
    }
    g.overlays.add(name);
  }

  Widget _menuButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _buildGame(GameConfig config) {
    final game = _game ??= _newGame(config);

    return GameWidget<EchoesGame>(
      key: ObjectKey(game), // game baru = widget baru
      game: game,
      initialActiveOverlays: const [GameOverlays.hud, GameOverlays.menuButtons],
      overlayBuilderMap: {
        GameOverlays.hud: (context, g) => HudOverlay(state: g.hud),
        GameOverlays.menuButtons: (context, g) {
          final continueOffline =
              _offlineActivity.mode == OfflineActivityMode.continueDungeon &&
              !_offlineActivity.isPaused;
          return Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _menuButton(
                      icon: Icons.inventory_2_outlined,
                      label: 'Tas',
                      onPressed: () => _togglePanel(g, GameOverlays.inventory),
                    ),
                    const SizedBox(height: 6),
                    _menuButton(
                      icon: Icons.shield_outlined,
                      label: 'Perlengkapan',
                      onPressed: () => _togglePanel(g, GameOverlays.equipment),
                    ),
                    const SizedBox(height: 6),
                    _menuButton(
                      icon: Icons.auto_awesome_outlined,
                      label: 'Karakter',
                      onPressed: () => _togglePanel(g, GameOverlays.character),
                    ),
                    const SizedBox(height: 6),
                    _menuButton(
                      icon: Icons.settings_outlined,
                      label: 'Pengaturan',
                      onPressed: () => _togglePanel(g, GameOverlays.settings),
                    ),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<bool>(
                      valueListenable: g.autoSkill,
                      builder: (context, on, _) => _menuButton(
                        icon: on ? Icons.flash_on : Icons.flash_off,
                        label: 'Auto Skill: ${on ? 'ON' : 'OFF'}',
                        onPressed: () {
                          g.autoSkill.value = !on;
                          unawaited(_flushSaveNow());
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    _menuButton(
                      icon: continueOffline
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                      label: continueOffline
                          ? 'Offline: Lanjut'
                          : 'Offline: Pause',
                      onPressed: continueOffline
                          ? _selectPauseOffline
                          : _selectContinueDungeon,
                    ),
                    const SizedBox(height: 6),
                    _menuButton(
                      icon: Icons.home_outlined,
                      label: 'Kembali ke Town',
                      onPressed: _returnToTown,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        GameOverlays.inventory: (context, g) => InventoryOverlay(
          entries: g.views.stacks,
          onClose: () => g.overlays.remove(GameOverlays.inventory),
        ),
        GameOverlays.equipment: (context, g) => EquipmentOverlay(
          snapshot: g.views.equipment,
          items: config.items,
          onEquip: g.equip,
          onUnequip: g.unequip,
          onClose: () => g.overlays.remove(GameOverlays.equipment),
        ),
        GameOverlays.character: (context, g) => CharacterOverlay(
          snapshot: g.views.characterView,
          onChooseSpecialization: g.chooseSpecialization,
          onUpgradeSkill: g.upgradeSkill,
          onClose: () => g.overlays.remove(GameOverlays.character),
        ),
        GameOverlays.settings: (context, g) => SettingsOverlay(
          settings: _audioService.settingsNotifier,
          onChanged: _updateSettings,
          onTestSfx: () => unawaited(_audioService.playSfx(AudioCue.loot)),
          onClose: () => g.overlays.remove(GameOverlays.settings),
        ),
        GameOverlays.runEnded: (context, _) {
          final failedDef = _dungeonManager?.activeDungeon;
          final isAscensionRun = failedDef?.isAscension ?? false;
          return RunEndedOverlay(
            subtitle: isAscensionRun
                ? 'Ascension Rank tidak berubah dan loot terkonfirmasi tetap disimpan.'
                : null,
            onRetry: () {
              unawaited(_flushSaveNow());
              _enterDungeon(config, dungeonId: failedDef?.id);
            },
            onReturnToTown: _returnToTown,
          );
        },
        GameOverlays.dungeonCompleted: (context, _) {
          final manager = _dungeonManager;
          final selectedId = _resolveSelectedDungeonId(config);
          final dungeon =
              manager?.activeDungeon ??
              (selectedId != null ? config.dungeons[selectedId] : null);
          final dungeonName = dungeon?.name ?? 'Dungeon';
          final clearedCount = manager?.session?.clearedRoomIds.length ?? 0;
          final isFinalBoss =
              dungeon != null &&
              dungeon.rooms.values.any(
                (room) => room.spawns.any(
                  (spawn) =>
                      config.monsters[spawn.monsterId]?.isFinalBoss == true,
                ),
              );
          final isAscension = dungeon?.isAscension ?? false;
          final ascResult = _lastAscensionResult;
          return DungeonCompletedOverlay(
            dungeonName: dungeonName,
            clearedRoomsCount: clearedCount,
            isFinalBoss: isFinalBoss,
            isAscension: isAscension,
            previousAscensionRank: isAscension ? ascResult?.previousRank : null,
            newAscensionRank: isAscension
                ? (ascResult?.newRank ?? _cycleProgress.ascensionRank)
                : null,
            completionReward: _lastCompletionReward,
            onRetry: isAscension
                ? null
                : () {
                    unawaited(_flushSaveNow());
                    _enterDungeon(
                      config,
                      dungeonId: manager?.activeDungeon?.id,
                    );
                  },
            onReturnToTown: _returnToTown,
          );
        },
      },
    );
  }
}
