import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/features/dungeon/inventory_overlay.dart';
import 'package:echoes_of_aether/features/shared/widgets/echoes_bottom_navigation.dart';
import 'package:echoes_of_aether/features/shared/widgets/hero_showcase_card.dart';
import 'package:echoes_of_aether/theme/app_theme.dart';
import 'package:echoes_of_aether/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tahap 2: Refactor Layar Adventure (Town/Camp) Tests', () {
    testWidgets(
      'HeroShowcaseCard menggunakan GamePanel.goldOrnate dan floating animation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme(),
            home: const Scaffold(
              body: HeroShowcaseCard(
                level: 25,
                ascensionRank: 2,
                specializationId: 'arcanist',
                specializationName: 'Arcanist',
                stats: CombatStats(maxHp: 450, atk: 60, def: 25),
              ),
            ),
          ),
        );

        // Verifikasi GamePanel membungkus hero showcase
        expect(find.byType(GamePanel), findsWidgets);
        final gamePanel = tester.widget<GamePanel>(
          find.byType(GamePanel).first,
        );
        expect(gamePanel.style, GamePanelStyle.goldOrnate);
        expect(gamePanel.showGlow, isTrue);

        // Verifikasi teks hero terdeteksi
        expect(find.text('Arcanist'), findsOneWidget);
        expect(find.text('Lv 25'), findsOneWidget);
      },
    );

    testWidgets(
      'EchoesBottomNavigation bergaya dark wood/metal dengan ikon menyala saat dipilih',
      (tester) async {
        var selectedIndex = 0;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) => MaterialApp(
              theme: AppTheme.darkTheme(),
              home: Scaffold(
                bottomNavigationBar: EchoesBottomNavigation(
                  currentIndex: selectedIndex,
                  onSelected: (idx) => setState(() => selectedIndex = idx),
                  items: const [
                    EchoesNavItem(
                      label: 'Adventure',
                      icon: Icons.explore_outlined,
                      activeIcon: Icons.explore,
                    ),
                    EchoesNavItem(
                      label: 'Hero',
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                    ),
                    EchoesNavItem(
                      label: 'Bag',
                      icon: Icons.inventory_2_outlined,
                      activeIcon: Icons.inventory_2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Tab aktif pertama (Adventure) menyala dengan warna emas
        final activeIcon = tester.widget<Icon>(find.byIcon(Icons.explore));
        expect(activeIcon.color, AppTheme.gold);
        expect(activeIcon.shadows, isNotNull);

        // Ketuk tab Hero
        await tester.tap(find.text('Hero'));
        await tester.pumpAndSettle();

        expect(selectedIndex, 1);
        final newActiveIcon = tester.widget<Icon>(find.byIcon(Icons.person));
        expect(newActiveIcon.color, AppTheme.gold);
      },
    );

    testWidgets(
      'InventoryOverlay dalam mode embedded merender Grid Slot dengan border warna sesuai rarity',
      (tester) async {
        final entries = ValueNotifier<List<InventoryEntry>>([
          InventoryEntry(
            const ItemDefinition(
              id: 'mat_common',
              name: 'Batu Kasar',
              category: ItemCategory.material,
              rarity: ItemRarity.common,
            ),
            20,
          ),
          InventoryEntry(
            const ItemDefinition(
              id: 'mat_rare',
              name: 'Kristal Aether',
              category: ItemCategory.material,
              rarity: ItemRarity.rare,
            ),
            5,
          ),
          InventoryEntry(
            const ItemDefinition(
              id: 'mat_epic',
              name: 'Arcane Shard',
              category: ItemCategory.material,
              rarity: ItemRarity.epic,
            ),
            3,
          ),
          InventoryEntry(
            const ItemDefinition(
              id: 'mat_legendary',
              name: 'Dragon Heart',
              category: ItemCategory.material,
              rarity: ItemRarity.legendary,
            ),
            1,
          ),
        ]);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme(),
            home: Scaffold(
              body: InventoryOverlay(
                entries: entries,
                embedded: true,
                onClose: () {},
              ),
            ),
          ),
        );

        // Verifikasi GridView ter-render
        expect(find.byKey(const Key('inventory_bag_grid')), findsOneWidget);

        // Verifikasi semua nama item dan kuantitas ter-render
        expect(find.text('Batu Kasar'), findsOneWidget);
        expect(find.text('Kristal Aether'), findsOneWidget);
        expect(find.text('Arcane Shard'), findsOneWidget);
        expect(find.text('Dragon Heart'), findsOneWidget);
        expect(find.text('x20'), findsOneWidget);
        expect(find.text('x5'), findsOneWidget);
        expect(find.text('x3'), findsOneWidget);
        expect(find.text('x1'), findsOneWidget);

        // Verifikasi label Rarity ter-render
        expect(find.text('COMMON'), findsOneWidget);
        expect(find.text('RARE'), findsOneWidget);
        expect(find.text('EPIC'), findsOneWidget);
        expect(find.text('LEGENDARY'), findsOneWidget);
      },
    );
  });
}
