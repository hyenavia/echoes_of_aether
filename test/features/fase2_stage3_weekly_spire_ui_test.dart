import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/domain/entities/infinite_spire.dart';
import 'package:echoes_of_aether/domain/services/infinite_spire_service.dart';
import 'package:echoes_of_aether/features/dungeon/infinite_spire_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final config = InfiniteSpireConfig(
    totalFloors: 20,
    floors: [
      for (var f = 1; f <= 20; f++)
        InfiniteSpireFloorDefinition(
          floor: f,
          name: f % 10 == 0 ? 'Boss Floor $f' : 'Floor $f',
          recommendedLevel: f,
          isBossFloor: f % 10 == 0,
          bossName: f % 10 == 0 ? 'Spire Guardian $f' : null,
        ),
    ],
  );

  group('Fase 2 Stage 3 — Weekly Spire Boss Rush UI Tests', () {
    testWidgets(
      'InfiniteSpireOverlay renders locked, active, and completed Weekly Boss Rush banner on 360x640',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // 1. Terkunci
        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: InfiniteSpireOverlay(
                config: config,
                progress: const InfiniteSpireProgressSnapshot(
                  highestFloorCleared: 5,
                ),
                playerLevel: 20,
                weeklyBossRush: const WeeklySpireBossRushInfo(
                  isUnlocked: false,
                  periodKey: '2026-11-23',
                  nextResetMs: 0,
                  claimId: 'infinite_spire:weekly_boss_rush:2026-11-23',
                  isCompletedThisWeek: false,
                  reward: InfiniteSpireReward(),
                ),
                onFightFloor: (_) {},
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('weekly_spire_boss_rush_card')),
          findsOneWidget,
        );
        expect(
          find.text('Tamatkan Lantai 10 untuk membuka Tantangan Bos Mingguan.'),
          findsOneWidget,
        );

        // 2. Aktif (bisa ditantang)
        int? challengedFloor;
        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: InfiniteSpireOverlay(
                config: config,
                progress: const InfiniteSpireProgressSnapshot(
                  highestFloorCleared: 20,
                ),
                playerLevel: 50,
                weeklyBossRush: WeeklySpireBossRushInfo(
                  isUnlocked: true,
                  periodKey: '2026-11-23',
                  nextResetMs: 0,
                  claimId: 'infinite_spire:weekly_boss_rush:2026-11-23',
                  isCompletedThisWeek: false,
                  featuredFloor: config.floor(20),
                  reward: const InfiniteSpireReward(
                    gold: 14000,
                    items: {InfiniteSpireService.aetherScrapItemId: 21},
                    currencies: {
                      InfiniteSpireService.aetherShardCurrencyId: 19,
                    },
                  ),
                ),
                onFightFloor: (floor) => challengedFloor = floor,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lantai 20 — Spire Guardian 20'), findsOneWidget);
        expect(find.text('+14K Gold • +21 Scrap • +19 Shard'), findsOneWidget);
        final fightBtn = find.byKey(
          const Key('weekly_spire_boss_rush_fight_button'),
        );
        expect(fightBtn, findsOneWidget);
        await tester.tap(fightBtn);
        await tester.pump();
        expect(challengedFloor, 20);

        // 3. Sudah selesai minggu ini
        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: InfiniteSpireOverlay(
                config: config,
                progress: const InfiniteSpireProgressSnapshot(
                  highestFloorCleared: 20,
                ),
                playerLevel: 50,
                weeklyBossRush: WeeklySpireBossRushInfo(
                  isUnlocked: true,
                  periodKey: '2026-11-23',
                  nextResetMs: 0,
                  claimId: 'infinite_spire:weekly_boss_rush:2026-11-23',
                  isCompletedThisWeek: true,
                  featuredFloor: config.floor(20),
                  reward: const InfiniteSpireReward(
                    gold: 14000,
                    items: {InfiniteSpireService.aetherScrapItemId: 21},
                    currencies: {
                      InfiniteSpireService.aetherShardCurrencyId: 19,
                    },
                  ),
                ),
                onFightFloor: (_) {},
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('weekly_spire_boss_rush_completed_badge')),
          findsOneWidget,
        );
        expect(find.text('Selesai Minggu Ini'), findsOneWidget);
        expect(
          find.byKey(const Key('weekly_spire_boss_rush_fight_button')),
          findsNothing,
        );
      },
    );
  });
}
