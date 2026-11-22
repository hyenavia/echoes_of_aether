import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/hero_ascension.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loot_table.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/features/dungeon/codex_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const progression = ProgressionConfig(
    maxLevel: 90,
    expBase: 100,
    expGrowth: 2.0,
    baseStats: CombatStats(maxHp: 100, atk: 10, def: 5),
    perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
  );

  final sampleConfig = GameConfig(
    monsters: const {
      'abyssal_archon': EnemyDefinition(
        id: 'abyssal_archon',
        name: 'Abyssal Archon',
        level: 68,
        stats: CombatStats(maxHp: 2800, atk: 35, def: 10),
        isBoss: true,
        lootTableId: 'abyssal_boss_loot',
      ),
    },
    revive: const ReviveConfig(),
    progression: progression,
    items: const {
      'dawns_aegis_blade': ItemDefinition(
        id: 'dawns_aegis_blade',
        name: "Dawn's Aegis Blade",
        category: ItemCategory.equipment,
        rarity: ItemRarity.mythical,
        equipment: EquipmentData(
          slot: EquipmentSlot.weapon,
          baseStats: EquipmentStats(atk: 120),
          signatureClassId: 'paladin',
          resonanceDescription: 'Memicu Holy Nova pemulihan HP saat memblokir.',
        ),
      ),
      'abyssal_remnant': ItemDefinition(
        id: 'abyssal_remnant',
        name: 'Abyssal Remnant',
        category: ItemCategory.material,
        rarity: ItemRarity.epic,
      ),
    },
    lootTables: const {
      'abyssal_boss_loot': LootTable(
        id: 'abyssal_boss_loot',
        entries: [LootEntry(itemId: 'abyssal_remnant', chance: 1.0)],
      ),
    },
    specializations: const SpecializationConfig(
      definitions: {
        'paladin': SpecializationDefinition(
          id: 'paladin',
          name: 'Paladin',
          rarity: ItemRarity.mythical,
          signatureWeaponId: 'dawns_aegis_blade',
          bonus: EquipmentStats(hp: 100),
        ),
      },
    ),
    dungeons: const {
      'abyssal_rift': DungeonDefinition(
        id: 'abyssal_rift',
        name: 'The Abyssal Rift',
        biome: 'abyssal_rift',
        startRoomId: 'core',
        roomOrder: ['core'],
        rooms: {
          'core': RoomDefinition(
            id: 'core',
            dungeonId: 'abyssal_rift',
            name: 'Abyssal Core',
            type: RoomType.boss,
            mapRef: 'map_core',
            layout: ['###', '#.#', '###'],
            entryPosition: GridPoint(1, 1),
            exitPosition: GridPoint(1, 1),
            spawns: [
              RoomSpawnConfig(
                id: 'boss_1',
                monsterId: 'abyssal_archon',
                position: GridPoint(1, 1),
              ),
            ],
            completionCondition: RoomCompletionCondition(
              type: RoomCompletionConditionType.defeatBoss,
            ),
          ),
        },
        completionReward: DungeonCompletionReward(
          lootTableId: 'abyssal_boss_loot',
        ),
      ),
    },
    heroAscension: const HeroAscensionConfig(
      phases: [
        HeroAscensionPhaseDefinition(
          phase: 5,
          levelCap: 80,
          requiredPlayerLevel: 70,
          cost: HeroAscensionCost(items: {'abyssal_remnant': 3}),
        ),
      ],
    ),
  );

  group('Fase 2 Stage 2 — Codex UI Tests', () {
    testWidgets(
      'CodexOverlay switches between Resonansi and Material & Drop cleanly on 360x640',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: CodexOverlay(
                config: sampleConfig,
                unlockedSpecializations: const {'paladin'},
                inventoryQuantitiesProvider: () => const {'abyssal_remnant': 7},
                embedded: true,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Codex & Panduan'), findsOneWidget);
        expect(find.text('Paladin'), findsOneWidget);
        expect(find.text('Terbuka'), findsOneWidget);
        expect(
          find.text("Senjata Signature: Dawn's Aegis Blade"),
          findsOneWidget,
        );
        expect(
          find.text('Memicu Holy Nova pemulihan HP saat memblokir.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Material & Drop'));
        await tester.pumpAndSettle();

        expect(find.text('Abyssal Remnant'), findsOneWidget);
        expect(find.text('Dimiliki: 7'), findsOneWidget);
        expect(find.text('Dipakai untuk Terobosan: A5'), findsOneWidget);
        expect(find.text('The Abyssal Rift (Clear)'), findsOneWidget);
        expect(find.text('100%'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'TownHubView Hero tab shows Codex sub-tab and renders CodexOverlay',
      (tester) async {
        final inv = Inventory(definitions: sampleConfig.items);
        final char = PlayerCharacter(config: progression);
        final views = InventoryViews(inventory: inv, character: char);

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: TownHubView(
                character: char,
                views: views,
                items: sampleConfig.items,
                dungeonProgress: const DungeonProgressSnapshot(),
                dungeonDefinition: null,
                onEnterDungeon: () {},
                onEquip: (_) {},
                onUnequip: (_) {},
                onChooseSpecialization: (_) {},
                codexConfig: sampleConfig,
                unlockedSpecializations: const {'paladin'},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Hero'));
        await tester.pumpAndSettle();

        expect(find.text('Codex'), findsOneWidget);
        await tester.tap(find.text('Codex'));
        await tester.pumpAndSettle();

        expect(find.byType(CodexOverlay), findsOneWidget);
        expect(find.text('Codex & Panduan'), findsOneWidget);
      },
    );

    testWidgets(
      'TownHubView Codex renders without error when inventory has stacks and shows owned quantity',
      (tester) async {
        final inv = Inventory(definitions: sampleConfig.items);
        inv.add('abyssal_remnant', 12);
        final char = PlayerCharacter(config: progression);
        final views = InventoryViews(inventory: inv, character: char);

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: TownHubView(
                character: char,
                views: views,
                items: sampleConfig.items,
                dungeonProgress: const DungeonProgressSnapshot(),
                dungeonDefinition: null,
                onEnterDungeon: () {},
                onEquip: (_) {},
                onUnequip: (_) {},
                onChooseSpecialization: (_) {},
                codexConfig: sampleConfig,
                unlockedSpecializations: const {'paladin'},
                inventoryQuantitiesProvider: () => {
                  for (final stack in inv.snapshot())
                    stack.definition.id: stack.quantity,
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Hero'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Codex'));
        await tester.pumpAndSettle();

        expect(find.byType(ErrorWidget), findsNothing);
        expect(find.byType(CodexOverlay), findsOneWidget);
        expect(find.text('Codex & Panduan'), findsOneWidget);

        await tester.tap(find.text('Material & Drop'));
        await tester.pumpAndSettle();

        expect(find.text('Abyssal Remnant'), findsOneWidget);
        expect(find.text('Dimiliki: 12'), findsOneWidget);
      },
    );
  });
}
