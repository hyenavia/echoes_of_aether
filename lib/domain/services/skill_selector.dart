import '../entities/combatant.dart';
import '../entities/skill_definition.dart';

/// Memilih skill yang dipakai otomatis (GDD 2.4). Prioritas:
/// 1. Healing, jika HP di bawah ambang.
/// 2. Serangan area, jika cukup musuh berkumpul di sekitar target.
/// 3. Skill damage tunggal, jika target dalam jangkauan.
/// Dalam satu kategori dipilih skill terkuat, lalu id terkecil (deterministik).
class SkillSelector {
  const SkillSelector({this.defaultHealThreshold = 0.4});

  final double defaultHealThreshold;

  SkillDefinition? select({
    required Iterable<SkillDefinition> skills,
    required bool Function(SkillDefinition skill) isReady,
    required Combatant caster,
    required Combatant? target,
    required Iterable<Combatant> enemies,
  }) {
    if (!caster.isAlive) return null;

    SkillDefinition? bestHeal;
    SkillDefinition? bestArea;
    SkillDefinition? bestSingle;

    final maxHp = caster.stats.maxHp;
    final hpRatio = maxHp <= 0 ? 1.0 : caster.hp / maxHp;

    for (final skill in skills) {
      if (!skill.isActive ||
          skill.effect == SkillEffectType.statModifier ||
          !isReady(skill)) {
        continue;
      }

      if (skill.effect == SkillEffectType.healing) {
        final threshold = skill.useWhenHpBelow ?? defaultHealThreshold;
        if (hpRatio < threshold && caster.hp < maxHp) {
          bestHeal = _stronger(bestHeal, skill);
        }
      } else if (target != null &&
          target.isAlive &&
          target.team != caster.team) {
        final range = skill.range ?? caster.stats.attackRange;
        if (caster.distanceTo(target) > range) continue;

        if (skill.targetType == SkillTarget.area) {
          final nearby = enemies
              .where(
                (e) =>
                    e.isAlive &&
                    e.team != caster.team &&
                    e.distanceTo(target) <= skill.radius,
              )
              .length;
          if (nearby >= skill.minEnemies) bestArea = _stronger(bestArea, skill);
        } else {
          bestSingle = _stronger(bestSingle, skill);
        }
      }
    }
    return bestHeal ?? bestArea ?? bestSingle;
  }

  SkillDefinition _stronger(SkillDefinition? current, SkillDefinition next) {
    if (current == null) return next;
    if (next.power != current.power) {
      return next.power > current.power ? next : current;
    }
    return next.id.compareTo(current.id) < 0 ? next : current;
  }
}
