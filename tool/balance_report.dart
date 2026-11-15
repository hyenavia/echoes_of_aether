import 'dart:io';
import 'dart:math' as math;

import 'package:echoes_of_aether/domain/services/dungeon_progression_service.dart';
import 'package:echoes_of_aether/domain/services/period_service.dart';

import 'src/balance_simulator.dart';

void main(List<String> args) {
  final config = BalanceSimulator.loadRealConfig();
  final sim = BalanceSimulator(config);
  const seedCount = 30;

  if (args.contains('--sweep')) {
    _printDiagnosticSweep(sim, seedCount);
    return;
  }
  if (args.contains('--economy')) {
    _printEconomyReport(sim);
    return;
  }
  if (args.contains('--boss')) {
    _printBossReport(sim, seedCount: 20);
    return;
  }
  if (args.contains('--event')) {
    _printEventReport(sim, seedCount: 15);
    return;
  }

  final allDungeons = config.dungeons.values.toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  stdout.writeln(
    '=== Echoes of Aether — Balance Simulator Report (M8 + M9 Stage 5) ===',
  );
  stdout.writeln(
    'Seeds per scenario: $seedCount | Specialization: vanguard (jika Lv >= ${config.specializations.unlockLevel})',
  );
  stdout.writeln(
    'Profil Gear Tier Rank 0 (asumsi simulator dari assets/data/items.json):',
  );
  for (final d in allDungeons) {
    final g = sim.defaultTierGearProfile(d, playerLevel: d.recommendedLevel);
    stdout.writeln(
      '- ${d.id} (${d.kind.name}, Lv rec ${d.recommendedLevel}, scale ${d.difficultyScale}): ${g.name} = [${g.describeGear()}]',
    );
  }
  stdout.writeln('');
  stdout.writeln(
    '| Dungeon | Scenario | Lv (Rec) | Gear Tier | WinRate | AvgRemHP | AvgDur(s) | AvgEXP | AvgGold | Runs/Lv | MinHit -> Boss | BossHit |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|---|---|---|---|');

  for (final d in allDungeons) {
    final rec = d.recommendedLevel;
    final lowLevel = math.max(1, rec - 10);
    final highLevel = rec + 10;

    final scenarios = <({String label, int level})>[
      (label: 'Under (-10)', level: lowLevel),
      (label: 'Recommended', level: rec),
      (label: 'Over (+10)', level: highLevel),
    ];

    for (final s in scenarios) {
      final gear = sim.defaultTierGearProfile(d, playerLevel: s.level);
      final metrics = sim.simulateScenario(
        dungeonId: d.id,
        scenarioLabel: s.label,
        playerLevel: s.level,
        gearProfile: gear,
        cycleRank: 0,
        seedCount: seedCount,
      );
      final winPct = '${(metrics.winRate * 100).toStringAsFixed(1)}%';
      final hpPct = '${metrics.avgRemainingHpPercent.toStringAsFixed(1)}%';
      final dur = metrics.avgDurationSeconds.toStringAsFixed(1);
      final exp = metrics.avgExpPerRun.toStringAsFixed(1);
      final gold = metrics.avgGoldPerRun.toStringAsFixed(1);
      final rpl = metrics.runsPerLevel?.toStringAsFixed(2) ?? '-';

      stdout.writeln(
        '| ${d.id} | ${s.label} | ${s.level} ($rec) | ${gear.name} | '
        '$winPct | $hpPct | $dur | $exp | $gold | $rpl | '
        '${metrics.minPlayerHitOnMonsters} / ${metrics.maxPlayerHitOnBoss} | '
        '${metrics.minBossHitOnPlayer} |',
      );
    }
  }

  stdout.writeln('');
  stdout.writeln(
    '=== Ascension Sanctum Rank 0 — All Specializations (Rec Lv 49) ===',
  );
  stdout.writeln(
    '| Specialization | Lv (Rec) | Gear | WinRate | AvgRemHP | AvgDur(s) | MinHit -> Boss | BossHit |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|');
  final ascDungeon = config.dungeons['ascension_sanctum']!;
  for (final spec in ['vanguard', 'arcanist', 'ranger']) {
    final gear = sim.rankTierGearProfile(
      ascDungeon,
      cycleRank: 0,
      playerLevel: ascDungeon.recommendedLevel,
      specializationId: spec,
    );
    final m = sim.simulateScenario(
      dungeonId: ascDungeon.id,
      scenarioLabel: 'Rec/$spec',
      playerLevel: ascDungeon.recommendedLevel,
      gearProfile: gear,
      cycleRank: 0,
      seedCount: seedCount,
    );
    stdout.writeln(
      '| $spec | ${ascDungeon.recommendedLevel} (${ascDungeon.recommendedLevel}) | ${gear.name} | '
      '${(m.winRate * 100).toStringAsFixed(1)}% | ${m.avgRemainingHpPercent.toStringAsFixed(1)}% | '
      '${m.avgDurationSeconds.toStringAsFixed(1)} | '
      '${m.minPlayerHitOnMonsters} / ${m.maxPlayerHitOnBoss} | ${m.minBossHitOnPlayer} |',
    );
  }
  stdout.writeln('');
  stdout.writeln(
    '=== Ascension Sanctum Rank 0 — Calibrated Min Lv per Specialization ===',
  );
  stdout.writeln(
    '| Specialization | FormulaRec | FormulaWin | CalibratedMinLv | CalWin | Cal(-10) | Cal(+10) |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|');
  for (final spec in ['vanguard', 'arcanist', 'ranger']) {
    final cal = sim.calibrateRecommendedLevel(
      dungeonId: ascDungeon.id,
      cycleRank: 0,
      seedCount: 20,
      searchCeilingLevel: 300,
      specializationId: spec,
    );
    stdout.writeln(
      '| $spec | ${cal.formulaRecommendedLevel} | ${(cal.formulaWinRate * 100).toStringAsFixed(1)}% | '
      '${cal.calibratedMinLevel ?? ">300"} | '
      '${cal.calibratedWinRate == null ? "-" : "${(cal.calibratedWinRate! * 100).toStringAsFixed(1)}%"} | '
      '${cal.calibratedUnderMinus10WinRate == null ? "-" : "${(cal.calibratedUnderMinus10WinRate! * 100).toStringAsFixed(1)}%"} | '
      '${cal.calibratedOverPlus10WinRate == null ? "-" : "${(cal.calibratedOverPlus10WinRate! * 100).toStringAsFixed(1)}%"} |',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    '=== M9 Stage 5: Rank Calibration & Drop Bonus Sweep (Rank 0, 1, 5, 10, 50) ===',
  );
  stdout.writeln(
    '| Dungeon | Rank | Mult | RollBonus | FormulaRec | FormulaWin | CalibratedMinLv | CalWin | Cal(-10) | Cal(+10) | Cal(+10)MinHit |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|---|---|---|');
  for (final d in allDungeons) {
    for (final rank in [0, 1, 5, 10, 50]) {
      final cal = sim.calibrateRecommendedLevel(
        dungeonId: d.id,
        cycleRank: rank,
        seedCount: 20,
        searchCeilingLevel: 3000,
      );
      final profile = sim.rankTierGearProfile(
        d,
        cycleRank: rank,
        playerLevel: cal.formulaRecommendedLevel,
      );
      final mult =
          d.difficultyScale * (1.0 + config.difficulty.cyclePerRank * rank);
      final calLv = cal.calibratedMinLevel?.toString() ?? '>3000';
      final calWin = cal.calibratedWinRate == null
          ? '-'
          : '${(cal.calibratedWinRate! * 100).toStringAsFixed(1)}%';
      final calLow = cal.calibratedUnderMinus10WinRate == null
          ? '-'
          : '${(cal.calibratedUnderMinus10WinRate! * 100).toStringAsFixed(1)}%';
      final calHigh = cal.calibratedOverPlus10WinRate == null
          ? '-'
          : '${(cal.calibratedOverPlus10WinRate! * 100).toStringAsFixed(1)}%';
      final calHit = cal.calibratedOverPlus10MinPlayerHit?.toString() ?? '-';
      stdout.writeln(
        '| ${d.id} | $rank | ${mult.toStringAsFixed(2)} | ${profile.name} | '
        '${cal.formulaRecommendedLevel} | ${(cal.formulaWinRate * 100).toStringAsFixed(1)}% | '
        '$calLv | $calWin | $calLow | $calHigh | $calHit |',
      );
    }
  }

  stdout.writeln('');
  stdout.writeln(
    '=== M9 Stage 5: Rank 1000 Extreme Formula vs High-Level Check ===',
  );
  stdout.writeln(
    '| Dungeon | Scenario | Lv | Gear | WinRate | AvgDur(s) | MinHit | BossHit |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|');
  for (final dId in [
    'forgotten_forest',
    'aether_sanctum',
    'ascension_sanctum',
  ]) {
    final d = config.dungeons[dId]!;
    for (final level in [
      150,
      1000,
      dId == 'forgotten_forest'
          ? 6000
          : (dId == 'aether_sanctum' ? 28000 : 55000),
    ]) {
      final gear = sim.rankTierGearProfile(
        d,
        cycleRank: 1000,
        playerLevel: level,
      );
      final m = sim.simulateScenario(
        dungeonId: d.id,
        scenarioLabel: 'Rank1000/Lv$level',
        playerLevel: level,
        gearProfile: gear,
        cycleRank: 1000,
        seedCount: 5,
      );
      stdout.writeln(
        '| ${d.id} | Rank 1000 | $level | ${gear.name} | '
        '${(m.winRate * 100).toStringAsFixed(1)}% | ${m.avgDurationSeconds.toStringAsFixed(1)} | '
        '${m.minPlayerHitOnMonsters} | ${m.minBossHitOnPlayer} |',
      );
    }
  }

  stdout.writeln('');
  stdout.writeln('=== High-Rank Safety Sweep (Rank 0, 1, 5, 10, 50, 1000) ===');
  stdout.writeln(
    '| Dungeon | Rank | Mult | RewardMul | DropMul | RollBonus | RecLv | Boss HP | Boss ATK | Boss DEF | Boss EXP | Clear EXP | WpnATK | Lv After Grant | Safe |',
  );
  stdout.writeln(
    '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|',
  );
  for (final r in sim.checkRankSafety()) {
    stdout.writeln(
      '| ${r.dungeonId} | ${r.cycleRank} | ${r.difficultyMultiplier.toStringAsFixed(2)} | '
      '${r.rewardMultiplier.toStringAsFixed(2)} | ${r.rareDropChanceMultiplier.toStringAsFixed(2)} | '
      '+${(r.equipmentRollBonus * 100).toStringAsFixed(0)}% | ${r.recommendedLevel} | '
      '${r.bossHp} | ${r.bossAtk} | ${r.bossDef} | ${r.bossExpReward} | ${r.dungeonClearExpReward} | '
      '${r.maxRolledItemAtk.toStringAsFixed(1)} | ${r.levelAfterMassiveGrant} | '
      '${r.allFiniteAndSafe ? "PASS" : "FAIL"} |',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    '=== 8-Jam Mode B Auto Farming per Dungeon (Rank 0, Rec Level) ===',
  );
  stdout.writeln(
    '| Dungeon | Rank | Lv Awal -> Akhir | Runs (Comp/Att/Fail) | EXP | Gold | Drop Equip | Capped8h | Bounded |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|---|');
  for (final f in sim.simulate8HourAutoFarmingAll(cycleRank: 0)) {
    stdout.writeln(
      '| ${f.dungeonId} | ${f.cycleRank} | ${f.startLevel} -> ${f.endLevel} (+${f.levelsGained}) | '
      '${f.runsCompleted}/${f.runsAttempted}/${f.runsFailed} | '
      '${f.expGained} | ${f.goldGained} | ${f.addedEquipmentCount} | '
      '${f.cappedAtMaxDuration} | ${f.isBoundedAndFinite ? "PASS" : "FAIL"} |',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    '=== 8-Jam Mode B Auto Farming Multi-Rank Boundedness (Rank 1, 5, 10, 50, 1000) ===',
  );
  stdout.writeln(
    '| Dungeon | Rank | Mode | Status | Lv Awal -> Akhir | Runs (Comp/Att/Fail) | EXP | Gold | Drop Equip | Capped8h | Bounded |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|---|---|---|');
  const multiRankAutoFarmIds = {'forgotten_forest', 'aether_sanctum'};
  for (final rank in [1, 5, 10, 50, 1000]) {
    final formulaRuns = sim.simulate8HourAutoFarmingAll(
      cycleRank: rank,
      dungeonIds: multiRankAutoFarmIds,
    );
    for (final f in formulaRuns) {
      stdout.writeln(
        '| ${f.dungeonId} | ${f.cycleRank} | FormulaRec | ${f.statusLabel} | ${f.startLevel} -> ${f.endLevel} (+${f.levelsGained}) | '
        '${f.runsCompleted}/${f.runsAttempted}/${f.runsFailed} | '
        '${f.expGained} | ${f.goldGained} | ${f.addedEquipmentCount} | '
        '${f.cappedAtMaxDuration} | ${f.isBoundedAndFinite ? "PASS" : "FAIL"} |',
      );
    }
    if (rank == 50 || rank == 1000) {
      final stressLevel = rank == 50 ? 2500 : 50000;
      final stressRuns = sim.simulate8HourAutoFarmingAll(
        cycleRank: rank,
        startLevelResolver: (_, _) => stressLevel,
        dungeonIds: multiRankAutoFarmIds,
      );
      for (final f in stressRuns) {
        stdout.writeln(
          '| ${f.dungeonId} | ${f.cycleRank} | StressLv$stressLevel | ${f.statusLabel} | ${f.startLevel} -> ${f.endLevel} (+${f.levelsGained}) | '
          '${f.runsCompleted}/${f.runsAttempted}/${f.runsFailed} | '
          '${f.expGained} | ${f.goldGained} | ${f.addedEquipmentCount} | '
          '${f.cappedAtMaxDuration} | ${f.isBoundedAndFinite ? "PASS" : "FAIL"} |',
        );
      }
    }
  }
}

void _printDiagnosticSweep(BalanceSimulator sim, int seedCount) {
  stdout.writeln(
    '=== D1 Forgotten Forest Level Sweep (Lv 1..7, T1 Common) ===',
  );
  for (final lv in [1, 2, 3, 4, 5, 6, 7]) {
    final d1 = sim.config.dungeons['forgotten_forest']!;
    final gear = sim.defaultTierGearProfile(d1, playerLevel: lv);
    final m = sim.simulateScenario(
      dungeonId: 'forgotten_forest',
      scenarioLabel: 'Lv $lv',
      playerLevel: lv,
      gearProfile: gear,
      seedCount: seedCount,
    );
    stdout.writeln(
      'Lv $lv (${gear.specializationId ?? "none"}): winRate=${(m.winRate * 100).toStringAsFixed(1)}% '
      'avgRemHP=${m.avgRemainingHpPercent.toStringAsFixed(1)}% dur=${m.avgDurationSeconds.toStringAsFixed(1)}s',
    );
  }

  stdout.writeln('');
  stdout.writeln('=== All Dungeons x All Specializations at Rec Lv ===');
  final dungeons = sim.config.dungeons.values.where((d) => d.isNormal).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  for (final d in dungeons) {
    final testLv = d.recommendedLevel;
    final defaultGear = sim.defaultTierGearProfile(d, playerLevel: testLv);
    for (final spec in ['vanguard', 'arcanist', 'ranger']) {
      final gear = sim.buildGearProfileForRarity(
        name: '${defaultGear.name}/$spec',
        maxRarity: defaultGear.maxRarity,
        specializationId: spec,
      );
      final m = sim.simulateScenario(
        dungeonId: d.id,
        scenarioLabel: 'Rec/$spec',
        playerLevel: testLv,
        gearProfile: gear,
        seedCount: seedCount,
      );
      stdout.writeln(
        '${d.id} Lv$testLv [$spec / ${defaultGear.maxRarity.name}]: '
        'winRate=${(m.winRate * 100).toStringAsFixed(1)}% avgRemHP=${m.avgRemainingHpPercent.toStringAsFixed(1)}%',
      );
    }
  }
}

void _printEconomyReport(BalanceSimulator sim) {
  final rarePrice = sim.config.shop.byId('shop_guardian_amulet')!.price;
  final epicPrice = sim.config.shop.byId('shop_aether_blade')!.price;
  final legendaryPrice = sim.config.shop.byId('shop_heart_of_aether')!.price;
  const ranks = [0, 1, 5, 10];

  stdout.writeln(
    '=== Echoes of Aether — Economy Simulator Report (M10 Stage 4) ===',
  );
  stdout.writeln(
    'Baseline Shop Prices: Rare=$rarePrice, Epic=$epicPrice, Legendary=$legendaryPrice Gold',
  );
  stdout.writeln('');
  stdout.writeln(
    '| Rank | Dungeon | Lv | Online G/hr | 8h Direct G | 8h Loot Sell G | 8h Total G/hr | Hrs Rare (On/Off) | Hrs Epic (On/Off) | Hrs Leg (On/Off) |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|---|---|');

  String fmtHrs(double h) => h.isFinite ? h.toStringAsFixed(2) : 'inf';

  for (final rank in ranks) {
    final rows = sim.simulateEconomyForRank(cycleRank: rank);
    for (final r in rows) {
      stdout.writeln(
        '| $rank | ${r.dungeonId} | ${r.playerLevel} | '
        '${r.onlineGoldPerHour.toStringAsFixed(1)} | '
        '${r.offlineDirectGold8h} | ${r.offlineLootSellGold8h} | '
        '${r.offlineTotalGoldPerHour.toStringAsFixed(1)} | '
        '${fmtHrs(r.hoursForPriceOnline(rarePrice))} / ${fmtHrs(r.hoursForPriceOfflineTotal(rarePrice))} | '
        '${fmtHrs(r.hoursForPriceOnline(epicPrice))} / ${fmtHrs(r.hoursForPriceOfflineTotal(epicPrice))} | '
        '${fmtHrs(r.hoursForPriceOnline(legendaryPrice))} / ${fmtHrs(r.hoursForPriceOfflineTotal(legendaryPrice))} |',
      );
    }
  }
}

void _printBossReport(BalanceSimulator sim, {int seedCount = 20}) {
  const ranks = [0, 1, 5, 10, 50];
  final normals = sim.config.dungeons.values.where((d) => d.isNormal).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  final dungeonProg = DungeonProgressionService(sim.config.difficulty);

  stdout.writeln(
    '=== Echoes of Aether — Boss Events Balance Simulator (M12 Stage 6) ===',
  );
  stdout.writeln('Seeds per scenario: $seedCount | Specialization: vanguard');
  stdout.writeln('');
  stdout.writeln(
    '| Period | Boss | RefDungeon | Rank | RecLv | Win(-10) | Win(Rec) | Win(+10) | AvgWinDur(s) | MinHit->Boss | BossHit |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|---|---|---|');

  for (final period in [Period.daily, Period.weekly]) {
    final pool = period == Period.daily
        ? sim.config.bossEvents!.daily.pool
        : sim.config.bossEvents!.weekly.pool;
    for (final boss in pool) {
      for (final rank in ranks) {
        for (final d in normals) {
          final rec = dungeonProg.recommendedLevel(d, rank);
          final low = math.max(1, rec - 10);
          final high = rec + 10;

          final mLow = sim.simulateBossScenario(
            period: period,
            boss: boss,
            referenceDungeonId: d.id,
            scenarioLabel: 'Under(-10)',
            playerLevel: low,
            gearProfile: sim.rankTierGearProfile(
              d,
              cycleRank: rank,
              playerLevel: low,
            ),
            cycleRank: rank,
            seedCount: seedCount,
          );
          final mRec = sim.simulateBossScenario(
            period: period,
            boss: boss,
            referenceDungeonId: d.id,
            scenarioLabel: 'Rec',
            playerLevel: rec,
            gearProfile: sim.rankTierGearProfile(
              d,
              cycleRank: rank,
              playerLevel: rec,
            ),
            cycleRank: rank,
            seedCount: seedCount,
          );
          final mHigh = sim.simulateBossScenario(
            period: period,
            boss: boss,
            referenceDungeonId: d.id,
            scenarioLabel: 'Over(+10)',
            playerLevel: high,
            gearProfile: sim.rankTierGearProfile(
              d,
              cycleRank: rank,
              playerLevel: high,
            ),
            cycleRank: rank,
            seedCount: seedCount,
          );

          stdout.writeln(
            '| ${period.name} | ${boss.id} | ${d.id} | $rank | $rec | '
            '${(mLow.winRate * 100).toStringAsFixed(1)}% | '
            '${(mRec.winRate * 100).toStringAsFixed(1)}% | '
            '${(mHigh.winRate * 100).toStringAsFixed(1)}% | '
            '${mRec.avgDurationSeconds.toStringAsFixed(1)} | '
            '${mRec.maxPlayerHitOnBoss} | ${mRec.minBossHitOnPlayer} |',
          );
        }
      }
    }
  }

  stdout.writeln('');
  stdout.writeln(
    '=== Boss Quest Rewards vs 1h Online Farming (Dungeon 1..5, Rank 0,1,5,10,50) ===',
  );
  stdout.writeln(
    '| Rank | RefDungeon | RecLv | Farm1h Gold | Farm1h EXP | Daily Gold | Daily EXP | Weekly Gold | Weekly EXP | Weekly Shards | Exceeds1hFarm |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|---|---|---|');
  final comparisons = sim.simulateBossQuestComparison(ranks: ranks);
  for (final c in comparisons) {
    final flag = (c.dailyExceedsFarmingHour || c.weeklyExceedsFarmingHour)
        ? 'YES (Daily=${c.dailyExceedsFarmingHour}, Weekly=${c.weeklyExceedsFarmingHour})'
        : 'no';
    stdout.writeln(
      '| ${c.cycleRank} | ${c.referenceDungeonId} | ${c.recommendedLevel} | '
      '${c.farmingGoldPerHour.toStringAsFixed(1)} | ${c.farmingExpPerHour.toStringAsFixed(1)} | '
      '${c.dailyQuestGold} | ${c.dailyQuestExp} | '
      '${c.weeklyQuestGold} | ${c.weeklyQuestExp} | '
      '${c.weeklyAetherShardIncome} | $flag |',
    );
  }
}

void _printEventReport(BalanceSimulator sim, {int seedCount = 15}) {
  final econ = sim.simulateEventShopEconomy();
  stdout.writeln(
    '=== Echoes of Aether — Event Shop Shard Economy & Pct Caps (M13 Stage 4) ===',
  );
  stdout.writeln(
    'Reward: Daily=${econ.dailyShard} Shard, Weekly=${econ.weeklyShard} Shard | '
    'Cycle=${econ.cycleWeeks} weeks | Prices: Epic=${econ.epicPrice}, Leg=${econ.legendaryPrice} | '
    'Full Epic=${econ.fullEpicSetCost}, Full Leg=${econ.fullLegendarySetCost}, Pool Total=${econ.totalPoolCost}',
  );
  stdout.writeln(
    'Max Legal Pct Sums vs Caps: '
    'HP=${(econ.pctCapCheck.maxLegalHpPct * 100).toStringAsFixed(1)}% / ${(econ.pctCapCheck.capHpPct * 100).toStringAsFixed(0)}%, '
    'ATK=${(econ.pctCapCheck.maxLegalAtkPct * 100).toStringAsFixed(1)}% / ${(econ.pctCapCheck.capAtkPct * 100).toStringAsFixed(0)}%, '
    'DEF=${(econ.pctCapCheck.maxLegalDefPct * 100).toStringAsFixed(1)}% / ${(econ.pctCapCheck.capDefPct * 100).toStringAsFixed(0)}% '
    '(BelowAllCaps=${econ.pctCapCheck.isBelowAllCaps})',
  );
  stdout.writeln('');
  stdout.writeln(
    '| Cadence | Shard/wk | 1 Epic (wk) | 1 Leg (wk) | 4 Epic (wk) | 4 Leg (wk) | Full Pool (wk) | Flag |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|');
  for (final c in econ.cadences) {
    final flags = <String>[
      if (c.buysAllInSingleCycle) 'TOO_FAST',
      if (c.impossibleForLegendary) 'IMPOSSIBLE',
    ];
    stdout.writeln(
      '| ${c.cadenceName} | ${c.weeklyShardIncome} | '
      '${c.weeksForOneEpic.toStringAsFixed(2)} | ${c.weeksForOneLegendary.toStringAsFixed(2)} | '
      '${c.weeksForFullEpicSet.toStringAsFixed(2)} | ${c.weeksForFullLegendarySet.toStringAsFixed(2)} | '
      '${c.weeksForFullPool.toStringAsFixed(2)} | ${flags.isEmpty ? "healthy" : flags.join(",")} |',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    '=== Event Set Impact (4-Slot Full Epic & Legendary vs Tier Baseline) ===',
  );
  stdout.writeln(
    '| Target | Kind | Rank | Lv | Win(Base/Epic/Leg) | Dur(Base/Epic/Leg s) | Epic DMG/EHP Δ% | Leg DMG/EHP Δ% | Safe |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|---|');
  final rows = sim.simulateEventSetImpact(
    ranks: const [0, 1, 5, 10, 50],
    seedCount: seedCount,
  );
  for (final r in rows) {
    String fmtPct(double p) => '${p >= 0 ? "+" : ""}${p.toStringAsFixed(1)}%';
    stdout.writeln(
      '| ${r.targetId} | ${r.targetKind} | ${r.cycleRank} | ${r.playerLevel} | '
      '${(r.baseWinRate * 100).toStringAsFixed(0)}%/'
      '${(r.epicWinRate * 100).toStringAsFixed(0)}%/'
      '${(r.legendaryWinRate * 100).toStringAsFixed(0)}% | '
      '${r.baseDurationSec.toStringAsFixed(1)}/'
      '${r.epicDurationSec.toStringAsFixed(1)}/'
      '${r.legendaryDurationSec.toStringAsFixed(1)} | '
      '${fmtPct(r.epicDamageDeltaPct)} / ${fmtPct(r.epicToughnessDeltaPct)} | '
      '${fmtPct(r.legendaryDamageDeltaPct)} / ${fmtPct(r.legendaryToughnessDeltaPct)} | '
      '${r.allFiniteAndSafe} |',
    );
  }
}
