import 'dart:math' as math;

import '../entities/equipment.dart';
import '../entities/event_shop_config.dart';
import '../entities/inventory.dart';
import '../entities/item_definition.dart';
import '../entities/shop_config.dart';
import 'currency_service.dart';
import 'equipment_factory.dart';
import 'event_rotation.dart';
import 'period_service.dart';
import 'requirement_evaluator.dart';

/// Hasil sealed pembelian dari Weekly Event Shop (`EventShopService.buy`).
sealed class EventShopBuyResult {
  const EventShopBuyResult();
}

final class EventShopBuySuccess extends EventShopBuyResult {
  const EventShopBuySuccess({
    required this.currencyId,
    required this.currencySpent,
    required this.remainingBalance,
    required this.newPurchaseCount,
    required this.itemId,
    required this.periodKey,
    this.purchasedEquipment,
    this.wasDuplicate = false,
  });

  final String currencyId;
  final int currencySpent;
  final int remainingBalance;
  final int newPurchaseCount;
  final String itemId;
  final String periodKey;
  final EquipmentInstance? purchasedEquipment;
  final bool wasDuplicate;
}

final class EventShopBuyInsufficientCurrency extends EventShopBuyResult {
  const EventShopBuyInsufficientCurrency({
    required this.currencyId,
    required this.requiredAmount,
    required this.currentBalance,
  });

  final String currencyId;
  final int requiredAmount;
  final int currentBalance;
}

final class EventShopBuyRequirementNotMet extends EventShopBuyResult {
  const EventShopBuyRequirementNotMet({required this.failedRequirements});

  final List<PurchaseRequirement> failedRequirements;
}

final class EventShopBuyInventoryFull extends EventShopBuyResult {
  const EventShopBuyInventoryFull();
}

final class EventShopBuyLimitReached extends EventShopBuyResult {
  const EventShopBuyLimitReached({
    required this.limit,
    required this.purchasedCount,
    required this.periodKey,
  });

  final int limit;
  final int purchasedCount;
  final String periodKey;
}

final class EventShopBuyNotInRotation extends EventShopBuyResult {
  const EventShopBuyNotInRotation({
    required this.entryId,
    required this.periodKey,
  });

  final String entryId;
  final String periodKey;
}

final class EventShopBuyNotFound extends EventShopBuyResult {
  const EventShopBuyNotFound({required this.entryId});

  final String entryId;
}

/// Data tampilan read-only untuk satu entri aktif Event Shop minggu ini.
/// Seluruh keputusan harga/requirement/batas sudah dievaluasi di domain.
class EventShopOfferView {
  const EventShopOfferView({
    required this.entry,
    required this.item,
    required this.purchasedCount,
    required this.weeklyLimit,
    required this.requirementCheck,
    required this.canAfford,
    required this.hasInventorySpace,
  });

  final EventShopEntry entry;
  final ItemDefinition item;
  final int purchasedCount;
  final int weeklyLimit;
  final RequirementCheck requirementCheck;
  final bool canAfford;
  final bool hasInventorySpace;

  bool get limitReached => purchasedCount >= weeklyLimit;

  bool get requirementsMet => requirementCheck.isMet;

  /// Tombol beli interaktif bila syarat & batas pembelian belum tercapai.
  bool get canAttemptBuy => requirementsMet && !limitReached;
}

/// Snapshot tampilan read-only Weekly Event Shop untuk widget UI.
class EventShopViewData {
  const EventShopViewData({
    required this.currencyId,
    required this.balance,
    required this.periodKey,
    required this.remainingToReset,
    required this.offers,
  });

  final String currencyId;
  final int balance;
  final String periodKey;
  final Duration remainingToReset;
  final List<EventShopOfferView> offers;
}

/// Layanan domain murni untuk Weekly Event Shop (M13 Stage 3):
/// - Menentukan 2 entri aktif minggu ini via [EventRotation] + [PeriodService].
/// - Mengevaluasi syarat pembelian via [RequirementEvaluator].
/// - Memvalidasi seluruh syarat, saldo mata uang (`aether_shard`), ruang tas,
///   rotasi aktif, dan batas pembelian mingguan `(entryId, periodKey)` sebelum
///   melakukan mutasi secara atomik tanpa roll acak (`fixed_stats`).
class EventShopService {
  EventShopService({
    required this.catalog,
    required this.items,
    required this.equipmentFactory,
    this.periodService = const PeriodService(),
    EventRotation? rotation,
  }) : rotation = rotation ?? EventRotation(items: items);

  final EventShopCatalog catalog;
  final Map<String, ItemDefinition> items;
  final EquipmentFactory equipmentFactory;
  final PeriodService periodService;
  final EventRotation rotation;

  final Set<String> _internalProcessedActions = {};

  String periodKeyAt(int effectiveNowMs, {Duration? offset}) =>
      periodService.keyFor(Period.weekly, effectiveNowMs, offset: offset);

  int weekIndexAt(int effectiveNowMs, {Duration? offset}) =>
      periodService.weekIndex(effectiveNowMs, offset: offset);

  int remainingToResetMs(int effectiveNowMs, {Duration? offset}) {
    final nextReset = periodService.nextResetMs(
      Period.weekly,
      effectiveNowMs,
      offset: offset,
    );
    return math.max(0, nextReset - effectiveNowMs);
  }

  /// Daftar entri aktif pada minggu [weekIndex].
  List<EventShopEntry> activeEntriesForWeek(int weekIndex) {
    if (catalog.pool.length < 2 || catalog.pool.length.isOdd) {
      return const [];
    }
    return rotation.entriesForWeek(weekIndex, catalog.pool);
  }

  /// Daftar entri aktif pada waktu efektif [effectiveNowMs].
  List<EventShopEntry> activeEntriesAt(int effectiveNowMs, {Duration? offset}) {
    final weekIdx = weekIndexAt(effectiveNowMs, offset: offset);
    return activeEntriesForWeek(weekIdx);
  }

  RequirementCheck check(EventShopEntry entry, ShopPlayerContext context) =>
      RequirementEvaluator.evaluate(entry.requirements, context);

  /// Mengembalikan `true` jika minggu ini memiliki minimal satu item event yang
  /// belum mencapai batas pembelian mingguan DAN syarat pembeliannya terpenuhi.
  bool hasEligibleUnboughtEntry({
    required int effectiveNowMs,
    required ShopPlayerContext context,
    Map<(String, String), int>? purchaseCounts,
    Duration? offset,
  }) {
    final periodKey = periodKeyAt(effectiveNowMs, offset: offset);
    final entries = activeEntriesAt(effectiveNowMs, offset: offset);
    for (final entry in entries) {
      final count =
          purchaseCounts?[(entry.id, periodKey)] ??
          context.eventPurchasedCountFor(entry.id, periodKey);
      if (count >= catalog.weeklyPurchaseLimit) continue;
      if (check(entry, context).isMet) {
        return true;
      }
    }
    return false;
  }

  /// Membangun data tampilan read-only untuk UI Event Shop tanpa menaruh logika
  /// harga maupun requirement di widget.
  EventShopViewData buildViewData({
    required int effectiveNowMs,
    required ShopPlayerContext context,
    required int currencyBalance,
    required bool hasInventorySpace,
    Map<(String, String), int>? purchaseCounts,
    Duration? offset,
  }) {
    final periodKey = periodKeyAt(effectiveNowMs, offset: offset);
    final entries = activeEntriesAt(effectiveNowMs, offset: offset);
    final offers = <EventShopOfferView>[];
    for (final entry in entries) {
      final itemDef = items[entry.itemId];
      if (itemDef == null) continue;
      final purchased =
          purchaseCounts?[(entry.id, periodKey)] ??
          context.eventPurchasedCountFor(entry.id, periodKey);
      offers.add(
        EventShopOfferView(
          entry: entry,
          item: itemDef,
          purchasedCount: purchased,
          weeklyLimit: catalog.weeklyPurchaseLimit,
          requirementCheck: check(entry, context),
          canAfford: currencyBalance >= entry.price,
          hasInventorySpace: hasInventorySpace,
        ),
      );
    }

    return EventShopViewData(
      currencyId: catalog.currencyId,
      balance: currencyBalance,
      periodKey: periodKey,
      remainingToReset: Duration(
        milliseconds: remainingToResetMs(effectiveNowMs, offset: offset),
      ),
      offers: List<EventShopOfferView>.unmodifiable(offers),
    );
  }

  /// Membeli satu entri Event Shop pada minggu berjalan.
  /// Seluruh kondisi divalidasi terlebih dahulu sebelum mengurangi mata uang,
  /// menambah equipment (`fixed_stats`), atau menambah hitungan pembelian.
  EventShopBuyResult buy({
    required String entryId,
    required int effectiveNowMs,
    required Inventory inventory,
    required CurrencyService currencyService,
    required ShopPlayerContext context,
    math.Random? random,
    Map<(String, String), int>? purchaseCounts,
    Duration? timeZoneOffset,
    String? actionId,
    Set<String>? processedActionIds,
  }) {
    final normalizedActionId = _normalizeActionId(actionId);
    final tracker = processedActionIds ?? _internalProcessedActions;
    final periodKey = periodKeyAt(effectiveNowMs, offset: timeZoneOffset);
    final entry = catalog.byId(entryId);
    final currentPurchases =
        purchaseCounts?[(entryId, periodKey)] ??
        context.eventPurchasedCountFor(entryId, periodKey);

    if (normalizedActionId != null && tracker.contains(normalizedActionId)) {
      return EventShopBuySuccess(
        currencyId: catalog.currencyId,
        currencySpent: 0,
        remainingBalance: currencyService.balance(catalog.currencyId),
        newPurchaseCount: currentPurchases,
        itemId: entry?.itemId ?? entryId,
        periodKey: periodKey,
        wasDuplicate: true,
      );
    }

    if (entry == null) {
      return EventShopBuyNotFound(entryId: entryId);
    }

    final itemDef = items[entry.itemId];
    if (itemDef == null || !itemDef.isEquipment) {
      return EventShopBuyNotFound(entryId: entryId);
    }

    final activeEntries = activeEntriesAt(
      effectiveNowMs,
      offset: timeZoneOffset,
    );
    if (!activeEntries.any((e) => e.id == entry.id)) {
      return EventShopBuyNotInRotation(entryId: entry.id, periodKey: periodKey);
    }

    if (currentPurchases >= catalog.weeklyPurchaseLimit) {
      return EventShopBuyLimitReached(
        limit: catalog.weeklyPurchaseLimit,
        purchasedCount: currentPurchases,
        periodKey: periodKey,
      );
    }

    final reqCheck = check(entry, context);
    if (!reqCheck.isMet) {
      return EventShopBuyRequirementNotMet(
        failedRequirements: reqCheck.failedRequirements,
      );
    }

    final currentBalance = currencyService.balance(catalog.currencyId);
    if (currentBalance < entry.price) {
      return EventShopBuyInsufficientCurrency(
        currencyId: catalog.currencyId,
        requiredAmount: entry.price,
        currentBalance: currentBalance,
      );
    }

    if (!inventory.hasEquipmentSpace) {
      return const EventShopBuyInventoryFull();
    }

    // Seluruh validasi lolos -> mutasi atomik shard + equipment + counter.
    final prevBalances = currencyService.toSnapshot();
    final prevClaims = currencyService.claimedIds;
    final spendResult = currencyService.spend(catalog.currencyId, entry.price);
    if (!spendResult.isSuccess) {
      return EventShopBuyInsufficientCurrency(
        currencyId: catalog.currencyId,
        requiredAmount: entry.price,
        currentBalance: currencyService.balance(catalog.currencyId),
      );
    }

    final candidate = equipmentFactory.create(
      instanceId: inventory.nextEquipmentId(),
      definition: itemDef,
      random: random ?? math.Random(0),
    );
    final added = inventory.addEquipment(candidate);
    if (!added) {
      currencyService.restoreState(
        balances: prevBalances,
        claimedIds: prevClaims,
      );
      return const EventShopBuyInventoryFull();
    }

    final nextPurchaseCount = currentPurchases + 1;
    if (purchaseCounts != null) {
      purchaseCounts[(entry.id, periodKey)] = nextPurchaseCount;
    }
    if (normalizedActionId != null) {
      tracker.add(normalizedActionId);
    }

    return EventShopBuySuccess(
      currencyId: catalog.currencyId,
      currencySpent: entry.price,
      remainingBalance: currencyService.balance(catalog.currencyId),
      newPurchaseCount: nextPurchaseCount,
      itemId: itemDef.id,
      periodKey: periodKey,
      purchasedEquipment: candidate,
    );
  }

  String? _normalizeActionId(String? actionId) {
    final trimmed = actionId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
