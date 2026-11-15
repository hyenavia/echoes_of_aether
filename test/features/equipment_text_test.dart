import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/features/dungeon/equipment_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ringkasan bonus: bilangan bulat tanpa desimal, persen untuk crit', () {
    expect(
      describeEquipmentStats(const EquipmentStats(atk: 4, critRate: 0.02)),
      'ATK +4, CRIT +2%',
    );
  });

  test('nilai pecahan ditampilkan satu desimal', () {
    expect(
      describeEquipmentStats(const EquipmentStats(atk: 4.23, hp: 10.0)),
      'HP +10, ATK +4.2',
    );
  });

  test(
    'skill haste, move speed, dan attack range ditampilkan saat tidak nol',
    () {
      expect(
        describeEquipmentStats(const EquipmentStats(skillHaste: 0.05)),
        'HASTE +5%',
      );
      expect(
        describeEquipmentStats(
          const EquipmentStats(
            skillHaste: 0.05,
            moveSpeed: 1.2,
            attackRange: 0.5,
          ),
        ),
        'SPD +1.2, RANGE +0.5, HASTE +5%',
      );
    },
  );

  test('semua stat nol menghasilkan teks kosong', () {
    expect(describeEquipmentStats(EquipmentStats.zero), '');
  });

  test('ringkasan stat akhir termasuk jangkauan', () {
    const s = CombatStats(
      maxHp: 120,
      atk: 14,
      def: 3,
      attackSpeed: 1.6,
      critRate: 0.12,
      critDamage: 1.5,
    );
    expect(
      describeCombatStats(s),
      'HP 120  ATK 14  DEF 3\nCRIT 12%  CRIT DMG 150%  ASPD 1.60\nRANGE 1',
    );
  });

  test('haste hanya tampil jika lebih dari nol', () {
    const s = CombatStats(
      maxHp: 1,
      atk: 1,
      def: 0,
      attackSpeed: 1.0,
      critRate: 0.1,
      critDamage: 1.5,
      attackRange: 4.0,
      skillHaste: 0.15,
    );
    expect(
      describeCombatStats(s),
      'HP 1  ATK 1  DEF 0\nCRIT 10%  CRIT DMG 150%  ASPD 1.00  HASTE 15%\nRANGE 4',
    );
  });

  test('label slot', () {
    expect(slotLabel(EquipmentSlot.weapon), 'Senjata');
    expect(slotLabel(EquipmentSlot.accessory), 'Aksesori');
  });

  test('describeEquipmentStats menampilkan stat persentase', () {
    expect(
      describeEquipmentStats(
        const EquipmentStats(hpPct: 0.1, atkPct: 0.155, defPct: 0.05),
      ),
      'HP +10%, ATK +15.5%, DEF +5%',
    );
    expect(
      describeEquipmentStats(const EquipmentStats(atk: 12, atkPct: 0.1)),
      'ATK +12, ATK +10%',
    );
  });

  test('computeEquipmentStatDeltas menghitung delta stat persentase', () {
    final deltas = computeEquipmentStatDeltas(
      const EquipmentStats(atk: 10, hpPct: 0.15, atkPct: 0.1, defPct: 0.05),
      const EquipmentStats(atk: 10, hpPct: 0.05, defPct: 0.1),
    );
    expect(
      deltas.map(
        (d) => '${d.label} ${formatStatDelta(d.delta, isPercent: d.isPercent)}',
      ),
      ['HP +10%', 'ATK +10%', 'DEF -5%'],
    );
  });
}
