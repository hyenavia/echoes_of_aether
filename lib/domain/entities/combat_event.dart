import 'enemy_definition.dart';
import 'skill_definition.dart';

/// Peristiwa yang dihasilkan simulasi combat. Game Layer membacanya untuk
/// efek visual (angka damage, animasi mati, dst.).
sealed class CombatEvent {
  const CombatEvent(this.tick);

  final int tick;
}

/// Serangan terjadi. [damage] bernilai 0 jika diblokir invulnerability.
/// [skillId] terisi jika serangan berasal dari skill.
final class AttackEvent extends CombatEvent {
  const AttackEvent(
    super.tick, {
    required this.attackerId,
    required this.targetId,
    required this.damage,
    required this.isCrit,
    required this.targetHpAfter,
    this.skillId,
    this.damageType = SkillDamageType.physical,
  });

  final String attackerId;
  final String targetId;
  final int damage;
  final bool isCrit;
  final int targetHpAfter;
  final String? skillId;
  final SkillDamageType damageType;
}

final class DeathEvent extends CombatEvent {
  const DeathEvent(super.tick, this.combatantId);

  final String combatantId;
}

/// Player masuk state Downed dan akan di-revive otomatis.
final class PlayerDownedEvent extends CombatEvent {
  const PlayerDownedEvent(super.tick);
}

final class PlayerRevivedEvent extends CombatEvent {
  const PlayerRevivedEvent(super.tick, this.hp);

  final int hp;
}

/// Player kalah saat revive cooldown: dungeon run berakhir.
final class RunEndedEvent extends CombatEvent {
  const RunEndedEvent(super.tick);
}

/// Musuh dikalahkan. Membawa definisinya agar reward (EXP, gold, loot) dapat
/// diproses di luar simulasi.
final class EnemyDefeatedEvent extends CombatEvent {
  const EnemyDefeatedEvent(super.tick, this.enemyId, this.definition);

  final String enemyId;
  final EnemyDefinition definition;
}

/// Sebuah skill dijalankan secara otomatis.
final class SkillCastEvent extends CombatEvent {
  const SkillCastEvent(
    super.tick, {
    required this.casterId,
    required this.skillId,
  });

  final String casterId;
  final String skillId;
}

/// HP dipulihkan (misalnya oleh skill healing). [amount] adalah pemulihan
/// yang benar-benar terjadi.
final class HealEvent extends CombatEvent {
  const HealEvent(
    super.tick, {
    required this.targetId,
    required this.amount,
    this.skillId,
  });

  final String targetId;
  final int amount;
  final String? skillId;
}
