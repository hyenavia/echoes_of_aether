import 'package:echoes_of_aether/app/theme/app_tokens.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/features/shared/widgets/hero_showcase_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestHarness({
    required Widget child,
    double width = 360,
    double height = 640,
  }) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.midnightForest,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }

  group('Stage 5: Living Aether Camp Ambient & Hero Showcase Polish', () {
    const stats = CombatStats(
      maxHp: 250,
      atk: 45,
      def: 18,
      attackSpeed: 1.2,
      critRate: 0.15,
      critDamage: 1.5,
    );

    testWidgets(
      'HeroShowcaseCard renders ambient painter across all 4 specializations',
      (tester) async {
        final specs = [
          (specId: null, name: 'Adventurer'),
          (specId: 'vanguard', name: 'Vanguard'),
          (specId: 'arcanist', name: 'Arcanist'),
          (specId: 'ranger', name: 'Ranger'),
        ];

        for (final (specId: specId, name: name) in specs) {
          await tester.pumpWidget(
            buildTestHarness(
              child: HeroShowcaseCard(
                level: 25,
                ascensionRank: 2,
                specializationId: specId,
                specializationName: name,
                stats: stats,
              ),
            ),
          );
          await tester.pump();

          expect(find.byKey(const Key('hero_showcase_card')), findsOneWidget);
          expect(
            find.byKey(const ValueKey<String>('camp_backdrop')),
            findsOneWidget,
          );
          expect(find.byType(CustomPaint), findsWidgets);
        }
      },
    );

    testWidgets(
      'HeroShowcaseCard handles narrow 320dp and wide 720dp viewports without overflow',
      (tester) async {
        // 1. Narrow 320dp
        await tester.pumpWidget(
          buildTestHarness(
            width: 320,
            child: const HeroShowcaseCard(
              level: 10,
              ascensionRank: 0,
              specializationId: 'vanguard',
              specializationName: 'Vanguard',
              stats: stats,
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        // 2. Wide 720dp
        await tester.pumpWidget(
          buildTestHarness(
            width: 720,
            child: const HeroShowcaseCard(
              level: 50,
              ascensionRank: 5,
              specializationId: 'arcanist',
              specializationName: 'Arcanist',
              stats: stats,
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('HeroShowcaseCard triggers onTap callback when tapped', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTestHarness(
          child: HeroShowcaseCard(
            level: 15,
            ascensionRank: 1,
            specializationId: 'ranger',
            specializationName: 'Ranger',
            stats: stats,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('hero_showcase_card')));
      await tester.pump();

      expect(tapped, isTrue);
    });

    test('Combat power computation formula matches design', () {
      final power = HeroShowcaseCard.computeCombatPower(stats);
      // (250 * 0.25) + (45 * 4.5) + (18 * 3.0) + (0.15 * 200) + (1.2 * 20)
      // 62.5 + 202.5 + 54 + 30 + 24 = 373
      expect(power, 373);
    });
  });
}
