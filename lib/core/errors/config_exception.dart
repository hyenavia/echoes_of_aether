/// Dilempar ketika file konfigurasi game (JSON) tidak valid.
/// Pesan harus cukup jelas untuk menunjukkan file dan field yang salah.
class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => 'ConfigException: $message';
}
