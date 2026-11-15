import 'dart:io';

import 'package:echoes_of_aether/data/models/event_shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/event_shop_config.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/services/event_rotation.dart';
import 'package:echoes_of_aether/domain/services/period_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

void main() {
  late Map<String, ItemDefinition> realItems;
  late EventShopCatalog realCatalog;
  late EventRotation rotation;

  setUpAll(() {
    realItems = const ItemConfigParser().parse(_readAsset('items.json'));
    realCatalog = const EventShopConfigParser().parse(
      _readAsset('event_shop.json'),
    );
    rotation = EventRotation(items: realItems);
  });

  group('EventRotation (8 item -> siklus 4 minggu)', () {
    test('dalam 1 siklus 4 minggu setiap item tampil tepat satu kali', () {
      for (final startWeek in [0, 4, 8, -4]) {
        final seenIds = <String>[];
        for (var offset = 0; offset < 4; offset++) {
          final pair = rotation.entriesForWeek(
            startWeek + offset,
            realCatalog.pool,
          );
          expect(pair, hasLength(2));
          seenIds.addAll(pair.map((e) => e.id));
        }
        expect(seenIds, hasLength(8));
        expect(seenIds.toSet(), hasLength(8));
        expect(seenIds.toSet(), realCatalog.pool.map((e) => e.id).toSet());
      }
    });

    test('tiap pasangan selalu berisi 1 epic + 1 legendary dari slot berbeda', () {
      for (var week = -12; week <= 84; week++) {
        final pair = rotation.entriesForWeek(week, realCatalog.pool);
        expect(pair, hasLength(2), reason: 'weekIndex=$week');
        expect(pair[0].tier, EventItemTier.epic, reason: 'weekIndex=$week');
        expect(
          pair[1].tier,
          EventItemTier.legendary,
          reason: 'weekIndex=$week',
        );

        final slot0 = realItems[pair[0].itemId]!.equipment!.slot;
        final slot1 = realItems[pair[1].itemId]!.equipment!.slot;
        expect(
          slot0,
          isNot(slot1),
          reason:
              'weekIndex=$week (${pair[0].id} & ${pair[1].id}) tidak boleh sama slot',
        );
      }
    });

    test('hasil identik pada pemanggilan berulang', () {
      for (final week in [0, 1, 2, 3, 4, 5, 19, 1000000]) {
        final first = rotation
            .entriesForWeek(week, realCatalog.pool)
            .map((e) => e.id)
            .toList();
        final second = rotation
            .entriesForWeek(week, realCatalog.pool)
            .map((e) => e.id)
            .toList();
        expect(second, first, reason: 'weekIndex=$week harus deterministik');
      }
    });

    test('deterministik lintas batas siklus (minggu 3 -> 4 -> 5) & integrasi PeriodService', () {
      final w3 = rotation
          .entriesForWeek(3, realCatalog.pool)
          .map((e) => e.id)
          .toList();
      final w4 = rotation
          .entriesForWeek(4, realCatalog.pool)
          .map((e) => e.id)
          .toList();
      final w5 = rotation
          .entriesForWeek(5, realCatalog.pool)
          .map((e) => e.id)
          .toList();

      // Re-run dari objek EventRotation baru memastikan state tidak terbawa antar panggilan.
      final fresh = EventRotation(items: realItems);
      expect(
        fresh.entriesForWeek(3, realCatalog.pool).map((e) => e.id).toList(),
        w3,
      );
      expect(
        fresh.entriesForWeek(4, realCatalog.pool).map((e) => e.id).toList(),
        w4,
      );
      expect(
        fresh.entriesForWeek(5, realCatalog.pool).map((e) => e.id).toList(),
        w5,
      );

      // Pastikan PeriodService.weekIndex memetakan epoch_monday dan batas Senin 00:00 konsisten.
      final timeConfig = const GameConfigParser().parseTime(
        _readAsset('game_config.json'),
      );
      final periodService = PeriodService(
        config: timeConfig,
        timeZoneOffset: () => Duration.zero,
      );
      final epochMonday = timeConfig.tryParseEpochMondayUtc()!;
      final sundayBeforeCycle2 = epochMonday
          .add(const Duration(days: 27, hours: 23, minutes: 59, seconds: 59))
          .millisecondsSinceEpoch;
      final mondayCycle2 = epochMonday
          .add(const Duration(days: 28))
          .millisecondsSinceEpoch;
      final weekBefore = periodService.weekIndex(sundayBeforeCycle2);
      final weekAtBoundary = periodService.weekIndex(mondayCycle2);
      expect(weekBefore, 3);
      expect(weekAtBoundary, 4);
      expect(
        rotation.entriesForWeek(weekBefore, realCatalog.pool).map((e) => e.id),
        w3,
      );
      expect(
        rotation
            .entriesForWeek(weekAtBoundary, realCatalog.pool)
            .map((e) => e.id),
        w4,
      );
    });

    test(
      'siklus berbeda menghasilkan susunan berbeda (sampel siklus 0..20)',
      () {
        final cycleSignatures = <String>{};
        for (var cycle = 0; cycle <= 20; cycle++) {
          final sig = [
            for (var w = 0; w < 4; w++)
              rotation
                  .entriesForWeek(cycle * 4 + w, realCatalog.pool)
                  .map((e) => e.id)
                  .join('+'),
          ].join('|');
          cycleSignatures.add(sig);
        }
        expect(cycleSignatures.length, greaterThan(1));
        expect(cycleSignatures.length, greaterThanOrEqualTo(15));
      },
    );

    test('weekIndex di batas epoch (0, -1) dan nilai besar stabil', () {
      for (final week in [0, -1, -1000000, 1000000, 1000000007]) {
        final pair = rotation.entriesForWeek(week, realCatalog.pool);
        expect(pair, hasLength(2), reason: 'weekIndex=$week');
        expect(pair[0].tier, EventItemTier.epic);
        expect(pair[1].tier, EventItemTier.legendary);
        expect(
          realItems[pair[0].itemId]!.equipment!.slot,
          isNot(realItems[pair[1].itemId]!.equipment!.slot),
        );
      }
    });
  });

  group('EventRotation ekspansi pool 10 item -> siklus 5 minggu', () {
    const expandedPool = <EventShopEntry>[
      EventShopEntry(
        id: 'e_w1',
        itemId: 'e_w1',
        tier: EventItemTier.epic,
        price: 100,
        slot: EquipmentSlot.weapon,
      ),
      EventShopEntry(
        id: 'e_w2',
        itemId: 'e_w2',
        tier: EventItemTier.epic,
        price: 100,
        slot: EquipmentSlot.weapon,
      ),
      EventShopEntry(
        id: 'e_h1',
        itemId: 'e_h1',
        tier: EventItemTier.epic,
        price: 100,
        slot: EquipmentSlot.head,
      ),
      EventShopEntry(
        id: 'e_b1',
        itemId: 'e_b1',
        tier: EventItemTier.epic,
        price: 100,
        slot: EquipmentSlot.body,
      ),
      EventShopEntry(
        id: 'e_a1',
        itemId: 'e_a1',
        tier: EventItemTier.epic,
        price: 100,
        slot: EquipmentSlot.accessory,
      ),
      EventShopEntry(
        id: 'l_w1',
        itemId: 'l_w1',
        tier: EventItemTier.legendary,
        price: 180,
        slot: EquipmentSlot.weapon,
      ),
      EventShopEntry(
        id: 'l_w2',
        itemId: 'l_w2',
        tier: EventItemTier.legendary,
        price: 180,
        slot: EquipmentSlot.weapon,
      ),
      EventShopEntry(
        id: 'l_h1',
        itemId: 'l_h1',
        tier: EventItemTier.legendary,
        price: 180,
        slot: EquipmentSlot.head,
      ),
      EventShopEntry(
        id: 'l_b1',
        itemId: 'l_b1',
        tier: EventItemTier.legendary,
        price: 180,
        slot: EquipmentSlot.body,
      ),
      EventShopEntry(
        id: 'l_a1',
        itemId: 'l_a1',
        tier: EventItemTier.legendary,
        price: 180,
        slot: EquipmentSlot.accessory,
      ),
    ];

    test('pool 10 item menghasilkan siklus 5 minggu tanpa duplikasi & tanpa sama-slot', () {
      const rot = EventRotation();
      for (var cycle = 0; cycle <= 30; cycle++) {
        final start = cycle * 5;
        final seen = <String>[];
        for (var offset = 0; offset < 5; offset++) {
          final pair = rot.entriesForWeek(start + offset, expandedPool);
          expect(pair, hasLength(2));
          expect(pair[0].tier, EventItemTier.epic);
          expect(pair[1].tier, EventItemTier.legendary);
          expect(
            pair[0].slot,
            isNot(pair[1].slot),
            reason: 'cycle=$cycle week=$offset sama slot!',
          );
          seen.addAll(pair.map((e) => e.id));
        }
        expect(seen, hasLength(10));
        expect(seen.toSet(), expandedPool.map((e) => e.id).toSet());
      }
    });
  });
}
