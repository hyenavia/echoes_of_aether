import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/event_shop_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_progression_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';

import 'src/balance_simulator.dart';

const List<int> _kSampleRanks = [0, 1, 2, 5, 10, 20, 50];
const List<String> _kSpecializations = ['vanguard', 'arcanist', 'ranger'];
const double _kCurveEnvelopeMargin = 1.05;
const int _kMaxBlobBytes = 900000;
const int _kSchemaVersion = 8;
const int _kCodecVersion = 1;
const int _kAbsMaxEquipmentCount = 2000;
const int _kAbsMaxLifetimeClears = 1000000000;
const int _kAbsMaxDailyQuests = 100000;
const int _kAbsMaxWeeklyQuests = 20000;
const int _kAbsMaxEventPurchases = 50000;
const int _kAbsMaxGold = 1000000000000000;
const int _kAbsMaxRank = 10000;
const int _kGoldBase = 100000;

class _RankSample {
  const _RankSample({
    required this.rank,
    required this.maxGoldPerSec,
    required this.maxExpPerSec,
    required this.minRunSeconds,
    required this.minCycleSeconds,
    required this.goldSource,
    required this.expSource,
    required this.minRunDungeon,
  });

  final int rank;
  final double maxGoldPerSec;
  final double maxExpPerSec;
  final double minRunSeconds;
  final double minCycleSeconds;
  final String goldSource;
  final String expSource;
  final String minRunDungeon;
}

class _CurveFit {
  const _CurveFit({
    required this.a,
    required this.aUnscaled,
    required this.b,
    required this.c,
    required this.rmsLogError,
    required this.maxRelFitError,
  });

  final double a;
  final double aUnscaled;
  final double b;
  final double c;
  final double rmsLogError;
  final double maxRelFitError;

  double eval(int rank) => a * math.pow(1.0 + b * rank, c).toDouble();
  double evalUnscaled(int rank) =>
      aUnscaled * math.pow(1.0 + b * rank, c).toDouble();
}

void main(List<String> args) {
  var safetyFactor = 5.0;
  var checkOnly = false;
  var quiet = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--check') {
      checkOnly = true;
    } else if (arg == '--quiet') {
      quiet = true;
    } else if (arg == '--safety-factor') {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for --safety-factor');
        exitCode = 64;
        return;
      }
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || !parsed.isFinite || parsed < 1.0) {
        stderr.writeln('Invalid --safety-factor: must be a number >= 1.0');
        exitCode = 64;
        return;
      }
      safetyFactor = parsed;
    } else if (arg.startsWith('--safety-factor=')) {
      final parsed = double.tryParse(arg.substring('--safety-factor='.length));
      if (parsed == null || !parsed.isFinite || parsed < 1.0) {
        stderr.writeln('Invalid --safety-factor: must be a number >= 1.0');
        exitCode = 64;
        return;
      }
      safetyFactor = parsed;
    } else {
      stderr.writeln('Unknown argument: $arg');
      exitCode = 64;
      return;
    }
  }

  final templateFile = File('firebase/firestore.rules.template');
  if (!templateFile.existsSync()) {
    stderr.writeln('Missing template: ${templateFile.path}');
    exitCode = 2;
    return;
  }

  final config = BalanceSimulator.loadRealConfig();
  final sim = BalanceSimulator(config);
  final samples = _measureAllRanks(sim);

  final goldFit = _fitPowerCurve(
    samples.map((s) => MapEntry(s.rank, s.maxGoldPerSec)).toList(),
  );
  final expFit = _fitPowerCurve(
    samples.map((s) => MapEntry(s.rank, s.maxExpPerSec)).toList(),
  );

  // Verify strict dominance at all sampled ranks AND conservative extrapolation.
  for (final s in samples) {
    final gCeil = goldFit.eval(s.rank);
    final eCeil = expFit.eval(s.rank);
    if (s.maxGoldPerSec >= gCeil) {
      throw StateError(
        'Gold ceiling failed at rank ${s.rank}: ${s.maxGoldPerSec} >= $gCeil',
      );
    }
    if (s.maxExpPerSec >= eCeil) {
      throw StateError(
        'Exp ceiling failed at rank ${s.rank}: ${s.maxExpPerSec} >= $eCeil',
      );
    }
  }

  final rawMinRunSec = samples
      .map((s) => s.minRunSeconds)
      .reduce((a, b) => math.min(a, b));
  final rawMinCycleSec = samples
      .map((s) => s.minCycleSeconds)
      .reduce((a, b) => math.min(a, b));
  final minRunSeconds = math.max(1, (rawMinRunSec / safetyFactor).floor());
  final minCycleSeconds = math.max(1, (rawMinCycleSec / safetyFactor).floor());

  final graceSeconds =
      OfflineTimeCalculator.defaultMaxOfflineDuration.inSeconds;
  final dailyShard =
      config.bossEvents?.daily.reward.currency['aether_shard'] ?? 10;
  final weeklyShard =
      config.bossEvents?.weekly.reward.currency['aether_shard'] ?? 50;
  final spireMaxShards = (config.bossSpire?.floors ?? const []).fold<int>(
    0,
    (sum, floor) =>
        sum + (floor.firstClearReward.currency['aether_shard'] ?? 0),
  );
  final absMaxShards = config.currencies['aether_shard']?.maxAmount ?? 1000000;
  final absMaxLevel =
      config.progression.maxLevel ?? ProgressionConfig.kTechnicalMaxLevel;
  final expBase = config.progression.expCurve.base.round();
  final expExponent = config.progression.expCurve.exponent ?? 1.8;

  final generatedLimits = <String, Object?>{
    'generatedBy': 'tool/export_cloud_limits.dart',
    'safetyFactor': safetyFactor,
    'graceSeconds': graceSeconds,
    'dailyShard': dailyShard,
    'weeklyShard': weeklyShard,
    'spireMaxShards': spireMaxShards,
    'maxBlobBytes': _kMaxBlobBytes,
    'minSchemaVersion': _kSchemaVersion,
    'absMaxSchemaVersion': 100,
    'minCodecVersion': _kCodecVersion,
    'absMaxCodecVersion': 100,
    'absMaxLevel': absMaxLevel,
    'absMaxGold': _kAbsMaxGold,
    'absMaxShards': absMaxShards,
    'absMaxRank': _kAbsMaxRank,
    'absMaxLifetimeClears': _kAbsMaxLifetimeClears,
    'absMaxDailyQuests': _kAbsMaxDailyQuests,
    'absMaxWeeklyQuests': _kAbsMaxWeeklyQuests,
    'absMaxEventPurchases': _kAbsMaxEventPurchases,
    'absMaxEquipmentCount': _kAbsMaxEquipmentCount,
    'minRunSeconds': minRunSeconds,
    'minCycleSeconds': minCycleSeconds,
    'rawMinRunSeconds': _round6(rawMinRunSec),
    'rawMinCycleSeconds': _round6(rawMinCycleSec),
    'goldBase': _kGoldBase,
    'expBase': expBase,
    'expExponent': _round6(expExponent),
    'goldPerSecCurve': {
      'formula': 'A * pow(1 + B * rank, C)',
      'a': _round6(goldFit.a),
      'aUnscaled': _round6(goldFit.aUnscaled),
      'b': _round6(goldFit.b),
      'c': _round6(goldFit.c),
      'rmsLogError': _round6(goldFit.rmsLogError),
      'maxRelFitError': _round6(goldFit.maxRelFitError),
    },
    'expPerSecCurve': {
      'formula': 'A * pow(1 + B * rank, C)',
      'a': _round6(expFit.a),
      'aUnscaled': _round6(expFit.aUnscaled),
      'b': _round6(expFit.b),
      'c': _round6(expFit.c),
      'rmsLogError': _round6(expFit.rmsLogError),
      'maxRelFitError': _round6(expFit.maxRelFitError),
    },
    'sampleDiagnostics': [
      for (final s in samples)
        {
          'rank': s.rank,
          'simMaxGoldPerSec': _round6(s.maxGoldPerSec),
          'curveGoldPerSec': _round6(goldFit.eval(s.rank)),
          'goldMarginAtSafety1': _round6(
            goldFit.eval(s.rank) / s.maxGoldPerSec,
          ),
          'goldMarginAtSafety2': _round6(
            (goldFit.eval(s.rank) * 2.0) / s.maxGoldPerSec,
          ),
          'goldMarginAtConfiguredSafety': _round6(
            (goldFit.eval(s.rank) * safetyFactor) / s.maxGoldPerSec,
          ),
          'goldFitErrorPct': _round6(
            ((goldFit.evalUnscaled(s.rank) - s.maxGoldPerSec) /
                    s.maxGoldPerSec) *
                100.0,
          ),
          'goldSource': s.goldSource,
          'simMaxExpPerSec': _round6(s.maxExpPerSec),
          'curveExpPerSec': _round6(expFit.eval(s.rank)),
          'expMarginAtSafety1': _round6(expFit.eval(s.rank) / s.maxExpPerSec),
          'expMarginAtSafety2': _round6(
            (expFit.eval(s.rank) * 2.0) / s.maxExpPerSec,
          ),
          'expMarginAtConfiguredSafety': _round6(
            (expFit.eval(s.rank) * safetyFactor) / s.maxExpPerSec,
          ),
          'expFitErrorPct': _round6(
            ((expFit.evalUnscaled(s.rank) - s.maxExpPerSec) / s.maxExpPerSec) *
                100.0,
          ),
          'expSource': s.expSource,
          'minRunSeconds': _round6(s.minRunSeconds),
          'minRunDungeon': s.minRunDungeon,
          'minCycleSeconds': _round6(s.minCycleSeconds),
        },
    ],
  };

  final renderedRules = _renderRules(
    template: templateFile.readAsStringSync(),
    goldFit: goldFit,
    expFit: expFit,
    safetyFactor: safetyFactor,
    graceSeconds: graceSeconds,
    dailyShard: dailyShard,
    weeklyShard: weeklyShard,
    spireMaxShards: spireMaxShards,
    absMaxShards: absMaxShards,
    absMaxLevel: absMaxLevel,
    minRunSeconds: minRunSeconds,
    minCycleSeconds: minCycleSeconds,
    expBase: expBase,
    expExponent: expExponent,
  );

  final limitsJson =
      '${const JsonEncoder.withIndent('  ').convert(generatedLimits)}\n';

  final testVectors = _buildTestVectors(
    samples: samples,
    goldFit: goldFit,
    expFit: expFit,
    safetyFactor: safetyFactor,
    graceSeconds: graceSeconds,
    dailyShard: dailyShard,
    weeklyShard: weeklyShard,
    spireMaxShards: spireMaxShards,
    absMaxShards: absMaxShards,
    absMaxLevel: absMaxLevel,
    minRunSeconds: minRunSeconds,
    minCycleSeconds: minCycleSeconds,
    expBase: expBase,
    expExponent: expExponent,
  );
  final testVectorsJson =
      '${const JsonEncoder.withIndent('  ').convert(testVectors)}\n';

  final dartConstants = _renderGeneratedDartConstants(
    safetyFactor: safetyFactor,
    graceSeconds: graceSeconds,
    dailyShard: dailyShard,
    weeklyShard: weeklyShard,
    spireMaxShards: spireMaxShards,
    absMaxShards: absMaxShards,
    absMaxLevel: absMaxLevel,
    minRunSeconds: minRunSeconds,
    minCycleSeconds: minCycleSeconds,
    expBase: expBase,
    expExponent: expExponent,
    goldFit: goldFit,
    expFit: expFit,
  );

  final targets = <String, String>{
    'firebase/firestore.rules': renderedRules,
    'firebase/limits.json': limitsJson,
    'firebase/test_vectors.json': testVectorsJson,
    'lib/domain/entities/generated_cloud_limits.dart': dartConstants,
  };

  if (checkOnly) {
    final stale = <String>[];
    for (final entry in targets.entries) {
      final f = File(entry.key);
      if (!f.existsSync() ||
          _normalizeLineEndings(f.readAsStringSync()) !=
              _normalizeLineEndings(entry.value)) {
        stale.add(entry.key);
      }
    }
    if (stale.isNotEmpty) {
      stderr.writeln(
        'Generated cloud limit artifacts are out of date: ${stale.join(', ')}',
      );
      stderr.writeln('Run `dart run tool/export_cloud_limits.dart` to update.');
      exitCode = 1;
      return;
    }
    if (!quiet) {
      stdout.writeln(
        'cloud_limits check OK (safetyFactor=${_fmtNum(safetyFactor)}, ${testVectors.length} vectors).',
      );
    }
    return;
  }

  for (final entry in targets.entries) {
    final file = File(entry.key);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
  }

  if (!quiet) {
    _printSummary(
      samples: samples,
      goldFit: goldFit,
      expFit: expFit,
      safetyFactor: safetyFactor,
      rawMinRunSec: rawMinRunSec,
      rawMinCycleSec: rawMinCycleSec,
      minRunSeconds: minRunSeconds,
      minCycleSeconds: minCycleSeconds,
      vectorCount: testVectors.length,
    );
  }
}

List<_RankSample> _measureAllRanks(BalanceSimulator sim) {
  final config = sim.config;
  final dungeonProg = DungeonProgressionService(config.difficulty);
  final difficultyService = DifficultyService(config.difficulty);
  final allDungeons =
      config.dungeons.values.where((d) => d.isNormal || d.isAscension).toList()
        ..sort((a, b) {
          if (a.isAscension != b.isAscension) {
            return a.isAscension ? 1 : -1;
          }
          return a.order.compareTo(b.order);
        });
  final normals = allDungeons.where((d) => d.isNormal).toList();

  final results = <_RankSample>[];
  for (final rank in _kSampleRanks) {
    var maxGoldPerSec = 0.0;
    var maxExpPerSec = 0.0;
    var minRunSec = double.infinity;
    var goldSource = '';
    var expSource = '';
    var minRunDungeon = '';

    final minPerDungeon = <String, double>{};

    for (final dungeon in allDungeons) {
      final recLevel = dungeonProg.recommendedLevel(dungeon, rank);
      final rollBonus = difficultyService
          .profileFor(dungeon, rank)
          .equipmentRollBonus;
      final candidateConfigs =
          <({String label, int level, TierGearProfile gear, bool randomize})>[
            (
              label: 'rec_vanguard',
              level: recLevel,
              gear: sim.rankTierGearProfile(
                dungeon,
                cycleRank: rank,
                playerLevel: recLevel,
                specializationId: 'vanguard',
              ),
              randomize: true,
            ),
            for (final spec in _kSpecializations)
              (
                label: 'over10_eventLeg_$spec',
                level: recLevel + 10,
                gear: sim.eventSetGearProfile(
                  EventItemTier.legendary,
                  specializationId: spec,
                ),
                randomize: false,
              ),
          ];

      for (final c in candidateConfigs) {
        final metrics = sim.simulateScenario(
          dungeonId: dungeon.id,
          scenarioLabel: '${c.label}_R$rank',
          playerLevel: c.level,
          gearProfile: c.gear,
          cycleRank: rank,
          seedCount: 2,
          baseSeed: 100,
          randomizeGearRoll: c.randomize,
          equipmentRollBonus: rollBonus,
        );
        if (metrics.winRate <= 0 || metrics.avgDurationSeconds <= 0) {
          continue;
        }
        final dur = metrics.avgDurationSeconds;
        final existingMin = minPerDungeon[dungeon.id];
        if (existingMin == null || dur < existingMin) {
          minPerDungeon[dungeon.id] = dur;
        }
        if (dur < minRunSec) {
          minRunSec = dur;
          minRunDungeon = '${dungeon.id}(${c.label})';
        }
        final onlineGoldPerSec = metrics.avgGoldPerRun / dur;
        final onlineExpPerSec = metrics.avgExpPerRun / dur;
        if (onlineGoldPerSec > maxGoldPerSec) {
          maxGoldPerSec = onlineGoldPerSec;
          goldSource = 'online:${dungeon.id}(${c.label})';
        }
        if (onlineExpPerSec > maxExpPerSec) {
          maxExpPerSec = onlineExpPerSec;
          expSource = 'online:${dungeon.id}(${c.label})';
        }
      }
    }

    // 8-hour offline auto-farming + loot liquidation on highest-tier normal dungeon.
    final offlineTargets = normals.isEmpty ? normals : [normals.last];
    for (final dungeon in offlineTargets) {
      final recLevel = dungeonProg.recommendedLevel(dungeon, rank);
      final gearProfiles = <(String, int, TierGearProfile)>[
        (
          'rec_vanguard',
          recLevel,
          sim.rankTierGearProfile(
            dungeon,
            cycleRank: rank,
            playerLevel: recLevel,
          ),
        ),
        (
          'over10_eventLeg_ranger',
          recLevel + 10,
          sim.eventSetGearProfile(
            EventItemTier.legendary,
            specializationId: 'ranger',
          ),
        ),
      ];

      for (final (label, level, gear) in gearProfiles) {
        final offlineRates = _measureOfflineRates(
          sim: sim,
          dungeon: dungeon,
          rank: rank,
          playerLevel: level,
          gear: gear,
        );
        if (offlineRates.totalGoldPerSec > maxGoldPerSec) {
          maxGoldPerSec = offlineRates.totalGoldPerSec;
          goldSource = 'offline8h_inclLoot:${dungeon.id}($label)';
        }
        if (offlineRates.expPerSec > maxExpPerSec) {
          maxExpPerSec = offlineRates.expPerSec;
          expSource = 'offline8h:${dungeon.id}($label)';
        }
      }
    }

    var minCycleSec = 0.0;
    for (final d in allDungeons) {
      minCycleSec += minPerDungeon[d.id] ?? 0.0;
    }

    results.add(
      _RankSample(
        rank: rank,
        maxGoldPerSec: maxGoldPerSec,
        maxExpPerSec: maxExpPerSec,
        minRunSeconds: minRunSec,
        minCycleSeconds: minCycleSec,
        goldSource: goldSource,
        expSource: expSource,
        minRunDungeon: minRunDungeon,
      ),
    );
  }
  return results;
}

({double directGoldPerSec, double totalGoldPerSec, double expPerSec})
_measureOfflineRates({
  required BalanceSimulator sim,
  required DungeonDefinition dungeon,
  required int rank,
  required int playerLevel,
  required TierGearProfile gear,
}) {
  const service = OfflineProgressionService();
  const startTime = 1700000000000;
  final elapsed =
      OfflineProgressionService.maxOfflineDuration.inMilliseconds + 3600000;
  final factory = EquipmentFactory(sim.config.equipment);
  final rollBonus = DifficultyService(sim.config.difficulty)
      .profileFor(dungeon, rank)
      .equipmentRollBonus;
  final shopService = ShopService(
    catalog: sim.config.shop,
    items: sim.config.items,
    equipmentFactory: factory,
  );
  final normals = sim.config.dungeons.values.where((d) => d.isNormal).toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  final character = sim.buildCharacter(
    level: playerLevel,
    gearProfile: gear,
    seed: 42,
    randomizeGearRoll: false,
    equipmentRollBonus: rollBonus,
  );
  final inventory = Inventory(definitions: sim.config.items);
  final rp = RewardProcessor(
    character: character,
    inventory: inventory,
    items: sim.config.items,
    lootTables: sim.config.lootTables,
    equipmentFactory: factory,
  );
  final progresses = <String, DungeonProgressSnapshot>{
    for (final other in normals)
      if (other.order <= dungeon.order)
        other.id: DungeonProgressSnapshot(
          currentDungeonId: other.id,
          currentRoomId: other.startRoomId,
          currentRoomIndex: 0,
          highestClearedRoomIndex: other.roomOrder.length - 1,
          clearsCount: 1,
          clearedInCycleRank: rank,
        ),
  };
  final activity = const OfflineActivitySnapshot.paused().withAutoFarming(
    dungeonId: dungeon.id,
    checkpointAtMs: startTime,
    simulationSeed: 42,
  );
  final res = service.process(
    character: character,
    inventory: inventory,
    config: sim.config,
    session: const GameSessionSnapshot(
      lastActiveAtMs: startTime,
      lastSavedAtMs: startTime,
      lastOfflineClaimAtMs: startTime,
    ),
    offlineActivity: activity,
    dungeonProgress: progresses[dungeon.id]!,
    dungeonProgresses: progresses,
    cycleProgress: CycleProgress(ascensionRank: rank),
    rewardProcessor: rp,
    nowMs: startTime + elapsed,
    simulationSeed: 42,
    maxIterations: 400000,
  );

  final goldBeforeSell = character.gold;
  for (final stack in inventory.snapshot()) {
    if (sim.config.shop.sell.sellableCategories.contains(
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
  const maxOfflineSeconds = 28800.0;
  return (
    directGoldPerSec: res.goldGained / maxOfflineSeconds,
    totalGoldPerSec: (res.goldGained + lootSellGold) / maxOfflineSeconds,
    expPerSec: res.expGained / maxOfflineSeconds,
  );
}

_CurveFit _fitPowerCurve(List<MapEntry<int, double>> points) {
  double evaluateLoss(double b, double c) {
    final basis = [for (final p in points) c * math.log(1.0 + b * p.key)];
    final logs = [for (final p in points) math.log(p.value)];
    var sumDiff = 0.0;
    for (var i = 0; i < points.length; i++) {
      sumDiff += logs[i] - basis[i];
    }
    final logA = sumDiff / points.length;
    var sse = 0.0;
    for (var i = 0; i < points.length; i++) {
      final err = (logA + basis[i]) - logs[i];
      sse += err * err;
    }
    return sse;
  }

  var bestB = 5.0;
  var bestC = 1.0;
  var bestLoss = double.infinity;

  // Coarse deterministic 2D search.
  for (var bi = 1; bi <= 120; bi++) {
    final b = bi * 0.25;
    for (var ci = 85; ci <= 250; ci += 2) {
      final c = ci / 100.0;
      final loss = evaluateLoss(b, c);
      if (loss < bestLoss) {
        bestLoss = loss;
        bestB = b;
        bestC = c;
      }
    }
  }

  // Deterministic coordinate refinement.
  var stepB = 0.25;
  var stepC = 0.02;
  for (var iter = 0; iter < 14; iter++) {
    for (var db = -2; db <= 2; db++) {
      for (var dc = -2; dc <= 2; dc++) {
        final nb = bestB + db * stepB;
        final nc = bestC + dc * stepC;
        if (nb <= 0.05 || nc < 0.85) continue;
        final loss = evaluateLoss(nb, nc);
        if (loss < bestLoss) {
          bestLoss = loss;
          bestB = nb;
          bestC = nc;
        }
      }
    }
    stepB *= 0.5;
    stepC *= 0.5;
  }

  // Optimal unscaled log-mean intercept A_fit.
  var sumDiff = 0.0;
  for (final p in points) {
    sumDiff += math.log(p.value) - bestC * math.log(1.0 + bestB * p.key);
  }
  final aUnscaled = math.exp(sumDiff / points.length);

  var maxRatio = 0.0;
  var maxRelErr = 0.0;
  for (final p in points) {
    final shape = math.pow(1.0 + bestB * p.key, bestC).toDouble();
    final ratio = p.value / shape;
    if (ratio > maxRatio) {
      maxRatio = ratio;
    }
    final fitted = aUnscaled * shape;
    final relErr = ((fitted - p.value) / p.value).abs();
    if (relErr > maxRelErr) {
      maxRelErr = relErr;
    }
  }

  final aScaled = maxRatio * _kCurveEnvelopeMargin;
  final rmsLogError = math.sqrt(bestLoss / points.length);
  return _CurveFit(
    a: aScaled,
    aUnscaled: aUnscaled,
    b: bestB,
    c: bestC,
    rmsLogError: rmsLogError,
    maxRelFitError: maxRelErr,
  );
}

String _renderRules({
  required String template,
  required _CurveFit goldFit,
  required _CurveFit expFit,
  required double safetyFactor,
  required int graceSeconds,
  required int dailyShard,
  required int weeklyShard,
  required int spireMaxShards,
  required int absMaxShards,
  required int absMaxLevel,
  required int minRunSeconds,
  required int minCycleSeconds,
  required int expBase,
  required double expExponent,
}) {
  final replacements = <String, String>{
    'SAFETY_FACTOR': _fmtNum(safetyFactor),
    'GOLD_A': _round6(goldFit.a).toString(),
    'GOLD_B': _round6(goldFit.b).toString(),
    'GOLD_C': _round6(goldFit.c).toString(),
    'EXP_A': _round6(expFit.a).toString(),
    'EXP_B': _round6(expFit.b).toString(),
    'EXP_C': _round6(expFit.c).toString(),
    'MIN_SCHEMA_VERSION': '$_kSchemaVersion',
    'ABS_MAX_SCHEMA_VERSION': '100',
    'MIN_CODEC_VERSION': '$_kCodecVersion',
    'ABS_MAX_CODEC_VERSION': '100',
    'ABS_MAX_LEVEL': '$absMaxLevel',
    'ABS_MAX_GOLD': '$_kAbsMaxGold',
    'ABS_MAX_SHARDS': '$absMaxShards',
    'ABS_MAX_RANK': '$_kAbsMaxRank',
    'ABS_MAX_LIFETIME_CLEARS': '$_kAbsMaxLifetimeClears',
    'ABS_MAX_DAILY_QUESTS': '$_kAbsMaxDailyQuests',
    'ABS_MAX_WEEKLY_QUESTS': '$_kAbsMaxWeeklyQuests',
    'ABS_MAX_EVENT_PURCHASES': '$_kAbsMaxEventPurchases',
    'ABS_MAX_EQUIPMENT_COUNT': '$_kAbsMaxEquipmentCount',
    'MAX_BLOB_BYTES': '$_kMaxBlobBytes',
    'DAILY_SHARD': '$dailyShard',
    'WEEKLY_SHARD': '$weeklyShard',
    'SPIRE_MAX_SHARDS': '$spireMaxShards',
    'GRACE_SECONDS': '$graceSeconds',
    'MIN_CYCLE_SECONDS': '$minCycleSeconds',
    'MIN_RUN_SECONDS': '$minRunSeconds',
    'EXP_BASE': '$expBase',
    'EXP_EXPONENT': _round6(expExponent).toString(),
    'GOLD_BASE': '$_kGoldBase',
  };

  var out = template;
  for (final entry in replacements.entries) {
    out = out.replaceAll('{{${entry.key}}}', entry.value);
  }
  final leftover = RegExp(r'\{\{[A-Z0-9_]+\}\}').firstMatch(out);
  if (leftover != null) {
    throw StateError('Unreplaced template placeholder: ${leftover.group(0)}');
  }
  return out;
}

String _renderGeneratedDartConstants({
  required double safetyFactor,
  required int graceSeconds,
  required int dailyShard,
  required int weeklyShard,
  required int spireMaxShards,
  required int absMaxShards,
  required int absMaxLevel,
  required int minRunSeconds,
  required int minCycleSeconds,
  required int expBase,
  required double expExponent,
  required _CurveFit goldFit,
  required _CurveFit expFit,
}) {
  return '''// GENERATED BY tool/export_cloud_limits.dart. DO NOT EDIT BY HAND.

import 'cloud_limits_spec.dart';

const CloudLimitsSpec kGeneratedCloudLimitsSpec = CloudLimitsSpec(
  safetyFactor: ${_fmtNum(safetyFactor)},
  graceSeconds: $graceSeconds,
  dailyShard: $dailyShard,
  weeklyShard: $weeklyShard,
  spireMaxShards: $spireMaxShards,
  maxBlobBytes: $_kMaxBlobBytes,
  minSchemaVersion: $_kSchemaVersion,
  absMaxSchemaVersion: 100,
  minCodecVersion: $_kCodecVersion,
  absMaxCodecVersion: 100,
  absMaxLevel: $absMaxLevel,
  absMaxGold: $_kAbsMaxGold,
  absMaxShards: $absMaxShards,
  absMaxRank: $_kAbsMaxRank,
  absMaxLifetimeClears: $_kAbsMaxLifetimeClears,
  absMaxDailyQuests: $_kAbsMaxDailyQuests,
  absMaxWeeklyQuests: $_kAbsMaxWeeklyQuests,
  absMaxEventPurchases: $_kAbsMaxEventPurchases,
  absMaxEquipmentCount: $_kAbsMaxEquipmentCount,
  minRunSeconds: $minRunSeconds,
  minCycleSeconds: $minCycleSeconds,
  goldBase: $_kGoldBase,
  expBase: $expBase,
  expExponent: ${_round6(expExponent)},
  goldCurveA: ${_round6(goldFit.a)},
  goldCurveB: ${_round6(goldFit.b)},
  goldCurveC: ${_round6(goldFit.c)},
  expCurveA: ${_round6(expFit.a)},
  expCurveB: ${_round6(expFit.b)},
  expCurveC: ${_round6(expFit.c)},
);
''';
}

List<Map<String, Object?>> _buildTestVectors({
  required List<_RankSample> samples,
  required _CurveFit goldFit,
  required _CurveFit expFit,
  required double safetyFactor,
  required int graceSeconds,
  required int dailyShard,
  required int weeklyShard,
  required int spireMaxShards,
  required int absMaxShards,
  required int absMaxLevel,
  required int minRunSeconds,
  required int minCycleSeconds,
  required int expBase,
  required double expExponent,
}) {
  String shaHex(String label) => sha256.convert(utf8.encode(label)).toString();
  String dummyBlobBase64(int length) =>
      base64Encode(List<int>.filled(length, 1));

  Map<String, Object?> makeDoc({
    required int revision,
    required int level,
    required int gold,
    required int shards,
    required int highestAscensionRank,
    required int lifetimeClears,
    required int dailyQuestDone,
    required int weeklyQuestDone,
    required int eventPurchasesLifetime,
    int equipmentCount = 12,
    int schemaVersion = _kSchemaVersion,
    int codecVersion = _kCodecVersion,
    int blobByteLength = 64,
    int? overrideBlobBytes,
    String deviceId = 'device-a',
    String appVersion = '1.0.0+1',
    String? slotOverride,
    Map<String, Object?>? extraFields,
    String? removeField,
    Map<String, Object?>? overrideFieldValues,
  }) {
    final doc = <String, Object?>{
      'revision': revision,
      'schemaVersion': schemaVersion,
      'codecVersion': codecVersion,
      'deviceId': deviceId,
      'appVersion': appVersion,
      'level': level,
      'gold': gold,
      'shards': shards,
      'highestAscensionRank': highestAscensionRank,
      'lifetimeClears': lifetimeClears,
      'dailyQuestDone': dailyQuestDone,
      'weeklyQuestDone': weeklyQuestDone,
      'eventPurchasesLifetime': eventPurchasesLifetime,
      'equipmentCount': equipmentCount,
      'blobBytes': overrideBlobBytes ?? blobByteLength,
      'blobSha256': shaHex('rev_${revision}_${level}_$gold'),
      'blobBase64': dummyBlobBase64(blobByteLength),
    };
    if (extraFields != null) {
      doc.addAll(extraFields);
    }
    if (removeField != null) {
      doc.remove(removeField);
    }
    if (overrideFieldValues != null) {
      doc.addAll(overrideFieldValues);
    }
    if (slotOverride != null) {
      doc['_targetSlot'] = slotOverride;
    }
    return doc;
  }

  final vectors = <Map<String, Object?>>[];

  // 1. Valid first upload (revision 1, slot 1).
  vectors.add({
    'name': 'accept_first_upload_revision_1',
    'category': 'valid_first_upload',
    'dtSeconds': 0,
    'prev': null,
    'next': makeDoc(
      revision: 1,
      level: 5,
      gold: 500,
      shards: 10,
      highestAscensionRank: 0,
      lifetimeClears: 3,
      dailyQuestDone: 1,
      weeklyQuestDone: 0,
      eventPurchasesLifetime: 0,
    ),
    'expectAccept': true,
    'reason':
        'Valid first upload to slot 1 at revision 1 within absolute bounds',
  });

  // 2. Valid simulator progression saves at ranks 0, 1, 5, 10, 50 over 1 hour (3600s).
  for (final targetRank in [0, 1, 5, 10, 50]) {
    final sample = samples.firstWhere((s) => s.rank == targetRank);
    final prevLevel = math.max(1, 5 + targetRank * 44);
    const dt = 3600;
    final simGoldDelta = (sample.maxGoldPerSec * dt).round();
    final expEarned = sample.maxExpPerSec * dt;
    final expPerLv = expBase * math.pow(prevLevel, expExponent).toDouble();
    final simLevelDelta = math.max(0, (expEarned / expPerLv).floor());
    final simClearsDelta = math.max(1, (dt / sample.minRunSeconds).floor());

    final prev = makeDoc(
      revision: 1,
      level: prevLevel,
      gold: 10000,
      shards: 60,
      highestAscensionRank: targetRank,
      lifetimeClears: 10 + targetRank * 20,
      dailyQuestDone: 1,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
    );
    final next = makeDoc(
      revision: 2,
      level: prevLevel + simLevelDelta,
      gold: 10000 + simGoldDelta,
      shards: 70,
      highestAscensionRank: targetRank,
      lifetimeClears: 10 + targetRank * 20 + simClearsDelta,
      dailyQuestDone: 2,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
    );
    vectors.add({
      'name': 'accept_simulator_valid_rank_$targetRank',
      'category': 'valid_simulator',
      'dtSeconds': dt,
      'prev': prev,
      'next': next,
      'expectAccept': true,
      'reason': 'Legitimate 1h simulator progression at rank $targetRank',
    });
  }

  // 3. Valid tight boundary case: right below continuous gold & clears ceilings + exact shard cap.
  {
    const dt = 3600;
    final effDt = dt + graceSeconds.toDouble();
    final roundedGoldRate =
        _round6(goldFit.a) *
        math.pow(1.0 + _round6(goldFit.b) * 5, _round6(goldFit.c)).toDouble();
    final maxGoldDelta = (roundedGoldRate * effDt * safetyFactor + _kGoldBase)
        .floor();
    final maxClearsDelta = (effDt / minRunSeconds).floor() + 1;
    final maxDailyDelta = (dt / 86400).floor() + 2; // 2
    final prev = makeDoc(
      revision: 1,
      level: 225,
      gold: 500000,
      shards: 100,
      highestAscensionRank: 5,
      lifetimeClears: 500,
      dailyQuestDone: 5,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
    );
    final nextDaily = 5 + maxDailyDelta;
    final next = makeDoc(
      revision: 2,
      level: 225,
      gold: 500000 + maxGoldDelta,
      shards: dailyShard * nextDaily + weeklyShard * 1 + spireMaxShards,
      highestAscensionRank: 5,
      lifetimeClears: 500 + maxClearsDelta,
      dailyQuestDone: nextDaily,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
    );
    vectors.add({
      'name': 'accept_tight_boundary_ceilings',
      'category': 'boundary_accept',
      'dtSeconds': dt,
      'prev': prev,
      'next': next,
      'expectAccept': true,
      'reason':
          'Exact legal upper bound on gold, clears, daily quests, and shards',
    });
  }

  // Helper base prev for cheat / invalid cases.
  final basePrev = makeDoc(
    revision: 1,
    level: 20,
    gold: 50000,
    shards: 60,
    highestAscensionRank: 1,
    lifetimeClears: 100,
    dailyQuestDone: 1,
    weeklyQuestDone: 1,
    eventPurchasesLifetime: 0,
  );

  // 4. Cheat: gold x1000 above simulator/ceiling.
  {
    const dt = 3600;
    final r1Gold = (samples.firstWhere((s) => s.rank == 1).maxGoldPerSec * dt)
        .round();
    vectors.add({
      'name': 'reject_cheat_gold_1000x',
      'category': 'cheat_continuous',
      'dtSeconds': dt,
      'prev': basePrev,
      'next': makeDoc(
        revision: 2,
        level: 21,
        gold: 50000 + r1Gold * 1000,
        shards: 60,
        highestAscensionRank: 1,
        lifetimeClears: 120,
        dailyQuestDone: 1,
        weeklyQuestDone: 1,
        eventPurchasesLifetime: 0,
      ),
      'expectAccept': false,
      'reason':
          'Gold gain is 1000x legitimate rate and exceeds GOLD_PER_SEC ceiling',
    });
  }

  // 5. Cheat: huge level jump in 60 seconds exceeding EXP_PER_SEC ceiling.
  {
    const dt = 60;
    final effDt = dt + graceSeconds.toDouble();
    final roundedExpRate =
        _round6(expFit.a) *
        math.pow(1.0 + _round6(expFit.b) * 1, _round6(expFit.c)).toDouble();
    final expDenom = expBase * math.pow(20, _round6(expExponent)).toDouble();
    final legalLevelMax =
        ((roundedExpRate * effDt * safetyFactor) / expDenom + 1.0).ceil();
    final cheatTargetLevel = math.min(absMaxLevel, 20 + legalLevelMax + 500);
    vectors.add({
      'name': 'reject_cheat_level_jump',
      'category': 'cheat_continuous',
      'dtSeconds': dt,
      'prev': basePrev,
      'next': makeDoc(
        revision: 2,
        level: cheatTargetLevel,
        gold: 60000,
        shards: 60,
        highestAscensionRank: 1,
        lifetimeClears: 105,
        dailyQuestDone: 1,
        weeklyQuestDone: 1,
        eventPurchasesLifetime: 0,
      ),
      'expectAccept': false,
      'reason':
          'Level jump (+${cheatTargetLevel - 20} in ${dt}s) exceeds EXP_PER_SEC ceiling ($legalLevelMax)',
    });
  }

  // 6. Cheat: rank jump exceeding MIN_CYCLE_SECONDS rate (+(floor(60/MIN_CYCLE)+2) in 60s, and +5 in 45s).
  final overCycle60Delta = (60 ~/ minCycleSeconds) + 2;
  vectors.add({
    'name': 'reject_cheat_rank_exceeds_min_cycle_in_60s',
    'category': 'cheat_continuous',
    'dtSeconds': 60,
    'prev': basePrev,
    'next': makeDoc(
      revision: 2,
      level: 25,
      gold: 60000,
      shards: 60,
      highestAscensionRank: 1 + overCycle60Delta,
      lifetimeClears: 110,
      dailyQuestDone: 1,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
    ),
    'expectAccept': false,
    'reason':
        'Rank jump +$overCycle60Delta in 60s exceeds floor(60/$minCycleSeconds)+1',
  });
  vectors.add({
    'name': 'reject_cheat_rank_plus_5_in_45s',
    'category': 'cheat_continuous',
    'dtSeconds': 45,
    'prev': basePrev,
    'next': makeDoc(
      revision: 2,
      level: 25,
      gold: 60000,
      shards: 60,
      highestAscensionRank: 6,
      lifetimeClears: 110,
      dailyQuestDone: 1,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
    ),
    'expectAccept': false,
    'reason': 'Rank jump +5 in 45s exceeds MIN_CYCLE_SECONDS rate',
  });

  // 7. Cheat: shards exceed ABS_MAX_SHARDS.
  vectors.add({
    'name': 'reject_cheat_shards_exceed_abs_max',
    'category': 'cheat_absolute',
    'dtSeconds': 600,
    'prev': basePrev,
    'next': makeDoc(
      revision: 2,
      level: 20,
      gold: 55000,
      shards: absMaxShards + 1,
      highestAscensionRank: 1,
      lifetimeClears: 101,
      dailyQuestDone: 1,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
    ),
    'expectAccept': false,
    'reason': 'Shards exceed ABS_MAX_SHARDS ($absMaxShards)',
  });

  // 8. Cheat: dailyQuestDone +10 in 1 hour.
  vectors.add({
    'name': 'reject_cheat_daily_quest_plus_10_in_1h',
    'category': 'cheat_periodic',
    'dtSeconds': 3600,
    'prev': basePrev,
    'next': makeDoc(
      revision: 2,
      level: 20,
      gold: 55000,
      shards: 60,
      highestAscensionRank: 1,
      lifetimeClears: 105,
      dailyQuestDone: 11,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
    ),
    'expectAccept': false,
    'reason': 'dailyQuestDone +10 in 3600s exceeds floor(3600/86400)+2 (=2)',
  });

  // 8b. Cheat: weeklyQuestDone +5 in 1h, eventPurchasesLifetime +10 in 1h, lifetimeClears bot.
  vectors.add({
    'name': 'reject_cheat_weekly_quest_plus_5_in_1h',
    'category': 'cheat_periodic',
    'dtSeconds': 3600,
    'prev': basePrev,
    'next': makeDoc(
      revision: 2,
      level: 20,
      gold: 55000,
      shards: 60,
      highestAscensionRank: 1,
      lifetimeClears: 105,
      dailyQuestDone: 1,
      weeklyQuestDone: 6,
      eventPurchasesLifetime: 0,
    ),
    'expectAccept': false,
    'reason': 'weeklyQuestDone +5 in 3600s exceeds floor(3600/604800)+2 (=2)',
  });
  vectors.add({
    'name': 'reject_cheat_event_purchases_plus_10_in_1h',
    'category': 'cheat_periodic',
    'dtSeconds': 3600,
    'prev': basePrev,
    'next': makeDoc(
      revision: 2,
      level: 20,
      gold: 55000,
      shards: 60,
      highestAscensionRank: 1,
      lifetimeClears: 105,
      dailyQuestDone: 1,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 10,
    ),
    'expectAccept': false,
    'reason': 'eventPurchasesLifetime +10 in 3600s exceeds 2*(floor(3600/604800)+2) (=4)',
  });
  {
    const dt = 60;
    final clearsCap = ((dt + graceSeconds) / minRunSeconds + 1.0).ceil();
    vectors.add({
      'name': 'reject_cheat_lifetime_clears_rate',
      'category': 'cheat_continuous',
      'dtSeconds': dt,
      'prev': basePrev,
      'next': makeDoc(
        revision: 2,
        level: 20,
        gold: 55000,
        shards: 60,
        highestAscensionRank: 1,
        lifetimeClears: 100 + clearsCap + 100,
        dailyQuestDone: 1,
        weeklyQuestDone: 1,
        eventPurchasesLifetime: 0,
      ),
      'expectAccept': false,
      'reason':
          'lifetimeClears jump (+${clearsCap + 100} in ${dt}s) exceeds MIN_RUN_SECONDS rate',
    });
  }

  // 9. Reject monotonic decrease (level & lifetimeClears decrease).
  vectors.add({
    'name': 'reject_monotonic_level_decrease',
    'category': 'monotonic',
    'dtSeconds': 600,
    'prev': basePrev,
    'next': makeDoc(
      revision: 2,
      level: 19,
      gold: 50000,
      shards: 60,
      highestAscensionRank: 1,
      lifetimeClears: 100,
      dailyQuestDone: 1,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
    ),
    'expectAccept': false,
    'reason': 'Monotonic field level decreased from 20 to 19',
  });

  // 10. Reject extra field (hasOnly).
  vectors.add({
    'name': 'reject_extra_field',
    'category': 'schema',
    'dtSeconds': 60,
    'prev': basePrev,
    'next': makeDoc(
      revision: 2,
      level: 20,
      gold: 50000,
      shards: 60,
      highestAscensionRank: 1,
      lifetimeClears: 100,
      dailyQuestDone: 1,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
      extraFields: {'injectedAdminFlag': true},
    ),
    'expectAccept': false,
    'reason': 'Extra undeclared field must fail hasOnly check',
  });

  // 11. Reject wrong type (gold as string).
  vectors.add({
    'name': 'reject_wrong_field_type',
    'category': 'schema',
    'dtSeconds': 60,
    'prev': basePrev,
    'next': makeDoc(
      revision: 2,
      level: 20,
      gold: 50000,
      shards: 60,
      highestAscensionRank: 1,
      lifetimeClears: 100,
      dailyQuestDone: 1,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
      overrideFieldValues: {'gold': '50000'},
    ),
    'expectAccept': false,
    'reason': 'Field gold has wrong type string instead of int',
  });

  // 12. Reject blob > 900000 bytes.
  vectors.add({
    'name': 'reject_blob_over_900000_bytes',
    'category': 'absolute',
    'dtSeconds': 60,
    'prev': basePrev,
    'next': makeDoc(
      revision: 2,
      level: 20,
      gold: 50000,
      shards: 60,
      highestAscensionRank: 1,
      lifetimeClears: 100,
      dailyQuestDone: 1,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
      blobByteLength: _kMaxBlobBytes + 1,
    ),
    'expectAccept': false,
    'reason': 'Blob size exceeds 900000 byte limit',
  });

  // 13. Reject wrong slot (revision 2 written to slot 1 instead of 0).
  vectors.add({
    'name': 'reject_wrong_slot_for_revision',
    'category': 'structure',
    'dtSeconds': 60,
    'prev': basePrev,
    'next': makeDoc(
      revision: 2,
      level: 20,
      gold: 50000,
      shards: 60,
      highestAscensionRank: 1,
      lifetimeClears: 100,
      dailyQuestDone: 1,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
      slotOverride: '1',
    ),
    'expectAccept': false,
    'reason': 'Revision 2 must target slot 0 (revision % 2), not slot 1',
  });

  // 14. Reject skipped revision (revision 3 instead of prev.revision + 1 = 2).
  vectors.add({
    'name': 'reject_skipped_revision',
    'category': 'structure',
    'dtSeconds': 60,
    'prev': basePrev,
    'next': makeDoc(
      revision: 3,
      level: 20,
      gold: 50000,
      shards: 60,
      highestAscensionRank: 1,
      lifetimeClears: 100,
      dailyQuestDone: 1,
      weeklyQuestDone: 1,
      eventPurchasesLifetime: 0,
    ),
    'expectAccept': false,
    'reason': 'Revision jumped from 1 to 3 instead of prev.revision + 1',
  });

  // 15. Reject first upload exceeding absolute caps.
  vectors.add({
    'name': 'reject_first_upload_exceeds_abs_level',
    'category': 'absolute',
    'dtSeconds': 0,
    'prev': null,
    'next': makeDoc(
      revision: 1,
      level: absMaxLevel + 1,
      gold: 500,
      shards: 0,
      highestAscensionRank: 0,
      lifetimeClears: 1,
      dailyQuestDone: 0,
      weeklyQuestDone: 0,
      eventPurchasesLifetime: 0,
    ),
    'expectAccept': false,
    'reason': 'First upload level exceeds ABS_MAX_LEVEL',
  });

  return vectors;
}

void _printSummary({
  required List<_RankSample> samples,
  required _CurveFit goldFit,
  required _CurveFit expFit,
  required double safetyFactor,
  required double rawMinRunSec,
  required double rawMinCycleSec,
  required int minRunSeconds,
  required int minCycleSeconds,
  required int vectorCount,
}) {
  stdout.writeln(
    '=== Echoes of Aether — Cloud Limits Export (SAFETY=${_fmtNum(safetyFactor)}) ===',
  );
  stdout.writeln(
    'GOLD_PER_SEC(rank) = ${_round6(goldFit.a)} * (1 + ${_round6(goldFit.b)} * rank)^${_round6(goldFit.c)} '
    '(unscaled A=${_round6(goldFit.aUnscaled)}, rmsLogErr=${_round6(goldFit.rmsLogError)}, maxRelFitErr=${_round6(goldFit.maxRelFitError * 100)}%)',
  );
  stdout.writeln(
    'EXP_PER_SEC(rank)  = ${_round6(expFit.a)} * (1 + ${_round6(expFit.b)} * rank)^${_round6(expFit.c)} '
    '(unscaled A=${_round6(expFit.aUnscaled)}, rmsLogErr=${_round6(expFit.rmsLogError)}, maxRelFitErr=${_round6(expFit.maxRelFitError * 100)}%)',
  );
  stdout.writeln(
    'MIN_RUN_SECONDS   = $minRunSeconds (raw min=${_round6(rawMinRunSec)}s)',
  );
  stdout.writeln(
    'MIN_CYCLE_SECONDS = $minCycleSeconds (raw min=${_round6(rawMinCycleSec)}s)',
  );
  stdout.writeln(
    '\n| Rank | Sim Max G/s | Curve G/s | Margin S=1 | Margin S=2 | Margin S=${_fmtNum(safetyFactor)} | Gold Fit Err% | Source |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|');
  for (final s in samples) {
    final gCurve = goldFit.eval(s.rank);
    final gFitErr =
        ((goldFit.evalUnscaled(s.rank) - s.maxGoldPerSec) / s.maxGoldPerSec) *
        100.0;
    stdout.writeln(
      '| ${s.rank} | ${s.maxGoldPerSec.toStringAsFixed(2)} | ${gCurve.toStringAsFixed(2)} | '
      '${(gCurve / s.maxGoldPerSec).toStringAsFixed(2)}x | '
      '${((gCurve * 2.0) / s.maxGoldPerSec).toStringAsFixed(2)}x | '
      '${((gCurve * safetyFactor) / s.maxGoldPerSec).toStringAsFixed(2)}x | '
      '${gFitErr.toStringAsFixed(1)}% | ${s.goldSource} |',
    );
  }
  stdout.writeln(
    '\n| Rank | Sim Max EXP/s | Curve EXP/s | Margin S=1 | Margin S=2 | Margin S=${_fmtNum(safetyFactor)} | EXP Fit Err% | Source |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|');
  for (final s in samples) {
    final eCurve = expFit.eval(s.rank);
    final eFitErr =
        ((expFit.evalUnscaled(s.rank) - s.maxExpPerSec) / s.maxExpPerSec) *
        100.0;
    stdout.writeln(
      '| ${s.rank} | ${s.maxExpPerSec.toStringAsFixed(2)} | ${eCurve.toStringAsFixed(2)} | '
      '${(eCurve / s.maxExpPerSec).toStringAsFixed(2)}x | '
      '${((eCurve * 2.0) / s.maxExpPerSec).toStringAsFixed(2)}x | '
      '${((eCurve * safetyFactor) / s.maxExpPerSec).toStringAsFixed(2)}x | '
      '${eFitErr.toStringAsFixed(1)}% | ${s.expSource} |',
    );
  }
  stdout.writeln('\n| Rank | Min Run (s) | Min Run Dungeon | Min Cycle (s) |');
  stdout.writeln('|---|---|---|---|');
  for (final s in samples) {
    stdout.writeln(
      '| ${s.rank} | ${s.minRunSeconds.toStringAsFixed(2)} | ${s.minRunDungeon} | ${s.minCycleSeconds.toStringAsFixed(2)} |',
    );
  }
  stdout.writeln('\nExported $vectorCount test vectors.');
}

double _round6(double value) => double.parse(value.toStringAsFixed(6));

String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(1) : _round6(v).toString();

String _normalizeLineEndings(String text) => text.replaceAll('\r\n', '\n');
