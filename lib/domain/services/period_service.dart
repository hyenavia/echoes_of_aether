import '../entities/time_config.dart';

/// Jenis periode reset untuk quest, boss, dan event shop.
enum Period { daily, weekly }

/// Layanan domain murni untuk menghitung kunci periode (`YYYY-MM-DD`),
/// indeks hari/minggu sejak `epoch_monday`, dan waktu reset berikutnya
/// berdasarkan waktu **lokal** perangkat dikurangi `reset_hour`.
class PeriodService {
  const PeriodService({this.config = const TimeConfig(), this.timeZoneOffset});

  final TimeConfig config;
  final Duration Function()? timeZoneOffset;

  /// Mengembalikan kunci periode `'YYYY-MM-DD'` berdasarkan tanggal lokal
  /// setelah dikurangi `config.resetHour`. Untuk [Period.weekly], mengembalikan
  /// tanggal hari Senin pada minggu periode tersebut.
  String keyFor(Period period, int nowMs, {Duration? offset}) {
    final shifted = _shiftedLocalWall(nowMs, offset: offset);
    return switch (period) {
      Period.daily => _formatDate(shifted),
      Period.weekly => _formatDate(_mondayOf(shifted)),
    };
  }

  /// Indeks hari sejak `config.epochMonday` (0 = hari `epoch_monday`).
  int dayIndex(int nowMs, {Duration? offset}) {
    final shifted = _shiftedLocalWall(nowMs, offset: offset);
    final gameDayUtc = DateTime.utc(shifted.year, shifted.month, shifted.day);
    final epochUtc =
        config.tryParseEpochMondayUtc() ?? DateTime.utc(2026, 11, 16);
    return gameDayUtc.difference(epochUtc).inDays;
  }

  /// Indeks minggu sejak `config.epochMonday` (0 = minggu `epoch_monday`).
  int weekIndex(int nowMs, {Duration? offset}) {
    final days = dayIndex(nowMs, offset: offset);
    return days >= 0 ? days ~/ 7 : ((days + 1) ~/ 7) - 1;
  }

  /// Indeks siklus dua mingguan (14 hari) sejak `config.epochMonday` (0 = dua minggu pertama).
  int biweekIndex(int nowMs, {Duration? offset}) {
    final days = dayIndex(nowMs, offset: offset);
    return days >= 0 ? days ~/ 14 : ((days + 1) ~/ 14) - 1;
  }

  /// Mengembalikan kunci periode siklus dua mingguan ('YYYY-MM-DD' hari Senin awal siklus).
  String biweeklyKey(int nowMs, {Duration? offset}) {
    final bIndex = biweekIndex(nowMs, offset: offset);
    final epochUtc =
        config.tryParseEpochMondayUtc() ?? DateTime.utc(2026, 11, 16);
    final cycleMonday = epochUtc.add(Duration(days: bIndex * 14));
    return _formatDate(cycleMonday);
  }

  /// Epoch ms waktu reset siklus dua mingguan berikutnya pada zona waktu lokal efektif.
  int nextBiweeklyResetMs(int nowMs, {Duration? offset}) {
    final tz = _resolveOffset(nowMs, offset: offset);
    final bIndex = biweekIndex(nowMs, offset: offset);
    final nextIndex = bIndex + 1;
    final epochUtc =
        config.tryParseEpochMondayUtc() ?? DateTime.utc(2026, 11, 16);
    final nextCycleMondayUtc = epochUtc.add(Duration(days: nextIndex * 14));
    final nextWallUtc = DateTime.utc(
      nextCycleMondayUtc.year,
      nextCycleMondayUtc.month,
      nextCycleMondayUtc.day,
      config.resetHour,
    );
    return nextWallUtc.millisecondsSinceEpoch - tz.inMilliseconds;
  }

  /// Epoch ms reset berikutnya untuk [period] pada zona waktu lokal efektif.
  int nextResetMs(Period period, int nowMs, {Duration? offset}) {
    final tz = _resolveOffset(nowMs, offset: offset);
    final shifted = _shiftedLocalWallWithOffset(nowMs, tz);
    final nextWall = switch (period) {
      Period.daily => DateTime.utc(
        shifted.year,
        shifted.month,
        shifted.day + 1,
        config.resetHour,
      ),
      Period.weekly => DateTime.utc(
        shifted.year,
        shifted.month,
        shifted.day + (7 - (shifted.weekday - DateTime.monday)),
        config.resetHour,
      ),
    };
    return nextWall.millisecondsSinceEpoch - tz.inMilliseconds;
  }

  Duration _resolveOffset(int nowMs, {Duration? offset}) {
    if (offset != null) return offset;
    final injected = timeZoneOffset?.call();
    if (injected != null) return injected;
    return DateTime.fromMillisecondsSinceEpoch(nowMs).timeZoneOffset;
  }

  DateTime _shiftedLocalWall(int nowMs, {Duration? offset}) {
    final tz = _resolveOffset(nowMs, offset: offset);
    return _shiftedLocalWallWithOffset(nowMs, tz);
  }

  DateTime _shiftedLocalWallWithOffset(int nowMs, Duration tzOffset) {
    final localWall = DateTime.fromMillisecondsSinceEpoch(
      nowMs + tzOffset.inMilliseconds,
      isUtc: true,
    );
    return localWall.subtract(Duration(hours: config.resetHour));
  }

  DateTime _mondayOf(DateTime shifted) => DateTime.utc(
    shifted.year,
    shifted.month,
    shifted.day - (shifted.weekday - DateTime.monday),
  );

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
