import 'dart:io';

import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/infinite_spire_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/infinite_spire.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/repositories/player_progress_repository.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/hero_ascension_service.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/features/dungeon/character_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/hero_ascension_dialog.dart';
import 'package:echoes_of_aether/features/dungeon/infinite_spire_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySaveRepository implements PlayerSaveRepository {
  PlayerSaveSnapshot? stored;
  bool shouldThrow = false;

  @override
  Future<PlayerSaveSnapshot?> loadSnapshot() async => stored;

  @override
  Future<void> saveSnapshot(PlayerSaveSnapshot snapshot) async {
    if (shouldThrow) throw Exception('Simulated storage error');
    stored = snapshot;
  }
}

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
    time: parser.parseTime(settings),
    currencies: parser.parseCurrencies(settings),
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
    heroAscension: parser.parseHeroAscension(settings),
    infiniteSpire: const InfiniteSpireConfigParser().parse(
      _readAsset('infinite_spire.json'),
    ),
  );
}

void main() {
  late GameConfig realConfig;
  late InfiniteSpireConfig spireConfig;

  setUpAll(() {
    realConfig = _loadRealConfig();
    spireConfig = realConfig.infiniteSpire!;
  });

  Widget wrapWithTheme(Widget child, {Size size = const Size(800, 1000)}) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: const [EchoesThemeExtension.dark],
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    );
  }

  group('M16 Stage 5 — HeroAscensionDialog Tests', () {
    testWidgets(
      'menampilkan rincian fase, preview bonus stat, dan syarat material',
      (tester) async {
        final snap = CharacterSnapshot(
          level: 20,
          gold: 1000,
          stats: const CombatStats(maxHp: 200, atk: 25, def: 10),
          specializationId: 'base',
          canChooseSpecialization: false,
          specializationUnlockLevel: 10,
          specializations: const [],
          skills: const [],
          ascensionPhase: 0,
          isAscendReady: true,
          effectiveLevelCap: 20,
          heroAscensionConfig: realConfig.heroAscension,
        );

        final inv = {'d1_boss_remnant': 3};

        await tester.pumpWidget(
          wrapWithTheme(
            HeroAscensionDialog(
              characterSnapshot: snap,
              items: realConfig.items,
              inventoryQuantities: inv,
              onConfirmAscend: () async => const HeroAscensionResult(
                succeeded: true,
                previousPhase: 0,
                newPhase: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Judul & deskripsi
        expect(find.text('Terobosan Hero Ascension'), findsOneWidget);
        expect(find.text('Fase A0'), findsOneWidget);
        expect(find.text('Fase A1'), findsOneWidget);
        expect(find.text('Cap Lv 40'), findsOneWidget);

        // Bonus Stat Terobosan A1: +50 Max HP, +8 ATK, +3 DEF
        expect(find.text('+50 Max HP'), findsOneWidget);
        expect(find.text('+8 ATK'), findsOneWidget);
        expect(find.text('+3 DEF'), findsOneWidget);

        // Checklist Syarat
        expect(find.text('Level Karakter'), findsOneWidget);
        expect(find.text('Gold'), findsOneWidget);
        expect(find.byKey(const Key('confirm_ascend_button')), findsOneWidget);
      },
    );

    testWidgets(
      'tombol konfirmasi terobosan memanggil onConfirmAscend dan menampilkan celebration view',
      (tester) async {
        var ascendCalled = false;
        final snap = CharacterSnapshot(
          level: 20,
          gold: 1500,
          stats: const CombatStats(maxHp: 200, atk: 25, def: 10),
          specializationId: 'base',
          canChooseSpecialization: false,
          specializationUnlockLevel: 10,
          specializations: const [],
          skills: const [],
          ascensionPhase: 0,
          isAscendReady: true,
          effectiveLevelCap: 20,
          heroAscensionConfig: realConfig.heroAscension,
        );

        final inv = {'boss_remnant': 5};

        await tester.pumpWidget(
          wrapWithTheme(
            HeroAscensionDialog(
              characterSnapshot: snap,
              items: realConfig.items,
              inventoryQuantities: inv,
              onConfirmAscend: () async {
                ascendCalled = true;
                return HeroAscensionResult(
                  succeeded: true,
                  previousPhase: 0,
                  newPhase: 1,
                  phaseDefinition: realConfig.heroAscension.phase(1),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final confirmBtn = find.byKey(const Key('confirm_ascend_button'));
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(ascendCalled, isTrue);
        // Tampilan celebration "ASCENDED!"
        expect(
          find.byKey(const Key('ascended_celebration_title')),
          findsOneWidget,
        );
        expect(find.text('ASCENDED!'), findsOneWidget);
        expect(
          find.text('Karakter berhasil menembus ke Fase A1!'),
          findsOneWidget,
        );
        expect(find.text('Lanjutkan Petualangan'), findsOneWidget);
      },
    );

    testWidgets(
      'menampilkan MAX POTENTIAL REACHED jika karakter sudah pada Fase A6',
      (tester) async {
        final snap = CharacterSnapshot(
          level: 90,
          gold: 50000,
          stats: const CombatStats(maxHp: 2000, atk: 250, def: 100),
          specializationId: 'vanguard',
          canChooseSpecialization: false,
          specializationUnlockLevel: 10,
          specializations: const [],
          skills: const [],
          ascensionPhase: 6,
          isAscendReady: false,
          effectiveLevelCap: 90,
          heroAscensionConfig: realConfig.heroAscension,
          hasGoldenAura: true,
        );

        await tester.pumpWidget(
          wrapWithTheme(
            HeroAscensionDialog(
              characterSnapshot: snap,
              items: realConfig.items,
              onConfirmAscend: () async => const HeroAscensionResult(
                succeeded: false,
                previousPhase: 6,
                newPhase: 6,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('MAX POTENTIAL REACHED'), findsOneWidget);
      },
    );
  });

  group(
    'M16 Stage 5 — CharacterOverlay Hero Ascension Button & Badge Tests',
    () {
      testWidgets('menampilkan tombol TEROBOSAN! saat karakter siap ascend', (
        tester,
      ) async {
        final notifier = ValueNotifier(
          CharacterSnapshot(
            level: 20,
            gold: 5000,
            stats: const CombatStats(maxHp: 200, atk: 25, def: 10),
            specializationId: 'base',
            canChooseSpecialization: false,
            specializationUnlockLevel: 10,
            specializations: const [],
            skills: const [],
            ascensionPhase: 0,
            isAscendReady: true,
            effectiveLevelCap: 20,
            heroAscensionConfig: realConfig.heroAscension,
          ),
        );

        await tester.pumpWidget(
          wrapWithTheme(
            CharacterOverlay(
              snapshot: notifier,
              onChooseSpecialization: (_) {},
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('hero_ascend_button')), findsOneWidget);
        expect(find.text('TEROBOSAN!'), findsOneWidget);

        // Menekan tombol membuka HeroAscensionDialog
        await tester.tap(find.byKey(const Key('hero_ascend_button')));
        await tester.pumpAndSettle();

        expect(find.byType(HeroAscensionDialog), findsOneWidget);
      });

      testWidgets('menampilkan badge Fase A0 saat belum siap ascend', (
        tester,
      ) async {
        final notifier = ValueNotifier(
          CharacterSnapshot(
            level: 15,
            gold: 200,
            stats: const CombatStats(maxHp: 150, atk: 20, def: 8),
            specializationId: 'base',
            canChooseSpecialization: false,
            specializationUnlockLevel: 10,
            specializations: const [],
            skills: const [],
            ascensionPhase: 0,
            isAscendReady: false,
            effectiveLevelCap: 20,
            heroAscensionConfig: realConfig.heroAscension,
          ),
        );

        await tester.pumpWidget(
          wrapWithTheme(
            CharacterOverlay(
              snapshot: notifier,
              onChooseSpecialization: (_) {},
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('hero_ascension_badge')), findsOneWidget);
        expect(find.text('Fase A0'), findsOneWidget);
      });

      testWidgets(
        'menampilkan badge A6 (MAX) saat karakter mencapai fase maksimal',
        (tester) async {
          final notifier = ValueNotifier(
            CharacterSnapshot(
              level: 90,
              gold: 50000,
              stats: const CombatStats(maxHp: 2000, atk: 250, def: 100),
              specializationId: 'base',
              canChooseSpecialization: false,
              specializationUnlockLevel: 10,
              specializations: const [],
              skills: const [],
              ascensionPhase: 6,
              isAscendReady: false,
              effectiveLevelCap: 90,
              heroAscensionConfig: realConfig.heroAscension,
              hasGoldenAura: true,
            ),
          );

          await tester.pumpWidget(
            wrapWithTheme(
              CharacterOverlay(
                snapshot: notifier,
                onChooseSpecialization: (_) {},
                onClose: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('A6 (MAX)'), findsOneWidget);
        },
      );
    },
  );

  group('M16 Stage 5 — InfiniteSpireOverlay Tests', () {
    testWidgets(
      'menampilkan judul The Infinite Spire, progress 100 lantai, dan status tiap lantai',
      (tester) async {
        final progress = const InfiniteSpireProgressSnapshot(
          highestFloorCleared: 1,
          claimedFloorRewards: {1},
        );

        int? challengedFloor;

        await tester.pumpWidget(
          wrapWithTheme(
            InfiniteSpireOverlay(
              config: spireConfig,
              progress: progress,
              playerLevel: 30,
              onFightFloor: (f) => challengedFloor = f,
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header
        expect(find.text('The Infinite Spire'), findsOneWidget);
        expect(find.text('Selesai: 1 / 100 Lantai'), findsOneWidget);

        // Lantai 1: SELESAI, tombol Latihan
        expect(
          find.byKey(const Key('infinite_spire_floor_card_1')),
          findsOneWidget,
        );
        expect(find.text('SELESAI'), findsWidgets);

        // Lantai 2: Terbuka, tombol Tantang
        final fightBtn2 = find.byKey(const Key('infinite_spire_fight_2'));
        expect(fightBtn2, findsOneWidget);

        // Lantai 3: TERKUNCI
        expect(find.text('TERKUNCI'), findsWidgets);

        // Tekan tombol Tantang Lantai 2
        await tester.tap(fightBtn2);
        await tester.pumpAndSettle();
        expect(challengedFloor, 2);
      },
    );

    testWidgets('filter Bos Saja memfilter daftar lantai ke kelipatan 10', (
      tester,
    ) async {
      const progress = InfiniteSpireProgressSnapshot(highestFloorCleared: 15);

      await tester.pumpWidget(
        wrapWithTheme(
          InfiniteSpireOverlay(
            config: spireConfig,
            progress: progress,
            playerLevel: 45,
            onFightFloor: (_) {},
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final filterChip = find.byKey(const Key('infinite_spire_boss_filter'));
      expect(filterChip, findsOneWidget);

      // Aktifkan filter bos
      await tester.tap(filterChip);
      await tester.pumpAndSettle();

      // Harus menampilkan lantai 10 dengan badge bos
      expect(find.text('F10 (BOS)'), findsOneWidget);
      expect(find.text('Corrupted Guardian'), findsOneWidget);
    });

    testWidgets('lantai 100 terdefinisi sebagai Peak Floor dengan nama bos', (
      tester,
    ) async {
      const progress = InfiniteSpireProgressSnapshot(highestFloorCleared: 99);

      await tester.pumpWidget(
        wrapWithTheme(
          InfiniteSpireOverlay(
            config: spireConfig,
            progress: progress,
            playerLevel: 90,
            onFightFloor: (_) {},
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Aktifkan filter bos untuk langsung melihat lantai puncak
      await tester.tap(find.byKey(const Key('infinite_spire_boss_filter')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('F100 (PEAK)'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('F100 (PEAK)'), findsOneWidget);
      expect(find.text('Apex Aether Sovereign'), findsOneWidget);
      expect(find.byKey(const Key('infinite_spire_fight_100')), findsOneWidget);
    });
  });

  group('TownHubView & GameSessionCoordinator integration', () {
    testWidgets('TownHubView menampilkan tombol quick access Infinite Spire', (
      tester,
    ) async {
      var spireOpened = false;
      final character = PlayerCharacter(
        config: realConfig.progression,
        progress: const PlayerProgress(level: 40, gold: 1000),
        skillCatalog: realConfig.skills,
        specializationConfig: realConfig.specializations,
      );
      final inventory = Inventory(definitions: realConfig.items);
      final views = InventoryViews(inventory: inventory, character: character);

      await tester.pumpWidget(
        wrapWithTheme(
          MaterialApp(
            home: Scaffold(
              body: TownHubView(
                character: character,
                views: views,
                items: realConfig.items,
                dungeonProgress: const DungeonProgressSnapshot(),
                dungeonDefinition: realConfig.dungeons.values.first,
                onEnterDungeon: () {},
                onEquip: (_) {},
                onUnequip: (_) {},
                onChooseSpecialization: (_) {},
                onOpenInfiniteSpire: () => spireOpened = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final spireButton = find.byKey(const Key('quick_access_infinite_spire'));
      expect(spireButton, findsOneWidget);
      expect(find.text('Spire'), findsOneWidget);
      expect(find.text('100 Lantai'), findsOneWidget);

      await tester.tap(spireButton);
      await tester.pumpAndSettle();
      expect(spireOpened, isTrue);
    });

    test('GameSessionCoordinator.startInfiniteSpireRun menginisialisasi runtime dungeon', () async {
      final repo = _MemorySaveRepository();
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: realConfig,
      );
      final dungeonManager = DungeonManager(dungeons: realConfig.dungeons);
      final character = PlayerCharacter(
        config: realConfig.progression,
        progress: const PlayerProgress(level: 50, gold: 2000),
        skillCatalog: realConfig.skills,
        specializationConfig: realConfig.specializations,
      );
      final inventory = Inventory(definitions: realConfig.items);
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: realConfig.items,
        lootTables: realConfig.lootTables,
        equipmentFactory: EquipmentFactory(realConfig.equipment),
      );

      final prepared = await coordinator.startInfiniteSpireRun(
        floorNumber: 5,
        dungeonManager: dungeonManager,
        character: character,
        inventory: inventory,
        dungeon: const DungeonProgressSnapshot(),
        dungeonProgresses: const {},
        cycleProgress: const CycleProgress(),
        rewardProcessor: rewardProcessor,
        autoSkillEnabled: false,
        lastOfflineClaimAtMs: 0,
      );

      expect(prepared.floor.floor, equals(5));
      expect(prepared.dungeon.id, equals('infinite_spire_f5'));
      expect(dungeonManager.activeDungeon?.id, equals('infinite_spire_f5'));
      expect(dungeonManager.activeRoom?.id, equals('infinite_spire_f5_room'));
    });

    test('GameSessionCoordinator.executeHeroAscension mengeksekusi terobosan dan rollback saat storage error', () async {
      final repo = _MemorySaveRepository();
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: realConfig,
      );
      final character = PlayerCharacter(
        config: realConfig.progression,
        progress: const PlayerProgress(
          level: 40,
          gold: 50000,
          ascensionPhase: 0,
        ),
        skillCatalog: realConfig.skills,
        specializationConfig: realConfig.specializations,
      );
      final inventory = Inventory(definitions: realConfig.items);
      inventory.add('boss_remnant', 5);
      final currencyService = CurrencyService(
        definitions: realConfig.currencies,
      );
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: realConfig.items,
        lootTables: realConfig.lootTables,
        equipmentFactory: EquipmentFactory(realConfig.equipment),
      );

      // 1. Eksekusi sukses A0 -> A1
      final result = await coordinator.executeHeroAscension(
        character: character,
        inventory: inventory,
        currencyService: currencyService,
        dungeon: const DungeonProgressSnapshot(),
        dungeonProgresses: const {},
        cycleProgress: const CycleProgress(),
        rewardProcessor: rewardProcessor,
        autoSkillEnabled: false,
        lastOfflineClaimAtMs: 0,
      );

      expect(result.succeeded, isTrue);
      expect(result.newPhase, equals(1));
      expect(character.ascensionPhase, equals(1));
      expect(character.gold, equals(49500)); // 50000 - 500 (biaya A1)
      expect(inventory.quantityOf('boss_remnant'), equals(2)); // 5 - 3
      expect(repo.stored, isNotNull);
      expect(repo.stored!.character.progress.ascensionPhase, equals(1));

      // 2. Simulasi error repository memicu rollback
      repo.shouldThrow = true;
      // Tingkatkan level ke 50 dan tambahkan material untuk A1 -> A2
      character.receiveReward(exp: 999999);
      inventory.add('boss_remnant', 10);
      inventory.add('aether_scrap', 20);
      final preRollbackPhase = character.ascensionPhase;
      final preRollbackGold = character.gold;
      final preRollbackRemnants = inventory.quantityOf('boss_remnant');

      await expectLater(
        coordinator.executeHeroAscension(
          character: character,
          inventory: inventory,
          currencyService: currencyService,
          dungeon: const DungeonProgressSnapshot(),
          dungeonProgresses: const {},
          cycleProgress: const CycleProgress(),
          rewardProcessor: rewardProcessor,
          autoSkillEnabled: false,
          lastOfflineClaimAtMs: 0,
        ),
        throwsA(isA<Exception>()),
      );

      // Pastikan state di-rollback sempurna
      expect(character.ascensionPhase, equals(preRollbackPhase));
      expect(character.gold, equals(preRollbackGold));
      expect(inventory.quantityOf('boss_remnant'), equals(preRollbackRemnants));
    });
  });
}
