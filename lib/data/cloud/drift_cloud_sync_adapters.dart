import 'dart:typed_data';

import '../../application/services/cloud_sync_service.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/entities/player_save_snapshot.dart';
import '../repositories/local_backup_service.dart';
import '../repositories/save_blob_packer.dart';

/// Adapter lapisan data yang menjembatani [SaveBlobPacker] (`dart:io` gzip +
/// SHA-256) ke kontrak [SaveBlobCodecPort] di lapisan aplikasi.
class SaveBlobPackerAdapter implements SaveBlobCodecPort {
  const SaveBlobPackerAdapter([this.packer = const SaveBlobPacker()]);

  final SaveBlobPacker packer;

  @override
  PackedCloudBlob pack(PlayerSaveSnapshot snapshot) {
    final packed = packer.pack(snapshot);
    return PackedCloudBlob(
      compressedBytes: packed.compressedBytes,
      sha256Hex: packed.sha256Hex,
      codecVersion: packed.codecVersion,
    );
  }

  @override
  PlayerSaveSnapshot unpack(
    Uint8List compressedBytes, {
    required String expectedSha256,
    required GameConfig config,
  }) => packer.unpack(
    compressedBytes,
    expectedSha256: expectedSha256,
    config: config,
  );
}

/// Adapter lapisan data yang menjembatani [LocalBackupService] (Drift tabel
/// `LocalSaveBackups`, retensi 3 salinan) ke [LocalBackupPort].
class LocalBackupServiceAdapter implements LocalBackupPort {
  const LocalBackupServiceAdapter(this.service);

  final LocalBackupService service;

  @override
  Future<void> createBackup(
    PlayerSaveSnapshot snapshot, {
    required String reason,
    int? createdAtMs,
  }) async {
    await service.saveBackup(
      snapshot,
      reason: reason,
      createdAtMs: createdAtMs,
    );
  }
}
