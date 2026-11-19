import '../entities/currency_config.dart';
import '../entities/inventory.dart';
import '../entities/player_character.dart';
import 'currency_service.dart';

/// Status hasil percobaan upgrade kapasitas tas.
enum BagExpansionUpgradeStatus { success, maxLevelReached, insufficientGold }

/// Hasil operasi upgrade kapasitas tas.
class BagExpansionUpgradeResult {
  const BagExpansionUpgradeResult({
    required this.status,
    this.newLevel = 0,
    this.newCapacity = 0,
    this.goldSpent = 0,
    this.remainingGold = 0,
  });

  final BagExpansionUpgradeStatus status;
  final int newLevel;
  final int newCapacity;
  final int goldSpent;
  final int remainingGold;

  bool get isSuccess => status == BagExpansionUpgradeStatus.success;
}

/// Service domain murni untuk mengelola peningkatan kapasitas tas perlengkapan.
///
/// Kapasitas dasar: 100 slot.
/// Tiap level ekspansi menambah +20 slot hingga maksimal level 10 (300 slot total).
/// Kurva harga dirancang sinkron dengan alur ekonomi game: total sink ~5.1M gold.
class BagExpansionService {
  const BagExpansionService();

  static const int baseCapacity = 100;
  static const int slotsPerLevel = 20;
  static const int maxLevel = 10;
  static const int maxCapacity =
      baseCapacity + (slotsPerLevel * maxLevel); // 300

  /// Biaya Gold per level ekspansi (indeks 0 = upgrade ke Lv 1, ..., indeks 9 = upgrade ke Lv 10).
  static const List<int> upgradeCosts = [
    10000, // Lv 1: 100 -> 120 slot (10.000 Gold)
    25000, // Lv 2: 120 -> 140 slot (25.000 Gold)
    60000, // Lv 3: 140 -> 160 slot (60.000 Gold)
    120000, // Lv 4: 160 -> 180 slot (120.000 Gold)
    250000, // Lv 5: 180 -> 200 slot (250.000 Gold)
    400000, // Lv 6: 200 -> 220 slot (400.000 Gold)
    600000, // Lv 7: 220 -> 240 slot (600.000 Gold)
    850000, // Lv 8: 240 -> 260 slot (850.000 Gold)
    1200000, // Lv 9: 260 -> 280 slot (1.200.000 Gold)
    1600000, // Lv 10: 280 -> 300 slot (1.600.000 Gold)
  ];

  /// Mengambil level ekspansi saat ini dari saldo currency (0..10).
  int getLevel(Map<String, int> balances) {
    final val = balances[kBagExpansionCurrencyId] ?? 0;
    return val.clamp(0, maxLevel);
  }

  /// Menghitung kapasitas total tas berdasarkan level ekspansi.
  int calculateCapacity(int level) {
    final clamped = level.clamp(0, maxLevel);
    return baseCapacity + (clamped * slotsPerLevel);
  }

  /// Mengambil biaya upgrade dari [currentLevel] ke level berikutnya.
  /// Mengembalikan null jika sudah mencapai [maxLevel] atau level tidak valid.
  int? getUpgradeCost(int currentLevel) {
    if (currentLevel >= maxLevel || currentLevel < 0) return null;
    return upgradeCosts[currentLevel];
  }

  /// Melakukan upgrade kapasitas tas secara atomik:
  /// 1. Validasi level maksimum (10).
  /// 2. Validasi kecukupan Gold pemain.
  /// 3. Memotong Gold pemain via [character.spendGold].
  /// 4. Menambahkan 1 level ke [currencyService].
  /// 5. Memperbarui [inventory.maxEquipmentCapacity].
  BagExpansionUpgradeResult upgrade({
    required PlayerCharacter character,
    required CurrencyService currencyService,
    required Inventory inventory,
  }) {
    final currentLevel = getLevel(currencyService.balances);
    if (currentLevel >= maxLevel) {
      return BagExpansionUpgradeResult(
        status: BagExpansionUpgradeStatus.maxLevelReached,
        newLevel: currentLevel,
        newCapacity: calculateCapacity(currentLevel),
        remainingGold: character.gold,
      );
    }

    final cost = getUpgradeCost(currentLevel);
    if (cost == null || !character.canAfford(cost)) {
      return BagExpansionUpgradeResult(
        status: BagExpansionUpgradeStatus.insufficientGold,
        newLevel: currentLevel,
        newCapacity: calculateCapacity(currentLevel),
        remainingGold: character.gold,
      );
    }

    final goldDeducted = character.spendGold(cost);
    if (!goldDeducted) {
      return BagExpansionUpgradeResult(
        status: BagExpansionUpgradeStatus.insufficientGold,
        newLevel: currentLevel,
        newCapacity: calculateCapacity(currentLevel),
        remainingGold: character.gold,
      );
    }

    final nextLevel = currentLevel + 1;
    final claimId = 'bag_expansion:$nextLevel';
    final grantResult = currencyService.grant(
      kBagExpansionCurrencyId,
      1,
      claimId: claimId,
    );
    if (!grantResult.isSuccess) {
      character.addGold(cost);
      return BagExpansionUpgradeResult(
        status: BagExpansionUpgradeStatus.maxLevelReached,
        newLevel: currentLevel,
        newCapacity: calculateCapacity(currentLevel),
        remainingGold: character.gold,
      );
    }

    final nextCapacity = calculateCapacity(nextLevel);
    inventory.maxEquipmentCapacity = nextCapacity;

    return BagExpansionUpgradeResult(
      status: BagExpansionUpgradeStatus.success,
      newLevel: nextLevel,
      newCapacity: nextCapacity,
      goldSpent: cost,
      remainingGold: character.gold,
    );
  }
}
