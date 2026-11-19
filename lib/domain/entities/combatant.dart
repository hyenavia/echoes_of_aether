import 'dart:math' as math;

import '../services/path_follower.dart';
import 'combat_stats.dart';
import 'grid_point.dart';

enum Team { player, enemy }

/// State AI monster (GDD 6.4 / TDD 10.1).
enum MonsterAiState { idle, chase, attack, returning, dead }

/// Peserta combat yang sedang hidup di dunia (player atau musuh).
/// State ini milik domain; komponen Flame hanya membacanya untuk ditampilkan.
class Combatant {
  Combatant({
    required this.id,
    required this.team,
    required this.stats,
    required GridPoint cell,
    this.definitionId,
    this.detectionRange = 0,
    double? leashRange,
    this.isElite = false,
    this.isBoss = false,
  }) : hp = stats.maxHp,
       spawnCell = cell,
       leashRange = leashRange ?? detectionRange * 1.5,
       follower = PathFollower(cell);

  final String id;
  final Team team;
  final String? definitionId;

  /// Dapat berubah (misalnya saat level naik atau ganti equipment).
  CombatStats stats;
  final double detectionRange;
  final double leashRange;
  final bool isElite;
  final bool isBoss;
  final GridPoint spawnCell;
  final PathFollower follower;

  int hp;

  /// Nilai perisai (shield/barrier) saat ini. Menyerap damage sebelum mengurangi [hp].
  int shield = 0;

  /// Kapasitas maksimum perisai (0 jika tidak dibatasi).
  int maxShield = 0;

  /// Sisa tick sebelum boleh menyerang lagi.
  int cooldownTicks = 0;

  /// Selama > 0, serangan yang mengenai combatant ini tidak memberi damage.
  int invulnerableTicks = 0;

  /// Cooldown (tick) skill khusus monster Elite (Heavy Strike).
  int eliteSpecialCooldownTicks = 0;

  /// Cooldown (tick) skill Ground Slam AoE milik Boss.
  int bossAoECooldownTicks = 0;

  /// Penanda apakah Boss sudah pernah memanggil minion guards dalam encounter ini.
  bool hasSummonedMinions = false;

  /// Penanda status Berserk/Enraged saat HP jatuh di bawah ambang batas (Elite / Boss).
  bool isEnraged = false;

  /// Penanda apakah Boss sudah pernah memicu Elemental Ward dalam encounter ini.
  bool hasTriggeredWard = false;

  /// Sisa tick durasi Elemental Ward (selama > 0, menyerap damage sesuai reduksi).
  int elementalWardTicks = 0;

  /// Cooldown (tick) skill Life Siphon milik Weekly Boss.
  int lifeSiphonCooldownTicks = 0;

  /// Penanda status Final Stand saat HP Weekly Boss jatuh di bawah ambang batas final.
  bool isFinalStand = false;

  /// Penanda status Shadow Mark dari Voidblade Signature Resonance.
  bool isShadowMarked = false;
  int shadowMarkTicks = 0;

  /// Penanda durasi Freeze dari Chronomancer Signature Resonance.
  int freezeTicks = 0;
  bool get isFrozen => freezeTicks > 0;

  /// Penanda status Shock (+15% damage diterima) dari Stormcaller Signature Resonance.
  bool isShocked = false;
  int shockTicks = 0;

  /// Sisa tick masa hidup (lifetime) untuk minion temporer seperti Shadow Minion Necromancer.
  int lifetimeTicks = 0;

  bool get isDailyBoss =>
      isBoss &&
      ((definitionId?.startsWith('daily_') ?? false) ||
          id.startsWith('daily_'));

  bool get isWeeklyBoss =>
      isBoss &&
      ((definitionId?.startsWith('weekly_') ?? false) ||
          id.startsWith('weekly_'));

  String? targetId;
  GridPoint? plannedGoal;

  /// Musuh yang sudah mendeteksi player akan terus mengejar.
  bool aggroed = false;
  MonsterAiState aiState = MonsterAiState.idle;

  bool get isAlive => hp > 0;
  bool get isAtSpawn =>
      (x - (spawnCell.x + 0.5)).abs() < 1e-6 &&
      (y - (spawnCell.y + 0.5)).abs() < 1e-6;

  /// Posisi dalam satuan tile (pusat sel = cx + 0.5).
  double get x => follower.x;
  double get y => follower.y;

  double distanceTo(Combatant other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double get distanceToSpawn {
    final dx = x - (spawnCell.x + 0.5);
    final dy = y - (spawnCell.y + 0.5);
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Mengganti stat. Jika max HP naik, HP saat ini ikut naik sebesar selisih
  /// (bukan pemulihan penuh); jika turun, HP dibatasi ke max baru.
  void applyStats(CombatStats newStats) {
    final delta = newStats.maxHp - stats.maxHp;
    stats = newStats;
    if (!isAlive) return;
    hp = delta > 0
        ? math.min(newStats.maxHp, hp + delta)
        : math.min(hp, newStats.maxHp);
  }

  void heal(int amount) {
    if (!isAlive || amount <= 0) return;
    hp = math.min(stats.maxHp, hp + amount);
  }

  /// Menambahkan perisai pelindung sebesar [amount].
  void addShield(int amount, {int? max}) {
    if (!isAlive || amount <= 0) return;
    if (max != null && max > 0) {
      maxShield = math.max(maxShield, max);
      shield = math.min(maxShield, shield + amount);
    } else {
      maxShield = math.max(maxShield, shield + amount);
      shield += amount;
    }
  }

  /// Menyerap [incomingDamage] menggunakan [shield] terlebih dahulu.
  /// Mengembalikan sisa damage yang belum terserap oleh perisai.
  int absorbDamage(int incomingDamage) {
    if (incomingDamage <= 0) return 0;
    if (shield <= 0) return incomingDamage;
    if (shield >= incomingDamage) {
      shield -= incomingDamage;
      return 0;
    } else {
      final unabsorbed = incomingDamage - shield;
      shield = 0;
      return unabsorbed;
    }
  }

  /// Menghapus perisai saat ini.
  void clearShield() {
    shield = 0;
    maxShield = 0;
  }

  /// Menempatkan combatant pada [cell] baru serta membersihkan target dan
  /// rencana jalur navigasi sebelumnya (dipakai saat berpindah room).
  void resetNavigation(GridPoint cell) {
    follower.resetTo(cell);
    targetId = null;
    plannedGoal = null;
    aggroed = false;
  }
}
