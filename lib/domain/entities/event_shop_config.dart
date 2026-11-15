import 'equipment.dart';
import 'shop_config.dart';

/// Tingkat kelangkaan/tier item dalam Weekly Event Shop (M13 Stage 2).
enum EventItemTier { epic, legendary }

/// Satu entri item di dalam pool Weekly Event Shop (`assets/data/event_shop.json`).
class EventShopEntry {
  const EventShopEntry({
    required this.id,
    required this.itemId,
    required this.tier,
    required this.price,
    this.requirements = const [],
    this.slot,
  });

  final String id;
  final String itemId;
  final EventItemTier tier;
  final int price;
  final List<PurchaseRequirement> requirements;

  /// Slot equipment opsional (umumnya diisi dari `items.json`, atau langsung
  /// pada fixture unit test).
  final EquipmentSlot? slot;
}

/// Konfigurasi statis Weekly Event Shop (`assets/data/event_shop.json`).
class EventShopCatalog {
  EventShopCatalog({
    List<EventShopEntry> pool = const [],
    this.weeklyPurchaseLimit = 1,
    this.currencyId = 'aether_shard',
  }) : pool = List<EventShopEntry>.unmodifiable(pool),
       _byId = {for (final entry in pool) entry.id: entry};

  const EventShopCatalog.empty({
    this.weeklyPurchaseLimit = 1,
    this.currencyId = 'aether_shard',
  }) : pool = const [],
       _byId = const {};

  final List<EventShopEntry> pool;
  final int weeklyPurchaseLimit;
  final String currencyId;
  final Map<String, EventShopEntry> _byId;

  int get cycleLength => pool.length ~/ 2;

  EventShopEntry? byId(String entryId) => _byId[entryId];
}
