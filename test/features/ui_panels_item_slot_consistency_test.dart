import 'package:echoes_of_aether/app/theme/app_tokens.dart';
import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/features/shared/widgets/item_card.dart';
import 'package:echoes_of_aether/features/shared/widgets/item_slot.dart';
import 'package:echoes_of_aether/features/shared/widgets/panel_frame.dart';
import 'package:echoes_of_aether/features/shared/widgets/pixel_ui_box.dart';
import 'package:echoes_of_aether/features/shared/widgets/rarity_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapWithTheme(
    Widget child, {
    double width = 400,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      theme: EchoesTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SizedBox(
            width: width,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
  }

  group('RarityBorder Tiered Decoration & Shadows', () {
    testWidgets(
      'Decoration menghasilkan tiered glow berjenjang untuk setiap rarity',
      (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          wrapWithTheme(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        );

        // Common & Uncommon: tidak memiliki glow secara default
        final commonDec = RarityBorder.decoration(
          capturedContext,
          rarity: ItemRarity.common,
        );
        expect(commonDec.boxShadow, isNull);

        final uncommonDec = RarityBorder.decoration(
          capturedContext,
          rarity: ItemRarity.uncommon,
        );
        expect(uncommonDec.boxShadow, isNull);

        // Rare: memiliki ethereal Aether blue glow
        final rareDec = RarityBorder.decoration(
          capturedContext,
          rarity: ItemRarity.rare,
        );
        expect(rareDec.boxShadow, isNotNull);
        expect(rareDec.boxShadow!.first.blurRadius, 5.0);

        // Epic: memiliki mystical Arcane violet glow
        final epicDec = RarityBorder.decoration(
          capturedContext,
          rarity: ItemRarity.epic,
        );
        expect(epicDec.boxShadow, isNotNull);
        expect(epicDec.boxShadow!.first.blurRadius, 6.0);

        // Legendary: memiliki radiant Antique Gold aura dengan border lebih tebal
        final legDec = RarityBorder.decoration(
          capturedContext,
          rarity: ItemRarity.legendary,
        );
        expect(legDec.boxShadow, isNotNull);
        expect(legDec.boxShadow!.first.blurRadius, 8.0);
        expect((legDec.border! as Border).top.width, 1.8);
      },
    );

    testWidgets('Selected dan Locked state mengoverride tiered glow', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      // Selected: border emas tebal (accent 2.0) dan glow emas
      final selectedDec = RarityBorder.decoration(
        capturedContext,
        rarity: ItemRarity.common,
        isSelected: true,
      );
      expect(selectedDec.boxShadow, isNotNull);
      expect((selectedDec.border! as Border).top.width, AppBorders.accent);

      // Locked: tidak ada glow sama sekali
      final lockedDec = RarityBorder.decoration(
        capturedContext,
        rarity: ItemRarity.legendary,
        isLocked: true,
      );
      expect(lockedDec.boxShadow, isNull);

      // allowTieredGlow = false menonaktifkan glow default
      final noTieredDec = RarityBorder.decoration(
        capturedContext,
        rarity: ItemRarity.legendary,
        allowTieredGlow: false,
      );
      expect(noTieredDec.boxShadow, isNull);
    });
  });

  group('ItemSlot Widget Consistency', () {
    testWidgets(
      'Merender seluruh rarity (${ItemRarity.values.length}) dengan ikon dan quantity badge',
      (tester) async {
        var slotTapped = false;
        await tester.pumpWidget(
          wrapWithTheme(
            Row(
              children: [
                for (final rarity in ItemRarity.values)
                  ItemSlot(
                    rarity: rarity,
                    slot: EquipmentSlot.weapon,
                    quantity: rarity == ItemRarity.legendary ? 5 : 1,
                    onTap: () => slotTapped = true,
                  ),
              ],
            ),
          ),
        );

        expect(find.byType(ItemSlot), findsNWidgets(ItemRarity.values.length));
        expect(find.text('x5'), findsOneWidget);

        await tester.tap(find.byType(ItemSlot).first);
        expect(slotTapped, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Slot terkunci menampilkan gembok dan tanpa glow', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const ItemSlot(
            rarity: ItemRarity.epic,
            category: ItemCategory.material,
            isLocked: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('EquipmentSlotTile Widget Consistency', () {
    testWidgets('Merender status terpasang dan kosong dengan konsisten', (
      tester,
    ) async {
      var tileTapped = false;
      await tester.pumpWidget(
        wrapWithTheme(
          Column(
            children: [
              EquipmentSlotTile(
                slot: EquipmentSlot.weapon,
                slotLabel: 'Senjata Utama',
                itemName: 'Pedang Aether',
                rarity: ItemRarity.legendary,
                statsSummary: 'ATK +85, CRIT +12%',
                onTap: () => tileTapped = true,
              ),
              const EquipmentSlotTile(
                slot: EquipmentSlot.head,
                slotLabel: 'Helm',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Senjata Utama'), findsOneWidget);
      expect(find.text('Pedang Aether'), findsOneWidget);
      expect(find.text('ATK +85, CRIT +12%'), findsOneWidget);
      expect(find.text('Kosong'), findsOneWidget);

      await tester.tap(find.text('Pedang Aether'));
      expect(tileTapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('PanelFrame & PanelFrame.pixel Consistency', () {
    testWidgets('PanelFrame standar dan pixel 9-slice merender dengan mulus', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const Column(
            children: [
              PanelFrame(
                showCornerOrnaments: true,
                child: Text('Standar Panel'),
              ),
              SizedBox(height: 12),
              PanelFrame.pixel(
                pixelStyle: PixelUiBoxStyle.darkStoneFrame,
                child: Text('Pixel Stone Panel'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Standar Panel'), findsOneWidget);
      expect(find.text('Pixel Stone Panel'), findsOneWidget);
      expect(find.byType(PixelUiBox), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Responsive Layout Stress Test (320dp & 1.5x Text Scale)', () {
    testWidgets(
      'Seluruh komponen Stage 6 tidak overflow di layar sempit 320dp',
      (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            width: 320,
            textScale: 1.5,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PanelFrame(
                  showCornerOrnaments: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inventory & Equipment Overview'),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ItemSlot(
                            rarity: ItemRarity.common,
                            slot: EquipmentSlot.weapon,
                          ),
                          ItemSlot(
                            rarity: ItemRarity.uncommon,
                            slot: EquipmentSlot.head,
                          ),
                          ItemSlot(
                            rarity: ItemRarity.rare,
                            slot: EquipmentSlot.body,
                          ),
                          ItemSlot(
                            rarity: ItemRarity.epic,
                            slot: EquipmentSlot.accessory,
                          ),
                          ItemSlot(
                            rarity: ItemRarity.legendary,
                            slot: EquipmentSlot.weapon,
                            quantity: 99,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const EquipmentSlotTile(
                  slot: EquipmentSlot.weapon,
                  slotLabel: 'Weapon Slot',
                  itemName: 'Sunfire Greatsword of the Radiant Dawn',
                  rarity: ItemRarity.legendary,
                  statsSummary: 'ATK +140, CRIT +25%, ASPD +15%',
                ),
                const SizedBox(height: 12),
                ItemCard(
                  name: 'Celestial Robe of Transcendence',
                  rarity: ItemRarity.epic,
                  slot: EquipmentSlot.body,
                  statsSummary: 'DEF +85, HP +420, HASTE +18%',
                  subtitle: 'Syarat: Arcanist Ascension Rank 3',
                  isLocked: true,
                  lockedReason: 'Kalahkan Boss Crypt',
                  trailing: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Equip'),
                  ),
                ),
              ],
            ),
          ),
        );

        expect(
          find.text('Sunfire Greatsword of the Radiant Dawn'),
          findsOneWidget,
        );
        expect(find.text('Celestial Robe of Transcendence'), findsOneWidget);
        expect(find.text('x99'), findsOneWidget);
        expect(find.byType(ItemSlot), findsNWidgets(5));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
