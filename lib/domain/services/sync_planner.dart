import '../entities/cloud_config.dart';
import '../repositories/cloud_save_repository.dart';

/// Jenis pemicu sinkronisasi (`DESIGN_ADDENDUM_v1.3 §1.3`).
enum SyncTrigger { appOpen, background, ascension, manual }

/// Alasan mengapa sinkronisasi dilewati.
enum SyncSkipReason { noLocalChanges, throttled, rejectBackoff }

/// Snapshot state lokal yang dibutuhkan [SyncPlanner] untuk menentukan aksi.
class LocalSyncStateSnapshot {
  const LocalSyncStateSnapshot({
    required this.lastSyncedRevision,
    required this.lastSyncedBlobSha256,
    required this.currentBlobSha256,
    this.lastSyncAtMs,
    this.lastRejectAtMs,
    this.hasMeaningfulLocalSave = true,
  });

  final int lastSyncedRevision;
  final String? lastSyncedBlobSha256;
  final String currentBlobSha256;
  final int? lastSyncAtMs;
  final int? lastRejectAtMs;

  /// `false` hanya untuk perangkat baru / save kosong sebelum pemain memiliki
  /// progres lokal yang berarti (`DESIGN_ADDENDUM_v1.3 §1.5`).
  final bool hasMeaningfulLocalSave;
}

/// Keputusan deterministik dari [SyncPlanner].
sealed class SyncPlan {
  const SyncPlan();
}

final class SyncUpload extends SyncPlan {
  const SyncUpload({
    required this.expectedBaseRevision,
    required this.newRevision,
  });

  final int expectedBaseRevision;
  final int newRevision;
}

final class SyncOfferRestore extends SyncPlan {
  const SyncOfferRestore(this.cloudMeta);

  final CloudSaveMeta cloudMeta;
}

final class SyncConflict extends SyncPlan {
  const SyncConflict(this.cloudMeta);

  final CloudSaveMeta cloudMeta;
}

final class SyncSkip extends SyncPlan {
  const SyncSkip(this.reason);

  final SyncSkipReason reason;
}

final class SyncRequireSignIn extends SyncPlan {
  const SyncRequireSignIn();
}

/// Perencana sinkronisasi domain murni tanpa I/O atau dependensi jaringan.
class SyncPlanner {
  const SyncPlanner();

  SyncPlan plan({
    required bool isSignedIn,
    required SyncTrigger trigger,
    required LocalSyncStateSnapshot local,
    required CloudSaveMeta? cloudMeta,
    required int nowMs,
    CloudConfig config = const CloudConfig(),
  }) {
    if (!isSignedIn) {
      return const SyncRequireSignIn();
    }

    final cloudRev = cloudMeta?.revision ?? 0;

    if (cloudMeta != null && cloudRev > local.lastSyncedRevision) {
      final localChanged = _hasLocalChanges(local);
      if (local.lastSyncedRevision == 0 && !local.hasMeaningfulLocalSave) {
        return SyncOfferRestore(cloudMeta);
      }
      if (!localChanged) {
        return SyncOfferRestore(cloudMeta);
      }
      return SyncConflict(cloudMeta);
    }

    if (cloudMeta != null && cloudRev < local.lastSyncedRevision) {
      return SyncConflict(cloudMeta);
    }

    if (cloudMeta == null && !local.hasMeaningfulLocalSave) {
      return const SyncSkip(SyncSkipReason.noLocalChanges);
    }

    if (cloudMeta != null && !_hasLocalChanges(local)) {
      return const SyncSkip(SyncSkipReason.noLocalChanges);
    }

    if (trigger != SyncTrigger.manual) {
      final rejectAt = local.lastRejectAtMs;
      if (rejectAt != null &&
          nowMs >= rejectAt &&
          (nowMs - rejectAt) < config.rejectBackoffMs) {
        return const SyncSkip(SyncSkipReason.rejectBackoff);
      }

      final appliesThrottle =
          trigger == SyncTrigger.appOpen || trigger == SyncTrigger.background;
      final lastSyncAt = local.lastSyncAtMs;
      if (appliesThrottle &&
          lastSyncAt != null &&
          nowMs >= lastSyncAt &&
          (nowMs - lastSyncAt) < config.autoSyncMinIntervalMs) {
        return const SyncSkip(SyncSkipReason.throttled);
      }
    }

    return SyncUpload(
      expectedBaseRevision: cloudRev,
      newRevision: cloudRev + 1,
    );
  }

  bool _hasLocalChanges(LocalSyncStateSnapshot local) {
    final lastHash = local.lastSyncedBlobSha256;
    if (lastHash == null) {
      return local.hasMeaningfulLocalSave;
    }
    return local.currentBlobSha256 != lastHash;
  }
}
