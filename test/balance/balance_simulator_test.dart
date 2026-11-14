import 'dart:math' as math;

import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_progression_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/balance_simulator.dart';

void main() {
  late BalanceSimulator sim;

  setUpAll(() {
    final config = BalanceSimulator.loadRealConfig();
    sim = BalanceSimulator(config);
  });

  group('M8 Stage 6 — Balance Simulator Verification', () {
    const seedCount = 20;

    test('seluruh dungeon normal memiliki recommended_level final sesuai hasil simulasi', () {
      final dungeons = sim.config.dungeons;
      expect(dungeons['forgotten_forest']!.recommendedLevel, 5);
      expect(dungeons['crystal_cavern']!.recommendedLevel, 8);
      expect(dungeons['ancient_crypt']!.recommendedLevel, 16);
      expect(dungeons['ashen_wasteland']!.recommendedLevel, 25);
      expect(dungeons['aether_sanctum']!.recommendedLevel, 35);
    });

    test('Rank 0 memenuhi target win rate pada level rekomendasi, -10, dan +10 untuk 5 dungeon', () {
      final dungeons =
          sim.config.dungeons.values.where((d) => d.isNormal).toList()
            ..sort((a, b) => a.order.compareTo(b.order));
      expect(dungeons, hasLength(5));

      for (final d in dungeons) {
        final rec = d.recommendedLevel;

        // 1. Level rekomendasi + gear tier wajar -> win rate >= 85%
        final recMetrics = sim.simulateScenario(
          dungeonId: d.id,
          scenarioLabel: 'Recommended',
          playerLevel: rec,
          gearProfile: sim.defaultTierGearProfile(d, playerLevel: rec),
          cycleRank: 0,
          seedCount: seedCount,
        );
        expect(
          recMetrics.winRate,
          greaterThanOrEqualTo(0.85),
          reason: '${d.id} pada Lv $rec harus memiliki win rate >= 85%.',
        );
        expect(recMetrics.avgDurationSeconds, greaterThan(0));
        expect(recMetrics.avgExpPerRun, greaterThan(0));
        expect(recMetrics.avgGoldPerRun, greaterThan(0));
        expect(recMetrics.runsPerLevel, isNotNull);
        expect(recMetrics.runsPerLevel!, greaterThan(0));

        // 2. 10 level di bawah rekomendasi (di-clamp ke min Lv 1) -> win rate < 50%
        final lowLv = math.max(1, rec - 10);
        final lowMetrics = sim.simulateScenario(
          dungeonId: d.id,
          scenarioLabel: 'Under (-10)',
          playerLevel: lowLv,
          gearProfile: sim.defaultTierGearProfile(d, playerLevel: lowLv),
          cycleRank: 0,
          seedCount: seedCount,
        );
        expect(
          lowMetrics.winRate,
          lessThan(0.50),
          reason: '${d.id} pada Lv $lowLv harus memiliki win rate < 50%.',
        );

        // 3. 10 level di atas rekomendasi -> win rate >= 99% & damage tidak mentok 1
        final highLv = rec + 10;
        final highMetrics = sim.simulateScenario(
          dungeonId: d.id,
          scenarioLabel: 'Over (+10)',
          playerLevel: highLv,
          gearProfile: sim.defaultTierGearProfile(d, playerLevel: highLv),
          cycleRank: 0,
          seedCount: seedCount,
        );
        expect(
          highMetrics.winRate,
          greaterThanOrEqualTo(0.99),
          reason: '${d.id} pada Lv $highLv harus memiliki win rate >= 99%.',
        );
        expect(
          highMetrics.minPlayerHitOnMonsters,
          greaterThan(1),
          reason: '${d.id} player damage tidak boleh mentok 1.',
        );
        expect(
          highMetrics.maxPlayerHitOnBoss,
          greaterThan(1),
          reason: '${d.id} damage ke boss tidak boleh mentok 1.',
        );
        expect(
          highMetrics.minBossHitOnPlayer,
          greaterThan(1),
          reason: '${d.id} damage boss (rumus ratio) tidak boleh mentok 1.',
        );
      }
    });

    test('seluruh specialization (vanguard, arcanist, ranger) kompetitif di D1 dan D5', () {
      for (final dungeonId in const ['forgotten_forest', 'aether_sanctum']) {
        final d = sim.config.dungeons[dungeonId]!;
        final baseGear = sim.defaultTierGearProfile(
          d,
          playerLevel: d.recommendedLevel,
        );
        for (final spec in const ['vanguard', 'arcanist', 'ranger']) {
          final gear = sim.buildGearProfileForRarity(
            name: '${baseGear.name}/$spec',
            maxRarity: baseGear.maxRarity,
            specializationId: spec,
          );
          final metrics = sim.simulateScenario(
            dungeonId: d.id,
            scenarioLabel: 'Spec-$spec',
            playerLevel: d.recommendedLevel,
            gearProfile: gear,
            seedCount: 10,
          );
          expect(
            metrics.winRate,
            greaterThanOrEqualTo(0.85),
            reason:
                '$dungeonId dengan $spec harus >= 85% pada Lv ${d.recommendedLevel}.',
          );
        }
      }
    });

    test('Rank 0, 1, 5, 10, 50, 1000 aman dari overflow, NaN, dan Infinity', () {
      final results = sim.checkRankSafety();
      expect(
        results,
        hasLength(
          sim.config.dungeons.length *
              BalanceSimulator.defaultSafetyRanks.length,
        ),
      );
      for (final row in results) {
        expect(
          row.allFiniteAndSafe,
          isTrue,
          reason:
              '${row.dungeonId} rank ${row.cycleRank} tidak boleh overflow/NaN/Infinity.',
        );
        expect(
          row.bossHp,
          lessThanOrEqualTo(DifficultyService.kMaxScaledValue),
        );
        expect(
          row.bossAtk,
          lessThanOrEqualTo(DifficultyService.kMaxScaledValue),
        );
      }
    });

    test('8-jam Mode B Auto Farming seluruh dungeon (1..5) terbatas, tanpa lonjakan, dan tanpa death loop pada recLevel', () {
      final results = sim.simulate8HourAutoFarmingAll();
      expect(results, hasLength(5));

      var prevExp = 0;
      for (final f in results) {
        expect(
          f.isBoundedAndFinite,
          isTrue,
          reason:
              '${f.dungeonId} harus finite & bounded dalam 8-jam Auto Farming.',
        );
        expect(f.cappedAtMaxDuration, isTrue);
        expect(f.runsCompleted, greaterThan(0));
        expect(f.runsFailed, 0);
        expect(f.levelsGained, greaterThan(0));
        expect(
          f.expGained,
          greaterThan(prevExp),
          reason:
              'EXP 8-jam ${f.dungeonId} harus meningkat wajar dibanding tier sebelumnya.',
        );
        prevExp = f.expGained;
      }
    });
  });

  group('M9 Stage 5 — Balance Rank & Ascension Verification', () {
    test('ascension_sanctum Rank 0 seimbang untuk ketiga specialization pada rec level 49', () {
      final asc = sim.config.dungeons['ascension_sanctum']!;
      final rec = asc.recommendedLevel;
      expect(rec, 49);

      // Setelah Option 1A (ascension_multiplier: 1.35), seluruh specialization >= 85% di rec level 49.
      final rangerAtRec = sim.simulateScenario(
        dungeonId: asc.id,
        scenarioLabel: 'Asc Rec/ranger',
        playerLevel: rec,
        gearProfile: sim.rankTierGearProfile(
          asc,
          cycleRank: 0,
          playerLevel: rec,
          specializationId: 'ranger',
        ),
        cycleRank: 0,
        seedCount: 20,
      );
      final vanguardAtRec = sim.simulateScenario(
        dungeonId: asc.id,
        scenarioLabel: 'Asc Rec/vanguard',
        playerLevel: rec,
        gearProfile: sim.rankTierGearProfile(
          asc,
          cycleRank: 0,
          playerLevel: rec,
          specializationId: 'vanguard',
        ),
        cycleRank: 0,
        seedCount: 20,
      );
      final arcanistAtRec = sim.simulateScenario(
        dungeonId: asc.id,
        scenarioLabel: 'Asc Rec/arcanist',
        playerLevel: rec,
        gearProfile: sim.rankTierGearProfile(
          asc,
          cycleRank: 0,
          playerLevel: rec,
          specializationId: 'arcanist',
        ),
        cycleRank: 0,
        seedCount: 20,
      );
      expect(rangerAtRec.winRate, greaterThanOrEqualTo(0.85));
      expect(vanguardAtRec.winRate, greaterThanOrEqualTo(0.85));
      expect(arcanistAtRec.winRate, greaterThanOrEqualTo(0.85));

      // Calibrated minimum level per specialization berada <= rec level 49 serta memenuhi band >=85% / <50% / >=99%.
      for (final entry in <String, int>{
        'ranger': 28,
        'arcanist': 37,
        'vanguard': 47,
      }.entries) {
        final calLv = entry.value;
        final spec = entry.key;
        expect(calLv, lessThanOrEqualTo(rec));
        final calRec = sim.simulateScenario(
          dungeonId: asc.id,
          scenarioLabel: 'Asc Cal/$spec',
          playerLevel: calLv,
          gearProfile: sim.rankTierGearProfile(
            asc,
            cycleRank: 0,
            playerLevel: calLv,
            specializationId: spec,
          ),
          cycleRank: 0,
          seedCount: 20,
        );
        final calLow = sim.simulateScenario(
          dungeonId: asc.id,
          scenarioLabel: 'Asc Cal-10/$spec',
          playerLevel: calLv - 10,
          gearProfile: sim.rankTierGearProfile(
            asc,
            cycleRank: 0,
            playerLevel: calLv - 10,
            specializationId: spec,
          ),
          cycleRank: 0,
          seedCount: 20,
        );
        final calHigh = sim.simulateScenario(
          dungeonId: asc.id,
          scenarioLabel: 'Asc Cal+10/$spec',
          playerLevel: calLv + 10,
          gearProfile: sim.rankTierGearProfile(
            asc,
            cycleRank: 0,
            playerLevel: calLv + 10,
            specializationId: spec,
          ),
          cycleRank: 0,
          seedCount: 20,
        );

        expect(calRec.winRate, greaterThanOrEqualTo(0.85));
        expect(calLow.winRate, lessThan(0.50));
        expect(calHigh.winRate, greaterThanOrEqualTo(0.99));
        expect(calHigh.minPlayerHitOnMonsters, greaterThan(1));
      }
    });

    test('rank 0, 1, 5, 10, 50, 1000 seluruh dungeon bebas overflow/NaN/Infinity termasuk clear reward dan drop roll bonus', () {
      const testRanks = [0, 1, 5, 10, 50, 1000];
      final safety = sim.checkRankSafety(ranks: testRanks);
      expect(safety, hasLength(36)); // 6 dungeon x 6 rank

      for (final s in safety) {
        expect(
          s.allFiniteAndSafe,
          isTrue,
          reason:
              '${s.dungeonId} rank ${s.cycleRank} harus aman dari overflow/NaN/Infinity.',
        );
        expect(s.rewardMultiplier.isFinite, isTrue);
        expect(s.rareDropChanceMultiplier, inInclusiveRange(1.0, 3.0));
        expect(s.equipmentRollBonus, inInclusiveRange(0.0, 0.50));
        expect(s.recommendedLevel, greaterThanOrEqualTo(1));
        expect(s.dungeonClearExpReward, greaterThan(0));
        expect(s.dungeonClearGoldReward, greaterThan(0));
        expect(s.maxRolledItemAtk.isFinite, isTrue);
        expect(s.maxRolledItemAtk, greaterThan(0.0));
      }

      // Pastikan profil gear rank >= 1 menerima equipmentRollBonus (+2% per rank, cap +50%)
      final d5 = sim.config.dungeons['aether_sanctum']!;
      final heroRank0 = sim.buildCharacter(
        level: 50,
        gearProfile: sim.rankTierGearProfile(d5, cycleRank: 0, playerLevel: 50),
        seed: 42,
        equipmentRollBonus: 0.0,
      );
      final heroRank50 = sim.buildCharacter(
        level: 50,
        gearProfile: sim.rankTierGearProfile(
          d5,
          cycleRank: 50,
          playerLevel: 50,
        ),
        seed: 42,
        equipmentRollBonus: 0.50,
      );
      expect(heroRank50.stats.atk, greaterThan(heroRank0.stats.atk));
      expect(heroRank50.stats.maxHp, greaterThan(heroRank0.stats.maxHp));
    });

    test('simulasi tempur multi-rank 0, 1, 5, 10, 50, 1000 menjaga integritas stat/EXP dan formula recommendedLevel terkalibrasi', () {
      final dungeonProg = DungeonProgressionService(sim.config.difficulty);

      // Setelah Option 2A (cycle_stat_exponents), formula recommendedLevel tercapai >= 85% di seluruh rank target.
      for (final id in [
        'forgotten_forest',
        'aether_sanctum',
        'ascension_sanctum',
      ]) {
        final dungeon = sim.config.dungeons[id]!;
        for (final rank in [0, 1, 5, 10, 50]) {
          final formulaRec = dungeonProg.recommendedLevel(dungeon, rank);
          final gear = sim.rankTierGearProfile(
            dungeon,
            cycleRank: rank,
            playerLevel: formulaRec,
          );
          final m = sim.simulateScenario(
            dungeonId: id,
            scenarioLabel: 'FormulaRec R$rank',
            playerLevel: formulaRec,
            gearProfile: gear,
            cycleRank: rank,
            seedCount: 20,
          );
          expect(
            m.winRate,
            greaterThanOrEqualTo(0.85),
            reason:
                '$id rank $rank pada formulaRec Lv $formulaRec harus >= 85%.',
          );
          expect(m.recommendedLevel, formulaRec);
          expect(m.avgExpPerRun.isFinite && m.avgExpPerRun > 0, isTrue);
          expect(m.avgGoldPerRun.isFinite && m.avgGoldPerRun > 0, isTrue);
          expect(m.minPlayerHitOnMonsters, greaterThan(1));
        }

        for (final rank in [0, 5, 50]) {
          final cal = sim.calibrateRecommendedLevel(
            dungeonId: id,
            cycleRank: rank,
            seedCount: 10,
          );
          expect(
            cal.calibratedMinLevel,
            lessThanOrEqualTo(cal.formulaRecommendedLevel),
            reason:
                '$id rank $rank: calibratedMinLevel (${cal.calibratedMinLevel}) '
                'harus <= formulaRecommendedLevel (${cal.formulaRecommendedLevel}).',
          );
        }
      }

      // Rank 1000 kelayakan simulasi & keamanan numerik di level tinggi
      for (final entry in <String, int>{
        'forgotten_forest': 6000,
        'aether_sanctum': 28000,
        'ascension_sanctum': 55000,
      }.entries) {
        final dungeon = sim.config.dungeons[entry.key]!;
        final m = sim.simulateScenario(
          dungeonId: entry.key,
          scenarioLabel: 'R1000 Stress Lv${entry.value}',
          playerLevel: entry.value,
          gearProfile: sim.rankTierGearProfile(
            dungeon,
            cycleRank: 1000,
            playerLevel: entry.value,
          ),
          cycleRank: 1000,
          seedCount: 5,
        );
        expect(m.winRate, greaterThanOrEqualTo(0.85));
        expect(m.avgExpPerRun.isFinite && m.avgExpPerRun > 0, isTrue);
        expect(m.avgGoldPerRun.isFinite && m.avgGoldPerRun > 0, isTrue);
        expect(m.minPlayerHitOnMonsters, greaterThan(1));
      }
    });

    test('8-jam Mode B Auto Farming pada rank 0, 1, 5, 10, 50, 1000 tetap bounded, finite, dan tidak overflow', () {
      // Rank 0, 50, 1000 mencakup seluruh 5 dungeon normal; Rank 1, 5, 10 mencakup
      // dungeon terendah (forgotten_forest) dan tertinggi (aether_sanctum).
      for (final rank in [0, 50, 1000]) {
        final runs = sim.simulate8HourAutoFarmingAll(cycleRank: rank);
        expect(runs, hasLength(5));
        for (final f in runs) {
          expect(
            f.isBoundedAndFinite,
            isTrue,
            reason:
                '${f.dungeonId} rank $rank formulaRec harus bounded & stop aman.',
          );
          expect(f.cappedAtMaxDuration, isTrue);
          expect(
            f.expGained,
            lessThanOrEqualTo(DifficultyService.kMaxScaledValue),
          );
          expect(
            f.goldGained,
            lessThanOrEqualTo(DifficultyService.kMaxScaledValue),
          );
          expect(
            f.endLevel,
            lessThanOrEqualTo(ProgressionConfig.kTechnicalMaxLevel),
          );
        }
      }

      for (final rank in [1, 5, 10]) {
        final runs = sim.simulate8HourAutoFarmingAll(
          cycleRank: rank,
          dungeonIds: const {'forgotten_forest', 'aether_sanctum'},
        );
        expect(runs, hasLength(2));
        for (final f in runs) {
          expect(
            f.isBoundedAndFinite,
            isTrue,
            reason:
                '${f.dungeonId} rank $rank formulaRec harus bounded & stop aman.',
          );
          expect(f.cappedAtMaxDuration, isTrue);
          expect(
            f.expGained,
            lessThanOrEqualTo(DifficultyService.kMaxScaledValue),
          );
          expect(
            f.goldGained,
            lessThanOrEqualTo(DifficultyService.kMaxScaledValue),
          );
          expect(
            f.endLevel,
            lessThanOrEqualTo(ProgressionConfig.kTechnicalMaxLevel),
          );
        }
      }

      // Stress test: pemain cukup kuat menyelesaikan ratusan run dalam 8 jam di Rank 50 & Rank 1000
      for (final entry in <int, int>{50: 2500, 1000: 50000}.entries) {
        final runs = sim.simulate8HourAutoFarmingAll(
          cycleRank: entry.key,
          startLevelResolver: (_, _) => entry.value,
        );
        expect(runs, hasLength(5));
        for (final f in runs) {
          expect(f.isBoundedAndFinite, isTrue);
          expect(f.cappedAtMaxDuration, isTrue);
          expect(f.runsCompleted, greaterThan(0));
          expect(f.runsFailed, 0);
          expect(f.expGained, greaterThan(0));
          expect(f.goldGained, greaterThan(0));
          expect(
            f.expGained,
            lessThanOrEqualTo(DifficultyService.kMaxScaledValue),
          );
          expect(
            f.goldGained,
            lessThanOrEqualTo(DifficultyService.kMaxScaledValue),
          );
        }
      }
    });
  });
}
