import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/player_status.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:flutter_test/flutter_test.dart';

/// Musuh yang membunuh player (HP 10) dengan satu serangan per detik.
const brute = EnemyDefinition(
  id: 'brute',
  name: 'Brute',
  level: 1,
  detectionRange: 10,
  stats: CombatStats(
    maxHp: 1000,
    atk: 10,
    def: 0,
    attackSpeed: 1,
    moveSpeed: 2,
    attackRange: 1.0,
  ),
);

({CombatSimulation sim, Combatant player, Combatant enemy}) setup([
  ReviveConfig config = const ReviveConfig(),
]) {
  final player = Combatant(
    id: 'player',
    team: Team.player,
    stats: const CombatStats(
      maxHp: 10,
      atk: 11,
      def: 0,
      attackSpeed: 1,
      moveSpeed: 4,
      attackRange: 1.5,
    ),
    cell: const GridPoint(1, 1),
  );
  final sim = CombatSimulation(
    grid: NavigationGrid.open(columns: 5, rows: 3),
    pathfinder: const AStarPathfinder(),
    player: player,
    reviveConfig: config,
    seed: 1,
  );
  final enemy = sim.spawnEnemy(brute, const GridPoint(2, 1));
  return (sim: sim, player: player, enemy: enemy);
}

/// Menjalankan [ticks] tick dan mengumpulkan semua event.
List<CombatEvent> run(CombatSimulation sim, int ticks) {
  final events = <CombatEvent>[];
  for (var i = 0; i < ticks; i++) {
    sim.tick();
    events.addAll(sim.drainEvents());
  }
  return events;
}

void main() {
  test('HP nol membuat player Downed dan combat berhenti sementara', () {
    final s = setup();
    final events = run(s.sim, 1);

    expect(s.player.hp, 0);
    expect(s.sim.playerStatus, PlayerStatus.downed);
    expect(events.whereType<PlayerDownedEvent>(), hasLength(1));

    final enemyHp = s.enemy.hp;
    final enemyX = s.enemy.x;
    run(s.sim, 50);
    expect(s.sim.playerStatus, PlayerStatus.downed);
    expect(s.enemy.hp, enemyHp);
    expect(s.enemy.x, enemyX);
  });

  test(
    'revive otomatis setelah 3 detik dengan 30% HP dan cooldown dimulai',
    () {
      final s = setup();
      final events = run(s.sim, 70);

      expect(s.sim.playerStatus, PlayerStatus.alive);
      expect(events.whereType<PlayerRevivedEvent>(), hasLength(1));
      expect(s.player.hp, 3); // 30% dari 10
      expect(s.sim.reviveCooldownTicks, greaterThan(0));
      expect(s.sim.isReviveAvailable, isFalse);
    },
  );

  test('invulnerability menahan serangan setelah revive', () {
    final s = setup();
    final events = run(s.sim, 95);

    final blocked = events.whereType<AttackEvent>().where(
      (e) => e.targetId == 'player' && e.tick > 61 && e.damage == 0,
    );
    expect(blocked, isNotEmpty);
    expect(s.player.hp, 3);
    expect(s.sim.playerStatus, PlayerStatus.alive);
  });

  test('kalah saat revive cooldown mengakhiri run', () {
    final s = setup();
    final events = run(s.sim, 400);

    expect(s.sim.playerStatus, PlayerStatus.runEnded);
    expect(events.whereType<RunEndedEvent>(), hasLength(1));
    expect(s.player.hp, 0);

    final enemyHp = s.enemy.hp;
    run(s.sim, 50);
    expect(s.enemy.hp, enemyHp); // simulasi berhenti
  });

  test('revive tersedia lagi setelah cooldown selesai', () {
    final s = setup(
      const ReviveConfig(
        delaySeconds: 0.5,
        hpPercent: 0.5,
        invulnerabilitySeconds: 0,
        cooldownSeconds: 0.5,
      ),
    );
    final events = run(s.sim, 120);

    expect(
      events.whereType<PlayerDownedEvent>().length,
      greaterThanOrEqualTo(2),
    );
    expect(events.whereType<RunEndedEvent>(), isEmpty);
    expect(s.sim.playerStatus, isNot(PlayerStatus.runEnded));
  });
}
