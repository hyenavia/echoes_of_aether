import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_completed_overlay.dart';
import 'package:echoes_of_aether/widgets/game_button.dart';
import 'package:echoes_of_aether/widgets/game_panel.dart';

void main() {
  group('Tahap 4: Pop-up Dungeon Selesai Visual Overhaul Tests', () {
    testWidgets(
      'DungeonCompletedOverlay menggunakan BackdropFilter, ConfettiWidget, dan GamePanel.goldOrnate',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: DungeonCompletedOverlay(
                dungeonName: 'Ancient Labyrinth',
                clearedRoomsCount: 5,
                isFinalBoss: true,
                completionReward: const GrantedReward(
                  eventId: 'test_event_1',
                  alreadyClaimed: false,
                  expGranted: 250,
                  goldGranted: 100,
                  levelsGained: 1,
                  displayParts: ['Aether Crystal x2'],
                ),
                onRetry: () {},
                onReturnToTown: () {},
              ),
            ),
          ),
        );

        // 1. Verifikasi BackdropFilter (blur) pada background
        expect(find.byType(BackdropFilter), findsOneWidget);

        // 2. Verifikasi ConfettiWidget di belakang pop-up
        expect(find.byType(ConfettiWidget), findsOneWidget);

        // 3. Verifikasi GamePanel desain emas mewah
        final panelFinder = find.byType(GamePanel);
        expect(panelFinder, findsOneWidget);
        final panelWidget = tester.widget<GamePanel>(panelFinder);
        expect(panelWidget.style, equals(GamePanelStyle.goldOrnate));
        expect(panelWidget.showGlow, isTrue);

        // 4. Verifikasi Judul dan Badge Final Boss
        expect(find.text('Dungeon Selesai!'), findsOneWidget);
        expect(find.text('Final Boss'), findsOneWidget);
        expect(
          find.text('Ancient Labyrinth ditaklukkan (5 room selesai).'),
          findsOneWidget,
        );

        // 5. Verifikasi Item Card untuk Hadiah EXP, Gold, dan Level Gained
        expect(find.text('HADIAH PENYELESAIAN'), findsOneWidget);
        expect(find.text('+250 EXP'), findsOneWidget);
        expect(find.text('Pengalaman'), findsOneWidget);
        expect(find.text('+100 Gold'), findsOneWidget);
        expect(find.text('Koin Emas'), findsOneWidget);
        expect(find.text('+1 Level'), findsOneWidget);
        expect(find.text('Naik Level!'), findsOneWidget);
        expect(find.text('Hadiah Tambahan: Aether Crystal x2'), findsOneWidget);

        // 6. Verifikasi Tombol GameButton kustom dengan animasi pulse pada Run Baru
        final runBaruFinder = find.widgetWithText(GameButton, 'Run baru');
        expect(runBaruFinder, findsOneWidget);
        final runBaruBtn = tester.widget<GameButton>(runBaruFinder);
        expect(runBaruBtn.pulse, isTrue);

        final townBtnFinder = find.widgetWithText(
          GameButton,
          'Kembali ke Town',
        );
        expect(townBtnFinder, findsOneWidget);
      },
    );

    testWidgets(
      'Tombol Run baru memicu callback onRetry dan Kembali ke Town memicu onReturnToTown',
      (tester) async {
        bool retryCalled = false;
        bool returnTownCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: DungeonCompletedOverlay(
                dungeonName: 'Forgotten Forest',
                clearedRoomsCount: 3,
                onRetry: () => retryCalled = true,
                onReturnToTown: () => returnTownCalled = true,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Run baru'));
        await tester.pump();
        expect(retryCalled, isTrue);

        await tester.tap(find.text('Kembali ke Town'));
        await tester.pump();
        expect(returnTownCalled, isTrue);
      },
    );

    testWidgets(
      'Mode Ascension menampilkan rank baru dan tombol tunggal beranimasi pulse',
      (tester) async {
        bool returnTownCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: DungeonCompletedOverlay(
                dungeonName: 'Ascension Sanctum',
                clearedRoomsCount: 6,
                isAscension: true,
                previousAscensionRank: 1,
                newAscensionRank: 2,
                onReturnToTown: () => returnTownCalled = true,
              ),
            ),
          ),
        );

        expect(find.text('Ascension Selesai!'), findsOneWidget);
        expect(find.text('Ascension Rank 1 → Rank 2'), findsOneWidget);

        // Hanya tombol Kembali ke Town yang muncul (tanpa Run baru)
        expect(find.text('Run baru'), findsNothing);
        final townBtnFinder = find.widgetWithText(
          GameButton,
          'Kembali ke Town',
        );
        expect(townBtnFinder, findsOneWidget);
        final townBtn = tester.widget<GameButton>(townBtnFinder);
        expect(townBtn.pulse, isTrue);

        await tester.tap(townBtnFinder);
        await tester.pump();
        expect(returnTownCalled, isTrue);
      },
    );
  });
}
