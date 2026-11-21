import 'dart:math' as math;

import '../entities/cloud_limits_spec.dart';
import '../entities/generated_cloud_limits.dart';
import '../entities/save_metrics.dart';
import '../repositories/cloud_save_repository.dart';

/// Kandidat metadata + metrik dokumen slot cloud untuk pemeriksaan [CloudLimits]
/// sebelum unggah maupun saat memverifikasi vektor uji.
class CloudSaveCandidate {
  const CloudSaveCandidate({
    required this.revision,
    required this.schemaVersion,
    required this.codecVersion,
    required this.deviceId,
    required this.appVersion,
    required this.level,
    required this.gold,
    required this.shards,
    required this.highestAscensionRank,
    required this.lifetimeClears,
    required this.dailyQuestDone,
    required this.weeklyQuestDone,
    required this.eventPurchasesLifetime,
    required this.equipmentCount,
    required this.blobBytes,
    required this.blobSha256,
    int? actualBlobLength,
    String? targetSlot,
    this.schemaErrors = const <String>[],
  }) : actualBlobLength = actualBlobLength ?? blobBytes,
       targetSlot = targetSlot ?? '';

  factory CloudSaveCandidate.fromMeta(
    CloudSaveMeta meta, {
    int? actualBlobLength,
    String? targetSlot,
  }) {
    return CloudSaveCandidate(
      revision: meta.revision,
      schemaVersion: meta.metrics.schemaVersion,
      codecVersion: meta.metrics.codecVersion,
      deviceId: meta.deviceId,
      appVersion: meta.appVersion,
      level: meta.metrics.level,
      gold: meta.metrics.gold,
      shards: meta.metrics.shards,
      highestAscensionRank: meta.metrics.highestAscensionRank,
      lifetimeClears: meta.metrics.lifetimeClears,
      dailyQuestDone: meta.metrics.dailyQuestDone,
      weeklyQuestDone: meta.metrics.weeklyQuestDone,
      eventPurchasesLifetime: meta.metrics.eventPurchasesLifetime,
      equipmentCount: meta.metrics.equipmentCount,
      blobBytes: meta.metrics.blobBytes,
      blobSha256: meta.metrics.blobSha256,
      actualBlobLength: actualBlobLength ?? meta.metrics.blobBytes,
      targetSlot: targetSlot ?? meta.slot.toString(),
    );
  }

  factory CloudSaveCandidate.fromMetrics(
    SaveMetrics metrics, {
    required int revision,
    required String deviceId,
    required String appVersion,
    int? actualBlobLength,
    String? targetSlot,
  }) {
    return CloudSaveCandidate(
      revision: revision,
      schemaVersion: metrics.schemaVersion,
      codecVersion: metrics.codecVersion,
      deviceId: deviceId,
      appVersion: appVersion,
      level: metrics.level,
      gold: metrics.gold,
      shards: metrics.shards,
      highestAscensionRank: metrics.highestAscensionRank,
      lifetimeClears: metrics.lifetimeClears,
      dailyQuestDone: metrics.dailyQuestDone,
      weeklyQuestDone: metrics.weeklyQuestDone,
      eventPurchasesLifetime: metrics.eventPurchasesLifetime,
      equipmentCount: metrics.equipmentCount,
      blobBytes: metrics.blobBytes,
      blobSha256: metrics.blobSha256,
      actualBlobLength: actualBlobLength ?? metrics.blobBytes,
      targetSlot: targetSlot ?? (revision % 2).toString(),
    );
  }

  static const Set<String> expectedSlotFields = <String>{
    'revision',
    'savedAt',
    'schemaVersion',
    'codecVersion',
    'deviceId',
    'appVersion',
    'level',
    'gold',
    'shards',
    'highestAscensionRank',
    'lifetimeClears',
    'dailyQuestDone',
    'weeklyQuestDone',
    'eventPurchasesLifetime',
    'equipmentCount',
    'blobBytes',
    'blobSha256',
    'blob',
  };

  /// Mengurai representasi JSON vektor (`test_vectors.json`), termasuk mencatat
  /// error field tambahan/hilang/tipe salah agar paritas dengan rules terjaga.
  factory CloudSaveCandidate.fromVectorJson(Map<String, Object?> json) {
    final errors = <String>[];
    final targetSlot = json['_targetSlot'] as String?;

    final normalizedKeys = <String>{};
    for (final k in json.keys) {
      if (k == '_targetSlot') continue;
      if (k == 'blobBase64') {
        normalizedKeys.add('blob');
      } else {
        normalizedKeys.add(k);
      }
    }
    normalizedKeys.add(
      'savedAt',
    ); // disuntikkan via serverTimestamp di emulator

    for (final extra in normalizedKeys.difference(expectedSlotFields)) {
      errors.add('Field tidak dikenal: $extra');
    }
    for (final missing in expectedSlotFields.difference(normalizedKeys)) {
      errors.add('Field wajib hilang: $missing');
    }

    int readInt(String key, {int fallback = 0}) {
      final v = json[key];
      if (v is int) return v;
      errors.add('Tipe field "$key" harus int.');
      return fallback;
    }

    String readString(String key, {String fallback = ''}) {
      final v = json[key];
      if (v is String) return v;
      errors.add('Tipe field "$key" harus string.');
      return fallback;
    }

    final blobBytes = readInt('blobBytes');
    var actualBlobLength = blobBytes;
    final rawBlobBase64 = json['blobBase64'];
    if (rawBlobBase64 is String) {
      // Hitung panjang byte dari panjang string base64 tanpa dart:convert
      // ataupun mengandalkan panjang eksplisit saat valid.
      final trimmed = rawBlobBase64.trim();
      var padding = 0;
      if (trimmed.endsWith('==')) {
        padding = 2;
      } else if (trimmed.endsWith('=')) {
        padding = 1;
      }
      if (trimmed.isEmpty) {
        actualBlobLength = 0;
      } else {
        actualBlobLength = ((trimmed.length ~/ 4) * 3) - padding;
      }
    } else if (json.containsKey('blobBase64')) {
      errors.add('Tipe field "blob" harus bytes.');
    }

    final revision = readInt('revision');
    return CloudSaveCandidate(
      revision: revision,
      schemaVersion: readInt('schemaVersion'),
      codecVersion: readInt('codecVersion'),
      deviceId: readString('deviceId'),
      appVersion: readString('appVersion'),
      level: readInt('level'),
      gold: readInt('gold'),
      shards: readInt('shards'),
      highestAscensionRank: readInt('highestAscensionRank'),
      lifetimeClears: readInt('lifetimeClears'),
      dailyQuestDone: readInt('dailyQuestDone'),
      weeklyQuestDone: readInt('weeklyQuestDone'),
      eventPurchasesLifetime: readInt('eventPurchasesLifetime'),
      equipmentCount: readInt('equipmentCount'),
      blobBytes: blobBytes,
      blobSha256: readString('blobSha256'),
      actualBlobLength: actualBlobLength,
      targetSlot:
          targetSlot ?? (revision >= 0 ? (revision % 2).toString() : ''),
      schemaErrors: List<String>.unmodifiable(errors),
    );
  }

  final int revision;
  final int schemaVersion;
  final int codecVersion;
  final String deviceId;
  final String appVersion;
  final int level;
  final int gold;
  final int shards;
  final int highestAscensionRank;
  final int lifetimeClears;
  final int dailyQuestDone;
  final int weeklyQuestDone;
  final int eventPurchasesLifetime;
  final int equipmentCount;
  final int blobBytes;
  final String blobSha256;
  final int actualBlobLength;
  final String targetSlot;
  final List<String> schemaErrors;

  String get resolvedSlot =>
      targetSlot.isNotEmpty ? targetSlot : (revision % 2).toString();
}

/// Rincian satu pelanggaran aturan batas Cloud Sync untuk diagnostik & UI.
class CloudLimitViolation {
  const CloudLimitViolation({
    required this.metric,
    required this.category,
    required this.actual,
    required this.limit,
    required this.message,
  });

  final String metric;
  final String category;
  final Object? actual;
  final Object? limit;
  final String message;

  @override
  String toString() =>
      'CloudLimitViolation($category/$metric: actual=$actual, limit=$limit, $message)';
}

/// Cermin aturan validasi Firestore Security Rules di lapisan domain murni.
class CloudLimits {
  const CloudLimits([this.spec = kGeneratedCloudLimitsSpec]);

  final CloudLimitsSpec spec;

  double goldPerSec(int rank) => spec.goldPerSec(rank);

  double expPerSec(int rank) => spec.expPerSec(rank);

  int maxShardsForQuests(int dailyQuestDone, int weeklyQuestDone) =>
      spec.dailyShard * dailyQuestDone +
      spec.weeklyShard * weeklyQuestDone +
      spec.spireMaxShards;

  int maxDailyQuestDelta(double dtSeconds) {
    final safeDt = dtSeconds < 0 ? 0.0 : dtSeconds;
    return (safeDt / 86400.0).floor() + 2;
  }

  int maxWeeklyQuestDelta(double dtSeconds) {
    final safeDt = dtSeconds < 0 ? 0.0 : dtSeconds;
    return (safeDt / 604800.0).floor() + 2;
  }

  int maxEventPurchasesDelta(double dtSeconds) =>
      2 * maxWeeklyQuestDelta(dtSeconds);

  int maxRankDelta(double dtSeconds) {
    final safeDt = dtSeconds < 0 ? 0.0 : dtSeconds;
    return (safeDt / spec.minCycleSeconds).floor() + 1;
  }

  double maxGoldDelta(int targetRank, double dtSeconds) {
    final effDt = (dtSeconds < 0 ? 0.0 : dtSeconds) + spec.graceSeconds;
    return spec.goldPerSec(targetRank) * effDt * spec.safetyFactor +
        spec.goldBase;
  }

  double maxLevelDelta(int targetRank, int prevLevel, double dtSeconds) {
    final effDt = (dtSeconds < 0 ? 0.0 : dtSeconds) + spec.graceSeconds;
    final expDenom =
        spec.expBase *
        math.pow(math.max(1, prevLevel), spec.expExponent).toDouble();
    return (spec.expPerSec(targetRank) * effDt * spec.safetyFactor) / expDenom +
        1.0;
  }

  double maxLifetimeClearsDelta(double dtSeconds) {
    final effDt = (dtSeconds < 0 ? 0.0 : dtSeconds) + spec.graceSeconds;
    return effDt / spec.minRunSeconds + 1.0;
  }

  bool isAllowed(
    CloudSaveCandidate? prev,
    CloudSaveCandidate next,
    double dtSeconds,
  ) => explainViolation(prev, next, dtSeconds).isEmpty;

  /// Mengevaluasi seluruh aturan mutlak, struktur, monotonik, periodik, dan
  /// kontinu terhadap [next] (dan [prev] bila tersedia).
  List<CloudLimitViolation> explainViolation(
    CloudSaveCandidate? prev,
    CloudSaveCandidate next,
    double dtSeconds,
  ) {
    final violations = <CloudLimitViolation>[];

    for (final err in next.schemaErrors) {
      violations.add(
        CloudLimitViolation(
          metric: 'schema',
          category: 'schema',
          actual: err,
          limit: 'exact 18 typed slot fields',
          message: err,
        ),
      );
    }

    // Mutlak & struktur dasar.
    if (next.revision < 1) {
      violations.add(
        CloudLimitViolation(
          metric: 'revision',
          category: 'structure',
          actual: next.revision,
          limit: '>= 1',
          message: 'Revision harus >= 1.',
        ),
      );
    }
    final expectedSlot = (next.revision % 2).toString();
    if (next.resolvedSlot != expectedSlot ||
        (next.resolvedSlot != '0' && next.resolvedSlot != '1')) {
      violations.add(
        CloudLimitViolation(
          metric: 'slot',
          category: 'structure',
          actual: next.resolvedSlot,
          limit: expectedSlot,
          message:
              'Slot target (${next.resolvedSlot}) harus sama dengan revision % 2 ($expectedSlot).',
        ),
      );
    }

    if (next.deviceId.isEmpty || next.deviceId.length > 128) {
      violations.add(
        CloudLimitViolation(
          metric: 'deviceId',
          category: 'absolute',
          actual: next.deviceId.length,
          limit: '1..128',
          message: 'Panjang deviceId tidak valid.',
        ),
      );
    }
    if (next.appVersion.isEmpty || next.appVersion.length > 64) {
      violations.add(
        CloudLimitViolation(
          metric: 'appVersion',
          category: 'absolute',
          actual: next.appVersion.length,
          limit: '1..64',
          message: 'Panjang appVersion tidak valid.',
        ),
      );
    }
    if (next.schemaVersion < spec.minSchemaVersion ||
        next.schemaVersion > spec.absMaxSchemaVersion) {
      violations.add(
        CloudLimitViolation(
          metric: 'schemaVersion',
          category: 'absolute',
          actual: next.schemaVersion,
          limit: '${spec.minSchemaVersion}..${spec.absMaxSchemaVersion}',
          message: 'schemaVersion di luar rentang yang didukung.',
        ),
      );
    }
    if (next.codecVersion < spec.minCodecVersion ||
        next.codecVersion > spec.absMaxCodecVersion) {
      violations.add(
        CloudLimitViolation(
          metric: 'codecVersion',
          category: 'absolute',
          actual: next.codecVersion,
          limit: '${spec.minCodecVersion}..${spec.absMaxCodecVersion}',
          message: 'codecVersion di luar rentang yang didukung.',
        ),
      );
    }

    _checkIntRange(
      violations,
      metric: 'level',
      value: next.level,
      min: 1,
      max: spec.absMaxLevel,
    );
    _checkIntRange(
      violations,
      metric: 'gold',
      value: next.gold,
      min: 0,
      max: spec.absMaxGold,
    );
    _checkIntRange(
      violations,
      metric: 'shards',
      value: next.shards,
      min: 0,
      max: spec.absMaxShards,
    );
    _checkIntRange(
      violations,
      metric: 'highestAscensionRank',
      value: next.highestAscensionRank,
      min: 0,
      max: spec.absMaxRank,
    );
    _checkIntRange(
      violations,
      metric: 'lifetimeClears',
      value: next.lifetimeClears,
      min: 0,
      max: spec.absMaxLifetimeClears,
    );
    _checkIntRange(
      violations,
      metric: 'dailyQuestDone',
      value: next.dailyQuestDone,
      min: 0,
      max: spec.absMaxDailyQuests,
    );
    _checkIntRange(
      violations,
      metric: 'weeklyQuestDone',
      value: next.weeklyQuestDone,
      min: 0,
      max: spec.absMaxWeeklyQuests,
    );
    _checkIntRange(
      violations,
      metric: 'eventPurchasesLifetime',
      value: next.eventPurchasesLifetime,
      min: 0,
      max: spec.absMaxEventPurchases,
    );
    _checkIntRange(
      violations,
      metric: 'equipmentCount',
      value: next.equipmentCount,
      min: 0,
      max: spec.absMaxEquipmentCount,
    );
    _checkIntRange(
      violations,
      metric: 'blobBytes',
      value: next.blobBytes,
      min: 1,
      max: spec.maxBlobBytes,
    );

    if (next.actualBlobLength != next.blobBytes ||
        next.actualBlobLength > spec.maxBlobBytes) {
      violations.add(
        CloudLimitViolation(
          metric: 'blob',
          category: 'absolute',
          actual: next.actualBlobLength,
          limit: '== blobBytes (${next.blobBytes}) <= ${spec.maxBlobBytes}',
          message:
              'Ukuran blob (${next.actualBlobLength}) tidak cocok dengan blobBytes (${next.blobBytes}) atau melebihi ${spec.maxBlobBytes}.',
        ),
      );
    }
    if (next.blobSha256.length != 64) {
      violations.add(
        CloudLimitViolation(
          metric: 'blobSha256',
          category: 'absolute',
          actual: next.blobSha256.length,
          limit: 64,
          message: 'blobSha256 harus hex 64 karakter.',
        ),
      );
    }

    if (prev == null) {
      if (next.revision != 1) {
        violations.add(
          CloudLimitViolation(
            metric: 'revision',
            category: 'structure',
            actual: next.revision,
            limit: 1,
            message: 'Unggahan pertama tanpa prev wajib revision == 1.',
          ),
        );
      }
      return violations;
    }

    if (next.revision != prev.revision + 1) {
      violations.add(
        CloudLimitViolation(
          metric: 'revision',
          category: 'structure',
          actual: next.revision,
          limit: prev.revision + 1,
          message:
              'Revision (${next.revision}) harus prev.revision + 1 (${prev.revision + 1}).',
        ),
      );
    }

    if (dtSeconds.isNaN || !dtSeconds.isFinite || dtSeconds < 0) {
      violations.add(
        CloudLimitViolation(
          metric: 'dtSeconds',
          category: 'structure',
          actual: dtSeconds,
          limit: '>= 0',
          message: 'Selisih waktu server dt tidak boleh negatif.',
        ),
      );
      return violations;
    }

    // Monotonik tidak turun (kecuali transisi migrasi M16 schemaVersion < 11 -> >= 11).
    final isM16Migration = prev.schemaVersion < 11 && next.schemaVersion >= 11;

    _checkMonotonic(
      violations,
      metric: 'schemaVersion',
      prevVal: prev.schemaVersion,
      nextVal: next.schemaVersion,
    );
    _checkMonotonic(
      violations,
      metric: 'codecVersion',
      prevVal: prev.codecVersion,
      nextVal: next.codecVersion,
    );
    _checkMonotonic(
      violations,
      metric: 'level',
      prevVal: isM16Migration && prev.level > 90
          ? math.min(prev.level, 90)
          : prev.level,
      nextVal: next.level,
    );
    _checkMonotonic(
      violations,
      metric: 'highestAscensionRank',
      prevVal: isM16Migration && prev.highestAscensionRank > 5
          ? math.min(prev.highestAscensionRank, 5)
          : prev.highestAscensionRank,
      nextVal: next.highestAscensionRank,
    );
    _checkMonotonic(
      violations,
      metric: 'lifetimeClears',
      prevVal: prev.lifetimeClears,
      nextVal: next.lifetimeClears,
    );
    _checkMonotonic(
      violations,
      metric: 'dailyQuestDone',
      prevVal: prev.dailyQuestDone,
      nextVal: next.dailyQuestDone,
    );
    _checkMonotonic(
      violations,
      metric: 'weeklyQuestDone',
      prevVal: prev.weeklyQuestDone,
      nextVal: next.weeklyQuestDone,
    );
    _checkMonotonic(
      violations,
      metric: 'eventPurchasesLifetime',
      prevVal: prev.eventPurchasesLifetime,
      nextVal: next.eventPurchasesLifetime,
    );

    // Periodik (eksak).
    final dailyDelta = next.dailyQuestDone - prev.dailyQuestDone;
    final dailyCap = maxDailyQuestDelta(dtSeconds);
    if (dailyDelta > dailyCap) {
      violations.add(
        CloudLimitViolation(
          metric: 'dailyQuestDone',
          category: 'periodic',
          actual: dailyDelta,
          limit: dailyCap,
          message:
              'Pertambahan dailyQuestDone ($dailyDelta) melebihi batas periodik ($dailyCap).',
        ),
      );
    }

    final weeklyDelta = next.weeklyQuestDone - prev.weeklyQuestDone;
    final weeklyCap = maxWeeklyQuestDelta(dtSeconds);
    if (weeklyDelta > weeklyCap) {
      violations.add(
        CloudLimitViolation(
          metric: 'weeklyQuestDone',
          category: 'periodic',
          actual: weeklyDelta,
          limit: weeklyCap,
          message:
              'Pertambahan weeklyQuestDone ($weeklyDelta) melebihi batas periodik ($weeklyCap).',
        ),
      );
    }

    final purchaseDelta =
        next.eventPurchasesLifetime - prev.eventPurchasesLifetime;
    final purchaseCap = maxEventPurchasesDelta(dtSeconds);
    if (purchaseDelta > purchaseCap) {
      violations.add(
        CloudLimitViolation(
          metric: 'eventPurchasesLifetime',
          category: 'periodic',
          actual: purchaseDelta,
          limit: purchaseCap,
          message:
              'Pertambahan eventPurchasesLifetime ($purchaseDelta) melebihi batas periodik ($purchaseCap).',
        ),
      );
    }

    // Kontinu (plafon simulator + safety factor).
    final rankDelta = next.highestAscensionRank - prev.highestAscensionRank;
    final rankCap = maxRankDelta(dtSeconds);
    if (rankDelta > rankCap) {
      violations.add(
        CloudLimitViolation(
          metric: 'highestAscensionRank',
          category: 'continuous',
          actual: rankDelta,
          limit: rankCap,
          message:
              'Kenaikan Ascension rank ($rankDelta) dalam ${dtSeconds.toStringAsFixed(0)}s melebihi batas ($rankCap).',
        ),
      );
    }

    final goldDelta = next.gold - prev.gold;
    final legacyGoldBonus = (isM16Migration && prev.level > 90)
        ? (prev.level - 90) * 5000.0
        : 0.0;
    final goldCap =
        maxGoldDelta(next.highestAscensionRank, dtSeconds) + legacyGoldBonus;
    if (goldDelta > goldCap) {
      violations.add(
        CloudLimitViolation(
          metric: 'gold',
          category: 'continuous',
          actual: goldDelta,
          limit: goldCap,
          message:
              'Kenaikan gold ($goldDelta) melebihi plafon simulator (${goldCap.toStringAsFixed(1)}).',
        ),
      );
    }

    final levelDelta = next.level - prev.level;
    final levelCap = maxLevelDelta(
      next.highestAscensionRank,
      prev.level,
      dtSeconds,
    );
    if (levelDelta > levelCap) {
      violations.add(
        CloudLimitViolation(
          metric: 'level',
          category: 'continuous',
          actual: levelDelta,
          limit: levelCap,
          message:
              'Kenaikan level ($levelDelta) melebihi plafon EXP (${levelCap.toStringAsFixed(2)}).',
        ),
      );
    }

    final clearsDelta = next.lifetimeClears - prev.lifetimeClears;
    final clearsCap = maxLifetimeClearsDelta(dtSeconds);
    if (clearsDelta > clearsCap) {
      violations.add(
        CloudLimitViolation(
          metric: 'lifetimeClears',
          category: 'continuous',
          actual: clearsDelta,
          limit: clearsCap,
          message:
              'Kenaikan lifetimeClears ($clearsDelta) melebihi batas laju run (${clearsCap.toStringAsFixed(1)}).',
        ),
      );
    }

    return violations;
  }

  static void _checkIntRange(
    List<CloudLimitViolation> out, {
    required String metric,
    required int value,
    required int min,
    required int max,
  }) {
    if (value < min || value > max) {
      out.add(
        CloudLimitViolation(
          metric: metric,
          category: 'absolute',
          actual: value,
          limit: '$min..$max',
          message: '$metric ($value) berada di luar rentang $min..$max.',
        ),
      );
    }
  }

  static void _checkMonotonic(
    List<CloudLimitViolation> out, {
    required String metric,
    required int prevVal,
    required int nextVal,
  }) {
    if (nextVal < prevVal) {
      out.add(
        CloudLimitViolation(
          metric: metric,
          category: 'monotonic',
          actual: nextVal,
          limit: '>= $prevVal',
          message: '$metric turun dari $prevVal menjadi $nextVal.',
        ),
      );
    }
  }
}
