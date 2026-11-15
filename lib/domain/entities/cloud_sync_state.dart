/// State sinkronisasi Cloud Save per pemain pada perangkat lokal
/// (`CloudSyncStates`, schema v8).
class CloudSyncState {
  const CloudSyncState({
    required this.playerId,
    required this.deviceId,
    this.lastSyncedRevision = 0,
    this.lastSyncedBlobSha256,
    this.lastSyncAtMs,
    this.lastRejectCode,
    this.lastRejectAtMs,
    this.serverOffsetMs,
    this.serverOffsetAtMs,
  });

  final String playerId;
  final String deviceId;
  final int lastSyncedRevision;
  final String? lastSyncedBlobSha256;
  final int? lastSyncAtMs;
  final String? lastRejectCode;
  final int? lastRejectAtMs;
  final int? serverOffsetMs;
  final int? serverOffsetAtMs;
}
