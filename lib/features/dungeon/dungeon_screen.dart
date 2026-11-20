import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../application/providers/cloud_sync_provider.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/game_clock_provider.dart';
import '../../application/providers/game_config_provider.dart';
import '../../application/providers/notification_provider.dart';
import '../../application/services/account_service.dart';
import '../../application/services/cloud_sync_service.dart';
import '../../application/services/game_session_coordinator.dart';
import '../../core/perf/perf_tracer.dart';
import '../../domain/entities/altar_blessing.dart';
import '../../domain/entities/boss_spire.dart';
import '../../domain/entities/currency_config.dart';
import '../../domain/entities/cycle_progress.dart';
import '../../domain/entities/difficulty_config.dart';
import '../../domain/entities/dungeon_definition.dart';
import '../../domain/entities/dungeon_session.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/event_shop_purchase.dart';
import '../../domain/entities/gacha_config.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/entities/game_settings.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/infinite_spire.dart';
import '../../domain/entities/mystery_box.dart';
import '../../domain/entities/offline_activity.dart';
import '../../domain/entities/player_character.dart';
import '../../domain/entities/player_save_snapshot.dart';
import '../../domain/entities/player_status.dart';
import '../../domain/repositories/cloud_save_repository.dart';
import '../../domain/repositories/game_settings_repository.dart';
import '../../domain/services/altar_service.dart';
import '../../domain/services/ascension_service.dart';
import '../../domain/services/bag_expansion_service.dart';
import '../../domain/services/blacksmith_service.dart';
import '../../domain/services/boss_event_service.dart';
import '../../domain/services/boss_quest_service.dart';
import '../../domain/services/boss_spire_service.dart';
import '../../domain/services/currency_service.dart';
import '../../domain/services/difficulty_service.dart';
import '../../domain/services/dungeon_manager.dart';
import '../../domain/services/dungeon_progression_service.dart';
import '../../domain/services/encounter_tracker.dart';
import '../../domain/services/equipment_factory.dart';
import '../../domain/services/equipment_service.dart';
import '../../domain/services/event_shop_service.dart';
import '../../domain/services/gacha_service.dart';
import '../../domain/services/game_clock.dart';
import '../../domain/services/hero_ascension_service.dart';
import '../../domain/services/infinite_spire_service.dart';
import '../../domain/services/mystery_box_service.dart';
import '../../domain/services/offline_progression_service.dart';
import '../../domain/services/period_service.dart';
import '../../domain/services/reward_processor.dart';
import '../../domain/services/shop_service.dart';
import '../../domain/services/sync_planner.dart';
import '../../game/audio/audio_service.dart';
import '../../game/echoes_game.dart';
import '../../game/hud/inventory_views.dart';
import '../../game/overlays.dart';
import '../shared/widgets/shared_widgets.dart';
import 'altar_overlay.dart';
import 'blacksmith_overlay.dart';
import 'boss_events_overlay.dart';
import 'boss_hub_overlay.dart';
import 'character_overlay.dart';
import 'cloud_sync_section.dart';
import 'dungeon_completed_overlay.dart';
import 'equipment_overlay.dart';
import 'gacha_overlay.dart';
import 'hud_overlay.dart';
import 'infinite_spire_overlay.dart';
import 'inventory_overlay.dart';
import 'offline_summary_overlay.dart';
import 'run_ended_overlay.dart';
import 'settings_overlay.dart';
import 'town_hub_view.dart';
import '../../theme/app_theme.dart';

/// Layar utama gameplay: memuat konfigurasi & save data, menampilkan Town Hub,
/// lalu menjalankan game Flame saat pemain memasuki dungeon.
class DungeonScreen extends ConsumerStatefulWidget {
  const DungeonScreen({
    super.key,
    this.roomTransitionDelaySeconds = 1.0,
    this.onExitConfirmed,
  });

  final double roomTransitionDelaySeconds;
  final VoidCallback? onExitConfirmed;

  @override
  ConsumerState<DungeonScreen> createState() => _DungeonScreenState();
}

class _DungeonScreenState extends ConsumerState<DungeonScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final AnimationController _shakeController;
  // Karakter, inventory, dan pengaturan hidup lebih lama daripada satu run:
  // level, EXP, gold, item, equipment, specialization tetap ada ketika pemain
  // memulai run baru dan dipersistensikan lewat Drift/SQLite.
  PlayerCharacter? _character;
  Inventory? _inventory;
  InventoryViews? _views;
  EquipmentService? _equipmentService;
  CurrencyService? _currencyService;
  RewardProcessor? _rewardProcessor;
  DungeonManager? _dungeonManager;
  DungeonProgressSnapshot _dungeon = const DungeonProgressSnapshot();
  Map<String, DungeonProgressSnapshot> _dungeonProgresses = const {};
  CycleProgress _cycleProgress = const CycleProgress();
  String? _selectedDungeonId;
  ActiveDungeonSessionSnapshot? _lastSessionSnapshot;
  String? _preferredAutoFarmDungeonId;
  OfflineActivitySnapshot _offlineActivity =
      const OfflineActivitySnapshot.paused();
  int? _pendingRecoveredHp;
  Map<String, int> _pendingRecoveredSkillCooldowns = const {};
  GrantedReward? _lastCompletionReward;
  AscensionResult? _lastAscensionResult;
  BossQuestSettlementResult? _lastBossQuestResult;
  BossSpireSettlementResult? _lastBossSpireResult;
  InfiniteSpireSettlementResult? _lastInfiniteSpireResult;
  DifficultyProfile? _activeBossDifficultyProfile;
  bool _showBossEvents = false;
  bool _showBossSpire = false;
  bool _showInfiniteSpire = false;
  bool _showAltar = false;
  bool _showGacha = false;
  Map<String, GachaPityState> _gachaPityStates = {};
  Set<String> _unlockedSpecializations = {};
  InfiniteSpireProgressSnapshot _infiniteSpireProgress =
      const InfiniteSpireProgressSnapshot();
  BossQuestService _bossQuestService = BossQuestService();
  Map<String, int> _consecutiveDefeats = const {};
  String? _lastFailedDungeonId;
  Map<String, int> _shopPurchases = {};
  Map<(String, String), int> _eventShopPurchases = {};
  final Set<String> _processedEventShopActionIds = {};
  int _shopActionCounter = 0;
  final math.Random _shopRandom = math.Random();
  DungeonEventListener? _managerListener;
  GameSessionCoordinator? _coordinator;
  GameClock _clock = const SystemGameClock();
  GameSettingsRepository? _settingsRepo;
  final AudioService _audioService = AudioService();
  GameConfig? _config;
  int _lastOfflineClaimAtMs = 0;

  final ValueNotifier<bool> _autoSkill = ValueNotifier<bool>(true);
  EchoesGame? _game;
  bool _inDungeon = false;
  Timer? _saveDebounce;
  bool _dirty = false;
  bool _isSaving = false;
  bool _pendingSaveAfterCurrent = false;
  bool _initialized = false;
  Future<void>? _initFuture;
  Future<void>? _resumeFuture;
  CloudSyncService? _cloudSync;
  bool _cloudConflictDialogOpen = false;

  bool get _isDungeonRunActive =>
      _inDungeon && (_dungeonManager?.hasActiveSession ?? false);

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  void _triggerScreenShake() {
    if (mounted) {
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _cloudSync?.serverClockListener = null;
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
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached) {
        unawaited(_flushSaveAndMaybeSyncBackground());
      } else {
        unawaited(_flushSaveNow());
      }
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_audioService.resumeBgm());
      unawaited(_handleAppResumed());
    }
  }

  bool _isExiting = false;

  Future<void> _handleBackNavigation() async {
    if (!mounted || _isExiting) return;

    // 1. Tutup panel modal aktif di dalam dungeon jika ada.
    if (_inDungeon && _game != null) {
      for (final panel in GameOverlays.panels) {
        if (_game!.overlays.isActive(panel)) {
          _game!.overlays.remove(panel);
          return;
        }
      }
    }

    // 2. Tutup overlay aktif di Town jika ada.
    if (!_inDungeon) {
      if (_showBossEvents) {
        setState(() => _showBossEvents = false);
        return;
      }
      if (_showBossSpire) {
        setState(() => _showBossSpire = false);
        return;
      }
      if (_showAltar) {
        setState(() => _showAltar = false);
        return;
      }
      final pendingSummary = _offlineActivity.pendingSummary;
      if (pendingSummary != null && !pendingSummary.acknowledged) {
        _acknowledgeOfflineSummary();
        return;
      }
    }

    // 3. Tampilkan dialog konfirmasi keluar bergaya Living Aether Camp.
    final confirmed = await showEchoesDialog<bool>(
      context: context,
      title: 'Keluar Permainan?',
      icon: Icons.exit_to_app,
      accentColor: AppColors.antiqueGold,
      secondaryLabel: 'Lanjut Main',
      primaryLabel: 'Simpan & Keluar',
      child: Text(
        'Progres permainan Anda akan disimpan otomatis ke database sebelum keluar.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      ),
    );

    if (confirmed == true && mounted) {
      _isExiting = true;
      _showMessage('Menyimpan progres permainan...');
      try {
        await _flushSaveAndMaybeSyncBackground();
      } finally {
        if (widget.onExitConfirmed != null) {
          widget.onExitConfirmed!();
        } else {
          await SystemNavigator.pop();
        }
      }
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
        final cloud =
            _cloudSync ?? await _ensureCloudSyncInitialized(coordinator);
        if (cloud != null && cloud.accountService.current.isSignedIn) {
          await cloud.syncServerClock();
        }
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
          unawaited(
            _triggerCloudSync(SyncTrigger.appOpen, showConflictPrompt: true),
          );
          return;
        }

        _applyLoadedSession(config, loaded);

        if (status == OfflineProgressionStatus.noEligibleEncounter &&
            loaded.offlineResult.failureReason != null) {
          _showMessage(loaded.offlineResult.failureReason!);
        }
        unawaited(
          _triggerCloudSync(SyncTrigger.appOpen, showConflictPrompt: true),
        );
      } finally {
        _resumeFuture = null;
      }
    }();
    _resumeFuture = future;
    return future;
  }

  void _applyLoadedSession(
    GameConfig config,
    LoadedGameSession loaded, {
    bool resetTransientRewards = false,
  }) {
    _offlineActivity = loaded.offlineActivity;
    if (loaded.offlineActivity.selectedDungeonId != null) {
      _preferredAutoFarmDungeonId = loaded.offlineActivity.selectedDungeonId;
    }
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
    _eventShopPurchases = {
      for (final record in loaded.eventShopPurchases)
        (record.entryId, record.periodKey): record.purchasedCount,
    };
    _consecutiveDefeats = Map.of(loaded.session.consecutiveDefeats);
    _lastFailedDungeonId = loaded.session.lastFailedDungeonId;
    _lastSessionSnapshot = loaded.activeDungeonSession;
    _rewardProcessor = loaded.rewardProcessor;
    _currencyService = CurrencyService(
      definitions: _config?.currencies ?? CurrencyDefinition.defaults,
      initialBalances: loaded.currencies,
      claimedIds: loaded.rewardProcessor.claimedEventIds,
    );
    const altarService = AltarService();
    _character?.updateAltarBonus(
      altarService.getAltarStatBonus(_currencyService!.balances),
    );
    _rewardProcessor?.goldMultiplier =
        1.0 + altarService.getGoldBonusPercent(_currencyService!.balances);
    _bossQuestService = BossQuestService(
      initialStates: loaded.periodicQuestStates,
    );
    _gachaPityStates = Map<String, GachaPityState>.of(loaded.gachaPityStates);
    _unlockedSpecializations = Set<String>.of(loaded.unlockedSpecializations);
    _views?.setUnlockedSpecializations(_unlockedSpecializations);
    _infiniteSpireProgress = loaded.infiniteSpireProgress;
    _autoSkill.value = loaded.session.autoSkillEnabled;
    if (resetTransientRewards) {
      _lastCompletionReward = null;
      _lastAscensionResult = null;
      _lastBossQuestResult = null;
      _lastBossSpireResult = null;
      _lastInfiniteSpireResult = null;
      _activeBossDifficultyProfile = null;
      _showBossEvents = false;
      _showBossSpire = false;
      _showInfiniteSpire = false;
      _showAltar = false;
      _showGacha = false;
    }

    final manager = _dungeonManager;
    setState(() {
      if (manager != null && loaded.hasRecoverableDungeonSession) {
        _game?.detachSessionListeners();
        manager.exitToTown();
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
          _offlineActivity = _resolvedTownOfflineActivity(config);
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
        _offlineActivity = _resolvedTownOfflineActivity(config);
      }
    });
    if (!_inDungeon && !identical(_offlineActivity, loaded.offlineActivity)) {
      unawaited(_flushSaveNow());
    }
  }

  Future<CloudSyncService?> _ensureCloudSyncInitialized([
    GameSessionCoordinator? coordinator,
  ]) async {
    final activeCoordinator = coordinator ?? _coordinator;
    if (_cloudSync != null) {
      if (activeCoordinator != null) {
        _cloudSync!.serverClockListener = activeCoordinator.updateServerClock;
      }
      return _cloudSync;
    }
    try {
      final service = await ref.read(cloudSyncServiceProvider.future);
      if (!mounted) return null;
      if (activeCoordinator != null) {
        service.serverClockListener = activeCoordinator.updateServerClock;
      }
      _cloudSync = service;
      return service;
    } catch (_) {
      return null;
    }
  }

  Future<void> _startupCloudSync(GameSessionCoordinator coordinator) =>
      PerfTracer.traceAsync('CloudSync.startup', () async {
        final cloud = await _ensureCloudSyncInitialized(coordinator);
        if (cloud == null || !mounted) return;
        if (cloud.accountService.current.isSignedIn) {
          await cloud.syncServerClock();
          if (!mounted) return;
        }
        await _triggerCloudSync(SyncTrigger.appOpen, showConflictPrompt: true);
      });

  Future<void> _flushSaveAndMaybeSyncBackground() async {
    await _flushSaveNow();
    await _triggerCloudSync(SyncTrigger.background);
  }

  Future<void> _flushSaveThenCloudSync(SyncTrigger trigger) async {
    await _flushSaveNow();
    await _triggerCloudSync(trigger, showConflictPrompt: true);
  }

  Future<void> _triggerCloudSync(
    SyncTrigger trigger, {
    bool showConflictPrompt = false,
  }) async {
    final cloud = await _ensureCloudSyncInitialized();
    if (cloud == null || !mounted) return;
    try {
      final outcome = await cloud.sync(trigger);
      if (!mounted) return;
      if (showConflictPrompt &&
          (outcome.kind == SyncOutcomeKind.offerRestore ||
              outcome.kind == SyncOutcomeKind.conflict)) {
        final conflictKind = outcome.kind == SyncOutcomeKind.offerRestore
            ? CloudConflictKind.cloudAheadUnchanged
            : (outcome.status.conflictKind ?? CloudConflictKind.divergedSave);
        await _promptCloudConflict(conflictKind, outcome.cloudMeta);
      }
    } catch (_) {
      // Sinkronisasi cloud tidak boleh pernah menghentikan permainan lokal.
    }
  }

  Future<void> _promptCloudConflict(
    CloudConflictKind kind,
    CloudSaveMeta? cloudMeta,
  ) async {
    final config = _config;
    if (!mounted || config == null || _cloudConflictDialogOpen) return;
    _cloudConflictDialogOpen = true;
    try {
      final shouldRestore = await showCloudConflictDialog(
        context,
        kind: kind,
        cloudMeta: cloudMeta,
        isDungeonRunActive: _isDungeonRunActive,
      );
      if (!mounted) return;
      if (shouldRestore) {
        await _performCloudRestore(config);
      } else {
        _cloudSync?.dismissConflictPromptAndContinueLocal();
      }
    } finally {
      _cloudConflictDialogOpen = false;
    }
  }

  Future<void> _performCloudRestore(GameConfig config) async {
    final cloud = await _ensureCloudSyncInitialized();
    final coordinator = _coordinator;
    if (cloud == null || coordinator == null) {
      if (mounted) {
        _showMessage('Layanan cloud tidak tersedia untuk pemulihan.');
      }
      return;
    }

    final result = await cloud.restoreFromCloud(
      isDungeonRunActive: _isDungeonRunActive,
    );
    if (!mounted) return;

    switch (result) {
      case CloudRestoreSuccess(:final meta):
        _lastOfflineClaimAtMs = coordinator.effectiveClockMs;
        final reloaded = await coordinator.loadAndProcessOffline();
        if (!mounted) return;
        _applyLoadedSession(config, reloaded, resetTransientRewards: true);
        _dirty = false;
        _showMessage('Save cloud revisi ${meta.revision} berhasil dipulihkan.');
      case CloudRestoreBlockedActiveRun(:final message):
      case CloudRestoreNotFound(:final message):
      case CloudRestoreFailed(:final message):
        _showMessage(message);
    }
  }

  Widget _buildCloudSyncSection(GameConfig cfg) {
    return Consumer(
      builder: (context, widgetRef, _) {
        final status =
            widgetRef.watch(cloudSyncStatusProvider).asData?.value ??
            const CloudSyncStatusSnapshot.initial();
        return CloudSyncSection(
          status: status,
          isDungeonRunActive: _isDungeonRunActive,
          onSectionOpened: () => unawaited(() async {
            final cloud = await _ensureCloudSyncInitialized();
            if (cloud != null) {
              await cloud.openAccountSection();
            }
          }()),
          onLinkEmail: ({required email, required password}) async {
            final cloud = await _ensureCloudSyncInitialized();
            if (cloud == null) {
              return const EmailAuthFailed('Layanan cloud tidak tersedia.');
            }
            final outcome = await cloud.linkEmailAccount(
              email: email,
              password: password,
            );
            if (mounted && outcome is EmailAuthSuccess) {
              _showMessage('Akun email berhasil ditautkan.');
            }
            return outcome;
          },
          onSignInEmail: ({required email, required password}) async {
            final cloud = await _ensureCloudSyncInitialized();
            if (cloud == null) {
              return const EmailAuthFailed('Layanan cloud tidak tersedia.');
            }
            final outcome = await cloud.signInWithEmailAccount(
              email: email,
              password: password,
            );
            if (mounted && outcome is EmailAuthSuccess) {
              _showMessage('Berhasil masuk ke akun email.');
            }
            return outcome;
          },
          onResetPassword: ({required email}) async {
            final cloud = await _ensureCloudSyncInitialized();
            if (cloud == null) {
              return const PasswordResetFailed('Layanan cloud tidak tersedia.');
            }
            return cloud.sendPasswordReset(email: email);
          },
          onAccountSwitchConflict: () async {
            final meta = _cloudSync?.status.pendingCloudMeta;
            await _promptCloudConflict(CloudConflictKind.accountSwitch, meta);
          },
          onSignOut: () async {
            final cloud = await _ensureCloudSyncInitialized();
            await cloud?.signOut();
            if (mounted) {
              _showMessage('Keluar dari akun cloud. Save lokal dipertahankan.');
            }
          },
          onSyncNow: () async {
            await _flushSaveNow();
            await _triggerCloudSync(
              SyncTrigger.manual,
              showConflictPrompt: true,
            );
          },
          onConfirmRestore: () => _performCloudRestore(cfg),
        );
      },
    );
  }

  void _precacheUiAssets() {
    if (!mounted) return;
    const uiAssets = [
      'assets/ui/ui_atlas.png',
      'assets/ui/slot_dark.png',
      'assets/ui/slot_stone.png',
      'assets/ui/slot_gold_blue.png',
      'assets/ui/card_parchment_small.png',
      'assets/ui/frame_stone_dark.png',
      'assets/ui/frame_gold_ornate.png',
      'assets/ui/frame_parchment.png',
      'assets/ui/banner_dark.png',
      'assets/ui/bar_frame_gold.png',
    ];
    for (final asset in uiAssets) {
      precacheImage(AssetImage(asset), context).catchError((_) {});
    }
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
      _precacheUiAssets();
      final offlineService = ref.read(offlineProgressionServiceProvider);
      final clock = ref.read(gameClockProvider);
      _clock = clock;
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: config,
        offlineService: offlineService,
        clock: clock,
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
      _eventShopPurchases = {
        for (final record in loaded.eventShopPurchases)
          (record.entryId, record.periodKey): record.purchasedCount,
      };
      _consecutiveDefeats = Map.of(loaded.session.consecutiveDefeats);
      _lastFailedDungeonId = loaded.session.lastFailedDungeonId;
      _lastSessionSnapshot = loaded.activeDungeonSession;
      _offlineActivity = loaded.offlineActivity;
      if (loaded.offlineActivity.selectedDungeonId != null) {
        _preferredAutoFarmDungeonId = loaded.offlineActivity.selectedDungeonId;
      }
      _rewardProcessor = loaded.rewardProcessor;
      _currencyService = CurrencyService(
        definitions: config.currencies,
        initialBalances: loaded.currencies,
        claimedIds: loaded.rewardProcessor.claimedEventIds,
      );
      const altarService = AltarService();
      _character?.updateAltarBonus(
        altarService.getAltarStatBonus(_currencyService!.balances),
      );
      _rewardProcessor?.goldMultiplier =
          1.0 + altarService.getGoldBonusPercent(_currencyService!.balances);
      _bossQuestService = BossQuestService(
        initialStates: loaded.periodicQuestStates,
      );
      _gachaPityStates = Map<String, GachaPityState>.of(loaded.gachaPityStates);
      _unlockedSpecializations = Set<String>.of(loaded.unlockedSpecializations);
      _views?.setUnlockedSpecializations(_unlockedSpecializations);
      _lastOfflineClaimAtMs = loaded.offlineResult.newLastOfflineClaimAtMs;
      _autoSkill.value = loaded.session.autoSkillEnabled;
      final manager = config.dungeons.isNotEmpty
          ? DungeonManager(
              dungeons: config.dungeons,
              encounterTracker: EncounterTracker(
                monsterCatalog: config.monsters,
              ),
              clock: _clock,
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
          _offlineActivity = _resolvedTownOfflineActivity(config);
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
        _offlineActivity = _resolvedTownOfflineActivity(config);
      }

      _initialized = true;

      if (loaded.isFirstLaunch ||
          (!_inDungeon &&
              !identical(_offlineActivity, loaded.offlineActivity))) {
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
      unawaited(_startupCloudSync(coordinator));
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

  OfflineActivitySnapshot _resolvedTownOfflineActivity(
    GameConfig config, {
    bool keepContinueDungeon = false,
  }) {
    return _progressionService(config).resolveTownOfflineActivity(
      current: _offlineActivity,
      dungeons: config.dungeons.values,
      cycle: _cycleProgress,
      progresses: _progressMapWithCurrent(),
      checkpointAtMs: _clock.nowMs,
      preferredDungeonId: _preferredAutoFarmDungeonId,
      keepContinueDungeon: keepContinueDungeon,
    );
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
      _preferredAutoFarmDungeonId = dungeonId;
      _offlineActivity = _offlineActivity.withAutoFarming(
        dungeonId: dungeonId,
        checkpointAtMs: _clock.nowMs,
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
        checkpointAtMs: _clock.nowMs,
      );
    });
    unawaited(_flushSaveNow());
  }

  void _acknowledgeOfflineSummary() {
    final cfg = _config;
    setState(() {
      _offlineActivity = _offlineActivity.acknowledgePendingSummary();
      if (!_inDungeon && cfg != null) {
        _offlineActivity = _resolvedTownOfflineActivity(cfg);
      }
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
    final delay = _inDungeon
        ? const Duration(seconds: 12)
        : const Duration(seconds: 3);
    _saveDebounce = Timer(delay, () {
      unawaited(_flushSaveNow());
    });
  }

  Future<void> _flushSaveNow() async {
    _saveDebounce?.cancel();
    if (_isSaving) {
      _pendingSaveAfterCurrent = true;
      return;
    }
    _isSaving = true;
    try {
      do {
        _pendingSaveAfterCurrent = false;
        await _performSaveInternal();
      } while (_pendingSaveAfterCurrent);
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _performSaveInternal() =>
      PerfTracer.traceAsync('Autosave._performSaveInternal', () async {
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
            currencyService: _currencyService,
            periodicQuestStates: _bossQuestService.toSnapshot(),
            eventShopPurchases: _eventShopPurchaseRecords(),
            gachaPityStates: Map<String, GachaPityState>.unmodifiable(
              _gachaPityStates,
            ),
            unlockedSpecializations: Set<String>.unmodifiable(
              _unlockedSpecializations,
            ),
          );
        } catch (e) {
          _dirty = true;
          if (mounted) _showMessage('Gagal menyimpan progres: $e');
        }
      });

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

          if (dungeonDef?.isInfiniteSpire == true ||
              event.session.dungeonId.startsWith('infinite_spire')) {
            unawaited(_settleInfiniteSpireVictory(event, dungeonDef));
          } else if (dungeonDef?.isBossSpire == true ||
              event.session.dungeonId.startsWith('boss_spire')) {
            unawaited(_settleBossSpireVictory(event, dungeonDef));
          } else if (event.session.isBossEvent) {
            unawaited(_settleBossQuestVictory(event, dungeonDef));
          } else if (dungeonDef != null &&
              dungeonDef.isAscension &&
              cfg != null) {
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
            unawaited(_flushSaveThenCloudSync(SyncTrigger.ascension));
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
          bossEventId: event.session.bossEventId,
          periodKeyAtStart: event.session.periodKeyAtStart,
          playerStatus: event.finalStatus == DungeonSessionStatus.failed
              ? PlayerStatus.runEnded
              : PlayerStatus.alive,
        );
        if (cfg != null) {
          if (event.finalStatus == DungeonSessionStatus.completed &&
              dungeonDef != null &&
              dungeonDef.isNormal &&
              _preferredAutoFarmDungeonId == null) {
            _preferredAutoFarmDungeonId = event.session.dungeonId;
          }
          _offlineActivity = _resolvedTownOfflineActivity(cfg);
        } else if (_offlineActivity.mode ==
            OfflineActivityMode.continueDungeon) {
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

  void _toggleFavorite(String instanceId) {
    final service = _equipmentService;
    if (service != null && service.toggleFavorite(instanceId)) {
      _views?.refresh();
      unawaited(_flushSaveNow());
    }
  }

  BlacksmithEnhanceResult _handleEnhanceEquipment(String instanceId) {
    final char = _character;
    final inv = _inventory;
    if (char == null || inv == null) {
      return const BlacksmithEnhanceResult(
        status: BlacksmithEnhanceStatus.itemNotFound,
      );
    }
    const service = BlacksmithService();
    final result = service.enhanceEquipment(
      character: char,
      inventory: inv,
      instanceId: instanceId,
      loadout: char.loadout,
    );
    if (result.isSuccess) {
      _views?.refresh();
      unawaited(_flushSaveNow());
      unawaited(_audioService.playSfx(AudioCue.loot));
    }
    return result;
  }

  AltarUpgradeResult _handleUpgradeAltarBlessing(AltarBlessingType type) {
    final char = _character;
    final curr = _currencyService;
    if (char == null || curr == null) {
      return const AltarUpgradeResult(
        status: AltarUpgradeStatus.unknownBlessing,
      );
    }
    const service = AltarService();
    final result = service.upgradeBlessing(
      character: char,
      currencyService: curr,
      type: type,
    );
    if (result.isSuccess) {
      _rewardProcessor?.goldMultiplier =
          1.0 + service.getGoldBonusPercent(curr.balances);
      _views?.refresh();
      unawaited(_flushSaveNow());
      unawaited(_audioService.playSfx(AudioCue.loot));
    }
    return result;
  }

  Future<bool> _handleExpandBagCapacity() async {
    final char = _character;
    final curr = _currencyService;
    final inv = _inventory;
    if (char == null || curr == null || inv == null) return false;

    const service = BagExpansionService();
    final result = service.upgrade(
      character: char,
      currencyService: curr,
      inventory: inv,
    );

    if (result.isSuccess) {
      _views?.refresh();
      unawaited(_flushSaveNow());
      unawaited(_audioService.playSfx(AudioCue.loot));
      if (mounted) {
        setState(() {});
      }
      return true;
    }
    return false;
  }

  Future<void> _handleTestNotification() async {
    final scheduler = ref.read(notificationSchedulerProvider);
    await scheduler.requestPermission();
    await scheduler.sendTestNotification();
    if (!mounted) return;
    showAppNotification(
      context,
      message: 'Notifikasi tes dikirim! Periksa bilah status HP-mu.',
      kind: AppNotificationKind.success,
    );
  }

  Future<MysteryBoxOpenResult> _handleOpenMysteryBox(
    MysteryBoxTier tier,
    int count,
  ) async {
    final char = _character;
    final inv = _inventory;
    final cfg = _config;
    if (char == null || inv == null || cfg == null) {
      return const MysteryBoxOpenResult(
        status: MysteryBoxOpenStatus.unknownTier,
      );
    }
    final service = MysteryBoxService(
      items: cfg.items,
      equipmentFactory: EquipmentFactory(cfg.equipment),
    );
    final random = math.Random();
    final result = service.openBox(
      character: char,
      inventory: inv,
      tier: tier,
      count: count,
      random: random,
    );
    if (result.isSuccess) {
      _views?.refresh();
      await _flushSaveNow();
      unawaited(_audioService.playSfx(AudioCue.loot));
    }
    return result;
  }

  BlacksmithReforgeResult _handleReforgeEquipment(String instanceId) {
    final char = _character;
    final inv = _inventory;
    if (char == null || inv == null) {
      return const BlacksmithReforgeResult(
        status: BlacksmithReforgeStatus.itemNotFound,
      );
    }
    const service = BlacksmithService();
    final result = service.reforgeEquipment(
      character: char,
      inventory: inv,
      instanceId: instanceId,
      loadout: char.loadout,
    );
    if (result.isSuccess) {
      _views?.refresh();
      unawaited(_flushSaveNow());
      unawaited(_audioService.playSfx(AudioCue.loot));
    }
    return result;
  }

  BlacksmithSalvageResult _handleSalvageEquipment(String instanceId) {
    final char = _character;
    final inv = _inventory;
    if (char == null || inv == null) {
      return const BlacksmithSalvageResult(
        status: BlacksmithSalvageStatus.itemNotFound,
      );
    }
    const service = BlacksmithService();
    final result = service.salvageEquipment(
      inventory: inv,
      instanceId: instanceId,
      loadout: char.loadout,
    );
    if (result.isSuccess) {
      _views?.refresh();
      unawaited(_flushSaveNow());
      unawaited(_audioService.playSfx(AudioCue.loot));
    }
    return result;
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
    eventShopPurchases: Map.unmodifiable(_eventShopPurchases),
  );

  List<EventShopPurchaseRecord> _eventShopPurchaseRecords() => [
    for (final entry in _eventShopPurchases.entries)
      EventShopPurchaseRecord(
        entryId: entry.key.$1,
        periodKey: entry.key.$2,
        purchasedCount: entry.value,
      ),
  ];

  String _nextShopActionId(String kind) =>
      '${kind}_${_clock.nowMs}_${++_shopActionCounter}';

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

  EventShopService? _eventShopServiceFor(GameConfig cfg) {
    final eventShop = cfg.eventShop;
    if (eventShop == null) return null;
    return EventShopService(
      catalog: eventShop,
      items: cfg.items,
      equipmentFactory: EquipmentFactory(cfg.equipment),
    );
  }

  EventShopViewData? _eventShopViewDataFor(GameConfig cfg) {
    final service = _eventShopServiceFor(cfg);
    if (service == null) return null;
    final effectiveNowMs = _coordinator?.effectiveClockMs ?? _clock.nowMs;
    final balance = _currencyService?.balance(cfg.eventShop!.currencyId) ?? 0;
    final hasSpace = _inventory?.hasEquipmentSpace ?? false;
    return service.buildViewData(
      effectiveNowMs: effectiveNowMs,
      context: _shopContextFor(),
      currencyBalance: balance,
      goldBalance: _character?.gold ?? 0,
      inventory: _inventory,
      hasInventorySpace: hasSpace,
      purchaseCounts: _eventShopPurchases,
    );
  }

  Future<EventShopBuyResult> _buyFromEventShop(
    GameConfig cfg,
    String entryId,
  ) async {
    final character = _character;
    final inventory = _inventory;
    final currencyService = _currencyService;
    final service = _eventShopServiceFor(cfg);
    if (character == null ||
        inventory == null ||
        currencyService == null ||
        service == null) {
      return EventShopBuyNotFound(entryId: entryId);
    }
    final actionId = _nextShopActionId('event_buy');
    final effectiveNowMs = _coordinator?.effectiveClockMs ?? _clock.nowMs;
    final prevBalances = currencyService.toSnapshot();
    final prevClaims = currencyService.claimedIds;
    final periodKey = service.periodKeyAt(effectiveNowMs);
    final key = (entryId, periodKey);
    final prevCount = _eventShopPurchases[key];
    final result = service.buy(
      entryId: entryId,
      effectiveNowMs: effectiveNowMs,
      inventory: inventory,
      currencyService: currencyService,
      character: character,
      context: _shopContextFor(),
      random: _shopRandom,
      purchaseCounts: _eventShopPurchases,
      actionId: actionId,
      processedActionIds: _processedEventShopActionIds,
    );
    if (result is EventShopBuySuccess && !result.wasDuplicate) {
      try {
        await _coordinator?.saveEventShopTransaction(
          character: character,
          inventory: inventory,
          currencyService: currencyService,
          purchase: EventShopPurchaseRecord(
            entryId: entryId,
            periodKey: result.periodKey,
            purchasedCount: result.newPurchaseCount,
          ),
          actionId: actionId,
        );
      } catch (_) {
        currencyService.restoreState(
          balances: prevBalances,
          claimedIds: prevClaims,
        );
        if (result.goldSpent > 0) {
          character.addGold(result.goldSpent);
        }
        for (final mat in result.materialsSpent.entries) {
          inventory.add(mat.key, mat.value);
        }
        final eq = result.purchasedEquipment;
        if (eq != null) {
          inventory.removeEquipment(eq.id);
        }
        if (prevCount == null) {
          _eventShopPurchases.remove(key);
        } else {
          _eventShopPurchases[key] = prevCount;
        }
        _processedEventShopActionIds.remove(actionId);
        rethrow;
      }
      _views?.refresh();
      if (mounted) {
        setState(() {});
      }
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
      _offlineActivity = _resolvedTownOfflineActivity(config);
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
        clock: _clock,
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

  Future<void> _settleBossQuestVictory(
    DungeonEndedEvent event,
    DungeonDefinition? dungeonDef,
  ) async {
    final coordinator = _coordinator;
    final character = _character;
    final inventory = _inventory;
    final rewardProcessor = _rewardProcessor;
    final currencyService = _currencyService;
    final config = _config;
    if (coordinator == null ||
        character == null ||
        inventory == null ||
        rewardProcessor == null ||
        currencyService == null ||
        config == null ||
        config.bossEvents == null) {
      return;
    }
    final period = config.bossEvents!.periodForSession(
      dungeon: dungeonDef,
      bossEventId: event.session.bossEventId,
      dungeonId: event.session.dungeonId,
    );
    if (period == null) {
      return;
    }
    final periodKeyAtStart = event.session.periodKeyAtStart ?? '';
    final profile =
        _activeBossDifficultyProfile ??
        _dungeonManager?.activeDifficultyProfile ??
        DifficultyProfile.identity;
    try {
      final result = await coordinator.settleBossQuestVictory(
        period: period,
        periodKeyAtStart: periodKeyAtStart,
        difficultyProfile: profile,
        character: character,
        inventory: inventory,
        dungeon: _dungeon,
        dungeonProgresses: _dungeonProgresses,
        cycleProgress: _cycleProgress,
        rewardProcessor: rewardProcessor,
        currencyService: currencyService,
        bossQuestService: _bossQuestService,
        autoSkillEnabled: _autoSkill.value,
        lastOfflineClaimAtMs: _lastOfflineClaimAtMs,
        activeDungeonSession: _lastSessionSnapshot,
        offlineActivity: _offlineActivity,
        consecutiveDefeats: _consecutiveDefeats,
        lastFailedDungeonId: _lastFailedDungeonId,
      );
      if (!mounted) return;
      _views?.refresh();
      setState(() {
        _lastBossQuestResult = result;
      });
    } catch (e) {
      if (mounted) {
        _showMessage('Gagal memproses hadiah Boss Quest: $e');
      }
    }
  }

  Future<void> _settleBossSpireVictory(
    DungeonEndedEvent event,
    DungeonDefinition? dungeonDef,
  ) async {
    final coordinator = _coordinator;
    final character = _character;
    final inventory = _inventory;
    final rewardProcessor = _rewardProcessor;
    final currencyService = _currencyService;
    final config = _config;
    if (coordinator == null ||
        character == null ||
        inventory == null ||
        rewardProcessor == null ||
        currencyService == null ||
        config == null ||
        config.bossSpire == null) {
      return;
    }
    final rawFloor =
        dungeonDef?.order ??
        int.tryParse(
          event.session.dungeonId.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        1;
    final floorNumber = rawFloor < 1 ? 1 : rawFloor;
    try {
      final result = await coordinator.settleBossSpireVictory(
        floorNumber: floorNumber,
        character: character,
        inventory: inventory,
        dungeon: _dungeon,
        dungeonProgresses: _dungeonProgresses,
        cycleProgress: _cycleProgress,
        rewardProcessor: rewardProcessor,
        currencyService: currencyService,
        autoSkillEnabled: _autoSkill.value,
        lastOfflineClaimAtMs: _lastOfflineClaimAtMs,
        activeDungeonSession: _lastSessionSnapshot,
        offlineActivity: _offlineActivity,
        consecutiveDefeats: _consecutiveDefeats,
        lastFailedDungeonId: _lastFailedDungeonId,
      );
      if (!mounted) return;
      _views?.refresh();
      setState(() {
        _lastBossSpireResult = result;
      });
    } catch (e) {
      if (mounted) {
        _showMessage('Gagal memproses hadiah Menara Bos: $e');
      }
    }
  }

  Future<void> _settleInfiniteSpireVictory(
    DungeonEndedEvent event,
    DungeonDefinition? dungeonDef,
  ) async {
    final coordinator = _coordinator;
    final character = _character;
    final inventory = _inventory;
    final rewardProcessor = _rewardProcessor;
    final currencyService = _currencyService;
    final config = _config;
    if (coordinator == null ||
        character == null ||
        inventory == null ||
        rewardProcessor == null ||
        currencyService == null ||
        config == null ||
        config.infiniteSpire == null) {
      return;
    }
    final rawFloor =
        dungeonDef?.order ??
        int.tryParse(
          event.session.dungeonId.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        1;
    final floorNumber = rawFloor < 1 ? 1 : rawFloor;
    try {
      final result = await coordinator.settleInfiniteSpireVictory(
        floorNumber: floorNumber,
        character: character,
        inventory: inventory,
        dungeon: _dungeon,
        dungeonProgresses: _dungeonProgresses,
        cycleProgress: _cycleProgress,
        rewardProcessor: rewardProcessor,
        currencyService: currencyService,
        autoSkillEnabled: _autoSkill.value,
        lastOfflineClaimAtMs: _lastOfflineClaimAtMs,
        activeDungeonSession: _lastSessionSnapshot,
        offlineActivity: _offlineActivity,
        consecutiveDefeats: _consecutiveDefeats,
        lastFailedDungeonId: _lastFailedDungeonId,
        infiniteSpireProgress: _infiniteSpireProgress,
      );
      if (!mounted) return;
      _infiniteSpireProgress = result.updatedProgress;
      _views?.refresh();
      setState(() {
        _lastInfiniteSpireResult = result;
      });
    } catch (e) {
      if (mounted) {
        _showMessage('Gagal memproses hadiah The Infinite Spire: $e');
      }
    }
  }

  Future<HeroAscensionResult> _handleHeroAscension() async {
    final coordinator = _coordinator;
    final char = _character;
    final inv = _inventory;
    final curr = _currencyService;
    final rew = _rewardProcessor;
    if (coordinator == null ||
        char == null ||
        inv == null ||
        curr == null ||
        rew == null) {
      return const HeroAscensionResult(
        succeeded: false,
        previousPhase: 0,
        newPhase: 0,
        failureReason: HeroAscensionFailureReason.none,
      );
    }
    final result = await coordinator.executeHeroAscension(
      character: char,
      inventory: inv,
      currencyService: curr,
      dungeon: _dungeon,
      dungeonProgresses: _dungeonProgresses,
      cycleProgress: _cycleProgress,
      rewardProcessor: rew,
      autoSkillEnabled: _autoSkill.value,
      lastOfflineClaimAtMs: _lastOfflineClaimAtMs,
      offlineActivity: _offlineActivity,
      consecutiveDefeats: _consecutiveDefeats,
      lastFailedDungeonId: _lastFailedDungeonId,
      infiniteSpireProgress: _infiniteSpireProgress,
    );
    if (result.succeeded) {
      _views?.refresh();
      unawaited(_audioService.playSfx(AudioCue.loot));
    }
    return result;
  }

  Future<void> _enterBossRun(GameConfig config, Period period) async {
    final coordinator = _coordinator;
    final character = _character;
    final inventory = _inventory;
    final rewardProcessor = _rewardProcessor;
    final currencyService = _currencyService;
    if (coordinator == null ||
        character == null ||
        inventory == null ||
        rewardProcessor == null ||
        config.bossEvents == null) {
      _showMessage('Konfigurasi Boss Events tidak tersedia.');
      return;
    }
    var manager = _dungeonManager;
    if (manager == null) {
      manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: EncounterTracker(monsterCatalog: config.monsters),
        clock: _clock,
        difficultyService: DifficultyService(config.difficulty),
      );
      _dungeonManager = manager;
      _attachManagerListener(manager);
    }
    _game?.detachSessionListeners();
    manager.exitToTown();
    _lastCompletionReward = null;
    _lastAscensionResult = null;
    _lastBossQuestResult = null;
    _lastSessionSnapshot = null;
    _pendingRecoveredHp = null;
    _pendingRecoveredSkillCooldowns = const {};
    if (_offlineActivity.mode == OfflineActivityMode.autoFarming ||
        _offlineActivity.mode == OfflineActivityMode.continueDungeon) {
      _offlineActivity = _offlineActivity.withPauseProgression();
    }
    final prepared = await coordinator.startBossRun(
      period: period,
      dungeonManager: manager,
      character: character,
      inventory: inventory,
      dungeon: _dungeon,
      dungeonProgresses: _progressMapWithCurrent(),
      cycleProgress: _cycleProgress,
      rewardProcessor: rewardProcessor,
      autoSkillEnabled: _autoSkill.value,
      lastOfflineClaimAtMs: _lastOfflineClaimAtMs,
      currencyService: currencyService,
      offlineActivity: _offlineActivity,
      consecutiveDefeats: _consecutiveDefeats,
      lastFailedDungeonId: _lastFailedDungeonId,
      periodicQuestStates: _bossQuestService.toSnapshot(),
    );
    _activeBossDifficultyProfile = prepared.difficultyProfile;
    _lastSessionSnapshot = manager.toActiveSessionSnapshot();
    if (!mounted) return;
    setState(() {
      _showBossEvents = false;
      _game = _newGame(config);
      _inDungeon = true;
    });
  }

  Future<void> _enterSpireRun(GameConfig config, int floorNumber) async {
    final coordinator = _coordinator;
    final character = _character;
    final inventory = _inventory;
    final rewardProcessor = _rewardProcessor;
    final currencyService = _currencyService;
    if (coordinator == null ||
        character == null ||
        inventory == null ||
        rewardProcessor == null ||
        config.bossSpire == null) {
      _showMessage('Konfigurasi Menara Bos tidak tersedia.');
      return;
    }
    var manager = _dungeonManager;
    if (manager == null) {
      manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: EncounterTracker(monsterCatalog: config.monsters),
        clock: _clock,
        difficultyService: DifficultyService(config.difficulty),
      );
      _dungeonManager = manager;
      _attachManagerListener(manager);
    }
    _game?.detachSessionListeners();
    manager.exitToTown();
    _lastCompletionReward = null;
    _lastAscensionResult = null;
    _lastBossQuestResult = null;
    _lastBossSpireResult = null;
    _lastSessionSnapshot = null;
    _pendingRecoveredHp = null;
    _pendingRecoveredSkillCooldowns = const {};
    if (_offlineActivity.mode == OfflineActivityMode.autoFarming ||
        _offlineActivity.mode == OfflineActivityMode.continueDungeon) {
      _offlineActivity = _offlineActivity.withPauseProgression();
    }
    final prepared = await coordinator.startBossSpireRun(
      floorNumber: floorNumber,
      dungeonManager: manager,
      character: character,
      inventory: inventory,
      dungeon: _dungeon,
      dungeonProgresses: _progressMapWithCurrent(),
      cycleProgress: _cycleProgress,
      rewardProcessor: rewardProcessor,
      autoSkillEnabled: _autoSkill.value,
      lastOfflineClaimAtMs: _lastOfflineClaimAtMs,
      currencyService: currencyService,
      offlineActivity: _offlineActivity,
      consecutiveDefeats: _consecutiveDefeats,
      lastFailedDungeonId: _lastFailedDungeonId,
    );
    _activeBossDifficultyProfile = prepared.difficultyProfile;
    _lastSessionSnapshot = manager.toActiveSessionSnapshot();
    if (!mounted) return;
    setState(() {
      _showBossEvents = false;
      _showBossSpire = false;
      _game = _newGame(config);
      _inDungeon = true;
    });
  }

  Future<void> _enterInfiniteSpireRun(
    GameConfig config,
    int floorNumber,
  ) async {
    final coordinator = _coordinator;
    final character = _character;
    final inventory = _inventory;
    final rewardProcessor = _rewardProcessor;
    final currencyService = _currencyService;
    if (coordinator == null ||
        character == null ||
        inventory == null ||
        rewardProcessor == null ||
        currencyService == null ||
        config.infiniteSpire == null) {
      _showMessage('Konfigurasi The Infinite Spire tidak tersedia.');
      return;
    }
    var manager = _dungeonManager;
    if (manager == null) {
      manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: EncounterTracker(monsterCatalog: config.monsters),
        clock: _clock,
        difficultyService: DifficultyService(config.difficulty),
      );
      _dungeonManager = manager;
      _attachManagerListener(manager);
    }
    _game?.detachSessionListeners();
    manager.exitToTown();
    _lastCompletionReward = null;
    _lastAscensionResult = null;
    _lastBossQuestResult = null;
    _lastBossSpireResult = null;
    _lastInfiniteSpireResult = null;
    _lastSessionSnapshot = null;
    _pendingRecoveredHp = null;
    _pendingRecoveredSkillCooldowns = const {};
    if (_offlineActivity.mode == OfflineActivityMode.autoFarming ||
        _offlineActivity.mode == OfflineActivityMode.continueDungeon) {
      _offlineActivity = _offlineActivity.withPauseProgression();
    }
    await coordinator.startInfiniteSpireRun(
      floorNumber: floorNumber,
      dungeonManager: manager,
      character: character,
      inventory: inventory,
      dungeon: _dungeon,
      dungeonProgresses: _progressMapWithCurrent(),
      cycleProgress: _cycleProgress,
      rewardProcessor: rewardProcessor,
      autoSkillEnabled: _autoSkill.value,
      lastOfflineClaimAtMs: _lastOfflineClaimAtMs,
      currencyService: currencyService,
      offlineActivity: _offlineActivity,
      consecutiveDefeats: _consecutiveDefeats,
      lastFailedDungeonId: _lastFailedDungeonId,
      infiniteSpireProgress: _infiniteSpireProgress,
    );
    _lastSessionSnapshot = manager.toActiveSessionSnapshot();
    if (!mounted) return;
    setState(() {
      _showInfiniteSpire = false;
      _game = _newGame(config);
      _inDungeon = true;
    });
  }

  Widget _buildInfiniteSpireOverlay(GameConfig config) {
    final spireConfig = config.infiniteSpire;
    if (spireConfig == null) return const SizedBox.shrink();
    return InfiniteSpireOverlay(
      config: spireConfig,
      progress: _infiniteSpireProgress,
      playerLevel: _character?.level ?? 1,
      onFightFloor: (floor) => unawaited(_enterInfiniteSpireRun(config, floor)),
      onClose: () => setState(() => _showInfiniteSpire = false),
    );
  }

  Widget _buildBossHubOverlay(GameConfig config) {
    final nowMs = _coordinator?.effectiveClockMs ?? _clock.nowMs;
    final periodService = PeriodService(config: config.time);

    BossEventCardData? dailyCard;
    BossEventCardData? weeklyCard;
    final bossEvents = config.bossEvents;
    if (bossEvents != null) {
      final bossService = BossEventService(bossEvents);
      final ref = bossService.resolveReference(
        _cycleProgress,
        _progressMapWithCurrent(),
        config.dungeons,
      );
      final diffService = DifficultyService(config.difficulty);
      final profile = diffService.profileFor(ref.dungeon, ref.cycleRank);

      BossEventCardData buildCard(Period period, String label) {
        final tier = bossEvents.tierFor(period);
        final index = period == Period.daily
            ? periodService.dayIndex(nowMs)
            : periodService.weekIndex(nowMs);
        final key = periodService.keyFor(period, nowMs);
        final boss = bossService.bossFor(period, index);
        final nextResetMs = periodService.nextResetMs(period, nowMs);
        final remaining = Duration(
          milliseconds: math.max(0, nextResetMs - nowMs),
        );
        final scaled = BossQuestService.computeScaledReward(
          reward: tier.reward,
          difficultyProfile: profile,
        );
        final isDone = _bossQuestService.isCompleted(tier.questId, key);
        return BossEventCardData(
          periodKeyId: period.name,
          periodLabel: label,
          bossName: boss.name,
          referenceDungeonName: ref.dungeon.name,
          recommendedLevel: ref.dungeon.recommendedLevel,
          isCompleted: isDone,
          remainingToReset: remaining,
          rewardSummary:
              '${scaled.aetherShard} Aether Shard • ${scaled.gold} Gold • ${scaled.exp} EXP',
          onFight: () => unawaited(_enterBossRun(config, period)),
        );
      }

      dailyCard = buildCard(Period.daily, 'Daily Boss');
      weeklyCard = buildCard(Period.weekly, 'Weekly Boss');
    }

    final spireConfig = config.bossSpire;
    BossSpireProgress? spireProgress;
    Duration? spireRemaining;
    if (spireConfig != null) {
      final spireService = BossSpireService(spireConfig);
      final cycleKey = periodService.biweeklyKey(nowMs);
      final nextResetMs = periodService.nextBiweeklyResetMs(nowMs);
      spireRemaining = Duration(
        milliseconds: math.max<int>(0, nextResetMs - nowMs),
      );
      final claimedIds = _rewardProcessor?.claimedEventIds ?? const <String>{};
      spireProgress = spireService.getProgress(claimedIds, cycleKey: cycleKey);
    }

    return BossHubOverlay(
      daily: dailyCard,
      weekly: weeklyCard,
      spireConfig: spireConfig,
      spireProgress: spireProgress,
      playerLevel: _character?.level ?? 1,
      spireRemainingToReset: spireRemaining,
      onFightSpireFloor: spireConfig != null
          ? (floor) => unawaited(_enterSpireRun(config, floor))
          : null,
      initialTab: _showBossSpire && !_showBossEvents ? 1 : 0,
      onClose: () => setState(() {
        _showBossEvents = false;
        _showBossSpire = false;
      }),
    );
  }

  Widget _buildAltarOverlay(GameConfig config) {
    final views = _views;
    if (views == null) return const SizedBox.shrink();
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _showAltar = false),
            child: Container(color: Colors.black54),
          ),
        ),
        AltarOverlay(
          characterSnapshot: views.characterView,
          getBalances: () => _currencyService?.balances ?? const {},
          onUpgradeBlessing: _handleUpgradeAltarBlessing,
          onClose: () => setState(() => _showAltar = false),
        ),
      ],
    );
  }

  GachaService? _gachaServiceFor(GameConfig cfg) {
    final gachaConfig = cfg.gacha;
    if (gachaConfig == null) return null;
    return GachaService(
      gachaConfig: gachaConfig,
      items: cfg.items,
      specializations: cfg.specializations.definitions,
      equipmentFactory: EquipmentFactory(cfg.equipment),
      periodService: const PeriodService(),
    );
  }

  PlayerSaveSnapshot _currentGachaSnapshot() {
    final char = _character!;
    final inv = _inventory!;
    return PlayerSaveSnapshot(
      character: char.toSnapshot(),
      inventory: inv.toSnapshot(),
      dungeon: _dungeon,
      dungeonProgresses: Map<String, DungeonProgressSnapshot>.unmodifiable(
        _dungeonProgresses,
      ),
      cycleProgress: _cycleProgress,
      currencies: _currencyService?.toSnapshot() ?? const {},
      gachaPityStates: Map<String, GachaPityState>.unmodifiable(
        _gachaPityStates,
      ),
      unlockedSpecializations: Set<String>.unmodifiable(
        _unlockedSpecializations,
      ),
    );
  }

  void _applyGachaSnapshot(PlayerSaveSnapshot updated) {
    _inventory?.restore(updated.inventory);
    _currencyService?.restoreState(
      balances: updated.currencies,
      claimedIds: _currencyService?.claimedIds ?? const {},
    );
    _gachaPityStates = Map<String, GachaPityState>.of(updated.gachaPityStates);
    _unlockedSpecializations = Set<String>.of(updated.unlockedSpecializations);
    _views?.setUnlockedSpecializations(_unlockedSpecializations);
    unawaited(_flushSaveNow());
    if (mounted) {
      setState(() {});
    }
  }

  Future<GachaPullSessionResult> _handleGachaPull(
    GameConfig cfg,
    GachaBannerType bannerType,
    int count,
  ) async {
    final service = _gachaServiceFor(cfg);
    if (service == null || _character == null || _inventory == null) {
      return GachaPullSessionResult(
        status: GachaPullStatus.bannerNotFound,
        bannerType: bannerType,
      );
    }
    final nowMs = _coordinator?.effectiveClockMs ?? _clock.nowMs;
    final snap = _currentGachaSnapshot();
    final result = count == 10
        ? service.pullTen(
            snapshot: snap,
            bannerType: bannerType,
            nowMs: nowMs,
            random: _shopRandom,
          )
        : service.pullOnce(
            snapshot: snap,
            bannerType: bannerType,
            nowMs: nowMs,
            random: _shopRandom,
          );
    if (result.isSuccess && result.updatedSnapshot != null) {
      _applyGachaSnapshot(result.updatedSnapshot!);
      unawaited(_audioService.playSfx(AudioCue.loot));
    }
    return result;
  }

  Future<SanctuaryExchangeResult> _handleSanctuaryExchangeWeapon(
    GameConfig cfg,
    String weaponId,
  ) async {
    final service = _gachaServiceFor(cfg);
    if (service == null || _character == null || _inventory == null) {
      return const SanctuaryExchangeResult(
        status: SanctuaryExchangeStatus.invalidTarget,
      );
    }
    final result = service.exchangeSanctuaryWeapon(
      snapshot: _currentGachaSnapshot(),
      weaponId: weaponId,
      random: _shopRandom,
    );
    if (result.isSuccess && result.updatedSnapshot != null) {
      _applyGachaSnapshot(result.updatedSnapshot!);
      unawaited(_audioService.playSfx(AudioCue.loot));
    }
    return result;
  }

  Future<SanctuaryExchangeResult> _handleSanctuaryExchangeClass(
    GameConfig cfg,
    String classId,
  ) async {
    final service = _gachaServiceFor(cfg);
    if (service == null || _character == null || _inventory == null) {
      return const SanctuaryExchangeResult(
        status: SanctuaryExchangeStatus.invalidTarget,
      );
    }
    final result = service.exchangeSanctuaryClass(
      snapshot: _currentGachaSnapshot(),
      classId: classId,
    );
    if (result.isSuccess && result.updatedSnapshot != null) {
      _applyGachaSnapshot(result.updatedSnapshot!);
      unawaited(_audioService.playSfx(AudioCue.loot));
    }
    return result;
  }

  Widget _buildGachaOverlay(GameConfig config) {
    final service = _gachaServiceFor(config);
    if (service == null) return const SizedBox.shrink();
    final nowMs = _coordinator?.effectiveClockMs ?? _clock.nowMs;
    final shards = _currencyService?.balance(kAetherShardCurrencyId) ?? 0;
    final prisms = _currencyService?.balance(kSoulPrismCurrencyId) ?? 0;
    return GachaOverlay(
      gachaService: service,
      aetherShards: shards,
      soulPrisms: prisms,
      pityStates: _gachaPityStates,
      unlockedSpecializations: _unlockedSpecializations,
      nowMs: nowMs,
      onPull: (bannerType, count) =>
          _handleGachaPull(config, bannerType, count),
      onExchangeWeapon: (weaponId) =>
          _handleSanctuaryExchangeWeapon(config, weaponId),
      onExchangeClass: (classId) =>
          _handleSanctuaryExchangeClass(config, classId),
      onClose: () => setState(() => _showGacha = false),
    );
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
      if (cfg != null) {
        _offlineActivity = _resolvedTownOfflineActivity(cfg);
      } else if (_offlineActivity.mode == OfflineActivityMode.continueDungeon) {
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        body: SafeArea(
          child: config.when(
            data: (cfg) => FutureBuilder<void>(
              future: _ensureInitialized(cfg),
              builder: (context, snapshot) {
                if (!_initialized &&
                    snapshot.connectionState != ConnectionState.done) {
                  return const LoadingState(title: 'Menyiapkan Camp Aether...');
                }
                if (snapshot.hasError && !_initialized) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: PanelFrame(
                          showCornerOrnaments: true,
                          borderColor: AppColors.emberRed,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.emberRed,
                                size: 32,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Gagal menginisialisasi data progres:\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
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
                        onSwitchCycleRank: (rank) =>
                            _switchCycleRank(cfg, rank),
                        onEquip: _equip,
                        onUnequip: _unequip,
                        onToggleFavorite: _toggleFavorite,
                        bagLevelProvider: () =>
                            _currencyService?.balance(
                              kBagExpansionCurrencyId,
                            ) ??
                            0,
                        onExpandBag: _handleExpandBagCapacity,
                        onChooseSpecialization: _chooseSpecialization,
                        onUpgradeSkill: _upgradeSkill,
                        settings: _audioService.settingsNotifier,
                        onSettingsChanged: _updateSettings,
                        onTestSfx: () =>
                            unawaited(_audioService.playSfx(AudioCue.loot)),
                        offlineActivity: _offlineActivity,
                        availableDungeons: cfg.dungeons,
                        dungeonProgresses: _dungeonProgresses,
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
                        eventShopData: _eventShopViewDataFor(cfg),
                        onEventShopBuy: cfg.eventShop != null
                            ? (entryId) => _buyFromEventShop(cfg, entryId)
                            : null,
                        aetherShard:
                            _currencyService?.balance(kAetherShardCurrencyId) ??
                            0,
                        onOpenBossEvents:
                            (cfg.bossEvents != null || cfg.bossSpire != null)
                            ? () => setState(() => _showBossEvents = true)
                            : null,
                        onOpenBossSpire: cfg.bossSpire != null
                            ? () => setState(() => _showBossSpire = true)
                            : null,
                        onRequestNotificationPermission: () => ref
                            .read(notificationSchedulerProvider)
                            .requestPermission(),
                        onTestNotification: _handleTestNotification,
                        cloudSyncSection: _buildCloudSyncSection(cfg),
                        onEnhanceEquipment: _handleEnhanceEquipment,
                        onReforgeEquipment: _handleReforgeEquipment,
                        onSalvageEquipment: _handleSalvageEquipment,
                        getAltarBalances: () =>
                            _currencyService?.balances ?? const {},
                        onUpgradeAltarBlessing: _handleUpgradeAltarBlessing,
                        onOpenAltar: () => setState(() => _showAltar = true),
                        onOpenGacha: cfg.gacha != null
                            ? () => setState(() => _showGacha = true)
                            : null,
                        onOpenMysteryBox: _handleOpenMysteryBox,
                        onOpenInfiniteSpire: cfg.infiniteSpire != null
                            ? () => setState(() => _showInfiniteSpire = true)
                            : null,
                        onAscendHero: _handleHeroAscension,
                        inventoryQuantitiesProvider: () => {
                          for (final stack
                              in (_inventory?.snapshot() ?? const []))
                            stack.definitionId: stack.quantity,
                        },
                        currenciesProvider: () =>
                            _currencyService?.balances ?? const {},
                      )
                    : _buildGame(cfg);
                final pendingSummary = _offlineActivity.pendingSummary;
                final showOfflineSummary =
                    pendingSummary != null && !pendingSummary.acknowledged;
                return Stack(
                  children: [
                    content,
                    if (!_inDungeon &&
                        (_showBossEvents || _showBossSpire) &&
                        (cfg.bossEvents != null || cfg.bossSpire != null))
                      _buildBossHubOverlay(cfg),
                    if (!_inDungeon && _showAltar) _buildAltarOverlay(cfg),
                    if (!_inDungeon && _showGacha && cfg.gacha != null)
                      _buildGachaOverlay(cfg),
                    if (!_inDungeon &&
                        _showInfiniteSpire &&
                        cfg.infiniteSpire != null)
                      _buildInfiniteSpireOverlay(cfg),
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
            loading: () =>
                const LoadingState(title: 'Memuat Konfigurasi Dunia...'),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: PanelFrame(
                    showCornerOrnaments: true,
                    borderColor: AppColors.emberRed,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.emberRed,
                          size: 32,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Gagal memuat konfigurasi game:\n$error',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
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
    dungeonBiome: _dungeonManager?.activeDungeon?.biome,
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

  Widget _compactChipButton({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? accentColor,
  }) {
    final gold = AppTheme.gold;
    final isExpanded = icon == Icons.close;
    final effectiveIcon = isExpanded ? Icons.close : Icons.settings;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF161F32), Color(0xFF090D16)],
          ),
          border: Border.all(color: gold.withValues(alpha: 0.80), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: 0.35),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          key: key,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(effectiveIcon, size: 16, color: gold),
                const SizedBox(width: 5),
                Text(
                  isExpanded ? 'Tutup' : 'Menu',
                  style: AppTheme.headingFantasy(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: gold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGame(GameConfig config) {
    final game = _game ??= _newGame(config);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final val = _shakeController.value;
          final offset = _shakeController.isAnimating
              ? Offset(
                  math.sin(val * math.pi * 6) * 3.0 * (1.0 - val),
                  math.cos(val * math.pi * 4) * 2.0 * (1.0 - val),
                )
              : Offset.zero;
          return Transform.translate(offset: offset, child: child);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background cave texture to eliminate dead space around/behind dungeon grid
            Positioned.fill(
              child: Image.asset(
                'assets/ui/dungeon_floor_crystal.png',
                fit: BoxFit.cover,
                repeat: ImageRepeat.repeat,
                color: const Color(0xFF090D16).withValues(alpha: 0.90),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0D111E), Color(0xFF070A10)],
                    ),
                  ),
                ),
              ),
            ),
            // Atmospheric dungeon cave ambient vignette
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.15,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.68),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: GameWidget<EchoesGame>(
                key: ObjectKey(game), // game baru = widget baru
                game: game,
                initialActiveOverlays: const [
                  GameOverlays.hud,
                  GameOverlays.menuButtons,
                ],
                overlayBuilderMap: {
                  GameOverlays.hud: (context, g) => RepaintBoundary(
                    child: HudOverlay(
                      state: g.hud,
                      onSkillTap: (_) => _triggerScreenShake(),
                    ),
                  ),
                  GameOverlays.menuButtons: (context, g) {
                    final continueOffline =
                        _offlineActivity.mode ==
                            OfflineActivityMode.continueDungeon &&
                        !_offlineActivity.isPaused;
                    return RepaintBoundary(
                      child: _DungeonCompactMenuCluster(
                        game: g,
                        continueOffline: continueOffline,
                        onToggleAutoSkill: (on) {
                          g.autoSkill.value = !on;
                          unawaited(_flushSaveNow());
                        },
                        onToggleOffline: continueOffline
                            ? _selectPauseOffline
                            : _selectContinueDungeon,
                        onTogglePanel: (panel) => _togglePanel(g, panel),
                        onReturnToTown: _returnToTown,
                        chipBuilder: _compactChipButton,
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
                    onToggleFavorite: g.toggleFavorite,
                    bagLevelProvider: () =>
                        _currencyService?.balance(kBagExpansionCurrencyId) ?? 0,
                    playerGoldProvider: () => _character?.gold ?? 0,
                    onExpandBag: _handleExpandBagCapacity,
                    onClose: () => g.overlays.remove(GameOverlays.equipment),
                  ),
                  GameOverlays.character: (context, g) => CharacterOverlay(
                    snapshot: g.views.characterView,
                    onChooseSpecialization: g.chooseSpecialization,
                    onUpgradeSkill: g.upgradeSkill,
                    onAscendHero: _handleHeroAscension,
                    inventoryQuantitiesProvider: () => {
                      for (final stack in (_inventory?.snapshot() ?? const []))
                        stack.definitionId: stack.quantity,
                    },
                    currenciesProvider: () =>
                        _currencyService?.balances ?? const {},
                    onClose: () => g.overlays.remove(GameOverlays.character),
                  ),
                  GameOverlays.settings: (context, g) => SettingsOverlay(
                    settings: _audioService.settingsNotifier,
                    onChanged: _updateSettings,
                    onTestSfx: () =>
                        unawaited(_audioService.playSfx(AudioCue.loot)),
                    onRequestNotificationPermission: () => ref
                        .read(notificationSchedulerProvider)
                        .requestPermission(),
                    onTestNotification: _handleTestNotification,
                    cloudSyncSection: _buildCloudSyncSection(config),
                    onClose: () => g.overlays.remove(GameOverlays.settings),
                  ),
                  GameOverlays.blacksmith: (context, g) => BlacksmithOverlay(
                    snapshot: g.views.equipment,
                    items: config.items,
                    inventoryEntries: g.views.stacks,
                    characterSnapshot: g.views.characterView,
                    onEnhanceEquipment: _handleEnhanceEquipment,
                    onReforgeEquipment: _handleReforgeEquipment,
                    onSalvageEquipment: _handleSalvageEquipment,
                    onClose: () => g.overlays.remove(GameOverlays.blacksmith),
                  ),
                  GameOverlays.altar: (context, g) => AltarOverlay(
                    characterSnapshot: g.views.characterView,
                    getBalances: () => _currencyService?.balances ?? const {},
                    onUpgradeBlessing: _handleUpgradeAltarBlessing,
                    onClose: () => g.overlays.remove(GameOverlays.altar),
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
                        (selectedId != null
                            ? config.dungeons[selectedId]
                            : null);
                    final dungeonName = dungeon?.name ?? 'Dungeon';
                    final clearedCount =
                        manager?.session?.clearedRoomIds.length ?? 0;
                    final isFinalBoss =
                        dungeon != null &&
                        dungeon.rooms.values.any(
                          (room) => room.spawns.any(
                            (spawn) =>
                                config.monsters[spawn.monsterId]?.isFinalBoss ==
                                true,
                          ),
                        );
                    final isAscension = dungeon?.isAscension ?? false;
                    final isBossEvent = dungeon?.isBossEvent ?? false;
                    final isBossSpire = dungeon?.isBossSpire ?? false;
                    final isInfiniteSpire = dungeon?.isInfiniteSpire ?? false;
                    final ascResult = _lastAscensionResult;
                    return DungeonCompletedOverlay(
                      dungeonName: dungeonName,
                      clearedRoomsCount: clearedCount,
                      isFinalBoss: isFinalBoss,
                      isAscension: isAscension,
                      previousAscensionRank: isAscension
                          ? ascResult?.previousRank
                          : null,
                      newAscensionRank: isAscension
                          ? (ascResult?.newRank ?? _cycleProgress.ascensionRank)
                          : null,
                      completionReward: _lastCompletionReward,
                      bossQuestMessage: isInfiniteSpire
                          ? (_lastInfiniteSpireResult?.userMessage ??
                                'Lantai Infinite Spire Selesai!')
                          : (isBossSpire
                                ? (_lastBossSpireResult?.userMessage ??
                                      'Menara Bos Selesai!')
                                : (isBossEvent
                                      ? (_lastBossQuestResult?.userMessage ??
                                            'Memproses hadiah boss quest...')
                                      : null)),
                      onRetry:
                          (isAscension ||
                              isBossEvent ||
                              isBossSpire ||
                              isInfiniteSpire)
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DungeonCompactMenuCluster extends StatefulWidget {
  const _DungeonCompactMenuCluster({
    required this.game,
    required this.continueOffline,
    required this.onToggleAutoSkill,
    required this.onToggleOffline,
    required this.onTogglePanel,
    required this.onReturnToTown,
    required this.chipBuilder,
  });

  final EchoesGame game;
  final bool continueOffline;
  final void Function(bool current) onToggleAutoSkill;
  final VoidCallback onToggleOffline;
  final void Function(String panel) onTogglePanel;
  final VoidCallback onReturnToTown;
  final Widget Function({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? accentColor,
  })
  chipBuilder;

  @override
  State<_DungeonCompactMenuCluster> createState() =>
      _DungeonCompactMenuClusterState();
}

class _DungeonCompactMenuClusterState
    extends State<_DungeonCompactMenuCluster> {
  bool _expanded = false;

  void _openPanel(String panel) {
    setState(() => _expanded = false);
    widget.onTogglePanel(panel);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (MediaQuery.sizeOf(context).width * 0.68).clamp(
              180.0,
              320.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_expanded) ...[
                PanelFrame(
                  key: const Key('hud_menu_drawer'),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  backgroundColor: const Color(0xF20B0E17),
                  borderColor: AppTheme.gold.withValues(alpha: 0.78),
                  showCornerOrnaments: true,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.75),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Text(
                          'Menu Dungeon',
                          style: AppTypography.headingSerif(
                            (theme.textTheme.labelSmall ?? const TextStyle())
                                .copyWith(fontSize: 11),
                            color: ext.gold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<bool>(
                        valueListenable: widget.game.autoSkill,
                        builder: (context, on, _) => _drawerItem(
                          key: const Key('hud_auto_skill_button'),
                          icon: on ? Icons.flash_on : Icons.flash_off,
                          label: 'Auto Skill: ${on ? 'ON' : 'OFF'}',
                          color: on ? ext.expBar : AppColors.textSecondary,
                          onTap: () => widget.onToggleAutoSkill(on),
                        ),
                      ),
                      _drawerItem(
                        key: const Key('hud_offline_button'),
                        icon: widget.continueOffline
                            ? Icons.play_circle_outline
                            : Icons.pause_circle_outline,
                        label: widget.continueOffline
                            ? 'Lanjut Offline: ON'
                            : 'Lanjut Offline: OFF',
                        subtitle: 'Saat aplikasi ditutup',
                        color: widget.continueOffline
                            ? ext.success
                            : AppColors.textSecondary,
                        onTap: widget.onToggleOffline,
                      ),
                      const Divider(height: 10),
                      _drawerItem(
                        icon: Icons.inventory_2_outlined,
                        label: 'Tas',
                        onTap: () => _openPanel(GameOverlays.inventory),
                      ),
                      _drawerItem(
                        icon: Icons.shield_outlined,
                        label: 'Perlengkapan',
                        onTap: () => _openPanel(GameOverlays.equipment),
                      ),
                      _drawerItem(
                        icon: Icons.auto_awesome_outlined,
                        label: 'Karakter',
                        onTap: () => _openPanel(GameOverlays.character),
                      ),
                      _drawerItem(
                        icon: Icons.settings_outlined,
                        label: 'Pengaturan',
                        onTap: () => _openPanel(GameOverlays.settings),
                      ),
                      const Divider(height: 10),
                      _drawerItem(
                        icon: Icons.home_outlined,
                        label: 'Kembali ke Town',
                        color: ext.gold,
                        onTap: () {
                          setState(() => _expanded = false);
                          widget.onReturnToTown();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              widget.chipBuilder(
                key: const Key('hud_menu_toggle_button'),
                icon: _expanded ? Icons.close : Icons.menu,
                label: 'Menu',
                accentColor: ext.gold,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem({
    Key? key,
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    Color color = AppColors.textPrimary,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
