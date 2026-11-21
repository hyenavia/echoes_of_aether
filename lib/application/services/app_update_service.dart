import '../../domain/services/app_version_comparator.dart';

/// Informasi rilis terbaru dari GitHub Releases.
class AppReleaseUpdateInfo {
  const AppReleaseUpdateInfo({
    required this.latestVersion,
    required this.releaseUrl,
    this.apkDownloadUrl,
    this.releaseName,
    this.releaseNotes,
  });

  final String latestVersion;
  final String releaseUrl;
  final String? apkDownloadUrl;
  final String? releaseName;
  final String? releaseNotes;

  /// URL terbaik untuk tombol aksi: langsung ke `.apk` bila tersedia,
  /// atau ke halaman rilis GitHub.
  String get preferredActionUrl =>
      (apkDownloadUrl != null && apkDownloadUrl!.trim().isNotEmpty)
      ? apkDownloadUrl!
      : releaseUrl;

  bool get hasDirectApk =>
      apkDownloadUrl != null && apkDownloadUrl!.trim().isNotEmpty;
}

/// Kontrak sumber pengecekan rilis terbaru.
abstract interface class AppReleaseSource {
  Future<AppReleaseUpdateInfo?> fetchLatestRelease();
}

/// Hasil pengecekan pembaruan aplikasi terhadap versi lokal aktif.
class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    this.releaseInfo,
  });

  final bool hasUpdate;
  final String currentVersion;
  final AppReleaseUpdateInfo? releaseInfo;
}

/// Layanan aplikasi untuk memeriksa pembaruan dari GitHub Releases secara
/// best-effort tanpa memblokir mode offline-first.
class AppUpdateService {
  const AppUpdateService({required this.source, required this.currentVersion});

  final AppReleaseSource source;
  final String currentVersion;

  Future<AppUpdateCheckResult> checkForUpdate() async {
    final info = await source.fetchLatestRelease();
    if (info == null) {
      return AppUpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
      );
    }
    final isNewer =
        AppVersionComparator.compare(info.latestVersion, currentVersion) > 0;
    return AppUpdateCheckResult(
      hasUpdate: isNewer,
      currentVersion: currentVersion,
      releaseInfo: isNewer ? info : null,
    );
  }
}
