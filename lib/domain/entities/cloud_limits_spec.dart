import 'dart:math' as math;

/// Spesifikasi parameter batas & fungsi plafon Cloud Sync (hasil pembangkit
/// deterministik `tool/export_cloud_limits.dart`).
///
/// Lapisan domain murni (tanpa dependensi Flutter/Flame/Drift/`dart:io`).
class CloudLimitsSpec {
  const CloudLimitsSpec({
    required this.safetyFactor,
    required this.graceSeconds,
    required this.dailyShard,
    required this.weeklyShard,
    this.spireMaxShards = 0,
    required this.maxBlobBytes,
    required this.minSchemaVersion,
    required this.absMaxSchemaVersion,
    required this.minCodecVersion,
    required this.absMaxCodecVersion,
    required this.absMaxLevel,
    required this.absMaxGold,
    required this.absMaxShards,
    required this.absMaxRank,
    required this.absMaxLifetimeClears,
    required this.absMaxDailyQuests,
    required this.absMaxWeeklyQuests,
    required this.absMaxEventPurchases,
    required this.absMaxEquipmentCount,
    required this.minRunSeconds,
    required this.minCycleSeconds,
    required this.goldBase,
    required this.expBase,
    required this.expExponent,
    required this.goldCurveA,
    required this.goldCurveB,
    required this.goldCurveC,
    required this.expCurveA,
    required this.expCurveB,
    required this.expCurveC,
  });

  factory CloudLimitsSpec.fromJson(Map<String, Object?> json) {
    final goldCurve =
        (json['goldPerSecCurve'] as Map<String, Object?>?) ?? const {};
    final expCurve =
        (json['expPerSecCurve'] as Map<String, Object?>?) ?? const {};
    return CloudLimitsSpec(
      safetyFactor: _asDouble(json['safetyFactor'], 'safetyFactor'),
      graceSeconds: _asInt(json['graceSeconds'], 'graceSeconds'),
      dailyShard: _asInt(json['dailyShard'], 'dailyShard'),
      weeklyShard: _asInt(json['weeklyShard'], 'weeklyShard'),
      spireMaxShards: json['spireMaxShards'] == null
          ? 0
          : _asInt(json['spireMaxShards'], 'spireMaxShards'),
      maxBlobBytes: _asInt(json['maxBlobBytes'], 'maxBlobBytes'),
      minSchemaVersion: _asInt(json['minSchemaVersion'], 'minSchemaVersion'),
      absMaxSchemaVersion: _asInt(
        json['absMaxSchemaVersion'],
        'absMaxSchemaVersion',
      ),
      minCodecVersion: _asInt(json['minCodecVersion'], 'minCodecVersion'),
      absMaxCodecVersion: _asInt(
        json['absMaxCodecVersion'],
        'absMaxCodecVersion',
      ),
      absMaxLevel: _asInt(json['absMaxLevel'], 'absMaxLevel'),
      absMaxGold: _asInt(json['absMaxGold'], 'absMaxGold'),
      absMaxShards: _asInt(json['absMaxShards'], 'absMaxShards'),
      absMaxRank: _asInt(json['absMaxRank'], 'absMaxRank'),
      absMaxLifetimeClears: _asInt(
        json['absMaxLifetimeClears'],
        'absMaxLifetimeClears',
      ),
      absMaxDailyQuests: _asInt(json['absMaxDailyQuests'], 'absMaxDailyQuests'),
      absMaxWeeklyQuests: _asInt(
        json['absMaxWeeklyQuests'],
        'absMaxWeeklyQuests',
      ),
      absMaxEventPurchases: _asInt(
        json['absMaxEventPurchases'],
        'absMaxEventPurchases',
      ),
      absMaxEquipmentCount: _asInt(
        json['absMaxEquipmentCount'],
        'absMaxEquipmentCount',
      ),
      minRunSeconds: _asInt(json['minRunSeconds'], 'minRunSeconds'),
      minCycleSeconds: _asInt(json['minCycleSeconds'], 'minCycleSeconds'),
      goldBase: _asInt(json['goldBase'], 'goldBase'),
      expBase: _asInt(json['expBase'], 'expBase'),
      expExponent: _asDouble(json['expExponent'], 'expExponent'),
      goldCurveA: _asDouble(goldCurve['a'], 'goldPerSecCurve.a'),
      goldCurveB: _asDouble(goldCurve['b'], 'goldPerSecCurve.b'),
      goldCurveC: _asDouble(goldCurve['c'], 'goldPerSecCurve.c'),
      expCurveA: _asDouble(expCurve['a'], 'expPerSecCurve.a'),
      expCurveB: _asDouble(expCurve['b'], 'expPerSecCurve.b'),
      expCurveC: _asDouble(expCurve['c'], 'expPerSecCurve.c'),
    );
  }

  final double safetyFactor;
  final int graceSeconds;
  final int dailyShard;
  final int weeklyShard;
  final int spireMaxShards;
  final int maxBlobBytes;
  final int minSchemaVersion;
  final int absMaxSchemaVersion;
  final int minCodecVersion;
  final int absMaxCodecVersion;
  final int absMaxLevel;
  final int absMaxGold;
  final int absMaxShards;
  final int absMaxRank;
  final int absMaxLifetimeClears;
  final int absMaxDailyQuests;
  final int absMaxWeeklyQuests;
  final int absMaxEventPurchases;
  final int absMaxEquipmentCount;
  final int minRunSeconds;
  final int minCycleSeconds;
  final int goldBase;
  final int expBase;
  final double expExponent;
  final double goldCurveA;
  final double goldCurveB;
  final double goldCurveC;
  final double expCurveA;
  final double expCurveB;
  final double expCurveC;

  double goldPerSec(int rank) {
    final safeRank = rank < 0 ? 0 : rank;
    return goldCurveA *
        math.pow(1.0 + goldCurveB * safeRank, goldCurveC).toDouble();
  }

  double expPerSec(int rank) {
    final safeRank = rank < 0 ? 0 : rank;
    return expCurveA *
        math.pow(1.0 + expCurveB * safeRank, expCurveC).toDouble();
  }

  static int _asInt(Object? raw, String field) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    throw FormatException('Expected int for CloudLimitsSpec.$field');
  }

  static double _asDouble(Object? raw, String field) {
    if (raw is num) return raw.toDouble();
    throw FormatException('Expected double for CloudLimitsSpec.$field');
  }
}
