import 'dart:typed_data';

import '../entities/save_metrics.dart';

/// Metadata slot cloud tanpa harus memuat atau membongkar blob save.
class CloudSaveMeta {
  const CloudSaveMeta({
    required this.revision,
    required this.slot,
    required this.savedAtServerMs,
    required this.deviceId,
    required this.appVersion,
    required this.metrics,
  });

  final int revision;
  final int slot;
  final int savedAtServerMs;
  final String deviceId;
  final String appVersion;
  final SaveMetrics metrics;
}

/// Hasil unduhan dokumen slot cloud beserta byte blob gzip terkompresi.
class CloudSaveDownload {
  const CloudSaveDownload({required this.meta, required this.blob});

  final CloudSaveMeta meta;
  final Uint8List blob;
}

/// Muatan unggahan save ke slot `newRevision % 2`.
class CloudSaveUploadRequest {
  const CloudSaveUploadRequest({
    required this.expectedBaseRevision,
    required this.newRevision,
    required this.deviceId,
    required this.appVersion,
    required this.metrics,
    required this.blob,
  });

  final int expectedBaseRevision;
  final int newRevision;
  final String deviceId;
  final String appVersion;
  final SaveMetrics metrics;
  final Uint8List blob;

  int get targetSlot => newRevision % 2;
}

/// Hasil bertipe seluruh operasi jaringan Cloud Save.
sealed class CloudResult<T> {
  const CloudResult();
}

final class CloudSuccess<T> extends CloudResult<T> {
  const CloudSuccess(this.value);

  final T value;
}

final class CloudRejected<T> extends CloudResult<T> {
  const CloudRejected({
    required this.code,
    this.message,
    this.currentRevision,
    this.isConflict = false,
  });

  final String code;
  final String? message;
  final int? currentRevision;
  final bool isConflict;
}

final class CloudNetworkError<T> extends CloudResult<T> {
  const CloudNetworkError([this.message = 'Koneksi jaringan bermasalah.']);

  final String message;
}

final class CloudAuthRequired<T> extends CloudResult<T> {
  const CloudAuthRequired([this.message = 'Masuk akun diperlukan.']);

  final String message;
}

final class CloudQuotaExceeded<T> extends CloudResult<T> {
  const CloudQuotaExceeded([this.message = 'Kuota Firestore terlampaui.']);

  final String message;
}

/// Kontrak repository Cloud Save di lapisan domain/application.
///
/// Implementasi memori dipakai pada unit test (Stage 1) dan implementasi
/// Firestore ditambahkan pada Stage 2 tanpa mengubah domain/application.
abstract interface class CloudSaveRepository {
  Future<CloudResult<CloudSaveMeta?>> latestMeta();

  Future<CloudResult<CloudSaveDownload?>> download();

  Future<CloudResult<CloudSaveMeta>> upload(CloudSaveUploadRequest request);

  Future<CloudResult<int>> serverTimeMs();
}
