import 'package:echoes_of_aether/theme/app_theme.dart';
import 'package:echoes_of_aether/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tahap 1: AppTheme Dark Fantasy Foundation Tests', () {
    test('AppTheme palet warna utama memenuhi spesifikasi Dark Fantasy', () {
      // Background Deep Navy / Slate
      expect(AppTheme.background, const Color(0xFF090D16));
      expect(AppTheme.backgroundSecondary, const Color(0xFF0F1523));
      expect(AppTheme.surface, const Color(0xFF141C2B));

      // Aksen Utama
      expect(AppTheme.gold, const Color(0xFFFFD700));
      expect(AppTheme.arcanePurple, const Color(0xFF9D4EDD));
      expect(AppTheme.cyanGlow, const Color(0xFF00F5D4));

      // Item Rarity
      expect(AppTheme.rarityCommon, const Color(0xFF94A3B8));
      expect(AppTheme.rarityRare, const Color(0xFF3B82F6));
      expect(AppTheme.rarityEpic, const Color(0xFF9D4EDD));
      expect(AppTheme.rarityLegendary, const Color(0xFFFFD700));
    });

    test('AppTheme typography menghasilkan font fantasy dan stat tabular', () {
      final heading = AppTheme.headingFantasy(fontSize: 22);
      expect(heading.fontFamily, AppTheme.fantasyFontFamily);
      expect(heading.color, AppTheme.gold);
      expect(heading.shadows, isNotNull);
      expect(heading.shadows!.isNotEmpty, isTrue);

      final stat = AppTheme.statNumber(fontSize: 14);
      expect(stat.fontFamily, AppTheme.statsFontFamily);
      expect(stat.fontFeatures, isNotNull);
      expect(stat.shadows, isNotNull);
    });

    test(
      'AppTheme.darkTheme() menghasilkan ThemeData dark fantasy terintegrasi',
      () {
        final theme = AppTheme.darkTheme();
        expect(theme.brightness, Brightness.dark);
        expect(theme.scaffoldBackgroundColor, AppTheme.background);
        expect(theme.colorScheme.primary, AppTheme.gold);
        expect(theme.colorScheme.secondary, AppTheme.arcanePurple);
        expect(theme.colorScheme.tertiary, AppTheme.cyanGlow);
      },
    );
  });

  group('Tahap 1: GamePanel Reusable Widget Tests', () {
    testWidgets(
      'GamePanel merender 9-slice frame image dan child dengan benar',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: GamePanel(
                  style: GamePanelStyle.goldOrnate,
                  title: 'KARTU HERO',
                  child: Text('Konten Karakter Arcanist'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('KARTU HERO'), findsOneWidget);
        expect(find.text('Konten Karakter Arcanist'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);

        final imageWidget = tester.widget<Image>(find.byType(Image));
        expect(
          (imageWidget.image as AssetImage).assetName,
          'assets/ui/frame_gold_ornate.png',
        );
        expect(imageWidget.centerSlice, isNotNull);
      },
    );

    testWidgets(
      'GamePanel.hudOverlay mendukung opacity 0.85 dan background semi-transparan',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: GamePanel.hudOverlay(child: Text('HUD Player Level 50')),
              ),
            ),
          ),
        );

        expect(find.text('HUD Player Level 50'), findsOneWidget);
        final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
        expect(opacityWidget.opacity, closeTo(0.88, 0.05));
      },
    );
  });

  group('Tahap 1: GameButton Reusable Widget Tests', () {
    testWidgets(
      'GameButton merender gradien, glossy overlay, dan merespons tap',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: GameButton.gold(
                  text: 'RUN BARU',
                  icon: Icons.play_arrow,
                  onPressed: () => tapped = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('RUN BARU'), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);

        // Verifikasi interaksi tap
        await tester.tap(find.byType(GameButton));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );

    testWidgets('GameButton mengecil saat pressed down (tactile animation)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GameButton.arcane(text: 'UPGRADE SPELL', onPressed: () {}),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GameButton)),
      );
      await tester.pump(const Duration(milliseconds: 40));

      final animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.scale, 0.94);

      await gesture.up();
      await tester.pumpAndSettle();

      final releasedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(releasedScale.scale, 1.0);
    });

    testWidgets(
      'GameButton disabled menolak interaksi dan meredupkan opacity',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: GameButton(
                  text: 'LOCKED ACTION',
                  enabled: false,
                  onPressed: () => tapped = true,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(GameButton));
        await tester.pumpAndSettle();
        expect(tapped, isFalse);

        final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
        expect(opacityWidget.opacity, 0.45);
      },
    );
  });

  group('Tahap 1: GameProgressBar Reusable Widget Tests', () {
    testWidgets('GameProgressBar merender slanted parallelogram dengan label', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GameProgressBar.hp(
                value: 0.75,
                width: 200,
                label: '750 / 1000 HP',
              ),
            ),
          ),
        ),
      );

      expect(find.text('750 / 1000 HP'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('GameProgressBar.exp merender dengan cyan glow preset', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GameProgressBar.exp(
                value: 0.50,
                width: 180,
                label: 'EXP 50%',
              ),
            ),
          ),
        ),
      );

      expect(find.text('EXP 50%'), findsOneWidget);
      final progressBar = tester.widget<GameProgressBar>(
        find.byType(GameProgressBar),
      );
      expect(progressBar.style, GameProgressBarStyle.exp);
      expect(progressBar.style.glowColor, AppTheme.cyanGlow);
    });
  });
}
