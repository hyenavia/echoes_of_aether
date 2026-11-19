import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/entities/game_config.dart';
import '../../domain/entities/player_save_snapshot.dart';
import '../../domain/repositories/cloud_save_repository.dart';
import '../../domain/repositories/cloud_sync_state_repository.dart';
import '../../domain/repositories/player_progress_repository.dart';
import '../../domain/services/clock_guard.dart';
import '../../domain/services/cloud_limits.dart';
import '../../domain/services/game_clock.dart';
import '../../domain/services/save_metrics_calculator.dart';
import '../../domain/services/sync_planner.dart';
import 'account_service.dart';

/// Hasil pengepakan blob terkompresi beserta SHA-256 hex untuk lapisan aplikasi.
class PackedCloudBlob {
  const PackedCloudBlob({
    required this.compressedBytes,
    required this.sha256Hex,
    required this.codecVersion,
  });

  final Uint8List compressedBytes;
  final String sha256Hex;
  final int codecVersion;

  int get blobBytes => compressedBytes.length;
}

/// Port aplikasi untuk pengepakan/pembongkaran blob save (implementasi data
/// memakai `dart:io` gzip & SHA-256).
abstract interface class SaveBlobCodecPort {
  PackedCloudBlob pack(PlayerSaveSnapshot snapshot);

  PlayerSaveSnapshot unpack(
    Uint8List compressedBytes, {
    required String expectedSha256,
    required GameConfig config,
  });
}

/// Port aplikasi untuk penyimpanan cadangan lokal sebelum pemulihan cloud.
abstract interface class LocalBackupPort {
  Future<void> createBackup(
    PlayerSaveSnapshot snapshot, {
    required String reason,
    int? createdAtMs,
  });
}

/// Status utama Cloud Sync yang dapat ditampilkan ke pemain (`DESIGN §1.4`).
enum CloudSyncPhase {
  unavailable,
  unauthenticated,
  syncing,
  synced,
  pendingChanges,
  offline,
  rejected,
  conflict,
}

/// Jenis konflik atau tawaran pemulihan yang memerlukan keputusan pemain.
enum CloudConflictKind { cloudAheadUnchanged, divergedSave, accountSwitch }

/// Snapshot status sinkronisasi cloud yang aman diobservasi layer presentasi.
class CloudSyncStatusSnapshot {
  const CloudSyncStatusSnapshot({
    required this.phase,
    required this.account,
    this.lastSyncedRevision = 0,
    this.lastSyncAtMs,
    this.lastRejectCode,
    this.lastRejectMessage,
    this.lastRejectAtMs,
    this.serverOffsetMs,
    this.serverOffsetAtMs,
    this.usingServerClock = false,
    this.pendingCloudMeta,
    this.conflictKind,
    this.infoMessage,
    this.consecutiveNetworkFailures = 0,
    this.nextNetworkRetryAtMs,
  });

  const CloudSyncStatusSnapshot.initial()
    : phase = CloudSyncPhase.unauthenticated,
      account = const CloudAccountSnapshot.unauthenticated(),
      lastSyncedRevision = 0,
      lastSyncAtMs = null,
      lastRejectCode = null,
      lastRejectMessage = null,
      lastRejectAtMs = null,
      serverOffsetMs = null,
      serverOffsetAtMs = null,
      usingServerClock = false,
      pendingCloudMeta = null,
      conflictKind = null,
      infoMessage = null,
      consecutiveNetworkFailures = 0,
      nextNetworkRetryAtMs = null;

  final CloudSyncPhase phase;
  final CloudAccountSnapshot account;
  final int lastSyncedRevision;
  final int? lastSyncAtMs;
  final String? lastRejectCode;
  final String? lastRejectMessage;
  final int? lastRejectAtMs;
  final int? serverOffsetMs;
  final int? serverOffsetAtMs;
  final bool usingServerClock;
  final CloudSaveMeta? pendingCloudMeta;
  final CloudConflictKind? conflictKind;
  final String? infoMessage;
  final int consecutiveNetworkFailures;
  final int? nextNetworkRetryAtMs;

  CloudSyncStatusSnapshot copyWith({
    CloudSyncPhase? phase,
    CloudAccountSnapshot? account,
    int? lastSyncedRevision,
    int? lastSyncAtMs,
    String? lastRejectCode,
    bool clearReject = false,
    String? lastRejectMessage,
    int? lastRejectAtMs,
    int? serverOffsetMs,
    int? serverOffsetAtMs,
    bool? usingServerClock,
    CloudSaveMeta? pendingCloudMeta,
    CloudConflictKind? conflictKind,
    bool clearConflict = false,
    String? infoMessage,
    bool clearInfoMessage = false,
    int? consecutiveNetworkFailures,
    int? nextNetworkRetryAtMs,
    bool clearNextNetworkRetryAtMs = false,
  }) => CloudSyncStatusSnapshot(
    phase: phase ?? this.phase,
    account: account ?? this.account,
    lastSyncedRevision: lastSyncedRevision ?? this.lastSyncedRevision,
    lastSyncAtMs: lastSyncAtMs ?? this.lastSyncAtMs,
    lastRejectCode: clearReject
        ? null
        : (lastRejectCode ?? this.lastRejectCode),
    lastRejectMessage: clearReject
        ? null
        : (lastRejectMessage ?? this.lastRejectMessage),
    lastRejectAtMs: clearReject
        ? null
        : (lastRejectAtMs ?? this.lastRejectAtMs),
    serverOffsetMs: serverOffsetMs ?? this.serverOffsetMs,
    serverOffsetAtMs: serverOffsetAtMs ?? this.serverOffsetAtMs,
    usingServerClock: usingServerClock ?? this.usingServerClock,
    pendingCloudMeta: clearConflict
        ? null
        : (pendingCloudMeta ?? this.pendingCloudMeta),
    conflictKind: clearConflict ? null : (conflictKind ?? this.conflictKind),
    infoMessage: clearInfoMessage ? null : (infoMessage ?? this.infoMessage),
    consecutiveNetworkFailures:
        consecutiveNetworkFailures ?? this.consecutiveNetworkFailures,
    nextNetworkRetryAtMs: clearNextNetworkRetryAtMs
        ? null
        : (nextNetworkRetryAtMs ?? this.nextNetworkRetryAtMs),
  );
}

enum SyncOutcomeKind {
  uploaded,
  skippedNoChanges,
  skippedThrottled,
  skippedRejectBackoff,
  skippedOfflineBackoff,
  offerRestore,
  conflict,
  rejected,
  offline,
  quotaExceeded,
  unauthenticated,
  unavailable,
}

class CloudSyncOutcome {
  const CloudSyncOutcome({
    required this.kind,
    required this.status,
    this.cloudMeta,
    this.message,
  });

  final SyncOutcomeKind kind;
  final CloudSyncStatusSnapshot status;
  final CloudSaveMeta? cloudMeta;
  final String? message;
}

sealed class CloudRestoreOutcome {
  const CloudRestoreOutcome();
}

final class CloudRestoreSuccess extends CloudRestoreOutcome {
  const CloudRestoreSuccess({
    required this.restoredSnapshot,
    required this.meta,
    required this.status,
  });

  final PlayerSaveSnapshot restoredSnapshot;
  final CloudSaveMeta meta;
  final CloudSyncStatusSnapshot status;
}

final class CloudRestoreBlockedActiveRun extends CloudRestoreOutcome {
  const CloudRestoreBlockedActiveRun(this.message);

  final String message;
}

final class CloudRestoreNotFound extends CloudRestoreOutcome {
  const CloudRestoreNotFound(this.message);

  final String message;
}

final class CloudRestoreFailed extends CloudRestoreOutcome {
  const CloudRestoreFailed(this.message);

  final String message;
}

class ServerClockSyncResult {
  const ServerClockSyncResult({
    required this.isOnline,
    this.serverTimeMs,
    this.offsetMs,
    required this.usesServerClock,
  });

  final bool isOnline;
  final int? serverTimeMs;
  final int? offsetMs;
  final bool usesServerClock;
}

typedef ServerClockUpdateCallback = void Function({
  int? serverOffsetMs,
  required bool isOnline,
});

/// Koordinator sinkronisasi Cloud Save (Spark tier), backoff jaringan & rule
/// rejection, kalibrasi jam server, serta pemulihan berkonfirmasi.
class CloudSyncService {
  CloudSyncService({
    required this.accountService,
    required this.cloudSaveRepository,
    required this.syncStateRepository,
    required this.saveRepository,
    SnapshotReplaceRepository? replaceRepository,
    required this.blobPort,
    required this.backupPort,
    required this.config,
    required this.appVersion,
    required this.schemaVersion,
    this.clock = const SystemGameClock(),
    this.planner = const SyncPlanner(),
    this.cloudLimits = const CloudLimits(),
    this.metricsCalculator = const SaveMetricsCalculator(),
    this.onServerClockUpdated,
    this.clockTimeout = defaultClockTimeout,
  }) : _replaceRepository =
           replaceRepository ??
           (saveRepository is SnapshotReplaceRepository
               ? saveRepository as SnapshotReplaceRepository
               : null);

  final SnapshotReplaceRepository? _replaceRepository;

  static const Duration defaultClockTimeout = Duration(seconds: 3);

  /// Backoff jaringan eksponensial berjenjang: 1, 5, 30 menit.
  static const List<int> networkBackoffMinutes = <int>[1, 5, 30];

  final AccountService accountService;
  final CloudSaveRepository cloudSaveRepository;
  final CloudSyncStateRepository syncStateRepository;
  final PlayerSaveRepository saveRepository;
  final SaveBlobCodecPort blobPort;
  final LocalBackupPort backupPort;
  final GameConfig config;
  final String appVersion;
  final int schemaVersion;
  final GameClock clock;
  final SyncPlanner planner;
  final CloudLimits cloudLimits;
  final SaveMetricsCalculator metricsCalculator;
  final ServerClockUpdateCallback? onServerClockUpdated;
  final Duration clockTimeout;

  /// Callback opsional yang dipasang runtime koordinator untuk menerima offset
  /// jam server terbaru tanpa harus merekonstruksi instance [CloudSyncService].
  ServerClockUpdateCallback? serverClockListener;

  final StreamController<CloudSyncStatusSnapshot> _statusController =
      StreamController<CloudSyncStatusSnapshot>.broadcast();

  CloudSyncStatusSnapshot _status = const CloudSyncStatusSnapshot.initial();
  Future<void> _operationQueue = Future<void>.value();
  int _consecutiveNetworkFailures = 0;
  int? _nextNetworkRetryAtMs;
  String? _lastRejectReasonMessage;
  bool _isOnline = false;
  int? _latestServerOffsetMs;

  CloudSyncStatusSnapshot get status => _status;

  Stream<CloudSyncStatusSnapshot> get statusStream => _statusController.stream;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        final result = await action();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      }
    });
    return completer.future;
  }

  /// Membaca status akun + status lokal `CloudSyncStates` tanpa jaringan.
  Future<CloudSyncStatusSnapshot> refreshLocalStatus() => _enqueue(() async {
    final account = await accountService.refreshState();
    final syncState = await syncStateRepository.getOrCreateState();
    final localSnap = await saveRepository.loadSnapshot();

    _latestServerOffsetMs ??= syncState.serverOffsetMs;
    final hasUnsynced = _hasUnsyncedLocalChanges(
      localSnap: localSnap,
      lastSyncedSha256: syncState.lastSyncedBlobSha256,
    );

    final CloudSyncPhase phase;
    if (account.kind == CloudAccountKind.unavailable) {
      phase = CloudSyncPhase.unavailable;
    } else if (!account.isSignedIn) {
      phase = CloudSyncPhase.unauthenticated;
    } else if (accountService.hasPendingAccountSwitchConflict) {
      phase = CloudSyncPhase.conflict;
    } else if (syncState.lastRejectCode != null) {
      phase = CloudSyncPhase.rejected;
    } else if (hasUnsynced) {
      phase = CloudSyncPhase.pendingChanges;
    } else if (syncState.lastSyncedRevision > 0) {
      phase = CloudSyncPhase.synced;
    } else {
      phase = CloudSyncPhase.pendingChanges;
    }

    final rejectMsg = syncState.lastRejectCode == null
        ? null
        : (_lastRejectReasonMessage ?? syncState.lastRejectCode);

    return _emitStatus(
      _status.copyWith(
        phase: phase,
        account: account,
        lastSyncedRevision: syncState.lastSyncedRevision,
        lastSyncAtMs: syncState.lastSyncAtMs,
        lastRejectCode: syncState.lastRejectCode,
        lastRejectMessage: rejectMsg,
        lastRejectAtMs: syncState.lastRejectAtMs,
        clearReject: syncState.lastRejectCode == null,
        serverOffsetMs: _latestServerOffsetMs,
        serverOffsetAtMs: syncState.serverOffsetAtMs,
        usingServerClock: _usesServerClock(),
      ),
    );
  });

  /// Dipanggil saat pemain membuka bagian Akun & Cloud Sync di Pengaturan:
  /// melakukan masuk anonim lazy bila belum masuk, lalu menyegarkan metadata
  /// konflik bila ada.
  Future<CloudSyncStatusSnapshot> openAccountSection() => _enqueue(() async {
    final ensure = await accountService.ensureSignedInForSync();
    final syncState = await syncStateRepository.getOrCreateState();
    _latestServerOffsetMs ??= syncState.serverOffsetMs;
    switch (ensure) {
      case EnsureSignInUnavailable(:final reason):
        return _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.unavailable,
            account: CloudAccountSnapshot.unavailable(reason),
            infoMessage: reason,
          ),
        );
      case EnsureSignInOffline(:final message):
        return _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.offline,
            account: accountService.current,
            infoMessage: message,
          ),
        );
      case EnsureSignInFailed(:final message):
        return _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.unauthenticated,
            account: accountService.current,
            infoMessage: message,
          ),
        );
      case EnsureSignInReady(:final account):
        final localSnap = await saveRepository.loadSnapshot();
        final hasUnsynced = _hasUnsyncedLocalChanges(
          localSnap: localSnap,
          lastSyncedSha256: syncState.lastSyncedBlobSha256,
        );
        final phase = accountService.hasPendingAccountSwitchConflict
            ? CloudSyncPhase.conflict
            : (syncState.lastRejectCode != null
                  ? CloudSyncPhase.rejected
                  : (hasUnsynced || syncState.lastSyncedRevision == 0
                        ? CloudSyncPhase.pendingChanges
                        : CloudSyncPhase.synced));
        return _emitStatus(
          _status.copyWith(
            phase: phase,
            account: account,
            lastSyncedRevision: syncState.lastSyncedRevision,
            lastSyncAtMs: syncState.lastSyncAtMs,
            serverOffsetMs: _latestServerOffsetMs,
            serverOffsetAtMs: syncState.serverOffsetAtMs,
            usingServerClock: _usesServerClock(),
          ),
        );
    }
  });

  /// Mengkalibrasi offset jam server terhadap midpoint `(t0 + t1) ~/ 2`
  /// dengan batas waktu [clockTimeout] (default 3 detik).
  ///
  /// Bila offline, belum masuk akun, atau timeout, mengembalikan `isOnline = false`
  /// dan tidak melempar exception agar jam perangkat + `ClockGuard` tetap bekerja.
  Future<ServerClockSyncResult> syncServerClock({Duration? timeout}) =>
      _enqueue(
        () => _syncServerClockInternal(timeout: timeout ?? clockTimeout),
      );

  Future<ServerClockSyncResult> _syncServerClockInternal({
    required Duration timeout,
  }) async {
    final syncState = await syncStateRepository.getOrCreateState();
    _latestServerOffsetMs ??= syncState.serverOffsetMs;

    final account = await accountService.refreshState();
    if (!account.isSignedIn || account.kind == CloudAccountKind.unavailable) {
      _isOnline = false;
      _notifyServerClockUpdated(
        serverOffsetMs: _latestServerOffsetMs,
        isOnline: false,
      );
      return ServerClockSyncResult(
        isOnline: false,
        offsetMs: _latestServerOffsetMs,
        usesServerClock: false,
      );
    }

    final t0 = math.max(0, clock.nowMs);
    CloudResult<int> result;
    Timer? clockTimer;
    try {
      final clockCompleter = Completer<CloudResult<int>>();
      clockTimer = Zone.root.createTimer(timeout, () {
        if (!clockCompleter.isCompleted) {
          clockCompleter.complete(
            const CloudNetworkError<int>(
              'Sinkronisasi jam server melebihi batas waktu.',
            ),
          );
        }
      });
      unawaited(
        cloudSaveRepository.serverTimeMs().then(
          (value) {
            if (!clockCompleter.isCompleted) {
              clockCompleter.complete(value);
            }
          },
          onError: (Object error, StackTrace _) {
            if (!clockCompleter.isCompleted) {
              clockCompleter.complete(
                CloudNetworkError<int>('Gagal membaca jam server: $error'),
              );
            }
          },
        ),
      );
      result = await clockCompleter.future;
    } catch (e) {
      result = CloudNetworkError<int>('Gagal membaca jam server: $e');
    } finally {
      clockTimer?.cancel();
    }

    final t1 = math.max(t0, clock.nowMs);
    switch (result) {
      case CloudSuccess<int>(:final value):
        final midpoint = (t0 + t1) ~/ 2;
        final offsetMs = value - midpoint;
        _isOnline = true;
        _latestServerOffsetMs = offsetMs;
        await syncStateRepository.updateServerOffset(
          offsetMs: offsetMs,
          measuredAtMs: value,
        );
        _notifyServerClockUpdated(serverOffsetMs: offsetMs, isOnline: true);
        final usesServer = ClockGuard.shouldUseServerTime(
          serverOffsetMs: offsetMs,
          isOnline: true,
          serverTimeToleranceMs: config.cloud.serverTimeToleranceMs,
        );
        _emitStatus(
          _status.copyWith(
            serverOffsetMs: offsetMs,
            serverOffsetAtMs: value,
            usingServerClock: usesServer,
          ),
        );
        return ServerClockSyncResult(
          isOnline: true,
          serverTimeMs: value,
          offsetMs: offsetMs,
          usesServerClock: usesServer,
        );
      case CloudNetworkError<int>():
      case CloudAuthRequired<int>():
      case CloudQuotaExceeded<int>():
      case CloudRejected<int>():
        _isOnline = false;
        _notifyServerClockUpdated(
          serverOffsetMs: _latestServerOffsetMs,
          isOnline: false,
        );
        return ServerClockSyncResult(
          isOnline: false,
          offsetMs: _latestServerOffsetMs,
          usesServerClock: false,
        );
    }
  }

  /// Menjalankan alur sinkronisasi cloud dengan single-flight queue, pemicu
  /// [SyncTrigger], [SyncPlanner], throttle, hash check, backoff jaringan &
  /// backoff penolakan.
  Future<CloudSyncOutcome> sync(SyncTrigger trigger) =>
      _enqueue(() => _syncInternal(trigger));

  Future<CloudSyncOutcome> _syncInternal(SyncTrigger trigger) async {
    final rawNow = math.max(0, clock.nowMs);
    var syncState = await syncStateRepository.getOrCreateState();
    _latestServerOffsetMs ??= syncState.serverOffsetMs;

    if (trigger != SyncTrigger.manual &&
        _nextNetworkRetryAtMs != null &&
        rawNow < _nextNetworkRetryAtMs!) {
      final statusSnapshot = _emitStatus(
        _status.copyWith(
          phase: CloudSyncPhase.offline,
          consecutiveNetworkFailures: _consecutiveNetworkFailures,
          nextNetworkRetryAtMs: _nextNetworkRetryAtMs,
          infoMessage:
              'Offline — menunggu backoff jaringan sebelum mencoba ulang.',
        ),
      );
      return CloudSyncOutcome(
        kind: SyncOutcomeKind.skippedOfflineBackoff,
        status: statusSnapshot,
        message: statusSnapshot.infoMessage,
      );
    }

    final ensure = await accountService.ensureSignedInForSync();
    switch (ensure) {
      case EnsureSignInUnavailable(:final reason):
        final snap = _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.unavailable,
            account: CloudAccountSnapshot.unavailable(reason),
            infoMessage: reason,
          ),
        );
        return CloudSyncOutcome(
          kind: SyncOutcomeKind.unavailable,
          status: snap,
          message: reason,
        );
      case EnsureSignInOffline(:final message):
        final snap = _recordNetworkFailure(rawNow: rawNow, message: message);
        return CloudSyncOutcome(
          kind: SyncOutcomeKind.offline,
          status: snap,
          message: message,
        );
      case EnsureSignInFailed(:final message):
        final snap = _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.unauthenticated,
            account: accountService.current,
            infoMessage: message,
          ),
        );
        return CloudSyncOutcome(
          kind: SyncOutcomeKind.unauthenticated,
          status: snap,
          message: message,
        );
      case EnsureSignInReady():
        break;
    }

    final account = accountService.current;

    if (accountService.hasPendingAccountSwitchConflict) {
      final metaResult = await cloudSaveRepository.latestMeta();
      CloudSaveMeta? cloudMeta;
      if (metaResult is CloudSuccess<CloudSaveMeta?>) {
        cloudMeta = metaResult.value;
      }
      final snap = _emitStatus(
        _status.copyWith(
          phase: CloudSyncPhase.conflict,
          account: account,
          pendingCloudMeta: cloudMeta,
          conflictKind: CloudConflictKind.accountSwitch,
          infoMessage:
              'Akun email ini sudah terhubung dengan progres cloud lain. '
              'Pilih Pulihkan dari cloud atau Batal.',
        ),
      );
      return CloudSyncOutcome(
        kind: SyncOutcomeKind.conflict,
        status: snap,
        cloudMeta: cloudMeta,
        message: snap.infoMessage,
      );
    }

    final localSnap = await saveRepository.loadSnapshot();
    final PackedCloudBlob? packed = localSnap == null
        ? null
        : blobPort.pack(localSnap);
    final hasMeaningful = _isMeaningfulSave(localSnap);
    final currentSha = packed?.sha256Hex ?? '';

    if (trigger == SyncTrigger.background &&
        localSnap != null &&
        syncState.lastSyncedRevision > 0 &&
        syncState.lastRejectCode == null &&
        currentSha == syncState.lastSyncedBlobSha256) {
      final snap = _emitStatus(
        _status.copyWith(
          phase: CloudSyncPhase.synced,
          account: account,
          lastSyncedRevision: syncState.lastSyncedRevision,
          lastSyncAtMs: syncState.lastSyncAtMs,
          clearInfoMessage: true,
        ),
      );
      return CloudSyncOutcome(
        kind: SyncOutcomeKind.skippedNoChanges,
        status: snap,
      );
    }

    await _syncServerClockInternal(timeout: clockTimeout);
    syncState = await syncStateRepository.getOrCreateState();
    final effectiveNowMs = ClockGuard.candidateNowMs(
      rawNowMs: math.max(0, clock.nowMs),
      serverOffsetMs: _latestServerOffsetMs,
      isOnline: _isOnline,
      serverTimeToleranceMs: config.cloud.serverTimeToleranceMs,
    );

    final metaResult = await cloudSaveRepository.latestMeta();
    final CloudSaveMeta? cloudMeta;
    switch (metaResult) {
      case CloudSuccess<CloudSaveMeta?>(:final value):
        cloudMeta = value;
        _resetNetworkFailures();
      case CloudNetworkError<CloudSaveMeta?>(:final message):
        final snap = _recordNetworkFailure(
          rawNow: math.max(0, clock.nowMs),
          message: message,
        );
        return CloudSyncOutcome(
          kind: SyncOutcomeKind.offline,
          status: snap,
          message: message,
        );
      case CloudAuthRequired<CloudSaveMeta?>(:final message):
        final snap = _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.unauthenticated,
            account: const CloudAccountSnapshot.unauthenticated(),
            infoMessage: message,
          ),
        );
        return CloudSyncOutcome(
          kind: SyncOutcomeKind.unauthenticated,
          status: snap,
          message: message,
        );
      case CloudQuotaExceeded<CloudSaveMeta?>(:final message):
        final snap = _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.rejected,
            account: account,
            lastRejectCode: 'resource-exhausted',
            lastRejectMessage: message,
            lastRejectAtMs: effectiveNowMs,
            infoMessage: message,
          ),
        );
        return CloudSyncOutcome(
          kind: SyncOutcomeKind.quotaExceeded,
          status: snap,
          message: message,
        );
      case CloudRejected<CloudSaveMeta?>(:final code, :final message):
        final msg = message ?? 'Gagal memeriksa save cloud ($code).';
        final snap = _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.rejected,
            account: account,
            lastRejectCode: code,
            lastRejectMessage: msg,
            lastRejectAtMs: effectiveNowMs,
            infoMessage: msg,
          ),
        );
        return CloudSyncOutcome(
          kind: SyncOutcomeKind.rejected,
          status: snap,
          message: msg,
        );
    }

    final plan = planner.plan(
      isSignedIn: account.isSignedIn,
      trigger: trigger,
      local: LocalSyncStateSnapshot(
        lastSyncedRevision: syncState.lastSyncedRevision,
        lastSyncedBlobSha256: syncState.lastSyncedBlobSha256,
        currentBlobSha256: currentSha,
        lastSyncAtMs: syncState.lastSyncAtMs,
        lastRejectAtMs: syncState.lastRejectAtMs,
        hasMeaningfulLocalSave: hasMeaningful,
      ),
      cloudMeta: cloudMeta,
      nowMs: effectiveNowMs,
      config: config.cloud,
    );

    switch (plan) {
      case SyncRequireSignIn():
        final snap = _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.unauthenticated,
            account: account,
          ),
        );
        return CloudSyncOutcome(
          kind: SyncOutcomeKind.unauthenticated,
          status: snap,
        );

      case SyncSkip(:final reason):
        switch (reason) {
          case SyncSkipReason.noLocalChanges:
            final snap = _emitStatus(
              _status.copyWith(
                phase: syncState.lastSyncedRevision > 0 || cloudMeta != null
                    ? CloudSyncPhase.synced
                    : CloudSyncPhase.pendingChanges,
                account: account,
                lastSyncedRevision: syncState.lastSyncedRevision,
                lastSyncAtMs: syncState.lastSyncAtMs,
                clearConflict: true,
                clearInfoMessage: true,
              ),
            );
            return CloudSyncOutcome(
              kind: SyncOutcomeKind.skippedNoChanges,
              status: snap,
              cloudMeta: cloudMeta,
            );
          case SyncSkipReason.throttled:
            final hasChanges = _hasUnsyncedLocalChanges(
              localSnap: localSnap,
              lastSyncedSha256: syncState.lastSyncedBlobSha256,
            );
            final snap = _emitStatus(
              _status.copyWith(
                phase: hasChanges
                    ? CloudSyncPhase.pendingChanges
                    : CloudSyncPhase.synced,
                account: account,
                lastSyncedRevision: syncState.lastSyncedRevision,
                lastSyncAtMs: syncState.lastSyncAtMs,
                infoMessage: 'Menunggu jeda sinkronisasi otomatis.',
              ),
            );
            return CloudSyncOutcome(
              kind: SyncOutcomeKind.skippedThrottled,
              status: snap,
              cloudMeta: cloudMeta,
            );
          case SyncSkipReason.rejectBackoff:
            final msg =
                _lastRejectReasonMessage ??
                syncState.lastRejectCode ??
                'Unggahan sebelumnya ditolak.';
            final snap = _emitStatus(
              _status.copyWith(
                phase: CloudSyncPhase.rejected,
                account: account,
                lastRejectCode: syncState.lastRejectCode,
                lastRejectMessage: msg,
                lastRejectAtMs: syncState.lastRejectAtMs,
                infoMessage: msg,
              ),
            );
            return CloudSyncOutcome(
              kind: SyncOutcomeKind.skippedRejectBackoff,
              status: snap,
              message: msg,
            );
        }

      case SyncOfferRestore(:final cloudMeta):
        final snap = _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.conflict,
            account: account,
            pendingCloudMeta: cloudMeta,
            conflictKind: CloudConflictKind.cloudAheadUnchanged,
            infoMessage:
                'Save cloud revisi ${cloudMeta.revision} lebih baru tersedia untuk dipulihkan.',
          ),
        );
        return CloudSyncOutcome(
          kind: SyncOutcomeKind.offerRestore,
          status: snap,
          cloudMeta: cloudMeta,
          message: snap.infoMessage,
        );

      case SyncConflict(:final cloudMeta):
        final snap = _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.conflict,
            account: account,
            pendingCloudMeta: cloudMeta,
            conflictKind: CloudConflictKind.divergedSave,
            infoMessage:
                'Progres lokal berbeda dengan save cloud revisi ${cloudMeta.revision}.',
          ),
        );
        return CloudSyncOutcome(
          kind: SyncOutcomeKind.conflict,
          status: snap,
          cloudMeta: cloudMeta,
          message: snap.infoMessage,
        );

      case SyncUpload(:final expectedBaseRevision, :final newRevision):
        if (localSnap == null || packed == null) {
          final snap = _emitStatus(
            _status.copyWith(phase: CloudSyncPhase.pendingChanges),
          );
          return CloudSyncOutcome(
            kind: SyncOutcomeKind.skippedNoChanges,
            status: snap,
          );
        }

        _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.syncing,
            account: account,
            clearInfoMessage: true,
          ),
        );

        final metrics = metricsCalculator.compute(
          snapshot: localSnap,
          config: config,
          blobBytes: packed.blobBytes,
          blobSha256: packed.sha256Hex,
          schemaVersion: schemaVersion,
          codecVersion: packed.codecVersion,
        );

        final uploadResult = await cloudSaveRepository.upload(
          CloudSaveUploadRequest(
            expectedBaseRevision: expectedBaseRevision,
            newRevision: newRevision,
            deviceId: syncState.deviceId,
            appVersion: appVersion,
            metrics: metrics,
            blob: packed.compressedBytes,
          ),
        );

        switch (uploadResult) {
          case CloudSuccess<CloudSaveMeta>(:final value):
            _resetNetworkFailures();
            _lastRejectReasonMessage = null;
            await syncStateRepository.markSynced(
              revision: value.revision,
              blobSha256: packed.sha256Hex,
              syncedAtMs: effectiveNowMs,
            );
            final snap = _emitStatus(
              _status.copyWith(
                phase: CloudSyncPhase.synced,
                account: account,
                lastSyncedRevision: value.revision,
                lastSyncAtMs: effectiveNowMs,
                clearReject: true,
                clearConflict: true,
                clearNextNetworkRetryAtMs: true,
                consecutiveNetworkFailures: 0,
                infoMessage: 'Tersinkron ke cloud (revisi ${value.revision}).',
              ),
            );
            return CloudSyncOutcome(
              kind: SyncOutcomeKind.uploaded,
              status: snap,
              cloudMeta: value,
              message: snap.infoMessage,
            );

          case CloudRejected<CloudSaveMeta>(
            :final code,
            :final message,
            :final isConflict,
          ):
            _resetNetworkFailures();
            if (isConflict) {
              CloudSaveMeta? latest = cloudMeta;
              final refreshed = await cloudSaveRepository.latestMeta();
              if (refreshed is CloudSuccess<CloudSaveMeta?>) {
                latest = refreshed.value;
              }
              final snap = _emitStatus(
                _status.copyWith(
                  phase: CloudSyncPhase.conflict,
                  account: account,
                  pendingCloudMeta: latest,
                  conflictKind: CloudConflictKind.divergedSave,
                  infoMessage:
                      'Konflik revisi cloud terdeteksi saat mengunggah.',
                ),
              );
              return CloudSyncOutcome(
                kind: SyncOutcomeKind.conflict,
                status: snap,
                cloudMeta: latest,
                message: snap.infoMessage,
              );
            }

            final candidate = CloudSaveCandidate.fromMetrics(
              metrics,
              revision: newRevision,
              deviceId: syncState.deviceId,
              appVersion: appVersion,
              actualBlobLength: packed.blobBytes,
            );
            final explained = _explainRejection(
              prev: cloudMeta,
              next: candidate,
              effectiveNowMs: effectiveNowMs,
              fallbackCode: code,
              fallbackMessage: message,
            );
            _lastRejectReasonMessage = explained.reason;
            await syncStateRepository.markRejected(
              code: explained.code,
              rejectedAtMs: effectiveNowMs,
            );
            final snap = _emitStatus(
              _status.copyWith(
                phase: CloudSyncPhase.rejected,
                account: account,
                lastRejectCode: explained.code,
                lastRejectMessage: explained.reason,
                lastRejectAtMs: effectiveNowMs,
                infoMessage: 'Ditolak: ${explained.reason}',
              ),
            );
            return CloudSyncOutcome(
              kind: SyncOutcomeKind.rejected,
              status: snap,
              message: explained.reason,
            );

          case CloudNetworkError<CloudSaveMeta>(:final message):
            final snap = _recordNetworkFailure(
              rawNow: math.max(0, clock.nowMs),
              message: message,
            );
            return CloudSyncOutcome(
              kind: SyncOutcomeKind.offline,
              status: snap,
              message: message,
            );

          case CloudQuotaExceeded<CloudSaveMeta>(:final message):
            final snap = _emitStatus(
              _status.copyWith(
                phase: CloudSyncPhase.rejected,
                account: account,
                lastRejectCode: 'resource-exhausted',
                lastRejectMessage: message,
                lastRejectAtMs: effectiveNowMs,
                infoMessage: message,
              ),
            );
            return CloudSyncOutcome(
              kind: SyncOutcomeKind.quotaExceeded,
              status: snap,
              message: message,
            );

          case CloudAuthRequired<CloudSaveMeta>(:final message):
            final snap = _emitStatus(
              _status.copyWith(
                phase: CloudSyncPhase.unauthenticated,
                account: const CloudAccountSnapshot.unauthenticated(),
                infoMessage: message,
              ),
            );
            return CloudSyncOutcome(
              kind: SyncOutcomeKind.unauthenticated,
              status: snap,
              message: message,
            );
        }
    }
  }

  /// Memulihkan save dari cloud atas konfirmasi eksplisit pemain.
  ///
  /// - Diblokir bila [isDungeonRunActive] bernilai `true`.
  /// - Memverifikasi SHA-256, gzip, dan `codecVersion` sebelum menulis apa pun.
  /// - Menyimpan cadangan lokal ke `LocalSaveBackups` terlebih dahulu.
  /// - Mengganti snapshot secara atomik lewat `replaceSnapshot`.
  Future<CloudRestoreOutcome> restoreFromCloud({
    required bool isDungeonRunActive,
  }) => _enqueue(() async {
    if (isDungeonRunActive) {
      return const CloudRestoreBlockedActiveRun(
        'Selesaikan atau keluar dari dungeon terlebih dahulu sebelum memulihkan save dari cloud.',
      );
    }

    final ensure = await accountService.ensureSignedInForSync();
    switch (ensure) {
      case EnsureSignInUnavailable(:final reason):
        return CloudRestoreFailed(reason);
      case EnsureSignInOffline(:final message):
        return CloudRestoreFailed(message);
      case EnsureSignInFailed(:final message):
        return CloudRestoreFailed(message);
      case EnsureSignInReady():
        break;
    }

    _emitStatus(
      _status.copyWith(
        phase: CloudSyncPhase.syncing,
        account: accountService.current,
        infoMessage: 'Mengunduh data cloud...',
      ),
    );

    await _syncServerClockInternal(timeout: clockTimeout);
    final effectiveNowMs = ClockGuard.candidateNowMs(
      rawNowMs: math.max(0, clock.nowMs),
      serverOffsetMs: _latestServerOffsetMs,
      isOnline: _isOnline,
      serverTimeToleranceMs: config.cloud.serverTimeToleranceMs,
    );

    final downloaded = await cloudSaveRepository.download();
    final CloudSaveDownload payload;
    switch (downloaded) {
      case CloudSuccess<CloudSaveDownload?>(:final value):
        _resetNetworkFailures();
        if (value == null) {
          await _refreshPhaseAfterFailure();
          return const CloudRestoreNotFound(
            'Belum ada save yang tersimpan di akun cloud ini.',
          );
        }
        payload = value;
      case CloudNetworkError<CloudSaveDownload?>(:final message):
        _recordNetworkFailure(
          rawNow: math.max(0, clock.nowMs),
          message: message,
        );
        return CloudRestoreFailed(message);
      case CloudAuthRequired<CloudSaveDownload?>(:final message):
        _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.unauthenticated,
            account: const CloudAccountSnapshot.unauthenticated(),
            infoMessage: message,
          ),
        );
        return CloudRestoreFailed(message);
      case CloudQuotaExceeded<CloudSaveDownload?>(:final message):
        await _refreshPhaseAfterFailure();
        return CloudRestoreFailed(message);
      case CloudRejected<CloudSaveDownload?>(:final message):
        await _refreshPhaseAfterFailure();
        return CloudRestoreFailed(
          message ??
              'Data save cloud ditolak karena gagal verifikasi integritas.',
        );
    }

    final PlayerSaveSnapshot decoded;
    try {
      decoded = blobPort.unpack(
        payload.blob,
        expectedSha256: payload.meta.metrics.blobSha256,
        config: config,
      );
    } catch (e) {
      await _refreshPhaseAfterFailure();
      return CloudRestoreFailed(
        'Save cloud tidak valid atau versi kodek tidak didukung ($e). '
        'Save lokal tetap dipertahankan.',
      );
    }

    try {
      final replaceRepo = _replaceRepository;
      if (replaceRepo == null) {
        await _refreshPhaseAfterFailure();
        return const CloudRestoreFailed(
          'Repository pemulihan snapshot atomik tidak tersedia.',
        );
      }
      final existingLocal = await saveRepository.loadSnapshot();
      if (existingLocal != null) {
        await backupPort.createBackup(
          existingLocal,
          reason: 'before_cloud_restore',
          createdAtMs: effectiveNowMs,
        );
      }

      await replaceRepo.replaceSnapshot(decoded, restoredAtMs: effectiveNowMs);
    } catch (e) {
      await _refreshPhaseAfterFailure();
      return CloudRestoreFailed(
        'Pemulihan gagal saat menyimpan ke database lokal: $e',
      );
    }

    final savedAfterRestore = await saveRepository.loadSnapshot();
    final syncedHash = savedAfterRestore == null
        ? payload.meta.metrics.blobSha256
        : blobPort.pack(savedAfterRestore).sha256Hex;

    await syncStateRepository.markSynced(
      revision: payload.meta.revision,
      blobSha256: syncedHash,
      syncedAtMs: effectiveNowMs,
    );
    accountService.clearAccountSwitchConflict();
    _lastRejectReasonMessage = null;

    final nextStatus = _emitStatus(
      _status.copyWith(
        phase: CloudSyncPhase.synced,
        account: accountService.current,
        lastSyncedRevision: payload.meta.revision,
        lastSyncAtMs: effectiveNowMs,
        clearReject: true,
        clearConflict: true,
        clearNextNetworkRetryAtMs: true,
        consecutiveNetworkFailures: 0,
        infoMessage:
            'Save cloud revisi ${payload.meta.revision} berhasil dipulihkan.',
      ),
    );

    return CloudRestoreSuccess(
      restoredSnapshot: savedAfterRestore ?? decoded,
      meta: payload.meta,
      status: nextStatus,
    );
  });

  /// Menautkan Email & Password ke akun cloud aktif dari Pengaturan.
  Future<EmailAuthOutcome> linkEmailAccount({
    required String email,
    required String password,
  }) => _enqueue(() async {
    final outcome = await accountService.linkEmailAccount(
      email: email,
      password: password,
    );
    return _applyEmailAuthOutcome(
      outcome,
      successMessage: 'Akun email berhasil ditautkan.',
      switchedMessage: 'Email ini sudah dipakai oleh progres lain. Save lokal tidak diunggah otomatis.',
    );
  });

  /// Masuk ke akun Email & Password yang sudah terdaftar (mis. pulihkan akun lama).
  Future<EmailAuthOutcome> signInWithEmailAccount({
    required String email,
    required String password,
  }) => _enqueue(() async {
    final outcome = await accountService.signInWithEmailAccount(
      email: email,
      password: password,
    );
    return _applyEmailAuthOutcome(
      outcome,
      successMessage: 'Berhasil masuk ke akun email.',
      switchedMessage: 'Berhasil masuk ke akun email. Pilih pulihkan cloud atau lanjut bermain lokal.',
    );
  });

  Future<EmailAuthOutcome> _applyEmailAuthOutcome(
    EmailAuthOutcome outcome, {
    required String successMessage,
    required String switchedMessage,
  }) async {
    switch (outcome) {
      case EmailAuthSuccess(:final account):
        final syncState = await syncStateRepository.getOrCreateState();
        final localSnap = await saveRepository.loadSnapshot();
        final hasUnsynced = _hasUnsyncedLocalChanges(
          localSnap: localSnap,
          lastSyncedSha256: syncState.lastSyncedBlobSha256,
        );
        _emitStatus(
          _status.copyWith(
            phase: hasUnsynced || syncState.lastSyncedRevision == 0
                ? CloudSyncPhase.pendingChanges
                : CloudSyncPhase.synced,
            account: account,
            lastSyncedRevision: syncState.lastSyncedRevision,
            lastSyncAtMs: syncState.lastSyncAtMs,
            infoMessage: successMessage,
          ),
        );
      case EmailAuthSwitchedAccountConflict(:final account):
        CloudSaveMeta? cloudMeta;
        final metaResult = await cloudSaveRepository.latestMeta();
        if (metaResult is CloudSuccess<CloudSaveMeta?>) {
          cloudMeta = metaResult.value;
        }
        _emitStatus(
          _status.copyWith(
            phase: CloudSyncPhase.conflict,
            account: account,
            pendingCloudMeta: cloudMeta,
            conflictKind: CloudConflictKind.accountSwitch,
            infoMessage: switchedMessage,
          ),
        );
      case EmailAuthFailed(:final message, :final isNetworkError):
        if (isNetworkError) {
          _recordNetworkFailure(
            rawNow: math.max(0, clock.nowMs),
            message: message,
          );
        } else {
          _emitStatus(_status.copyWith(infoMessage: message));
        }
    }
    return outcome;
  }

  /// Mengirim email reset kata sandi tanpa mengubah save lokal atau status akun.
  Future<PasswordResetOutcome> sendPasswordReset({required String email}) =>
      _enqueue(() async {
        final outcome = await accountService.sendPasswordReset(email: email);
        switch (outcome) {
          case PasswordResetSent(:final email):
            _emitStatus(
              _status.copyWith(
                infoMessage: 'Email reset kata sandi dikirim ke $email.',
              ),
            );
          case PasswordResetFailed(:final message, :final isNetworkError):
            if (isNetworkError) {
              _recordNetworkFailure(
                rawNow: math.max(0, clock.nowMs),
                message: message,
              );
            } else {
              _emitStatus(_status.copyWith(infoMessage: message));
            }
        }
        return outcome;
      });

  /// Menandai bahwa pemain memilih "Batal / Lanjut bermain lokal tanpa sinkronisasi".
  void dismissConflictPromptAndContinueLocal() {
    _emitStatus(
      _status.copyWith(
        phase: accountService.hasPendingAccountSwitchConflict
            ? CloudSyncPhase.conflict
            : CloudSyncPhase.pendingChanges,
        clearConflict: true,
        infoMessage:
            'Melanjutkan bermain dengan save lokal tanpa sinkronisasi cloud.',
      ),
    );
  }

  /// Keluar dari akun cloud tanpa menghapus save lokal Drift.
  Future<void> signOut() => _enqueue(() async {
    await accountService.signOut();
    _resetNetworkFailures();
    final nextAcc = accountService.current;
    _emitStatus(
      _status.copyWith(
        phase: nextAcc.kind == CloudAccountKind.unavailable
            ? CloudSyncPhase.unavailable
            : CloudSyncPhase.unauthenticated,
        account: nextAcc,
        clearConflict: true,
        infoMessage: 'Keluar dari akun cloud. Save lokal tetap tersimpan.',
      ),
    );
  });

  Future<void> _refreshPhaseAfterFailure() async {
    final syncState = await syncStateRepository.getOrCreateState();
    final localSnap = await saveRepository.loadSnapshot();
    final hasUnsynced = _hasUnsyncedLocalChanges(
      localSnap: localSnap,
      lastSyncedSha256: syncState.lastSyncedBlobSha256,
    );
    final phase = accountService.hasPendingAccountSwitchConflict
        ? CloudSyncPhase.conflict
        : (hasUnsynced || syncState.lastSyncedRevision == 0
              ? CloudSyncPhase.pendingChanges
              : CloudSyncPhase.synced);
    _emitStatus(_status.copyWith(phase: phase));
  }

  CloudSyncStatusSnapshot _recordNetworkFailure({
    required int rawNow,
    required String message,
  }) {
    _isOnline = false;
    _notifyServerClockUpdated(
      serverOffsetMs: _latestServerOffsetMs,
      isOnline: false,
    );
    _consecutiveNetworkFailures += 1;
    final idx = math.min(
      _consecutiveNetworkFailures - 1,
      networkBackoffMinutes.length - 1,
    );
    final retryAt = rawNow + networkBackoffMinutes[idx] * 60 * 1000;
    _nextNetworkRetryAtMs = retryAt;
    return _emitStatus(
      _status.copyWith(
        phase: CloudSyncPhase.offline,
        account: accountService.current,
        consecutiveNetworkFailures: _consecutiveNetworkFailures,
        nextNetworkRetryAtMs: retryAt,
        usingServerClock: false,
        infoMessage: message,
      ),
    );
  }

  void _notifyServerClockUpdated({
    int? serverOffsetMs,
    required bool isOnline,
  }) {
    onServerClockUpdated?.call(
      serverOffsetMs: serverOffsetMs,
      isOnline: isOnline,
    );
    serverClockListener?.call(
      serverOffsetMs: serverOffsetMs,
      isOnline: isOnline,
    );
  }

  void _resetNetworkFailures() {
    _consecutiveNetworkFailures = 0;
    _nextNetworkRetryAtMs = null;
  }

  bool _usesServerClock() => ClockGuard.shouldUseServerTime(
    serverOffsetMs: _latestServerOffsetMs,
    isOnline: _isOnline,
    serverTimeToleranceMs: config.cloud.serverTimeToleranceMs,
  );

  bool _hasUnsyncedLocalChanges({
    required PlayerSaveSnapshot? localSnap,
    required String? lastSyncedSha256,
  }) {
    if (localSnap == null) return false;
    final packed = blobPort.pack(localSnap);
    if (lastSyncedSha256 == null) {
      return _isMeaningfulSave(localSnap);
    }
    return packed.sha256Hex != lastSyncedSha256;
  }

  bool _isMeaningfulSave(PlayerSaveSnapshot? snap) {
    if (snap == null) return false;
    if (snap.character.progress.level > 1 ||
        snap.character.progress.currentExp > 0 ||
        snap.character.progress.gold > 0) {
      return true;
    }
    if (snap.inventory.equipment.isNotEmpty ||
        snap.inventory.stacks.isNotEmpty ||
        snap.character.equipped.isNotEmpty) {
      return true;
    }
    if (snap.cycleProgress.highestAscensionRank > 0) return true;
    if (snap.currencies.values.any((v) => v > 0)) return true;
    for (final prog in snap.dungeonProgresses.values) {
      if (prog.clearsCount > 0 || prog.highestClearedRoomIndex >= 0) {
        return true;
      }
    }
    if (snap.dungeon.clearsCount > 0 ||
        snap.dungeon.highestClearedRoomIndex >= 0) {
      return true;
    }
    return false;
  }

  ({String code, String reason}) _explainRejection({
    required CloudSaveMeta? prev,
    required CloudSaveCandidate next,
    required int effectiveNowMs,
    required String fallbackCode,
    String? fallbackMessage,
  }) {
    final prevCandidate = prev == null
        ? null
        : CloudSaveCandidate.fromMeta(prev);
    final dtSeconds = prev == null
        ? 0.0
        : math.max(0.0, (effectiveNowMs - prev.savedAtServerMs) / 1000.0);
    final violations = cloudLimits.explainViolation(
      prevCandidate,
      next,
      dtSeconds,
    );
    if (violations.isNotEmpty) {
      final first = violations.first;
      final summary = violations.map((v) => v.message).join(' ');
      return (code: 'limit_${first.metric}', reason: summary);
    }
    final cleanMsg = (fallbackMessage == null || fallbackMessage.trim().isEmpty)
        ? 'Unggahan ditolak oleh aturan Firestore ($fallbackCode).'
        : fallbackMessage.trim();
    return (code: fallbackCode, reason: cleanMsg);
  }

  CloudSyncStatusSnapshot _emitStatus(CloudSyncStatusSnapshot next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
    return next;
  }

  Future<void> dispose() async {
    await _statusController.close();
  }
}
