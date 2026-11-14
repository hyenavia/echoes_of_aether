import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_status.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/skill_runtime_state.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/damage_calculator.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/domain/services/skill_selector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Musuh statis (detectionRange 0 = tidak pernah mengejar) dengan HP besar.
const dummy = EnemyDefinition(
  id: 'dummy',
  name: 'Dummy',
  level: 1,
  detectionRange: 0,
  stats: CombatStats(
    maxHp: 100000,
    atk: 1,
    def: 0,
    attackSpeed: 1,
    moveSpeed: 1,
    attackRange: 1,
  ),
);

const powerStrike = SkillDefinition(
  id: 'power_strike',
  name: 'Power Strike',
  type: SkillType.active,
  cooldownSeconds: 5,
  damageMultiplier: 1.5,
);
const heavyStrike = SkillDefinition(
  id: 'heavy_strike',
  name: 'Heavy Strike',
  type: SkillType.active,
  cooldownSeconds: 5,
  damageMultiplier: 2.0,
);
const secondWind = SkillDefinition(
  id: 'second_wind',
  name: 'Second Wind',
  type: SkillType.active,
  cooldownSeconds: 25,
  effect: SkillEffectType.healing,
  targetType: SkillTarget.self,
  healPercent: 0.35,
  useWhenHpBelow: 0.4,
);
const burst = SkillDefinition(
  id: 'burst',
  name: 'Burst',
  type: SkillType.active,
  cooldownSeconds: 5,
  damageMultiplier: 1.0,
  targetType: SkillTarget.area,
  radius: 2,
  range: 4,
  minEnemies: 2,
);

Combatant makePlayer({int atk = 20, int hp = 100, double haste = 0}) =>
    Combatant(
      id: 'player',
      team: Team.player,
      stats: CombatStats(
        maxHp: 100,
        atk: atk,
        def: 2,
        attackSpeed: 1,
        moveSpeed: 4,
        attackRange: 1.5,
        skillHaste: haste,
      ),
      cell: const GridPoint(1, 2),
    )..hp = hp;

CombatSimulation makeSim(
  Combatant player,
  List<SkillDefinition> skills, {
  DamageCalculator damageCalculator = const DamageCalculator(),
}) {
  final sim = CombatSimulation(
    grid: NavigationGrid.open(columns: 12, rows: 5),
    pathfinder: const AStarPathfinder(),
    player: player,
    damageCalculator: damageCalculator,
    seed: 1,
  );
  sim.setPlayerSkills(skills);
  return sim;
}

List<CombatEvent> run(CombatSimulation sim, int ticks) {
  final events = <CombatEvent>[];
  for (var i = 0; i < ticks; i++) {
    sim.tick();
    events.addAll(sim.drainEvents());
  }
  return events;
}

Combatant enemyAt(String id, int x, int y, {int hp = 100}) => Combatant(
  id: id,
  team: Team.enemy,
  stats: CombatStats(maxHp: hp, atk: 1, def: 0),
  cell: GridPoint(x, y),
);

void main() {
  group('CombatSimulation + skill', () {
    test('skill dipakai saat siap, lalu menunggu cooldown 5 detik', () {
      final sim = makeSim(makePlayer(), [powerStrike]);
      sim.spawnEnemy(dummy, const GridPoint(2, 2));
      final events = run(sim, 250);

      final casts = events.whereType<SkillCastEvent>().map((e) => e.tick);
      expect(casts.toList(), [1, 101, 201]);

      final skillHits = events.whereType<AttackEvent>().where(
        (e) => e.skillId == 'power_strike',
      );
      expect(skillHits, hasLength(3));
      expect(skillHits.every((e) => e.damage == 30), isTrue); // 20 x 1.5

      // Di sela cooldown, serangan dasar tetap berjalan.
      final basic = events.whereType<AttackEvent>().where(
        (e) => e.skillId == null && e.attackerId == 'player',
      );
      expect(basic, isNotEmpty);
    });

    test('auto skill dimatikan: skill tidak pernah dipakai', () {
      final sim = makeSim(makePlayer(), [powerStrike])
        ..autoSkillEnabled = false;
      sim.spawnEnemy(dummy, const GridPoint(2, 2));
      final events = run(sim, 100);

      expect(events.whereType<SkillCastEvent>(), isEmpty);
      expect(
        events.whereType<AttackEvent>().every((e) => e.skillId == null),
        isTrue,
      );
      expect(events.whereType<AttackEvent>(), isNotEmpty); // serangan dasar
    });

    test(
      'damage skill = ATK x pengali dikurangi DEF musuh (subtractive regresi)',
      () {
        const armored = EnemyDefinition(
          id: 'armored',
          name: 'A',
          level: 1,
          detectionRange: 0,
          stats: CombatStats(maxHp: 100000, atk: 1, def: 5),
        );
        final sim = makeSim(
          makePlayer(),
          [powerStrike],
          damageCalculator: const DamageCalculator(
            formula: DamageFormula.subtractive,
          ),
        );
        sim.spawnEnemy(armored, const GridPoint(2, 2));
        final hit = run(sim, 1).whereType<AttackEvent>().single;
        expect(hit.damage, 25); // round(20 x 1.5) - 5
      },
    );

    test('damage skill memakai rumus rasio default', () {
      const armored = EnemyDefinition(
        id: 'armored',
        name: 'A',
        level: 1,
        detectionRange: 0,
        stats: CombatStats(maxHp: 100000, atk: 1, def: 5),
      );
      final sim = makeSim(makePlayer(), [powerStrike]);
      sim.spawnEnemy(armored, const GridPoint(2, 2));
      final hit = run(sim, 1).whereType<AttackEvent>().single;
      // 30 * 30 / (30 + 5) = 900 / 35 = 25.714... -> round = 26
      expect(hit.damage, 26);
    });

    test('skill yang membunuh musuh memicu EnemyDefeatedEvent', () {
      const weak = EnemyDefinition(
        id: 'weak',
        name: 'W',
        level: 1,
        detectionRange: 0,
        stats: CombatStats(maxHp: 30, atk: 1, def: 0),
      );
      final sim = makeSim(makePlayer(), [heavyStrike]);
      final enemy = sim.spawnEnemy(weak, const GridPoint(2, 2));
      final events = run(sim, 1);
      expect(enemy.isAlive, isFalse);
      expect(events.whereType<DeathEvent>(), hasLength(1));
      expect(events.whereType<EnemyDefeatedEvent>(), hasLength(1));
    });

    test('Skill Haste memperpendek cooldown', () {
      final sim = makeSim(makePlayer(haste: 0.5), [powerStrike]);
      sim.spawnEnemy(dummy, const GridPoint(2, 2));
      final casts = run(
        sim,
        120,
      ).whereType<SkillCastEvent>().map((e) => e.tick).toList();
      expect(casts, [1, 51, 101]); // 5 detik x 50% = 2.5 detik = 50 tick
    });

    test('Skill Haste dibatasi 75%', () {
      final sim = makeSim(makePlayer(haste: 5.0), [powerStrike]);
      sim.spawnEnemy(dummy, const GridPoint(2, 2));
      final casts = run(
        sim,
        60,
      ).whereType<SkillCastEvent>().map((e) => e.tick).toList();
      expect(casts, [1, 26, 51]); // 5 detik x 25% = 1.25 detik = 25 tick
    });

    test('healing dipakai saat HP di bawah ambang, tanpa perlu musuh', () {
      final player = makePlayer(hp: 30);
      final sim = makeSim(player, [secondWind]);
      final events = run(sim, 1);

      final heal = events.whereType<HealEvent>().single;
      expect(heal.amount, 35);
      expect(player.hp, 65);
      // HP sudah di atas ambang dan skill dalam cooldown: tidak ada lagi.
      expect(run(sim, 200).whereType<HealEvent>(), isEmpty);
    });

    test('healing dilaporkan sebesar pemulihan nyata (dibatasi max HP)', () {
      const bigHeal = SkillDefinition(
        id: 'big',
        name: 'Big',
        type: SkillType.active,
        cooldownSeconds: 10,
        effect: SkillEffectType.healing,
        targetType: SkillTarget.self,
        healPercent: 1.0,
        useWhenHpBelow: 0.4,
      );
      final player = makePlayer(hp: 30);
      final sim = makeSim(player, [bigHeal]);
      expect(run(sim, 1).whereType<HealEvent>().single.amount, 70);
      expect(player.hp, 100);
    });

    test('healing tidak dipakai saat HP di atas ambang', () {
      final sim = makeSim(makePlayer(hp: 100), [secondWind]);
      expect(run(sim, 40).whereType<SkillCastEvent>(), isEmpty);
      final sim2 = makeSim(makePlayer(hp: 50), [secondWind]);
      expect(run(sim2, 40).whereType<SkillCastEvent>(), isEmpty);
    });

    test('prioritas: healing lebih dulu daripada skill damage', () {
      final sim = makeSim(makePlayer(hp: 20), [powerStrike, secondWind]);
      sim.spawnEnemy(dummy, const GridPoint(2, 2));
      final casts = run(sim, 3).whereType<SkillCastEvent>().toList();
      expect(casts.first.skillId, 'second_wind');
    });

    test('skill area mengenai musuh dalam radius dan tidak yang di luar', () {
      final sim = makeSim(makePlayer(), [burst]);
      final a = sim.spawnEnemy(dummy, const GridPoint(3, 2)); // target utama
      final b = sim.spawnEnemy(dummy, const GridPoint(3, 3)); // jarak 1 dari a
      final c = sim.spawnEnemy(dummy, const GridPoint(10, 2)); // jauh
      final hits = run(sim, 1)
          .whereType<AttackEvent>()
          .where((e) => e.skillId == 'burst')
          .map((e) => e.targetId)
          .toSet();
      expect(hits, {a.id, b.id});
      expect(hits.contains(c.id), isFalse);
    });

    test(
      'skill area tidak dipakai jika musuh kurang; skill tunggal dipakai',
      () {
        final sim = makeSim(makePlayer(), [burst, powerStrike]);
        sim.spawnEnemy(dummy, const GridPoint(2, 2));
        sim.spawnEnemy(dummy, const GridPoint(10, 2)); // di luar radius
        final first = run(sim, 1).whereType<SkillCastEvent>().single;
        expect(first.skillId, 'power_strike');
      },
    );

    test('mengganti daftar skill mempertahankan cooldown yang berjalan', () {
      final sim = makeSim(makePlayer(), [powerStrike]);
      sim.spawnEnemy(dummy, const GridPoint(2, 2));
      run(sim, 10);
      expect(sim.skillCooldownTicks('power_strike'), 91);

      sim.setPlayerSkills([powerStrike, secondWind]);
      expect(sim.skillCooldownTicks('power_strike'), 91);

      sim.setPlayerSkills(const []);
      expect(sim.skillCooldownTicks('power_strike'), 0);
      expect(sim.playerSkills, isEmpty);
    });

    test('hasil deterministik untuk seed yang sama', () {
      List<String> runOnce() {
        final sim = makeSim(makePlayer(), [powerStrike, burst]);
        sim.spawnEnemy(dummy, const GridPoint(3, 2));
        sim.spawnEnemy(dummy, const GridPoint(3, 3));
        return run(sim, 300)
            .whereType<AttackEvent>()
            .map((e) => '${e.tick}:${e.targetId}:${e.damage}:${e.skillId}')
            .toList();
      }

      expect(runOnce(), runOnce());
    });
  });

  group('SkillSelector', () {
    const selector = SkillSelector();
    final caster = makePlayer();

    test('null jika tidak ada skill yang siap', () {
      final target = enemyAt('e1', 2, 2);
      expect(
        selector.select(
          skills: const [powerStrike],
          isReady: (_) => false,
          caster: caster,
          target: target,
          enemies: [target],
        ),
        isNull,
      );
    });

    test('null jika target di luar jangkauan skill', () {
      final far = enemyAt('e1', 9, 2);
      expect(
        selector.select(
          skills: const [powerStrike],
          isReady: (_) => true,
          caster: caster,
          target: far,
          enemies: [far],
        ),
        isNull,
      );
    });

    test('area lebih diprioritaskan daripada skill tunggal', () {
      final a = enemyAt('a', 3, 2);
      final b = enemyAt('b', 3, 3);
      final picked = selector.select(
        skills: const [powerStrike, burst],
        isReady: (_) => true,
        caster: caster,
        target: a,
        enemies: [a, b],
      );
      expect(picked?.id, 'burst');
    });

    test('dalam kategori sama dipilih yang terkuat, lalu id terkecil', () {
      final target = enemyAt('e1', 2, 2);
      SkillDefinition? pick(List<SkillDefinition> skills) => selector.select(
        skills: skills,
        isReady: (_) => true,
        caster: caster,
        target: target,
        enemies: [target],
      );

      expect(pick(const [powerStrike, heavyStrike])?.id, 'heavy_strike');
      const sameA = SkillDefinition(
        id: 'a',
        name: 'A',
        type: SkillType.active,
        cooldownSeconds: 1,
        damageMultiplier: 1.5,
      );
      expect(pick(const [powerStrike, sameA])?.id, 'a');
    });

    test('skill pasif diabaikan', () {
      const passive = SkillDefinition(
        id: 'p',
        name: 'P',
        type: SkillType.passive,
      );
      final target = enemyAt('e1', 2, 2);
      expect(
        selector.select(
          skills: const [passive],
          isReady: (_) => true,
          caster: caster,
          target: target,
          enemies: [target],
        ),
        isNull,
      );
    });
  });

  group('SkillRuntimeState', () {
    test('initial state dan konversi cooldown 50 ms per tick', () {
      const state = SkillRuntimeState(skillId: 'power_strike');
      expect(state.skillId, 'power_strike');
      expect(state.level, 1);
      expect(state.unlocked, isFalse);
      expect(state.cooldownTicksRemaining, 0);
      expect(state.isReady, isFalse);

      expect(SkillRuntimeState.ticksPerSecond, 20);
      expect(SkillRuntimeState.secondsToTicks(5.0), 100);
      expect(SkillRuntimeState.secondsToTicks(0.05), 1);
      expect(SkillRuntimeState.secondsToTicks(0), 0);
    });

    test('cooldown decrement, selesai menjadi siap, dan reset cooldown', () {
      const initial = SkillRuntimeState(
        skillId: 'power_strike',
        unlocked: true,
      );
      var state = initial.triggerCooldown(3);
      expect(state.isReady, isFalse);
      expect(state.cooldownTicksRemaining, 3);

      state = state.decrementCooldown();
      expect(state.cooldownTicksRemaining, 2);
      expect(state.isReady, isFalse);

      state = state.decrementCooldown().decrementCooldown();
      expect(state.cooldownTicksRemaining, 0);
      expect(state.isReady, isTrue);

      // Decrement lagi tetap 0, tidak negatif.
      expect(state.decrementCooldown().cooldownTicksRemaining, 0);

      // Reset mengosongkan cooldown yang sedang berjalan.
      final reset = state.triggerCooldown(50).resetCooldown();
      expect(reset.cooldownTicksRemaining, 0);
      expect(reset.isReady, isTrue);
    });

    test('skill yang belum unlocked tidak dieksekusi di CombatSimulation', () {
      final sim = CombatSimulation(
        grid: NavigationGrid.open(columns: 6, rows: 5),
        pathfinder: const AStarPathfinder(),
        player: makePlayer(),
        seed: 1,
      );
      sim.setPlayerSkills(
        const [powerStrike],
        runtimeStates: const {
          'power_strike': SkillRuntimeState(
            skillId: 'power_strike',
            unlocked: false,
          ),
        },
      );
      sim.spawnEnemy(dummy, const GridPoint(2, 2));
      final events = run(sim, 40);
      expect(events.whereType<SkillCastEvent>(), isEmpty);
      expect(events.whereType<AttackEvent>(), isNotEmpty);
    });
  });

  group('Skill progression & upgrade', () {
    const prog = ProgressionConfig(
      maxLevel: 10,
      expBase: 100,
      expGrowth: 1.5,
      baseStats: CombatStats(maxHp: 100, atk: 10, def: 2),
      perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
    );
    const catalog = <String, SkillDefinition>{
      'power_strike': SkillDefinition(
        id: 'power_strike',
        name: 'Power Strike',
        type: SkillType.active,
        damageType: SkillDamageType.physical,
        unlockLevel: 2,
        cooldownSeconds: 5,
        damageMultiplier: 1.5,
        valuePerLevel: 0.2,
        maxLevel: 3,
        upgradeCost: 50,
      ),
      'vitality': SkillDefinition(
        id: 'vitality',
        name: 'Vitality',
        type: SkillType.passive,
        unlockLevel: 1,
        valuePerLevel: 0.5,
        maxLevel: 3,
        upgradeCost: 40,
        passiveStats: EquipmentStats(hp: 20, def: 2),
      ),
    };

    test('skill terkunci tidak dapat di-upgrade dan gold tidak berkurang', () {
      final char = PlayerCharacter(
        config: prog,
        progress: const PlayerProgress(level: 1, gold: 500),
        skillCatalog: catalog,
      );

      expect(char.skillRuntimeState('power_strike').unlocked, isFalse);
      final result = char.upgradeSkill('power_strike');
      expect(result.succeeded, isFalse);
      expect(result.status, SkillUpgradeStatus.locked);
      expect(char.gold, 500);
      expect(char.skillLevel('power_strike'), 1);
    });

    test(
      'upgrade gagal jika gold tidak cukup dan state tidak berubah sebagian',
      () {
        final char = PlayerCharacter(
          config: prog,
          progress: const PlayerProgress(level: 2, gold: 49),
          skillCatalog: catalog,
        );

        expect(char.skillRuntimeState('power_strike').unlocked, isTrue);
        final result = char.upgradeSkill('power_strike');
        expect(result.succeeded, isFalse);
        expect(result.status, SkillUpgradeStatus.insufficientGold);
        expect(char.gold, 49);
        expect(char.skillLevel('power_strike'), 1);
      },
    );

    test('upgrade skill berhasil memotong gold, menskalakan efek, dan berhenti di maxLevel', () {
      final char = PlayerCharacter(
        config: prog,
        progress: const PlayerProgress(level: 2, gold: 200),
        skillCatalog: catalog,
      );

      // Lv 1 -> Lv 2 (biaya 50)
      final up1 = char.upgradeSkill('power_strike');
      expect(up1.succeeded, isTrue);
      expect(up1.status, SkillUpgradeStatus.upgraded);
      expect(up1.newLevel, 2);
      expect(up1.goldSpent, 50);
      expect(char.gold, 150);
      expect(
        catalog['power_strike']!.damageMultiplierAt(2),
        closeTo(1.7, 1e-9),
      );

      // Lv 2 -> Lv 3 (maxLevel, biaya 100)
      final up2 = char.upgradeSkill('power_strike');
      expect(up2.succeeded, isTrue);
      expect(up2.newLevel, 3);
      expect(up2.goldSpent, 100);
      expect(char.gold, 50);

      // Sudah maxLevel: gagal, sisa gold tetap 50.
      final upMax = char.upgradeSkill('power_strike');
      expect(upMax.succeeded, isFalse);
      expect(upMax.status, SkillUpgradeStatus.maxLevelReached);
      expect(char.gold, 50);
      expect(char.skillLevel('power_strike'), 3);

      // Passive skill upgrade juga menskalakan derived stats karakter.
      final baseHp = char.stats.maxHp;
      final upPassive = char.upgradeSkill('vitality'); // biaya 40 -> sisa 10
      expect(upPassive.succeeded, isTrue);
      expect(char.gold, 10);
      expect(char.stats.maxHp, baseHp + 10); // 20 * 0.5 tambahan
    });

    test('skill aktif level tinggi menggunakan multiplier terskalakan dalam CombatSimulation', () {
      final scaledSkill = catalog['power_strike']!;
      final sim = CombatSimulation(
        grid: NavigationGrid.open(columns: 6, rows: 5),
        pathfinder: const AStarPathfinder(),
        player: makePlayer(atk: 20),
        seed: 1,
      );
      sim.setPlayerSkills(
        [scaledSkill],
        runtimeStates: const {
          'power_strike': SkillRuntimeState(
            skillId: 'power_strike',
            level: 3, // multiplier = 1.5 + 0.2 * 2 = 1.9 -> 20 * 1.9 = 38
            unlocked: true,
          ),
        },
      );
      sim.spawnEnemy(dummy, const GridPoint(2, 2));
      final hit = run(sim, 1).whereType<AttackEvent>().single;
      expect(hit.skillId, 'power_strike');
      expect(hit.damage, 38);
    });
  });

  group('M4 Phase B — Automatic Skill Execution', () {
    const gddPowerStrike = SkillDefinition(
      id: 'power_strike',
      name: 'Power Strike',
      type: SkillType.active,
      effect: SkillEffectType.damage,
      damageType: SkillDamageType.physical,
      targetType: SkillTarget.single,
      cooldownSeconds: 5,
      baseValue: 1.5,
      valuePerLevel: 0.2,
      maxLevel: 5,
    );
    const gddAetherBurst = SkillDefinition(
      id: 'aether_burst',
      name: 'Aether Burst',
      type: SkillType.active,
      effect: SkillEffectType.damage,
      damageType: SkillDamageType.magic,
      targetType: SkillTarget.area,
      cooldownSeconds: 8,
      baseValue: 1.25,
      valuePerLevel: 0.15,
      maxLevel: 5,
      radius: 2,
      range: 4,
      minEnemies: 2,
    );
    const gddHealingPulse = SkillDefinition(
      id: 'healing_pulse',
      name: 'Healing Pulse',
      type: SkillType.active,
      effect: SkillEffectType.healing,
      targetType: SkillTarget.self,
      cooldownSeconds: 18,
      baseValue: 0.30,
      valuePerLevel: 0.05,
      maxLevel: 5,
    );
    const gddVitality = SkillDefinition(
      id: 'vitality',
      name: 'Vitality',
      type: SkillType.passive,
      effect: SkillEffectType.statModifier,
      valuePerLevel: 0.25,
      maxLevel: 5,
      passiveStats: EquipmentStats(hp: 25, def: 2),
    );
    const gddFocus = SkillDefinition(
      id: 'focus',
      name: 'Focus',
      type: SkillType.passive,
      effect: SkillEffectType.statModifier,
      valuePerLevel: 0.25,
      maxLevel: 5,
      passiveStats: EquipmentStats(atk: 4, critRate: 0.03),
    );

    test('prioritas penuh: Healing Pulse -> Aether Burst -> Power Strike -> tidak memblokir saat syarat gagal', () {
      const selector = SkillSelector(defaultHealThreshold: 0.5);
      final e1 = enemyAt('e1', 2, 2);
      final e2 = enemyAt('e2', 3, 2);
      const skills = [gddPowerStrike, gddAetherBurst, gddHealingPulse];

      // HP 40/100 < threshold 0.5 -> Healing Pulse
      final wounded = makePlayer(hp: 40);
      expect(
        selector
            .select(
              skills: skills,
              isReady: (_) => true,
              caster: wounded,
              target: e1,
              enemies: [e1, e2],
            )
            ?.id,
        'healing_pulse',
      );

      // HP 60/100 >= threshold 0.5 (Healing Pulse tidak memenuhi syarat, tidak memblokir),
      // 2 musuh berdekatan -> Aether Burst.
      final healthy = makePlayer(hp: 60);
      expect(
        selector
            .select(
              skills: skills,
              isReady: (_) => true,
              caster: healthy,
              target: e1,
              enemies: [e1, e2],
            )
            ?.id,
        'aether_burst',
      );

      // Hanya 1 musuh valid di sekitar target -> Aether Burst skipped, jatuh ke Power Strike.
      expect(
        selector
            .select(
              skills: skills,
              isReady: (_) => true,
              caster: healthy,
              target: e1,
              enemies: [e1],
            )
            ?.id,
        'power_strike',
      );
    });

    test('Power Strike menghasilkan physical damage & Aether Burst menghasilkan magic AoE sesuai level', () {
      // Test Power Strike physical
      final simPhys = CombatSimulation(
        grid: NavigationGrid.open(columns: 8, rows: 5),
        pathfinder: const AStarPathfinder(),
        player: makePlayer(atk: 20),
        seed: 1,
      );
      simPhys.setPlayerSkills(
        const [gddPowerStrike],
        runtimeStates: const {
          'power_strike': SkillRuntimeState(
            skillId: 'power_strike',
            level: 2, // 1.5 + 0.2 = 1.7 -> 34 damage
            unlocked: true,
          ),
        },
      );
      simPhys.spawnEnemy(dummy, const GridPoint(2, 2));
      final physHit = run(simPhys, 1).whereType<AttackEvent>().single;
      expect(physHit.skillId, 'power_strike');
      expect(physHit.damageType, SkillDamageType.physical);
      expect(physHit.damage, 34);

      // Test Aether Burst magic AoE
      final simMagic = CombatSimulation(
        grid: NavigationGrid.open(columns: 12, rows: 5),
        pathfinder: const AStarPathfinder(),
        player: makePlayer(atk: 20),
        seed: 1,
      );
      simMagic.setPlayerSkills(
        const [gddAetherBurst],
        runtimeStates: const {
          'aether_burst': SkillRuntimeState(
            skillId: 'aether_burst',
            level: 3, // 1.25 + 0.30 = 1.55 -> 31 magic damage
            unlocked: true,
          ),
        },
      );
      final near1 = simMagic.spawnEnemy(dummy, const GridPoint(2, 2));
      final near2 = simMagic.spawnEnemy(dummy, const GridPoint(3, 2));
      final far = simMagic.spawnEnemy(dummy, const GridPoint(10, 2));

      final events = run(simMagic, 1);
      final magicHits = events.whereType<AttackEvent>().toList();
      expect(magicHits.map((e) => e.targetId).toSet(), {near1.id, near2.id});
      expect(magicHits.any((e) => e.targetId == far.id), isFalse);
      expect(
        magicHits.every(
          (e) =>
              e.skillId == 'aether_burst' &&
              e.damageType == SkillDamageType.magic &&
              e.damage == 31,
        ),
        isTrue,
      );
    });

    test('Healing Pulse berskala sesuai level dan dibatasi maxHp', () {
      final player = makePlayer(hp: 30);
      final sim = CombatSimulation(
        grid: NavigationGrid.open(columns: 6, rows: 5),
        pathfinder: const AStarPathfinder(),
        player: player,
        seed: 1,
      );
      sim.setPlayerSkills(
        const [gddHealingPulse],
        runtimeStates: const {
          'healing_pulse': SkillRuntimeState(
            skillId: 'healing_pulse',
            level: 3, // 0.30 + 0.05*2 = 0.40 -> +40 HP
            unlocked: true,
          ),
        },
      );
      final heal = run(sim, 1).whereType<HealEvent>().single;
      expect(heal.skillId, 'healing_pulse');
      expect(heal.amount, 40);
      expect(player.hp, 70);
    });

    test('skill pasif Vitality & Focus memodifikasi derived stats namun tidak pernah di-cast', () {
      const prog = ProgressionConfig(
        maxLevel: 10,
        expBase: 100,
        expGrowth: 1.5,
        baseStats: CombatStats(maxHp: 100, atk: 10, def: 2),
        perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
      );
      final char = PlayerCharacter(
        config: prog,
        progress: const PlayerProgress(level: 1),
        skillCatalog: const {'vitality': gddVitality, 'focus': gddFocus},
      );
      expect(char.stats.maxHp, 125); // +25 dari Vitality
      expect(char.stats.def, 4); // +2 dari Vitality
      expect(char.stats.atk, 14); // +4 dari Focus
      expect(char.stats.critRate, closeTo(0.03, 1e-9));

      final sim = CombatSimulation(
        grid: NavigationGrid.open(columns: 6, rows: 5),
        pathfinder: const AStarPathfinder(),
        player: makePlayer(),
        seed: 1,
      );
      sim.setPlayerSkills(const [gddVitality, gddFocus, gddPowerStrike]);
      sim.spawnEnemy(dummy, const GridPoint(2, 2));
      final events = run(sim, 1);
      final casts = events.whereType<SkillCastEvent>().toList();
      expect(casts, hasLength(1));
      expect(casts.single.skillId, 'power_strike');
    });

    test('SkillSelector menolak target mati atau rekan satu tim, serta caster mati', () {
      const selector = SkillSelector();
      final deadTarget = enemyAt('dead', 2, 2, hp: 0);
      final allyTarget = Combatant(
        id: 'ally',
        team: Team.player,
        stats: const CombatStats(maxHp: 100, atk: 10, def: 0),
        cell: const GridPoint(2, 2),
      );
      final aliveCaster = makePlayer();
      final deadCaster = makePlayer(hp: 0);

      expect(
        selector.select(
          skills: const [gddPowerStrike],
          isReady: (_) => true,
          caster: aliveCaster,
          target: deadTarget,
          enemies: [deadTarget],
        ),
        isNull,
      );
      expect(
        selector.select(
          skills: const [gddPowerStrike],
          isReady: (_) => true,
          caster: aliveCaster,
          target: allyTarget,
          enemies: [allyTarget],
        ),
        isNull,
      );
      expect(
        selector.select(
          skills: const [gddHealingPulse],
          isReady: (_) => true,
          caster: deadCaster,
          target: null,
          enemies: const [],
        ),
        isNull,
      );
    });

    test(
      'state Downed dan RunEnded mencegah eksekusi skill maupun basic attack',
      () {
        const killer = EnemyDefinition(
          id: 'killer',
          name: 'Killer',
          level: 1,
          detectionRange: 10,
          stats: CombatStats(maxHp: 500, atk: 200, def: 0, attackSpeed: 1),
        );
        final player = makePlayer(hp: 20);
        final sim = CombatSimulation(
          grid: NavigationGrid.open(columns: 6, rows: 5),
          pathfinder: const AStarPathfinder(),
          player: player,
          seed: 1,
          reviveConfig: const ReviveConfig(
            delaySeconds: 1.0,
            cooldownSeconds: 60.0,
            hpPercent: 0.5,
            invulnerabilitySeconds: 0,
          ),
        );
        // Power Strike saja sehingga saat musuh menyerang di tick 1 player tumbang -> Downed.
        sim.setPlayerSkills(const [gddPowerStrike]);
        sim.spawnEnemy(killer, const GridPoint(2, 2));

        // Tick 1: player cast power_strike, lalu killer membunuh player -> Downed.
        final tick1 = run(sim, 1);
        expect(tick1.whereType<PlayerDownedEvent>(), hasLength(1));
        expect(sim.playerStatus, PlayerStatus.downed);

        // Beri healing_pulse siap pakai selama Downed: tidak boleh dieksekusi selama Downed!
        sim.setPlayerSkills(const [gddHealingPulse]);
        final duringDowned = run(sim, 10);
        expect(duringDowned.whereType<SkillCastEvent>(), isEmpty);
        expect(duringDowned.whereType<HealEvent>(), isEmpty);
        expect(duringDowned.whereType<AttackEvent>(), isEmpty);

        // Selesaikan sisa Downed hingga revive, lalu biarkan killer menjatuhkan lagi -> RunEnded.
        sim.setPlayerSkills(const [gddPowerStrike]);
        run(sim, 35);
        expect(sim.playerStatus, PlayerStatus.runEnded);
        sim.setPlayerSkills(const [gddHealingPulse]);
        final afterRunEnded = run(sim, 20);
        expect(afterRunEnded.whereType<SkillCastEvent>(), isEmpty);
        expect(afterRunEnded.whereType<HealEvent>(), isEmpty);
        expect(afterRunEnded.whereType<AttackEvent>(), isEmpty);
      },
    );

    test('maksimal satu skill dieksekusi per tick dan jatuh ke basic attack saat cooldown', () {
      final player = makePlayer(hp: 20); // cukup rendah untuk Healing Pulse
      final sim = CombatSimulation(
        grid: NavigationGrid.open(columns: 6, rows: 5),
        pathfinder: const AStarPathfinder(),
        player: player,
        seed: 1,
      );
      sim.setPlayerSkills(const [
        gddHealingPulse,
        gddAetherBurst,
        gddPowerStrike,
      ]);
      sim.spawnEnemy(dummy, const GridPoint(2, 2));
      sim.spawnEnemy(dummy, const GridPoint(2, 3));

      // Tick 1: hanya Healing Pulse (tidak ada AttackEvent player pada tick yang sama).
      final t1 = run(sim, 1);
      final casts1 = t1.whereType<SkillCastEvent>().toList();
      expect(casts1.map((e) => e.skillId), ['healing_pulse']);
      expect(
        t1.whereType<AttackEvent>().where((e) => e.attackerId == 'player'),
        isEmpty,
      );

      // Tick 2: Healing Pulse cooldown -> Aether Burst (1 skill saja).
      final t2 = run(sim, 1);
      final casts2 = t2.whereType<SkillCastEvent>().toList();
      expect(casts2.map((e) => e.skillId), ['aether_burst']);
      expect(
        t2.whereType<AttackEvent>().where(
          (e) => e.attackerId == 'player' && e.skillId == null,
        ),
        isEmpty,
      );

      // Tick 3: Power Strike (1 skill saja).
      final t3 = run(sim, 1);
      final casts3 = t3.whereType<SkillCastEvent>().toList();
      expect(casts3.map((e) => e.skillId), ['power_strike']);

      // Tick 4: seluruh skill cooldown -> basic attack fallback.
      final t4 = run(sim, 1);
      expect(t4.whereType<SkillCastEvent>(), isEmpty);
      final basic4 = t4
          .whereType<AttackEvent>()
          .where((e) => e.attackerId == 'player')
          .single;
      expect(basic4.skillId, isNull);
      expect(basic4.damageType, SkillDamageType.physical);
    });
  });
}
