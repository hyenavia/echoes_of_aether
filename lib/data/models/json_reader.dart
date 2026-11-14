import 'dart:convert';

import '../../core/errors/config_exception.dart';

/// Pembaca JSON bervalidasi untuk file konfigurasi. Setiap error menyebut
/// nama file dan lokasi field agar mudah diperbaiki.
class JsonReader {
  const JsonReader(this.file);

  final String file;

  Map<String, dynamic> decodeRoot(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw ConfigException('$file bukan JSON valid: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ConfigException('$file: root harus berupa object.');
    }
    return decoded;
  }

  Map<String, dynamic> asMap(Object? value, String where) {
    if (value is Map<String, dynamic>) return value;
    throw ConfigException('$file: $where harus berupa object.');
  }

  List<dynamic> list(Map<String, dynamic> map, String where, String key) {
    final value = map[key];
    if (value is List) return value;
    throw ConfigException('$file: $where."$key" harus berupa array.');
  }

  /// Menolak field yang tidak dikenal (menangkap salah ketik seperti "atck").
  void ensureKnownKeys(
    Map<String, dynamic> map,
    String where,
    Set<String> allowed,
  ) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        throw ConfigException(
          '$file: $where memiliki field tidak dikenal "$key" '
          '(yang valid: ${allowed.join(', ')}).',
        );
      }
    }
  }

  String string(Map<String, dynamic> map, String where, String key) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
    throw ConfigException(
      '$file: $where."$key" harus berupa teks tidak kosong.',
    );
  }

  int integer(
    Map<String, dynamic> map,
    String where,
    String key, {
    required int min,
    int? fallback,
  }) {
    final value = map[key];
    if (value == null) {
      if (fallback != null) return fallback;
      throw ConfigException('$file: $where."$key" wajib diisi.');
    }
    if (value is! int) {
      throw ConfigException(
        '$file: $where."$key" harus berupa bilangan bulat.',
      );
    }
    if (value < min) {
      throw ConfigException(
        '$file: $where."$key" harus >= $min (nilai: $value).',
      );
    }
    return value;
  }

  double number(
    Map<String, dynamic> map,
    String where,
    String key, {
    required double min,
    bool minExclusive = false,
    double? max,
    double? fallback,
  }) {
    final value = map[key];
    if (value == null) {
      if (fallback != null) return fallback;
      throw ConfigException('$file: $where."$key" wajib diisi.');
    }
    if (value is! num) {
      throw ConfigException('$file: $where."$key" harus berupa angka.');
    }
    final number = value.toDouble();
    if (minExclusive ? number <= min : number < min) {
      final op = minExclusive ? '>' : '>=';
      throw ConfigException(
        '$file: $where."$key" harus $op $min (nilai: $number).',
      );
    }
    if (max != null && number > max) {
      throw ConfigException(
        '$file: $where."$key" harus <= $max (nilai: $number).',
      );
    }
    return number;
  }
}
