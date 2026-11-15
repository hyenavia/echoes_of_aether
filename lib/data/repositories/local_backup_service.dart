import 'package:drift/drift.dart';

import '../../domain/entities/game_config.dart';
import '../../domain/entities/player_save_snapshot.dart';
import '../../domain/services/game_clock.dart';
import '../database/app_database.dart';
import 'save_blob_packer.dart';

/// Metadata dan payload satu entri cadangan lokal di `LocalSaveBackups`.
class LocalSaveBackupRecord {
  const LocalSaveBackupRecord({
    required this.id,
    required this.createdAtMs,
    required this.reason,
    required this.schemaVersion,
    required this.blobSha256,
    required this.blob,
  });

  final int id;
  final int createdAtMs;
  final String reason;
  final int schemaVersion;
  final String blobSha256;
  final Uint8List blob;
}

/// Mengelola tabel `LocalSaveBackups` (schema v8): menyimpan cadangan lokal
/// terkompresi sebelum pemulihan cloud dan mempertahankan hanya [maxRetained]
/// salinan terbaru.
class LocalBackupService {
  const LocalBackupService({
    required this.db,
    this.packer = const SaveBlobPacker(),
    this.clock = const SystemGameClock(),
  });

  static const int defaultMaxRetained = 3;

  final AppDatabase db;
  final SaveBlobPacker packer;
  final GameClock clock;

  /// Mengepak [snapshot] ke blob gzip lalu menyimpannya ke `LocalSaveBackups`
  /// dan memangkas entri lama agar maksimal hanya [maxRetained] (default 3)
  /// baris terbaru yang tersimpan.
  Future<LocalSaveBackupRecord> saveBackup(
    PlayerSaveSnapshot snapshot, {
    required String reason,
    int? createdAtMs,
    int maxRetained = defaultMaxRetained,
  }) async {
    final packed = packer.pack(snapshot);
    final timestamp = createdAtMs ?? clock.nowMs;
    final schemaVersion = db.schemaVersion;

    return db.transaction(() async {
      final insertedId = await db
          .into(db.localSaveBackups)
          .insert(
            LocalSaveBackupsCompanion.insert(
              createdAtMs: timestamp,
              reason: reason,
              schemaVersion: schemaVersion,
              blobSha256: packed.sha256Hex,
              payload: packed.compressedBytes,
            ),
          );

      final allOrdered = await (db.select(
        db.localSaveBackups,
      )..orderBy([(t) => OrderingTerm.desc(t.id)])).get();
      if (allOrdered.length > maxRetained) {
        final toDeleteIds = allOrdered
            .skip(maxRetained)
            .map((r) => r.id)
            .toList();
        await (db.delete(
          db.localSaveBackups,
        )..where((t) => t.id.isIn(toDeleteIds))).go();
      }

      return LocalSaveBackupRecord(
        id: insertedId,
        createdAtMs: timestamp,
        reason: reason,
        schemaVersion: schemaVersion,
        blobSha256: packed.sha256Hex,
        blob: packed.compressedBytes,
      );
    });
  }

  /// Mengembalikan daftar cadangan terbaru terlebih dahulu.
  Future<List<LocalSaveBackupRecord>> listBackups() async {
    final rows = await (db.select(
      db.localSaveBackups,
    )..orderBy([(t) => OrderingTerm.desc(t.id)])).get();
    return [
      for (final r in rows)
        LocalSaveBackupRecord(
          id: r.id,
          createdAtMs: r.createdAtMs,
          reason: r.reason,
          schemaVersion: r.schemaVersion,
          blobSha256: r.blobSha256,
          blob: r.payload,
        ),
    ];
  }

  /// Membongkar cadangan [record] serta memverifikasi integritas SHA-256 dan
  /// validitasnya terhadap [config].
  PlayerSaveSnapshot restoreFromRecord(
    LocalSaveBackupRecord record, {
    required GameConfig config,
  }) {
    return packer.unpack(
      record.blob,
      expectedSha256: record.blobSha256,
      config: config,
    );
  }
}
