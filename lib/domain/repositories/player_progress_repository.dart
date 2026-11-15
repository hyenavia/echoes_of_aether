import '../entities/clock_state.dart';
import '../entities/cycle_progress.dart';
import '../entities/equipment.dart';
import '../entities/event_shop_purchase.dart';
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

/// Kontrak repository untuk mengganti total snapshot pemain pada satu
/// perangkat secara atomik saat pemulihan cloud (`DESIGN_ADDENDUM_v1.3 §1.5`).
abstract interface class SnapshotReplaceRepository {
  /// Mengganti seluruh data pemain dalam satu transaksi database tanpa
  /// menyentuh `GameSettings`. Mengosongkan sesi dungeon aktif, menyetel
  /// jangkar offline ke [restoredAtMs] dengan mode pause, dan mempertahankan
  /// `ClockState.lastSeenAtMs = max(restored, local)`.
  Future<void> replaceSnapshot(
    PlayerSaveSnapshot snapshot, {
    required int restoredAtMs,
  });
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

/// Kontrak repository untuk persistensi pembelian mingguan Event Shop
/// (`EventShopPurchases`) secara atomik bersama perubahan mata uang dan inventory.
abstract interface class EventShopPurchaseRepository {
  Future<List<EventShopPurchaseRecord>> loadEventShopPurchases();

  Future<void> saveEventShopTransaction({
    required PlayerProgress progress,
    required InventorySnapshot inventory,
    required Map<EquipmentSlot, EquipmentInstance> equipped,
    required Map<String, int> currencies,
    required EventShopPurchaseRecord purchase,
    String? actionId,
    int? updatedAtMs,
  });
}

/// Kontrak repository untuk persistensi `ClockStates` per pemain.
abstract interface class ClockStateRepository {
  Future<ClockState> loadClockState();

  Future<void> saveClockState(ClockState state);
}

/// Kontrak repository untuk pemangkasan aman tabel `ClaimedRewards`.
abstract interface class ClaimedRewardsPruningRepository {
  Future<int> pruneClaimedRewards({
    required int cutoffMs,
    String? activeRunId,
    Set<String> activePeriodKeys = const {},
  });
}
