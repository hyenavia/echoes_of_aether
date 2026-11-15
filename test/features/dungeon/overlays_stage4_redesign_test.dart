import 'dart:io';

import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/game_settings.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:echoes_of_aether/features/dungeon/character_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/equipment_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/inventory_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/offline_summary_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/settings_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/shop_overlay.dart';
import 'package:echoes_of_aether/features/shared/widgets/shared_widgets.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  return GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(
      _readAsset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
    shop: const ShopConfigParser().parse(_readAsset('shop.json')),
  );
}

Widget _wrapViewport(Widget child, Size size, double textScale) {
  return MaterialApp(
    theme: EchoesTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  const baseStats = CombatStats(
    maxHp: 320,
    atk: 46,
    def: 18,
    critRate: 0.14,
    critDamage: 1.75,
    attackSpeed: 1.2,
    moveSpeed: 95,
    attackRange: 52,
  );

  const specs = [
    SpecializationDefinition(
      id: 'vanguard',
      name: 'Vanguard',
      description: 'Benteng baja di garis depan dungeon.',
      bonus: EquipmentStats(hp: 60, def: 12),
      attackRange: 52,
      skillAffinities: {'power_strike': 0.2},
    ),
    SpecializationDefinition(
      id: 'arcanist',
      name: 'Arcanist',
      description: 'Pengendali kristal Aether dengan burst magis.',
      bonus: EquipmentStats(atk: 16, skillHaste: 0.15),
      attackRange: 130,
      skillAffinities: {'aether_bolt': 0.25},
    ),
    SpecializationDefinition(
      id: 'ranger',
      name: 'Ranger',
      description: 'Pemanah lincah dengan crit dan attack speed tinggi.',
      bonus: EquipmentStats(atk: 12, critRate: 0.08),
      attackRange: 140,
      skillAffinities: {'rapid_shot': 0.25},
    ),
  ];

  const sampleSkill = SkillDefinition(
    id: 'power_strike',
    name: 'Power Strike',
    type: SkillType.active,
    effect: SkillEffectType.damage,
    targetType: SkillTarget.single,
    cooldownSeconds: 4,
    unlockLevel: 1,
    maxLevel: 3,
    upgradeCost: 50,
    damageMultiplier: 1.8,
  );

  testWidgets(
    'Stage 4: CharacterOverlay menampilkan CampBackdrop, CharacterIllustration sesuai class, dan bebas overflow',
    (tester) async {
      for (final specId in [null, 'vanguard', 'arcanist', 'ranger']) {
        final expectedId = specId ?? 'base';
        final snapshot = ValueNotifier(
          CharacterSnapshot(
            level: 12,
            gold: 2450,
            stats: baseStats,
            specializationId: specId,
            canChooseSpecialization: true,
            specializationUnlockLevel: 5,
            specializations: specs,
            skills: const [
              SkillEntry(
                sampleSkill,
                unlocked: true,
                level: 2,
                nextUpgradeCost: 100,
                canUpgrade: true,
              ),
            ],
          ),
        );

        for (final viewport in [
          (size: const Size(320, 568), scale: 1.5),
          (size: const Size(960, 720), scale: 1.0),
        ]) {
          await tester.binding.setSurfaceSize(viewport.size);
          await tester.pumpWidget(
            _wrapViewport(
              CharacterOverlay(
                snapshot: snapshot,
                onChooseSpecialization: (_) {},
                onUpgradeSkill: (_) {},
                onClose: () {},
              ),
              viewport.size,
              viewport.scale,
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('character_profile_banner')),
            findsOneWidget,
          );
          expect(find.byType(CampBackdrop), findsOneWidget);
          final illustration = tester.widget<CharacterIllustration>(
            find.byType(CharacterIllustration),
          );
          expect(illustration.specializationId, expectedId);
          expect(find.textContaining('Combat Power:'), findsOneWidget);
        }
        snapshot.dispose();
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'Stage 4: EquipmentOverlay & InventoryOverlay bebas overflow di 320x568@1.5x dan 960x720',
    (tester) async {
      const items = <String, ItemDefinition>{
        'iron_sword': ItemDefinition(
          id: 'iron_sword',
          name: 'Iron Sword of Aether',
          category: ItemCategory.equipment,
          rarity: ItemRarity.rare,
        ),
        'runic_blade': ItemDefinition(
          id: 'runic_blade',
          name: 'Runic Blade of the Ancient Grove',
          category: ItemCategory.equipment,
          rarity: ItemRarity.epic,
        ),
      };
      const sword = EquipmentInstance(
        id: 'eq_sword_1',
        definitionId: 'iron_sword',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.rare,
        rolledStats: EquipmentStats(atk: 18, critRate: 0.04),
      );
      const bagSword = EquipmentInstance(
        id: 'eq_sword_2',
        definitionId: 'runic_blade',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.epic,
        rolledStats: EquipmentStats(atk: 28, critRate: 0.06, critDamage: 0.15),
      );
      final equipSnap = ValueNotifier(
        const EquipmentSnapshot(
          stats: baseStats,
          equipped: {EquipmentSlot.weapon: sword},
          bag: [bagSword],
        ),
      );
      final emptyEquipSnap = ValueNotifier(
        const EquipmentSnapshot(stats: baseStats, equipped: {}, bag: []),
      );
      final stacksSnap = ValueNotifier<List<InventoryEntry>>([
        const InventoryEntry(
          ItemDefinition(
            id: 'slime_gel',
            name: 'Crystal Slime Gel',
            category: ItemCategory.material,
            rarity: ItemRarity.uncommon,
          ),
          14,
        ),
      ]);
      final emptyStacksSnap = ValueNotifier<List<InventoryEntry>>([]);

      for (final viewport in [
        (size: const Size(320, 568), scale: 1.5),
        (size: const Size(960, 720), scale: 1.0),
      ]) {
        await tester.binding.setSurfaceSize(viewport.size);

        await tester.pumpWidget(
          _wrapViewport(
            EquipmentOverlay(
              snapshot: equipSnap,
              items: items,
              onEquip: (_) {},
              onUnequip: (_) {},
              onClose: () {},
            ),
            viewport.size,
            viewport.scale,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(EquipmentSlotTile), findsNWidgets(3));
        expect(find.textContaining('Tas perlengkapan (1)'), findsOneWidget);

        await tester.pumpWidget(
          _wrapViewport(
            EquipmentOverlay(
              snapshot: emptyEquipSnap,
              items: items,
              onEquip: (_) {},
              onUnequip: (_) {},
              onClose: () {},
            ),
            viewport.size,
            viewport.scale,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(EmptyState), findsOneWidget);

        await tester.pumpWidget(
          _wrapViewport(
            InventoryOverlay(entries: stacksSnap, onClose: () {}),
            viewport.size,
            viewport.scale,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('x14'), findsOneWidget);

        await tester.pumpWidget(
          _wrapViewport(
            InventoryOverlay(entries: emptyStacksSnap, onClose: () {}),
            viewport.size,
            viewport.scale,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(EmptyState), findsOneWidget);
      }

      equipSnap.dispose();
      emptyEquipSnap.dispose();
      stacksSnap.dispose();
      emptyStacksSnap.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'Stage 4: ShopOverlay, SettingsOverlay, dan OfflineSummaryOverlay bebas overflow di 320x568@1.5x dan 390x844',
    (tester) async {
      final config = _loadRealConfig();
      final character = PlayerCharacter(
        config: config.progression,
        skillCatalog: config.skills,
      )..receiveReward(gold: 1500);
      final inventory = Inventory(definitions: config.items)
        ..add('slime_gel', 5);
      final views = InventoryViews(character: character, inventory: inventory);
      final shopService = ShopService(
        catalog: config.shop,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      final settingsNotifier = ValueNotifier(const GameSettingsData());
      const summary = OfflineSummarySnapshot(
        eventId: 'offline:stage4',
        mode: OfflineActivityMode.autoFarming,
        finalState: OfflineActivityState.completed,
        effectiveElapsedMs: 3600000,
        cappedAtMaxDuration: false,
        runsAttempted: 2,
        runsCompleted: 2,
        runsFailed: 0,
        roomsCleared: 10,
        encountersCleared: 18,
        expGained: 950,
        goldGained: 480,
        levelsGained: 1,
        addedStacks: {'slime_gel': 8},
        addedEquipmentCount: 1,
      );
      const dungeons = <String, DungeonDefinition>{
        'forgotten_forest': DungeonDefinition(
          id: 'forgotten_forest',
          name: 'Forgotten Forest',
          biome: 'Forest',
          startRoomId: 'r1',
          rooms: {},
          roomOrder: ['r1'],
        ),
      };

      for (final viewport in [
        (size: const Size(320, 568), scale: 1.5),
        (size: const Size(390, 844), scale: 1.0),
      ]) {
        await tester.binding.setSurfaceSize(viewport.size);

        await tester.pumpWidget(
          _wrapViewport(
            ShopOverlay(
              catalog: config.shop,
              items: config.items,
              dungeons: dungeons,
              playerGold: 1500,
              playerContext: const ShopPlayerContext(playerLevel: 10),
              shopService: shopService,
              views: views,
              onBuy: (_) async => const ShopBuyNotFound(entryId: 'x'),
              onSellEquipment: (_) async =>
                  const ShopSellNotFound(targetId: 'x'),
              onSellMaterialBulk: (_, _) async =>
                  const ShopSellNotFound(targetId: 'x'),
              onClose: () {},
            ),
            viewport.size,
            viewport.scale,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Jual'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _wrapViewport(
            SettingsOverlay(
              settings: settingsNotifier,
              onChanged: (_) {},
              onTestSfx: () {},
              onClose: () {},
            ),
            viewport.size,
            viewport.scale,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Tes Suara'), findsOneWidget);

        await tester.pumpWidget(
          _wrapViewport(
            Stack(
              children: [
                OfflineSummaryOverlay(
                  summary: summary,
                  items: config.items,
                  dungeons: dungeons,
                  selectedDungeonId: 'forgotten_forest',
                  onAcknowledge: () {},
                ),
              ],
            ),
            viewport.size,
            viewport.scale,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Tutup & Simpan'), findsOneWidget);
      }

      settingsNotifier.dispose();
      await tester.binding.setSurfaceSize(null);
    },
  );
}
