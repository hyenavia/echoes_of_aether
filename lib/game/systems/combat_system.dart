import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, VoidCallback;

import '../../core/constants/test_room.dart';
import '../../domain/entities/combat_event.dart';
import '../../domain/entities/combatant.dart';
import '../../domain/entities/dungeon_definition.dart';
import '../../domain/entities/dungeon_session.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/entities/player_character.dart';
import '../../domain/entities/player_status.dart';
import '../../domain/entities/skill_definition.dart';
import '../../domain/services/combat_simulation.dart';
import '../../domain/services/difficulty_service.dart';
import '../../domain/services/dungeon_manager.dart';
import '../../domain/services/dungeon_reward_settlement_service.dart';
import '../../domain/services/equipment_factory.dart';
import '../../domain/services/loot_service.dart';
import '../../domain/services/reward_processor.dart';
import '../audio/audio_service.dart';
import '../components/combatant_component.dart';
import '../components/effects/floating_text_component.dart';
import '../components/effects/skill_vfx_component.dart';
import '../components/enemies/enemy_component.dart';
import '../components/player/player_component.dart';
import '../hud/hud_state.dart';
import '../hud/inventory_views.dart';
import '../overlays.dart';

/// Menjembatani simulasi domain dengan Flame: menjalankan tick tetap 50 ms,
/// membuat/menghapus komponen visual musuh, memberikan reward (EXP, gold,
/// loot), menyinkronkan stat dan skill player (level, equipment,
/// specialization), memperbarui HUD dan inventory, menampilkan overlay saat
/// run berakhir, dan (sementara, untuk pengujian) memunculkan gelombang musuh
/// baru setelah gelombang sebelumnya habis.
class CombatSystem extends Component {
  CombatSystem({
    required this.simulation,
    required this.config,
    required this.character,
    required this.views,
    required this.hud,
    required this.autoSkill,
    required this.random,
    required this.tileSize,
    required this.viewParent,
    this.playerView,
    this.dungeonManager,
    this.enableDebugWaveRespawn = true,
    this.roomTransitionDelaySeconds = 1.0,
    this.isTransitionBusy,
    this.onExitUnlockedChanged,
    this.lootService = const LootService(),
    this.settlementService = const DungeonRewardSettlementService(),
    RewardProcessor? rewardProcessor,
    this.onProgressionChanged,
    this.onCriticalSaveRequired,
    this.onDungeonRewardSettled,
    this.audioService,
    this.difficultyProfile,
    DifficultyService? difficultyService,
  }) : difficultyService =
           difficultyService ?? DifficultyService(config.difficulty),
       equipmentFactory = EquipmentFactory(config.equipment),
       rewardProcessor =
           rewardProcessor ??
           RewardProcessor(
             character: character,
             inventory: views.inventory,
             items: config.items,
             lootTables: config.lootTables,
             lootService: lootService,
             equipmentFactory: EquipmentFactory(config.equipment),
           );

  final CombatSimulation simulation;
  final GameConfig config;
  final PlayerCharacter character;
  final InventoryViews views;
  final ValueNotifier<HudState> hud;
  final ValueNotifier<bool> autoSkill;
  final math.Random random;
  final double tileSize;
  final Component viewParent;
  final PlayerComponent? playerView;
  final DungeonManager? dungeonManager;
  final bool enableDebugWaveRespawn;
  final double roomTransitionDelaySeconds;
  final bool Function()? isTransitionBusy;
  final void Function(bool unlocked)? onExitUnlockedChanged;
  final LootService lootService;
  final DungeonRewardSettlementService settlementService;
  final EquipmentFactory equipmentFactory;
  final RewardProcessor rewardProcessor;
  final VoidCallback? onProgressionChanged;
  final VoidCallback? onCriticalSaveRequired;
  final void Function(GrantedReward reward)? onDungeonRewardSettled;
  final AudioService? audioService;
  final DifficultyProfile? difficultyProfile;
  final DifficultyService difficultyService;

  DifficultyProfile get activeDifficultyProfile =>
      difficultyProfile ??
      dungeonManager?.activeDifficultyProfile ??
      DifficultyProfile.identity;

  static const double _respawnDelaySeconds = 3;
  static const double _messageSeconds = 4;
  static const double _skillMessageSeconds = 1.5;
  static const double _transitionMessageSeconds = 2.5;
  static const int _maxTicksPerFrame = 5;
  static const double _hudPublishIntervalSeconds = 0.1;

  final Map<String, EnemyComponent> _views = {};
  final List<Component> _transientEffects = [];
  double _accumulator = 0;
  double _hudAccumulator = 0;
  double? _respawnTimer;
  double? _pendingTransitionTimer;
  String _lastLoot = '';
  double _lootTimer = 0;
  String _lastSkill = '';
  double _skillTimer = 0;
  String _roomStatusOverride = '';
  String _transitionMessage = '';
  double _transitionMessageTimer = 0;
  DungeonEventListener? _dungeonListener;

  // Build yang terakhir diterapkan ke combatant player.
  late int _appliedLevel = character.level;
  late int _appliedLoadoutRevision = character.loadout.revision;
  late int _appliedBuildRevision = character.buildRevision;

  @override
  Future<void> onLoad() async {
    final manager = dungeonManager;
    if (manager != null) {
      _dungeonListener = _onDungeonEvent;
      manager.addListener(_dungeonListener!);
    }
    if (enableDebugWaveRespawn && manager == null) {
      _spawnWave();
    }
  }

  /// Melepas listener `DungeonManager` agar instance sistem lama tidak
  /// bereaksi pada run berikutnya.
  void detachSessionListeners() {
    final listener = _dungeonListener;
    if (listener != null) {
      dungeonManager?.removeListener(listener);
      _dungeonListener = null;
    }
    _pendingTransitionTimer = null;
  }

  @override
  void onRemove() {
    detachSessionListeners();
    super.onRemove();
  }

  /// Memastikan seluruh musuh yang hidup di [simulation] memiliki
  /// `EnemyComponent` visual tanpa menggandakan komponen yang sudah ada.
  void syncEnemyViews() {
    for (final enemy in simulation.aliveEnemies) {
      if (_views.containsKey(enemy.id)) continue;
      final definition = enemy.definitionId != null
          ? config.monsters[enemy.definitionId!]
          : null;
      final view = EnemyComponent(
        combatant: enemy,
        tileSize: tileSize,
        spriteRef: definition?.spriteRef,
        spriteTintHex: definition?.spriteTint,
      )..priority = 1;
      _views[enemy.id] = view;
      viewParent.add(view);
    }
  }

  /// Membersihkan view musuh, efek visual room, dan timer gelombang/accumulator
  /// saat room dilepas atau diganti.
  void clearRoomViews() {
    for (final view in _views.values) {
      if (view.parent != null) {
        view.removeFromParent();
      }
    }
    _views.clear();
    for (final effect in _transientEffects) {
      if (effect.parent != null) {
        effect.removeFromParent();
      } else if (!effect.isRemoved) {
        viewParent.remove(effect);
      }
    }
    _transientEffects.clear();
    _respawnTimer = null;
    _accumulator = 0;
  }

  void _addTransientEffect(Component effect) {
    if (_transientEffects.length > 48) {
      _transientEffects.removeWhere((c) => c.isRemoved);
    }
    _transientEffects.add(effect);
    viewParent.add(effect);
  }

  /// Memaksa pembaruan snapshot HUD (misalnya setelah room baru dimuat).
  void publishHudNow() {
    _hudAccumulator = 0;
    _publishHud();
  }

  void _publishHudThrottled(double dt) {
    _hudAccumulator += dt;
    if (_hudAccumulator >= _hudPublishIntervalSeconds) {
      _hudAccumulator = 0;
      _publishHud();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateMessages(dt);

    final manager = dungeonManager;
    if (manager != null) {
      final session = manager.session;
      if (session == null || session.isTerminal) {
        _publishHudThrottled(dt);
        return;
      }
      if (session.roomLifecycle == RoomLifecycleState.completed) {
        final timer = _pendingTransitionTimer;
        if (timer != null && !(isTransitionBusy?.call() ?? false)) {
          final remaining = timer - dt;
          if (remaining <= 0) {
            _pendingTransitionTimer = null;
            manager.transitionToNextRoom();
          } else {
            _pendingTransitionTimer = remaining;
          }
        }
        _publishHudThrottled(dt);
        return;
      }
      if (session.roomLifecycle != RoomLifecycleState.active) {
        _publishHudThrottled(dt);
        return;
      }
    }

    simulation.autoSkillEnabled = autoSkill.value;

    _accumulator += dt;
    var steps = 0;
    while (_accumulator >= CombatSimulation.tickSeconds &&
        steps < _maxTicksPerFrame) {
      simulation.tick();
      _accumulator -= CombatSimulation.tickSeconds;
      steps++;
    }
    // Jika frame tertinggal terlalu jauh, buang sisa waktu agar tidak menumpuk.
    if (steps == _maxTicksPerFrame) _accumulator = 0;

    final hasEvents = _handleEvents();
    _evaluateRoomProgress();
    _syncPlayerBuild();
    if (enableDebugWaveRespawn && manager == null) {
      _updateWaves(dt);
    }
    if (hasEvents) {
      publishHudNow();
    } else {
      _publishHudThrottled(dt);
    }
  }

  void _evaluateRoomProgress() {
    final manager = dungeonManager;
    if (manager == null) return;
    final room = manager.activeRoom;
    final session = manager.session;
    if (room == null ||
        session == null ||
        session.isTerminal ||
        session.roomLifecycle != RoomLifecycleState.active) {
      return;
    }
    if (simulation.playerStatus != PlayerStatus.alive) {
      simulation.setExitNavigation(null);
      return;
    }

    final cell = simulation.player.follower.currentCell;
    manager.updatePlayerCell(cell);
    final eval = manager.evaluateCurrentRoom(playerCell: cell);
    onExitUnlockedChanged?.call(eval.exitUnlocked);

    if (eval.isCompleted) {
      simulation.setExitNavigation(null);
      manager.tryCompleteActiveRoom(
        playerCell: cell,
        expectedRunId: session.runId,
        expectedRoomId: room.id,
      );
    } else if (eval.exitRequired && eval.exitUnlocked && !eval.exitReached) {
      simulation.setExitNavigation(room.exitPosition);
    } else {
      simulation.setExitNavigation(null);
    }
  }

  void _onDungeonEvent(DungeonRuntimeEvent event) {
    if (event is RoomCompletedEvent) {
      simulation.setExitNavigation(null);
      onExitUnlockedChanged?.call(true);
      final roomGranted = settlementService.settleRoomCompleted(
        session: event.session,
        room: event.room,
        rewardProcessor: rewardProcessor,
        random: random,
        difficultyProfile: activeDifficultyProfile,
        difficultyService: difficultyService,
      );
      if (roomGranted != null && !roomGranted.alreadyClaimed) {
        if (roomGranted.levelsGained > 0) {
          unawaited(audioService?.playSfx(AudioCue.levelUp));
        }
        if (roomGranted.displayParts.isNotEmpty) {
          _lastLoot = roomGranted.displayParts.join(', ');
          _lootTimer = _messageSeconds;
        }
        views.refresh();
      }
      unawaited(audioService?.playSfx(AudioCue.roomClear));
      _roomStatusOverride = 'Room Selesai';
      final nextName = event.nextRoomId != null
          ? (dungeonManager?.activeDungeon?.roomById(event.nextRoomId!)?.name ??
                event.nextRoomId)
          : null;
      _transitionMessage = nextName != null
          ? 'Room selesai! Menuju $nextName...'
          : 'Room selesai!';
      _transitionMessageTimer = _transitionMessageSeconds;
      _pendingTransitionTimer = event.nextRoomId != null
          ? roomTransitionDelaySeconds
          : null;
      _publishHud();
      onCriticalSaveRequired?.call();
      return;
    }
    if (event is RoomTransitioningEvent) {
      _pendingTransitionTimer = null;
      final toName =
          dungeonManager?.activeDungeon?.roomById(event.toRoomId)?.name ??
          event.toRoomId;
      _roomStatusOverride = 'Berpindah ke $toName...';
      _transitionMessage = 'Berpindah ke $toName...';
      _transitionMessageTimer = _transitionMessageSeconds;
      _publishHud();
      return;
    }
    if (event is RoomLoadedEvent) {
      _roomStatusOverride = '';
      _transitionMessage = 'Memasuki ${event.room.name}';
      _transitionMessageTimer = _transitionMessageSeconds;
      _publishHud();
      onCriticalSaveRequired?.call();
      return;
    }
    if (event is RoomTransitionFailedEvent) {
      _pendingTransitionTimer = null;
      _roomStatusOverride = 'Transisi Gagal';
      _transitionMessage = 'Transisi gagal: ${event.reason}';
      _transitionMessageTimer = _messageSeconds;
      _publishHud();
      return;
    }
    if (event is DungeonEndedEvent) {
      _pendingTransitionTimer = null;
      if (event.finalStatus == DungeonSessionStatus.completed) {
        final settlement = settlementService.settleDungeonCompleted(
          event: event,
          config: config,
          rewardProcessor: rewardProcessor,
          random: random,
          dungeonManager: dungeonManager,
          difficultyProfile: activeDifficultyProfile,
          difficultyService: difficultyService,
        );
        final granted = settlement.granted;
        if (granted != null && !granted.alreadyClaimed) {
          if (granted.levelsGained > 0) {
            unawaited(audioService?.playSfx(AudioCue.levelUp));
          }
          if (granted.displayParts.isNotEmpty) {
            _lastLoot = granted.displayParts.join(', ');
            _lootTimer = _messageSeconds;
          }
          views.refresh();
          onDungeonRewardSettled?.call(granted);
        }
        unawaited(audioService?.playSfx(AudioCue.roomClear));
        _roomStatusOverride = 'Dungeon Selesai!';
        _transitionMessage =
            '${event.dungeon?.name ?? 'Dungeon'} selesai ditaklukkan!';
        _transitionMessageTimer = _messageSeconds;
        _publishHud();
        onCriticalSaveRequired?.call();
        _showOverlayIfRegistered(GameOverlays.dungeonCompleted);
      } else if (event.effectiveReason == DungeonEndReason.transitionFailed) {
        _publishHud();
        onCriticalSaveRequired?.call();
        _showOverlayIfRegistered(GameOverlays.runEnded);
      }
    }
  }

  void _showOverlayIfRegistered(String overlayName) {
    final overlays = findGame()?.overlays;
    if (overlays != null && overlays.registeredOverlays.contains(overlayName)) {
      overlays.add(overlayName);
    }
  }

  bool _handleEvents() {
    final events = simulation.drainEvents();
    for (final event in events) {
      if (event is AttackEvent) {
        _onAttackVisual(event);
      } else if (event is HealEvent) {
        _onHealVisual(event);
      } else if (event is DeathEvent &&
          event.combatantId != simulation.player.id) {
        _views.remove(event.combatantId)?.removeFromParent();
      } else if (event is EnemyDefeatedEvent) {
        _grantRewards(event);
        final tracker = dungeonManager?.encounterTracker;
        if (tracker != null) {
          tracker.onEnemyDefeated(
            event.enemyId,
            simulation: simulation,
            grid: simulation.grid,
          );
          syncEnemyViews();
        }
      } else if (event is SkillCastEvent &&
          event.casterId == simulation.player.id) {
        playerView?.triggerAttackAnimation();
        _lastSkill = config.skills[event.skillId]?.name ?? event.skillId;
        _skillTimer = _skillMessageSeconds;
      } else if (event is PlayerDownedEvent) {
        simulation.setExitNavigation(null);
        _roomStatusOverride = 'Downed (Revive)';
        _transitionMessage =
            'HP habis! Revive dalam ${config.revive.delaySeconds.toStringAsFixed(0)} detik...';
        _transitionMessageTimer = math.max(
          _transitionMessageSeconds,
          config.revive.delaySeconds,
        );
        onCriticalSaveRequired?.call();
      } else if (event is PlayerRevivedEvent) {
        _roomStatusOverride = '';
        _transitionMessage = 'Revive berhasil (+${event.hp} HP)';
        _transitionMessageTimer = _transitionMessageSeconds;
        _addTransientEffect(
          SkillVfxComponent.healPulse(
            position: Vector2(
              simulation.player.x * tileSize,
              simulation.player.y * tileSize,
            ),
          ),
        );
        onCriticalSaveRequired?.call();
      } else if (event is RunEndedEvent) {
        simulation.setExitNavigation(null);
        dungeonManager?.encounterTracker?.onRunFailed();
        if (dungeonManager != null && dungeonManager!.hasActiveSession) {
          dungeonManager!.endRun(
            finalStatus: DungeonSessionStatus.failed,
            reason: DungeonEndReason.defeated,
          );
        }
        (onCriticalSaveRequired ?? onProgressionChanged)?.call();
        _showOverlayIfRegistered(GameOverlays.runEnded);
      }
    }
    return events.isNotEmpty;
  }

  CombatantComponent? _viewFor(String id) {
    if (id == simulation.player.id) return playerView;
    return _views[id];
  }

  Combatant? _combatantFor(String id) {
    if (id == simulation.player.id) return simulation.player;
    for (final e in simulation.enemies) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _onAttackVisual(AttackEvent event) {
    final attackerView = _viewFor(event.attackerId);
    attackerView?.triggerAttackAnimation();
    final targetView = _viewFor(event.targetId);
    if (event.damage > 0) targetView?.triggerHitFlash();

    final target = _combatantFor(event.targetId);
    if (target == null) return;
    attackerView?.faceToward(target.x);

    final targetPos = Vector2(target.x * tileSize, target.y * tileSize);
    if (event.damage > 0) {
      if (event.damageType == SkillDamageType.magic) {
        _addTransientEffect(SkillVfxComponent.arcaneBurst(position: targetPos));
        unawaited(audioService?.playSfx(AudioCue.magic));
      } else {
        _addTransientEffect(
          SkillVfxComponent.slash(
            position: targetPos,
            isSkill: event.skillId != null,
          ),
        );
        unawaited(
          audioService?.playSfx(
            event.attackerId == simulation.player.id
                ? AudioCue.slash
                : AudioCue.hit,
          ),
        );
      }
      if (event.isCrit) {
        _addTransientEffect(SkillVfxComponent.critSpark(position: targetPos));
      }
    }

    final isPlayerHit = event.targetId == simulation.player.id;
    final color = event.damage == 0
        ? const Color(0xFFB0BEC5)
        : (isPlayerHit
              ? const Color(0xFFEF5350)
              : (event.isCrit
                    ? const Color(0xFFFFD54F)
                    : const Color(0xFFFFFFFF)));
    final label = event.isCrit && event.damage > 0
        ? '${event.damage}!'
        : '${event.damage}';
    _addTransientEffect(
      FloatingTextComponent(
        text: label,
        position: Vector2(target.x * tileSize, (target.y - 0.5) * tileSize),
        color: color,
        isBold: event.isCrit,
        fontSize: event.isCrit ? 8 : 7,
      ),
    );
  }

  void _onHealVisual(HealEvent event) {
    if (event.amount <= 0) return;
    final target = _combatantFor(event.targetId);
    if (target == null) return;
    final targetPos = Vector2(target.x * tileSize, target.y * tileSize);
    _addTransientEffect(SkillVfxComponent.healPulse(position: targetPos));
    unawaited(audioService?.playSfx(AudioCue.heal));
    _addTransientEffect(
      FloatingTextComponent(
        text: '+${event.amount}',
        position: Vector2(target.x * tileSize, (target.y - 0.5) * tileSize),
        color: const Color(0xFF66BB6A),
        isBold: true,
      ),
    );
  }

  /// Menerapkan stat dan skill baru ke simulasi bila level, equipment, atau
  /// specialization berubah. Jika max HP naik, HP ikut naik sebesar selisih
  /// (lihat Combatant.applyStats).
  void _syncPlayerBuild() {
    final revision = character.loadout.revision;
    if (character.level == _appliedLevel &&
        revision == _appliedLoadoutRevision &&
        character.buildRevision == _appliedBuildRevision) {
      return;
    }
    _appliedLevel = character.level;
    _appliedLoadoutRevision = revision;
    _appliedBuildRevision = character.buildRevision;
    simulation.player.applyStats(character.stats);
    simulation.setPlayerSkills(
      character.activeSkills,
      runtimeStates: {
        for (final s in character.activeSkills)
          s.id: character.skillRuntimeState(s.id),
      },
      skillAffinities: character.activeSkillAffinities,
    );
    views.refresh();
  }

  void _grantRewards(EnemyDefeatedEvent event) {
    final granted = rewardProcessor.processEnemyDefeated(
      eventId: 'enemy:${event.tick}:${event.enemyId}',
      definition: event.definition,
      random: random,
      difficultyProfile: activeDifficultyProfile,
      difficultyService: difficultyService,
    );
    if (granted.alreadyClaimed) return;
    if (granted.levelsGained > 0) {
      unawaited(audioService?.playSfx(AudioCue.levelUp));
    } else if (granted.hasLootChanges) {
      unawaited(audioService?.playSfx(AudioCue.loot));
    }
    if (granted.displayParts.isNotEmpty) {
      _lastLoot = granted.displayParts.join(', ');
      _lootTimer = _messageSeconds;
      views.refresh();
    }
    onProgressionChanged?.call();
  }

  void _updateMessages(double dt) {
    if (_lastLoot.isNotEmpty) {
      _lootTimer -= dt;
      if (_lootTimer <= 0) _lastLoot = '';
    }
    if (_lastSkill.isNotEmpty) {
      _skillTimer -= dt;
      if (_skillTimer <= 0) _lastSkill = '';
    }
    if (_transitionMessage.isNotEmpty) {
      _transitionMessageTimer -= dt;
      if (_transitionMessageTimer <= 0) _transitionMessage = '';
    }
  }

  void _publishHud() {
    final player = simulation.player;
    final manager = dungeonManager;
    final tracker = manager?.encounterTracker;
    var bossName = '';
    var bossHp = 0;
    var bossMaxHp = 0;
    final bossEncounter = tracker?.primaryBossEncounter;
    if (bossEncounter != null && bossEncounter.isActive) {
      for (final enemy in simulation.aliveEnemies) {
        if (bossEncounter.spawnedEnemyIds.contains(enemy.id)) {
          bossName =
              config.monsters[bossEncounter.monsterId]?.name ??
              bossEncounter.monsterId;
          bossHp = enemy.hp;
          bossMaxHp = enemy.stats.maxHp;
          break;
        }
      }
    }

    final room = manager?.activeRoom;
    final session = manager?.session;
    final evaluation = manager?.lastEvaluation;
    var roomStatus = _roomStatusOverride;
    var exitRequired = false;
    var exitUnlocked = false;
    if (manager != null && room != null) {
      exitRequired =
          evaluation?.exitRequired ?? room.completionCondition.requiresExit;
      exitUnlocked =
          (evaluation?.exitUnlocked ?? false) ||
          session?.roomLifecycle == RoomLifecycleState.completed;
      if (roomStatus.isEmpty) {
        if (evaluation != null &&
            evaluation.exitRequired &&
            evaluation.exitUnlocked &&
            !evaluation.exitReached) {
          roomStatus = 'Menuju Exit';
        } else {
          switch (room.completionCondition.type) {
            case RoomCompletionConditionType.defeatBoss:
              roomStatus = 'Kalahkan Boss';
            case RoomCompletionConditionType.defeatElite:
              roomStatus = 'Kalahkan Elite';
            case RoomCompletionConditionType.defeatRequiredEnemies:
              roomStatus = 'Kalahkan Musuh';
            case RoomCompletionConditionType.reachExit:
              roomStatus = 'Capai Exit';
          }
        }
      }
    }

    hud.value = HudState.fromCharacter(
      character,
      hp: player.hp,
      maxHp: player.stats.maxHp,
      lastLoot: _lastLoot,
      lastSkill: _lastSkill,
      dungeonName: manager?.activeDungeon?.name ?? '',
      roomName: room?.name ?? '',
      roomStatus: roomStatus,
      exitUnlocked: exitUnlocked,
      exitRequired: exitRequired,
      transitionMessage: _transitionMessage,
      activeEnemies: tracker?.totalActiveEnemies ?? 0,
      totalEnemies: tracker?.totalPlannedEnemies ?? 0,
      bossName: bossName,
      bossHp: bossHp,
      bossMaxHp: bossMaxHp,
    );
  }

  /// Sementara (pengujian): setelah semua musuh kalah, player dipulihkan 50%
  /// dan gelombang baru muncul. Akan diganti sistem room di Milestone 5.
  void _updateWaves(double dt) {
    final player = simulation.player;
    if (!player.isAlive) return;

    if (simulation.aliveEnemies.isNotEmpty) {
      _respawnTimer = null;
      return;
    }
    if (_respawnTimer == null) {
      _respawnTimer = _respawnDelaySeconds;
      player.heal(player.stats.maxHp ~/ 2);
      return;
    }
    _respawnTimer = _respawnTimer! - dt;
    if (_respawnTimer! <= 0) {
      _respawnTimer = null;
      _spawnWave();
    }
  }

  void _spawnWave() {
    for (final (monsterId, cell) in TestRoom.enemySpawns) {
      final definition = config.monsters[monsterId];
      if (definition == null) {
        throw StateError('Monster "$monsterId" tidak ada di monsters.json.');
      }
      final enemy = simulation.spawnEnemy(definition, cell);
      final view = EnemyComponent(
        combatant: enemy,
        tileSize: tileSize,
        spriteRef: definition.spriteRef,
        spriteTintHex: definition.spriteTint,
      )..priority = 1;
      _views[enemy.id] = view;
      viewParent.add(view);
    }
  }
}
