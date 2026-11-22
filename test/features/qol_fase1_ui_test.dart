import 'dart:math';

import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/blacksmith_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/features/dungeon/blacksmith_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_completed_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/run_ended_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:echoes_of_aether/widgets/game_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const progression = ProgressionConfig(
    maxLevel: 30,
    expBase: 100,
    expGrowth: 2.0,
    baseStats: CombatStats(maxHp: 100, atk: 10, def: 5),
    perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
  );

  const scrapDef = ItemDefinition(
    id: BlacksmithService.aetherScrapItemId,
    name: 'Aether Scrap',
    category: ItemCategory.material,
    maxStack: 999,
  );

  ItemDefinition makeWeaponDef(String id, ItemRarity rarity) => ItemDefinition(
    id: id,
    name: 'Weapon $id',
    category: ItemCategory.equipment,
    rarity: rarity,
    equipment: const EquipmentData(
      slot: EquipmentSlot.weapon,
      weaponType: 'sword',
      baseStats: EquipmentStats(atk: 15),
    ),
  );

  final items = <String, ItemDefinition>{
    scrapDef.id: scrapDef,
    'wp_common': makeWeaponDef('wp_common', ItemRarity.common),
    'wp_uncommon': makeWeaponDef('wp_uncommon', ItemRarity.uncommon),
    'wp_rare': makeWeaponDef('wp_rare', ItemRarity.rare),
  };

  const factory = EquipmentFactory(EquipmentConfig(rollVariance: 0.0));

  group('Fase 1 QoL UI Tests', () {
    testWidgets(
      'BlacksmithOverlay bulk salvage dialog previews eligible count and updates preset',
      (tester) async {
        final inv = Inventory(definitions: items);
        final char = PlayerCharacter(config: progression);
        final rng = Random(1);

        inv.addEquipment(
          factory.create(
            instanceId: 'c1',
            definition: items['wp_common']!,
            random: rng,
          ),
        );
        inv.addEquipment(
          factory
              .create(
                instanceId: 'c_fav',
                definition: items['wp_common']!,
                random: rng,
              )
              .copyWith(isFavorite: true),
        );
        inv.addEquipment(
          factory.create(
            instanceId: 'u1',
            definition: items['wp_uncommon']!,
            random: rng,
          ),
        );
        inv.addEquipment(
          factory
              .create(
                instanceId: 'u_enh',
                definition: items['wp_uncommon']!,
                random: rng,
              )
              .copyWith(enhancementLevel: 1),
        );
        inv.addEquipment(
          factory.create(
            instanceId: 'r1',
            definition: items['wp_rare']!,
            random: rng,
          ),
        );

        final views = InventoryViews(inventory: inv, character: char);
        Set<ItemRarity>? capturedRarities;

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: BlacksmithOverlay(
                snapshot: views.equipment,
                items: items,
                inventoryEntries: views.stacks,
                characterSnapshot: views.characterView,
                onEnhanceEquipment: (_) => const BlacksmithEnhanceResult(
                  status: BlacksmithEnhanceStatus.success,
                ),
                onReforgeEquipment: (_) => const BlacksmithReforgeResult(
                  status: BlacksmithReforgeStatus.success,
                ),
                onSalvageEquipment: (id) => const BlacksmithService()
                    .salvageEquipment(inventory: inv, instanceId: id),
                onSalvageEquipmentBulk: (rarities) {
                  capturedRarities = rarities;
                  final res = const BlacksmithService().salvageEquipmentBulk(
                    inventory: inv,
                    targetRarities: rarities,
                    loadout: char.loadout,
                  );
                  views.refresh();
                  return res;
                },
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Bongkar'));
        await tester.pumpAndSettle();

        final bulkBtn = find.byKey(const Key('blacksmith_bulk_salvage_button'));
        await tester.ensureVisible(bulkBtn);
        expect(bulkBtn, findsOneWidget);

        await tester.tap(bulkBtn);
        await tester.pumpAndSettle();

        // Default preset: Common + Uncommon -> c1 (+2) & u1 (+5) = 2 item, +7 Scrap.
        expect(find.text('Terpilih: 2 perlengkapan'), findsOneWidget);
        expect(find.text('Estimasi Hasil: +7 Aether Scrap'), findsOneWidget);

        // Pilih preset 'Semua ≤ Rare' -> tambah r1 (+12) = 3 item, +19 Scrap.
        await tester.tap(find.byKey(const Key('bulk_salvage_preset_2')));
        await tester.pumpAndSettle();
        expect(find.text('Terpilih: 3 perlengkapan'), findsOneWidget);
        expect(find.text('Estimasi Hasil: +19 Aether Scrap'), findsOneWidget);

        await tester.tap(find.byKey(const Key('bulk_salvage_confirm_button')));
        await tester.pumpAndSettle();

        expect(capturedRarities, {
          ItemRarity.common,
          ItemRarity.uncommon,
          ItemRarity.rare,
        });
        expect(
          find.textContaining(
            'Berhasil membongkar 3 perlengkapan (+19 Aether Scrap)',
          ),
          findsOneWidget,
        );
        expect(inv.equipmentById('c_fav'), isNotNull);
        expect(inv.equipmentById('u_enh'), isNotNull);
        expect(inv.equipmentById('c1'), isNull);
        expect(inv.equipmentById('u1'), isNull);
        expect(inv.equipmentById('r1'), isNull);
      },
    );

    testWidgets(
      'DungeonCompletedOverlay renders next-floor button on mobile portrait and invokes onNextFloor when provided',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var nextFloorTapped = false;
        var townTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: DungeonCompletedOverlay(
                dungeonName: 'Spire Floor 11',
                clearedRoomsCount: 1,
                nextFloorLabel: 'Lanjut Lantai 12',
                onNextFloor: () => nextFloorTapped = true,
                onReturnToTown: () => townTapped = true,
              ),
            ),
          ),
        );

        final nextBtn = find.byKey(
          const Key('dungeon_completed_next_floor_button'),
        );
        expect(nextBtn, findsOneWidget);
        expect(
          find.widgetWithText(GameButton, 'Lanjut Lantai 12'),
          findsOneWidget,
        );

        await tester.tap(nextBtn);
        await tester.pump();
        expect(nextFloorTapped, isTrue);
        expect(townTapped, isFalse);
      },
    );

    testWidgets(
      'RunEndedOverlay shows compact defeat summary on mobile portrait and hides it when omitted',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: RunEndedOverlay(
                onRetry: () {},
                onReturnToTown: () {},
                dungeonName: 'Abyssal Rift',
                progressText: 'Ruangan 2 / 5',
                levelComparisonText: 'Hero Lv 52 • Rek. Lv 65',
                adviceText: 'Tingkatkan level atau perkuat perlengkapan.',
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('run_ended_summary_panel')),
          findsOneWidget,
        );
        expect(find.text('RINGKASAN KEKALAHAN'), findsOneWidget);
        expect(find.text('Abyssal Rift'), findsOneWidget);
        expect(
          find.text('Ruangan 2 / 5 • Hero Lv 52 • Rek. Lv 65'),
          findsOneWidget,
        );
        expect(
          find.text('Tingkatkan level atau perkuat perlengkapan.'),
          findsOneWidget,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: RunEndedOverlay(onRetry: () {}, onReturnToTown: () {}),
            ),
          ),
        );

        expect(find.byKey(const Key('run_ended_summary_panel')), findsNothing);
      },
    );

    testWidgets(
      'TownHubView Spire quick access shows level recommendation under Lv 20 and standard subtitle at Lv 20+',
      (tester) async {
        final inv = Inventory(definitions: items);
        final lowChar = PlayerCharacter(
          config: progression,
          progress: const PlayerProgress(level: 5),
        );
        final lowViews = InventoryViews(inventory: inv, character: lowChar);

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: TownHubView(
                character: lowChar,
                views: lowViews,
                items: items,
                dungeonProgress: const DungeonProgressSnapshot(),
                dungeonDefinition: null,
                onEnterDungeon: () {},
                onEquip: (_) {},
                onUnequip: (_) {},
                onChooseSpecialization: (_) {},
                onOpenInfiniteSpire: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('quick_access_infinite_spire')),
          findsOneWidget,
        );
        expect(find.text('Rek. Lv 20+ • 100 Lt'), findsOneWidget);

        final highChar = PlayerCharacter(
          config: progression,
          progress: const PlayerProgress(level: 25),
        );
        final highViews = InventoryViews(inventory: inv, character: highChar);

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: TownHubView(
                character: highChar,
                views: highViews,
                items: items,
                dungeonProgress: const DungeonProgressSnapshot(),
                dungeonDefinition: null,
                onEnterDungeon: () {},
                onEquip: (_) {},
                onUnequip: (_) {},
                onChooseSpecialization: (_) {},
                onOpenInfiniteSpire: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('100 Lantai'), findsOneWidget);
        expect(find.text('Rek. Lv 20+ • 100 Lt'), findsNothing);
      },
    );
  });
}
