import 'dart:math' as math;

import '../entities/equipment.dart';
import '../entities/gacha_config.dart';
import '../entities/item_definition.dart';
import '../entities/player_save_snapshot.dart';
import '../entities/specialization.dart';
import 'bag_expansion_service.dart';
import 'equipment_factory.dart';
import 'period_service.dart';

/// Status hasil penarikan gacha.
enum GachaPullStatus {
  success,
  insufficientAetherShards,
  inventoryFull,
  bannerNotFound,
  invalidCount,
}

/// Hasil dari satu sesi penarikan gacha (1x atau 10x pull).
class GachaPullSessionResult {
  const GachaPullSessionResult({
    required this.status,
    required this.bannerType,
    this.pulls = const [],
    this.updatedSnapshot,
    this.shardsSpent = 0,
    this.remainingShards = 0,
    this.soulPrismGranted = 0,
    this.remainingSoulPrism = 0,
    this.newEquipmentGranted = const [],
    this.newClassesUnlocked = const {},
    this.updatedPityState,
    this.errorMessage,
  });

  final GachaPullStatus status;
  final GachaBannerType bannerType;
  final List<GachaPullResult> pulls;
  final PlayerSaveSnapshot? updatedSnapshot;
  final int shardsSpent;
  final int remainingShards;
  final int soulPrismGranted;
  final int remainingSoulPrism;
  final List<EquipmentInstance> newEquipmentGranted;
  final Set<String> newClassesUnlocked;
  final GachaPityState? updatedPityState;
  final String? errorMessage;

  bool get isSuccess => status == GachaPullStatus.success;
}

/// Status hasil penukaran di Toko Sanctuary.
enum SanctuaryExchangeStatus {
  success,
  insufficientSoulPrisms,
  invalidTarget,
  alreadyOwned,
  inventoryFull,
}

/// Hasil operasi pertukaran Soul Prism di Toko Sanctuary.
class SanctuaryExchangeResult {
  const SanctuaryExchangeResult({
    required this.status,
    this.updatedSnapshot,
    this.soulPrismSpent = 0,
    this.remainingSoulPrism = 0,
    this.grantedEquipment,
    this.unlockedClassId,
    this.errorMessage,
  });

  final SanctuaryExchangeStatus status;
  final PlayerSaveSnapshot? updatedSnapshot;
  final int soulPrismSpent;
  final int remainingSoulPrism;
  final EquipmentInstance? grantedEquipment;
  final String? unlockedClassId;
  final String? errorMessage;

  bool get isSuccess => status == SanctuaryExchangeStatus.success;
}

/// Informasi banner aktif saat ini berdasarkan siklus waktu 21 hari.
class GachaActiveBannerInfo {
  const GachaActiveBannerInfo({
    required this.banner,
    required this.bannerType,
    required this.cycleIndex,
    required this.featuredId,
    required this.standardPool,
    required this.nextResetMs,
    required this.pityState,
  });

  final GachaBannerDefinition banner;
  final GachaBannerType bannerType;
  final int cycleIndex;
  final String featuredId;
  final List<String> standardPool;
  final int nextResetMs;
  final GachaPityState pityState;

  int remainingSeconds(int nowMs) =>
      math.max(0, (nextResetMs - nowMs) ~/ 1000);
}

/// Service domain murni untuk mengelola seluruh ekosistem Gacha:
/// 1. Perhitungan banner aktif berdasarkan siklus waktu 21 hari (rotasi terpusat).
/// 2. Roll deterministik: Rate-Up 50/50, Hard Pity independen (Class: 40, Weapon: 30),
///    dan Pity Carryover.
/// 3. Konversi duplikasi Class Mythical menjadi 1x Soul Prism secara otomatis.
/// 4. Toko Sanctuary permanen (2 Soul Prism -> Senjata Mythical, 3 Soul Prism -> Class Mythical).
class GachaService {
  const GachaService({
    required this.gachaConfig,
    required this.items,
    required this.specializations,
    required this.equipmentFactory,
    required this.periodService,
    this.bagExpansionService = const BagExpansionService(),
  });

  final GachaConfig gachaConfig;
  final Map<String, ItemDefinition> items;
  final Map<String, SpecializationDefinition> specializations;
  final EquipmentFactory equipmentFactory;
  final PeriodService periodService;
  final BagExpansionService bagExpansionService;

  static const List<String> fourStarConsolationPool = [
    'aether_blade',
    'windforce_bow',
    'cosmic_staff',
    'aether_helm',
    'aether_armor',
    'aether_ring',
    'aether_sigil',
    'ancient_fragment',
  ];

  static const List<String> threeStarConsolationPool = [
    'rusty_sword',
    'hunters_bow',
    'apprentice_staff',
    'leather_cap',
    'padded_vest',
    'copper_ring',
    'small_potion',
    'slime_gel',
    'forest_herb',
    'wolf_fang',
    'corrupted_bark',
  ];

  /// Menghitung indeks siklus rotasi 21-hari dari waktu [nowMs].
  int getCycleIndex(int nowMs, {Duration? offset}) {
    final days = periodService.dayIndex(nowMs, offset: offset);
    final cycleDays = gachaConfig.cycleDays;
    return days >= 0 ? days ~/ cycleDays : ((days + 1) ~/ cycleDays) - 1;
  }

  /// Menghitung waktu reset siklus berikutnya dalam epoch ms.
  int getNextResetMs(int nowMs, {Duration? offset}) {
    final tz = _resolveOffset(nowMs, offset: offset);
    final cycleIndex = getCycleIndex(nowMs, offset: offset);
    final nextIndex = cycleIndex + 1;
    final epochUtc = periodService.config.tryParseEpochMondayUtc() ??
        DateTime.utc(2026, 11, 16);
    final nextCycleMondayUtc =
        epochUtc.add(Duration(days: nextIndex * gachaConfig.cycleDays));
    final nextWallUtc = DateTime.utc(
      nextCycleMondayUtc.year,
      nextCycleMondayUtc.month,
      nextCycleMondayUtc.day,
      periodService.config.resetHour,
    );
    return nextWallUtc.millisecondsSinceEpoch - tz.inMilliseconds;
  }

  Duration _resolveOffset(int nowMs, {Duration? offset}) {
    if (offset != null) return offset;
    final injected = periodService.timeZoneOffset?.call();
    if (injected != null) return injected;
    return DateTime.fromMillisecondsSinceEpoch(nowMs).timeZoneOffset;
  }

  /// Mengambil informasi lengkap banner aktif untuk [bannerType] pada [nowMs].
  GachaActiveBannerInfo getActiveBannerInfo({
    required GachaBannerType bannerType,
    required int nowMs,
    Map<String, GachaPityState>? pityStates,
    Duration? offset,
  }) {
    final banner = gachaConfig.bannerByType(bannerType);
    if (banner == null) {
      throw StateError('Banner untuk tipe $bannerType tidak terdaftar.');
    }

    final cycleIndex = getCycleIndex(nowMs, offset: offset);
    final poolLen = banner.featuredPool.length;
    final featuredIndex =
        poolLen > 0 ? ((cycleIndex % poolLen) + poolLen) % poolLen : 0;
    final featuredId =
        poolLen > 0 ? banner.featuredPool[featuredIndex] : '';
    final standardPool =
        banner.standardPool.where((id) => id != featuredId).toList();
    final nextReset = getNextResetMs(nowMs, offset: offset);
    final pity = pityStates?[bannerType.idString] ??
        GachaPityState(bannerType: bannerType.idString);

    return GachaActiveBannerInfo(
      banner: banner,
      bannerType: bannerType,
      cycleIndex: cycleIndex,
      featuredId: featuredId,
      standardPool: standardPool,
      nextResetMs: nextReset,
      pityState: pity,
    );
  }

  /// Melakukan penarikan gacha 1x (30 Aether Shard).
  GachaPullSessionResult pullOnce({
    required PlayerSaveSnapshot snapshot,
    required GachaBannerType bannerType,
    required int nowMs,
    required math.Random random,
    Duration? offset,
  }) {
    return pull(
      snapshot: snapshot,
      bannerType: bannerType,
      nowMs: nowMs,
      random: random,
      count: 1,
      offset: offset,
    );
  }

  /// Melakukan penarikan gacha 10x (300 Aether Shard).
  GachaPullSessionResult pullTen({
    required PlayerSaveSnapshot snapshot,
    required GachaBannerType bannerType,
    required int nowMs,
    required math.Random random,
    Duration? offset,
  }) {
    return pull(
      snapshot: snapshot,
      bannerType: bannerType,
      nowMs: nowMs,
      random: random,
      count: 10,
      offset: offset,
    );
  }

  /// Melakukan penarikan gacha sebanyak [count] kali (1 atau 10).
  GachaPullSessionResult pull({
    required PlayerSaveSnapshot snapshot,
    required GachaBannerType bannerType,
    required int nowMs,
    required math.Random random,
    int count = 1,
    Duration? offset,
  }) {
    if (count != 1 && count != 10) {
      return GachaPullSessionResult(
        status: GachaPullStatus.invalidCount,
        bannerType: bannerType,
        errorMessage: 'Jumlah pull harus 1 atau 10 (diberikan $count).',
      );
    }

    final banner = gachaConfig.bannerByType(bannerType);
    if (banner == null) {
      return GachaPullSessionResult(
        status: GachaPullStatus.bannerNotFound,
        bannerType: bannerType,
        errorMessage: 'Banner tipe "${bannerType.idString}" tidak ditemukan.',
      );
    }

    final cost = count == 10
        ? gachaConfig.costPerTenPull
        : (gachaConfig.costPerPull * count);
    final currentShards = snapshot.currencies[gachaConfig.currencyId] ?? 0;
    if (currentShards < cost) {
      return GachaPullSessionResult(
        status: GachaPullStatus.insufficientAetherShards,
        bannerType: bannerType,
        shardsSpent: 0,
        remainingShards: currentShards,
        errorMessage:
            'Aether Shard tidak mencukupi (dibutuhkan $cost, saldo: $currentShards).',
      );
    }

    // Periksa ruang tas jika tarikan berpotensi menghasilkan item perlengkapan
    final bagLevel = bagExpansionService.getLevel(snapshot.currencies);
    final bagCapacity = BagExpansionService.baseCapacity +
        (BagExpansionService.slotsPerLevel * bagLevel);
    final currentEquipCount = snapshot.inventory.equipment.length;
    if (currentEquipCount + count > bagCapacity) {
      return GachaPullSessionResult(
        status: GachaPullStatus.inventoryFull,
        bannerType: bannerType,
        shardsSpent: 0,
        remainingShards: currentShards,
        errorMessage:
            'Tas perlengkapan tidak memiliki cukup slot kosong (butuh $count slot).',
      );
    }

    final activeInfo = getActiveBannerInfo(
      bannerType: bannerType,
      nowMs: nowMs,
      pityStates: snapshot.gachaPityStates,
      offset: offset,
    );

    var currentPullCount = activeInfo.pityState.pullCount;
    var isGuaranteed = activeInfo.pityState.isGuaranteed;
    final unlockedSpecs = Set<String>.from(snapshot.unlockedSpecializations);
    var totalSoulPrismsGranted = 0;

    final pulls = <GachaPullResult>[];
    final newEquipment = <EquipmentInstance>[];
    final newClasses = <String>{};
    final updatedStacks = Map<String, int>.from(snapshot.inventory.stacks);
    final updatedEquipment =
        List<EquipmentInstance>.from(snapshot.inventory.equipment);
    var eqCounter = snapshot.inventory.equipmentCounter;

    for (var i = 0; i < count; i++) {
      currentPullCount++;

      final isHardPity = currentPullCount >= banner.hardPity;
      final isLuckyRoll = random.nextDouble() < banner.baseRate;
      final is5Star = isHardPity || isLuckyRoll;

      if (is5Star) {
        currentPullCount = 0;
        final bool isFeatured;
        final String rolledId;

        if (isGuaranteed) {
          isFeatured = true;
          isGuaranteed = false;
          rolledId = activeInfo.featuredId;
        } else {
          final won5050 = random.nextDouble() < banner.rateUpShare;
          if (won5050) {
            isFeatured = true;
            isGuaranteed = false;
            rolledId = activeInfo.featuredId;
          } else {
            isFeatured = false;
            isGuaranteed = true;
            final candidates = activeInfo.standardPool;
            rolledId = candidates.isNotEmpty
                ? candidates[random.nextInt(candidates.length)]
                : activeInfo.featuredId;
          }
        }

        if (bannerType == GachaBannerType.classBanner) {
          final isDuplicate = unlockedSpecs.contains(rolledId);
          if (isDuplicate) {
            final granted = gachaConfig.duplicateGrantedAmount;
            totalSoulPrismsGranted += granted;
            pulls.add(
              GachaPullResult(
                itemId: rolledId,
                bannerType: bannerType,
                isSpecialization: true,
                isMythical: true,
                isFeatured: isFeatured,
                isDuplicate: true,
                soulPrismGranted: granted,
              ),
            );
          } else {
            unlockedSpecs.add(rolledId);
            newClasses.add(rolledId);
            pulls.add(
              GachaPullResult(
                itemId: rolledId,
                bannerType: bannerType,
                isSpecialization: true,
                isMythical: true,
                isFeatured: isFeatured,
                isDuplicate: false,
                soulPrismGranted: 0,
              ),
            );
          }
        } else if (bannerType == GachaBannerType.weaponBanner) {
          final def = items[rolledId];
          if (def == null || !def.isEquipment) {
            throw StateError('Item senjata gacha "$rolledId" tidak valid.');
          }
          final inst = equipmentFactory.create(
            instanceId: 'eq_${++eqCounter}',
            definition: def,
            random: random,
          );
          updatedEquipment.add(inst);
          newEquipment.add(inst);
          pulls.add(
            GachaPullResult(
              itemId: rolledId,
              bannerType: bannerType,
              isSpecialization: false,
              isMythical: true,
              isFeatured: isFeatured,
              isDuplicate: false,
              soulPrismGranted: 0,
            ),
          );
        }
      } else {
        // Hadiah konsolasi non-5★ (4★ ~10%, 3★ ~90%)
        final is4Star = random.nextDouble() < 0.10;
        final pool = is4Star
            ? fourStarConsolationPool
            : threeStarConsolationPool;
        final cId = pool[random.nextInt(pool.length)];
        final def = items[cId];

        if (def != null && def.isEquipment) {
          final inst = equipmentFactory.create(
            instanceId: 'eq_${++eqCounter}',
            definition: def,
            random: random,
          );
          updatedEquipment.add(inst);
          newEquipment.add(inst);
        } else if (def != null) {
          final currentQty = updatedStacks[cId] ?? 0;
          updatedStacks[cId] = math.min(currentQty + 1, def.maxStack);
        }

        pulls.add(
          GachaPullResult(
            itemId: cId,
            bannerType: bannerType,
            isSpecialization: false,
            isMythical: false,
            isFeatured: false,
            isDuplicate: false,
            soulPrismGranted: 0,
          ),
        );
      }
    }

    final remainingShards = currentShards - cost;
    final currentPrism =
        snapshot.currencies[gachaConfig.duplicateCurrencyId] ?? 0;
    final remainingSoulPrism = currentPrism + totalSoulPrismsGranted;

    final newCurrencies = Map<String, int>.from(snapshot.currencies);
    newCurrencies[gachaConfig.currencyId] = remainingShards;
    if (remainingSoulPrism > 0) {
      newCurrencies[gachaConfig.duplicateCurrencyId] = remainingSoulPrism;
    }

    final newPityState = GachaPityState(
      bannerType: bannerType.idString,
      pullCount: currentPullCount,
      isGuaranteed: isGuaranteed,
    );
    final newPityStates =
        Map<String, GachaPityState>.from(snapshot.gachaPityStates);
    newPityStates[bannerType.idString] = newPityState;

    final updatedSnapshot = snapshot.copyWith(
      inventory: InventorySnapshot(
        stacks: updatedStacks,
        equipment: updatedEquipment,
        equipmentCounter: eqCounter,
      ),
      currencies: newCurrencies,
      gachaPityStates: newPityStates,
      unlockedSpecializations: unlockedSpecs,
    );

    return GachaPullSessionResult(
      status: GachaPullStatus.success,
      bannerType: bannerType,
      pulls: pulls,
      updatedSnapshot: updatedSnapshot,
      shardsSpent: cost,
      remainingShards: remainingShards,
      soulPrismGranted: totalSoulPrismsGranted,
      remainingSoulPrism: remainingSoulPrism,
      newEquipmentGranted: newEquipment,
      newClassesUnlocked: newClasses,
      updatedPityState: newPityState,
    );
  }

  /// Melakukan penukaran Soul Prism untuk 1 Senjata Mythical pilihan di Toko Sanctuary (Biaya: 2).
  SanctuaryExchangeResult exchangeSanctuaryWeapon({
    required PlayerSaveSnapshot snapshot,
    required String weaponId,
    required math.Random random,
  }) {
    final exchange = gachaConfig.sanctuaryExchange;
    final cost = exchange.weaponCost;
    final currentPrism = snapshot.currencies[exchange.currencyId] ?? 0;
    if (currentPrism < cost) {
      return SanctuaryExchangeResult(
        status: SanctuaryExchangeStatus.insufficientSoulPrisms,
        soulPrismSpent: 0,
        remainingSoulPrism: currentPrism,
        errorMessage:
            'Soul Prism tidak mencukupi (dibutuhkan $cost, saldo: $currentPrism).',
      );
    }

    final item = items[weaponId];
    if (item == null ||
        item.rarity != ItemRarity.mythical ||
        !item.isEquipment) {
      return SanctuaryExchangeResult(
        status: SanctuaryExchangeStatus.invalidTarget,
        soulPrismSpent: 0,
        remainingSoulPrism: currentPrism,
        errorMessage:
            'Item "$weaponId" bukan merupakan Senjata Mythical yang valid.',
      );
    }

    final bagLevel = bagExpansionService.getLevel(snapshot.currencies);
    final capacity = BagExpansionService.baseCapacity +
        (BagExpansionService.slotsPerLevel * bagLevel);
    if (snapshot.inventory.equipment.length >= capacity) {
      return SanctuaryExchangeResult(
        status: SanctuaryExchangeStatus.inventoryFull,
        soulPrismSpent: 0,
        remainingSoulPrism: currentPrism,
        errorMessage: 'Kapasitas tas perlengkapan penuh.',
      );
    }

    final remainingPrism = currentPrism - cost;
    final newCurrencies = Map<String, int>.from(snapshot.currencies);
    newCurrencies[exchange.currencyId] = remainingPrism;

    var eqCounter = snapshot.inventory.equipmentCounter + 1;
    final grantedEq = equipmentFactory.create(
      instanceId: 'eq_$eqCounter',
      definition: item,
      random: random,
    );
    final newEquipment =
        List<EquipmentInstance>.from(snapshot.inventory.equipment)
          ..add(grantedEq);

    final updatedSnapshot = snapshot.copyWith(
      currencies: newCurrencies,
      inventory: InventorySnapshot(
        stacks: snapshot.inventory.stacks,
        equipment: newEquipment,
        equipmentCounter: eqCounter,
      ),
    );

    return SanctuaryExchangeResult(
      status: SanctuaryExchangeStatus.success,
      updatedSnapshot: updatedSnapshot,
      soulPrismSpent: cost,
      remainingSoulPrism: remainingPrism,
      grantedEquipment: grantedEq,
    );
  }

  /// Melakukan penukaran Soul Prism untuk 1 Class Mythical pilihan di Toko Sanctuary (Biaya: 3).
  SanctuaryExchangeResult exchangeSanctuaryClass({
    required PlayerSaveSnapshot snapshot,
    required String classId,
  }) {
    final exchange = gachaConfig.sanctuaryExchange;
    final cost = exchange.classCost;
    final currentPrism = snapshot.currencies[exchange.currencyId] ?? 0;
    if (currentPrism < cost) {
      return SanctuaryExchangeResult(
        status: SanctuaryExchangeStatus.insufficientSoulPrisms,
        soulPrismSpent: 0,
        remainingSoulPrism: currentPrism,
        errorMessage:
            'Soul Prism tidak mencukupi (dibutuhkan $cost, saldo: $currentPrism).',
      );
    }

    final spec = specializations[classId];
    if (spec == null || spec.rarity != ItemRarity.mythical) {
      return SanctuaryExchangeResult(
        status: SanctuaryExchangeStatus.invalidTarget,
        soulPrismSpent: 0,
        remainingSoulPrism: currentPrism,
        errorMessage:
            'Class "$classId" bukan merupakan Class Mythical yang valid.',
      );
    }

    if (snapshot.unlockedSpecializations.contains(classId)) {
      return SanctuaryExchangeResult(
        status: SanctuaryExchangeStatus.alreadyOwned,
        soulPrismSpent: 0,
        remainingSoulPrism: currentPrism,
        errorMessage: 'Class "${spec.name}" sudah dibuka sebelumnya.',
      );
    }

    final remainingPrism = currentPrism - cost;
    final newCurrencies = Map<String, int>.from(snapshot.currencies);
    newCurrencies[exchange.currencyId] = remainingPrism;
    final newUnlockedSpecs =
        Set<String>.from(snapshot.unlockedSpecializations)..add(classId);

    final updatedSnapshot = snapshot.copyWith(
      currencies: newCurrencies,
      unlockedSpecializations: newUnlockedSpecs,
    );

    return SanctuaryExchangeResult(
      status: SanctuaryExchangeStatus.success,
      updatedSnapshot: updatedSnapshot,
      soulPrismSpent: cost,
      remainingSoulPrism: remainingPrism,
      unlockedClassId: classId,
    );
  }
}
