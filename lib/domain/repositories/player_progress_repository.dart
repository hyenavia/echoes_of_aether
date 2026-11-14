import '../entities/cycle_progress.dart';
import '../entities/equipment.dart';
import '../entities/player_progress.dart';
import '../entities/player_save_snapshot.dart';

/// Kontrak repository untuk persistensi progres karakter (implementasi penuh di M6).
abstract interface class PlayerProgressRepository {
  Future<PlayerProgress?> load();

  Future<void> save(PlayerProgress progress);
}

/// Kontrak repository untuk persistensi snapshot lengkap karakter dan inventory
/// (Phase E preparation -> implementasi Drift di Phase F / M6).
abstract interface class PlayerSaveRepository {
  Future<PlayerSaveSnapshot?> loadSnapshot();

  Future<void> saveSnapshot(PlayerSaveSnapshot snapshot);
}

/// Kontrak repository untuk operasi atomik state siklus Ascension serta
/// perpindahan progres dungeon lintas-siklus.
abstract interface class CycleProgressRepository {
  Future<CycleProgress> loadCycleProgress();

  Future<void> saveCycleProgress(CycleProgress cycleProgress);

  Future<void> saveCycleTransition({
    required CycleProgress cycleProgress,
    required Map<String, DungeonProgressSnapshot> dungeonProgresses,
    String? claimEventId,
    int? updatedAtMs,
  });
}

/// Kontrak repository untuk persistensi batas pembelian shop dan transaksi
/// beli/jual atomik.
abstract interface class ShopPurchaseRepository {
  Future<Map<String, int>> loadShopPurchases();

  Future<void> saveShopTransaction({
    required PlayerProgress progress,
    required InventorySnapshot inventory,
    required Map<EquipmentSlot, EquipmentInstance> equipped,
    required Map<String, int> shopPurchases,
    String? actionId,
    int? updatedAtMs,
  });
}
