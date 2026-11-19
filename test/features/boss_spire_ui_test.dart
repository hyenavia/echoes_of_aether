import 'dart:io';

import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/data/models/boss_spire_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/boss_spire.dart';
import 'package:echoes_of_aether/features/dungeon/boss_spire_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

void main() {
  group('BossSpireOverlay Widget Test', () {
    late BossSpireConfig config;

    setUp(() {
      config = const BossSpireConfigParser().parse(
        _readAsset('boss_spire.json'),
      );
    });

    Widget createWidget({
      required BossSpireProgress progress,
      int playerLevel = 20,
      Duration? remainingToReset,
      void Function(int floor)? onFightFloor,
      VoidCallback? onClose,
    }) {
      return MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [EchoesThemeExtension.dark],
        ),
        home: Scaffold(
          body: BossSpireOverlay(
            config: config,
            progress: progress,
            playerLevel: playerLevel,
            remainingToReset: remainingToReset,
            onFightFloor: onFightFloor ?? (_) {},
            onClose: onClose ?? () {},
          ),
        ),
      );
    }

    testWidgets('menampilkan header dan kartu lantai dengan benar', (
      tester,
    ) async {
      final progress = BossSpireProgress(
        highestClearedFloor: 1,
        clearedFloors: {1},
      );

      await tester.pumpWidget(createWidget(progress: progress));
      await tester.pumpAndSettle();

      expect(find.text(config.name), findsOneWidget);
      expect(find.text('Selesai: 1 / 20 Lantai'), findsOneWidget);

      // Lantai 1: SELESAI
      expect(find.text('F1'), findsOneWidget);
      expect(find.text('SELESAI'), findsOneWidget);

      // Lantai 2: TANTANG (karena unlocked)
      expect(find.text('F2'), findsOneWidget);
      expect(find.byKey(const Key('spire_fight_2')), findsOneWidget);

      // Lantai 3: TERKUNCI
      expect(find.text('F3'), findsOneWidget);
      expect(find.text('TERKUNCI'), findsWidgets);
    });

    testWidgets('menekan tombol Tantang memanggil onFightFloor', (
      tester,
    ) async {
      int? foughtFloor;
      final progress = const BossSpireProgress(); // Lantai 1 unlocked

      await tester.pumpWidget(
        createWidget(progress: progress, onFightFloor: (f) => foughtFloor = f),
      );
      await tester.pumpAndSettle();

      final fightBtn = find.byKey(const Key('spire_fight_1'));
      expect(fightBtn, findsOneWidget);

      await tester.tap(fightBtn);
      await tester.pumpAndSettle();

      expect(foughtFloor, 1);
    });

    testWidgets('menekan tombol Tutup memanggil onClose', (tester) async {
      var closed = false;
      final progress = const BossSpireProgress();

      await tester.pumpWidget(
        createWidget(progress: progress, onClose: () => closed = true),
      );
      await tester.pumpAndSettle();

      final closeBtn = find.byKey(const Key('boss_spire_close'));
      expect(closeBtn, findsOneWidget);

      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });

    testWidgets(
      'menampilkan countdown reset 2-mingguan saat remainingToReset diberikan',
      (tester) async {
        final progress = const BossSpireProgress(
          highestClearedFloor: 0,
          clearedFloors: {},
        );

        await tester.pumpWidget(
          createWidget(
            progress: progress,
            remainingToReset: const Duration(days: 11, hours: 14, minutes: 25),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Reset: 11h 14:25:00'), findsOneWidget);
        expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      },
    );
  });
}
