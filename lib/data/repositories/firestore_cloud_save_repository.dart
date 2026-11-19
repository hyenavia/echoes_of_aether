import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/save_metrics.dart';
import '../../domain/repositories/cloud_save_repository.dart';
import '../cloud/firebase_bootstrap.dart';

/// Implementasi Firestore [CloudSaveRepository] (`DESIGN_ADDENDUM_v1.3 §2`).
///
/// Selalu membaca kedua slot (`0` dan `1`) dengan `Source.server`, memilih
/// revisi tertinggi, mengunggah ke slot `revision % 2` dengan
/// `FieldValue.serverTimestamp()`, memverifikasi checksum SHA-256 + panjang
/// blob saat unduhan, dan menyinkronkan waktu server lewat `clock/ping`.
class FirestoreCloudSaveRepository implements CloudSaveRepository {
  FirestoreCloudSaveRepository({
    FirebaseBootstrap? bootstrap,
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
    this.requestTimeout = const Duration(seconds: 8),
    this.clockTimeout = const Duration(seconds: 3),
  }) : _bootstrap = bootstrap ?? FirebaseBootstrap.instance,
       _firestoreOverride = firestore,
       _currentUidOverride = currentUid;

  final FirebaseBootstrap _bootstrap;
  final FirebaseFirestore? _firestoreOverride;
  final String? Function()? _currentUidOverride;
  final Duration requestTimeout;
  final Duration clockTimeout;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  String? _uid() {
    if (_currentUidOverride != null) {
      return _currentUidOverride();
    }
    return FirebaseAuth.instance.currentUser?.uid;
  }

  DocumentReference<Map<String, dynamic>> _slotRef(String uid, int slot) =>
      _db.collection('saves').doc(uid).collection('slots').doc('$slot');

  DocumentReference<Map<String, dynamic>> _pingRef(String uid) =>
      _db.collection('saves').doc(uid).collection('clock').doc('ping');

  @override
  Future<CloudResult<CloudSaveMeta?>> latestMeta() async {
    final initResult = await _ensureReadyUid<CloudSaveMeta?>();
    if (initResult.error != null) return initResult.error!;
    final uid = initResult.uid!;

    try {
      final highest = await _readHighestSlotDoc(uid);
      return CloudSuccess<CloudSaveMeta?>(highest?.meta);
    } on TimeoutException {
      return const CloudNetworkError(
        'Pemeriksaan metadata cloud melebihi batas waktu.',
      );
    } on FirebaseException catch (e) {
      return _mapFirestoreError<CloudSaveMeta?>(e);
    } on _MalformedSlotDocumentException catch (e) {
      return CloudRejected<CloudSaveMeta?>(
        code: 'invalid-cloud-document',
        message: e.message,
      );
    } catch (e) {
      return CloudNetworkError('Gagal membaca metadata cloud: $e');
    }
  }

  @override
  Future<CloudResult<CloudSaveDownload?>> download() async {
    final initResult = await _ensureReadyUid<CloudSaveDownload?>();
    if (initResult.error != null) return initResult.error!;
    final uid = initResult.uid!;

    try {
      final highest = await _readHighestSlotDoc(uid);
      if (highest == null) {
        return const CloudSuccess<CloudSaveDownload?>(null);
      }

      final rawBlob = highest.data['blob'];
      if (rawBlob is! Blob) {
        return const CloudRejected<CloudSaveDownload?>(
          code: 'invalid-cloud-document',
          message: 'Field blob pada dokumen cloud tidak valid.',
        );
      }
      final bytes = Uint8List.fromList(rawBlob.bytes);
      final expectedBytes = highest.meta.metrics.blobBytes;
      final expectedSha = highest.meta.metrics.blobSha256.toLowerCase();
      final actualSha = sha256.convert(bytes).toString().toLowerCase();

      if (bytes.length != expectedBytes || actualSha != expectedSha) {
        return const CloudRejected<CloudSaveDownload?>(
          code: 'checksum-mismatch',
          message: 'Verifikasi SHA-256 atau ukuran blob dari cloud gagal; pemulihan dibatalkan.',
        );
      }

      return CloudSuccess<CloudSaveDownload?>(
        CloudSaveDownload(meta: highest.meta, blob: bytes),
      );
    } on TimeoutException {
      return const CloudNetworkError(
        'Unduhan save cloud melebihi batas waktu.',
      );
    } on FirebaseException catch (e) {
      return _mapFirestoreError<CloudSaveDownload?>(e);
    } on _MalformedSlotDocumentException catch (e) {
      return CloudRejected<CloudSaveDownload?>(
        code: 'invalid-cloud-document',
        message: e.message,
      );
    } catch (e) {
      return CloudNetworkError('Gagal mengunduh save cloud: $e');
    }
  }

  @override
  Future<CloudResult<CloudSaveMeta>> upload(
    CloudSaveUploadRequest request,
  ) async {
    final initResult = await _ensureReadyUid<CloudSaveMeta>();
    if (initResult.error != null) return initResult.error!;
    final uid = initResult.uid!;

    final docRef = _slotRef(uid, request.targetSlot);
    final payload = <String, Object?>{
      'revision': request.newRevision,
      'savedAt': FieldValue.serverTimestamp(),
      'schemaVersion': request.metrics.schemaVersion,
      'codecVersion': request.metrics.codecVersion,
      'deviceId': request.deviceId,
      'appVersion': request.appVersion,
      'level': request.metrics.level,
      'gold': request.metrics.gold,
      'shards': request.metrics.shards,
      'highestAscensionRank': request.metrics.highestAscensionRank,
      'lifetimeClears': request.metrics.lifetimeClears,
      'dailyQuestDone': request.metrics.dailyQuestDone,
      'weeklyQuestDone': request.metrics.weeklyQuestDone,
      'eventPurchasesLifetime': request.metrics.eventPurchasesLifetime,
      'equipmentCount': request.metrics.equipmentCount,
      'blobBytes': request.metrics.blobBytes,
      'blobSha256': request.metrics.blobSha256,
      'blob': Blob(request.blob),
    };

    try {
      await docRef.set(payload).timeout(requestTimeout);
      final written = await docRef
          .get(const GetOptions(source: Source.server))
          .timeout(requestTimeout);
      final data = written.data();
      if (!written.exists || data == null) {
        return CloudSuccess<CloudSaveMeta>(
          CloudSaveMeta(
            revision: request.newRevision,
            slot: request.targetSlot,
            savedAtServerMs: 0,
            deviceId: request.deviceId,
            appVersion: request.appVersion,
            metrics: request.metrics,
          ),
        );
      }
      final parsed = _parseMeta(data, slot: request.targetSlot);
      return CloudSuccess<CloudSaveMeta>(parsed);
    } on TimeoutException {
      return const CloudNetworkError('Unggahan cloud melebihi batas waktu.');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' ||
          e.code == 'failed-precondition' ||
          e.code == 'invalid-argument') {
        _ParsedSlotDoc? latest;
        try {
          latest = await _readHighestSlotDoc(uid);
        } catch (_) {
          latest = null;
        }
        final cloudRev = latest?.meta.revision;
        final isConflict =
            cloudRev != null &&
            (cloudRev >= request.newRevision ||
                cloudRev != request.expectedBaseRevision);
        return CloudRejected<CloudSaveMeta>(
          code: e.code,
          message:
              e.message ??
              (isConflict
                  ? 'Konflik revisi: cloud memiliki data yang lebih baru.'
                  : 'Unggahan ditolak oleh aturan Firestore.'),
          currentRevision: cloudRev,
          isConflict: isConflict,
        );
      }
      return _mapFirestoreError<CloudSaveMeta>(e);
    } catch (e) {
      return CloudNetworkError('Gagal mengunggah save ke cloud: $e');
    }
  }

  @override
  Future<CloudResult<int>> serverTimeMs() async {
    final initResult = await _ensureReadyUid<int>();
    if (initResult.error != null) return initResult.error!;
    final uid = initResult.uid!;

    try {
      final ref = _pingRef(uid);
      await ref
          .set(<String, Object?>{'t': FieldValue.serverTimestamp()})
          .timeout(clockTimeout);
      final snap = await ref
          .get(const GetOptions(source: Source.server))
          .timeout(clockTimeout);
      final ts = snap.data()?['t'];
      if (ts is! Timestamp) {
        return const CloudNetworkError('Timestamp server tidak tersedia.');
      }
      return CloudSuccess<int>(ts.millisecondsSinceEpoch);
    } on TimeoutException {
      return const CloudNetworkError(
        'Pengambilan waktu server melebihi batas waktu.',
      );
    } on FirebaseException catch (e) {
      return _mapFirestoreError<int>(e);
    } catch (e) {
      return CloudNetworkError('Gagal membaca waktu server: $e');
    }
  }

  Future<({String? uid, CloudResult<T>? error})> _ensureReadyUid<T>() async {
    final availability = await _bootstrap.initialize();
    if (availability is CloudUnavailable) {
      return (uid: null, error: CloudNetworkError<T>(availability.reason));
    }
    final uid = _uid();
    if (uid == null || uid.isEmpty) {
      return (uid: null, error: CloudAuthRequired<T>());
    }
    return (uid: uid, error: null);
  }

  Future<_ParsedSlotDoc?> _readHighestSlotDoc(String uid) async {
    const serverOpts = GetOptions(source: Source.server);
    final snaps = await Future.wait<DocumentSnapshot<Map<String, dynamic>>>([
      _slotRef(uid, 0).get(serverOpts).timeout(requestTimeout),
      _slotRef(uid, 1).get(serverOpts).timeout(requestTimeout),
    ]);

    _ParsedSlotDoc? best;
    for (var slot = 0; slot < snaps.length; slot++) {
      final snap = snaps[slot];
      final data = snap.data();
      if (!snap.exists || data == null) continue;
      final meta = _parseMeta(data, slot: slot);
      if (best == null || meta.revision > best.meta.revision) {
        best = _ParsedSlotDoc(meta: meta, data: data);
      }
    }
    return best;
  }

  CloudSaveMeta _parseMeta(Map<String, dynamic> data, {required int slot}) {
    final savedAt = data['savedAt'];
    final savedAtMs = savedAt is Timestamp ? savedAt.millisecondsSinceEpoch : 0;
    final revision = _readInt(data, 'revision');
    final schemaVersion = _readInt(data, 'schemaVersion');
    final codecVersion = _readInt(data, 'codecVersion');
    final deviceId = _readString(data, 'deviceId');
    final appVersion = _readString(data, 'appVersion');
    final level = _readInt(data, 'level');
    final gold = _readInt(data, 'gold');
    final shards = _readInt(data, 'shards');
    final highestAscensionRank = _readInt(data, 'highestAscensionRank');
    final lifetimeClears = _readInt(data, 'lifetimeClears');
    final dailyQuestDone = _readInt(data, 'dailyQuestDone');
    final weeklyQuestDone = _readInt(data, 'weeklyQuestDone');
    final eventPurchasesLifetime = _readInt(data, 'eventPurchasesLifetime');
    final equipmentCount = _readInt(data, 'equipmentCount');
    final blobBytes = _readInt(data, 'blobBytes');
    final blobSha256 = _readString(data, 'blobSha256');

    return CloudSaveMeta(
      revision: revision,
      slot: slot,
      savedAtServerMs: savedAtMs,
      deviceId: deviceId,
      appVersion: appVersion,
      metrics: SaveMetrics(
        level: level,
        gold: gold,
        shards: shards,
        highestAscensionRank: highestAscensionRank,
        lifetimeClears: lifetimeClears,
        dailyQuestDone: dailyQuestDone,
        weeklyQuestDone: weeklyQuestDone,
        eventPurchasesLifetime: eventPurchasesLifetime,
        equipmentCount: equipmentCount,
        blobBytes: blobBytes,
        blobSha256: blobSha256,
        schemaVersion: schemaVersion,
        codecVersion: codecVersion,
      ),
    );
  }

  static int _readInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is int) return value;
    throw _MalformedSlotDocumentException(
      'Field "$key" pada dokumen cloud bukan integer.',
    );
  }

  static String _readString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String) return value;
    throw _MalformedSlotDocumentException(
      'Field "$key" pada dokumen cloud bukan string.',
    );
  }

  static CloudResult<T> _mapFirestoreError<T>(FirebaseException e) {
    return switch (e.code) {
      'unauthenticated' => CloudAuthRequired<T>(
        e.message ?? 'Masuk akun diperlukan.',
      ),
      'resource-exhausted' => CloudQuotaExceeded<T>(
        e.message ?? 'Kuota Firestore terlampaui.',
      ),
      'permission-denied' ||
      'failed-precondition' ||
      'invalid-argument' => CloudRejected<T>(
        code: e.code,
        message: e.message ?? 'Operasi ditolak oleh Firestore.',
      ),
      _ => CloudNetworkError<T>(
        e.message ?? 'Koneksi jaringan cloud bermasalah (${e.code}).',
      ),
    };
  }
}

class _ParsedSlotDoc {
  const _ParsedSlotDoc({required this.meta, required this.data});

  final CloudSaveMeta meta;
  final Map<String, dynamic> data;
}

class _MalformedSlotDocumentException implements Exception {
  const _MalformedSlotDocumentException(this.message);

  final String message;
}
