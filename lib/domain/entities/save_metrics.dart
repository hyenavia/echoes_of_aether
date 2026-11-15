/// Ringkasan metrik progres & metadata blob untuk dokumen cloud Firestore.
///
/// Nilai-nilai ini dihitung deterministik di klien dari [PlayerSaveSnapshot]
/// dan blob terkompresi agar Firestore Security Rules (Spark tier) dan dialog
/// pemulihan dapat memeriksa integritas serta membandingkan progres tanpa
/// mengunduh atau membongkar seluruh blob terlebih dahulu.
class SaveMetrics {
  const SaveMetrics({
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
    required this.schemaVersion,
    required this.codecVersion,
  });

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
  final int schemaVersion;
  final int codecVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveMetrics &&
          level == other.level &&
          gold == other.gold &&
          shards == other.shards &&
          highestAscensionRank == other.highestAscensionRank &&
          lifetimeClears == other.lifetimeClears &&
          dailyQuestDone == other.dailyQuestDone &&
          weeklyQuestDone == other.weeklyQuestDone &&
          eventPurchasesLifetime == other.eventPurchasesLifetime &&
          equipmentCount == other.equipmentCount &&
          blobBytes == other.blobBytes &&
          blobSha256 == other.blobSha256 &&
          schemaVersion == other.schemaVersion &&
          codecVersion == other.codecVersion;

  @override
  int get hashCode => Object.hash(
    level,
    gold,
    shards,
    highestAscensionRank,
    lifetimeClears,
    dailyQuestDone,
    weeklyQuestDone,
    eventPurchasesLifetime,
    equipmentCount,
    blobBytes,
    blobSha256,
    schemaVersion,
    codecVersion,
  );
}
