import '../../domain/entities/combat_stats.dart';

/// Stat player sementara untuk pengujian combat. Pada Milestone 4 stat
/// dihitung dari level, atribut dasar, dan equipment.
///
/// HP sengaja rendah agar death/revive/akhir-run mudah terlihat saat uji.
class TestPlayer {
  TestPlayer._();

  static const CombatStats stats = CombatStats(
    maxHp: 100,
    atk: 12,
    def: 2,
    attackSpeed: 1.5,
    critRate: 0.1,
    critDamage: 1.5,
    moveSpeed: 4,
    attackRange: 1.5,
  );
}
