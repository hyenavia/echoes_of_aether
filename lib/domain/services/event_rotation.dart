import '../entities/equipment.dart';
import '../entities/event_shop_config.dart';
import '../entities/item_definition.dart';

/// Penjadwal rotasi mingguan Weekly Event Shop yang murni dan deterministik
/// (M13 Stage 2, TECHNICAL_DESIGN_ADDENDUM_v1.2 §3.5).
///
/// Algoritma:
/// 1. Panjang siklus = `pool.length ~/ 2`; `cycleIndex` dan `slotInCycle`
///    dihitung dengan pembagian lantai Euclidean agar deterministik termasuk pada
///    `weekIndex < 0`.
/// 2. Entri `epic` dan `legendary` diurutkan kanonik berdasarkan `id` agar
///    tidak bergantung pada urutan iterasi koleksi/hash, lalu dikocok memakai
///    PRNG 32-bit murni (`xorshift32` + warm-up Weyl) ber-seed `cycleIndex`.
/// 3. Daftar `legendary` digeser siklis secara deterministik sampai setiap
///    pasangan `[epic, legendary]` berasal dari [EquipmentSlot] berbeda; bila
///    pada ukuran ganjil (`pool.length = 10` -> siklus 5) seluruh pergeseran
///    siklis masih menyisakan tabrakan slot, dilakukan pertukaran deterministik
///    pertama yang bebas tabrakan.
class EventRotation {
  const EventRotation({this.items = const {}});

  final Map<String, ItemDefinition> items;

  /// Mengembalikan daftar pasangan `[epic, legendary]` untuk seluruh minggu pada
  /// siklus [cycleIndex] dari [pool].
  List<List<EventShopEntry>> scheduleForCycle(
    int cycleIndex,
    List<EventShopEntry> pool,
  ) {
    if (pool.isEmpty || pool.length.isOdd) {
      throw ArgumentError.value(
        pool.length,
        'pool',
        'Ukuran pool event shop harus genap dan >= 2.',
      );
    }

    final epics = <EventShopEntry>[];
    final legendaries = <EventShopEntry>[];
    for (final entry in pool) {
      if (entry.tier == EventItemTier.epic) {
        epics.add(entry);
      } else {
        legendaries.add(entry);
      }
    }
    if (epics.length != legendaries.length || epics.length < 2) {
      throw ArgumentError(
        'Pool event shop harus memiliki jumlah item epic dan legendary yang '
        'seimbang serta minimal 2 pasang agar tiap pasangan berbeda slot.',
      );
    }

    epics.sort((a, b) => a.id.compareTo(b.id));
    legendaries.sort((a, b) => a.id.compareTo(b.id));

    final n = epics.length;
    final epicSlotsBeforeShuffle = <EquipmentSlot>[
      for (final e in epics) _slotOf(e),
    ];
    final legendarySlotsBeforeShuffle = <EquipmentSlot>[
      for (final l in legendaries) _slotOf(l),
    ];
    _ensureSlotsPairable(
      n,
      epicSlotsBeforeShuffle,
      legendarySlotsBeforeShuffle,
    );

    final epicOrder = _shuffled(epics, seed: cycleIndex);
    final legendaryBase = _shuffled(legendaries, seed: cycleIndex ^ 0x5A5A5A5A);

    final pairedLegendaries = _pairDifferentSlots(
      epicOrder,
      legendaryBase,
      cycleIndex: cycleIndex,
    );

    return List<List<EventShopEntry>>.unmodifiable([
      for (var i = 0; i < n; i++)
        List<EventShopEntry>.unmodifiable([epicOrder[i], pairedLegendaries[i]]),
    ]);
  }

  /// Mengembalikan pasangan `[epic, legendary]` yang tampil pada minggu [weekIndex].
  List<EventShopEntry> entriesForWeek(
    int weekIndex,
    List<EventShopEntry> pool,
  ) {
    if (pool.isEmpty || pool.length.isOdd) {
      throw ArgumentError.value(
        pool.length,
        'pool',
        'Ukuran pool event shop harus genap dan >= 2.',
      );
    }
    final cycleLength = pool.length ~/ 2;
    final cycleIndex = weekIndex >= 0
        ? weekIndex ~/ cycleLength
        : ((weekIndex + 1) ~/ cycleLength) - 1;
    final slotInCycle = weekIndex % cycleLength;
    final cycleSchedule = scheduleForCycle(cycleIndex, pool);
    return cycleSchedule[slotInCycle];
  }

  EquipmentSlot _slotOf(EventShopEntry entry) {
    final slot = entry.slot ?? items[entry.itemId]?.equipment?.slot;
    if (slot == null) {
      throw ArgumentError(
        'Slot equipment untuk entri event shop "${entry.id}" '
        '(item "${entry.itemId}") tidak ditemukan.',
      );
    }
    return slot;
  }

  void _ensureSlotsPairable(
    int n,
    List<EquipmentSlot> epicSlots,
    List<EquipmentSlot> legendarySlots,
  ) {
    final epicCounts = <EquipmentSlot, int>{};
    final legendaryCounts = <EquipmentSlot, int>{};
    for (final s in epicSlots) {
      epicCounts[s] = (epicCounts[s] ?? 0) + 1;
    }
    for (final s in legendarySlots) {
      legendaryCounts[s] = (legendaryCounts[s] ?? 0) + 1;
    }
    for (final slot in EquipmentSlot.values) {
      final totalInSlot =
          (epicCounts[slot] ?? 0) + (legendaryCounts[slot] ?? 0);
      if (totalInSlot > n) {
        throw ArgumentError(
          'Slot ${slot.name} terlalu mendominasi pool ($totalInSlot > $n), '
          'sehingga pasangan berbeda slot tidak dapat dijamin.',
        );
      }
    }
  }

  List<EventShopEntry> _pairDifferentSlots(
    List<EventShopEntry> epics,
    List<EventShopEntry> legendaries, {
    required int cycleIndex,
  }) {
    final n = epics.length;
    final epicSlots = [for (final e in epics) _slotOf(e)];
    final legSlots = [for (final l in legendaries) _slotOf(l)];

    // Coba pergeseran siklis dimulai dari offset deterministik berbasis cycleIndex.
    final startShift = _initialOffset(cycleIndex ^ 0x3C6EF372, n);
    for (var step = 0; step < n; step++) {
      final shift = (startShift + step) % n;
      var hasCollision = false;
      for (var i = 0; i < n; i++) {
        if (epicSlots[i] == legSlots[(i + shift) % n]) {
          hasCollision = true;
          break;
        }
      }
      if (!hasCollision) {
        return [for (var i = 0; i < n; i++) legendaries[(i + shift) % n]];
      }
    }

    // Fallback deterministik (mis. kasus langka pada ukuran siklus ganjil n=5):
    // geser sesuai startShift lalu tukar pasangan bertabrakan dengan pasangan
    // pertama yang menghilangkan tabrakan tanpa membuat tabrakan baru.
    final candidate = [
      for (var i = 0; i < n; i++) legendaries[(i + startShift) % n],
    ];
    final candidateSlots = [
      for (var i = 0; i < n; i++) legSlots[(i + startShift) % n],
    ];

    for (var i = 0; i < n; i++) {
      if (epicSlots[i] != candidateSlots[i]) continue;
      final collidingSlot = epicSlots[i];
      var swapped = false;
      for (var j = 0; j < n; j++) {
        if (j == i) continue;
        if (candidateSlots[j] != collidingSlot &&
            epicSlots[j] != collidingSlot) {
          final tmpEntry = candidate[i];
          candidate[i] = candidate[j];
          candidate[j] = tmpEntry;

          final tmpSlot = candidateSlots[i];
          candidateSlots[i] = candidateSlots[j];
          candidateSlots[j] = tmpSlot;
          swapped = true;
          break;
        }
      }
      if (!swapped) {
        throw StateError(
          'Gagal memasangkan item event berbeda slot pada siklus $cycleIndex.',
        );
      }
    }
    return candidate;
  }

  List<T> _shuffled<T>(List<T> source, {required int seed}) {
    final copy = List<T>.from(source);
    var state = _seedState(seed);
    for (var i = copy.length - 1; i > 0; i--) {
      state = _stepXorshift32((state + i + 0x7F4A7C15) & 0xFFFFFFFF);
      final j = state % (i + 1);
      final tmp = copy[i];
      copy[i] = copy[j];
      copy[j] = tmp;
    }
    return copy;
  }

  int _initialOffset(int seed, int modulo) {
    final state = _seedState(seed);
    return state % modulo;
  }

  int _seedState(int seed) {
    var state = ((seed & 0xFFFFFFFF) ^ 0x9E3779B9) & 0xFFFFFFFF;
    for (var r = 0; r < 6; r++) {
      state = _stepXorshift32((state + 0x9E3779B9) & 0xFFFFFFFF);
    }
    return state;
  }

  int _stepXorshift32(int s) {
    var x = s & 0xFFFFFFFF;
    if (x == 0) x = 0x6D2B79F5;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= (x >> 17) & 0xFFFFFFFF;
    x ^= (x << 5) & 0xFFFFFFFF;
    return x & 0xFFFFFFFF;
  }
}
