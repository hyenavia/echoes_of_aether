import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../domain/entities/cloud_sync_state.dart' as domain;
import '../../domain/entities/player_save_snapshot.dart';
import '../../domain/repositories/cloud_sync_state_repository.dart';
import '../database/app_database.dart';

/// Implementasi Drift untuk [CloudSyncStateRepository].
///
/// Menghasilkan `deviceId` acak memakai [math.Random.secure()] saat pertama kali
/// dibutuhkan dan menyimpannya ke tabel `CloudSyncStates`.
class DriftCloudSyncStateRepository implements CloudSyncStateRepository {
  DriftCloudSyncStateRepository({
    required this.db,
    this.defaultPlayerId = GameSessionSnapshot.defaultPlayerId,
    math.Random? secureRandom,
  }) : _random = secureRandom ?? math.Random.secure();

  final AppDatabase db;
  final String defaultPlayerId;
  final math.Random _random;

  String _generateDeviceId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  domain.CloudSyncState _mapRow(CloudSyncState row) => domain.CloudSyncState(
    playerId: row.playerId,
    deviceId: row.deviceId,
    lastSyncedRevision: row.lastSyncedRevision,
    lastSyncedBlobSha256: row.lastSyncedBlobSha256,
    lastSyncAtMs: row.lastSyncAtMs,
    lastRejectCode: row.lastRejectCode,
    lastRejectAtMs: row.lastRejectAtMs,
    serverOffsetMs: row.serverOffsetMs,
    serverOffsetAtMs: row.serverOffsetAtMs,
  );

  @override
  Future<domain.CloudSyncState> getOrCreateState({String? playerId}) {
    final pid = playerId ?? defaultPlayerId;
    return db.transaction(() async {
      final existing = await (db.select(
        db.cloudSyncStates,
      )..where((t) => t.playerId.equals(pid))).getSingleOrNull();
      if (existing != null && existing.deviceId.trim().isNotEmpty) {
        return _mapRow(existing);
      }

      final deviceId = _generateDeviceId();
      await db
          .into(db.cloudSyncStates)
          .insertOnConflictUpdate(
            CloudSyncStatesCompanion.insert(playerId: pid, deviceId: deviceId),
          );
      final created = await (db.select(
        db.cloudSyncStates,
      )..where((t) => t.playerId.equals(pid))).getSingle();
      return _mapRow(created);
    });
  }

  @override
  Future<void> saveState(domain.CloudSyncState state) {
    return db.transaction(() async {
      await db
          .into(db.cloudSyncStates)
          .insertOnConflictUpdate(
            CloudSyncStatesCompanion(
              playerId: Value(state.playerId),
              deviceId: Value(
                state.deviceId.trim().isEmpty
                    ? _generateDeviceId()
                    : state.deviceId,
              ),
              lastSyncedRevision: Value(math.max(0, state.lastSyncedRevision)),
              lastSyncedBlobSha256: Value(state.lastSyncedBlobSha256),
              lastSyncAtMs: Value(state.lastSyncAtMs),
              lastRejectCode: Value(state.lastRejectCode),
              lastRejectAtMs: Value(state.lastRejectAtMs),
              serverOffsetMs: Value(state.serverOffsetMs),
              serverOffsetAtMs: Value(state.serverOffsetAtMs),
            ),
          );
    });
  }

  @override
  Future<void> markSynced({
    String? playerId,
    required int revision,
    required String blobSha256,
    required int syncedAtMs,
  }) async {
    final current = await getOrCreateState(playerId: playerId);
    await db.transaction(() async {
      await (db.update(
        db.cloudSyncStates,
      )..where((t) => t.playerId.equals(current.playerId))).write(
        CloudSyncStatesCompanion(
          lastSyncedRevision: Value(math.max(0, revision)),
          lastSyncedBlobSha256: Value(blobSha256),
          lastSyncAtMs: Value(syncedAtMs),
          lastRejectCode: const Value(null),
          lastRejectAtMs: const Value(null),
        ),
      );
    });
  }

  @override
  Future<void> markRejected({
    String? playerId,
    required String code,
    required int rejectedAtMs,
  }) async {
    final current = await getOrCreateState(playerId: playerId);
    await db.transaction(() async {
      await (db.update(
        db.cloudSyncStates,
      )..where((t) => t.playerId.equals(current.playerId))).write(
        CloudSyncStatesCompanion(
          lastRejectCode: Value(code),
          lastRejectAtMs: Value(rejectedAtMs),
        ),
      );
    });
  }

  @override
  Future<void> updateServerOffset({
    String? playerId,
    required int offsetMs,
    required int measuredAtMs,
  }) async {
    final current = await getOrCreateState(playerId: playerId);
    await db.transaction(() async {
      await (db.update(
        db.cloudSyncStates,
      )..where((t) => t.playerId.equals(current.playerId))).write(
        CloudSyncStatesCompanion(
          serverOffsetMs: Value(offsetMs),
          serverOffsetAtMs: Value(measuredAtMs),
        ),
      );
    });
  }
}
