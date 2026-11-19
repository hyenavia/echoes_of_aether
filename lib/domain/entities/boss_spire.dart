import 'boss_event.dart';
import 'combat_stats.dart';
import 'enemy_definition.dart';

/// Konfigurasi untuk satu lantai pada Menara Bos (Boss Spire).
class BossSpireFloorConfig {
  const BossSpireFloorConfig({
    required this.floor,
    required this.name,
    required this.bossId,
    required this.bossName,
    required this.spriteRef,
    this.spriteTint,
    required this.recommendedLevel,
    this.affixDescription,
    required this.baseStats,
    required this.firstClearReward,
  });

  final int floor;
  final String name;
  final String bossId;
  final String bossName;
  final String spriteRef;
  final String? spriteTint;
  final int recommendedLevel;
  final String? affixDescription;
  final BossBaseStats baseStats;
  final BossQuestReward firstClearReward;

  /// ID klaim unik dan persisten untuk melacak first-clear reward di [ClaimedEvents].
  String get claimId => 'boss_spire:floor_$floor';

  /// ID klaim untuk siklus dua mingguan tertentu [cycleKey] ('YYYY-MM-DD').
  String claimIdFor(String cycleKey) => 'boss_spire:$cycleKey:floor_$floor';

  /// ID dungeon runtime untuk lantai menara ini.
  String get dungeonId => 'boss_spire:floor_$floor';

  /// Mengonversi lantai ini menjadi [EnemyDefinition] untuk simulasi combat.
  EnemyDefinition toEnemyDefinition({EnemyDefinition? spriteTemplate}) {
    final baseTemplateStats = spriteTemplate?.stats;
    return EnemyDefinition(
      id: bossId,
      name: bossName,
      level: recommendedLevel < 1 ? 1 : recommendedLevel,
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

/// Konfigurasi Menara Bos dari `assets/data/boss_spire.json`.
class BossSpireConfig {
  const BossSpireConfig({
    required this.spireId,
    required this.name,
    required this.arenaMapRef,
    required this.floors,
  });

  final String spireId;
  final String name;
  final String arenaMapRef;
  final List<BossSpireFloorConfig> floors;

  int get maxFloor => floors.isEmpty ? 0 : floors.last.floor;

  BossSpireFloorConfig? floorFor(int floor) {
    for (final f in floors) {
      if (f.floor == floor) return f;
    }
    return null;
  }

  bool hasFloor(int floor) => floorFor(floor) != null;
}

/// Progres pemain di Menara Bos (dihitung dari set [claimedEventIds]).
class BossSpireProgress {
  const BossSpireProgress({
    this.highestClearedFloor = 0,
    this.clearedFloors = const {},
  });

  final int highestClearedFloor;
  final Set<int> clearedFloors;

  bool isFloorCleared(int floor) => clearedFloors.contains(floor);

  bool isFloorUnlocked(int floor) => floor == 1 || isFloorCleared(floor - 1);

  int get nextUnlockedFloor => highestClearedFloor + 1;

  static BossSpireProgress fromClaimedEventIds(
    Set<String> claimedEventIds, {
    int maxFloor = 20,
    String? cycleKey,
  }) {
    final cleared = <int>{};
    var highest = 0;
    for (var f = 1; f <= maxFloor; f++) {
      final isCleared = cycleKey == null
          ? claimedEventIds.contains('boss_spire:floor_$f')
          : (claimedEventIds.contains('boss_spire:$cycleKey:floor_$f') ||
                (cycleKey == '2026-11-16' &&
                    claimedEventIds.contains('boss_spire:floor_$f')));
      if (isCleared) {
        cleared.add(f);
        if (f > highest) {
          highest = f;
        }
      }
    }
    return BossSpireProgress(
      highestClearedFloor: highest,
      clearedFloors: Set.unmodifiable(cleared),
    );
  }
}

/// Hasil penyelesaian kemenangan pertempuran di Menara Bos.
class BossSpireSettlementResult {
  const BossSpireSettlementResult({
    required this.floor,
    required this.isFirstClear,
    required this.reward,
    required this.userMessage,
    this.claimId,
  });

  final int floor;
  final bool isFirstClear;
  final BossQuestReward reward;
  final String userMessage;
  final String? claimId;
}
