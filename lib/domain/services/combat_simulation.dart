import 'dart:math' as math;

import '../entities/combat_event.dart';
import '../entities/combat_stats.dart';
import '../entities/combatant.dart';
import '../entities/difficulty_config.dart';
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
    this.mechanics = const EliteBossMechanicsConfig(),
    this.cycleRank = 0,
    this.minionProvider,
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
  final EliteBossMechanicsConfig mechanics;
  final int cycleRank;
  final EnemyDefinition Function(Combatant boss)? minionProvider;

  /// Pengaturan auto skill (GDD 2.4): jika false, skill tidak dipakai.
  bool autoSkillEnabled = true;

  final math.Random _random;
  final List<Combatant> _enemies = [];
  final List<Combatant> _allies = [];
  final List<CombatEvent> _events = [];
  final Map<String, EnemyDefinition> _definitions = {};
  int _tick = 0;
  int _spawnCounter = 0;

  /// Id class yang sedang aktif Signature Weapon Resonance-nya (jika ada).
  String? activeResonanceClassId;

  /// Id class yang sedang aktif 4-piece Set Resonance-nya (jika ada).
  String? activeFourPieceClassId;
  int _paladinHolyNovaCooldownTicks = 0;
  int _chronomancerSkillCasts = 0;
  int _voidbladeFrenzyTicks = 0;

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
  List<Combatant> get allies => List.unmodifiable(_allies);
  Iterable<Combatant> get aliveAllies => _allies.where((a) => a.isAlive);

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
    _allies.clear();
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
    if (isBoss) {
      enemy.bossAoECooldownTicks =
          (mechanics.bossAoeCooldownSeconds * ticksPerSecond).round();
      enemy.lifeSiphonCooldownTicks =
          (mechanics.weeklyLifeSiphonCooldownSeconds * ticksPerSecond).round();
    }
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
    if (_paladinHolyNovaCooldownTicks > 0) _paladinHolyNovaCooldownTicks--;
    if (_voidbladeFrenzyTicks > 0) _voidbladeFrenzyTicks--;
    _tickSkillCooldowns();

    _updatePlayer();
    _updateAllies();
    for (final enemy in List<Combatant>.of(_enemies)) {
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

  void _updateAllies() {
    _allies.removeWhere((ally) {
      if (!ally.isAlive) return true;
      if (ally.lifetimeTicks > 0) {
        ally.lifetimeTicks--;
        if (ally.lifetimeTicks <= 0) return true;
      }
      return false;
    });

    for (final ally in List<Combatant>.of(_allies)) {
      if (!ally.isAlive || _status != PlayerStatus.alive) continue;
      _tickCooldown(ally);
      final target = targetSelector.select(
        seeker: ally,
        candidates: aliveEnemies,
      );
      ally.targetId = target?.id;
      if (target == null) continue;
      _engage(ally, target);
    }
  }

  void _updateEnemy(Combatant enemy) {
    _tickCooldown(enemy);
    if (!enemy.isAlive) {
      enemy.aiState = MonsterAiState.dead;
      return;
    }

    // Status efek Weapon Resonance pada musuh
    if (enemy.shadowMarkTicks > 0) {
      enemy.shadowMarkTicks--;
      enemy.isShadowMarked = enemy.shadowMarkTicks > 0;
    }
    if (enemy.shockTicks > 0) {
      enemy.shockTicks--;
      enemy.isShocked = enemy.shockTicks > 0;
    }
    if (enemy.chronoVulnerabilityTicks > 0) {
      enemy.chronoVulnerabilityTicks--;
    }
    if (enemy.freezeTicks > 0) {
      enemy.freezeTicks--;
      return; // Chronomancer Timestop Freeze: musuh diam dan tidak bisa bergerak/menyerang
    }

    if (enemy.aiState == MonsterAiState.returning) {
      _returnToSpawn(enemy);
      return;
    }

    final mechanicsActive = mechanics.isEnabledFor(cycleRank);
    if (mechanicsActive) {
      if (enemy.eliteSpecialCooldownTicks > 0) {
        enemy.eliteSpecialCooldownTicks--;
      }
      if (enemy.bossAoECooldownTicks > 0) {
        enemy.bossAoECooldownTicks--;
      }
      if (enemy.lifeSiphonCooldownTicks > 0) {
        enemy.lifeSiphonCooldownTicks--;
      }
      if (enemy.elementalWardTicks > 0) {
        enemy.elementalWardTicks--;
      }

      // Berserk / Enrage check (Elite / Boss).
      if ((enemy.isElite || enemy.isBoss) && !enemy.isEnraged) {
        final threshold = enemy.isDailyBoss
            ? mechanics.dailyEnragedRushHpThreshold
            : mechanics.berserkHpThreshold;
        if (enemy.hp <= (enemy.stats.maxHp * threshold)) {
          enemy.isEnraged = true;
          final msg = enemy.isDailyBoss ? 'ENRAGED RUSH!' : 'BERSERK!';
          _events.add(
            EnemySpecialEvent(
              _tick,
              enemyId: enemy.id,
              specialType: EnemySpecialType.berserk,
              message: msg,
            ),
          );
        }
      }
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

    if (mechanicsActive && enemy.isBoss) {
      if (enemy.isDailyBoss) {
        // Daily Boss: Elemental Ward
        if (!enemy.hasTriggeredWard &&
            enemy.hp <=
                (enemy.stats.maxHp * mechanics.dailyElementalWardHpThreshold)) {
          _triggerDailyElementalWard(enemy);
        }
        // Daily Boss: Blazing Surge AoE
        if (player.isAlive &&
            _status == PlayerStatus.alive &&
            enemy.bossAoECooldownTicks == 0 &&
            enemy.distanceTo(player) <= mechanics.dailyBlazingSurgeRadius) {
          _triggerDailyBlazingSurge(enemy);
          return;
        }
      } else if (enemy.isWeeklyBoss) {
        // Weekly Boss: Summon Elite Reinforcements
        if (!enemy.hasSummonedMinions &&
            enemy.hp <=
                (enemy.stats.maxHp * mechanics.weeklySummonHpThreshold)) {
          _triggerWeeklySummonMinions(enemy);
        }
        // Weekly Boss: Final Stand
        if (!enemy.isFinalStand &&
            enemy.hp <=
                (enemy.stats.maxHp * mechanics.weeklyFinalStandHpThreshold)) {
          _triggerWeeklyFinalStand(enemy);
        }
        // Weekly Boss: Cataclysm AoE
        if (player.isAlive &&
            _status == PlayerStatus.alive &&
            enemy.bossAoECooldownTicks == 0 &&
            enemy.distanceTo(player) <= mechanics.weeklyCataclysmRadius) {
          _triggerWeeklyCataclysm(enemy);
          return;
        }
        // Weekly Boss: Life Siphon
        if (player.isAlive &&
            _status == PlayerStatus.alive &&
            enemy.lifeSiphonCooldownTicks == 0 &&
            enemy.distanceTo(player) <= enemy.stats.attackRange) {
          _triggerWeeklyLifeSiphon(enemy);
          return;
        }
      } else {
        // Standard Dungeon Boss Summon Minions check.
        if (!enemy.hasSummonedMinions &&
            enemy.hp <= (enemy.stats.maxHp * mechanics.bossSummonHpThreshold)) {
          _triggerBossSummonMinions(enemy);
        }

        // Standard Dungeon Boss Ground Slam / Shockwave AoE check.
        if (player.isAlive &&
            _status == PlayerStatus.alive &&
            enemy.bossAoECooldownTicks == 0 &&
            enemy.distanceTo(player) <= mechanics.bossAoeRadius) {
          _triggerBossGroundSlam(enemy);
          return;
        }
      }
    }

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

  void _triggerDailyElementalWard(Combatant boss) {
    boss.hasTriggeredWard = true;
    boss.elementalWardTicks =
        (mechanics.dailyElementalWardDurationSeconds * ticksPerSecond).round();
    final shieldAmount = (boss.stats.maxHp * 0.10).round();
    boss.addShield(shieldAmount, max: shieldAmount);
    _events.add(
      ShieldEvent(
        _tick,
        targetId: boss.id,
        shieldRemaining: boss.shield,
        absorbedDamage: 0,
      ),
    );
    _events.add(
      EnemySpecialEvent(
        _tick,
        enemyId: boss.id,
        specialType: EnemySpecialType.elementalWard,
        message: 'ELEMENTAL WARD!',
      ),
    );
  }

  void _triggerDailyBlazingSurge(Combatant boss) {
    boss.bossAoECooldownTicks =
        (mechanics.dailyBlazingSurgeCooldownSeconds * ticksPerSecond).round();
    boss.cooldownTicks = math.max(
      boss.cooldownTicks,
      _intervalTicks(boss.stats.attackSpeed),
    );
    final multiplier =
        mechanics.dailyBlazingSurgeMultiplier *
        (boss.isEnraged ? mechanics.dailyEnragedRushAtkMultiplier : 1.0);
    _strike(
      boss,
      player,
      multiplier: multiplier,
      skillId: 'blazing_surge',
      damageType: SkillDamageType.physical,
    );
    _events.add(
      EnemySpecialEvent(
        _tick,
        enemyId: boss.id,
        specialType: EnemySpecialType.blazingSurge,
        message: 'BLAZING SURGE!',
      ),
    );
  }

  void _triggerWeeklySummonMinions(Combatant boss) {
    boss.hasSummonedMinions = true;
    _events.add(
      EnemySpecialEvent(
        _tick,
        enemyId: boss.id,
        specialType: EnemySpecialType.summonMinions,
        message: 'SUMMON ELITE GUARDS!',
      ),
    );

    final bossDef = _definitions[boss.id];
    final minionDef = _resolveMinionDefinition(boss, bossDef, isElite: true);
    final count = mechanics.weeklySummonCount;
    final cells = _findMinionSpawnCells(boss, count);

    for (final cell in cells) {
      final minionId = '${boss.id}__guard_${_spawnCounter++}';
      final minion = spawnEnemy(
        minionDef,
        cell,
        id: minionId,
        isEliteOverride: true,
        isBossOverride: false,
      );
      minion.aggroed = true;
      minion.targetId = player.id;
      minion.aiState = MonsterAiState.chase;
    }
  }

  void _triggerWeeklyFinalStand(Combatant boss) {
    boss.isFinalStand = true;
    boss.isEnraged = true;
    final shieldAmount = (boss.stats.maxHp * 0.05).round();
    boss.addShield(shieldAmount, max: shieldAmount);
    _events.add(
      ShieldEvent(
        _tick,
        targetId: boss.id,
        shieldRemaining: boss.shield,
        absorbedDamage: 0,
      ),
    );
    _events.add(
      EnemySpecialEvent(
        _tick,
        enemyId: boss.id,
        specialType: EnemySpecialType.finalStand,
        message: 'FINAL STAND!',
      ),
    );
  }

  void _triggerWeeklyCataclysm(Combatant boss) {
    boss.bossAoECooldownTicks =
        (mechanics.weeklyCataclysmCooldownSeconds * ticksPerSecond).round();
    boss.cooldownTicks = math.max(
      boss.cooldownTicks,
      _intervalTicks(boss.stats.attackSpeed),
    );
    final multiplier =
        mechanics.weeklyCataclysmMultiplier *
        (boss.isFinalStand
            ? mechanics.weeklyFinalStandAtkMultiplier
            : (boss.isEnraged ? mechanics.berserkAtkMultiplier : 1.0));
    _strike(
      boss,
      player,
      multiplier: multiplier,
      skillId: 'cataclysm',
      damageType: SkillDamageType.physical,
    );
    _events.add(
      EnemySpecialEvent(
        _tick,
        enemyId: boss.id,
        specialType: EnemySpecialType.cataclysm,
        message: 'CATACLYSM!',
      ),
    );
  }

  void _triggerWeeklyLifeSiphon(Combatant boss) {
    boss.lifeSiphonCooldownTicks =
        (mechanics.weeklyLifeSiphonCooldownSeconds * ticksPerSecond).round();
    boss.cooldownTicks = math.max(
      boss.cooldownTicks,
      _intervalTicks(boss.stats.attackSpeed),
    );
    final multiplier =
        mechanics.weeklyLifeSiphonMultiplier *
        (boss.isFinalStand
            ? mechanics.weeklyFinalStandAtkMultiplier
            : (boss.isEnraged ? mechanics.berserkAtkMultiplier : 1.0));
    final prevPlayerHp = player.hp;
    _strike(
      boss,
      player,
      multiplier: multiplier,
      skillId: 'life_siphon',
      damageType: SkillDamageType.physical,
    );
    final dealt = math.max(0, prevPlayerHp - player.hp);
    if (dealt > 0 && boss.isAlive) {
      final healAmount = (dealt * mechanics.weeklyLifeSiphonHealRatio).round();
      boss.heal(healAmount);
      _events.add(
        HealEvent(
          _tick,
          targetId: boss.id,
          amount: healAmount,
          skillId: 'life_siphon',
        ),
      );
    }
    _events.add(
      EnemySpecialEvent(
        _tick,
        enemyId: boss.id,
        specialType: EnemySpecialType.lifeSiphon,
        message: 'LIFE SIPHON!',
      ),
    );
  }

  void _triggerBossGroundSlam(Combatant boss) {
    boss.bossAoECooldownTicks =
        (mechanics.bossAoeCooldownSeconds * ticksPerSecond).round();
    boss.cooldownTicks = math.max(
      boss.cooldownTicks,
      _intervalTicks(boss.stats.attackSpeed),
    );
    final multiplier =
        mechanics.bossAoeMultiplier *
        (boss.isEnraged ? mechanics.berserkAtkMultiplier : 1.0);
    _strike(
      boss,
      player,
      multiplier: multiplier,
      skillId: 'ground_slam',
      damageType: SkillDamageType.physical,
    );
    _events.add(
      EnemySpecialEvent(
        _tick,
        enemyId: boss.id,
        specialType: EnemySpecialType.groundSlam,
        message: 'SHOCKWAVE!',
      ),
    );
  }

  void _triggerBossSummonMinions(Combatant boss) {
    boss.hasSummonedMinions = true;
    final shieldAmount = (boss.stats.maxHp * 0.08).round();
    boss.addShield(shieldAmount, max: shieldAmount);
    _events.add(
      ShieldEvent(
        _tick,
        targetId: boss.id,
        shieldRemaining: boss.shield,
        absorbedDamage: 0,
      ),
    );
    _events.add(
      EnemySpecialEvent(
        _tick,
        enemyId: boss.id,
        specialType: EnemySpecialType.summonMinions,
        message: 'SUMMON GUARDS!',
      ),
    );

    final bossDef = _definitions[boss.id];
    final minionDef = _resolveMinionDefinition(boss, bossDef);
    final count = mechanics.bossSummonCount;
    final cells = _findMinionSpawnCells(boss, count);

    for (final cell in cells) {
      final minionId = '${boss.id}__guard_${_spawnCounter++}';
      final minion = spawnEnemy(
        minionDef,
        cell,
        id: minionId,
        isEliteOverride: false,
        isBossOverride: false,
      );
      minion.aggroed = true;
      minion.targetId = player.id;
      minion.aiState = MonsterAiState.chase;
    }
  }

  EnemyDefinition _resolveMinionDefinition(
    Combatant boss,
    EnemyDefinition? bossDef, {
    bool isElite = false,
  }) {
    final provided = minionProvider?.call(boss);
    if (provided != null) return provided;

    final hpRatio = isElite ? 0.06 : 0.04;
    final atkRatio = isElite ? 0.10 : 0.06;
    final defRatio = isElite ? 0.05 : 0.0;

    if (bossDef != null) {
      return EnemyDefinition(
        id: '${bossDef.id}_guard',
        name: isElite ? '${bossDef.name} Elite Guard' : '${bossDef.name} Guard',
        level: bossDef.level,
        stats: CombatStats(
          maxHp: math.max(10, (bossDef.stats.maxHp * hpRatio).round()),
          atk: math.max(1, (bossDef.stats.atk * atkRatio).round()),
          def: (bossDef.stats.def * defRatio).round(),
          attackSpeed: bossDef.stats.attackSpeed,
          moveSpeed: bossDef.stats.moveSpeed,
          attackRange: bossDef.stats.attackRange,
        ),
        detectionRange: bossDef.detectionRange,
        leashRange: bossDef.leashRange,
        isElite: isElite,
        isBoss: false,
        expReward: 0,
        goldReward: 0,
        spriteRef: bossDef.spriteRef,
        spriteTint: bossDef.spriteTint,
      );
    }

    return EnemyDefinition(
      id: '${boss.id}_guard',
      name: isElite ? 'Boss Elite Guard' : 'Boss Guard',
      level: 1,
      stats: CombatStats(
        maxHp: math.max(
          10,
          (boss.stats.maxHp * (isElite ? 0.25 : 0.15)).round(),
        ),
        atk: math.max(1, (boss.stats.atk * (isElite ? 0.25 : 0.20)).round()),
        def: (boss.stats.def * (isElite ? 0.25 : 0.20)).round(),
        attackSpeed: boss.stats.attackSpeed,
        moveSpeed: boss.stats.moveSpeed,
        attackRange: boss.stats.attackRange,
      ),
      detectionRange: boss.detectionRange,
      leashRange: boss.leashRange,
      isElite: isElite,
      isBoss: false,
    );
  }

  List<GridPoint> _findMinionSpawnCells(Combatant boss, int count) {
    const offsets = [
      (-1, 0),
      (1, 0),
      (0, -1),
      (0, 1),
      (-1, -1),
      (1, -1),
      (-1, 1),
      (1, 1),
      (-2, 0),
      (2, 0),
      (0, -2),
      (0, 2),
    ];
    final bx = boss.follower.currentCell.x;
    final by = boss.follower.currentCell.y;
    final valid = <GridPoint>[];
    for (final (dx, dy) in offsets) {
      final nx = bx + dx;
      final ny = by + dy;
      if (grid.inBounds(nx, ny) && grid.isWalkable(nx, ny)) {
        valid.add(GridPoint(nx, ny));
        if (valid.length >= count) break;
      }
    }
    if (valid.isEmpty) {
      valid.add(boss.follower.currentCell);
    }
    return valid;
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
    final speedMultiplier =
        (mover.isEnraged && mechanics.isEnabledFor(cycleRank)) ? 1.25 : 1.0;
    mover.follower.advance(
      mover.stats.moveSpeed * speedMultiplier * tickSeconds,
    );
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
    final mechanicsActive = mechanics.isEnabledFor(cycleRank);
    var speedMultiplier = 1.0;
    var multiplier = 1.0;
    if (attacker.team == Team.enemy && attacker.isEnraged && mechanicsActive) {
      if (attacker.isDailyBoss) {
        speedMultiplier = mechanics.dailyEnragedRushSpeedMultiplier;
        multiplier *= mechanics.dailyEnragedRushAtkMultiplier;
      } else if (attacker.isWeeklyBoss && attacker.isFinalStand) {
        speedMultiplier = mechanics.weeklyFinalStandSpeedMultiplier;
        multiplier *= mechanics.weeklyFinalStandAtkMultiplier;
      } else {
        speedMultiplier = mechanics.berserkSpeedMultiplier;
        multiplier *= mechanics.berserkAtkMultiplier;
      }
    }
    if (attacker.team == Team.player && _voidbladeFrenzyTicks > 0) {
      speedMultiplier *= 1.3;
    }
    final baseTicks = _intervalTicks(attacker.stats.attackSpeed);
    attacker.cooldownTicks = math.max(1, (baseTicks / speedMultiplier).round());

    String? skillId;
    if (attacker.team == Team.enemy &&
        attacker.isElite &&
        mechanicsActive &&
        attacker.eliteSpecialCooldownTicks == 0) {
      attacker.eliteSpecialCooldownTicks =
          (mechanics.eliteHeavyStrikeCooldownSeconds * ticksPerSecond).round();
      multiplier *= mechanics.eliteHeavyStrikeMultiplier;
      skillId = 'heavy_strike';
      _events.add(
        EnemySpecialEvent(
          _tick,
          enemyId: attacker.id,
          specialType: EnemySpecialType.heavyStrike,
          message: 'HEAVY STRIKE!',
        ),
      );
    }

    _strike(attacker, target, multiplier: multiplier, skillId: skillId);

    // Gunslinger: Serangan dasar menembus seluruh monster dalam garis lurus
    if (attacker.team == Team.player &&
        activeResonanceClassId == 'gunslinger' &&
        skillId == null) {
      _triggerGunslingerPiercingBeam(attacker, target, multiplier);
    }
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

    var defenderDef = target.stats.def;
    var effectiveDamageType = damageType;

    // REC-05: Voidblade Shadow Mark mengabaikan 50% DEF (100% pada 4-piece)
    final isVoidbladeTrueDamage =
        attacker.team == Team.player &&
        activeResonanceClassId == 'voidblade' &&
        (target.isShadowMarked || target.shadowMarkTicks > 0);
    if (isVoidbladeTrueDamage) {
      if (activeFourPieceClassId == 'voidblade') {
        defenderDef = 0;
        _voidbladeFrenzyTicks = (4.0 * ticksPerSecond).round();
      } else {
        defenderDef = (defenderDef * 0.5).round();
      }
    }

    final result = damageCalculator.roll(
      attacker: attacker.stats,
      defenderDef: defenderDef,
      random: _random,
      multiplier: multiplier,
      damageType: effectiveDamageType,
    );

    var finalDamage = result.amount;

    // Stormcaller: Target dengan status Shock menerima +15% damage (+25% pada 4-piece)
    if (target.isShocked || target.shockTicks > 0) {
      final shockMult = activeFourPieceClassId == 'stormcaller' ? 1.25 : 1.15;
      finalDamage = (finalDamage * shockMult).round();
    }

    // Chronomancer 4-piece: Target terkena Chrono Vulnerability menerima +25% damage
    if (target.chronoVulnerabilityTicks > 0) {
      finalDamage = (finalDamage * 1.25).round();
    }

    // Voidblade: Serangan kritikal memberi tanda Shadow Mark
    if (attacker.team == Team.player &&
        activeResonanceClassId == 'voidblade' &&
        result.isCrit) {
      target.shadowMarkTicks = (6.0 * ticksPerSecond).round(); // 120 ticks = 6s
      target.isShadowMarked = true;
      _events.add(
        WeaponResonanceEvent(
          _tick,
          resonanceClassId: 'voidblade',
          trigger: WeaponResonanceTrigger.voidbladeShadowMark,
          targetId: target.id,
          message: 'SHADOW MARK!',
        ),
      );
    }
    if (isVoidbladeTrueDamage) {
      _events.add(
        WeaponResonanceEvent(
          _tick,
          resonanceClassId: 'voidblade',
          trigger: WeaponResonanceTrigger.voidbladeTrueDamage,
          targetId: target.id,
          value: finalDamage,
          message: 'TRUE DAMAGE!',
        ),
      );
    }
    final mechanicsActive = mechanics.isEnabledFor(cycleRank);
    if (mechanicsActive) {
      if (target.isElite && !target.isDailyBoss && !target.isWeeklyBoss) {
        if (target.hp > (target.stats.maxHp * mechanics.stoneskinHpThreshold)) {
          final reduced =
              (finalDamage * (1.0 - mechanics.stoneskinDamageReduction))
                  .round();
          finalDamage = math.max(1, reduced);
        }
      } else if (target.isDailyBoss && target.elementalWardTicks > 0) {
        final reduced =
            (finalDamage * (1.0 - mechanics.dailyElementalWardReduction))
                .round();
        finalDamage = math.max(1, reduced);
      } else if (target.isWeeklyBoss && target.isFinalStand) {
        final reduced =
            (finalDamage * (1.0 - mechanics.weeklyFinalStandDamageReduction))
                .round();
        finalDamage = math.max(1, reduced);
      }
    }

    final unabsorbedDamage = target.absorbDamage(finalDamage);
    final absorbedByShield = finalDamage - unabsorbedDamage;
    if (absorbedByShield > 0) {
      _events.add(
        ShieldEvent(
          _tick,
          targetId: target.id,
          shieldRemaining: target.shield,
          absorbedDamage: absorbedByShield,
        ),
      );
    }
    target.hp = math.max(0, target.hp - unabsorbedDamage);

    // REC-01: Serangan valid memicu aggro musuh terlepas dari jangkauan deteksi
    if (finalDamage > 0 &&
        target.isAlive &&
        target.team == Team.enemy &&
        !target.aggroed &&
        attacker.isAlive) {
      target.aggroed = true;
      target.targetId = attacker.id;
      target.aiState = MonsterAiState.chase;
    }

    // Lifesteal (Basic Attack) & Spell Vamp (Skill Damage)
    if (finalDamage > 0 && attacker.isAlive) {
      if (skillId == null && attacker.stats.lifesteal > 0) {
        final healAmount = (finalDamage * attacker.stats.lifesteal).round();
        if (healAmount > 0) {
          final hpBefore = attacker.hp;
          attacker.heal(healAmount);
          final actualHealed = attacker.hp - hpBefore;
          if (actualHealed > 0) {
            _events.add(
              HealEvent(
                _tick,
                targetId: attacker.id,
                amount: actualHealed,
                skillId: 'lifesteal',
              ),
            );
          }
        }
      } else if (skillId != null && attacker.stats.spellVamp > 0) {
        final healAmount = (finalDamage * attacker.stats.spellVamp).round();
        if (healAmount > 0) {
          final hpBefore = attacker.hp;
          attacker.heal(healAmount);
          final actualHealed = attacker.hp - hpBefore;
          if (actualHealed > 0) {
            _events.add(
              HealEvent(
                _tick,
                targetId: attacker.id,
                amount: actualHealed,
                skillId: 'spell_vamp',
              ),
            );
          }
        }
      }
    }

    _events.add(
      AttackEvent(
        _tick,
        attackerId: attacker.id,
        targetId: target.id,
        damage: finalDamage,
        isCrit: result.isCrit,
        targetHpAfter: target.hp,
        skillId: skillId,
        damageType: result.damageType,
      ),
    );

    // Stormcaller: Serangan petir menyambar ke +2 musuh tambahan & menyebabkan Shock
    if (attacker.team == Team.player &&
        activeResonanceClassId == 'stormcaller' &&
        skillId != 'chain_lightning') {
      target.shockTicks = (4.0 * ticksPerSecond).round();
      target.isShocked = true;
      final chainCandidates =
          aliveEnemies
              .where(
                (e) => !identical(e, target) && target.distanceTo(e) <= 3.0,
              )
              .toList()
            ..sort(
              (a, b) => target.distanceTo(a).compareTo(target.distanceTo(b)),
            );
      final chainCount = activeFourPieceClassId == 'stormcaller' ? 4 : 2;
      for (final extra in chainCandidates.take(chainCount)) {
        extra.shockTicks = (4.0 * ticksPerSecond).round();
        extra.isShocked = true;
        _strike(
          attacker,
          extra,
          multiplier: 0.8,
          damageType: SkillDamageType.magic,
          skillId: 'chain_lightning',
        );
      }
      _events.add(
        WeaponResonanceEvent(
          _tick,
          resonanceClassId: 'stormcaller',
          trigger: WeaponResonanceTrigger.stormcallerChainLightning,
          targetId: target.id,
          message: 'CHAIN LIGHTNING!',
        ),
      );
    }

    // REC-06/07: Paladin Holy Nova retaliation saat menerima damage
    // Dasar: CD 5.0s, Heal 3% Max HP, 35% DEF. 4-piece: CD 3.0s, Heal 6% Max HP, 60% DEF.
    if (identical(target, player) &&
        activeResonanceClassId == 'paladin' &&
        _paladinHolyNovaCooldownTicks == 0 &&
        finalDamage > 0) {
      final isFourPiece = activeFourPieceClassId == 'paladin';
      _paladinHolyNovaCooldownTicks =
          ((isFourPiece ? 3.0 : 5.0) * ticksPerSecond).round();
      final healPct = isFourPiece ? 0.06 : 0.03;
      final healAmount = math.max(1, (player.stats.maxHp * healPct).round());
      player.heal(healAmount);
      _events.add(
        HealEvent(
          _tick,
          targetId: player.id,
          amount: healAmount,
          skillId: 'holy_nova',
        ),
      );
      final defScale = isFourPiece ? 0.60 : 0.35;
      final novaDamage = math.max(1, (player.stats.def * defScale).round());
      final strikeMultiplier = isFourPiece ? (0.60 / 0.35) : 1.0;
      final inRange = aliveEnemies
          .where((e) => player.distanceTo(e) <= 2.0)
          .toList();
      for (final enemy in inRange) {
        _strike(
          player,
          enemy,
          multiplier: strikeMultiplier,
          damageType: SkillDamageType.magic,
          skillId: 'holy_nova_retaliation',
        );
      }
      _events.add(
        WeaponResonanceEvent(
          _tick,
          resonanceClassId: 'paladin',
          trigger: WeaponResonanceTrigger.paladinHolyNova,
          value: novaDamage,
          message: 'HOLY NOVA!',
        ),
      );
    }

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

        // Necromancer: Memanggil Shadow Minion saat musuh gugur
        if (activeResonanceClassId == 'necromancer') {
          _spawnNecromancerMinion(target.follower.currentCell);
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
      _onSkillCastResonanceCheck();
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
    _onSkillCastResonanceCheck();

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

  void _triggerGunslingerPiercingBeam(
    Combatant attacker,
    Combatant primaryTarget,
    double multiplier,
  ) {
    final px = attacker.x;
    final py = attacker.y;
    final tx = primaryTarget.x;
    final ty = primaryTarget.y;
    final vx = tx - px;
    final vy = ty - py;
    final distTarget = math.sqrt(vx * vx + vy * vy);
    if (distTarget < 1e-4) return;
    final ux = vx / distTarget;
    final uy = vy / distTarget;
    final maxDist = attacker.stats.attackRange + 1.0;

    for (final enemy in aliveEnemies) {
      if (identical(enemy, primaryTarget)) continue;
      final ex = enemy.x;
      final ey = enemy.y;
      final wx = ex - px;
      final wy = ey - py;
      final proj = wx * ux + wy * uy;
      if (proj > 0 && proj <= maxDist) {
        final perp2 = (wx * wx + wy * wy) - (proj * proj);
        if (perp2 <= 0.6 * 0.6) {
          final pierceMult = activeFourPieceClassId == 'gunslinger'
              ? multiplier * 1.25
              : multiplier;
          _strike(
            attacker,
            enemy,
            multiplier: pierceMult,
            skillId: 'piercing_beam',
            damageType: SkillDamageType.physical,
          );
          _events.add(
            WeaponResonanceEvent(
              _tick,
              resonanceClassId: 'gunslinger',
              trigger: WeaponResonanceTrigger.gunslingerPiercing,
              targetId: enemy.id,
              message: 'PIERCING BEAM!',
            ),
          );
        }
      }
    }
  }

  void _spawnNecromancerMinion(GridPoint cell) {
    if (_allies.length >= 2) return;
    final isFourPiece = activeFourPieceClassId == 'necromancer';
    final ratio = isFourPiece ? 0.75 : 0.5;
    final durationSeconds = isFourPiece ? 10.0 : 6.0;
    final minionId = 'shadow_minion_${_spawnCounter++}';
    final minionStats = CombatStats(
      maxHp: math.max(1, (player.stats.maxHp * ratio).round()),
      atk: math.max(1, (player.stats.atk * ratio).round()),
      def: (player.stats.def * ratio).round(),
      attackSpeed: player.stats.attackSpeed,
      moveSpeed: player.stats.moveSpeed,
      attackRange: player.stats.attackRange,
    );
    final minion = Combatant(
      id: minionId,
      team: Team.player,
      stats: minionStats,
      cell: cell,
    )..lifetimeTicks = (durationSeconds * ticksPerSecond).round();
    _allies.add(minion);
    _events.add(
      WeaponResonanceEvent(
        _tick,
        resonanceClassId: 'necromancer',
        trigger: WeaponResonanceTrigger.necromancerShadowMinion,
        targetId: minionId,
        message: 'SHADOW MINION RISES!',
      ),
    );
  }

  void _onSkillCastResonanceCheck() {
    if (activeResonanceClassId == 'chronomancer') {
      final isFourPiece = activeFourPieceClassId == 'chronomancer';
      final triggerEvery = isFourPiece ? 3 : 4;
      _chronomancerSkillCasts++;
      if (_chronomancerSkillCasts % triggerEvery == 0) {
        final durationTicks = (2.0 * ticksPerSecond).round();
        for (final enemy in aliveEnemies) {
          if (!enemy.isBoss) {
            enemy.freezeTicks = durationTicks;
          }
          if (isFourPiece) {
            enemy.chronoVulnerabilityTicks = durationTicks;
          }
        }
        _events.add(
          WeaponResonanceEvent(
            _tick,
            resonanceClassId: 'chronomancer',
            trigger: WeaponResonanceTrigger.chronomancerFreeze,
            value: durationTicks,
            message: 'TIMESTOP FREEZE!',
          ),
        );
      }
    }
  }
}
