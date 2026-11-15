import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/features/dungeon/town_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'TownTopBar menampilkan Aether Shard dengan NumberFormatter tanpa overflow pada lebar 320dp',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: TownTopBar(
                  level: 12,
                  currentExp: 45,
                  expToNext: 100,
                  gold: 2500,
                  aetherShard: 1500,
                  ascensionRank: 3,
                  specializationName: 'Vanguard',
                  maxHp: 320,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('top_bar_gold')), findsOneWidget);
      expect(find.byKey(const Key('top_bar_aether_shard')), findsOneWidget);
      expect(find.text('Aether Shard: 1.5K'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
