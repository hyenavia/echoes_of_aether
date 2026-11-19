import 'dart:convert';
import 'dart:io';

import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/features/shared/assets/item_sprite_registry.dart';
import 'package:echoes_of_aether/features/shared/widgets/item_card.dart';
import 'package:echoes_of_aether/features/shared/widgets/item_slot.dart';
import 'package:echoes_of_aether/features/shared/widgets/pixel_item_icon.dart';
import 'package:echoes_of_aether/features/shared/widgets/pixel_ui_box.dart';
import 'package:echoes_of_aether/features/shared/widgets/resource_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ItemSpriteRegistry & items.json parity', () {
    test('Setiap item di assets/data/items.json terdaftar di ItemSpriteRegistry', () {
      final file = File('assets/data/items.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'assets/data/items.json harus ada',
      );

      final data = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final items = (data['items'] as List).cast<Map<String, dynamic>>();

      for (final item in items) {
        final id = item['id'] as String;
        final path = ItemSpriteRegistry.spriteForItem(id);
        expect(
          path,
          isNotNull,
          reason:
              'Item "$id" harus memiliki sprite terdaftar di ItemSpriteRegistry',
        );

        final spriteFile = File(path!);
        expect(
          spriteFile.existsSync(),
          isTrue,
          reason: 'Berkas sprite "$path" untuk item "$id" harus ada di disk',
        );
      }
    });

    test('Hub & currency sprites terdaftar dan berkas fisiknya ada', () {
      for (final entry in ItemSpriteRegistry.hubSprites.entries) {
        final key = entry.key;
        final path = entry.value;
        expect(ItemSpriteRegistry.spriteForHub(key), equals(path));

        final spriteFile = File(path);
        expect(
          spriteFile.existsSync(),
          isTrue,
          reason:
              'Berkas hub sprite "$path" untuk key "$key" harus ada di disk',
        );
      }
    });

    test(
      'spriteForItem mengembalikan null untuk id tidak dikenal atau kosong',
      () {
        expect(ItemSpriteRegistry.spriteForItem(null), isNull);
        expect(ItemSpriteRegistry.spriteForItem(''), isNull);
        expect(
          ItemSpriteRegistry.spriteForItem('unknown_non_existent_item_id'),
          isNull,
        );
      },
    );
  });

  group('PixelUiBoxStyle 9-Slice specifications', () {
    test('Semua style memiliki centerSlice valid dan berkas asset ada di disk', () {
      for (final style in PixelUiBoxStyle.values) {
        final file = File(style.assetPath);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'Asset UI "${style.assetPath}" untuk style $style harus ada di disk',
        );

        expect(style.centerSlice.left, greaterThanOrEqualTo(0));
        expect(style.centerSlice.top, greaterThanOrEqualTo(0));
        expect(style.centerSlice.right, greaterThan(style.centerSlice.left));
        expect(style.centerSlice.bottom, greaterThan(style.centerSlice.top));
      }
    });

    testWidgets('PixelUiBox dapat dirender dengan child dan custom padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PixelUiBox(
              style: PixelUiBoxStyle.darkStoneFrame,
              width: 120,
              height: 120,
              child: Text('Konten Frame'),
            ),
          ),
        ),
      );

      expect(find.text('Konten Frame'), findsOneWidget);
      expect(find.byType(PixelUiBox), findsOneWidget);
    });
  });

  group('PixelItemIcon Widget', () {
    testWidgets('Merender Image saat itemId terdaftar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PixelItemIcon(itemId: 'rusty_sword', size: 40)),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('Fallback ke Icon saat itemId tidak ada di registry', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PixelItemIcon(
              itemId: 'non_existent_item',
              fallbackIcon: Icons.help_outline,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });
  });

  group('ItemCard & ItemSlot Integration', () {
    testWidgets('ItemCard menampilkan PixelItemIcon saat itemId diisi', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ItemCard(
              itemId: 'rusty_sword',
              name: 'Rusty Sword',
              rarity: ItemRarity.common,
              slot: EquipmentSlot.weapon,
            ),
          ),
        ),
      );

      expect(find.text('Rusty Sword'), findsOneWidget);
      expect(find.byType(PixelItemIcon), findsOneWidget);
    });

    testWidgets('ItemSlot menampilkan PixelItemIcon saat itemId diisi', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ItemSlot(
              itemId: 'small_potion',
              rarity: ItemRarity.common,
              category: ItemCategory.consumable,
              quantity: 5,
            ),
          ),
        ),
      );

      expect(find.text('x5'), findsOneWidget);
      expect(find.byType(PixelItemIcon), findsOneWidget);
    });

    testWidgets(
      'ResourceChip.gold dan aetherShard menyertakan sprite pixel art',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ResourceChip.gold(1250),
                  ResourceChip.aetherShard(42),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(ResourceChip), findsNWidgets(2));
        expect(find.byType(Image), findsNWidgets(2));
      },
    );
  });
}
