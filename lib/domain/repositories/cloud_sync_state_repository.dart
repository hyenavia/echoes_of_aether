import '../entities/cloud_sync_state.dart';

/// Kontrak repository lokal untuk membaca/memperbarui state sinkronisasi cloud
/// pada tabel `CloudSyncStates`.
abstract interface class CloudSyncStateRepository {
  Future<CloudSyncState> getOrCreateState({String? playerId});

  Future<void> saveState(CloudSyncState state);

  Future<void> markSynced({
    String? playerId,
    required int revision,
    required String blobSha256,
    required int syncedAtMs,
  });

  Future<void> markRejected({
    String? playerId,
    required String code,
    required int rejectedAtMs,
  });

  Future<void> updateServerOffset({
    String? playerId,
    required int offsetMs,
    required int measuredAtMs,
  });
}
