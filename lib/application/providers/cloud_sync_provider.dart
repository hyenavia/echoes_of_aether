import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cloud/drift_cloud_sync_adapters.dart';
import '../../data/cloud/firebase_auth_gateway.dart';
import '../../data/cloud/firebase_bootstrap.dart';
import '../../data/cloud/github_release_checker.dart';
import '../../data/repositories/drift_cloud_sync_state_repository.dart';
import '../../data/repositories/drift_player_save_repository.dart';
import '../../data/repositories/firestore_cloud_save_repository.dart';
import '../../data/repositories/local_backup_service.dart';
import '../../domain/entities/cloud_sync_state.dart';
import '../../domain/entities/player_save_snapshot.dart';
import '../../domain/repositories/cloud_save_repository.dart';
import '../../domain/repositories/cloud_sync_state_repository.dart';
import '../services/account_service.dart';
import '../services/app_update_service.dart';
import '../services/cloud_sync_service.dart';
import 'database_provider.dart' show playerSaveRepositoryProvider;
import 'game_clock_provider.dart';
import 'game_config_provider.dart';

/// Versi aplikasi saat ini (selaras dengan `pubspec.yaml` `1.0.0+1`).
const String kCloudSyncAppVersion = '1.0.0+1';

final appReleaseSourceProvider = Provider<AppReleaseSource>((ref) {
  return GithubReleaseChecker();
});

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(
    source: ref.watch(appReleaseSourceProvider),
    currentVersion: kCloudSyncAppVersion,
  );
});

final firebaseBootstrapProvider = Provider<FirebaseBootstrap>((ref) {
  final bootstrap = FirebaseBootstrap.instance;
  ref.onDispose(bootstrap.cancelPendingInit);
  return bootstrap;
});

final authGatewayProvider = Provider<AuthGateway>((ref) {
  final bootstrap = ref.watch(firebaseBootstrapProvider);
  return FirebaseAuthGateway(bootstrap: bootstrap);
});

final accountServiceProvider = Provider<AccountService>((ref) {
  final gateway = ref.watch(authGatewayProvider);
  final service = AccountService(gateway: gateway);
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final cloudSaveRepositoryProvider = Provider<CloudSaveRepository>((ref) {
  final bootstrap = ref.watch(firebaseBootstrapProvider);
  final accountService = ref.watch(accountServiceProvider);
  return FirestoreCloudSaveRepository(
    bootstrap: bootstrap,
    currentUid: () => accountService.current.uid,
  );
});

final cloudSyncStateRepositoryProvider =
    FutureProvider<CloudSyncStateRepository>((ref) async {
      final saveRepo = await ref.watch(playerSaveRepositoryProvider.future);
      if (saveRepo is DriftPlayerSaveRepository) {
        return DriftCloudSyncStateRepository(db: saveRepo.db);
      }
      return _InMemoryCloudSyncStateRepository();
    });

final cloudSyncServiceProvider = FutureProvider<CloudSyncService>((ref) async {
  final config = await ref.watch(gameConfigProvider.future);
  final saveRepo = await ref.watch(playerSaveRepositoryProvider.future);
  final stateRepo = await ref.watch(cloudSyncStateRepositoryProvider.future);
  final accountService = ref.watch(accountServiceProvider);
  final cloudSaveRepo = ref.watch(cloudSaveRepositoryProvider);
  final clock = ref.watch(gameClockProvider);

  final LocalBackupPort backupPort;
  final int schemaVersion;
  if (saveRepo is DriftPlayerSaveRepository) {
    final db = saveRepo.db;
    schemaVersion = db.schemaVersion;
    backupPort = LocalBackupServiceAdapter(
      LocalBackupService(db: db, clock: clock),
    );
  } else {
    schemaVersion = 8;
    backupPort = const _NoopLocalBackupPort();
  }

  final service = CloudSyncService(
    accountService: accountService,
    cloudSaveRepository: cloudSaveRepo,
    syncStateRepository: stateRepo,
    saveRepository: saveRepo,
    blobPort: const SaveBlobPackerAdapter(),
    backupPort: backupPort,
    config: config,
    appVersion: kCloudSyncAppVersion,
    schemaVersion: schemaVersion,
    clock: clock,
  );
  ref.onDispose(() => unawaited(service.dispose()));
  await service.refreshLocalStatus();
  return service;
});

final cloudSyncStatusProvider = StreamProvider<CloudSyncStatusSnapshot>((
  ref,
) async* {
  try {
    final service = await ref.watch(cloudSyncServiceProvider.future);
    yield service.status;
    yield* service.statusStream;
  } catch (_) {
    yield const CloudSyncStatusSnapshot.initial();
  }
});

class _NoopLocalBackupPort implements LocalBackupPort {
  const _NoopLocalBackupPort();

  @override
  Future<void> createBackup(
    PlayerSaveSnapshot snapshot, {
    required String reason,
    int? createdAtMs,
  }) async {}
}

class _InMemoryCloudSyncStateRepository implements CloudSyncStateRepository {
  final Map<String, CloudSyncState> _states = {};

  @override
  Future<CloudSyncState> getOrCreateState({String? playerId}) async {
    final pid = playerId ?? GameSessionSnapshot.defaultPlayerId;
    return _states.putIfAbsent(
      pid,
      () => CloudSyncState(playerId: pid, deviceId: 'in_memory_device_$pid'),
    );
  }

  @override
  Future<void> saveState(CloudSyncState state) async {
    _states[state.playerId] = state;
  }

  @override
  Future<void> markSynced({
    String? playerId,
    required int revision,
    required String blobSha256,
    required int syncedAtMs,
  }) async {
    final current = await getOrCreateState(playerId: playerId);
    _states[current.playerId] = CloudSyncState(
      playerId: current.playerId,
      deviceId: current.deviceId,
      lastSyncedRevision: math.max(0, revision),
      lastSyncedBlobSha256: blobSha256,
      lastSyncAtMs: syncedAtMs,
      lastRejectCode: null,
      lastRejectAtMs: null,
      serverOffsetMs: current.serverOffsetMs,
      serverOffsetAtMs: current.serverOffsetAtMs,
    );
  }

  @override
  Future<void> markRejected({
    String? playerId,
    required String code,
    required int rejectedAtMs,
  }) async {
    final current = await getOrCreateState(playerId: playerId);
    _states[current.playerId] = CloudSyncState(
      playerId: current.playerId,
      deviceId: current.deviceId,
      lastSyncedRevision: current.lastSyncedRevision,
      lastSyncedBlobSha256: current.lastSyncedBlobSha256,
      lastSyncAtMs: current.lastSyncAtMs,
      lastRejectCode: code,
      lastRejectAtMs: rejectedAtMs,
      serverOffsetMs: current.serverOffsetMs,
      serverOffsetAtMs: current.serverOffsetAtMs,
    );
  }

  @override
  Future<void> updateServerOffset({
    String? playerId,
    required int offsetMs,
    required int measuredAtMs,
  }) async {
    final current = await getOrCreateState(playerId: playerId);
    _states[current.playerId] = CloudSyncState(
      playerId: current.playerId,
      deviceId: current.deviceId,
      lastSyncedRevision: current.lastSyncedRevision,
      lastSyncedBlobSha256: current.lastSyncedBlobSha256,
      lastSyncAtMs: current.lastSyncAtMs,
      lastRejectCode: current.lastRejectCode,
      lastRejectAtMs: current.lastRejectAtMs,
      serverOffsetMs: offsetMs,
      serverOffsetAtMs: measuredAtMs,
    );
  }
}
