import 'package:flutter/services.dart';

/// Pembuka URL eksternal (browser / unduh APK) melalui Android platform channel.
class ExternalUrlLauncher {
  const ExternalUrlLauncher._();

  static const MethodChannel _channel = MethodChannel(
    'echoes_of_aether/external_url',
  );

  /// Membuka [url] di browser/aplikasi eksternal perangkat.
  /// Mengembalikan `true` bila berhasil dipicu.
  static Future<bool> openUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('openUrl', {
        'url': trimmed,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
