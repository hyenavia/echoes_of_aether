import 'dart:io';
import 'dart:math' as math;

import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_loadout.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/damage_calculator.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_progression_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/progression_service.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';

/// Profil gear per tier dungeon yang dibangun langsung dari [GameConfig.items]
/// berdasarkan batas rarity maksimum per slot.
class TierGearProfile {
  const TierGearProfile({
    required this.name,
    required this.maxRarity,
    required this.specializationId,
    required this.itemsBySlot,
  });

  final String name;
  final ItemRarity maxRarity;
  final String? specializationId;
  final Map<EquipmentSlot, ItemDefinition> itemsBySlot;

  String describeGear() => itemsBySlot.values.map((e) => e.id).join(', ');
}

/// Hasil simulasi batch multi-seed untuk satu skenario (dungeon, level, rank, gear).
class DungeonScenarioMetrics {
  const DungeonScenarioMetrics({
    required this.dungeonId,
    required this.dungeonName,
    required this.scenarioLabel,
    required this.playerLevel,
    required this.recommendedLevel,
    required this.cycleRank,
    required this.seedCount,
    required this.gearProfile,
    required this.winCount,
    required this.winRate,
    required this.avgRemainingHpPercent,
    required this.avgWinRemainingHpPercent,
    required this.avgDurationSeconds,
    required this.avgExpPerRun,
    required this.avgGoldPerRun,
    required this.runsPerLevel,
    required this.minPlayerHitOnMonsters,
    required this.maxPlayerHitOnBoss,
    required this.minBossHitOnPlayer,
  });

  final String dungeonId;
  final String dungeonName;
  final String scenarioLabel;
  final int playerLevel;
  final int recommendedLevel;
  final int cycleRank;
  final int seedCount;
  final TierGearProfile gearProfile;
  final int winCount;
  final double winRate;
  final double avgRemainingHpPercent;
  final double avgWinRemainingHpPercent;
  final double avgDurationSeconds;
  final double avgExpPerRun;
  final double avgGoldPerRun;
  final double? runsPerLevel;
  final int minPlayerHitOnMonsters;
  final int maxPlayerHitOnBoss;
  final int minBossHitOnPlayer;
}

/// Hasil pengecekan batas numerik stat/reward/EXP/drop pada satu rank.
class RankSafetyMetrics {
  const RankSafetyMetrics({
    required this.dungeonId,
    required this.cycleRank,
    required this.difficultyMultiplier,
    required this.bossHp,
    required this.bossAtk,
    required this.bossDef,
    required this.bossExpReward,
    required this.bossGoldReward,
    required this.levelAfterMassiveGrant,
    required this.allFiniteAndSafe,
    this.rewardMultiplier = 1.0,
    this.rareDropChanceMultiplier = 1.0,
    this.equipmentRollBonus = 0.0,
    this.dungeonClearExpReward = 0,
    this.dungeonClearGoldReward = 0,
    this.recommendedLevel = 1,
    this.maxRolledItemAtk = 0.0,
  });

  final String dungeonId;
  final int cycleRank;
  final double difficultyMultiplier;
  final double rewardMultiplier;
  final double rareDropChanceMultiplier;
  final double equipmentRollBonus;
  final int bossHp;
  final int bossAtk;
  final int bossDef;
  final int bossExpReward;
  final int bossGoldReward;
  final int dungeonClearExpReward;
  final int dungeonClearGoldReward;
  final int recommendedLevel;
  final double maxRolledItemAtk;
  final int levelAfterMassiveGrant;
  final bool allFiniteAndSafe;
}

/// Hasil kalibrasi level minimum untuk mencapai target win rate pada dungeon & rank tertentu.
class LevelCalibrationResult {
  const LevelCalibrationResult({
    required this.dungeonId,
    required this.cycleRank,
    required this.formulaRecommendedLevel,
    required this.formulaWinRate,
    required this.formulaAvgRemHpPercent,
    required this.calibratedMinLevel,
    required this.calibratedWinRate,
    required this.calibratedUnderMinus10WinRate,
    required this.calibratedOverPlus10WinRate,
    required this.calibratedOverPlus10MinPlayerHit,
    required this.searchCeilingLevel,
  });

  final String dungeonId;
  final int cycleRank;
  final int formulaRecommendedLevel;
  final double formulaWinRate;
  final double formulaAvgRemHpPercent;
  final int? calibratedMinLevel;
  final double? calibratedWinRate;
  final double? calibratedUnderMinus10WinRate;
  final double? calibratedOverPlus10WinRate;
  final int? calibratedOverPlus10MinPlayerHit;
  final int searchCeilingLevel;

  bool get formulaMeetsTarget => formulaWinRate >= 0.85;
}

/// Hasil simulasi 8-jam Mode B Auto Farming per dungeon pada level & rank uji.
class AutoFarm8HourMetrics {
  const AutoFarm8HourMetrics({
    required this.dungeonId,
    required this.dungeonName,
    this.cycleRank = 0,
    this.statusLabel = 'applied',
    required this.startLevel,
    required this.endLevel,
    required this.levelsGained,
    required this.runsAttempted,
    required this.runsCompleted,
    required this.runsFailed,
    required this.expGained,
    required this.goldGained,
    required this.addedEquipmentCount,
    required this.droppedEquipmentCount,
    required this.cappedAtMaxDuration,
    required this.isBoundedAndFinite,
  });

  final String dungeonId;
  final String dungeonName;
  final int cycleRank;
  final String statusLabel;
  final int startLevel;
  final int endLevel;
  final int levelsGained;
  final int runsAttempted;
  final int runsCompleted;
  final int runsFailed;
  final int expGained;
  final int goldGained;
  final int addedEquipmentCount;
  final int droppedEquipmentCount;
  final bool cappedAtMaxDuration;
  final bool isBoundedAndFinite;
}

/// Metrik ekonomi M10 Stage 4: gold/jam online vs Auto Farming 8 jam + likuidasi loot.
class EconomyDungeonMetrics {
  const EconomyDungeonMetrics({
    required this.dungeonId,
    required this.dungeonName,
    required this.cycleRank,
    required this.playerLevel,
    required this.onlineGoldPerHour,
    required this.offlineDirectGold8h,
    required this.offlineLootSellGold8h,
    required this.offlineDirectGoldPerHour,
    required this.offlineTotalGoldPerHour,
  });

  final String dungeonId;
  final String dungeonName;
  final int cycleRank;
  final int playerLevel;
  final double onlineGoldPerHour;
  final int offlineDirectGold8h;
  final int offlineLootSellGold8h;
  final double offlineDirectGoldPerHour;
  final double offlineTotalGoldPerHour;

  int get offlineTotalGold8h => offlineDirectGold8h + offlineLootSellGold8h;

  double hoursForPriceOnline(int price) =>
      onlineGoldPerHour > 0 ? price / onlineGoldPerHour : double.infinity;

  double hoursForPriceOfflineTotal(int price) => offlineTotalGoldPerHour > 0
      ? price / offlineTotalGoldPerHour
      : double.infinity;
}

/// Simulator headless M8 Stage 6 yang memakai engine domain resmi tanpa Flutter/Flame.
class BalanceSimulator {
  BalanceSimulator(this.config, {OfflineDungeonRunner? runner})
    : _runner = runner ?? const OfflineDungeonRunner();

  final GameConfig config;
  final OfflineDungeonRunner _runner;

  static const List<int> defaultSafetyRanks = [0, 1, 5, 10, 50, 1000];

  /// Memuat dan memvalidasi seluruh [GameConfig] langsung dari `assets/data/*.json`.
  static GameConfig loadRealConfig({String assetsDir = 'assets/data'}) {
    String read(String name) => File('$assetsDir/$name').readAsStringSync();
    const parser = GameConfigParser();
    final settings = read('game_config.json');
    final difficulty = parser.parseDifficulty(settings);
    final config = GameConfig(
      monsters: const MonsterConfigParser().parse(read('monsters.json')),
      damage: parser.parseDamage(settings),
      difficulty: difficulty,
      farming: parser.parseFarming(settings),
      revive: parser.parseRevive(settings),
      progression: parser.parseProgression(settings),
      equipment: parser.parseEquipment(settings),
      dungeonCompletion: parser.parseDungeonCompletion(settings),
      items: const ItemConfigParser().parse(read('items.json')),
      lootTables: const LootConfigParser().parse(read('loot_tables.json')),
      skills: const SkillConfigParser().parse(read('skills.json')),
      specializations: const SpecializationConfigParser().parse(
        read('specializations.json'),
      ),
      dungeons: const DungeonConfigParser().parse(
        read('dungeons.json'),
        ascensionMultiplier: difficulty.ascensionMultiplier,
      ),
      shop: const ShopConfigParser().parse(read('shop.json')),
    );
    const GameConfigValidator().validate(config);
    return config;
  }

  /// Menentukan profil gear berdasarkan tier dungeon dan rarity pada `items.json`.
  TierGearProfile defaultTierGearProfile(
    DungeonDefinition dungeon, {
    int? playerLevel,
  }) {
    final effectiveLevel = playerLevel ?? dungeon.recommendedLevel;
    final canChooseSpec = effectiveLevel >= config.specializations.unlockLevel;

    final ItemRarity ceiling;
    final String label;
    switch (dungeon.order) {
      case 1:
        ceiling = ItemRarity.common;
        label = 'T1 Common';
        break;
      case 2:
        ceiling = ItemRarity.uncommon;
        label = 'T2 Uncommon';
        break;
      case 3:
        ceiling = ItemRarity.rare;
        label = 'T3 Rare';
        break;
      case 4:
        ceiling = ItemRarity.epic;
        label = 'T4 Epic';
        break;
      default:
        ceiling = ItemRarity.legendary;
        label = 'T5 Legendary';
        break;
    }

    return buildGearProfileForRarity(
      name: label,
      maxRarity: ceiling,
      specializationId: canChooseSpec ? 'vanguard' : null,
    );
  }

  /// Menentukan profil gear berdasarkan tier dungeon dan rank siklus.
  ///
  /// - Rank 0: memakai profil tier progresi awal ([defaultTierGearProfile]).
  /// - Rank >= 1: inventory/equipment bersifat persisten lintas siklus (tidak
  ///   di-reset saat ascend), sehingga pemain endgame membawa gear [ItemRarity.legendary]
  ///   dengan bonus kualitas roll dari drop rank tinggi (`equipmentRollBonus`).
  TierGearProfile rankTierGearProfile(
    DungeonDefinition dungeon, {
    required int cycleRank,
    int? playerLevel,
    String specializationId = 'vanguard',
  }) {
    if (cycleRank <= 0) {
      if (specializationId == 'vanguard') {
        return defaultTierGearProfile(dungeon, playerLevel: playerLevel);
      }
      final base = defaultTierGearProfile(dungeon, playerLevel: playerLevel);
      final effectiveLevel = playerLevel ?? dungeon.recommendedLevel;
      final canChooseSpec =
          effectiveLevel >= config.specializations.unlockLevel;
      return buildGearProfileForRarity(
        name: base.name,
        maxRarity: base.maxRarity,
        specializationId: canChooseSpec ? specializationId : null,
      );
    }

    final safeLevel = playerLevel ?? dungeon.recommendedLevel;
    final canChooseSpec = safeLevel >= config.specializations.unlockLevel;
    final rollBonus = DifficultyService(config.difficulty)
        .profileFor(dungeon, cycleRank)
        .equipmentRollBonus;
    final bonusPct = (rollBonus * 100).round();
    return buildGearProfileForRarity(
      name: bonusPct > 0 ? 'T5 Legendary +$bonusPct%' : 'T5 Legendary',
      maxRarity: ItemRarity.legendary,
      specializationId: canChooseSpec ? specializationId : null,
    );
  }

  /// Membangun profil gear dengan memilih item terbaik per slot yang rarity-nya
  /// `<= maxRarity` dari katalog `items.json`.
  TierGearProfile buildGearProfileForRarity({
    required String name,
    required ItemRarity maxRarity,
    required String? specializationId,
  }) {
    final bySlot = <EquipmentSlot, ItemDefinition>{};
    for (final slot in EquipmentSlot.values) {
      final candidates =
          config.items.values.where((item) {
            final eq = item.equipment;
            if (eq == null || eq.slot != slot) return false;
            return item.rarity.index <= maxRarity.index;
          }).toList()..sort((a, b) {
            final rCmp = b.rarity.index.compareTo(a.rarity.index);
            if (rCmp != 0) return rCmp;
            final aPower = _itemScore(a.equipment!.baseStats);
            final bPower = _itemScore(b.equipment!.baseStats);
            final pCmp = bPower.compareTo(aPower);
            if (pCmp != 0) return pCmp;
            return a.id.compareTo(b.id);
          });
      if (candidates.isNotEmpty) {
        bySlot[slot] = candidates.first;
      }
    }

    return TierGearProfile(
      name: name,
      maxRarity: maxRarity,
      specializationId: specializationId,
      itemsBySlot: Map.unmodifiable(bySlot),
    );
  }

  static double _itemScore(EquipmentStats stats) =>
      stats.atk * 3.0 +
      stats.def * 2.5 +
      stats.hp * 0.25 +
      stats.attackSpeed * 20.0 +
      stats.critRate * 100.0 +
      stats.critDamage * 30.0 +
      stats.skillHaste * 50.0;

  /// Menghitung level skill yang wajar dimiliki karakter pada level tertentu.
  Map<String, int> skillLevelsFor({
    required int playerLevel,
    required String? specializationId,
  }) {
    return <String, int>{
      for (final skill in config.skills.values)
        if (playerLevel >= skill.unlockLevel &&
            (skill.specializationId == null ||
                skill.specializationId == specializationId))
          skill.id: (playerLevel ~/ 7).clamp(1, skill.maxLevel),
    };
  }

  /// Membangun [PlayerCharacter] headless lengkap dengan gear roll deterministik per seed.
  PlayerCharacter buildCharacter({
    required int level,
    required TierGearProfile gearProfile,
    required int seed,
    bool randomizeGearRoll = false,
    double equipmentRollBonus = 0.0,
  }) {
    final safeLevel = math.max(1, level);
    final safeRollBonus = equipmentRollBonus.isFinite && equipmentRollBonus > 0
        ? equipmentRollBonus
        : 0.0;
    final canSpec = safeLevel >= config.specializations.unlockLevel;
    final effectiveSpecId = canSpec ? gearProfile.specializationId : null;
    final loadout = EquipmentLoadout();
    final factory = EquipmentFactory(config.equipment);
    final rollRng = math.Random(seed * 97 + 13);

    var slotIdx = 0;
    for (final entry in gearProfile.itemsBySlot.entries) {
      slotIdx++;
      final def = entry.value;
      final instance = randomizeGearRoll
          ? factory.create(
              instanceId: 'sim_${seed}_${def.id}_$slotIdx',
              definition: def,
              random: rollRng,
              rollBonus: safeRollBonus,
            )
          : EquipmentInstance(
              id: 'sim_${seed}_${def.id}_$slotIdx',
              definitionId: def.id,
              slot: def.equipment!.slot,
              rarity: def.rarity,
              rolledStats: safeRollBonus > 0
                  ? def.equipment!.baseStats.scaled(1.0 + safeRollBonus)
                  : def.equipment!.baseStats,
            );
      loadout.equip(instance);
    }

    return PlayerCharacter(
      config: config.progression,
      progress: PlayerProgress(level: safeLevel),
      loadout: loadout,
      skillCatalog: config.skills,
      specializationConfig: config.specializations,
      initialSpecializationId: effectiveSpecId,
      skillLevels: skillLevelsFor(
        playerLevel: safeLevel,
        specializationId: effectiveSpecId,
      ),
    );
  }

  /// Menjalankan simulasi multi-seed untuk satu skenario dungeon tunggal (1 run per seed).
  DungeonScenarioMetrics simulateScenario({
    required String dungeonId,
    required String scenarioLabel,
    required int playerLevel,
    required TierGearProfile gearProfile,
    int cycleRank = 0,
    int seedCount = 20,
    int baseSeed = 100,
    bool randomizeGearRoll = true,
    double? equipmentRollBonus,
    Duration simulationBudget = const Duration(minutes: 45),
    int maxIterations = 200000,
  }) {
    final dungeon = config.dungeons[dungeonId];
    if (dungeon == null) {
      throw ArgumentError('Dungeon "$dungeonId" tidak ditemukan di config.');
    }

    final safeLevel = math.max(1, playerLevel);
    final safeRank = cycleRank < 0 ? 0 : cycleRank;
    final effectiveSeeds = math.max(1, seedCount);
    final difficultyService = DifficultyService(config.difficulty);
    final profile = difficultyService.profileFor(dungeon, safeRank);
    final resolvedRollBonus = equipmentRollBonus ?? profile.equipmentRollBonus;
    final resolvedRecommendedLevel = DungeonProgressionService(
      config.difficulty,
    ).recommendedLevel(dungeon, safeRank);

    final factory = EquipmentFactory(config.equipment);
    final calculator = const OfflineTimeCalculator();
    final timeWindow = calculator.calculate(
      session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
      nowMs: 1000000 + simulationBudget.inMilliseconds,
    );

    var winCount = 0;
    var totalHpPct = 0.0;
    var totalWinHpPct = 0.0;
    var totalDurationSec = 0.0;
    var totalExp = 0;
    var totalGold = 0;

    for (var i = 0; i < effectiveSeeds; i++) {
      final seed = baseSeed + i;
      final character = buildCharacter(
        level: safeLevel,
        gearProfile: gearProfile,
        seed: seed,
        randomizeGearRoll: randomizeGearRoll,
        equipmentRollBonus: resolvedRollBonus,
      );
      final inventory = Inventory(definitions: config.items);
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: factory,
      );

      final runRequest = OfflineDungeonRunRequest(
        mode: OfflineActivityMode.continueDungeon,
        character: character,
        inventory: inventory,
        config: config,
        rewardProcessor: rewardProcessor,
        dungeonId: dungeonId,
        dungeonProgress: DungeonProgressSnapshot(currentDungeonId: dungeonId),
        timeWindow: timeWindow,
        simulationSeed: seed,
        maxIterations: maxIterations,
        cycleRank: safeRank,
        activeDungeonSession: ActiveDungeonSessionSnapshot(
          runId: 'sim_${dungeonId}_${safeLevel}_$seed',
          dungeonId: dungeonId,
          currentRoomId: dungeon.startRoomId,
          currentRoomIndex: 0,
          status: DungeonSessionStatus.inProgress,
          cycleRank: safeRank,
        ),
      );
      final outcome = dungeon.isNormal
          ? _runner.runBatch(runRequest)
          : _runner.simulateManualRun(runRequest);

      final won =
          outcome.stopReason == OfflineDungeonStopReason.dungeonCompleted &&
          outcome.runsCompleted == 1;
      if (won) winCount++;

      final maxHp = math.max(
        1,
        outcome.finalPlayerMaxHp ?? character.stats.maxHp,
      );
      final remHp = math.max(0, outcome.finalPlayerHp ?? 0);
      final hpPct = (remHp * 100.0 / maxHp).clamp(0.0, 100.0);
      totalHpPct += hpPct;
      if (won) totalWinHpPct += hpPct;

      totalDurationSec +=
          outcome.ticksSimulated * OfflineDungeonRunner.tickDurationMs / 1000.0;
      totalExp += outcome.expGained;
      totalGold += outcome.goldGained;
    }

    // Evaluasi batas damage menggunakan base gear deterministik pada level uji.
    final refChar = buildCharacter(
      level: safeLevel,
      gearProfile: gearProfile,
      seed: baseSeed,
      randomizeGearRoll: false,
      equipmentRollBonus: resolvedRollBonus,
    );
    final damageCalc = DamageCalculator(formula: config.damage.formula);

    var minPlayerHit = 1 << 30;
    var maxPlayerHitBoss = 0;
    var minBossHitPlayer = 1 << 30;

    final monsterIds = <String>{
      for (final room in dungeon.rooms.values)
        for (final spawn in room.spawns) spawn.monsterId,
    };
    for (final mId in monsterIds) {
      final rawDef = config.monsters[mId]!;
      final scaledStats = difficultyService.scaleMonsterStats(
        rawDef.stats,
        profile,
      );
      final pDmg = damageCalc.physicalDamage(
        refChar.stats.atk,
        scaledStats.def,
      );
      if (pDmg < minPlayerHit) minPlayerHit = pDmg;
      if (rawDef.isBoss) {
        if (pDmg > maxPlayerHitBoss) maxPlayerHitBoss = pDmg;
        final bDmg = damageCalc.physicalDamage(
          scaledStats.atk,
          refChar.stats.def,
        );
        if (bDmg < minBossHitPlayer) minBossHitPlayer = bDmg;
      }
    }

    final avgExp = totalExp / effectiveSeeds;
    final expNeeded = config.progression.expToNext(safeLevel);
    final runsPerLevel = avgExp > 0 ? expNeeded / avgExp : null;

    return DungeonScenarioMetrics(
      dungeonId: dungeonId,
      dungeonName: dungeon.name,
      scenarioLabel: scenarioLabel,
      playerLevel: safeLevel,
      recommendedLevel: resolvedRecommendedLevel,
      cycleRank: safeRank,
      seedCount: effectiveSeeds,
      gearProfile: gearProfile,
      winCount: winCount,
      winRate: winCount / effectiveSeeds,
      avgRemainingHpPercent: totalHpPct / effectiveSeeds,
      avgWinRemainingHpPercent: winCount > 0 ? totalWinHpPct / winCount : 0.0,
      avgDurationSeconds: totalDurationSec / effectiveSeeds,
      avgExpPerRun: avgExp,
      avgGoldPerRun: totalGold / effectiveSeeds,
      runsPerLevel: runsPerLevel,
      minPlayerHitOnMonsters: minPlayerHit == (1 << 30) ? 0 : minPlayerHit,
      maxPlayerHitOnBoss: maxPlayerHitBoss,
      minBossHitOnPlayer: minBossHitPlayer == (1 << 30) ? 0 : minBossHitPlayer,
    );
  }

  /// Mencari level minimum empiris yang mencapai [targetWinRate] untuk [dungeonId]
  /// pada [cycleRank], menggunakan profil gear rank yang sesuai.
  LevelCalibrationResult calibrateRecommendedLevel({
    required String dungeonId,
    required int cycleRank,
    double targetWinRate = 0.85,
    int seedCount = 20,
    int baseSeed = 100,
    int searchCeilingLevel = 2000,
    String specializationId = 'vanguard',
  }) {
    final dungeon = config.dungeons[dungeonId];
    if (dungeon == null) {
      throw ArgumentError('Dungeon "$dungeonId" tidak ditemukan di config.');
    }

    final safeRank = cycleRank < 0 ? 0 : cycleRank;
    final formulaRec = DungeonProgressionService(config.difficulty)
        .recommendedLevel(dungeon, safeRank);

    final cache = <int, DungeonScenarioMetrics>{};
    DungeonScenarioMetrics evalAt(int level, {String? label}) {
      return cache.putIfAbsent(level, () {
        final gear = rankTierGearProfile(
          dungeon,
          cycleRank: safeRank,
          playerLevel: level,
          specializationId: specializationId,
        );
        return simulateScenario(
          dungeonId: dungeonId,
          scenarioLabel: label ?? 'Calibrate Lv $level',
          playerLevel: level,
          gearProfile: gear,
          cycleRank: safeRank,
          seedCount: seedCount,
          baseSeed: baseSeed,
        );
      });
    }

    final formulaMetrics = evalAt(formulaRec, label: 'Formula Rec');

    var lowFail = 0;
    int? highPass;

    if (formulaMetrics.winRate >= targetWinRate) {
      highPass = formulaRec;
      final lv1 = evalAt(1);
      if (lv1.winRate >= targetWinRate) {
        lowFail = 0;
        highPass = 1;
      } else {
        lowFail = 1;
      }
    } else {
      lowFail = formulaRec;
      var probe = formulaRec;
      while (probe < searchCeilingLevel) {
        final next = math.min(
          searchCeilingLevel,
          math.max(probe + 5, (probe * 1.4).ceil()),
        );
        final probeMetrics = evalAt(next);
        if (probeMetrics.winRate >= targetWinRate) {
          highPass = next;
          break;
        }
        lowFail = next;
        probe = next;
      }
    }

    if (highPass == null) {
      return LevelCalibrationResult(
        dungeonId: dungeonId,
        cycleRank: safeRank,
        formulaRecommendedLevel: formulaRec,
        formulaWinRate: formulaMetrics.winRate,
        formulaAvgRemHpPercent: formulaMetrics.avgRemainingHpPercent,
        calibratedMinLevel: null,
        calibratedWinRate: null,
        calibratedUnderMinus10WinRate: null,
        calibratedOverPlus10WinRate: null,
        calibratedOverPlus10MinPlayerHit: null,
        searchCeilingLevel: searchCeilingLevel,
      );
    }

    var lo = lowFail;
    var hi = highPass;
    while (lo + 1 < hi) {
      final mid = lo + ((hi - lo) >> 1);
      final m = evalAt(mid);
      if (m.winRate >= targetWinRate) {
        hi = mid;
      } else {
        lo = mid;
      }
    }

    final bestMetrics = evalAt(hi, label: 'Calibrated');
    final underLv = math.max(1, hi - 10);
    final underMetrics = evalAt(underLv, label: 'Calibrated -10');
    final overMetrics = evalAt(hi + 10, label: 'Calibrated +10');

    return LevelCalibrationResult(
      dungeonId: dungeonId,
      cycleRank: safeRank,
      formulaRecommendedLevel: formulaRec,
      formulaWinRate: formulaMetrics.winRate,
      formulaAvgRemHpPercent: formulaMetrics.avgRemainingHpPercent,
      calibratedMinLevel: hi,
      calibratedWinRate: bestMetrics.winRate,
      calibratedUnderMinus10WinRate: underMetrics.winRate,
      calibratedOverPlus10WinRate: overMetrics.winRate,
      calibratedOverPlus10MinPlayerHit: overMetrics.minPlayerHitOnMonsters,
      searchCeilingLevel: searchCeilingLevel,
    );
  }

  /// Memverifikasi tidak adanya overflow/NaN/Infinity di seluruh daftar rank uji.
  List<RankSafetyMetrics> checkRankSafety({
    List<int> ranks = defaultSafetyRanks,
  }) {
    final difficultyService = DifficultyService(config.difficulty);
    final progressionService = ProgressionService(config.progression);
    final dungeonProgression = DungeonProgressionService(config.difficulty);
    final equipmentFactory = EquipmentFactory(config.equipment);
    final results = <RankSafetyMetrics>[];

    final sortedDungeons = config.dungeons.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final dungeon in sortedDungeons) {
      final bossDef = _findBossForDungeon(dungeon);
      final clearReward = dungeon.completionReward ?? config.dungeonCompletion;
      for (final rank in ranks) {
        final safeRank = rank < 0 ? 0 : rank;
        final profile = difficultyService.profileFor(dungeon, safeRank);
        final scaledBossStats = difficultyService.scaleMonsterStats(
          bossDef.stats,
          profile,
        );
        final bossExp = difficultyService.scaleExp(bossDef.expReward, profile);
        final bossGold = difficultyService.scaleGold(
          bossDef.goldReward,
          profile,
        );
        final clearExp = difficultyService.scaleExp(
          clearReward.expReward,
          profile,
        );
        final clearGold = difficultyService.scaleGold(
          clearReward.goldReward,
          profile,
        );
        final recLevel = dungeonProgression.recommendedLevel(dungeon, safeRank);

        final gear = rankTierGearProfile(
          dungeon,
          cycleRank: safeRank,
          playerLevel: recLevel,
        );
        final weaponDef = gear.itemsBySlot[EquipmentSlot.weapon];
        final rolledWeapon = weaponDef == null
            ? null
            : equipmentFactory.create(
                instanceId: 'safety_${dungeon.id}_$safeRank',
                definition: weaponDef,
                random: math.Random(42 + safeRank),
                rollBonus: profile.equipmentRollBonus,
              );
        final maxRolledAtk = rolledWeapon?.rolledStats.atk ?? 0.0;

        final testProgress = PlayerProgress(level: dungeon.recommendedLevel);
        final granted = progressionService.grant(
          testProgress,
          exp: bossExp + clearExp,
          gold: bossGold + clearGold,
        );

        final safe =
            profile.multiplier.isFinite &&
            profile.multiplier > 0 &&
            profile.rewardMultiplier.isFinite &&
            profile.rewardMultiplier >= 1.0 &&
            profile.rareDropChanceMultiplier.isFinite &&
            profile.rareDropChanceMultiplier >= 1.0 &&
            profile.rareDropChanceMultiplier <=
                config.difficulty.drop.maxChanceMultiplier &&
            profile.equipmentRollBonus.isFinite &&
            profile.equipmentRollBonus >= 0.0 &&
            profile.equipmentRollBonus <= config.difficulty.drop.maxRollBonus &&
            maxRolledAtk.isFinite &&
            maxRolledAtk >= 0.0 &&
            recLevel >= dungeon.recommendedLevel &&
            recLevel <= DifficultyService.kMaxScaledValue &&
            scaledBossStats.maxHp > 0 &&
            scaledBossStats.maxHp <= DifficultyService.kMaxScaledValue &&
            scaledBossStats.atk > 0 &&
            scaledBossStats.atk <= DifficultyService.kMaxScaledValue &&
            scaledBossStats.def >= 0 &&
            scaledBossStats.def <= DifficultyService.kMaxScaledValue &&
            bossExp >= 0 &&
            bossExp <= DifficultyService.kMaxScaledValue &&
            bossGold >= 0 &&
            bossGold <= DifficultyService.kMaxScaledValue &&
            clearExp >= 0 &&
            clearExp <= DifficultyService.kMaxScaledValue &&
            clearGold >= 0 &&
            clearGold <= DifficultyService.kMaxScaledValue &&
            granted.progress.level >= testProgress.level &&
            granted.progress.level <= ProgressionConfig.kTechnicalMaxLevel &&
            granted.progress.currentExp >= 0 &&
            granted.progress.gold >= bossGold + clearGold;

        results.add(
          RankSafetyMetrics(
            dungeonId: dungeon.id,
            cycleRank: safeRank,
            difficultyMultiplier: profile.multiplier,
            rewardMultiplier: profile.rewardMultiplier,
            rareDropChanceMultiplier: profile.rareDropChanceMultiplier,
            equipmentRollBonus: profile.equipmentRollBonus,
            bossHp: scaledBossStats.maxHp,
            bossAtk: scaledBossStats.atk,
            bossDef: scaledBossStats.def,
            bossExpReward: bossExp,
            bossGoldReward: bossGold,
            dungeonClearExpReward: clearExp,
            dungeonClearGoldReward: clearGold,
            recommendedLevel: recLevel,
            maxRolledItemAtk: maxRolledAtk,
            levelAfterMassiveGrant: granted.progress.level,
            allFiniteAndSafe: safe,
          ),
        );
      }
    }
    return results;
  }

  EnemyDefinition _findBossForDungeon(DungeonDefinition dungeon) {
    for (final room in dungeon.rooms.values) {
      for (final spawn in room.spawns) {
        final def = config.monsters[spawn.monsterId];
        if (def != null && def.isBoss) return def;
      }
    }
    final firstId = dungeon.rooms.values.first.spawns.first.monsterId;
    return config.monsters[firstId]!;
  }

  /// Mensimulasikan 8-jam Mode B Auto Farming untuk seluruh dungeon normal (atau subset [dungeonIds]).
  List<AutoFarm8HourMetrics> simulate8HourAutoFarmingAll({
    int seed = 42,
    int cycleRank = 0,
    int Function(DungeonDefinition dungeon, int cycleRank)? startLevelResolver,
    bool useRankGear = true,
    Set<String>? dungeonIds,
  }) {
    const service = OfflineProgressionService();
    const startTime = 1700000000000;
    final elapsed9Hours =
        OfflineProgressionService.maxOfflineDuration.inMilliseconds + 3600000;
    final safeRank = cycleRank < 0 ? 0 : cycleRank;
    final factory = EquipmentFactory(config.equipment);
    final difficultyService = DifficultyService(config.difficulty);
    final dungeonProgression = DungeonProgressionService(config.difficulty);

    final sortedDungeons =
        config.dungeons.values.where((d) => d.isNormal).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    final targetDungeons = dungeonIds == null
        ? sortedDungeons
        : sortedDungeons.where((d) => dungeonIds.contains(d.id)).toList();

    final results = <AutoFarm8HourMetrics>[];
    for (final dungeon in targetDungeons) {
      final startLevel =
          startLevelResolver?.call(dungeon, safeRank) ??
          dungeonProgression.recommendedLevel(dungeon, safeRank);
      final gear = useRankGear
          ? rankTierGearProfile(
              dungeon,
              cycleRank: safeRank,
              playerLevel: startLevel,
            )
          : defaultTierGearProfile(dungeon, playerLevel: startLevel);
      final rollBonus = useRankGear && safeRank > 0
          ? difficultyService.profileFor(dungeon, safeRank).equipmentRollBonus
          : 0.0;
      final character = buildCharacter(
        level: startLevel,
        gearProfile: gear,
        seed: seed,
        randomizeGearRoll: false,
        equipmentRollBonus: rollBonus,
      );
      final inventory = Inventory(definitions: config.items);
      final rp = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: factory,
      );

      final dungeonProgress = DungeonProgressSnapshot(
        currentDungeonId: dungeon.id,
        currentRoomId: dungeon.startRoomId,
        currentRoomIndex: 0,
        highestClearedRoomIndex: dungeon.roomOrder.length - 1,
        clearsCount: 1,
        clearedInCycleRank: safeRank,
      );

      final progresses = <String, DungeonProgressSnapshot>{
        for (final other in sortedDungeons)
          if (other.order <= dungeon.order)
            other.id: DungeonProgressSnapshot(
              currentDungeonId: other.id,
              currentRoomId: other.startRoomId,
              currentRoomIndex: 0,
              highestClearedRoomIndex: other.roomOrder.length - 1,
              clearsCount: 1,
              clearedInCycleRank: safeRank,
            ),
      };

      final activity = const OfflineActivitySnapshot.paused().withAutoFarming(
        dungeonId: dungeon.id,
        checkpointAtMs: startTime,
        simulationSeed: seed,
      );

      final res = service.process(
        character: character,
        inventory: inventory,
        config: config,
        session: const GameSessionSnapshot(
          lastActiveAtMs: startTime,
          lastSavedAtMs: startTime,
          lastOfflineClaimAtMs: startTime,
        ),
        offlineActivity: activity,
        dungeonProgress: dungeonProgress,
        dungeonProgresses: progresses,
        cycleProgress: CycleProgress(ascensionRank: safeRank),
        rewardProcessor: rp,
        nowMs: startTime + elapsed9Hours,
        simulationSeed: seed,
        maxIterations: 400000,
      );

      final validStatus =
          res.status == OfflineProgressionStatus.applied ||
          (res.status == OfflineProgressionStatus.failed &&
              res.stopReason == OfflineDungeonStopReason.playerDefeated);
      final statusLabel = res.status == OfflineProgressionStatus.failed
          ? 'failed(${res.stopReason?.name ?? "unknown"})'
          : res.status.name;

      final bounded =
          validStatus &&
          res.cappedAtMaxDuration &&
          res.runsAttempted >= 0 &&
          res.runsCompleted >= 0 &&
          res.runsFailed >= 0 &&
          res.expGained >= 0 &&
          res.goldGained >= 0 &&
          (res.runsCompleted == 0 ||
              (res.expGained > 0 && res.goldGained > 0)) &&
          res.expGained <= DifficultyService.kMaxScaledValue &&
          res.goldGained <= DifficultyService.kMaxScaledValue &&
          res.levelsGained >= 0 &&
          character.level <= ProgressionConfig.kTechnicalMaxLevel;

      results.add(
        AutoFarm8HourMetrics(
          dungeonId: dungeon.id,
          dungeonName: dungeon.name,
          cycleRank: safeRank,
          statusLabel: statusLabel,
          startLevel: startLevel,
          endLevel: character.level,
          levelsGained: res.levelsGained,
          runsAttempted: res.runsAttempted,
          runsCompleted: res.runsCompleted,
          runsFailed: res.runsFailed,
          expGained: res.expGained,
          goldGained: res.goldGained,
          addedEquipmentCount: res.addedEquipment.length,
          droppedEquipmentCount: res.droppedEquipment.length,
          cappedAtMaxDuration: res.cappedAtMaxDuration,
          isBoundedAndFinite: bounded,
        ),
      );
    }

    return results;
  }

  /// Mensimulasikan metrik ekonomi (gold/jam online & 8-jam Mode B Auto Farming
  /// termasuk hasil jual loot material + equipment) untuk seluruh dungeon normal
  /// pada [cycleRank].
  List<EconomyDungeonMetrics> simulateEconomyForRank({
    int cycleRank = 0,
    int onlineSeedCount = 15,
    int offlineSeed = 42,
  }) {
    const service = OfflineProgressionService();
    const startTime = 1700000000000;
    final elapsed9Hours =
        OfflineProgressionService.maxOfflineDuration.inMilliseconds + 3600000;
    final safeRank = cycleRank < 0 ? 0 : cycleRank;
    final factory = EquipmentFactory(config.equipment);
    final difficultyService = DifficultyService(config.difficulty);
    final dungeonProgression = DungeonProgressionService(config.difficulty);
    final shopService = ShopService(
      catalog: config.shop,
      items: config.items,
      equipmentFactory: factory,
    );

    final sortedDungeons =
        config.dungeons.values.where((d) => d.isNormal).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    final results = <EconomyDungeonMetrics>[];
    for (final dungeon in sortedDungeons) {
      final level = dungeonProgression.recommendedLevel(dungeon, safeRank);
      final gear = rankTierGearProfile(
        dungeon,
        cycleRank: safeRank,
        playerLevel: level,
      );
      final online = simulateScenario(
        dungeonId: dungeon.id,
        scenarioLabel: 'Econ-R$safeRank',
        playerLevel: level,
        gearProfile: gear,
        cycleRank: safeRank,
        seedCount: onlineSeedCount,
      );
      final onlineGoldPerHour = online.avgDurationSeconds > 0
          ? (online.avgGoldPerRun / online.avgDurationSeconds) * 3600.0
          : 0.0;

      final rollBonus = safeRank > 0
          ? difficultyService.profileFor(dungeon, safeRank).equipmentRollBonus
          : 0.0;
      final character = buildCharacter(
        level: level,
        gearProfile: gear,
        seed: offlineSeed,
        randomizeGearRoll: false,
        equipmentRollBonus: rollBonus,
      );
      final inventory = Inventory(definitions: config.items);
      final rp = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: factory,
      );
      final progresses = <String, DungeonProgressSnapshot>{
        for (final other in sortedDungeons)
          if (other.order <= dungeon.order)
            other.id: DungeonProgressSnapshot(
              currentDungeonId: other.id,
              currentRoomId: other.startRoomId,
              currentRoomIndex: 0,
              highestClearedRoomIndex: other.roomOrder.length - 1,
              clearsCount: 1,
              clearedInCycleRank: safeRank,
            ),
      };
      final activity = const OfflineActivitySnapshot.paused().withAutoFarming(
        dungeonId: dungeon.id,
        checkpointAtMs: startTime,
        simulationSeed: offlineSeed,
      );
      final res = service.process(
        character: character,
        inventory: inventory,
        config: config,
        session: const GameSessionSnapshot(
          lastActiveAtMs: startTime,
          lastSavedAtMs: startTime,
          lastOfflineClaimAtMs: startTime,
        ),
        offlineActivity: activity,
        dungeonProgress: progresses[dungeon.id]!,
        dungeonProgresses: progresses,
        cycleProgress: CycleProgress(ascensionRank: safeRank),
        rewardProcessor: rp,
        nowMs: startTime + elapsed9Hours,
        simulationSeed: offlineSeed,
        maxIterations: 400000,
      );

      final goldBeforeSell = character.gold;
      for (final stack in inventory.snapshot()) {
        if (config.shop.sell.sellableCategories.contains(
              stack.definition.category,
            ) &&
            stack.quantity > 0) {
          shopService.sellMaterialBulk(
            itemId: stack.definition.id,
            quantity: stack.quantity,
            character: character,
            inventory: inventory,
          );
        }
      }
      for (final eq in inventory.equipmentSnapshot()) {
        shopService.sellEquipment(
          instanceId: eq.id,
          character: character,
          inventory: inventory,
        );
      }
      final lootSellGold = character.gold - goldBeforeSell;
      final offlineDirectPerHour = res.goldGained / 8.0;
      final offlineTotalPerHour = (res.goldGained + lootSellGold) / 8.0;

      results.add(
        EconomyDungeonMetrics(
          dungeonId: dungeon.id,
          dungeonName: dungeon.name,
          cycleRank: safeRank,
          playerLevel: level,
          onlineGoldPerHour: onlineGoldPerHour,
          offlineDirectGold8h: res.goldGained,
          offlineLootSellGold8h: lootSellGold,
          offlineDirectGoldPerHour: offlineDirectPerHour,
          offlineTotalGoldPerHour: offlineTotalPerHour,
        ),
      );
    }
    return results;
  }
}
