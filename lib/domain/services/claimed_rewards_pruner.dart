/// Kebijakan konservatif pemangkasan `ClaimedRewards`:
///
/// - **Dihapus** bila `claimedAtMs < cutoffMs` (`nowMs - retention_days`):
///   - `offline_kill:<runId>:<enemyId>` milik run yang sudah selesai (`runId != activeRunId`).
///   - `room_clear:<runId>:<roomId>` milik run yang sudah selesai (`runId != activeRunId`).
///   - `dungeon_clear:<runId>` milik run yang sudah selesai (`runId != activeRunId`).
///   - `offline:<anchorMs>:<endMs>` yang sudah kedaluwarsa (`lastOfflineClaimAtMs`
///     tetap memblokir pemutaran ulang jendela waktu lama).
/// - **TIDAK PERNAH dihapus**:
///   - ID milik run aktif yang masih dapat dipulihkan (`activeRunId`).
///   - ID permanen: `ascension:*` dan `shop:*`.
///   - ID periode berjalan (dan semua `bossquest:*` / `eventshop:*` jika periode
///     cocok atau tidak dapat dipastikan kadaluwarsa).
class ClaimedRewardsPruner {
  const ClaimedRewardsPruner();

  static const List<String> neverPrunePrefixes = ['ascension:', 'shop:'];

  static const List<String> periodScopedPrefixes = ['bossquest:', 'eventshop:'];

  static const List<String> runScopedPrefixes = [
    'offline_kill:',
    'room_clear:',
    'dungeon_clear:',
  ];

  /// Mengembalikan `true` jika [eventId] yang diklaim pada [claimedAtMs] aman
  /// untuk dipangkas pada batas [cutoffMs].
  bool shouldPrune({
    required String eventId,
    required int claimedAtMs,
    required int cutoffMs,
    String? activeRunId,
    Set<String> activePeriodKeys = const {},
  }) {
    if (claimedAtMs >= cutoffMs) return false;

    for (final prefix in neverPrunePrefixes) {
      if (eventId.startsWith(prefix)) return false;
    }

    for (final prefix in periodScopedPrefixes) {
      if (eventId.startsWith(prefix)) {
        final periodKey = _extractLastSegment(eventId);
        if (periodKey == null ||
            activePeriodKeys.isEmpty ||
            activePeriodKeys.contains(periodKey)) {
          return false;
        }
        return true;
      }
    }

    if (eventId.startsWith('offline:')) {
      return true;
    }

    for (final prefix in runScopedPrefixes) {
      if (eventId.startsWith(prefix)) {
        final runId = _extractRunId(eventId, prefix);
        if (activeRunId != null &&
            activeRunId.isNotEmpty &&
            runId == activeRunId) {
          return false;
        }
        return true;
      }
    }

    // Konservatif: ID dengan format tak dikenal tidak dihapus.
    return false;
  }

  String? _extractRunId(String eventId, String prefix) {
    final rest = eventId.substring(prefix.length);
    if (rest.isEmpty) return null;
    final sep = rest.indexOf(':');
    return sep == -1 ? rest : rest.substring(0, sep);
  }

  String? _extractLastSegment(String eventId) {
    final idx = eventId.lastIndexOf(':');
    if (idx == -1 || idx == eventId.length - 1) return null;
    return eventId.substring(idx + 1);
  }
}
