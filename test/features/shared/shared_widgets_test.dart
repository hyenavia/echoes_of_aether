import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_settings.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/features/dungeon/settings_overlay.dart';
import 'package:echoes_of_aether/features/shared/widgets/shared_widgets.dart';
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

  testWidgets('RarityLabel dan ItemCard menampilkan seluruh rarity dan warna', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Column(
          children: [
            for (final rarity in ItemRarity.values)
              ItemCard(
                name: 'Item ${rarity.name}',
                rarity: rarity,
                slot: EquipmentSlot.weapon,
                statsSummary: 'ATK +15, CRIT +5%',
                subtitle: 'Harga 1.2K Gold',
              ),
          ],
        ),
      ),
    );

    for (final rarity in ItemRarity.values) {
      expect(find.text(RarityLabel.labelOf(rarity)), findsOneWidget);
      expect(find.text('Item ${rarity.name}'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ItemCard state terkunci, teks panjang, dan tombol aksi berfungsi',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrapWithTheme(
          ItemCard(
            name: 'Pedang Kuno Legendaris dari Lembah Aether yang Sangat Panjang Namanya',
            rarity: ItemRarity.legendary,
            slot: EquipmentSlot.weapon,
            quantity: 12,
            statsSummary: 'ATK +9999, CRIT +45%, ASPD +0.50, HASTE +25%',
            isLocked: true,
            lockedReason: 'Butuh Min Ascension Rank 1 dan Lv 49',
            trailing: PrimaryButton(
              label: 'Beli',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byType(LockedBadge), findsOneWidget);
      expect(find.text('Butuh Min Ascension Rank 1 dan Lv 49'), findsOneWidget);
      await tester.tap(find.text('Beli'));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Komponen tidak overflow pada lebar 320dp dan skala teks besar 1.5x',
    (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          width: 320,
          textScale: 1.5,
          PanelFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'Ringkasan Karakter Sangat Panjang Sekali',
                  trailing: ResourceChip.rank(1250),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ResourceChip.gold(9876543210),
                    ResourceChip.rank(999),
                  ],
                ),
                const SizedBox(height: 8),
                StatBar.hp(current: 12345678, max: 98765432),
                const SizedBox(height: 6),
                StatBar.exp(current: 999999999, max: 1000000000),
                const SizedBox(height: 8),
                ItemCard(
                  name: 'Ancient Heart Armor of Eternity',
                  rarity: ItemRarity.epic,
                  slot: EquipmentSlot.body,
                  statsSummary: 'HP +1.2K, DEF +340, HASTE +12%',
                  isLocked: true,
                  lockedReason: 'Selesaikan Ancient Crypt terlebih dahulu',
                  trailing: SecondaryButton(
                    label: 'Detail Item',
                    onPressed: () {},
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Masuk Dungeon Sekarang',
                  icon: Icons.play_arrow,
                  expand: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(PanelFrame), findsOneWidget);
      expect(find.byType(StatBar), findsNWidgets(2));
      expect(find.byType(ResourceChip), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SettingsOverlay memakai tema dan komponen bersama tanpa mengubah perilaku',
    (tester) async {
      final notifier = ValueNotifier<GameSettingsData>(
        const GameSettingsData(),
      );
      var closed = false;
      var testedSfx = false;

      await tester.pumpWidget(
        wrapWithTheme(
          ValueListenableBuilder<GameSettingsData>(
            valueListenable: notifier,
            builder: (context, _, _) => SettingsOverlay(
              settings: notifier,
              onChanged: (next) => notifier.value = next,
              onClose: () => closed = true,
              onTestSfx: () => testedSfx = true,
            ),
          ),
        ),
      );

      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      await tester.tap(find.text('Tes Suara'));
      expect(testedSfx, isTrue);

      await tester.tap(find.byTooltip('Tutup'));
      expect(closed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'HeroShowcaseCard, EmptyState, dan BiomeStyle berfungsi tanpa overflow di layar sempit',
    (tester) async {
      var tapped = false;
      const stats = CombatStats(maxHp: 320, atk: 42, def: 18, critRate: 0.15);
      final expectedPower = HeroShowcaseCard.computeCombatPower(stats);

      await tester.pumpWidget(
        wrapWithTheme(
          width: 320,
          textScale: 1.5,
          Column(
            children: [
              HeroShowcaseCard(
                level: 14,
                ascensionRank: 2,
                specializationId: 'vanguard',
                specializationName: 'Vanguard',
                stats: stats,
                onTap: () => tapped = true,
              ),
              const SizedBox(height: 8),
              const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Tas kosong',
                subtitle: 'Kalahkan monster untuk loot.',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Vanguard'), findsOneWidget);
      expect(find.text('Lv 14'), findsOneWidget);
      expect(find.text('Rank 2'), findsOneWidget);
      expect(find.text('Combat Power $expectedPower'), findsOneWidget);
      expect(find.text('Tas kosong'), findsOneWidget);

      await tester.tap(find.byKey(const Key('hero_showcase_card')));
      expect(tapped, isTrue);

      for (final biome in const [
        'forgotten_forest',
        'crystal_cavern',
        'ancient_crypt',
        'ashen_wasteland',
        'aether_sanctum',
      ]) {
        expect(BiomeStyle.resolve(biome).label, isNotEmpty);
      }
      expect(
        BiomeStyle.resolve('aether_sanctum', isAscension: true).label,
        'Ascension Sanctum',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Komponen Stage 1 baru (Navigation, Cards, Slots, Dialog, Sheet, Notif, Loader, Artwork) aman di 320dp @ 1.5x',
    (tester) async {
      var selectedTab = 0;
      var enteredDungeon = false;
      var tappedIcon = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 600),
              textScaler: TextScaler.linear(1.5),
            ),
            child: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                bottomNavigationBar: EchoesBottomNavigation(
                  currentIndex: selectedTab,
                  onSelected: (index) => setState(() => selectedTab = index),
                  items: const [
                    EchoesNavItem(
                      label: 'Adventure',
                      icon: Icons.explore_outlined,
                    ),
                    EchoesNavItem(label: 'Hero', icon: Icons.person_outline),
                    EchoesNavItem(
                      label: 'Bag',
                      icon: Icons.inventory_2_outlined,
                    ),
                    EchoesNavItem(
                      label: 'Shop',
                      icon: Icons.storefront_outlined,
                    ),
                    EchoesNavItem(
                      label: 'Settings',
                      icon: Icons.settings_outlined,
                    ),
                  ],
                ),
                body: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CampBackdrop(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final cls in const [
                                'base',
                                'vanguard',
                                'arcanist',
                                'ranger',
                              ])
                                Flexible(
                                  child: CharacterIllustration(
                                    specializationId: cls,
                                    width: 64,
                                    height: 82,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          AppIconButton(
                            icon: Icons.shield_outlined,
                            semanticLabel: 'Equipment',
                            onPressed: () => tappedIcon = true,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: InformationCard(
                              title: 'Aether Output',
                              value: '1.2K',
                              subtitle: 'Camp aktif',
                              icon: Icons.auto_awesome,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DungeonCard(
                        name: 'Forgotten Forest',
                        biomeId: 'forgotten_forest',
                        recommendedLevel: 1,
                        clearedRooms: 3,
                        totalRooms: 5,
                        isSelected: true,
                        areaLabel: 'Room 3/5',
                        primaryActionLabel: 'Enter Dungeon',
                        onPrimaryAction: () => enteredDungeon = true,
                        secondaryActionLabel: 'Switch',
                        onSecondaryAction: () {},
                      ),
                      const SizedBox(height: 8),
                      const Wrap(
                        spacing: 8,
                        children: [
                          ItemSlot(
                            rarity: ItemRarity.epic,
                            slot: EquipmentSlot.weapon,
                            quantity: 2,
                            isSelected: true,
                          ),
                          ItemSlot(
                            rarity: ItemRarity.rare,
                            category: ItemCategory.consumable,
                            isLocked: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const EquipmentSlotTile(
                        slot: EquipmentSlot.weapon,
                        slotLabel: 'Weapon',
                        itemName: 'Aetherblade',
                        rarity: ItemRarity.legendary,
                        statsSummary: 'ATK +42',
                      ),
                      const SizedBox(height: 8),
                      const ProgressBar(
                        value: 0.6,
                        label: 'Dungeon Mastery',
                        trailingText: '60%',
                      ),
                      const SizedBox(height: 8),
                      const AppNotificationBanner(
                        title: 'Drop Langka',
                        message: 'Menemukan Aether Shard x3.',
                        kind: AppNotificationKind.success,
                      ),
                      const SizedBox(height: 8),
                      const Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          BiomeArtwork(
                            biomeId: 'crystal_cavern',
                            width: 72,
                            height: 40,
                          ),
                          BiomeArtwork(
                            biomeId: 'ancient_crypt',
                            width: 72,
                            height: 40,
                          ),
                          BiomeArtwork(
                            biomeId: 'ashen_wasteland',
                            width: 72,
                            height: 40,
                          ),
                          BiomeArtwork(
                            biomeId: 'aether_sanctum',
                            width: 72,
                            height: 40,
                          ),
                          BiomeArtwork(
                            biomeId: 'aether_sanctum',
                            isAscension: true,
                            width: 72,
                            height: 40,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const LoadingState(compact: true),
                      Builder(
                        builder: (btnCtx) => Wrap(
                          spacing: 8,
                          children: [
                            PrimaryButton(
                              label: 'Dialog',
                              onPressed: () => showEchoesDialog<void>(
                                context: btnCtx,
                                title: 'Konfirmasi Camp',
                                primaryLabel: 'Lanjut',
                                secondaryLabel: 'Batal',
                                child: const Text('Masuk ke dungeon sekarang?'),
                              ),
                            ),
                            SecondaryButton(
                              label: 'Sheet',
                              onPressed: () => showEchoesBottomSheet<void>(
                                context: btnCtx,
                                title: 'Detail Biome',
                                subtitle: 'Forgotten Forest',
                                child: const Text('Monster: Slime & Wolf'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify character illustrations & camp backdrop
      expect(find.byKey(const ValueKey('camp_backdrop')), findsOneWidget);
      for (final cls in const ['base', 'vanguard', 'arcanist', 'ranger']) {
        expect(
          find.byKey(ValueKey('character_illustration_$cls')),
          findsOneWidget,
        );
      }

      // Verify icon button >= 44dp touch target
      final iconBox = tester.getSize(find.byType(AppIconButton));
      expect(iconBox.width, greaterThanOrEqualTo(44));
      expect(iconBox.height, greaterThanOrEqualTo(44));

      await tester.tap(find.byType(AppIconButton));
      expect(tappedIcon, isTrue);

      await tester.tap(find.text('Enter Dungeon'));
      expect(enteredDungeon, isTrue);

      await tester.tap(find.text('Hero'));
      await tester.pump();
      expect(selectedTab, 1);

      // Verify all 6 biome artwork keys can render cleanly
      for (final biome in const [
        'forgotten_forest',
        'crystal_cavern',
        'ancient_crypt',
        'ashen_wasteland',
        'aether_sanctum',
      ]) {
        expect(
          BiomeVisualSpec.resolve(biome).assetPath,
          startsWith(GameAssetDirectories.biomes),
        );
      }

      // Open & dismiss dialog (pump twice so route animation completes cleanly)
      await tester.ensureVisible(find.text('Dialog'));
      await tester.pump();
      await tester.tap(find.text('Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Konfirmasi Camp'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Konfirmasi Camp'), findsNothing);

      // Open & dismiss bottom sheet
      await tester.ensureVisible(find.text('Sheet'));
      await tester.pump();
      await tester.tap(find.text('Sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Detail Biome'), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Detail Biome'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );
}
