import 'package:drift/drift.dart' show InsertMode;
import 'package:drift/native.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/game_settings.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/features/dungeon/character_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/settings_overlay.dart';
import 'package:echoes_of_aether/game/audio/audio_service.dart';
import 'package:echoes_of_aether/game/echoes_game.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAudioBackend implements AudioBackend {
  final List<String> sfxPlayed = [];
  final List<double> sfxVolumes = [];
  int bgmPlayCount = 0;
  int bgmStopCount = 0;
  int bgmPauseCount = 0;
  int bgmResumeCount = 0;
  double? lastBgmVolume;
  bool shouldThrow = false;

  @override
  Future<void> preloadAll(List<String> files) async {
    if (shouldThrow) throw StateError('no audio platform');
  }

  @override
  Future<void> playSfx(String file, {required double volume}) async {
    if (shouldThrow) throw StateError('no audio platform');
    sfxPlayed.add(file);
    sfxVolumes.add(volume);
  }

  @override
  Future<void> playBgm(String file, {required double volume}) async {
    if (shouldThrow) throw StateError('no audio platform');
    bgmPlayCount++;
    lastBgmVolume = volume;
  }

  @override
  Future<void> stopBgm() async {
    if (shouldThrow) throw StateError('no audio platform');
    bgmStopCount++;
  }

  @override
  Future<void> pauseBgm() async {
    if (shouldThrow) throw StateError('no audio platform');
    bgmPauseCount++;
  }

  @override
  Future<void> resumeBgm() async {
    if (shouldThrow) throw StateError('no audio platform');
    bgmResumeCount++;
  }

  @override
  Future<void> setBgmVolume(double volume) async {
    if (shouldThrow) throw StateError('no audio platform');
    lastBgmVolume = volume;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  const progression = ProgressionConfig(
    maxLevel: 20,
    expBase: 50,
    expGrowth: 1.4,
    baseStats: CombatStats(maxHp: 100, atk: 12, def: 3),
    perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
  );

  const testConfig = GameConfig(
    monsters: {},
    revive: ReviveConfig(),
    progression: progression,
    items: {},
    lootTables: {},
    skills: {
      'power_strike': SkillDefinition(
        id: 'power_strike',
        name: 'Power Strike',
        type: SkillType.active,
        unlockLevel: 1,
        cooldownSeconds: 4,
        baseValue: 1.5,
        valuePerLevel: 0.2,
        maxLevel: 3,
        upgradeCost: 50,
      ),
      'iron_will': SkillDefinition(
        id: 'iron_will',
        name: 'Iron Will',
        type: SkillType.passive,
        unlockLevel: 5,
        baseValue: 1.0,
        valuePerLevel: 0.25,
        maxLevel: 5,
        upgradeCost: 80,
      ),
    },
  );

  group('GameSettingsRepository (Drift GameSettings table)', () {
    test(
      'menyimpan, memuat ulang, dan memvalidasi data korup secara aman',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.initialize();

        final repo = DriftPlayerSaveRepository(db: db, config: testConfig);
        expect(await repo.loadSettings(), const GameSettingsData());

        const custom = GameSettingsData(
          bgmEnabled: false,
          sfxEnabled: true,
          bgmVolume: 0.25,
          sfxVolume: 0.90,
        );
        await repo.saveSettings(custom);

        final repo2 = DriftPlayerSaveRepository(db: db, config: testConfig);
        final loaded = await repo2.loadSettings();
        expect(loaded, custom);

        // Korupkan isi tabel dan pastikan fallback/clamp aman bekerja.
        await db
            .into(db.gameSettings)
            .insert(
              GameSettingsCompanion.insert(
                key: 'audio.bgm_volume',
                value: 'not_a_number',
              ),
              mode: InsertMode.insertOrReplace,
            );
        await db
            .into(db.gameSettings)
            .insert(
              GameSettingsCompanion.insert(
                key: 'audio.sfx_volume',
                value: '3.5',
              ),
              mode: InsertMode.insertOrReplace,
            );

        final sanitized = await repo2.loadSettings();
        expect(sanitized.bgmVolume, const GameSettingsData().bgmVolume);
        expect(sanitized.sfxVolume, 1.0);
      },
    );
  });

  group('AudioService', () {
    test('mengelola BGM, cooldown SFX, mute settings, dan error backend secara aman', () async {
      var now = 1000;
      final backend = _RecordingAudioBackend();
      final audio = AudioService(backend: backend, nowMs: () => now);

      await audio.startBgm();
      expect(backend.bgmPlayCount, 1);
      expect(backend.lastBgmVolume, closeTo(0.45, 1e-6));

      await audio.playSfx(AudioCue.slash);
      now += 20; // di bawah cooldown 75ms
      await audio.playSfx(AudioCue.slash);
      expect(backend.sfxPlayed, ['sfx_slash.wav']);

      now += 80;
      await audio.playSfx(AudioCue.slash);
      expect(backend.sfxPlayed, ['sfx_slash.wav', 'sfx_slash.wav']);

      await audio.pauseBgm();
      await audio.resumeBgm();
      expect(backend.bgmPauseCount, 1);
      expect(backend.bgmResumeCount, 1);

      // Matikan SFX & ubah BGM -> hentikan BGM dan blokir SFX.
      await audio.applySettings(
        const GameSettingsData(bgmEnabled: false, sfxEnabled: false),
      );
      expect(backend.bgmStopCount, 1);
      now += 500;
      await audio.playSfx(AudioCue.loot);
      expect(backend.sfxPlayed, hasLength(2));

      // Aktifkan BGM kembali -> mulai lagi otomatis jika sebelumnya aktif.
      await audio.applySettings(
        const GameSettingsData(bgmEnabled: true, bgmVolume: 0.6),
      );
      expect(backend.bgmPlayCount, 2);

      // Exception dari platform tidak boleh melempar error ke gameplay.
      backend.shouldThrow = true;
      now += 500;
      await audio.playSfx(AudioCue.levelUp);
      await audio.pauseBgm();
    });
  });

  group('Skill Upgrade UI & SettingsOverlay', () {
    testWidgets(
      'CharacterOverlay menampilkan upgrade skill, memotong gold, dan update level',
      (tester) async {
        final character = PlayerCharacter(
          config: progression,
          skillCatalog: testConfig.skills,
        )..receiveReward(gold: 60);
        final inventory = Inventory(definitions: const {});
        final views = InventoryViews(
          inventory: inventory,
          character: character,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CharacterOverlay(
                snapshot: views.characterView,
                onChooseSpecialization: (_) {},
                onUpgradeSkill: (id) {
                  final res = character.upgradeSkill(id);
                  if (res.status == SkillUpgradeStatus.upgraded) {
                    views.refresh();
                  }
                },
                onClose: () {},
              ),
            ),
          ),
        );

        expect(find.text('Gold 60'), findsOneWidget);
        expect(find.text('Power Strike • Lv 1/3'), findsOneWidget);
        expect(find.text('Upgrade (50G)'), findsOneWidget);
        expect(find.text('Terkunci'), findsOneWidget);

        await tester.tap(find.text('Upgrade (50G)'));
        await tester.pump();

        expect(character.gold, 10);
        expect(character.skillLevel('power_strike'), 2);
        expect(find.text('Gold 10'), findsOneWidget);
        expect(find.text('Power Strike • Lv 2/3'), findsOneWidget);
        expect(find.text('Upgrade (100G)'), findsOneWidget);

        // Saldo tinggal 10G -> tombol Upgrade (100G) nonaktif.
        final btn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Upgrade (100G)'),
        );
        expect(btn.onPressed, isNull);

        // Naikkan ke Lv 3 (MAX) lewat gold tambahan + upgrade.
        character.receiveReward(gold: 100);
        views.refresh();
        await tester.pump();
        await tester.tap(find.text('Upgrade (100G)'));
        await tester.pump();
        expect(find.text('MAX'), findsOneWidget);
      },
    );

    test('EchoesGame.upgradeSkill memanggil character.upgradeSkill dan memicu onBuildChanged', () {
      var buildChanged = 0;
      final character = PlayerCharacter(
        config: progression,
        skillCatalog: testConfig.skills,
      )..receiveReward(gold: 100);
      final game = EchoesGame(
        config: testConfig,
        character: character,
        inventory: Inventory(definitions: const {}),
        autoSkill: ValueNotifier(true),
        onBuildChanged: () => buildChanged++,
      );

      game.upgradeSkill('power_strike');
      expect(character.skillLevel('power_strike'), 2);
      expect(character.gold, 50);
      expect(buildChanged, 1);
      expect(game.views.characterView.value.gold, 50);
    });

    testWidgets(
      'SettingsOverlay memperbarui switch BGM/SFX, slider, dan tombol Tes Suara',
      (tester) async {
        final notifier = ValueNotifier<GameSettingsData>(
          const GameSettingsData(),
        );
        var testSfxClicks = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SettingsOverlay(
                settings: notifier,
                onChanged: (next) => notifier.value = next,
                onTestSfx: () => testSfxClicks++,
                onClose: () {},
              ),
            ),
          ),
        );

        await tester.tap(find.text('Tes Suara'));
        await tester.pump();
        expect(testSfxClicks, 1);

        await tester.tap(find.text('Musik Latar (BGM)'));
        await tester.pump();
        expect(notifier.value.bgmEnabled, isFalse);

        await tester.tap(find.text('Efek Suara (SFX)'));
        await tester.pump();
        expect(notifier.value.sfxEnabled, isFalse);

        final testBtn = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Tes Suara'),
        );
        expect(testBtn.onPressed, isNull);
      },
    );
  });
}
