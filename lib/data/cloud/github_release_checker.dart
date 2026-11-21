import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../application/services/app_update_service.dart';
import '../../domain/services/app_version_comparator.dart';

/// Mengecek rilis terbaru aplikasi dari GitHub Releases API secara best-effort
/// menggunakan `dart:io` [HttpClient] tanpa dependensi eksternal tambahan.
class GithubReleaseChecker implements AppReleaseSource {
  GithubReleaseChecker({
    this.owner = defaultOwner,
    this.repo = defaultRepo,
    this.timeout = const Duration(seconds: 4),
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  static const String defaultOwner = 'hyenavia';
  static const String defaultRepo = 'echoes_of_aether';

  final String owner;
  final String repo;
  final Duration timeout;
  final HttpClient Function() _httpClientFactory;

  Uri get latestReleaseUri =>
      Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');

  @override
  Future<AppReleaseUpdateInfo?> fetchLatestRelease() async {
    HttpClient? client;
    try {
      client = _httpClientFactory();
      client.connectionTimeout = timeout;
      final req = await client.getUrl(latestReleaseUri).timeout(timeout);
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      req.headers.set(HttpHeaders.userAgentHeader, 'echoes_of_aether');
      final res = await req.close().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      return parseReleaseJson(body);
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// Mengurai payload JSON `/releases/latest` GitHub menjadi [AppReleaseUpdateInfo].
  static AppReleaseUpdateInfo? parseReleaseJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['draft'] == true) return null;

      final tag = (decoded['tag_name'] as String?)?.trim() ?? '';
      final htmlUrl = (decoded['html_url'] as String?)?.trim() ?? '';
      if (tag.isEmpty || htmlUrl.isEmpty) return null;
      if (AppVersionComparator.tryParse(tag) == null) return null;

      final normalizedVersion = tag.toLowerCase().startsWith('v')
          ? tag.substring(1).trim()
          : tag;

      String? apkUrl;
      final assets = decoded['assets'];
      if (assets is List) {
        for (final asset in assets) {
          if (asset is! Map<String, dynamic>) continue;
          final name = (asset['name'] as String?)?.toLowerCase() ?? '';
          final url = (asset['browser_download_url'] as String?)?.trim() ?? '';
          if (name.endsWith('.apk') && url.isNotEmpty) {
            apkUrl = url;
            break;
          }
        }
      }

      final releaseName = (decoded['name'] as String?)?.trim();
      final releaseNotes = (decoded['body'] as String?)?.trim();
      return AppReleaseUpdateInfo(
        latestVersion: normalizedVersion,
        releaseUrl: htmlUrl,
        apkDownloadUrl: apkUrl,
        releaseName: (releaseName == null || releaseName.isEmpty)
            ? null
            : releaseName,
        releaseNotes: (releaseNotes == null || releaseNotes.isEmpty)
            ? null
            : releaseNotes,
      );
    } catch (_) {
      return null;
    }
  }
}
