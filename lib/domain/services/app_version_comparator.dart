/// Utilitas pembanding versi aplikasi berformat `major.minor.patch+build`.
class AppVersionComparator {
  const AppVersionComparator._();

  static final RegExp _versionPattern = RegExp(
    r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:\+(\d+))?$',
    caseSensitive: false,
  );

  /// Mengurai string versi menjadi tuple angka, atau `null` bila format tidak valid.
  static ({int major, int minor, int patch, int build})? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final match = _versionPattern.firstMatch(trimmed);
    if (match == null) return null;

    final major = int.tryParse(match.group(1) ?? '');
    final minor = match.group(2) == null ? 0 : int.tryParse(match.group(2)!);
    final patch = match.group(3) == null ? 0 : int.tryParse(match.group(3)!);
    final build = match.group(4) == null ? 0 : int.tryParse(match.group(4)!);
    if (major == null || minor == null || patch == null || build == null) {
      return null;
    }
    return (major: major, minor: minor, patch: patch, build: build);
  }

  /// Mengembalikan `< 0` bila `a < b`, `0` bila setara/tidak dapat dibandingkan,
  /// dan `> 0` bila `a > b`.
  static int compare(String a, String b) {
    final pa = tryParse(a);
    final pb = tryParse(b);
    if (pa == null || pb == null) return 0;

    if (pa.major != pb.major) return pa.major.compareTo(pb.major);
    if (pa.minor != pb.minor) return pa.minor.compareTo(pb.minor);
    if (pa.patch != pb.patch) return pa.patch.compareTo(pb.patch);
    return pa.build.compareTo(pb.build);
  }

  /// Menentukan apakah informasi remote lebih baru dibanding versi aplikasi atau
  /// versi schema lokal saat ini.
  static bool isRemoteNewer({
    required String localAppVersion,
    required int localSchemaVersion,
    String? remoteAppVersion,
    int? remoteSchemaVersion,
  }) {
    if (remoteSchemaVersion != null &&
        remoteSchemaVersion > localSchemaVersion) {
      return true;
    }
    if (remoteAppVersion != null &&
        remoteAppVersion.trim().isNotEmpty &&
        compare(remoteAppVersion, localAppVersion) > 0) {
      return true;
    }
    return false;
  }
}
