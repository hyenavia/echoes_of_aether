import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/experimental.dart' show Rectangle;
import 'package:flame/game.dart' show FlameGame;
import 'package:flutter/foundation.dart' show ValueNotifier, VoidCallback;

import '../../core/constants/game_constants.dart';
import '../../core/constants/test_room.dart';
import '../../domain/entities/combatant.dart';
import '../../domain/entities/dungeon_definition.dart';
import '../../domain/entities/dungeon_session.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/entities/grid_point.dart';
import '../../domain/entities/player_character.dart';
import '../../domain/services/astar_pathfinder.dart';
import '../../domain/services/combat_simulation.dart';
import '../../domain/services/difficulty_service.dart';
import '../../domain/services/dungeon_manager.dart';
import '../../domain/services/navigation_grid.dart';
import '../../domain/services/reward_processor.dart';
import '../audio/audio_service.dart';
import '../components/effects/floating_text_component.dart';
import '../components/effects/room_transition_curtain.dart';
import '../components/effects/skill_vfx_component.dart';
import '../components/enemies/enemy_component.dart';
import '../components/player/player_component.dart';
import '../hud/hud_state.dart';
import '../hud/inventory_views.dart';
import '../systems/combat_system.dart';
import 'debug_room_component.dart';

/// Dunia dungeon (GDD 12.2).
class DungeonWorld extends World {
  DungeonWorld({
    required this.config,
    required this.character,
    required this.views,
    required this.hud,
    required this.autoSkill,
    this.dungeonManager,
    this.roomLayout = TestRoom.layout,
    this.playerStart = TestRoom.playerStart,
    this.roomTransitionDelaySeconds = 1.0,
    this.rewardProcessor,
    this.onProgressionChanged,
    this.onCriticalSaveRequired,
    this.onDungeonRewardSettled,
    this.initialPlayerHp,
    this.initialReviveCooldownTicks = 0,
    this.initialSkillCooldownTicks = const {},
    this.simulationSeed,
    this.audioService,
    this.difficultyProfile,
  });

  final GameConfig config;
  final PlayerCharacter character;
  final InventoryViews views;
  final ValueNotifier<HudState> hud;
  final ValueNotifier<bool> autoSkill;
  final DungeonManager? dungeonManager;
  final List<String> roomLayout;
  final GridPoint playerStart;
  final double roomTransitionDelaySeconds;
  final RewardProcessor? rewardProcessor;
  final VoidCallback? onProgressionChanged;
  final VoidCallback? onCriticalSaveRequired;
  final void Function(GrantedReward reward)? onDungeonRewardSettled;
  final int? initialPlayerHp;
  final int initialReviveCooldownTicks;
  final Map<String, int> initialSkillCooldownTicks;
  final int? simulationSeed;
  final AudioService? audioService;
  final DifficultyProfile? difficultyProfile;

  late NavigationGrid grid;
  late final CombatSimulation simulation;
  late final PlayerComponent playerView;
  late final CombatSystem _combatSystem;

  DebugRoomComponent? _roomView;
  RoomDefinition? _activeRoom;
  String? _mountedRoomId;
  String? _mountingRoomId;
  List<RoomSpawnConfig> _preparedSpawns = const [];
  final List<Component> _pendingRemovals = [];
  Future<void>? _pendingMountFuture;
  DungeonEventListener? _dungeonListener;
  CombatSystem? _attachedCombatSystem;
  bool _sessionDetached = false;

  RoomDefinition? get activeRoom => _activeRoom;
  String? get mountedRoomId => _mountedRoomId;
  List<RoomSpawnConfig> get preparedSpawns => _preparedSpawns;
  Future<void>? get pendingRoomLoad => _pendingMountFuture;

  double get worldWidth => grid.columns * GameConstants.tileSize;
  double get worldHeight => grid.rows * GameConstants.tileSize;

  @override
  Future<void> onLoad() async {
    final manager = dungeonManager;
    final initialRoom = manager?.activeRoom;
    final initialGrid = manager?.activeGrid;

    if (manager != null) {
      if (initialRoom == null || initialGrid == null) {
        throw StateError(
          'DungeonManager belum memiliki room aktif untuk dimuat.',
        );
      }
      grid = initialGrid;
      _activeRoom = initialRoom;
      _mountedRoomId = initialRoom.id;
      _preparedSpawns = manager.preparedSpawns;
    } else {
      grid = NavigationGrid.fromAscii(roomLayout);
    }

    final initialCell = initialRoom?.entryPosition ?? playerStart;
    if (!grid.isWalkable(initialCell.x, initialCell.y)) {
      throw StateError('Entry position $initialCell pada room tidak walkable.');
    }

    // Setiap run dimulai dengan HP penuh berdasarkan stat karakter saat ini
    // (termasuk equipment, skill pasif, dan specialization).
    final player = Combatant(
      id: 'player',
      team: Team.player,
      stats: character.stats,
      cell: initialCell,
    );

    final resolvedSeed = simulationSeed ?? math.Random().nextInt(0x7fffffff);
    simulation =
        CombatSimulation(
          grid: grid,
          pathfinder: const AStarPathfinder(),
          player: player,
          reviveConfig: config.revive,
          damageCalculator: config.damage.createCalculator(),
          seed: resolvedSeed,
        )..setPlayerSkills(
          character.activeSkills,
          runtimeStates: {
            for (final s in character.activeSkills)
              s.id: character.skillRuntimeState(s.id),
          },
          skillAffinities: character.activeSkillAffinities,
        );

    if (initialPlayerHp != null ||
        initialReviveCooldownTicks > 0 ||
        initialSkillCooldownTicks.isNotEmpty) {
      simulation.restoreRunState(
        hp: initialPlayerHp,
        reviveCooldownTicks: initialReviveCooldownTicks,
        skillCooldownTicks: initialSkillCooldownTicks,
      );
    }

    playerView = PlayerComponent(
      combatant: player,
      tileSize: GameConstants.tileSize,
      specializationIdProvider: () => character.specializationId,
    )..priority = 2;

    _roomView = DebugRoomComponent(
      grid: grid,
      tileSize: GameConstants.tileSize,
      markers: initialRoom == null ? const [] : [initialRoom.exitPosition],
    )..priority = 0;

    _combatSystem = CombatSystem(
      simulation: simulation,
      config: config,
      character: character,
      views: views,
      hud: hud,
      autoSkill: autoSkill,
      random: math.Random(), // loot online: tidak perlu reproduksi
      tileSize: GameConstants.tileSize,
      viewParent: this,
      playerView: playerView,
      dungeonManager: manager,
      enableDebugWaveRespawn: manager == null,
      roomTransitionDelaySeconds: roomTransitionDelaySeconds,
      isTransitionBusy: () =>
          _pendingMountFuture != null || _mountingRoomId != null,
      onExitUnlockedChanged: (unlocked) {
        _roomView?.exitUnlocked = unlocked;
      },
      rewardProcessor: rewardProcessor,
      onProgressionChanged: onProgressionChanged,
      onCriticalSaveRequired: onCriticalSaveRequired,
      onDungeonRewardSettled: onDungeonRewardSettled,
      audioService: audioService,
      difficultyService: DifficultyService(config.difficulty),
      difficultyProfile: difficultyProfile ?? manager?.activeDifficultyProfile,
    );
    _attachedCombatSystem = _combatSystem;

    await addAll([_roomView!, playerView, _combatSystem]);
    if (_sessionDetached) return;

    if (manager != null) {
      _dungeonListener = _onDungeonEvent;
      manager.addListener(_dungeonListener!);
    }

    _attachCamera();

    final tracker = manager?.encounterTracker;
    if (tracker != null) {
      tracker.onRoomLoaded(simulation, grid: grid);
      _combatSystem.syncEnemyViews();
    }

    if (manager != null &&
        manager.session?.roomLifecycle == RoomLifecycleState.ready &&
        manager.activeRoom?.id == initialRoom?.id) {
      manager.activateRoom();
    }

    if (tracker != null) {
      tracker.onRoomActivated(simulation, grid: grid);
      _combatSystem.syncEnemyViews();
    }

    _combatSystem.publishHudNow();
  }

  /// Melepas listener `DungeonManager` agar instance world lama tidak
  /// memicu pemuatan room atau pemrosesan reward pada run baru.
  void detachSessionListeners() {
    _sessionDetached = true;
    final listener = _dungeonListener;
    if (listener != null) {
      dungeonManager?.removeListener(listener);
      _dungeonListener = null;
    }
    _attachedCombatSystem?.detachSessionListeners();
  }

  @override
  void onRemove() {
    detachSessionListeners();
    _pendingRemovals.clear();
    super.onRemove();
  }

  void _onDungeonEvent(DungeonRuntimeEvent event) {
    if (_sessionDetached) return;
    if (event is RoomUnloadedEvent) {
      _cleanupCurrentRoom();
      return;
    }
    if (event is DungeonEndedEvent) {
      _cleanupCurrentRoom();
      return;
    }
    if (event is RoomLoadedEvent) {
      if (_mountedRoomId == event.room.id || _mountingRoomId == event.room.id) {
        return;
      }
      _pendingMountFuture = _mountRoom(
        event.room,
        event.grid,
        event.preparedSpawns,
      );
      unawaited(_pendingMountFuture);
    }
  }

  void _cleanupCurrentRoom() {
    _combatSystem.clearRoomViews();

    final transient = <Component>{
      ?_roomView,
      ...children.whereType<DebugRoomComponent>(),
      ...children.whereType<EnemyComponent>(),
      ...children.whereType<FloatingTextComponent>(),
      ...children.whereType<SkillVfxComponent>(),
      ...children.whereType<RoomTransitionCurtain>(),
    };

    for (final component in transient) {
      if (component.isMounted) {
        _pendingRemovals.add(component);
      }
      if (component.parent != null) {
        component.removeFromParent();
      }
    }

    _roomView = null;
    _activeRoom = null;
    _mountedRoomId = null;
    _preparedSpawns = const [];
  }

  Future<void> _mountRoom(
    RoomDefinition room,
    NavigationGrid nextGrid,
    List<RoomSpawnConfig> spawns,
  ) async {
    _mountingRoomId = room.id;
    try {
      if (_pendingRemovals.isNotEmpty) {
        final removals = _pendingRemovals
            .where((c) => c.isMounted)
            .map((c) => c.removed)
            .toList();
        _pendingRemovals.clear();
        if (removals.isNotEmpty) {
          await Future.wait(removals);
        }
      }

      if (_sessionDetached ||
          !isMounted ||
          dungeonManager?.activeRoom?.id != room.id) {
        return;
      }

      grid = nextGrid;
      simulation.loadRoom(nextGrid, entryCell: room.entryPosition);
      playerView.resetVisualTransient();

      final nextRoomView = DebugRoomComponent(
        grid: nextGrid,
        tileSize: GameConstants.tileSize,
        markers: [room.exitPosition],
      )..priority = 0;

      _roomView = nextRoomView;
      await add(nextRoomView);

      if (_sessionDetached ||
          !isMounted ||
          dungeonManager?.activeRoom?.id != room.id) {
        return;
      }

      _activeRoom = room;
      _mountedRoomId = room.id;
      _preparedSpawns = spawns;

      _attachCamera();

      final tracker = dungeonManager?.encounterTracker;
      if (tracker != null) {
        tracker.onRoomLoaded(simulation, grid: grid);
        _combatSystem.syncEnemyViews();
      }

      if (dungeonManager?.session?.roomLifecycle == RoomLifecycleState.ready &&
          dungeonManager?.activeRoom?.id == room.id) {
        dungeonManager!.activateRoom();
      }

      if (tracker != null) {
        tracker.onRoomActivated(simulation, grid: grid);
        _combatSystem.syncEnemyViews();
      }

      add(
        RoomTransitionCurtain(worldWidth: worldWidth, worldHeight: worldHeight),
      );

      _combatSystem.publishHudNow();
    } finally {
      if (_mountingRoomId == room.id) {
        _mountingRoomId = null;
        _pendingMountFuture = null;
      }
    }
  }

  void _attachCamera() {
    final game = findGame();
    if (game is! FlameGame) return;

    game.camera.follow(playerView, snap: true);
    game.camera.setBounds(
      Rectangle.fromLTWH(
        0,
        0,
        math.max(worldWidth, GameConstants.viewWidth),
        math.max(worldHeight, GameConstants.viewHeight),
      ),
      considerViewport: true,
    );
  }
}
