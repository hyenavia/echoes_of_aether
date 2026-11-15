import '../../core/utils/number_formatter.dart';
import '../../domain/entities/combat_stats.dart';
import '../../domain/entities/equipment.dart';

String _n(double value) {
  final r = (value * 10).round() / 10;
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
}

/// Ringkasan bonus stat, misalnya "ATK +4.2, CRIT +2%".
String describeEquipmentStats(EquipmentStats s) {
  final parts = <String>[
    if (s.hp != 0) 'HP +${_n(s.hp)}',
    if (s.hpPct != 0) 'HP +${_n(s.hpPct * 100)}%',
    if (s.atk != 0) 'ATK +${_n(s.atk)}',
    if (s.atkPct != 0) 'ATK +${_n(s.atkPct * 100)}%',
    if (s.def != 0) 'DEF +${_n(s.def)}',
    if (s.defPct != 0) 'DEF +${_n(s.defPct * 100)}%',
    if (s.critRate != 0) 'CRIT +${_n(s.critRate * 100)}%',
    if (s.critDamage != 0) 'CRIT DMG +${_n(s.critDamage * 100)}%',
    if (s.attackSpeed != 0) 'ASPD +${_n(s.attackSpeed)}',
    if (s.moveSpeed != 0) 'SPD +${_n(s.moveSpeed)}',
    if (s.attackRange != 0) 'RANGE +${_n(s.attackRange)}',
    if (s.skillHaste != 0) 'HASTE +${_n(s.skillHaste * 100)}%',
  ];
  return parts.join(', ');
}

/// Ringkasan stat tempur akhir karakter.
String describeCombatStats(CombatStats s) {
  final haste = s.skillHaste > 0 ? '  HASTE ${_n(s.skillHaste * 100)}%' : '';
  return 'HP ${NumberFormatter.format(s.maxHp)}  '
      'ATK ${NumberFormatter.format(s.atk)}  '
      'DEF ${NumberFormatter.format(s.def)}\n'
      'CRIT ${_n(s.critRate * 100)}%  CRIT DMG ${_n(s.critDamage * 100)}%  '
      'ASPD ${s.attackSpeed.toStringAsFixed(2)}$haste\n'
      'RANGE ${_n(s.attackRange)}';
}

String slotLabel(EquipmentSlot slot) => switch (slot) {
  EquipmentSlot.weapon => 'Senjata',
  EquipmentSlot.head => 'Kepala',
  EquipmentSlot.body => 'Badan',
  EquipmentSlot.accessory => 'Aksesori',
};

/// Delta stat antara item kandidat dan item yang sedang terpasang.
typedef EquipmentStatDelta = ({String label, double delta, bool isPercent});

/// Menghitung selisih stat (candidate - current) yang bernilai non-nol.
List<EquipmentStatDelta> computeEquipmentStatDeltas(
  EquipmentStats candidate,
  EquipmentStats current,
) {
  return <EquipmentStatDelta>[
    (label: 'HP', delta: candidate.hp - current.hp, isPercent: false),
    (
      label: 'HP',
      delta: (candidate.hpPct - current.hpPct) * 100,
      isPercent: true,
    ),
    (label: 'ATK', delta: candidate.atk - current.atk, isPercent: false),
    (
      label: 'ATK',
      delta: (candidate.atkPct - current.atkPct) * 100,
      isPercent: true,
    ),
    (label: 'DEF', delta: candidate.def - current.def, isPercent: false),
    (
      label: 'DEF',
      delta: (candidate.defPct - current.defPct) * 100,
      isPercent: true,
    ),
    (
      label: 'CRIT',
      delta: (candidate.critRate - current.critRate) * 100,
      isPercent: true,
    ),
    (
      label: 'CRIT DMG',
      delta: (candidate.critDamage - current.critDamage) * 100,
      isPercent: true,
    ),
    (
      label: 'ASPD',
      delta: candidate.attackSpeed - current.attackSpeed,
      isPercent: false,
    ),
    (
      label: 'SPD',
      delta: candidate.moveSpeed - current.moveSpeed,
      isPercent: false,
    ),
    (
      label: 'RANGE',
      delta: candidate.attackRange - current.attackRange,
      isPercent: false,
    ),
    (
      label: 'HASTE',
      delta: (candidate.skillHaste - current.skillHaste) * 100,
      isPercent: true,
    ),
  ].where((e) => e.delta.abs() >= 0.05).toList();
}

/// Memformat nilai delta stat dengan tanda `+` atau `-`.
String formatStatDelta(double delta, {bool isPercent = false}) {
  final sign = delta >= 0 ? '+' : '-';
  final mag = _n(delta.abs());
  return isPercent ? '$sign$mag%' : '$sign$mag';
}
