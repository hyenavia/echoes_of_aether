import 'package:echoes_of_aether/domain/entities/altar_blessing.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/altar_service.dart';
import 'package:echoes_of_aether/features/dungeon/altar_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const progression = ProgressionConfig(
    maxLevel: 10,
    expBase: 100,
    expGrowth: 2.0,
    baseStats: CombatStats(maxHp: 100, atk: 10, def: 5),
    perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
  );

  Widget createSubject({
    required InventoryViews views,
    required Map<String, int> Function() getBalances,
    required AltarUpgradeResult Function(AltarBlessingType) onUpgrade,
    VoidCallback? onClose,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AltarOverlay(
          characterSnapshot: views.characterView,
          getBalances: getBalances,
          onUpgradeBlessing: onUpgrade,
          onClose: onClose ?? () {},
        ),
      ),
    );
  }

  testWidgets(
    'AltarOverlay displays header, player gold, 4 blessing cards, summary chips, close button',
    (tester) async {
      final inv = Inventory(definitions: const {});
      final char = PlayerCharacter(
        config: progression,
        progress: const PlayerProgress(level: 1, gold: 50000),
      );
      final views = InventoryViews(inventory: inv, character: char);

      await tester.pumpWidget(
        createSubject(
          views: views,
          getBalances: () => {'altar_might': 2, 'altar_vitality': 1},
          onUpgrade: (_) =>
              const AltarUpgradeResult(status: AltarUpgradeStatus.success),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Camp Altar'), findsOneWidget);
      expect(
        find.text('Persembahkan Gold untuk berkah permanen'),
        findsOneWidget,
      );
      expect(find.text('50K'), findsOneWidget); // 50,000 gold
      expect(find.byKey(const Key('altar_close_button')), findsOneWidget);

      // 4 Blessing Cards
      expect(find.text('Berkah Kekuatan'), findsOneWidget);
      expect(find.text('Berkah Vitalitas'), findsOneWidget);
      expect(find.text('Berkah Perlindungan'), findsOneWidget);
      expect(find.text('Berkah Kemakmuran'), findsOneWidget);

      // Level indicators
      expect(find.text('Lv. 2/20'), findsOneWidget); // Might
      expect(find.text('Lv. 1/20'), findsOneWidget); // Vitality
      expect(find.text('Lv. 0/20'), findsNWidgets(2)); // Aegis & Fortune

      // Summary banner
      expect(find.text('+20 HP'), findsOneWidget);
      expect(find.text('+4 ATK'), findsOneWidget);
      expect(find.text('0 DEF'), findsOneWidget);
      expect(find.text('0% Gold'), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping upgrade button calls onUpgradeBlessing and displays success message',
    (tester) async {
      final inv = Inventory(definitions: const {});
      final char = PlayerCharacter(
        config: progression,
        progress: const PlayerProgress(level: 1, gold: 50000),
      );
      final views = InventoryViews(inventory: inv, character: char);

      AltarBlessingType? upgradedType;

      await tester.pumpWidget(
        createSubject(
          views: views,
          getBalances: () => {},
          onUpgrade: (type) {
            upgradedType = type;
            return AltarUpgradeResult(
              status: AltarUpgradeStatus.success,
              blessingType: type,
              newLevel: 1,
              goldSpent: 10000,
              remainingGold: 40000,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final upgradeMightBtn = find.byKey(const Key('altar_upgrade_might'));
      expect(upgradeMightBtn, findsOneWidget);

      await tester.tap(upgradeMightBtn);
      await tester.pumpAndSettle();

      expect(upgradedType, AltarBlessingType.might);
      expect(
        find.text('Sukses! Berkah Kekuatan berhasil ditingkatkan ke Lv. 1.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Upgrade button is disabled when player gold is insufficient', (
    tester,
  ) async {
    final inv = Inventory(definitions: const {});
    final char = PlayerCharacter(
      config: progression,
      progress: const PlayerProgress(level: 1, gold: 1000), // Butuh 10k
    );
    final views = InventoryViews(inventory: inv, character: char);

    await tester.pumpWidget(
      createSubject(
        views: views,
        getBalances: () => {},
        onUpgrade: (_) => const AltarUpgradeResult(
          status: AltarUpgradeStatus.insufficientGold,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final btnFinder = find.byKey(const Key('altar_upgrade_might'));
    expect(btnFinder, findsOneWidget);

    final button = tester.widget<ElevatedButton>(btnFinder);
    expect(button.onPressed, isNull); // Disabled
  });

  testWidgets(
    'Card displays MAKSIMUM and disabled state when blessing is level 20',
    (tester) async {
      final inv = Inventory(definitions: const {});
      final char = PlayerCharacter(
        config: progression,
        progress: const PlayerProgress(level: 1, gold: 999999999),
      );
      final views = InventoryViews(inventory: inv, character: char);

      await tester.pumpWidget(
        createSubject(
          views: views,
          getBalances: () => {'altar_might': 20},
          onUpgrade: (_) => const AltarUpgradeResult(
            status: AltarUpgradeStatus.maxLevelReached,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lv. 20/20'), findsOneWidget);
      expect(find.text('MAKSIMUM'), findsOneWidget);
      expect(find.byKey(const Key('altar_upgrade_might')), findsNothing);
    },
  );

  testWidgets('Tapping close button calls onClose', (tester) async {
    final inv = Inventory(definitions: const {});
    final char = PlayerCharacter(config: progression);
    final views = InventoryViews(inventory: inv, character: char);

    var closed = false;

    await tester.pumpWidget(
      createSubject(
        views: views,
        getBalances: () => {},
        onUpgrade: (_) =>
            const AltarUpgradeResult(status: AltarUpgradeStatus.success),
        onClose: () => closed = true,
      ),
    );
    await tester.pumpAndSettle();

    final closeBtn = find.byKey(const Key('altar_close_button'));
    expect(closeBtn, findsOneWidget);

    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });

  testWidgets('TownHubView Hero tab -> Altar sub-tab triggers Altar', (
    tester,
  ) async {
    final inv = Inventory(definitions: const {});
    final char = PlayerCharacter(config: progression);
    final views = InventoryViews(inventory: inv, character: char);

    var altarOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TownHubView(
            character: char,
            views: views,
            items: const {},
            dungeonProgress: const DungeonProgressSnapshot(),
            dungeonDefinition: null,
            onEnterDungeon: () {},
            onEquip: (_) {},
            onUnequip: (_) {},
            onChooseSpecialization: (_) {},
            onOpenAltar: () => altarOpened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Altar sudah dipindah dari Quick Access Town ke sub-tab Hero.
    expect(find.byKey(const Key('quick_access_altar')), findsNothing);

    await tester.tap(find.text('Hero'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Altar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buka Altar'));
    await tester.pumpAndSettle();

    expect(altarOpened, isTrue);
  });
}
