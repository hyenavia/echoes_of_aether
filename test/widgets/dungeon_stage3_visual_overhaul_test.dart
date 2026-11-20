import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/features/dungeon/hud_overlay.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:echoes_of_aether/widgets/game_panel.dart';
import 'package:echoes_of_aether/widgets/game_progress_bar.dart';

void main() {
  group('Tahap 3: Dungeon Gameplay UI Overhaul Tests', () {
    testWidgets(
      'HUD Hero Panel menggunakan GamePanel semi-transparan & GameProgressBar untuk HP dan EXP',
      (tester) async {
        final hud = ValueNotifier<HudState>(
          const HudState(
            level: 12,
            currentExp: 350,
            expToNext: 1000,
            gold: 4850,
            hp: 240,
            maxHp: 300,
            dungeonName: 'Crystal Cavern',
            roomName: 'Subterranean Depths',
            totalEnemies: 5,
            activeEnemies: 2,
            exitRequired: true,
            exitUnlocked: true,
            roomStatus: 'Musuh tersisa',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(body: HudOverlay(state: hud)),
          ),
        );

        // 1. Verifikasi Hero Panel menggunakan GamePanel
        final heroPanelFinder = find.byKey(
          const ValueKey<String>('hud_hero_panel'),
        );
        expect(heroPanelFinder, findsOneWidget);
        final gamePanelWidget = tester.widget<GamePanel>(heroPanelFinder);
        expect(gamePanelWidget.opacity, equals(0.85));

        // 2. Verifikasi GameProgressBar untuk HP dan EXP
        final progressBars = find.descendant(
          of: heroPanelFinder,
          matching: find.byType(GameProgressBar),
        );
        expect(progressBars, findsNWidgets(2));

        // 3. Verifikasi teks dungeon, room, level, gold, dan exit
        expect(
          find.text('Crystal Cavern • Subterranean Depths'),
          findsOneWidget,
        );
        expect(find.text('Lv 12'), findsOneWidget);
        expect(find.text('Gold 4.9K'), findsOneWidget);
        expect(find.text('240/300 HP'), findsOneWidget);
        expect(find.text('EXP 35%'), findsOneWidget);
        expect(find.text('Musuh: 2/5'), findsOneWidget);
        expect(find.text('Exit: Terbuka'), findsOneWidget);
      },
    );

    testWidgets(
      'HUD Boss Encounter Plate menggunakan GamePanel berornamen & GameProgressBar',
      (tester) async {
        final hud = ValueNotifier<HudState>(
          const HudState(
            level: 25,
            currentExp: 100,
            expToNext: 2000,
            gold: 9999,
            hp: 450,
            maxHp: 500,
            bossName: 'Aether Chimera',
            bossHp: 8000,
            bossMaxHp: 10000,
            isFinalBoss: true,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(body: HudOverlay(state: hud)),
          ),
        );

        final bossPanelFinder = find.byKey(
          const ValueKey<String>('hud_boss_panel'),
        );
        expect(bossPanelFinder, findsOneWidget);

        final bossGamePanel = tester.widget<GamePanel>(bossPanelFinder);
        expect(bossGamePanel.showGlow, isTrue);

        expect(find.text('FINAL BOSS: Aether Chimera'), findsOneWidget);

        final bossProgressBar = find.descendant(
          of: bossPanelFinder,
          matching: find.byType(GameProgressBar),
        );
        expect(bossProgressBar, findsOneWidget);
        final barWidget = tester.widget<GameProgressBar>(bossProgressBar);
        expect(barWidget.value, closeTo(0.8, 0.01));
      },
    );

    testWidgets(
      'Floating Action Bar menampilkan slot skill berborder tebal, cooldown overlay, dan dapat ditekan',
      (tester) async {
        String? tappedSkillId;
        final hud = ValueNotifier<HudState>(
          const HudState(
            level: 10,
            currentExp: 50,
            expToNext: 500,
            gold: 1200,
            hp: 200,
            maxHp: 200,
            skills: [
              HudSkillInfo(
                id: 'skill_fireball',
                name: 'Fireball',
                cooldownSeconds: 8.0,
                remainingSeconds: 0.0,
                progress: 0.0,
                isReady: true,
              ),
              HudSkillInfo(
                id: 'skill_frost_nova',
                name: 'Frost Nova',
                cooldownSeconds: 15.0,
                remainingSeconds: 6.5,
                progress: 0.43,
                isReady: false,
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: HudOverlay(
                state: hud,
                onSkillTap: (id) => tappedSkillId = id,
              ),
            ),
          ),
        );

        final skillBarFinder = find.byKey(
          const ValueKey<String>('hud_skill_bar'),
        );
        expect(skillBarFinder, findsOneWidget);

        // Verifikasi kedua slot skill
        final fireballFinder = find.byKey(
          const ValueKey<String>('hud_skill_skill_fireball'),
        );
        final frostFinder = find.byKey(
          const ValueKey<String>('hud_skill_skill_frost_nova'),
        );
        expect(fireballFinder, findsOneWidget);
        expect(frostFinder, findsOneWidget);

        // Verifikasi nama skill
        expect(find.text('Fireball'), findsOneWidget);
        expect(find.text('Frost Nova'), findsOneWidget);

        // Verifikasi waktu cooldown skill kedua
        expect(find.text('6.5s'), findsOneWidget);

        // Tap Fireball -> pemicu callback interaksi skill
        await tester.tap(fireballFinder);
        await tester.pump();
        expect(tappedSkillId, equals('skill_fireball'));
      },
    );

    testWidgets(
      'Combat Feed semi-transparan memudar otomatis setelah jeda waktu',
      (tester) async {
        final hud = ValueNotifier<HudState>(
          const HudState(
            level: 5,
            currentExp: 20,
            expToNext: 100,
            gold: 250,
            hp: 150,
            maxHp: 150,
            transitionMessage: 'Memasuki Zona Kristal...',
            lastSkill: 'Arcane Shield',
            lastLoot: 'Ancient Rune',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(body: HudOverlay(state: hud)),
          ),
        );

        final feedFinder = find.byKey(
          const ValueKey<String>('hud_combat_feed'),
        );
        expect(feedFinder, findsOneWidget);

        expect(find.text('Memasuki Zona Kristal...'), findsOneWidget);
        expect(find.text('Skill: Arcane Shield'), findsOneWidget);
        expect(find.text('+ Ancient Rune'), findsOneWidget);

        // Pada detik 0, opasitas awal terlihat (1.0)
        final opacityFinder = find.descendant(
          of: feedFinder,
          matching: find.byType(Opacity),
        );
        expect(opacityFinder, findsOneWidget);
        final initialOpacity = tester.widget<Opacity>(opacityFinder);
        expect(initialOpacity.opacity, equals(1.0));

        // Majukan waktu timer (3.3 detik) lalu jalankan frame animasi (1 detik) -> auto-fade aktif menuju 0.20
        await tester.pump(const Duration(milliseconds: 3300));
        await tester.pump(const Duration(milliseconds: 1000));
        final fadedOpacity = tester.widget<Opacity>(opacityFinder);
        expect(fadedOpacity.opacity, lessThan(0.5));
      },
    );
  });
}
