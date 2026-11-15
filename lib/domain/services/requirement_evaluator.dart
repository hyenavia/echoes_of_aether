import 'dart:math' as math;

import '../entities/cycle_progress.dart';
import '../entities/player_save_snapshot.dart';
import '../entities/shop_config.dart';

/// Konteks pemain yang dipakai [ShopService] dan [EventShopService] untuk
/// mengevaluasi syarat pembelian dan batas pembelian tanpa bergantung pada UI.
class ShopPlayerContext {
  const ShopPlayerContext({
    required this.playerLevel,
    this.cycleProgress = const CycleProgress(),
    this.dungeonProgresses = const {},
    this.shopPurchases = const {},
    this.eventShopPurchases = const {},
  });

  final int playerLevel;
  final CycleProgress cycleProgress;
  final Map<String, DungeonProgressSnapshot> dungeonProgresses;
  final Map<String, int> shopPurchases;
  final Map<(String, String), int> eventShopPurchases;

  int get effectiveAscensionRank =>
      math.max(cycleProgress.ascensionRank, cycleProgress.highestAscensionRank);

  bool hasClearedDungeonLifetime(String dungeonId) =>
      (dungeonProgresses[dungeonId]?.clearsCount ?? 0) > 0;

  int purchasedCountFor(String entryId) =>
      math.max(0, shopPurchases[entryId] ?? 0);

  int eventPurchasedCountFor(String entryId, String periodKey) =>
      math.max(0, eventShopPurchases[(entryId, periodKey)] ?? 0);
}

/// Hasil evaluasi seluruh [PurchaseRequirement] pada suatu entri shop.
class RequirementCheck {
  const RequirementCheck({required this.failedRequirements});

  final List<PurchaseRequirement> failedRequirements;

  bool get isMet => failedRequirements.isEmpty;
}

/// Evaluator murni untuk syarat pembelian [PurchaseRequirement] yang dipakai
/// bersama oleh Shop gold biasa dan Weekly Event Shop.
class RequirementEvaluator {
  const RequirementEvaluator();

  static RequirementCheck evaluate(
    List<PurchaseRequirement> requirements,
    ShopPlayerContext context,
  ) {
    final failed = <PurchaseRequirement>[];
    for (final req in requirements) {
      switch (req) {
        case MinLevelRequirement(:final minLevel):
          if (context.playerLevel < minLevel) {
            failed.add(req);
          }
        case DungeonClearedRequirement(:final dungeonId):
          if (!context.hasClearedDungeonLifetime(dungeonId)) {
            failed.add(req);
          }
        case MinAscensionRankRequirement(:final minRank):
          if (context.effectiveAscensionRank < minRank) {
            failed.add(req);
          }
      }
    }
    return RequirementCheck(failedRequirements: List.unmodifiable(failed));
  }

  RequirementCheck call(
    List<PurchaseRequirement> requirements,
    ShopPlayerContext context,
  ) => evaluate(requirements, context);
}
