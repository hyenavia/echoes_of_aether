import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loadout_preset.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/features/dungeon/equipment_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/loadout_preset_bar.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
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

  group('Fase 2 Stage 1 — LoadoutPreset UI Tests', () {
    testWidgets(
      'LoadoutPresetBar switches slots, disables Pakai on empty slot, and triggers callbacks on 360x640',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        int? savedSlot;
        int? appliedSlot;

        const presets = [
          LoadoutPreset(
            slotIndex: 0,
            name: 'Preset 1',
            specializationId: 'paladin',
            equipmentInstanceIds: {
              EquipmentSlot.weapon: 'eq_1',
              EquipmentSlot.body: 'eq_2',
            },
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: LoadoutPresetBar(
                  presets: presets,
                  specializationNames: const {'paladin': 'Paladin'},
                  onSavePreset: (slot) => savedSlot = slot,
                  onApplyPreset: (slot) => appliedSlot = slot,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Slot 0 terisi: menampilkan ringkasan class + jumlah gear
        expect(find.text('Paladin • 2 Gear tersimpan'), findsOneWidget);
        await tester.tap(find.byKey(const Key('loadout_preset_apply_button')));
        await tester.pump();
        expect(appliedSlot, 0);

        // Pindah ke Slot 1 (kosong): tombol Pakai nonaktif, Simpan tetap aktif
        await tester.tap(find.byKey(const Key('loadout_preset_slot_1')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Slot kosong — tekan Simpan untuk menyimpan build saat ini.',
          ),
          findsOneWidget,
        );

        appliedSlot = null;
        await tester.tap(find.byKey(const Key('loadout_preset_apply_button')));
        await tester.pump();
        expect(appliedSlot, isNull);

        await tester.tap(find.byKey(const Key('loadout_preset_save_button')));
        await tester.pump();
        expect(savedSlot, 1);
      },
    );

    testWidgets(
      'EquipmentOverlay displays LoadoutPresetBar when callbacks are wired',
      (tester) async {
        final inv = Inventory(definitions: const {});
        final char = PlayerCharacter(config: progression);
        final views = InventoryViews(inventory: inv, character: char);

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: EquipmentOverlay(
                snapshot: views.equipment,
                items: const <String, ItemDefinition>{},
                onEquip: (_) {},
                onUnequip: (_) {},
                loadoutPresets: const [
                  LoadoutPreset(
                    slotIndex: 0,
                    name: 'Preset 1',
                    specializationId: 'vanguard',
                  ),
                ],
                specializationNames: const {'vanguard': 'Vanguard'},
                onSaveLoadoutPreset: (_) {},
                onApplyLoadoutPreset: (_) {},
                embedded: true,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('loadout_preset_bar')), findsOneWidget);
        expect(find.text('Vanguard • 0 Gear tersimpan'), findsOneWidget);
      },
    );
  });
}
