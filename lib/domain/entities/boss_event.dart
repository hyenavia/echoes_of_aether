import '../services/period_service.dart';
import 'combat_stats.dart';
import 'dungeon_definition.dart';
import 'enemy_definition.dart';

/// Stat dasar boss event sebelum dikalikan profil acuan dan `power_factor`.
class BossBaseStats {
  const BossBaseStats({
    required this.hp,
    required this.atk,
    required this.def,
    this.lifesteal = 0.0,
    this.spellVamp = 0.0,
  });

  final int hp;
  final int atk;
  final int def;
  final double lifesteal;
  final double spellVamp;
}

/// Hadiah quest untuk mengalahkan Daily/Weekly Boss.
class BossQuestReward {
  const BossQuestReward({
    this.currency = const {},
    this.exp = 0,
    this.gold = 0,
  });

  final Map<String, int> currency;
  final int exp;
  final int gold;
}

/// Definisi satu boss di dalam pool Daily atau Weekly Boss Event.
class BossEvent {
  const BossEvent({
    required this.id,
    required this.name,
    required this.spriteRef,
    this.spriteTint,
    required this.baseStats,
  });

  final String id;
  final String name;
  final String spriteRef;
  final String? spriteTint;
  final BossBaseStats baseStats;

  /// Mengonversi [BossEvent] menjadi [EnemyDefinition] untuk simulasi combat
  /// runtime (`EncounterTracker` / `CombatSimulation`). Hadiah monster disetel
  /// `0` karena hadiah boss diberikan melalui sistem Boss Quest (Stage 4).
  EnemyDefinition toEnemyDefinition({
    int level = 1,
    EnemyDefinition? spriteTemplate,
  }) {
    final baseTemplateStats = spriteTemplate?.stats;
    return EnemyDefinition(
      id: id,
      name: name,
      level: level < 1 ? 1 : level,
      isBoss: true,
      spriteRef: spriteRef,
      spriteTint: spriteTint,
      stats: CombatStats(
        maxHp: baseStats.hp,
        atk: baseStats.atk,
        def: baseStats.def,
        attackSpeed: baseTemplateStats?.attackSpeed ?? 1.0,
        critRate: baseTemplateStats?.critRate ?? 0.0,
        critDamage: baseTemplateStats?.critDamage ?? 1.5,
        moveSpeed: baseTemplateStats?.moveSpeed ?? 1.4,
        attackRange: baseTemplateStats?.attackRange ?? 1.5,
        skillHaste: baseTemplateStats?.skillHaste ?? 0.0,
        lifesteal: baseStats.lifesteal,
        spellVamp: baseStats.spellVamp,
      ),
      detectionRange: spriteTemplate?.detectionRange ?? 10.0,
      expReward: 0,
      goldReward: 0,
    );
  }
}

/// Konfigurasi satu tier Boss Event (`daily` atau `weekly`).
class BossTierConfig {
  const BossTierConfig({
    this.period,
    required this.questId,
    required this.powerFactor,
    required this.reward,
    required this.pool,
  });

  final Period? period;
  final String questId;
  final double powerFactor;
  final BossQuestReward reward;
  final List<BossEvent> pool;
}

/// Konfigurasi lengkap dari `assets/data/boss_events.json`.
class BossEventsConfig {
  const BossEventsConfig({
    required this.daily,
    required this.weekly,
    required this.arenaMapRef,
  });

  final BossTierConfig daily;
  final BossTierConfig weekly;
  final String arenaMapRef;

  /// Mengembalikan konfigurasi tier untuk [period] sebagai satu sumber kebenaran.
  BossTierConfig tierFor(Period period) => switch (period) {
    Period.daily => daily,
    Period.weekly => weekly,
  };

  /// Menentukan [Period] otoritatif berdasarkan `quest_id` dari konfigurasi.
  Period? periodForQuestId(String questId) {
    final normalized = questId.trim();
    if (normalized.isEmpty) return null;
    if (normalized == daily.questId.trim()) return daily.period ?? Period.daily;
    if (normalized == weekly.questId.trim()) {
      return weekly.period ?? Period.weekly;
    }
    return null;
  }

  /// Menentukan [Period] otoritatif berdasarkan ID boss pada pool.
  Period? periodForBossId(String bossId) {
    final normalized = bossId.trim();
    if (normalized.isEmpty) return null;
    if (daily.pool.any((b) => b.id == normalized)) {
      return daily.period ?? Period.daily;
    }
    if (weekly.pool.any((b) => b.id == normalized)) {
      return weekly.period ?? Period.weekly;
    }
    return null;
  }

  /// Menentukan [Period] untuk sebuah sesi/run boss tanpa fallback diam-diam ke
  /// `Period.daily`. Mengembalikan `null` jika identitas tidak dikenali.
  Period? periodForSession({
    DungeonDefinition? dungeon,
    String? bossEventId,
    String? dungeonId,
  }) {
    if (dungeon != null) {
      if (dungeon.kind == DungeonKind.bossWeekly) return Period.weekly;
      if (dungeon.kind == DungeonKind.bossDaily) return Period.daily;
    }
    if (bossEventId != null) {
      final byBoss = periodForBossId(bossEventId);
      if (byBoss != null) return byBoss;
    }
    if (dungeonId != null) {
      if (dungeonId.startsWith('boss_weekly:')) return Period.weekly;
      if (dungeonId.startsWith('boss_daily:')) return Period.daily;
    }
    return null;
  }

  BossEvent? findBossById(String bossId) {
    for (final boss in daily.pool) {
      if (boss.id == bossId) return boss;
    }
    for (final boss in weekly.pool) {
      if (boss.id == bossId) return boss;
    }
    return null;
  }
}

/// Acuan kesulitan Boss Event berdasarkan dungeon normal tertinggi yang sudah
/// diselesaikan pada `ascensionRank` terpilih.
class BossReference {
  const BossReference({required this.dungeon, required this.cycleRank});

  final DungeonDefinition dungeon;
  final int cycleRank;
}
