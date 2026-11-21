import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:echoes_of_aether/domain/entities/cloud_limits_spec.dart';
import 'package:echoes_of_aether/domain/entities/generated_cloud_limits.dart';
import 'package:echoes_of_aether/domain/entities/save_metrics.dart';
import 'package:echoes_of_aether/domain/services/cloud_limits.dart';
import 'package:echoes_of_aether/domain/services/dungeon_progression_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/balance_simulator.dart';

void main() {
  late Map<String, Object?> limitsJson;
  late List<Map<String, Object?>> vectorsJson;
  late CloudLimits limits;

  setUpAll(() {
    limitsJson = jsonDecode(
      File('firebase/limits.json').readAsStringSync(),
    ) as Map<String, Object?>;
    vectorsJson = (jsonDecode(
      File('firebase/test_vectors.json').readAsStringSync(),
    ) as List<Object?>).cast<Map<String, Object?>>();
    limits = const CloudLimits();
  });

  group('M14 Stage 2 — CloudLimits & parity dengan pembangkit', () {
    test('kGeneratedCloudLimitsSpec cocok dengan firebase/limits.json', () {
      final fromJson = CloudLimitsSpec.fromJson(limitsJson);
      expect(fromJson.safetyFactor, kGeneratedCloudLimitsSpec.safetyFactor);
      expect(fromJson.graceSeconds, kGeneratedCloudLimitsSpec.graceSeconds);
      expect(fromJson.dailyShard, kGeneratedCloudLimitsSpec.dailyShard);
      expect(fromJson.weeklyShard, kGeneratedCloudLimitsSpec.weeklyShard);
      expect(fromJson.spireMaxShards, kGeneratedCloudLimitsSpec.spireMaxShards);
      expect(kGeneratedCloudLimitsSpec.spireMaxShards, 1960);
      expect(fromJson.minRunSeconds, kGeneratedCloudLimitsSpec.minRunSeconds);
      expect(
        fromJson.minCycleSeconds,
        kGeneratedCloudLimitsSpec.minCycleSeconds,
      );
      expect(fromJson.goldCurveA, kGeneratedCloudLimitsSpec.goldCurveA);
      expect(fromJson.goldCurveB, kGeneratedCloudLimitsSpec.goldCurveB);
      expect(fromJson.goldCurveC, kGeneratedCloudLimitsSpec.goldCurveC);
      expect(fromJson.expCurveA, kGeneratedCloudLimitsSpec.expCurveA);
      expect(fromJson.expCurveB, kGeneratedCloudLimitsSpec.expCurveB);
      expect(fromJson.expCurveC, kGeneratedCloudLimitsSpec.expCurveC);
    });

    test('seluruh vektor test_vectors.json menghasilkan keputusan identik pada CloudLimits', () {
      expect(vectorsJson.length, greaterThanOrEqualTo(15));
      for (final vector in vectorsJson) {
        final name = vector['name'] as String;
        final expectAccept = vector['expectAccept'] as bool;
        final dtSeconds = (vector['dtSeconds'] as num).toDouble();
        final rawPrev = vector['prev'] as Map<String, Object?>?;
        final rawNext = vector['next'] as Map<String, Object?>;

        final prev = rawPrev == null
            ? null
            : CloudSaveCandidate.fromVectorJson(rawPrev);
        final next = CloudSaveCandidate.fromVectorJson(rawNext);
        final violations = limits.explainViolation(prev, next, dtSeconds);

        expect(
          violations.isEmpty,
          expectAccept,
          reason: 'Vector "$name" failed parity: $violations',
        );
        if (!expectAccept) {
          expect(
            violations,
            isNotEmpty,
            reason: 'Rejected vector "$name" must explain violation.',
          );
          expect(violations.first.message, isNotEmpty);
        }
      }
    });

    test('fungsi plafon monoton naik & mendominasi setiap titik simulator di limits.json (SAFETY 1, 2, 5)', () {
      final diagnostics = (limitsJson['sampleDiagnostics'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(diagnostics.map((d) => d['rank']), [0, 1, 2, 5, 10, 20, 50]);

      for (final row in diagnostics) {
        final rank = row['rank'] as int;
        final simGold = (row['simMaxGoldPerSec'] as num).toDouble();
        final simExp = (row['simMaxExpPerSec'] as num).toDouble();
        final curveGold = limits.goldPerSec(rank);
        final curveExp = limits.expPerSec(rank);

        expect(
          curveGold,
          greaterThan(simGold),
          reason: 'Gold ceiling must exceed raw simulator rate at rank $rank',
        );
        expect(
          curveExp,
          greaterThan(simExp),
          reason: 'EXP ceiling must exceed raw simulator rate at rank $rank',
        );
        // Verifikasi juga tetap aman bila SAFETY diturunkan menjadi 2.
        expect(curveGold * 2.0, greaterThan(simGold * 2.0));
        expect(curveExp * 2.0, greaterThan(simExp * 2.0));
      }

      // Ekstrapolasi di luar rentang [0..50] harus monoton naik hingga ABS_MAX_RANK.
      var prevGold = limits.goldPerSec(0);
      var prevExp = limits.expPerSec(0);
      for (final r in [1, 2, 5, 10, 20, 50, 100, 500, 1000, 5000, 10000]) {
        final g = limits.goldPerSec(r);
        final e = limits.expPerSec(r);
        expect(g, greaterThan(prevGold), reason: 'goldPerSec monotonic at $r');
        expect(e, greaterThan(prevExp), reason: 'expPerSec monotonic at $r');
        prevGold = g;
        prevExp = e;
      }
    });

    test('simulasi nyata BalanceSimulator pada rank {0, 1, 5, 10, 50} diterima oleh CloudLimits', () {
      final config = BalanceSimulator.loadRealConfig();
      final sim = BalanceSimulator(config);
      final dungeonProg = DungeonProgressionService(config.difficulty);
      final targetDungeon = config.dungeons['aether_sanctum']!;

      for (final rank in [0, 1, 5, 10, 50]) {
        final rec = dungeonProg.recommendedLevel(targetDungeon, rank);
        final res = sim.simulateScenario(
          dungeonId: targetDungeon.id,
          scenarioLabel: 'ParityCheck-R$rank',
          playerLevel: rec,
          gearProfile: sim.rankTierGearProfile(
            targetDungeon,
            cycleRank: rank,
            playerLevel: rec,
          ),
          cycleRank: rank,
          seedCount: 2,
        );
        const dt = 3600.0;
        final runsInHour = math.max(1, (dt / res.avgDurationSeconds).floor());
        final goldGain = (res.avgGoldPerRun * runsInHour).round();
        final expGain = res.avgExpPerRun * runsInHour;
        final expDenom =
            limits.spec.expBase *
            math.pow(rec, limits.spec.expExponent).toDouble();
        final levelsGain = (expGain / expDenom).floor();

        final prev = CloudSaveCandidate.fromMetrics(
          const SaveMetrics(
            level: 1,
            gold: 0,
            shards: 0,
            highestAscensionRank: 0,
            lifetimeClears: 0,
            dailyQuestDone: 0,
            weeklyQuestDone: 0,
            eventPurchasesLifetime: 0,
            equipmentCount: 4,
            blobBytes: 128,
            blobSha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            schemaVersion: 8,
            codecVersion: 1,
          ).copyWithValues(
            level: rec,
            highestAscensionRank: rank,
            lifetimeClears: 10,
          ),
          revision: 1,
          deviceId: 'sim-device',
          appVersion: '1.0.0+1',
        );
        final next = CloudSaveCandidate(
          revision: 2,
          schemaVersion: 8,
          codecVersion: 1,
          deviceId: 'sim-device',
          appVersion: '1.0.0+1',
          level: rec + levelsGain,
          gold: goldGain,
          shards: 0,
          highestAscensionRank: rank,
          lifetimeClears: 10 + runsInHour,
          dailyQuestDone: 0,
          weeklyQuestDone: 0,
          eventPurchasesLifetime: 0,
          equipmentCount: 8,
          blobBytes: 128,
          blobSha256: 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
        );

        final violations = limits.explainViolation(prev, next, dt);
        expect(
          violations,
          isEmpty,
          reason: 'Simulator progression at rank $rank rejected: $violations',
        );
      }
    });

    test('explainViolation melaporkan metrik, nilai aktual, batas, dan pesan yang tepat', () {
      const prev = CloudSaveCandidate(
        revision: 1,
        schemaVersion: 8,
        codecVersion: 1,
        deviceId: 'dev-1',
        appVersion: '1.0.0+1',
        level: 20,
        gold: 1000,
        shards: 10,
        highestAscensionRank: 1,
        lifetimeClears: 50,
        dailyQuestDone: 1,
        weeklyQuestDone: 0,
        eventPurchasesLifetime: 0,
        equipmentCount: 6,
        blobBytes: 64,
        blobSha256:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      const cheated = CloudSaveCandidate(
        revision: 2,
        schemaVersion: 8,
        codecVersion: 1,
        deviceId: 'dev-1',
        appVersion: '1.0.0+1',
        level: 19,
        gold: 1000,
        shards: 1000001,
        highestAscensionRank: 8,
        lifetimeClears: 50,
        dailyQuestDone: 1,
        weeklyQuestDone: 0,
        eventPurchasesLifetime: 0,
        equipmentCount: 6,
        blobBytes: 64,
        blobSha256:
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
      );

      final violations = limits.explainViolation(prev, cheated, 60);
      final metrics = violations.map((v) => v.metric).toSet();
      expect(metrics, containsAll(['level', 'shards', 'highestAscensionRank']));
      for (final v in violations) {
        expect(v.message, isNotEmpty);
        expect(v.category, isNotEmpty);
      }

      // Pemain dengan progres Boss Spire (mis. 1920 shard pada quest cap 140)
      // harus diterima karena total plafon quest + spire = 140 + 1960 = 2100.
      const spirePlayerPrev = CloudSaveCandidate(
        revision: 51,
        schemaVersion: 8,
        codecVersion: 1,
        deviceId: 'dev-1',
        appVersion: '1.0.0+1',
        level: 480,
        gold: 400000,
        shards: 140,
        highestAscensionRank: 10,
        lifetimeClears: 300,
        dailyQuestDone: 4,
        weeklyQuestDone: 2,
        eventPurchasesLifetime: 0,
        equipmentCount: 20,
        blobBytes: 64,
        blobSha256:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      const spirePlayerNext = CloudSaveCandidate(
        revision: 52,
        schemaVersion: 8,
        codecVersion: 1,
        deviceId: 'dev-1',
        appVersion: '1.0.0+1',
        level: 482,
        gold: 413600,
        shards: 1920,
        highestAscensionRank: 10,
        lifetimeClears: 320,
        dailyQuestDone: 4,
        weeklyQuestDone: 2,
        eventPurchasesLifetime: 0,
        equipmentCount: 20,
        blobBytes: 64,
        blobSha256:
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
      );
      expect(
        limits.explainViolation(spirePlayerPrev, spirePlayerNext, 3600),
        isEmpty,
      );
    });

    test('transisi migrasi M16 schemaVersion < 11 -> >= 11 mengizinkan clamp Lv>90->90, Rank>5->5, dan bonus gold Legacy Gift', () {
      const legacyCloud = CloudSaveCandidate(
        revision: 68,
        schemaVersion: 10,
        codecVersion: 1,
        deviceId: 'dev-1',
        appVersion: '1.0.0+1',
        level: 604,
        gold: 34230000,
        shards: 2900,
        highestAscensionRank: 13,
        lifetimeClears: 2500,
        dailyQuestDone: 40,
        weeklyQuestDone: 10,
        eventPurchasesLifetime: 12,
        equipmentCount: 40,
        blobBytes: 1024,
        blobSha256:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      // (604 - 90) * 5000 = 2.570.000 gold kompensasi Aether Legacy Gift
      const migratedLocal = CloudSaveCandidate(
        revision: 69,
        schemaVersion: 11,
        codecVersion: 1,
        deviceId: 'dev-1',
        appVersion: '1.0.0+1',
        level: 90,
        gold: 36800000,
        shards: 2900,
        highestAscensionRank: 5,
        lifetimeClears: 2500,
        dailyQuestDone: 40,
        weeklyQuestDone: 10,
        eventPurchasesLifetime: 12,
        equipmentCount: 40,
        blobBytes: 1024,
        blobSha256:
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
      );
      expect(limits.explainViolation(legacyCloud, migratedLocal, 0), isEmpty);

      // Turun di bawah 90 atau rank di bawah 5 tetap ditolak meski schema 10 -> 11.
      const invalidLevelDrop = CloudSaveCandidate(
        revision: 69,
        schemaVersion: 11,
        codecVersion: 1,
        deviceId: 'dev-1',
        appVersion: '1.0.0+1',
        level: 80,
        gold: 36800000,
        shards: 2900,
        highestAscensionRank: 5,
        lifetimeClears: 2500,
        dailyQuestDone: 40,
        weeklyQuestDone: 10,
        eventPurchasesLifetime: 12,
        equipmentCount: 40,
        blobBytes: 1024,
        blobSha256:
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
      );
      expect(
        limits
            .explainViolation(legacyCloud, invalidLevelDrop, 0)
            .map((v) => v.metric),
        contains('level'),
      );

      const invalidRankDrop = CloudSaveCandidate(
        revision: 69,
        schemaVersion: 11,
        codecVersion: 1,
        deviceId: 'dev-1',
        appVersion: '1.0.0+1',
        level: 90,
        gold: 36800000,
        shards: 2900,
        highestAscensionRank: 4,
        lifetimeClears: 2500,
        dailyQuestDone: 40,
        weeklyQuestDone: 10,
        eventPurchasesLifetime: 12,
        equipmentCount: 40,
        blobBytes: 1024,
        blobSha256:
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
      );
      expect(
        limits
            .explainViolation(legacyCloud, invalidRankDrop, 0)
            .map((v) => v.metric),
        contains('highestAscensionRank'),
      );

      // Pada schema yang sama (11 -> 11), penurunan level maupun rank tetap ditolak.
      const v11Prev = CloudSaveCandidate(
        revision: 68,
        schemaVersion: 11,
        codecVersion: 1,
        deviceId: 'dev-1',
        appVersion: '1.0.0+1',
        level: 604,
        gold: 34230000,
        shards: 2900,
        highestAscensionRank: 13,
        lifetimeClears: 2500,
        dailyQuestDone: 40,
        weeklyQuestDone: 10,
        eventPurchasesLifetime: 12,
        equipmentCount: 40,
        blobBytes: 1024,
        blobSha256:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      final sameSchemaViolations = limits
          .explainViolation(v11Prev, migratedLocal, 0)
          .map((v) => v.metric)
          .toSet();
      expect(
        sameSchemaViolations,
        containsAll(['level', 'highestAscensionRank']),
      );
    });
  });
}

extension on SaveMetrics {
  SaveMetrics copyWithValues({
    int? level,
    int? highestAscensionRank,
    int? lifetimeClears,
  }) => SaveMetrics(
    level: level ?? this.level,
    gold: gold,
    shards: shards,
    highestAscensionRank: highestAscensionRank ?? this.highestAscensionRank,
    lifetimeClears: lifetimeClears ?? this.lifetimeClears,
    dailyQuestDone: dailyQuestDone,
    weeklyQuestDone: weeklyQuestDone,
    eventPurchasesLifetime: eventPurchasesLifetime,
    equipmentCount: equipmentCount,
    blobBytes: blobBytes,
    blobSha256: blobSha256,
    schemaVersion: schemaVersion,
    codecVersion: codecVersion,
  );
}
