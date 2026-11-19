import 'package:echoes_of_aether/app/app.dart';
import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/domain/entities/game_settings.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_completed_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/settings_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_top_bar.dart';
import 'package:echoes_of_aether/features/shared/assets/game_assets.dart';
import 'package:echoes_of_aether/features/shared/widgets/branding/aether_loading_indicator.dart';
import 'package:echoes_of_aether/features/shared/widgets/branding/aether_logo.dart';
import 'package:echoes_of_aether/features/shared/widgets/branding/aether_splash_screen.dart';
import 'package:echoes_of_aether/features/shared/widgets/branding/aether_symbol_mark.dart';
import 'package:echoes_of_aether/features/shared/widgets/hero_showcase_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Branding Asset Paths', () {
    test('BrandingAssetPaths constants have valid paths', () {
      expect(
        BrandingAssetPaths.appIconFull,
        contains('assets/branding/app_icon/'),
      );
      expect(BrandingAssetPaths.logoPrimary, contains('assets/branding/logo/'));
      expect(BrandingAssetPaths.logoCompact, contains('assets/branding/logo/'));
      expect(BrandingAssetPaths.logoWinged, contains('assets/branding/logo/'));
      expect(
        BrandingAssetPaths.symbolMark,
        contains('assets/branding/symbol/'),
      );
      expect(
        BrandingAssetPaths.symbolBadge,
        contains('assets/branding/symbol/'),
      );
      expect(
        BrandingAssetPaths.logoMonoWhite,
        contains('assets/branding/monochrome/'),
      );
      expect(
        BrandingAssetPaths.logoMonoDark,
        contains('assets/branding/monochrome/'),
      );
      expect(
        BrandingAssetPaths.symbolMonoWhite,
        contains('assets/branding/monochrome/'),
      );
      expect(
        BrandingAssetPaths.symbolMonoDark,
        contains('assets/branding/monochrome/'),
      );
      expect(
        BrandingAssetPaths.splashBranding,
        contains('assets/branding/splash/'),
      );
    });
  });

  group('AetherLogo Widget', () {
    testWidgets('renders all logo variants without errors', (tester) async {
      for (final variant in AetherLogoVariant.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AetherLogo(variant: variant, width: 200)),
          ),
        );
        expect(find.byType(AetherLogo), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
      }
    });
  });

  group('AetherSymbolMark Widget', () {
    testWidgets('renders symbol mark variants with and without glow', (
      tester,
    ) async {
      for (final variant in AetherSymbolVariant.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AetherSymbolMark(variant: variant, size: 48, glow: true),
            ),
          ),
        );
        expect(find.byType(AetherSymbolMark), findsOneWidget);
      }
    });
  });

  group('AetherLoadingIndicator Widget', () {
    testWidgets('renders with message and animates', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AetherLoadingIndicator(
              size: 40,
              message: 'Menghubungkan ke Aether...',
            ),
          ),
        ),
      );

      expect(find.byType(AetherLoadingIndicator), findsOneWidget);
      expect(find.text('Menghubungkan ke Aether...'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AetherSymbolMark), findsOneWidget);
    });
  });

  group('AetherSplashScreen Widget', () {
    testWidgets('displays branding and triggers onComplete on tap', (
      tester,
    ) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AetherSplashScreen(
            onComplete: () => completed = true,
            minDuration: const Duration(seconds: 10),
          ),
        ),
      );

      expect(find.byType(AetherLogo), findsOneWidget);
      expect(find.byType(AetherSymbolMark), findsOneWidget);
      expect(find.text('Echoes of Aether • Idle Dungeon RPG'), findsOneWidget);

      // Tap to skip
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();
      expect(completed, isTrue);
    });

    testWidgets('auto advances on timeout', (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AetherSplashScreen(
            onComplete: () => completed = true,
            minDuration: const Duration(milliseconds: 500),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));
      expect(completed, isTrue);
    });
  });

  group('EchoesApp Startup Integration', () {
    testWidgets(
      'EchoesApp boots into AetherSplashScreen when showSplash is true',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: EchoesApp(showSplash: true)),
        );

        expect(find.byType(AetherSplashScreen), findsOneWidget);
        expect(find.byType(AetherLogo), findsOneWidget);

        // Tap to skip splash
        await tester.tap(find.byType(GestureDetector));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(DungeonScreen), findsOneWidget);
      },
    );
  });

  group('Town & Camp Branding Integration (Stage C)', () {
    testWidgets('TownTopBar displays AetherSymbolMark insignia beside level', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: const Scaffold(
            body: TownTopBar(
              level: 10,
              currentExp: 50,
              expToNext: 100,
              gold: 1200,
              aetherShard: 50,
              ascensionRank: 1,
              specializationName: 'Vanguard',
              maxHp: 280,
            ),
          ),
        ),
      );

      expect(find.byType(TownTopBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TownTopBar),
          matching: find.byType(AetherSymbolMark),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'HeroShowcaseCard displays subtle background Aether emblem watermark',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: const Scaffold(
              body: HeroShowcaseCard(
                level: 10,
                ascensionRank: 1,
                specializationId: 'vanguard',
                specializationName: 'Vanguard',
              ),
            ),
          ),
        );

        expect(find.byType(HeroShowcaseCard), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(HeroShowcaseCard),
            matching: find.byType(AetherSymbolMark),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('Other Screens Branding Integration (Stage D)', () {
    testWidgets(
      'SettingsOverlay displays AetherSymbolMark in header and AetherLogo in About section',
      (tester) async {
        final settingsNotifier = ValueNotifier<GameSettingsData>(
          const GameSettingsData(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: SettingsOverlay(
                settings: settingsNotifier,
                onChanged: (_) {},
                onClose: () {},
              ),
            ),
          ),
        );

        expect(find.byType(SettingsOverlay), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SettingsOverlay),
            matching: find.byType(AetherSymbolMark),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(SettingsOverlay),
            matching: find.byType(AetherLogo),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'DungeonCompletedOverlay displays AetherSymbolMark in victory medallion',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: DungeonCompletedOverlay(
                dungeonName: 'Verdant Ruins',
                clearedRoomsCount: 5,
                onReturnToTown: () {},
              ),
            ),
          ),
        );

        expect(find.byType(DungeonCompletedOverlay), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(DungeonCompletedOverlay),
            matching: find.byType(AetherSymbolMark),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
