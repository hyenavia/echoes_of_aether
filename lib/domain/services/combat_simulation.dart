import 'dart:math' as math;

import '../entities/combat_event.dart';
import '../entities/combat_stats.dart';
import '../entities/combatant.dart';
import '../entities/enemy_definition.dart';
import '../entities/equipment.dart';
import '../entities/grid_point.dart';
import '../entities/player_status.dart';
import '../entities/revive_config.dart';
import '../entities/skill_definition.dart';
import '../entities/skill_runtime_state.dart';
import 'astar_pathfinder.dart';
import 'attack_position_finder.dart';
import 'damage_calculator.dart';
import 'navigation_grid.dart';
import 'skill_selector.dart';
import 'target_selector.dart';

/// Simulasi combat deterministik dengan timestep tetap 50 ms (20 tick/detik),
/// terpisah dari rendering (GDD 12.7). Tidak bergantung pada Flutter/Flame,
/// sehingga bisa dipakai ulang oleh offline simulation.
///
/// Cakupan: gerak, targeting, serangan dasar, skill otomatis dengan cooldown,
/// kematian musuh, serta Downed/auto-revive/akhir run untuk player (GDD
/// bagian 5). Skill musuh dan boss ditambahkan pada Milestone 5.
class CombatSimulation {
  CombatSimulation({
    required NavigationGrid grid,
    required this.pathfinder,
    required this.player,
    int seed = 0,
    this.reviveConfig = const ReviveConfig(),
    this.damageCalculator = const DamageCalculator(),
    this.targetSelector = const TargetSelector(),
    this.skillSelector = const SkillSelector(),
    this.attackPositionFinder = const AttackPositionFinder(),
  }) : _grid = grid, // ignore: prefer_initializing_formals
       _random = math.Random(seed);

  static const int ticksPerSecond = 20;
  static const double tickSeconds = 1 / ticksPerSecond;

  NavigationGrid _grid;
  NavigationGrid get grid => _grid;
  final AStarPathfinder pathfinder;
  final Combatant player;
  final ReviveConfig reviveConfig;
  final DamageCalculator damageCalculator;
  final TargetSelector targetSelector;
  final SkillSelector skillSelector;
  final AttackPositionFinder attackPositionFinder;

  /// Pengaturan auto skill (GDD 2.4): jika false, skill tidak dipakai.
  bool autoSkillEnabled = true;

  final math.Random _random;
  final List<Combatant> _enemies = [];
  final List<CombatEvent> _events = [];
  final Map<String, EnemyDefinition> _definitions = {};
  int _tick = 0;
  int _spawnCounter = 0;

  List<SkillDefinition> _skills = const [];
  final Map<String, SkillRuntimeState> _skillStates = {};
  Map<String, double> _skillAffinities = const {};

  PlayerStatus _status = PlayerStatus.alive;
  int _downedTicksLeft = 0;
  int _reviveCooldownTicks = 0;
  GridPoint? _exitNavigationTarget;

  int get currentTick => _tick;
  PlayerStatus get playerStatus => _status;
  GridPoint? get exitNavigationTarget => _exitNavigationTarget;

  /// Sisa cooldown revive dalam tick; 0 berarti revive tersedia.
  int get reviveCooldownTicks => _reviveCooldownTicks;
  bool get isReviveAvailable => _reviveCooldownTicks == 0;

  List<Combatant> get enemies => List.unmodifiable(_enemies);
  Iterable<Combatant> get aliveEnemies => _enemies.where((e) => e.isAlive);

  /// Skill aktif player saat ini.
  List<SkillDefinition> get playerSkills => List.unmodifiable(_skills);

  /// Sisa cooldown skill dalam tick; 0 berarti siap dipakai.
  int skillCooldownTicks(String skillId) =>
      _skillStates[skillId]?.cooldownTicksRemaining ?? 0;

  SkillRuntimeState? skillState(String skillId) => _skillStates[skillId];

  Map<String, SkillRuntimeState> get skillStates =>
      Map.unmodifiable(_skillStates);

  double skillAffinityFor(String skillId) => _skillAffinities[skillId] ?? 0.0;

  /// Mengganti daftar skill aktif player (misalnya saat level naik atau
  /// specialization berubah). Cooldown skill yang tetap ada dipertahankan.
  void setPlayerSkills(
    Iterable<SkillDefinition> skills, {
    Map<String, SkillRuntimeState>? runtimeStates,
    Map<String, double> skillAffinities = const {},
  }) {
    _skills = skills.where((s) => s.isActive).toList(growable: false);
    _skillAffinities = Map.unmodifiable(skillAffinities);
    final ids = _skills.map((s) => s.id).toSet();
    _skillStates.removeWhere((id, _) => !ids.contains(id));
    for (final skill in _skills) {
      final previous = _skillStates[skill.id];
      final incoming = runtimeStates?[skill.id];
      _skillStates[skill.id] = SkillRuntimeState(
        skillId: skill.id,
        level: incoming?.level ?? previous?.level ?? 1,
        unlocked: incoming?.unlocked ?? previous?.unlocked ?? true,
        cooldownTicksRemaining:
            previous?.cooldownTicksRemaining ??
            incoming?.cooldownTicksRemaining ??
            0,
      );
    }
  }

  /// Mereset seluruh cooldown skill runtime menjadi siap pakai (dipakai saat
  /// memulai run dungeon baru, bukan saat berpindah room dalam satu run).
  void resetSkillCooldowns() {
    for (final id in _skillStates.keys.toList()) {
      _skillStates[id] = _skillStates[id]!.resetCooldown();
    }
  }

  /// Memulihkan state runtime player (HP, revive cooldown, dan cooldown skill)
  /// ketika sesi dungeon `inProgress` dipulihkan ke awal room terakhir.
  void restoreRunState({
    int? hp,
    int reviveCooldownTicks = 0,
    Map<String, int>? skillCooldownTicks,
  }) {
    if (hp != null) {
      player.hp = hp.clamp(1, player.stats.maxHp);
    }
    _reviveCooldownTicks = math.max(0, reviveCooldownTicks);
    _downedTicksLeft = 0;
    _status = PlayerStatus.alive;
    if (skillCooldownTicks != null && skillCooldownTicks.isNotEmpty) {
      for (final id in _skillStates.keys.toList()) {
        final savedTicks = skillCooldownTicks[id];
        if (savedTicks == null || savedTicks <= 0) continue;
        final current = _skillStates[id]!;
        _skillStates[id] = SkillRuntimeState(
          skillId: current.skillId,
          level: current.level,
          unlocked: current.unlocked,
          cooldownTicksRemaining: savedTicks,
        );
      }
    }
  }

  /// Mengatur tujuan navigasi otomatis menuju exit room (atau `null` untuk
  /// menonaktifkan). Hanya digunakan ketika syarat combat room telah terpenuhi
  /// dan kondisi room mewajibkan mencapai `exitPosition`.
  void setExitNavigation(GridPoint? target) {
    if (_exitNavigationTarget == target) return;
    _exitNavigationTarget = target;
    if (target == null) {
      player.plannedGoal = null;
    }
  }

  /// Memuat konteks ruangan baru dalam satu dungeon run.
  ///
  /// Membersihkan musuh, definisi spawn, event sementara, target combat lama,
  /// dan jalur pathfinding sebelumnya lalu menempatkan [player] pada [entryCell].
  ///
  /// State yang sengaja **dipertahankan** antar-room dalam satu run:
  /// - HP [player] terakhir, stat tempur, serta `invulnerableTicks`.
  /// - `_reviveCooldownTicks` dan `_status` player.
  /// - `_skillStates` (unlock, level, dan sisa cooldown tick agar tidak bisa
  ///   di-exploit dengan melewati batas room).
  /// - `autoSkillEnabled` dan `_tick` simulasi yang terus berjalan kontinu.
  void loadRoom(NavigationGrid nextGrid, {required GridPoint entryCell}) {
    if (!nextGrid.isWalkable(entryCell.x, entryCell.y)) {
      throw ArgumentError.value(
        entryCell,
        'entryCell',
        'Entry point tidak walkable pada NavigationGrid room.',
      );
    }
    _grid = nextGrid;
    _enemies.clear();
    _definitions.clear();
    _events.clear();
    _spawnCounter = 0;
    _exitNavigationTarget = null;
    player.resetNavigation(entryCell);
  }

  Combatant spawnEnemy(
    EnemyDefinition definition,
    GridPoint cell, {
    String? id,
    CombatStats? statsOverride,
    bool? isEliteOverride,
    bool? isBossOverride,
  }) {
    final resolvedId = (id != null && id.isNotEmpty)
        ? id
        : '${definition.id}_${_spawnCounter++}';
    if (_definitions.containsKey(resolvedId)) {
      throw ArgumentError.value(
        resolvedId,
        'id',
        'ID musuh "$resolvedId" sudah terdaftar pada simulasi room saat ini.',
      );
    }
    final isBoss = isBossOverride ?? definition.isBoss;
    final isElite = !isBoss && (isEliteOverride ?? definition.isElite);
    final enemy = Combatant(
      id: resolvedId,
      team: Team.enemy,
      definitionId: definition.id,
      stats: statsOverride ?? definition.stats,
      cell: cell,
      detectionRange: definition.detectionRange,
      leashRange: definition.leashRange,
      isElite: isElite,
      isBoss: isBoss,
    );
    _enemies.add(enemy);
    _definitions[enemy.id] = definition;
    return enemy;
  }

  /// Mengambil dan mengosongkan daftar event sejak panggilan terakhir.
  List<CombatEvent> drainEvents() {
    final events = List<CombatEvent>.of(_events);
    _events.clear();
    return events;
  }

  /// Memajukan simulasi satu tick (50 ms).
  void tick() {
    _tick++;

    if (_status == PlayerStatus.runEnded) return;
    if (_status == PlayerStatus.downed) {
      _tickDowned(); // combat dihentikan sementara selama Downed
      for (final enemy in _enemies) {
        if (enemy.isAlive && enemy.aiState == MonsterAiState.returning) {
          _returnToSpawn(enemy);
        }
      }
      return;
    }

    if (_reviveCooldownTicks > 0) _reviveCooldownTicks--;
    if (player.invulnerableTicks > 0) player.invulnerableTicks--;
    _tickSkillCooldowns();

    _updatePlayer();
    for (final enemy in _enemies) {
      if (_status != PlayerStatus.alive) break;
      if (enemy.isAlive) _updateEnemy(enemy);
    }
  }

  void _updatePlayer() {
    _tickCooldown(player);
    final exitTarget = _exitNavigationTarget;
    if (exitTarget != null) {
      player.targetId = null;
      if (_tryCastSkill(null)) return;
      if (player.follower.currentCell != exitTarget ||
          player.follower.isMoving) {
        _moveToCell(player, exitTarget);
      }
      return;
    }

    final target = targetSelector.select(
      seeker: player,
      candidates: aliveEnemies,
    );
    player.targetId = target?.id;

    if (_tryCastSkill(target)) return;
    if (target == null) return;
    _engage(player, target);
  }

  void _updateEnemy(Combatant enemy) {
    _tickCooldown(enemy);
    if (!enemy.isAlive) {
      enemy.aiState = MonsterAiState.dead;
      return;
    }
    if (enemy.aiState == MonsterAiState.returning) {
      _returnToSpawn(enemy);
      return;
    }
    if (!enemy.aggroed) {
      if (!player.isAlive || _status != PlayerStatus.alive) return;
      if (enemy.distanceTo(player) > enemy.detectionRange) return;
      enemy.aggroed = true;
      enemy.aiState = MonsterAiState.chase;
    }

    final outOfLeash =
        enemy.leashRange > 0 &&
        (enemy.distanceToSpawn > enemy.leashRange ||
            enemy.distanceTo(player) > enemy.leashRange);
    if (!player.isAlive || _status != PlayerStatus.alive || outOfLeash) {
      _startReturning(enemy);
      return;
    }

    enemy.targetId = player.id;
    if (enemy.distanceTo(player) <= enemy.stats.attackRange) {
      enemy.aiState = MonsterAiState.attack;
      if (enemy.cooldownTicks == 0) _attack(enemy, player);
      return;
    }

    enemy.aiState = MonsterAiState.chase;
    if (!_chase(enemy, player)) {
      _startReturning(enemy);
    }
  }

  void _startReturning(Combatant enemy) {
    enemy.aggroed = false;
    enemy.targetId = null;
    enemy.plannedGoal = null;
    enemy.aiState = enemy.isAtSpawn
        ? MonsterAiState.idle
        : MonsterAiState.returning;
    if (enemy.aiState == MonsterAiState.returning) {
      _returnToSpawn(enemy);
    }
  }

  void _returnToSpawn(Combatant enemy) {
    if (enemy.isAtSpawn) {
      enemy.aiState = MonsterAiState.idle;
      enemy.plannedGoal = null;
      return;
    }
    _moveToCell(enemy, enemy.spawnCell);
    if (enemy.isAtSpawn) {
      enemy.aiState = MonsterAiState.idle;
      enemy.plannedGoal = null;
    }
  }

  void _engage(Combatant attacker, Combatant target) {
    if (attacker.distanceTo(target) <= attacker.stats.attackRange) {
      if (attacker.cooldownTicks == 0) _attack(attacker, target);
      return;
    }
    _chase(attacker, target);
  }

  bool _chase(Combatant mover, Combatant target) {
    final cachedGoal = mover.plannedGoal;
    final cacheValid =
        cachedGoal != null &&
        grid.isWalkable(cachedGoal.x, cachedGoal.y) &&
        mover.follower.isMoving &&
        (cachedGoal == target.follower.currentCell ||
            AttackPositionFinder.isCellInAttackRange(
              cachedGoal,
              target,
              mover.stats.attackRange,
            ));
    if (!cacheValid) {
      final path = attackPositionFinder.findPath(
        grid: grid,
        pathfinder: pathfinder,
        attacker: mover,
        target: target,
      );
      if (path == null) return false;
      mover.plannedGoal = path.last;
      if (path.length == 1 && mover.follower.currentCell == path.last) {
        mover.follower.walkToCenterOf(path.last);
      } else {
        mover.follower.setPath(path);
      }
    }
    mover.follower.advance(mover.stats.moveSpeed * tickSeconds);
    return true;
  }

  bool _moveToCell(Combatant mover, GridPoint goal) {
    if (mover.plannedGoal != goal || !mover.follower.isMoving) {
      mover.plannedGoal = goal;
      final from = mover.follower.currentCell;
      if (from == goal) {
        mover.follower.walkToCenterOf(goal);
      } else {
        final path = pathfinder.findPath(grid, from, goal);
        if (path == null) return false; // tidak terjangkau
        mover.follower.setPath(path);
      }
    }
    mover.follower.advance(mover.stats.moveSpeed * tickSeconds);
    return true;
  }

  // ---- Serangan dasar ----

  void _attack(Combatant attacker, Combatant target) {
    attacker.cooldownTicks = _intervalTicks(attacker.stats.attackSpeed);
    _strike(attacker, target);
  }

  /// Satu pukulan (serangan dasar atau bagian dari skill).
  void _strike(
    Combatant attacker,
    Combatant target, {
    double multiplier = 1.0,
    String? skillId,
    SkillDamageType damageType = SkillDamageType.physical,
  }) {
    if (_status != PlayerStatus.alive || !attacker.isAlive || !target.isAlive) {
      return;
    }

    if (target.invulnerableTicks > 0) {
      _events.add(
        AttackEvent(
          _tick,
          attackerId: attacker.id,
          targetId: target.id,
          damage: 0,
          isCrit: false,
          targetHpAfter: target.hp,
          skillId: skillId,
          damageType: damageType,
        ),
      );
      return;
    }

    final result = damageCalculator.roll(
      attacker: attacker.stats,
      defenderDef: target.stats.def,
      random: _random,
      multiplier: multiplier,
      damageType: damageType,
    );
    target.hp = math.max(0, target.hp - result.amount);

    _events.add(
      AttackEvent(
        _tick,
        attackerId: attacker.id,
        targetId: target.id,
        damage: result.amount,
        isCrit: result.isCrit,
        targetHpAfter: target.hp,
        skillId: skillId,
        damageType: result.damageType,
      ),
    );
    if (!target.isAlive) {
      _events.add(DeathEvent(_tick, target.id));
      if (identical(target, player)) {
        _onPlayerDefeated();
      } else {
        target.aiState = MonsterAiState.dead;
        target.aggroed = false;
        target.targetId = null;
        target.plannedGoal = null;
        final definition = _definitions[target.id];
        if (definition != null) {
          _events.add(EnemyDefeatedEvent(_tick, target.id, definition));
        }
      }
    }
  }

  // ---- Skill ----

  bool _tryCastSkill(Combatant? target) {
    if (_status != PlayerStatus.alive || !player.isAlive) return false;
    if (!autoSkillEnabled || _skills.isEmpty) return false;
    final skill = skillSelector.select(
      skills: _skills,
      isReady: (s) {
        final state = _skillStates[s.id];
        return state != null && state.isReady && state.level >= 1;
      },
      caster: player,
      target: target,
      enemies: aliveEnemies,
    );
    if (skill == null) return false;
    _castSkill(skill, target);
    return true;
  }

  void _castSkill(SkillDefinition skill, Combatant? target) {
    if (_status != PlayerStatus.alive || !player.isAlive || !skill.isActive) {
      return;
    }
    final state = _skillStates[skill.id];
    if (state == null || !state.isReady || state.level < 1) return;

    final affinityBonus = skillAffinityFor(skill.id);

    if (skill.effect == SkillEffectType.healing) {
      if (player.hp >= player.stats.maxHp) return;
      _skillStates[skill.id] = state.triggerCooldown(
        _skillCooldownTicks(skill),
      );
      _events.add(
        SkillCastEvent(_tick, casterId: player.id, skillId: skill.id),
      );
      final before = player.hp;
      final effectiveHealPercent =
          (skill.healPercentAt(state.level) * (1.0 + affinityBonus)).clamp(
            0.0,
            1.0,
          );
      player.heal((player.stats.maxHp * effectiveHealPercent).round());
      _events.add(
        HealEvent(
          _tick,
          targetId: player.id,
          amount: player.hp - before,
          skillId: skill.id,
        ),
      );
      return;
    }

    if (skill.effect != SkillEffectType.damage) return;
    if (target == null || !target.isAlive || target.team == player.team) {
      return;
    }
    final range = skill.range ?? player.stats.attackRange;
    if (player.distanceTo(target) > range) return;

    _skillStates[skill.id] = state.triggerCooldown(_skillCooldownTicks(skill));
    _events.add(SkillCastEvent(_tick, casterId: player.id, skillId: skill.id));

    final victims = skill.targetType == SkillTarget.area
        ? aliveEnemies
              .where(
                (e) =>
                    e.isAlive &&
                    e.team != player.team &&
                    e.distanceTo(target) <= skill.radius,
              )
              .toList()
        : [target];
    final multiplier =
        skill.damageMultiplierAt(state.level) * (1.0 + affinityBonus);
    final damageType = skill.damageType ?? SkillDamageType.physical;
    for (final victim in victims) {
      if (!player.isAlive || _status != PlayerStatus.alive) break;
      if (!victim.isAlive) continue;
      _strike(
        player,
        victim,
        multiplier: multiplier,
        skillId: skill.id,
        damageType: damageType,
      );
    }
  }

  /// Cooldown skill dalam tick setelah dikurangi Skill Haste (maksimum 75%).
  int _skillCooldownTicks(SkillDefinition skill) {
    final haste = math.min(
      EquipmentStats.maxSkillHaste,
      math.max(0.0, player.stats.skillHaste),
    );
    final seconds = skill.cooldownSeconds * (1 - haste);
    return SkillRuntimeState.secondsToTicks(seconds);
  }

  void _tickSkillCooldowns() {
    for (final id in _skillStates.keys.toList()) {
      _skillStates[id] = _skillStates[id]!.decrementCooldown();
    }
  }

  // ---- Downed / revive ----

  /// GDD 5.1 / 5.2: Downed jika revive tersedia, selain itu run berakhir.
  void _onPlayerDefeated() {
    for (final enemy in _enemies) {
      if (!enemy.isAlive) continue;
      enemy.aggroed = false;
      enemy.targetId = null;
      enemy.plannedGoal = null;
      enemy.aiState = enemy.isAtSpawn
          ? MonsterAiState.idle
          : MonsterAiState.returning;
    }
    if (isReviveAvailable) {
      _status = PlayerStatus.downed;
      _downedTicksLeft = math.max(
        1,
        _secondsToTicks(reviveConfig.delaySeconds),
      );
      _events.add(PlayerDownedEvent(_tick));
    } else {
      _status = PlayerStatus.runEnded;
      _events.add(RunEndedEvent(_tick));
    }
  }

  void _tickDowned() {
    _downedTicksLeft--;
    if (_downedTicksLeft > 0) return;

    player.hp = math.max(
      1,
      (player.stats.maxHp * reviveConfig.hpPercent).round(),
    );
    player.invulnerableTicks = _secondsToTicks(
      reviveConfig.invulnerabilitySeconds,
    );
    player.cooldownTicks = 0;
    player.targetId = null;
    player.plannedGoal = null;
    _reviveCooldownTicks = _secondsToTicks(reviveConfig.cooldownSeconds);
    _status = PlayerStatus.alive;
    _events.add(PlayerRevivedEvent(_tick, player.hp));
  }

  int _secondsToTicks(double seconds) =>
      math.max(0, (seconds * ticksPerSecond).round());

  /// Interval serangan dalam tick (bilangan bulat agar bebas error floating
  /// point): 1 / attackSpeed detik.
  int _intervalTicks(double attackSpeed) =>
      math.max(1, (ticksPerSecond / attackSpeed).round());

  void _tickCooldown(Combatant c) {
    if (c.cooldownTicks > 0) c.cooldownTicks--;
  }
}
