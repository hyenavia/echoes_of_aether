import 'package:flutter/foundation.dart';

/// Jenis banner gacha (Class Awakening vs Mythical Armory).
enum GachaBannerType {
  classBanner,
  weaponBanner;

  static GachaBannerType fromString(String raw) => switch (raw) {
    'class' || 'classBanner' => GachaBannerType.classBanner,
    'weapon' || 'weaponBanner' => GachaBannerType.weaponBanner,
    _ => throw ArgumentError('Tipe gacha banner tidak dikenal: "$raw".'),
  };

  String get idString => switch (this) {
    GachaBannerType.classBanner => 'class',
    GachaBannerType.weaponBanner => 'weapon',
  };
}

/// Definisi konfigurasi satu banner gacha dari `gacha_banners.json`.
@immutable
class GachaBannerDefinition {
  const GachaBannerDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.hardPity,
    required this.baseRate,
    this.rateUpShare = 0.5,
    this.featuredPool = const [],
    this.standardPool = const [],
  });

  final String id;
  final String name;
  final GachaBannerType type;
  final int hardPity;
  final double baseRate;
  final double rateUpShare;
  final List<String> featuredPool;
  final List<String> standardPool;
}

/// Konfigurasi pertukaran Soul Prism di Sanctuary Shop.
@immutable
class SanctuaryExchangeConfig {
  const SanctuaryExchangeConfig({
    required this.currencyId,
    required this.classCost,
    required this.weaponCost,
  });

  final String currencyId;
  final int classCost;
  final int weaponCost;
}

/// Konfigurasi seluruh sistem gacha dari `gacha_banners.json`.
@immutable
class GachaConfig {
  const GachaConfig({
    required this.cycleDays,
    required this.costPerPull,
    required this.costPerTenPull,
    required this.currencyId,
    required this.duplicateCurrencyId,
    required this.duplicateGrantedAmount,
    required this.banners,
    required this.sanctuaryExchange,
  });

  final int cycleDays;
  final int costPerPull;
  final int costPerTenPull;
  final String currencyId;
  final String duplicateCurrencyId;
  final int duplicateGrantedAmount;
  final Map<String, GachaBannerDefinition> banners;
  final SanctuaryExchangeConfig sanctuaryExchange;

  GachaBannerDefinition? bannerByType(GachaBannerType type) {
    for (final b in banners.values) {
      if (b.type == type) return b;
    }
    return null;
  }
}

/// State akumulasi pity gacha per banner yang dipersistensikan di database.
@immutable
class GachaPityState {
  const GachaPityState({
    required this.bannerType,
    this.pullCount = 0,
    this.isGuaranteed = false,
  });

  final String bannerType;
  final int pullCount;
  final bool isGuaranteed;

  GachaPityState copyWith({
    String? bannerType,
    int? pullCount,
    bool? isGuaranteed,
  }) {
    return GachaPityState(
      bannerType: bannerType ?? this.bannerType,
      pullCount: pullCount ?? this.pullCount,
      isGuaranteed: isGuaranteed ?? this.isGuaranteed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GachaPityState &&
          bannerType == other.bannerType &&
          pullCount == other.pullCount &&
          isGuaranteed == other.isGuaranteed;

  @override
  int get hashCode => Object.hash(bannerType, pullCount, isGuaranteed);
}

/// Hasil dari satu tarikan gacha.
@immutable
class GachaPullResult {
  const GachaPullResult({
    required this.itemId,
    required this.bannerType,
    required this.isSpecialization,
    required this.isMythical,
    required this.isFeatured,
    this.isDuplicate = false,
    this.soulPrismGranted = 0,
  });

  final String itemId;
  final GachaBannerType bannerType;
  final bool isSpecialization;
  final bool isMythical;
  final bool isFeatured;
  final bool isDuplicate;
  final int soulPrismGranted;
}
