import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/services/target_selector.dart';
import 'package:flutter_test/flutter_test.dart';

Combatant make(
  String id,
  GridPoint cell, {
  Team team = Team.enemy,
  int hp = 50,
  double range = 1.0,
  bool isElite = false,
}) {
  final c = Combatant(
    id: id,
    team: team,
    stats: CombatStats(maxHp: 100, atk: 5, def: 0, attackRange: range),
    cell: cell,
    isElite: isElite,
  );
  c.hp = hp;
  return c;
}

void main() {
  const selector = TargetSelector();
  final player = make('player', const GridPoint(0, 0), team: Team.player);

  test('memilih musuh terdekat', () {
    final far = make('far', const GridPoint(5, 0));
    final near = make('near', const GridPoint(2, 0));
    expect(selector.select(seeker: player, candidates: [far, near]), near);
  });

  test('musuh yang sedang menyerang diprioritaskan walau lebih jauh', () {
    final near = make('near', const GridPoint(2, 0));
    final attacker = make('attacker', const GridPoint(3, 0), range: 5);
    attacker.targetId = player.id;
    expect(
      selector.select(seeker: player, candidates: [near, attacker]),
      attacker,
    );
  });

  test('jarak sama: pilih HP terendah', () {
    final healthy = make('a', const GridPoint(3, 0), hp: 80);
    final weak = make('b', const GridPoint(-3, 0), hp: 10);
    expect(selector.select(seeker: player, candidates: [healthy, weak]), weak);
  });

  test('jarak dan HP sama: pilih ID terkecil (deterministik)', () {
    final a = make('a', const GridPoint(3, 0));
    final b = make('b', const GridPoint(-3, 0));
    expect(selector.select(seeker: player, candidates: [b, a]), a);
    expect(selector.select(seeker: player, candidates: [a, b]), a);
  });

  test('mengabaikan musuh yang sudah mati dan null jika tidak ada', () {
    final dead = make('dead', const GridPoint(1, 0), hp: 0);
    expect(selector.select(seeker: player, candidates: [dead]), isNull);
    expect(selector.select(seeker: player, candidates: const []), isNull);
  });

  test('prioritas dapat dikonfigurasi: elite dan lowestHp', () {
    final normalNear = make('normal', const GridPoint(2, 0), hp: 10);
    final eliteFar = make(
      'elite',
      const GridPoint(5, 0),
      hp: 90,
      isElite: true,
    );

    const eliteFirst = TargetSelector(
      priority: TargetPriorityConfig(
        order: [TargetPriorityCriterion.elite, TargetPriorityCriterion.nearest],
      ),
    );
    expect(
      eliteFirst.select(seeker: player, candidates: [normalNear, eliteFar]),
      eliteFar,
    );

    const lowestHpFirst = TargetSelector(
      priority: TargetPriorityConfig(
        order: [
          TargetPriorityCriterion.lowestHp,
          TargetPriorityCriterion.nearest,
        ],
      ),
    );
    expect(
      lowestHpFirst.select(seeker: player, candidates: [eliteFar, normalNear]),
      normalNear,
    );
  });
}
