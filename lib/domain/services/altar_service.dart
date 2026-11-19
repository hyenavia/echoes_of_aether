import '../entities/altar_blessing.dart';
import '../entities/equipment.dart';
import '../entities/player_character.dart';
import 'currency_service.dart';

/// Status hasil percobaan upgrade berkah di Camp Altar.
enum AltarUpgradeStatus {
  success,
  maxLevelReached,
  insufficientGold,
  unknownBlessing,
}

/// Hasil operasi upgrade berkah di Camp Altar.
class AltarUpgradeResult {
  const AltarUpgradeResult({
    required this.status,
    this.blessingType,
    this.newLevel = 0,
    this.goldSpent = 0,
    this.remainingGold = 0,
  });

  final AltarUpgradeStatus status;
  final AltarBlessingType? blessingType;
  final int newLevel;
  final int goldSpent;
  final int remainingGold;

  bool get isSuccess => status == AltarUpgradeStatus.success;
}

/// Service domain murni untuk mengelola peningkatan berkah permanen Camp Altar.
///
/// Menyediakan perhitungan level berkah dari saldo mata uang, biaya gold,
/// total bonus stat tempur, bonus multiplier gold, dan transaksi peningkatan level.
class AltarService {
  const AltarService({this.definitions = AltarBlessingDefinition.defaults});

  final Map<AltarBlessingType, AltarBlessingDefinition> definitions;

  /// Mengambil level berkah [type] dari saldo mata uang [balances].
  int getBlessingLevel(AltarBlessingType type, Map<String, int> balances) {
    final def = definitions[type];
    if (def == null) return 0;
    final val = balances[def.id] ?? 0;
    return val.clamp(0, def.maxLevel);
  }

  /// Mengambil biaya gold untuk menaikkan berkah [type] dari [currentLevel] ke level berikutnya.
  int? getUpgradeCost(AltarBlessingType type, int currentLevel) {
    final def = definitions[type];
    if (def == null) return null;
    return def.upgradeCost(currentLevel);
  }

  /// Menghitung total bonus stat tempur aditif (ATK, HP, DEF) dari seluruh berkah altar.
  EquipmentStats getAltarStatBonus(Map<String, int> balances) {
    var total = EquipmentStats.zero;
    for (final entry in definitions.entries) {
      final lvl = getBlessingLevel(entry.key, balances);
      if (lvl > 0) {
        total = total + entry.value.statBonusAt(lvl);
      }
    }
    return total;
  }

  /// Menghitung bonus persentase drop gold dari berkah kemakmuran (Fortune).
  /// Contoh: level 5 menghasilkan 0.05 (+5%).
  double getGoldBonusPercent(Map<String, int> balances) {
    final def = definitions[AltarBlessingType.fortune];
    if (def == null) return 0.0;
    final lvl = getBlessingLevel(AltarBlessingType.fortune, balances);
    return def.goldBonusPercentAt(lvl);
  }

  /// Melakukan upgrade berkah secara atomik:
  /// 1. Validasi eksistensi berkah dan batasan level maksimum (20).
  /// 2. Validasi kecukupan saldo gold pemain.
  /// 3. Memotong gold pemain.
  /// 4. Menambahkan level berkah ke [currencyService].
  /// 5. Memperbarui [character.altarBonus] agar CombatStats langsung ter-update.
  AltarUpgradeResult upgradeBlessing({
    required PlayerCharacter character,
    required CurrencyService currencyService,
    required AltarBlessingType type,
  }) {
    final def = definitions[type];
    if (def == null) {
      return AltarUpgradeResult(
        status: AltarUpgradeStatus.unknownBlessing,
        blessingType: type,
        remainingGold: character.gold,
      );
    }

    final currentLevel = getBlessingLevel(type, currencyService.balances);
    if (currentLevel >= def.maxLevel) {
      return AltarUpgradeResult(
        status: AltarUpgradeStatus.maxLevelReached,
        blessingType: type,
        newLevel: currentLevel,
        remainingGold: character.gold,
      );
    }

    final cost = def.upgradeCost(currentLevel);
    if (cost == null || !character.canAfford(cost)) {
      return AltarUpgradeResult(
        status: AltarUpgradeStatus.insufficientGold,
        blessingType: type,
        newLevel: currentLevel,
        remainingGold: character.gold,
      );
    }

    // Eksekusi potong gold
    final goldDeducted = character.spendGold(cost);
    if (!goldDeducted) {
      return AltarUpgradeResult(
        status: AltarUpgradeStatus.insufficientGold,
        blessingType: type,
        newLevel: currentLevel,
        remainingGold: character.gold,
      );
    }

    final nextLevel = currentLevel + 1;
    // Tambah level mata uang di currencyService secara idempoten
    final claimId = 'altar_upgrade:${def.id}:$nextLevel';
    final grantResult = currencyService.grant(def.id, 1, claimId: claimId);
    if (!grantResult.isSuccess) {
      // Rollback gold bila grant gagal secara tidak terduga
      character.addGold(cost);
      return AltarUpgradeResult(
        status: AltarUpgradeStatus.unknownBlessing,
        blessingType: type,
        newLevel: currentLevel,
        remainingGold: character.gold,
      );
    }

    // Perbarui bonus stat altar di PlayerCharacter
    character.updateAltarBonus(getAltarStatBonus(currencyService.balances));

    return AltarUpgradeResult(
      status: AltarUpgradeStatus.success,
      blessingType: type,
      newLevel: nextLevel,
      goldSpent: cost,
      remainingGold: character.gold,
    );
  }
}
