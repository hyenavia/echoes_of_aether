import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/account_service.dart';
import 'package:echoes_of_aether/application/services/cloud_sync_service.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/cloud/drift_cloud_sync_adapters.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide ClockState, CloudSyncState, GameSettings, PeriodicQuestState;
import 'package:echoes_of_aether/data/repositories/drift_cloud_sync_state_repository.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/data/repositories/in_memory_cloud_save_repository.dart';
import 'package:echoes_of_aether/data/repositories/local_backup_service.dart';
import 'package:echoes_of_aether/domain/entities/clock_state.dart';
import 'package:echoes_of_aether/domain/entities/cloud_config.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/time_config.dart';
import 'package:echoes_of_aether/domain/repositories/cloud_save_repository.dart';
import 'package:echoes_of_aether/domain/services/clock_guard.dart';
import 'package:echoes_of_aether/domain/services/game_clock.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MutableClock implements GameClock {
  _MutableClock(this._nowMs);
  int _nowMs;
  @override
  int get nowMs => _nowMs;
  set nowMs(int value) => _nowMs = value;
}

class _SimpleAuthGateway implements AuthGateway {
  CloudAccountSnapshot account = const CloudAccountSnapshot(
    kind: CloudAccountKind.anonymous,
    uid: 'uid-clock',
  );

  @override
  Future<CloudAccountSnapshot> currentAccount() async => account;

  @override
  Future<AuthSignInResult> signInAnonymously() async =>
      AuthSignInSuccess(account);

  @override
  Future<AuthLinkResult> linkWithEmailPassword({
    required String email,
    required String password,
  }) async => const AuthLinkCancelled();

  @override
  Future<AuthLinkResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async => const AuthLinkCancelled();

  @override
  Future<PasswordResetOutcome> sendPasswordResetEmail({
    required String email,
  }) async => PasswordResetSent(email);

  @override
  Future<void> signOut() async {
    account = const CloudAccountSnapshot.unauthenticated();
  }
}

class _SlowClockCloudSaveRepository extends InMemoryCloudSaveRepository {
  _SlowClockCloudSaveRepository({required this.delay}) : super();
  final Duration delay;

  @override
  Future<CloudResult<int>> serverTimeMs() async {
    await Future<void>.delayed(delay);
    return super.serverTimeMs();
  }
}

GameConfig _clockTestConfig({int toleranceMinutes = 5}) => GameConfig(
  monsters: const {},
  revive: const ReviveConfig(),
  progression: const ProgressionConfig(
    baseStats: CombatStats(maxHp: 100, atk: 12, def: 2),
    perLevel: LevelGrowth(hp: 15, atk: 2, def: 0.5),
  ),
  items: const {},
  lootTables: const {},
  time: const TimeConfig(forwardJumpRecordThresholdHours: 48),
  cloud: CloudConfig(serverTimeToleranceMinutes: toleranceMinutes),
);

void main() {
  group('ClockGuard dengan jam server & fallback offline', () {
    test('selisih jam server <= toleransi tetap memakai jam perangkat', () {
      const guard = ClockGuard();
      const base = 1700000000000;
      const state = ClockState(lastSeenAtMs: base);

      expect(
        ClockGuard.shouldUseServerTime(
          serverOffsetMs: 120000, // +2 menit <= 5 menit toleransi
          isOnline: true,
          serverTimeToleranceMs: 300000,
        ),
        isFalse,
      );

      final res = guard.resolve(
        current: state,
        rawNowMs: base + 60000,
        serverOffsetMs: 120000,
        isOnline: true,
        serverTimeToleranceMs: 300000,
      );

      expect(res.effectiveMs, base + 60000);
      expect(res.wentBack, isFalse);
    });

    test('selisih jam server > toleransi (maju/mundur besar) beralih ke jam server', () {
      const guard = ClockGuard();
      const base = 1700000000000;
      const state = ClockState(lastSeenAtMs: base);

      // Jam perangkat dimajukan +2 hari, namun server hanya maju +10 menit
      const tamperedDeviceNow = base + 48 * 3600 * 1000;
      const serverOffsetMs = -(48 * 3600 * 1000 - 10 * 60 * 1000);

      expect(
        ClockGuard.shouldUseServerTime(
          serverOffsetMs: serverOffsetMs,
          isOnline: true,
          serverTimeToleranceMs: 300000,
        ),
        isTrue,
      );

      final res = guard.resolve(
        current: state,
        rawNowMs: tamperedDeviceNow,
        serverOffsetMs: serverOffsetMs,
        isOnline: true,
        serverTimeToleranceMs: 300000,
      );

      expect(res.effectiveMs, base + 10 * 60 * 1000);
      expect(res.wentBack, isFalse);
    });

    test(
      'saat offline kembali ke ClockGuard monotonik (jam mundur ditahan)',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        await db.initialize();
        addTearDown(db.close);
        const t0 = 1700000000000;
        final clock = _MutableClock(t0);
        final config = _clockTestConfig();
        final saveRepo = DriftPlayerSaveRepository(
          db: db,
          config: config,
          clock: clock,
        );
        await saveRepo.saveSnapshot(
          PlayerSaveSnapshot(
            character: const PlayerCharacterSnapshot(
              progress: PlayerProgress(level: 5, gold: 100),
            ),
            inventory: const InventorySnapshot(),
            session: const GameSessionSnapshot(
              lastActiveAtMs: t0,
              lastSavedAtMs: t0,
              lastOfflineClaimAtMs: t0,
            ),
            offlineActivity: OfflineActivitySnapshot.paused().withAutoFarming(
              dungeonId: 'forgotten_forest',
              checkpointAtMs: t0,
            ),
            clockState: const ClockState(lastSeenAtMs: t0),
          ),
        );

        final coordinator = GameSessionCoordinator(
          repository: saveRepo,
          config: config,
          clock: clock,
        );

        // Online dengan jam perangkat maju 10 jam namun offset server -9.5 jam -> server +30 menit
        clock.nowMs = t0 + 10 * 3600 * 1000;
        coordinator.updateServerClock(
          serverOffsetMs: -((9 * 3600 + 1800) * 1000),
          isOnline: true,
        );
        expect(coordinator.isUsingServerClock, isTrue);
        expect(coordinator.effectiveClockMs, t0 + 1800 * 1000);

        // Putus koneksi, lalu jam perangkat mundur sebelum t0 -> offline invalidClock terdeteksi
        coordinator.updateServerClock(isOnline: false);
        expect(coordinator.isUsingServerClock, isFalse);
        clock.nowMs = t0 - 5000;
        final loadResult = await coordinator.loadAndProcessOffline();
        expect(
          loadResult.offlineResult.status,
          OfflineProgressionStatus.invalidClock,
        );
        expect(loadResult.clockState.lastSeenAtMs, t0);
        expect(coordinator.effectiveClockMs, t0);
      },
    );
  });

  group('CloudSyncService.syncServerClock', () {
    test('menghitung offset midpoint (t0 + t1) ~/ 2, menyimpan ke DB, dan memberi tahu koordinator', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      final config = _clockTestConfig();
      final clock = _MutableClock(1700000000000);
      final saveRepo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      final syncStateRepo = DriftCloudSyncStateRepository(db: db);

      const serverTrueMs = 1700000900000; // +15 menit dari perangkat
      final cloudRepo = InMemoryCloudSaveRepository(
        serverNowMs: () {
          // Simulasi RTT 200 ms saat ping
          clock.nowMs += 200;
          return serverTrueMs;
        },
      );

      int? receivedOffset;
      bool? receivedOnline;
      final syncService = CloudSyncService(
        accountService: AccountService(gateway: _SimpleAuthGateway()),
        cloudSaveRepository: cloudRepo,
        syncStateRepository: syncStateRepo,
        saveRepository: saveRepo,
        replaceRepository: saveRepo,
        blobPort: const SaveBlobPackerAdapter(),
        backupPort: LocalBackupServiceAdapter(
          LocalBackupService(db: db, clock: clock),
        ),
        config: config,
        appVersion: '1.0.0',
        schemaVersion: 8,
        clock: clock,
        onServerClockUpdated: ({int? serverOffsetMs, required bool isOnline}) {
          receivedOffset = serverOffsetMs;
          receivedOnline = isOnline;
        },
      );

      final result = await syncService.syncServerClock();
      // t0 = 1700000000000, t1 = 1700000000200, midpoint = +100
      const expectedOffset = serverTrueMs - 1700000000100;
      expect(result.isOnline, isTrue);
      expect(result.serverTimeMs, serverTrueMs);
      expect(result.offsetMs, expectedOffset);
      expect(result.usesServerClock, isTrue);
      expect(receivedOnline, isTrue);
      expect(receivedOffset, expectedOffset);

      final persisted = await syncStateRepo.getOrCreateState();
      expect(persisted.serverOffsetMs, expectedOffset);
    });

    test('timeout / error jaringan jatuh kembali ke jam perangkat offline secara bersih', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      final config = _clockTestConfig();
      final clock = _MutableClock(1700000000000);
      final saveRepo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      final syncStateRepo = DriftCloudSyncStateRepository(db: db);
      final slowCloudRepo = _SlowClockCloudSaveRepository(
        delay: const Duration(milliseconds: 120),
      );

      bool? notifiedOnline;
      final syncService = CloudSyncService(
        accountService: AccountService(gateway: _SimpleAuthGateway()),
        cloudSaveRepository: slowCloudRepo,
        syncStateRepository: syncStateRepo,
        saveRepository: saveRepo,
        replaceRepository: saveRepo,
        blobPort: const SaveBlobPackerAdapter(),
        backupPort: LocalBackupServiceAdapter(
          LocalBackupService(db: db, clock: clock),
        ),
        config: config,
        appVersion: '1.0.0',
        schemaVersion: 8,
        clock: clock,
        clockTimeout: const Duration(milliseconds: 20),
        onServerClockUpdated: ({int? serverOffsetMs, required bool isOnline}) {
          notifiedOnline = isOnline;
        },
      );

      final timedOut = await syncService.syncServerClock();
      expect(timedOut.isOnline, isFalse);
      expect(timedOut.usesServerClock, isFalse);
      expect(notifiedOnline, isFalse);
    });
  });
}
