import '../entities/game_config.dart';
import '../entities/player_save_snapshot.dart';
import '../entities/save_metrics.dart';
import 'save_snapshot_codec.dart';

/// Penghitung [SaveMetrics] domain murni dari [PlayerSaveSnapshot] dan hasil
/// pengepakan blob.
class SaveMetricsCalculator {
  const SaveMetricsCalculator();

  static const String shardCurrencyId = 'aether_shard';
  static const String defaultDailyQuestId = 'daily_boss';
  static const String defaultWeeklyQuestId = 'weekly_boss';

  SaveMetrics compute({
    required PlayerSaveSnapshot snapshot,
    required GameConfig config,
    required int blobBytes,
    required String blobSha256,
    required int schemaVersion,
    int codecVersion = SaveSnapshotCodec.supportedCodecVersion,
  }) {
    final mergedDungeonProgress = <String, DungeonProgressSnapshot>{
      ...snapshot.dungeonProgresses,
      snapshot.dungeon.currentDungeonId: snapshot.dungeon,
    };
    var lifetimeClears = 0;
    for (final entry in mergedDungeonProgress.values) {
      lifetimeClears += entry.clearsCount;
    }

    final dailyQuestId =
        config.bossEvents?.daily.questId ?? defaultDailyQuestId;
    final weeklyQuestId =
        config.bossEvents?.weekly.questId ?? defaultWeeklyQuestId;

    final dailyPeriods = <String>{};
    final weeklyPeriods = <String>{};
    for (final quest in snapshot.periodicQuestStates) {
      if (quest.questId == dailyQuestId) {
        dailyPeriods.add(quest.periodKey);
      } else if (quest.questId == weeklyQuestId) {
        weeklyPeriods.add(quest.periodKey);
      }
    }

    var eventPurchasesLifetime = 0;
    for (final purchase in snapshot.eventShopPurchases) {
      eventPurchasesLifetime += purchase.purchasedCount;
    }

    return SaveMetrics(
      level: snapshot.character.progress.level,
      gold: snapshot.character.progress.gold,
      shards: snapshot.currencies[shardCurrencyId] ?? 0,
      highestAscensionRank: snapshot.cycleProgress.highestAscensionRank,
      lifetimeClears: lifetimeClears,
      dailyQuestDone: dailyPeriods.length,
      weeklyQuestDone: weeklyPeriods.length,
      eventPurchasesLifetime: eventPurchasesLifetime,
      equipmentCount:
          snapshot.inventory.equipment.length +
          snapshot.character.equipped.length,
      blobBytes: blobBytes,
      blobSha256: blobSha256,
      schemaVersion: schemaVersion,
      codecVersion: codecVersion,
    );
  }
}
