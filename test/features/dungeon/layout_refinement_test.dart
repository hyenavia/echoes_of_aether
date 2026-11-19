import 'dart:io';

import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/data/models/boss_spire_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/boss_spire.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/altar_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_service.dart';
import 'package:echoes_of_aether/features/dungeon/boss_events_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/boss_hub_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const progression = ProgressionConfig(
    maxLevel: 50,
    expBase: 100,
    expGrowth: 2.0,
    baseStats: CombatStats(maxHp: 120, atk: 20, def: 8),
    perLevel: LevelGrowth(hp: 12, atk: 3, def: 1),
  );

  const swordDef = ItemDefinition(
    id: 'iron_sword',
    name: 'Iron Sword',
    category: ItemCategory.equipment,
    rarity: ItemRarity.rare,
    equipment: EquipmentData(
      slot: EquipmentSlot.weapon,
      weaponType: 'sword',
      baseStats: EquipmentStats(atk: 18),
    ),
  );

  testWidgets(
    'TownHubView Quick Access hanya menampilkan 2 tombol (Boss & Gacha), Hero memiliki 3 sub-tab, dan Bag tidak menduplikasi Stat Tempur',
    (tester) async {
      final items = {'iron_sword': swordDef};
      final inv = Inventory(definitions: items);
      final char = PlayerCharacter(
        config: progression,
        progress: const PlayerProgress(level: 10, gold: 5000),
      );
      const sword = EquipmentInstance(
        id: 'eq_1',
        definitionId: 'iron_sword',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.rare,
        rolledStats: EquipmentStats(atk: 18),
      );
      inv.addEquipment(sword);
      final eqService = EquipmentService(inventory: inv, loadout: char.loadout);
      eqService.equip('eq_1');
      final views = InventoryViews(inventory: inv, character: char);

      var bossOpened = false;
      var gachaOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: Scaffold(
            body: TownHubView(
              character: char,
              views: views,
              items: items,
              dungeonProgress: const DungeonProgressSnapshot(),
              dungeonDefinition: null,
              onEnterDungeon: () {},
              onEquip: (id) {
                if (eqService.equip(id)) views.refresh();
              },
              onUnequip: (slot) {
                if (eqService.unequip(slot)) views.refresh();
              },
              onChooseSpecialization: (_) {},
              onOpenBossEvents: () => bossOpened = true,
              onOpenGacha: () => gachaOpened = true,
              getAltarBalances: () => const {},
              onUpgradeAltarBlessing: (_) => const AltarUpgradeResult(
                status: AltarUpgradeStatus.success,
                newLevel: 1,
                goldSpent: 100,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hanya 2 tombol di Quick Access Town: Boss & Gacha
      expect(find.byKey(const Key('quick_access_boss')), findsOneWidget);
      expect(find.byKey(const Key('quick_access_gacha')), findsOneWidget);
      expect(find.byKey(const Key('quick_access_altar')), findsNothing);
      expect(find.byKey(const Key('quick_access_spire')), findsNothing);
      expect(find.byKey(const Key('quick_access_hero')), findsNothing);
      expect(find.byKey(const Key('quick_access_blacksmith')), findsNothing);

      await tester.tap(find.byKey(const Key('quick_access_boss')));
      await tester.pump();
      expect(bossOpened, isTrue);

      await tester.tap(find.byKey(const Key('quick_access_gacha')));
      await tester.pump();
      expect(gachaOpened, isTrue);

      // Tab Hero -> 3 sub-tab: Profil & Gear, Kelas & Skill, Altar
      await tester.tap(find.text('Hero'));
      await tester.pumpAndSettle();
      expect(find.text('Profil & Gear'), findsOneWidget);
      expect(find.text('Kelas & Skill'), findsOneWidget);
      expect(find.text('Altar'), findsOneWidget);
      expect(find.text('Stat Tempur'), findsOneWidget);
      expect(find.text('Perlengkapan Terpasang'), findsOneWidget);
      expect(find.text('Iron Sword'), findsOneWidget);

      // Pindah ke sub-tab Altar di dalam Hero
      await tester.tap(find.text('Altar'));
      await tester.pumpAndSettle();
      expect(find.text('Camp Altar'), findsOneWidget);

      // Tab Bag -> Equipment tidak menduplikasi Stat Tempur / Terpasang
      await tester.tap(find.text('Bag'));
      await tester.pumpAndSettle();
      expect(find.text('Stat Tempur'), findsNothing);
      expect(find.text('Terpasang'), findsNothing);
      expect(find.text('Tas perlengkapan (0)'), findsOneWidget);
    },
  );

  testWidgets(
    'BossHubOverlay menggabungkan Daily & Weekly Boss dengan Menara Bos dalam 1 overlay',
    (tester) async {
      var dailyFought = false;
      var spireFloorFought = -1;
      var closed = false;

      final spireConfig = const BossSpireConfigParser().parse(
        File('assets/data/boss_spire.json').readAsStringSync(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: Scaffold(
            body: BossHubOverlay(
              daily: BossEventCardData(
                periodKeyId: 'daily',
                periodLabel: 'Daily Boss',
                bossName: 'Forest Guardian',
                referenceDungeonName: 'Forgotten Forest',
                recommendedLevel: 5,
                isCompleted: false,
                remainingToReset: const Duration(hours: 3),
                rewardSummary: '10 Aether Shard',
                onFight: () => dailyFought = true,
              ),
              weekly: BossEventCardData(
                periodKeyId: 'weekly',
                periodLabel: 'Weekly Boss',
                bossName: 'Void Tyrant',
                referenceDungeonName: 'Shadow Abyss',
                recommendedLevel: 25,
                isCompleted: false,
                remainingToReset: const Duration(days: 2),
                rewardSummary: '50 Aether Shard',
                onFight: () {},
              ),
              spireConfig: spireConfig,
              spireProgress: const BossSpireProgress(
                highestClearedFloor: 0,
                clearedFloors: {},
              ),
              playerLevel: 12,
              onFightSpireFloor: (floor) => spireFloorFought = floor,
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily & Weekly'), findsOneWidget);
      expect(find.text('Menara'), findsOneWidget);
      expect(find.text('Forest Guardian'), findsOneWidget);
      expect(find.text('Void Tyrant'), findsOneWidget);

      await tester.tap(find.byKey(const Key('boss_fight_daily')));
      await tester.pump();
      expect(dailyFought, isTrue);

      // Pindah ke tab Menara
      await tester.tap(find.text('Menara'));
      await tester.pumpAndSettle();
      expect(find.text(spireConfig.name), findsOneWidget);

      await tester.tap(find.byKey(const Key('spire_fight_1')));
      await tester.pump();
      expect(spireFloorFought, 1);

      await tester.tap(find.byKey(const Key('boss_hub_close')));
      await tester.pump();
      expect(closed, isTrue);
    },
  );
}
