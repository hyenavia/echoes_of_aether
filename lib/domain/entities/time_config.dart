/// Konfigurasi lapisan waktu (reset harian/mingguan dan ambang pencatatan
/// lonjakan jam maju) dari `game_config.json`.
class TimeConfig {
  const TimeConfig({
    this.resetHour = 0,
    this.weekStart = 'monday',
    this.epochMonday = '2026-11-16',
    this.forwardJumpRecordThresholdHours = 48,
  });

  final int resetHour;
  final String weekStart;
  final String epochMonday;
  final int forwardJumpRecordThresholdHours;

  int get forwardJumpRecordThresholdMs =>
      forwardJumpRecordThresholdHours * Duration.millisecondsPerHour;

  /// Mem-parse [epochMonday] (`YYYY-MM-DD`) menjadi `DateTime` UTC tengah malam.
  /// Mengembalikan `null` jika format atau tanggal tidak valid.
  DateTime? tryParseEpochMondayUtc() => tryParseDateUtc(epochMonday);

  static DateTime? tryParseDateUtc(String raw) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final dt = DateTime.utc(year, month, day);
    if (dt.year != year || dt.month != month || dt.day != day) return null;
    return dt;
  }
}

/// Konfigurasi retensi pemangkasan tabel `ClaimedRewards`.
class ClaimedRewardsConfig {
  const ClaimedRewardsConfig({this.retentionDays = 14});

  final int retentionDays;

  int get retentionMs => retentionDays * Duration.millisecondsPerDay;
}
