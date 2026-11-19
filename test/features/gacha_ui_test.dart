import 'dart:io';
import 'dart:math' as math;

import 'package:echoes_of_aether/data/models/gacha_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/currency_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/gacha_service.dart';
import 'package:echoes_of_aether/domain/services/period_service.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:echoes_of_aether/features/dungeon/character_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/gacha_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
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
    time: parser.parseTime(settings),
    claimedRewards: parser.parseClaimedRewards(settings),
    currencies: parser.parseCurrencies(settings),
    notifications: parser.parseNotifications(settings),
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
    gacha: const GachaConfigParser().parse(_readAsset('gacha_banners.json')),
  );
}

void main() {
  late GameConfig config;
  late GachaService gachaService;
  final nowMs = DateTime.utc(2026, 11, 16, 12, 0).millisecondsSinceEpoch;

  setUpAll(() {
    config = _loadRealConfig();
    gachaService = GachaService(
      gachaConfig: config.gacha!,
      items: config.items,
      specializations: config.specializations.definitions,
      equipmentFactory: EquipmentFactory(config.equipment),
      periodService: const PeriodService(),
    );
  });

  group('M15 Stage 5 — GachaOverlay & Sanctuary UI', () {
    testWidgets(
      'menampilkan tab Class/Senjata/Sanctuary, pity counter, dan hasil pull 1x/10x dengan dialog animasi',
      (tester) async {
        final char = PlayerCharacter(
          config: config.progression,
          specializationConfig: config.specializations,
          skillCatalog: config.skills,
          progress: const PlayerProgress(level: 30),
          initialSpecializationId: 'vanguard',
        );
        final inv = Inventory(definitions: config.items);
        var snapshot = PlayerSaveSnapshot(
          character: char.toSnapshot(),
          inventory: inv.toSnapshot(),
          currencies: const {
            kAetherShardCurrencyId: 500,
            kSoulPrismCurrencyId: 3,
          },
          unlockedSpecializations: const {
            'vanguard',
            'arcanist',
            'ranger',
            'paladin',
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return GachaOverlay(
                    gachaService: gachaService,
                    aetherShards:
                        snapshot.currencies[kAetherShardCurrencyId] ?? 0,
                    soulPrisms: snapshot.currencies[kSoulPrismCurrencyId] ?? 0,
                    pityStates: snapshot.gachaPityStates,
                    unlockedSpecializations: snapshot.unlockedSpecializations,
                    nowMs: nowMs,
                    onPull: (bannerType, count) async {
                      final res = count == 10
                          ? gachaService.pullTen(
                              snapshot: snapshot,
                              bannerType: bannerType,
                              nowMs: nowMs,
                              random: math.Random(42),
                            )
                          : gachaService.pullOnce(
                              snapshot: snapshot,
                              bannerType: bannerType,
                              nowMs: nowMs,
                              random: math.Random(42),
                            );
                      if (res.isSuccess && res.updatedSnapshot != null) {
                        setState(() => snapshot = res.updatedSnapshot!);
                      }
                      return res;
                    },
                    onExchangeWeapon: (weaponId) async {
                      final res = gachaService.exchangeSanctuaryWeapon(
                        snapshot: snapshot,
                        weaponId: weaponId,
                        random: math.Random(1),
                      );
                      if (res.isSuccess && res.updatedSnapshot != null) {
                        setState(() => snapshot = res.updatedSnapshot!);
                      }
                      return res;
                    },
                    onExchangeClass: (classId) async {
                      final res = gachaService.exchangeSanctuaryClass(
                        snapshot: snapshot,
                        classId: classId,
                      );
                      if (res.isSuccess && res.updatedSnapshot != null) {
                        setState(() => snapshot = res.updatedSnapshot!);
                      }
                      return res;
                    },
                    onClose: () {},
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('Altar Pemanggilan'), findsOneWidget);
        expect(find.byKey(const Key('gacha_pity_counter')), findsOneWidget);
        expect(find.text('Pity: 0/40'), findsOneWidget);

        // Pindah ke tab Senjata (Mythical Armory) -> pity 0/30
        await tester.tap(find.text('Senjata'));
        await tester.pumpAndSettle();
        expect(find.text('Pity: 0/30'), findsOneWidget);

        // Pull 10x -> dialog hasil muncul
        await tester.tap(find.byKey(const Key('gacha_pull_10x')));
        await tester.pumpAndSettle();
        expect(find.text('Hasil Pemanggilan (10x)'), findsOneWidget);
        await tester.tap(find.byKey(const Key('gacha_result_close')));
        await tester.pumpAndSettle();

        // Pindah ke tab Sanctuary -> tukar Class Mythical (voidblade) seharga 3 Prism
        await tester.tap(find.text('Sanctuary'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('sanctuary_class_voidblade')),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(
          find.byKey(const Key('sanctuary_class_voidblade')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('sanctuary_class_voidblade')));
        await tester.pumpAndSettle();

        expect(snapshot.unlockedSpecializations.contains('voidblade'), isTrue);
        expect(find.textContaining('Berhasil membuka Class'), findsOneWidget);
      },
    );

    testWidgets(
      'layout GachaOverlay responsif tanpa overflow pada layar mobile sempit (320x640) dan tablet (800x1024)',
      (tester) async {
        for (final size in const [Size(320, 640), Size(800, 1024)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: GachaOverlay(
                  gachaService: gachaService,
                  aetherShards: 300,
                  soulPrisms: 2,
                  pityStates: const {},
                  unlockedSpecializations: const {'vanguard'},
                  nowMs: nowMs,
                  onPull: (b, _) async => GachaPullSessionResult(
                    status: GachaPullStatus.bannerNotFound,
                    bannerType: b,
                  ),
                  onExchangeWeapon: (_) async => const SanctuaryExchangeResult(
                    status: SanctuaryExchangeStatus.invalidTarget,
                  ),
                  onExchangeClass: (_) async => const SanctuaryExchangeResult(
                    status: SanctuaryExchangeStatus.invalidTarget,
                  ),
                  onClose: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'TownHubView menampilkan tombol quick access Gacha dan CharacterOverlay menghormati unlockedSpecializations',
      (tester) async {
        final char = PlayerCharacter(
          config: config.progression,
          specializationConfig: config.specializations,
          skillCatalog: config.skills,
          progress: const PlayerProgress(level: 30),
          initialSpecializationId: 'vanguard',
        );
        final inv = Inventory(definitions: config.items);
        final views = InventoryViews(
          inventory: inv,
          character: char,
          unlockedSpecializations: const {'vanguard', 'paladin'},
        );
        final shopService = ShopService(
          catalog: config.shop,
          items: config.items,
          equipmentFactory: EquipmentFactory(config.equipment),
        );

        var gachaOpened = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TownHubView(
                character: char,
                views: views,
                items: config.items,
                dungeonProgress: const DungeonProgressSnapshot(),
                dungeonDefinition: config.dungeons['forgotten_forest'],
                availableDungeons: config.dungeons,
                onEnterDungeon: () {},
                onEquip: (_) {},
                onUnequip: (_) {},
                onChooseSpecialization: (_) {},
                shopCatalog: config.shop,
                shopService: shopService,
                shopContext: const ShopPlayerContext(playerLevel: 30),
                onShopBuy: (id) async => ShopBuyNotFound(entryId: id),
                onShopSellEquipment: (id) async =>
                    ShopSellNotFound(targetId: id),
                onShopSellMaterialBulk: (id, _) async =>
                    ShopSellNotFound(targetId: id),
                onOpenGacha: () => gachaOpened = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const Key('quick_access_gacha')),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const Key('quick_access_gacha')));
        await tester.pumpAndSettle();
        expect(gachaOpened, isTrue);

        // Verifikasi CharacterOverlay mengunci class Mythical yang belum terbuka
        String? chosenSpec;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CharacterOverlay(
                snapshot: views.characterView,
                onChooseSpecialization: (id) => chosenSpec = id,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gacha / Sanctuary'), findsWidgets);
        await tester.scrollUntilVisible(
          find.text('Paladin'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Paladin'), findsOneWidget);
        expect(chosenSpec, isNull);
      },
    );
  });
}
