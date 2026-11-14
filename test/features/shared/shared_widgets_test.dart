import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
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
}
