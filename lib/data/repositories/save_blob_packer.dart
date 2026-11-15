import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../domain/entities/game_config.dart';
import '../../domain/entities/player_save_snapshot.dart';
import '../../domain/services/save_snapshot_codec.dart';

/// Jenis kegagalan pembongkaran blob terkompresi sebelum atau di luar validasi kodek.
enum SaveBlobUnpackErrorCode { hashMismatch, corruptedGzip, invalidUtf8 }

/// Exception bertipe untuk kegagalan kompresi/dekompresi/verifikasi SHA-256 blob save.
class SaveBlobPackException implements Exception {
  const SaveBlobPackException(this.code, this.message);

  final SaveBlobUnpackErrorCode code;
  final String message;

  @override
  String toString() => 'SaveBlobPackException($code: $message)';
}

/// Hasil pengepakan [PlayerSaveSnapshot] menjadi blob gzip siap simpan/unggah.
class PackedSaveBlob {
  const PackedSaveBlob({
    required this.canonicalJson,
    required this.rawJsonBytes,
    required this.compressedBytes,
    required this.sha256Hex,
    required this.codecVersion,
  });

  final String canonicalJson;
  final int rawJsonBytes;
  final Uint8List compressedBytes;
  final String sha256Hex;
  final int codecVersion;

  int get blobBytes => compressedBytes.length;
}

/// Pengepak lapisan data: JSON kanonis -> UTF-8 -> gzip (`dart:io`) + SHA-256 hex.
///
/// Lapisan `dart:io` terisolasi di file ini agar domain tetap bebas dari `dart:io`.
class SaveBlobPacker {
  const SaveBlobPacker({this.codec = const SaveSnapshotCodec()});

  final SaveSnapshotCodec codec;

  /// Mengubah [snapshot] menjadi [PackedSaveBlob] deterministik beserta hash SHA-256
  /// dari byte gzip.
  PackedSaveBlob pack(PlayerSaveSnapshot snapshot) {
    final canonicalJson = codec.encodeToCanonicalJson(snapshot);
    final rawBytes = utf8.encode(canonicalJson);
    final compressed = Uint8List.fromList(gzip.encode(rawBytes));
    final hash = sha256Hex(compressed);
    return PackedSaveBlob(
      canonicalJson: canonicalJson,
      rawJsonBytes: rawBytes.length,
      compressedBytes: compressed,
      sha256Hex: hash,
      codecVersion: SaveSnapshotCodec.supportedCodecVersion,
    );
  }

  /// Memverifikasi hash [expectedSha256] (jika tersedia), mendekompresi gzip,
  /// mendekode UTF-8, lalu memvalidasi ketat lewat [SaveSnapshotCodec].
  PlayerSaveSnapshot unpack(
    Uint8List blobBytes, {
    String? expectedSha256,
    required GameConfig config,
  }) {
    final actualSha256 = sha256Hex(blobBytes);
    if (expectedSha256 != null &&
        expectedSha256.trim().toLowerCase() != actualSha256) {
      throw SaveBlobPackException(
        SaveBlobUnpackErrorCode.hashMismatch,
        'Hash SHA-256 blob tidak cocok '
        '(diharapkan: $expectedSha256, aktual: $actualSha256).',
      );
    }

    final List<int> rawBytes;
    try {
      rawBytes = gzip.decode(blobBytes);
    } on Object catch (e) {
      throw SaveBlobPackException(
        SaveBlobUnpackErrorCode.corruptedGzip,
        'Stream gzip save rusak: $e',
      );
    }

    final String jsonSource;
    try {
      jsonSource = utf8.decode(rawBytes);
    } on FormatException catch (e) {
      throw SaveBlobPackException(
        SaveBlobUnpackErrorCode.invalidUtf8,
        'Payload UTF-8 save tidak valid: ${e.message}',
      );
    }

    return codec.decodeFromCanonicalJson(jsonSource, config: config);
  }

  static String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();
}
