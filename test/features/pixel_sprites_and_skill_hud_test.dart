import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/features/dungeon/hud_overlay.dart';
import 'package:echoes_of_aether/features/shared/assets/item_sprite_registry.dart';
import 'package:echoes_of_aether/features/shared/widgets/artwork/character_illustration.dart';
import 'package:echoes_of_aether/features/shared/widgets/item_slot.dart';
import 'package:echoes_of_aether/features/shared/widgets/pixel_item_icon.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ItemSpriteRegistry - Skills, Slots & Stats', () {
    test(
      'memetakan seluruh skill aktif dan pasif ke file sprite yang valid',
      () {
        expect(
          ItemSpriteRegistry.spriteForSkill('power_strike'),
          'assets/sprite/fc1452.png',
        );
        expect(
          ItemSpriteRegistry.spriteForSkill('healing_pulse'),
          'assets/sprite/fc364.png',
        );
        expect(
          ItemSpriteRegistry.spriteForSkill('vitality'),
          'assets/sprite/fc260.png',
        );
        expect(
          ItemSpriteRegistry.spriteForSkill('focus'),
          'assets/sprite/fc381.png',
        );
        expect(
          ItemSpriteRegistry.spriteForSkill('iron_resolve'),
          'assets/sprite/fc2014.png',
        );
        expect(
          ItemSpriteRegistry.spriteForSkill('crushing_blow'),
          'assets/sprite/fc1413.png',
        );
        expect(
          ItemSpriteRegistry.spriteForSkill('aether_burst'),
          'assets/sprite/fc604.png',
        );
        expect(
          ItemSpriteRegistry.spriteForSkill('mana_attunement'),
          'assets/sprite/fc292.png',
        );
        expect(
          ItemSpriteRegistry.spriteForSkill('meteor_fall'),
          'assets/sprite/fc345.png',
        );
        expect(
          ItemSpriteRegistry.spriteForSkill('quick_shot'),
          'assets/sprite/fc1100.png',
        );
        expect(
          ItemSpriteRegistry.spriteForSkill('hawk_eye'),
          'assets/sprite/fc382.png',
        );
        expect(
          ItemSpriteRegistry.spriteForSkill('volley'),
          'assets/sprite/fc1099.png',
        );
      },
    );

    test('memetakan slot equipment ke placeholder sprite', () {
      expect(
        ItemSpriteRegistry.spriteForSlot(EquipmentSlot.weapon),
        'assets/sprite/fc1447.png',
      );
      expect(
        ItemSpriteRegistry.spriteForSlot(EquipmentSlot.head),
        'assets/sprite/fc2003.png',
      );
      expect(
        ItemSpriteRegistry.spriteForSlot(EquipmentSlot.body),
        'assets/sprite/fc2019.png',
      );
      expect(
        ItemSpriteRegistry.spriteForSlot(EquipmentSlot.accessory),
        'assets/sprite/fc117.png',
      );
    });

    test('memetakan stat tempur ke sprite', () {
      expect(ItemSpriteRegistry.spriteForStat('HP'), 'assets/sprite/fc260.png');
      expect(
        ItemSpriteRegistry.spriteForStat('ATK'),
        'assets/sprite/fc1447.png',
      );
      expect(
        ItemSpriteRegistry.spriteForStat('DEF'),
        'assets/sprite/fc2014.png',
      );
      expect(
        ItemSpriteRegistry.spriteForStat('CRIT'),
        'assets/sprite/fc382.png',
      );
      expect(
        ItemSpriteRegistry.spriteForStat('SPEED'),
        'assets/sprite/fc2028.png',
      );
      expect(
        ItemSpriteRegistry.spriteForStat('HASTE'),
        'assets/sprite/fc293.png',
      );
    });

    test('memetakan kategori item fallback ke sprite', () {
      expect(
        ItemSpriteRegistry.spriteForCategory(ItemCategory.material),
        'assets/sprite/fc254.png',
      );
      expect(
        ItemSpriteRegistry.spriteForCategory(ItemCategory.consumable),
        'assets/sprite/fc265.png',
      );
      expect(
        ItemSpriteRegistry.spriteForCategory(ItemCategory.questItem),
        'assets/sprite/fc600.png',
      );
    });
  });

  group('PixelItemIcon fallback resolution', () {
    testWidgets('menyelesaikan sprite slot ketika itemId null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PixelItemIcon(slot: EquipmentSlot.weapon)),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect((image.image as AssetImage).assetName, 'assets/sprite/fc1447.png');
      expect(image.filterQuality, FilterQuality.none);
    });

    testWidgets('menyelesaikan sprite skill ketika skillId diberikan', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PixelItemIcon(skillId: 'meteor_fall')),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect((image.image as AssetImage).assetName, 'assets/sprite/fc345.png');
      expect(image.filterQuality, FilterQuality.none);
    });
  });

  group('CharacterIllustration Pixel Sprite Integration', () {
    testWidgets('menampilkan sprite hero idle0 sesuai spesialisasi aktif', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterIllustration(specializationId: 'vanguard'),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(
        (image.image as AssetImage).assetName,
        'assets/char/frames/hero_vanguard_idle0.png',
      );
      expect(image.filterQuality, FilterQuality.none);
    });

    testWidgets(
      'menampilkan sprite hero base saat specializationId null/base',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CharacterIllustration(specializationId: 'base'),
            ),
          ),
        );

        final imageFinder = find.byType(Image);
        expect(imageFinder, findsOneWidget);
        final image = tester.widget<Image>(imageFinder);
        expect(
          (image.image as AssetImage).assetName,
          'assets/char/frames/hero_base_idle0.png',
        );
        expect(image.filterQuality, FilterQuality.none);
      },
    );
  });

  group('HudOverlay Skill UI & Cooldowns', () {
    testWidgets('menampilkan skill bar dengan status ready dan on-cooldown', (
      tester,
    ) async {
      final hudState = ValueNotifier<HudState>(
        const HudState(
          level: 5,
          currentExp: 40,
          expToNext: 150,
          gold: 250,
          hp: 85,
          maxHp: 100,
          skills: [
            HudSkillInfo(
              id: 'power_strike',
              name: 'Power Strike',
              spritePath: 'assets/sprite/fc1452.png',
              cooldownSeconds: 5.0,
              remainingSeconds: 0.0,
              progress: 0.0,
              isReady: true,
            ),
            HudSkillInfo(
              id: 'healing_pulse',
              name: 'Healing Pulse',
              spritePath: 'assets/sprite/fc364.png',
              cooldownSeconds: 25.0,
              remainingSeconds: 12.0,
              progress: 0.48,
              isReady: false,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HudOverlay(state: hudState)),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('hud_skill_bar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('hud_skill_power_strike')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('hud_skill_healing_pulse')),
        findsOneWidget,
      );

      expect(find.text('Power Strike'), findsOneWidget);
      expect(find.text('Healing Pulse'), findsOneWidget);
      expect(find.text('12s'), findsOneWidget);
    });

    testWidgets('menampilkan cooldown pecahan untuk waktu < 10 detik', (
      tester,
    ) async {
      final hudState = ValueNotifier<HudState>(
        const HudState(
          level: 5,
          currentExp: 40,
          expToNext: 150,
          gold: 250,
          hp: 85,
          maxHp: 100,
          skills: [
            HudSkillInfo(
              id: 'power_strike',
              name: 'Power Strike',
              spritePath: 'assets/sprite/fc1452.png',
              cooldownSeconds: 5.0,
              remainingSeconds: 2.3,
              progress: 0.46,
              isReady: false,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HudOverlay(state: hudState)),
        ),
      );

      expect(find.text('2.3s'), findsOneWidget);
    });

    testWidgets(
      'Skill Bar dan Combat Feed tidak tumpang tindih (non-intersecting bounds)',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final hudState = ValueNotifier<HudState>(
          const HudState(
            level: 5,
            currentExp: 40,
            expToNext: 150,
            gold: 250,
            hp: 85,
            maxHp: 100,
            transitionMessage: 'Memasuki Sanctum Nave',
            lastLoot: 'Swift Charm, Ranger Blade',
            skills: [
              HudSkillInfo(
                id: 'healing_pulse',
                name: 'Healing Pulse',
                spritePath: 'assets/sprite/fc364.png',
                cooldownSeconds: 25.0,
                remainingSeconds: 0.0,
                progress: 0.0,
                isReady: true,
              ),
              HudSkillInfo(
                id: 'power_strike',
                name: 'Power Strike',
                spritePath: 'assets/sprite/fc1452.png',
                cooldownSeconds: 5.0,
                remainingSeconds: 2.0,
                progress: 0.4,
                isReady: false,
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: HudOverlay(state: hudState)),
          ),
        );

        final skillBarRect = tester.getRect(
          find.byKey(const ValueKey<String>('hud_skill_bar')),
        );
        final combatFeedRect = tester.getRect(
          find.byKey(const ValueKey<String>('hud_combat_feed')),
        );

        expect(
          skillBarRect.overlaps(combatFeedRect),
          isFalse,
          reason: 'Skill Bar dan Combat Feed tidak boleh saling menabrak',
        );
        expect(
          combatFeedRect.bottom,
          lessThanOrEqualTo(skillBarRect.top + 2),
          reason: 'Combat Feed harus berada di atas Skill Bar',
        );
      },
    );
  });

  group('EquipmentSlotTile unequipped placeholder sprite', () {
    testWidgets('menampilkan placeholder sprite saat slot kosong', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EquipmentSlotTile(
              slot: EquipmentSlot.weapon,
              slotLabel: 'Senjata',
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect((image.image as AssetImage).assetName, 'assets/sprite/fc1447.png');
      expect(find.text('Senjata'), findsOneWidget);
      expect(find.text('Kosong'), findsOneWidget);
    });
  });
}
