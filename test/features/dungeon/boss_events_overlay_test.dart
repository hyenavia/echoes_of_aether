import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/features/dungeon/boss_events_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_completed_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'BossEventsOverlay menampilkan status Belum/Selesai, hitung mundur, dan tombol Lawan tanpa hard lock',
    (tester) async {
      var dailyTapped = 0;
      var weeklyTapped = 0;
      var closed = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BossEventsOverlay(
              daily: BossEventCardData(
                periodKeyId: 'daily',
                periodLabel: 'Daily Boss',
                bossName: 'Ash Tyrant',
                referenceDungeonName: 'Forgotten Forest',
                recommendedLevel: 12,
                isCompleted: false,
                remainingToReset: const Duration(
                  hours: 3,
                  minutes: 4,
                  seconds: 5,
                ),
                rewardSummary: '50 Aether Shard • 120 Gold • 200 EXP',
                onFight: () => dailyTapped++,
              ),
              weekly: BossEventCardData(
                periodKeyId: 'weekly',
                periodLabel: 'Weekly Boss',
                bossName: 'Crimson Sovereign',
                referenceDungeonName: 'Ancient Ruins',
                recommendedLevel: 25,
                isCompleted: true,
                remainingToReset: const Duration(days: 2, hours: 5),
                rewardSummary: '200 Aether Shard • 600 Gold • 1000 EXP',
                onFight: () => weeklyTapped++,
              ),
              onClose: () => closed++,
            ),
          ),
        ),
      );

      expect(find.text('Ash Tyrant'), findsOneWidget);
      expect(find.text('Crimson Sovereign'), findsOneWidget);
      expect(find.byKey(const Key('boss_status_daily')), findsOneWidget);
      expect(find.text('Belum'), findsOneWidget);
      expect(find.byKey(const Key('boss_status_weekly')), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Reset dalam: 03:04:05'), findsOneWidget);
      expect(find.text('Reset dalam: 2h 05:00:00'), findsOneWidget);
      expect(
        find.text('Peringatan: Rekomendasi Lv 12 (Forgotten Forest)'),
        findsOneWidget,
      );

      // Tidak ada hard lock meskipun Weekly sudah Selesai: tombol Lawan tetap aktif.
      await tester.tap(find.byKey(const Key('boss_fight_daily')));
      await tester.tap(find.byKey(const Key('boss_fight_weekly')));
      await tester.tap(find.byKey(const Key('boss_events_close')));
      await tester.pump();

      expect(dailyTapped, 1);
      expect(weeklyTapped, 1);
      expect(closed, 1);
    },
  );

  testWidgets(
    'DungeonCompletedOverlay menampilkan pesan hadiah atau status sudah selesai periode ini',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: Scaffold(
            body: DungeonCompletedOverlay(
              dungeonName: 'Daily Boss: Ash Tyrant',
              clearedRoomsCount: 1,
              bossQuestMessage: 'Tidak ada hadiah (sudah selesai periode ini).',
              onReturnToTown: () {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('boss_quest_result_message')),
        findsOneWidget,
      );
      expect(
        find.text('Tidak ada hadiah (sudah selesai periode ini).'),
        findsOneWidget,
      );
    },
  );
}
