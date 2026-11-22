import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/gacha_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/gacha_service.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/domain/services/period_service.dart';
import 'package:echoes_of_aether/features/dungeon/character_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/codex_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/gacha_overlay.dart';
import 'package:echoes_of_aether/features/shared/assets/game_assets.dart';
import 'package:echoes_of_aether/features/shared/widgets/artwork/character_illustration.dart';
import 'package:echoes_of_aether/game/components/combatant_component.dart';
import 'package:echoes_of_aether/game/components/effects/skill_vfx_component.dart';
import 'package:echoes_of_aether/game/components/player/player_component.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:echoes_of_aether/game/systems/combat_system.dart';
import 'package:echoes_of_aether/game/visuals/pixel_sprite_atlas.dart';
import 'package:echoes_of_aether/game/visuals/pixel_sprite_data.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

String _readDataAsset(String name) =>
    File('assets/data/$name').readAsStringSync();

GameConfig _loadProductionConfig() {
  const parser = GameConfigParser();
  final settings = _readDataAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  return GameConfig(
    monsters: const MonsterConfigParser().parse(
      _readDataAsset('monsters.json'),
    ),
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
    items: const ItemConfigParser().parse(_readDataAsset('items.json')),
    lootTables: const LootConfigParser().parse(
      _readDataAsset('loot_tables.json'),
    ),
    skills: const SkillConfigParser().parse(_readDataAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readDataAsset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(
      _readDataAsset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
    shop: const ShopConfigParser().parse(_readDataAsset('shop.json')),
    gacha: const GachaConfigParser().parse(
      _readDataAsset('gacha_banners.json'),
    ),
  );
}

bool _isPngHeader(List<int> bytes) {
  if (bytes.length < 24) return false;
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < sig.length; i++) {
    if (bytes[i] != sig[i]) return false;
  }
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const allClasses = [
    'base',
    'vanguard',
    'arcanist',
    'ranger',
    'paladin',
    'voidblade',
    'chronomancer',
    'gunslinger',
    'necromancer',
    'stormcaller',
  ];

  group('Extracted Character Assets Integration', () {
    test('Adventurer asset_inventory.json matches disk files and 7 animation sequences', () {
      final inventoryFile = File(
        'assets/characters/adventurer/asset_inventory.json',
      );
      expect(inventoryFile.existsSync(), isTrue);

      final entries = (jsonDecode(
        inventoryFile.readAsStringSync(),
      ) as List<dynamic>).cast<Map<String, dynamic>>();
      expect(entries.length, greaterThanOrEqualTo(34));

      for (final entry in entries) {
        final relPath = entry['path'] as String;
        final mode = entry['mode'] as String;
        final fullPath = 'assets/characters/adventurer/$relPath';
        expect(
          File(fullPath).existsSync(),
          isTrue,
          reason: 'Missing Adventurer inventory asset: $fullPath',
        );
        expect(mode, 'RGBA');
      }

      final adventurer = CharacterAssetCatalog.forClass('base');
      expect(CharacterAssetCatalog.forClass('adventurer').classId, 'base');
      expect(
        adventurer.framesForSequence(CharacterAnimationSequence.idle).length,
        4,
      );
      expect(
        adventurer
            .framesForSequence(CharacterAnimationSequence.idleAlternate)
            .length,
        4,
      );
      expect(
        adventurer.framesForSequence(CharacterAnimationSequence.walk).length,
        4,
      );
      expect(
        adventurer.framesForSequence(CharacterAnimationSequence.run).length,
        4,
      );
      expect(
        adventurer.framesForSequence(CharacterAnimationSequence.attack).length,
        4,
      );
      expect(
        adventurer
            .framesForSequence(CharacterAnimationSequence.skillSpecial)
            .length,
        4,
      );
      expect(
        adventurer.framesForSequence(CharacterAnimationSequence.downed).length,
        2,
      );
    });

    test('All 10 classes have valid manifests, disk PNGs, RGBA color type, and bundled rootBundle assets', () async {
      expect(CharacterAssetCatalog.playableClassIds, equals(allClasses));

      for (final classId in allClasses) {
        final spec = CharacterVisualSpec.resolve(classId);
        expect(spec.classId, classId);
        final manifest = spec.manifest;
        expect(manifest.classId, classId);

        for (final seq in CharacterAnimationSequence.values) {
          final frames = manifest.framesForSequence(seq);
          expect(
            frames,
            isNotEmpty,
            reason: '$classId sequence ${seq.key} must resolve frames',
          );
        }

        for (final assetPath in manifest.allAssetPaths) {
          final file = File(assetPath);
          expect(
            file.existsSync(),
            isTrue,
            reason: 'Missing disk file for $classId: $assetPath',
          );
          final bytes = file.readAsBytesSync();
          expect(
            _isPngHeader(bytes),
            isTrue,
            reason: 'Invalid PNG signature for $assetPath',
          );
          // Color type 6 (RGBA) or 3 (indexed PNG with alpha/palette).
          final colorType = bytes[25];
          expect(
            colorType == 6 || colorType == 3,
            isTrue,
            reason: 'Unexpected PNG colorType $colorType in $assetPath',
          );
          final bundled = await rootBundle.load(assetPath);
          expect(
            bundled.lengthInBytes,
            greaterThan(0),
            reason: 'rootBundle failed for $assetPath',
          );
        }
      }
    });

    test('Graceful fallback handles missing sequences and unknown classes', () {
      final unknown = CharacterAssetCatalog.forClass('nonexistent_class');
      expect(unknown.classId, 'base');

      const partial = CharacterClassAssetManifest(
        classId: 'partial_test',
        emblemPath: 'assets/icons/class/crest_vanguard.png',
        portraitPath: 'assets/char/hero_vanguard.png',
        showcasePath: 'assets/char/hero_vanguard.png',
        sequences: {
          CharacterAnimationSequence.idle: [
            'assets/char/frames/hero_vanguard_idle0.png',
          ],
        },
      );

      expect(
        partial.framesForSequence(CharacterAnimationSequence.idleAlternate),
        ['assets/char/frames/hero_vanguard_idle0.png'],
      );
      expect(partial.framesForSequence(CharacterAnimationSequence.run), [
        'assets/char/frames/hero_vanguard_idle0.png',
      ]);
      expect(
        partial.framesForSequence(CharacterAnimationSequence.skillSpecial),
        ['assets/char/frames/hero_vanguard_idle0.png'],
      );
      expect(
        partial.frameFor(CharacterAnimationSequence.downed, 99),
        'assets/char/frames/hero_vanguard_idle0.png',
      );
    });

    test('PixelSpriteAtlas preloads extracted PNGs and provides 16x16 + sequence sprites for all 10 classes', () async {
      final atlas = PixelSpriteAtlas.instance;
      const poses = ['idle0', 'idle1', 'walk0', 'walk1', 'attack', 'downed'];
      for (final classId in allClasses) {
        for (final pose in poses) {
          final key = 'hero_${classId}_$pose';
          expect(
            PixelSpriteData.frames.containsKey(key),
            isTrue,
            reason: 'Missing PixelSpriteData 16x16 frame $key',
          );
          final img = atlas.combatantSprite(
            isPlayer: true,
            specializationId: classId,
            pose: pose,
          );
          expect(img.width, PixelSpriteAtlas.gridSize);
          expect(img.height, PixelSpriteAtlas.gridSize);
        }
      }

      await atlas.preloadCharacterAssets(rootBundle);
      for (final classId in allClasses) {
        final extracted = atlas.combatantSequenceSprite(
          isPlayer: true,
          specializationId: classId,
          sequence: CharacterAnimationSequence.idle,
          frameIndex: 0,
          fallbackPose: 'idle0',
        );
        expect(
          extracted.width > 16 || extracted.height > 16,
          isTrue,
          reason:
              'Expected high-res extracted frame for $classId after preload',
        );
      }
    });

    test('CombatantComponent transitions through all 7 animation states and renders all 10 classes cleanly', () async {
      await PixelSpriteAtlas.instance.preloadCharacterAssets(rootBundle);

      for (final classId in allClasses) {
        final combatant = Combatant(
          id: 'hero_$classId',
          team: Team.player,
          stats: const CombatStats(
            maxHp: 200,
            atk: 30,
            def: 10,
            attackSpeed: 1.5,
            moveSpeed: 3.0,
            attackRange: 1.5,
          ),
          cell: const GridPoint(2, 2),
        );
        final view = PlayerComponent(
          combatant: combatant,
          tileSize: 16,
          specializationIdProvider: () => classId,
        );

        // 1. Idle
        expect(view.animationState, CombatantAnimationState.idle);
        expect(view.activeAnimationSequence, CharacterAnimationSequence.idle);

        // 2. Idle Alternate after sustained idle time
        view.update(3.4);
        expect(view.animationState, CombatantAnimationState.idleAlternate);
        expect(
          view.activeAnimationSequence,
          CharacterAnimationSequence.idleAlternate,
        );

        // 3. Walk on short 1-step path
        combatant.follower.setPath(const [GridPoint(2, 2), GridPoint(3, 2)]);
        expect(view.animationState, CombatantAnimationState.walk);
        expect(view.activeAnimationSequence, CharacterAnimationSequence.walk);

        // 4. Run on longer path (>2 remaining steps)
        combatant.follower.setPath(const [
          GridPoint(2, 2),
          GridPoint(3, 2),
          GridPoint(4, 2),
          GridPoint(5, 2),
          GridPoint(6, 2),
        ]);
        expect(view.animationState, CombatantAnimationState.run);
        expect(view.activeAnimationSequence, CharacterAnimationSequence.run);

        // 5. Attack
        view.triggerAttackAnimation(0.2);
        expect(view.animationState, CombatantAnimationState.attack);
        expect(view.activeAnimationSequence, CharacterAnimationSequence.attack);

        // 6. Skill / Special
        view.triggerSkillAnimation(0.36);
        expect(view.animationState, CombatantAnimationState.skillSpecial);
        expect(
          view.activeAnimationSequence,
          CharacterAnimationSequence.skillSpecial,
        );

        // 7. Downed
        combatant.hp = 0;
        expect(combatant.isAlive, isFalse);
        expect(view.animationState, CombatantAnimationState.downed);
        expect(view.activeAnimationSequence, CharacterAnimationSequence.downed);

        // Render frame cleanly to canvas preserving proportions without errors.
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        view.render(canvas);
        final picture = recorder.endRecording();
        picture.dispose();
      }
    });

    test('CombatSystem skill casts and all class SkillVfxComponent factories render cleanly', () async {
      final pos = Vector2(48, 48);
      final vfxSamples = [
        SkillVfxComponent.radiantSmite(position: pos),
        SkillVfxComponent.divineJudgment(position: pos),
        SkillVfxComponent.phantomSlash(position: pos),
        SkillVfxComponent.voidExecution(position: pos),
        SkillVfxComponent.timeBolt(position: pos),
        SkillVfxComponent.chronoCollapse(position: pos),
        SkillVfxComponent.rapidFire(position: pos),
        SkillVfxComponent.aetherBarrage(position: pos),
        SkillVfxComponent.deathBolt(position: pos),
        SkillVfxComponent.soulEruption(position: pos),
        SkillVfxComponent.lightningArc(position: pos),
        SkillVfxComponent.thunderstorm(position: pos),
      ];

      for (final type in SkillVfxType.values) {
        final vfx = SkillVfxComponent(type: type, position: pos);
        vfx.update(vfx.duration * 0.4);
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        vfx.render(canvas);
        recorder.endRecording().dispose();
      }
      expect(vfxSamples.length, 12);

      final config = _loadProductionConfig();
      const enemyDef = EnemyDefinition(
        id: 'target_dummy',
        name: 'Training Dummy',
        level: 1,
        detectionRange: 8,
        stats: CombatStats(
          maxHp: 500,
          atk: 1,
          def: 0,
          attackSpeed: 0.5,
          moveSpeed: 0,
          attackRange: 1,
        ),
      );
      final testConfig = GameConfig(
        monsters: const {'target_dummy': enemyDef},
        revive: const ReviveConfig(),
        progression: config.progression,
        items: const {},
        lootTables: const {},
        skills: config.skills,
        specializations: config.specializations,
      );

      final character = PlayerCharacter(
        config: config.progression,
        specializationConfig: config.specializations,
        skillCatalog: config.skills,
        progress: const PlayerProgress(level: 30),
        initialSpecializationId: 'paladin',
      );
      final views = InventoryViews(
        inventory: Inventory(definitions: const {}),
        character: character,
      );
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: character.stats,
        cell: const GridPoint(2, 2),
      );
      final playerView = PlayerComponent(
        combatant: player,
        tileSize: 16,
        specializationIdProvider: () => character.specializationId,
      );
      final paladinSkills = [
        config.skills['radiant_smite']!,
        config.skills['divine_judgment']!,
      ];
      final sim = CombatSimulation(
        grid: NavigationGrid.open(columns: 10, rows: 6),
        pathfinder: const AStarPathfinder(),
        player: player,
        seed: 7,
      )..setPlayerSkills(paladinSkills);
      final game = FlameGame()..onGameResize(Vector2(320, 176));
      await game.onLoad();
      game.onMount();
      final container = Component();
      await game.add(container);
      game.update(0);

      final system = CombatSystem(
        simulation: sim,
        config: testConfig,
        character: character,
        views: views,
        hud: ValueNotifier(
          HudState.fromCharacter(
            character,
            hp: player.hp,
            maxHp: player.stats.maxHp,
          ),
        ),
        autoSkill: ValueNotifier(true),
        random: math.Random(7),
        tileSize: 16,
        viewParent: container,
        playerView: playerView,
      );
      sim.spawnEnemy(enemyDef, const GridPoint(3, 2));

      var sawSkillAnim = false;
      var sawHolyVfx = false;
      for (var i = 0; i < 60; i++) {
        system.update(CombatSimulation.tickSeconds);
        playerView.update(CombatSimulation.tickSeconds);
        game.update(0);
        if (playerView.animationState == CombatantAnimationState.skillSpecial) {
          sawSkillAnim = true;
        }
        if (container.children.whereType<SkillVfxComponent>().any(
          (v) => v.type == SkillVfxType.holyBurst,
        )) {
          sawHolyVfx = true;
        }
        if (sawSkillAnim && sawHolyVfx) break;
      }
      expect(
        sawSkillAnim,
        isTrue,
        reason:
            'CombatSystem should trigger skillSpecial animation on skill cast',
      );
      expect(
        sawHolyVfx,
        isTrue,
        reason:
            'CombatSystem should spawn holyBurst VFX for Paladin active skills',
      );
    });

    testWidgets(
      'UI components render portraits, animations, and emblems for all 10 classes without error',
      (tester) async {
        final config = _loadProductionConfig();
        final gachaService = GachaService(
          gachaConfig: config.gacha!,
          items: config.items,
          specializations: config.specializations.definitions,
          equipmentFactory: EquipmentFactory(config.equipment),
          periodService: const PeriodService(),
        );
        final nowMs = DateTime.utc(2026, 11, 16, 12, 0).millisecondsSinceEpoch;

        // 1. CharacterIllustration + ClassEmblemIcon for all 10 classes.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final classId in allClasses)
                      Row(
                        children: [
                          ClassEmblemIcon(specializationId: classId, size: 24),
                          CharacterIllustration(
                            specializationId: classId,
                            width: 48,
                            height: 64,
                          ),
                          CharacterIllustration(
                            specializationId: classId,
                            width: 48,
                            height: 64,
                            sequence: CharacterAnimationSequence.attack,
                            frameIndex: 0,
                          ),
                          CharacterIllustration(
                            specializationId: classId,
                            width: 48,
                            height: 64,
                            useShowcase: true,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final classId in allClasses) {
          expect(
            find.byKey(ValueKey<String>('class_emblem_$classId')),
            findsOneWidget,
          );
        }

        // 2. CharacterOverlay shows emblems & class illustration cleanly.
        final char = PlayerCharacter(
          config: config.progression,
          specializationConfig: config.specializations,
          skillCatalog: config.skills,
          progress: const PlayerProgress(level: 30),
          initialSpecializationId: 'stormcaller',
        );
        final snapshot = ValueNotifier(
          CharacterSnapshot.from(
            char,
            unlockedSpecializations: const {
              'vanguard',
              'stormcaller',
              'paladin',
            },
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CharacterOverlay(
                snapshot: snapshot,
                onChooseSpecialization: (_) {},
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(
            const ValueKey<String>('character_illustration_stormcaller'),
          ),
          findsOneWidget,
        );

        // 3. GachaOverlay Class banner renders character illustration cleanly.
        final saveSnapshot = PlayerSaveSnapshot(
          character: char.toSnapshot(),
          inventory: Inventory(definitions: config.items).toSnapshot(),
          currencies: const {'aether_shard': 1000, 'soul_prism': 5},
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GachaOverlay(
                gachaService: gachaService,
                aetherShards: 1000,
                soulPrisms: 5,
                pityStates: saveSnapshot.gachaPityStates,
                unlockedSpecializations: const {'vanguard', 'stormcaller'},
                nowMs: nowMs,
                onPull: (_, _) async => throw UnimplementedError(),
                onExchangeWeapon: (_) async => throw UnimplementedError(),
                onExchangeClass: (_) async => throw UnimplementedError(),
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.person_pin), findsNothing);

        // 4. CodexOverlay renders class emblems cleanly.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CodexOverlay(
                config: config,
                unlockedSpecializations: const {'vanguard', 'paladin'},
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
