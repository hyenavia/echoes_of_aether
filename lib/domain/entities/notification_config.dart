/// Rentang jam tenang (quiet hours) dalam jam lokal `0..23`.
class QuietHoursConfig {
  const QuietHoursConfig({this.startHour = 23, this.endHour = 7});

  final int startHour;
  final int endHour;

  /// Mengembalikan `true` bila [hour] (`0..23`) berada di dalam rentang jam
  /// tenang `[startHour, endHour)`. Mendukung rentang yang melewati tengah malam.
  bool containsHour(int hour) {
    if (startHour == endHour) return false;
    if (startHour < endHour) {
      return hour >= startHour && hour < endHour;
    }
    return hour >= startHour || hour < endHour;
  }
}

/// Konfigurasi notifikasi lokal dari blok `"notifications"` di `game_config.json`.
class NotificationConfig {
  const NotificationConfig({
    this.dailyReminderHour = 18,
    this.weeklyReminderWeekday = DateTime.sunday,
    this.weeklyReminderHour = 18,
    this.quietHours = const QuietHoursConfig(),
    this.maxPerDay = 3,
  });

  final int dailyReminderHour;
  final int weeklyReminderWeekday;
  final int weeklyReminderHour;
  final QuietHoursConfig quietHours;
  final int maxPerDay;

  static int? parseWeekday(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'monday' => DateTime.monday,
      'tuesday' => DateTime.tuesday,
      'wednesday' => DateTime.wednesday,
      'thursday' => DateTime.thursday,
      'friday' => DateTime.friday,
      'saturday' => DateTime.saturday,
      'sunday' => DateTime.sunday,
      _ => null,
    };
  }
}
