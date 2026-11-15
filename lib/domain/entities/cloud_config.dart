/// Konfigurasi aturan Cloud Sync (`game_config.json` blok `"cloud"`).
class CloudConfig {
  const CloudConfig({
    this.autoSyncMinIntervalMinutes = 5,
    this.rejectBackoffMinutes = 60,
    this.serverTimeToleranceMinutes = 5,
  });

  /// Jeda minimal antar auto-sync (buka aplikasi / latar belakang) dalam menit.
  final int autoSyncMinIntervalMinutes;

  /// Jeda tunggu setelah upload ditolak server sebelum auto-sync mencoba lagi.
  final int rejectBackoffMinutes;

  /// Toleransi selisih jam perangkat terhadap waktu server dalam menit.
  final int serverTimeToleranceMinutes;

  int get autoSyncMinIntervalMs => autoSyncMinIntervalMinutes * 60 * 1000;
  int get rejectBackoffMs => rejectBackoffMinutes * 60 * 1000;
  int get serverTimeToleranceMs => serverTimeToleranceMinutes * 60 * 1000;
}
