import '../../domain/entities/skill_definition.dart';
import 'equipment_text.dart';

String _n(double value) {
  final r = (value * 10).round() / 10;
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
}

/// Deskripsi ringkas skill (mendukung skala level skill) untuk layar karakter.
String describeSkill(SkillDefinition s, {int level = 1}) {
  if (s.isPassive) {
    return 'Pasif: ${describeEquipmentStats(s.passiveStatsAt(level))}';
  }

  final cooldown = 'Cooldown ${_n(s.cooldownSeconds)}s';
  if (s.effect == SkillEffectType.healing) {
    final below = ((s.useWhenHpBelow ?? 0.4) * 100).round();
    return '$cooldown, pulihkan ${_n(s.healPercentAt(level) * 100)}% HP '
        '(otomatis saat HP < $below%)';
  }
  final area = s.targetType == SkillTarget.area
      ? ', area r${_n(s.radius)} (min ${s.minEnemies} musuh)'
      : '';
  return '$cooldown, DMG x${_n(s.damageMultiplierAt(level))}$area';
}
