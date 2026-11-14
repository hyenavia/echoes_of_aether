/// Atribut tempur (GDD 2.3). Immutable.
class CombatStats {
  const CombatStats({
    required this.maxHp,
    required this.atk,
    required this.def,
    this.attackSpeed = 1.0,
    this.critRate = 0.0,
    this.critDamage = 1.5,
    this.moveSpeed = 1.0,
    this.attackRange = 1.0,
    this.skillHaste = 0.0,
  });

  final int maxHp;
  final int atk;
  final int def;

  /// Jumlah serangan per detik.
  final double attackSpeed;

  /// Peluang critical, 0.0 sampai 1.0.
  final double critRate;

  /// Pengali damage saat critical (1.5 = +50%).
  final double critDamage;

  /// Kecepatan gerak dalam tile per detik.
  final double moveSpeed;

  /// Jangkauan serangan dalam tile (jarak pusat ke pusat).
  final double attackRange;

  /// Pengurangan cooldown skill (0.1 = 10% lebih cepat).
  final double skillHaste;

  CombatStats withAttackRange(double range) => CombatStats(
    maxHp: maxHp,
    atk: atk,
    def: def,
    attackSpeed: attackSpeed,
    critRate: critRate,
    critDamage: critDamage,
    moveSpeed: moveSpeed,
    attackRange: range,
    skillHaste: skillHaste,
  );
}
