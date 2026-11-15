import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/notifications/local_notification_scheduler.dart';
import '../../data/repositories/drift_player_save_repository.dart';
import '../../domain/services/requirement_evaluator.dart';
import '../services/app_lifecycle_notification_observer.dart';
import '../services/notification_scheduler.dart';
import 'database_provider.dart';
import 'game_clock_provider.dart';
import 'game_config_provider.dart';

final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return LocalNotificationScheduler();
});

final appLifecycleNotificationObserverProvider =
    Provider<AppLifecycleNotificationObserver>((ref) {
      final scheduler = ref.watch(notificationSchedulerProvider);
      final clock = ref.watch(gameClockProvider);
      final observer = AppLifecycleNotificationObserver(
        scheduler: scheduler,
        clock: clock,
        loadSnapshot: () async {
          try {
            final config = await ref.read(gameConfigProvider.future);
            final db = ref.read(appDatabaseProvider);
            final repo = DriftPlayerSaveRepository(
              db: db,
              config: config,
              clock: clock,
            );
            final settings = await repo.loadSettings();
            final save = await repo.loadSnapshot();
            if (save == null) return null;
            return NotificationRuntimeSnapshot(
              config: config,
              settings: settings,
              offlineMode: save.offlineActivity.mode,
              lastOfflineClaimAtMs: save.session.lastOfflineClaimAtMs,
              lastSeenAtMs: save.clockState.lastSeenAtMs,
              periodicQuestStates: save.periodicQuestStates,
              shopContext: ShopPlayerContext(
                playerLevel: save.character.progress.level,
                cycleProgress: save.cycleProgress,
                dungeonProgresses: save.dungeonProgresses,
                shopPurchases: save.shopPurchases,
                eventShopPurchases: {
                  for (final p in save.eventShopPurchases)
                    (p.entryId, p.periodKey): p.purchasedCount,
                },
              ),
            );
          } catch (_) {
            return null;
          }
        },
      );
      observer.attach();
      ref.onDispose(observer.detach);
      return observer;
    });
