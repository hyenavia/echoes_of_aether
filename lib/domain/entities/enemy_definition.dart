import 'combat_stats.dart';

/// Kategori monster untuk scaling encounter dan sumber reward.
enum EnemyTier { normal, elite, boss }

/// Definisi statis satu jenis monster (dari monsters.json).
/// Instance musuh yang hidup di dungeon adalah `Combatant`.
class EnemyDefinition {
  const EnemyDefinition({
    required this.id,
    required this.name,
    required this.level,
    required this.stats,
    this.detectionRange = 6.0,
    this.leashRange,
    this.isElite = false,
    this.isBoss = false,
    this.expReward = 0,
    this.goldReward = 0,
    this.lootTableId,
    this.spriteRef,
    this.spriteTint,
    this.isFinalBoss = false,
  });

  final String id;
  final String name;
  final int level;
  final CombatStats stats;

  /// Jarak (tile) saat musuh mulai mengejar player.
  final double detectionRange;

  /// Jarak maksimum dari spawn/target sebelum musuh kembali ke posisi awal.
  /// Null memakai `detectionRange * 1.5`.
  final double? leashRange;

  final bool isElite;
  final bool isBoss;

  /// Referensi species sprite opsional (fallback ke [id] di renderer).
  final String? spriteRef;

  /// Tint warna opsional dalam format hex `#RRGGBB` / `#AARRGGBB`.
  final String? spriteTint;

  /// Penanda UI untuk boss terakhir dalam progresi dungeon normal.
  final bool isFinalBoss;

  EnemyTier get tier {
    if (isBoss) return EnemyTier.boss;
    if (isElite) return EnemyTier.elite;
    return EnemyTier.normal;
  }

  /// EXP dan gold yang diberikan saat musuh dikalahkan.
  final int expReward;
  final int goldReward;

  /// Id loot table di loot_tables.json; null berarti tidak menjatuhkan loot.
  final String? lootTableId;
}
