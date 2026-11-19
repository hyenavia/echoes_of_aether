import 'dart:io';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/event_shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/event_shop_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loot_table.dart';
import 'package:echoes_of_aether/domain/entities/shop_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig({
  Map<String, ItemDefinition>? itemsOverride,
  Map<String, LootTable>? lootTablesOverride,
  ShopCatalog? shopOverride,
  EventShopCatalog? eventShopOverride,
}) {
  const parser = GameConfigParser();
  const dungeonParser = DungeonConfigParser();
  final settings = _readAsset('game_config.json');
  final dungeonsJson = _readAsset('dungeons.json');

  return GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: parser.parseDifficulty(settings),
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    time: parser.parseTime(settings),
    claimedRewards: parser.parseClaimedRewards(settings),
    currencies: parser.parseCurrencies(settings),
    notifications: parser.parseNotifications(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items:
        itemsOverride ??
        const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables:
        lootTablesOverride ??
        const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: dungeonParser.parse(
      dungeonsJson,
      ascensionMultiplier: parser.parseDifficulty(settings).ascensionMultiplier,
    ),
    mapLayouts: dungeonParser.parseMaps(dungeonsJson),
    bossEvents: const BossEventsConfigParser().parse(
      _readAsset('boss_events.json'),
    ),
    shop:
        shopOverride ?? const ShopConfigParser().parse(_readAsset('shop.json')),
    eventShop:
        eventShopOverride ??
        const EventShopConfigParser().parse(_readAsset('event_shop.json')),
  );
}

void main() {
  const eventItemIds = {
    'event_dawn_blade',
    'event_eclipse_blade',
    'event_aegis_mail',
    'event_bulwark_plate',
    'event_warden_helm',
    'event_crown_of_dusk',
    'event_ember_ring',
    'event_aether_pendant',
  };

  group('Assets event items & event_shop.json', () {
    test('8 item event di items.json sesuai baseline, fixed_stats: true, sellable: false', () {
      final config = _loadRealConfig();
      expect(
        () => const GameConfigValidator().validate(config),
        returnsNormally,
      );

      for (final id in eventItemIds) {
        final item = config.items[id];
        expect(item, isNotNull, reason: 'Item $id harus ada di items.json');
        expect(item!.isEquipment, isTrue, reason: '$id harus equipment');
        expect(item.sellable, isFalse, reason: '$id harus sellable: false');
        expect(item.sellValue, 0, reason: '$id sell_value = 0');
        expect(
          item.equipment!.fixedStats,
          isTrue,
          reason: '$id harus fixed_stats: true',
        );
      }

      // Spot-check seluruh stat baseline GDD Addendum §5.3.
      expect(config.items['event_dawn_blade']!.rarity, ItemRarity.epic);
      expect(
        config.items['event_dawn_blade']!.equipment!.baseStats.atkPct,
        closeTo(0.10, 1e-9),
      );
      expect(
        config.items['event_dawn_blade']!.equipment!.baseStats.critDamage,
        closeTo(0.15, 1e-9),
      );

      expect(config.items['event_eclipse_blade']!.rarity, ItemRarity.legendary);
      expect(
        config.items['event_eclipse_blade']!.equipment!.baseStats.atkPct,
        closeTo(0.16, 1e-9),
      );
      expect(
        config.items['event_eclipse_blade']!.equipment!.baseStats.critRate,
        closeTo(0.05, 1e-9),
      );
      expect(
        config.items['event_eclipse_blade']!.equipment!.baseStats.critDamage,
        closeTo(0.20, 1e-9),
      );

      expect(
        config.items['event_aegis_mail']!.equipment!.slot,
        EquipmentSlot.body,
      );
      expect(
        config.items['event_aegis_mail']!.equipment!.baseStats.hpPct,
        closeTo(0.12, 1e-9),
      );
      expect(
        config.items['event_aegis_mail']!.equipment!.baseStats.defPct,
        closeTo(0.08, 1e-9),
      );

      expect(
        config.items['event_bulwark_plate']!.equipment!.baseStats.hpPct,
        closeTo(0.20, 1e-9),
      );
      expect(
        config.items['event_bulwark_plate']!.equipment!.baseStats.defPct,
        closeTo(0.12, 1e-9),
      );

      expect(
        config.items['event_warden_helm']!.equipment!.slot,
        EquipmentSlot.head,
      );
      expect(
        config.items['event_warden_helm']!.equipment!.baseStats.defPct,
        closeTo(0.10, 1e-9),
      );
      expect(
        config.items['event_warden_helm']!.equipment!.baseStats.hpPct,
        closeTo(0.06, 1e-9),
      );

      expect(
        config.items['event_crown_of_dusk']!.equipment!.baseStats.defPct,
        closeTo(0.16, 1e-9),
      );
      expect(
        config.items['event_crown_of_dusk']!.equipment!.baseStats.hpPct,
        closeTo(0.10, 1e-9),
      );
      expect(
        config.items['event_crown_of_dusk']!.equipment!.baseStats.skillHaste,
        closeTo(0.05, 1e-9),
      );

      expect(
        config.items['event_ember_ring']!.equipment!.slot,
        EquipmentSlot.accessory,
      );
      expect(
        config.items['event_ember_ring']!.equipment!.baseStats.atkPct,
        closeTo(0.06, 1e-9),
      );
      expect(
        config.items['event_ember_ring']!.equipment!.baseStats.critRate,
        closeTo(0.04, 1e-9),
      );
      expect(
        config.items['event_ember_ring']!.equipment!.baseStats.skillHaste,
        closeTo(0.05, 1e-9),
      );

      expect(
        config.items['event_aether_pendant']!.equipment!.baseStats.atkPct,
        closeTo(0.10, 1e-9),
      );
      expect(
        config.items['event_aether_pendant']!.equipment!.baseStats.hpPct,
        closeTo(0.08, 1e-9),
      );
      expect(
        config.items['event_aether_pendant']!.equipment!.baseStats.critRate,
        closeTo(0.06, 1e-9),
      );
    });

    test(
      'event_shop.json memenuhi struktur, harga, dan requirement baseline',
      () {
        final config = _loadRealConfig();
        final eventShop = config.eventShop!;
        expect(eventShop.pool, hasLength(8));
        expect(eventShop.cycleLength, 4);
        expect(eventShop.weeklyPurchaseLimit, 1);
        expect(eventShop.currencyId, 'barter');

        for (final entry in eventShop.pool) {
          expect(entry.isBarter, isTrue);
          expect(entry.price, 0);
          if (entry.tier == EventItemTier.epic) {
            expect(entry.goldPrice, 25000);
            expect(entry.materialCosts, {
              'boss_remnant': 3,
              'aether_scrap': 30,
            });
            expect(
              entry.requirements,
              contains(const DungeonClearedRequirement('ancient_crypt')),
            );
          } else {
            expect(entry.goldPrice, 75000);
            expect(entry.materialCosts, {
              'boss_remnant': 6,
              'aether_scrap': 75,
            });
            expect(
              entry.requirements,
              contains(const MinAscensionRankRequirement(1)),
            );
          }
        }
      },
    );

    test('item event tidak ada di loot_tables.json maupun shop.json biasa', () {
      final config = _loadRealConfig();
      for (final table in config.lootTables.values) {
        for (final drop in table.entries) {
          expect(
            eventItemIds.contains(drop.itemId),
            isFalse,
            reason:
                '${drop.itemId} tidak boleh muncul di loot table ${table.id}',
          );
        }
      }
      for (final shopEntry in config.shop.entries) {
        expect(
          eventItemIds.contains(shopEntry.itemId),
          isFalse,
          reason:
              '${shopEntry.itemId} tidak boleh muncul di shop biasa (${shopEntry.id})',
        );
      }
    });
  });

  group('EventShopConfigParser & GameConfigValidator', () {
    const parser = EventShopConfigParser();
    const validator = GameConfigValidator();

    test('menolak ukuran pool ganjil', () {
      final base = _loadRealConfig();
      final bad = _loadRealConfig(
        eventShopOverride: EventShopCatalog(
          pool: base.eventShop!.pool.take(7).toList(),
        ),
      );
      expect(() => validator.validate(bad), throwsA(isA<ConfigException>()));
    });

    test('menolak jumlah tier epic dan legendary tidak seimbang', () {
      final base = _loadRealConfig();
      final pool = base.eventShop!.pool.toList();
      final replaced = EventShopEntry(
        id: pool[1].id,
        itemId: pool[1].itemId,
        tier: EventItemTier.epic,
        price: 100,
      );
      pool[1] = replaced;
      final bad = _loadRealConfig(
        eventShopOverride: EventShopCatalog(pool: pool),
      );
      expect(() => validator.validate(bad), throwsA(isA<ConfigException>()));
    });

    test('menolak slot kurang (mis. tanpa accessory atau satu tier hilang pada suatu slot)', () {
      final base = _loadRealConfig();
      // Hapus entri accessory & duplikatkan weapon dengan id unik -> ukuran tetap 8 genap, epic=4, legendary=4, tapi accessory 0.
      final filtered =
          base.eventShop!.pool
              .where(
                (e) =>
                    e.itemId != 'event_ember_ring' &&
                    e.itemId != 'event_aether_pendant',
              )
              .toList()
            ..add(
              const EventShopEntry(
                id: 'evt_extra_weapon_epic',
                itemId: 'event_dawn_blade',
                tier: EventItemTier.epic,
                price: 100,
              ),
            )
            ..add(
              const EventShopEntry(
                id: 'evt_extra_weapon_leg',
                itemId: 'event_eclipse_blade',
                tier: EventItemTier.legendary,
                price: 180,
              ),
            );
      final bad = _loadRealConfig(
        eventShopOverride: EventShopCatalog(pool: filtered),
      );
      expect(() => validator.validate(bad), throwsA(isA<ConfigException>()));
    });

    test('menolak item yang bisa dijual (sellable: true)', () {
      final base = _loadRealConfig();
      final itemsCopy = Map<String, ItemDefinition>.from(base.items);
      final orig = itemsCopy['event_dawn_blade']!;
      itemsCopy['event_dawn_blade'] = ItemDefinition(
        id: orig.id,
        name: orig.name,
        category: orig.category,
        rarity: orig.rarity,
        sellValue: 0,
        sellable: true,
        equipment: orig.equipment,
      );
      final bad = _loadRealConfig(itemsOverride: itemsCopy);
      expect(() => validator.validate(bad), throwsA(isA<ConfigException>()));
    });

    test('menolak item_id yang tidak ada di items.json', () {
      final base = _loadRealConfig();
      final pool = base.eventShop!.pool.toList();
      pool[0] = const EventShopEntry(
        id: 'evt_missing',
        itemId: 'item_tidak_ada',
        tier: EventItemTier.epic,
        price: 100,
      );
      final bad = _loadRealConfig(
        eventShopOverride: EventShopCatalog(pool: pool),
      );
      expect(() => validator.validate(bad), throwsA(isA<ConfigException>()));
    });

    test('menolak item event muncul di loot table atau shop biasa', () {
      final base = _loadRealConfig();

      final lootWithEvent = Map<String, LootTable>.from(base.lootTables);
      lootWithEvent['slime_loot'] = const LootTable(
        id: 'slime_loot',
        entries: [LootEntry(itemId: 'event_dawn_blade', chance: 0.1)],
      );
      expect(
        () => validator.validate(
          _loadRealConfig(lootTablesOverride: lootWithEvent),
        ),
        throwsA(isA<ConfigException>()),
      );

      final shopWithEvent = ShopCatalog(
        entries: [
          ...base.shop.entries,
          const ShopEntry(
            id: 'shop_illegal_event',
            itemId: 'event_dawn_blade',
            price: 1000,
          ),
        ],
        sell: base.shop.sell,
      );
      expect(
        () => validator.validate(_loadRealConfig(shopOverride: shopWithEvent)),
        throwsA(isA<ConfigException>()),
      );
    });

    test('parser menolak JSON invalid, tier tidak dikenal, price <= 0, dan duplikat id', () {
      expect(() => parser.parse('{bad'), throwsA(isA<ConfigException>()));
      expect(
        () => parser.parse(
          '{"pool":[{"id":"a","item_id":"x","tier":"rare","price":10}]}',
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parser.parse(
          '{"pool":[{"id":"a","item_id":"x","tier":"epic","price":0}]}',
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parser.parse(
          '{"pool":['
          '{"id":"dup","item_id":"x","tier":"epic","price":100},'
          '{"id":"dup","item_id":"y","tier":"legendary","price":180}'
          ']}',
        ),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
