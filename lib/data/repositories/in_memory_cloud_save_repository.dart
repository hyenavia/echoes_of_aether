import 'dart:typed_data';

import '../../domain/repositories/cloud_save_repository.dart';

/// Hook kesalahan terprogram untuk mensimulasikan berbagai skenario Cloud Save
/// pada implementasi memori.
enum CloudFaultMode {
  none,
  networkError,
  authRequired,
  quotaExceeded,
  rejected,
  conflict,
}

/// Implementasi memori [CloudSaveRepository] yang meniru dua slot bergantian
/// (`revision % 2`), validasi revisi, jam server injeksi, dan hook simulasi
/// penolakan/jaringan putus/konflik.
class InMemoryCloudSaveRepository implements CloudSaveRepository {
  InMemoryCloudSaveRepository({
    int Function()? serverNowMs,
    this.isSignedIn = true,
  }) : _serverNowMs =
           serverNowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const int maxBlobBytes = 900000;

  final int Function() _serverNowMs;
  bool isSignedIn;

  /// Hook kesalahan umum (berlaku sebelum atau saat operasi berikutnya).
  CloudFaultMode nextFault = CloudFaultMode.none;
  String nextRejectCode = 'permission-denied';
  String? nextRejectMessage;

  /// Jika true, kesalahan hanya berlaku sekali lalu otomatis reset ke `none`.
  bool oneShotFault = false;

  /// Hook custom opsional untuk mensimulasikan validasi rules Firestore per upload.
  CloudRejected<CloudSaveMeta>? Function(
    CloudSaveUploadRequest request,
    CloudSaveMeta? previousMeta,
  )?
  uploadValidatorHook;

  final Map<int, CloudSaveDownload> _slots = {};

  CloudSaveDownload? slotData(int slot) => _slots[slot];

  void seedSlot(CloudSaveDownload entry) {
    _slots[entry.meta.slot] = entry;
  }

  CloudResult<T>? _checkFault<T>() {
    if (!isSignedIn) {
      return CloudAuthRequired<T>();
    }
    final mode = nextFault;
    if (mode == CloudFaultMode.none) return null;
    if (oneShotFault) {
      nextFault = CloudFaultMode.none;
    }
    return switch (mode) {
      CloudFaultMode.none => null,
      CloudFaultMode.networkError => CloudNetworkError<T>(
        nextRejectMessage ?? 'Koneksi jaringan terputus.',
      ),
      CloudFaultMode.authRequired => CloudAuthRequired<T>(
        nextRejectMessage ?? 'Sesi login tidak valid.',
      ),
      CloudFaultMode.quotaExceeded => CloudQuotaExceeded<T>(
        nextRejectMessage ?? 'Kuota Spark harian tercapai.',
      ),
      CloudFaultMode.rejected => CloudRejected<T>(
        code: nextRejectCode,
        message: nextRejectMessage ?? 'Ditolak oleh aturan server.',
      ),
      CloudFaultMode.conflict => CloudRejected<T>(
        code: 'revision_conflict',
        message: nextRejectMessage ?? 'Revisi cloud sudah berubah.',
        currentRevision: _latestDownload()?.meta.revision,
        isConflict: true,
      ),
    };
  }

  CloudSaveDownload? _latestDownload() {
    CloudSaveDownload? best;
    for (final entry in _slots.values) {
      if (best == null || entry.meta.revision > best.meta.revision) {
        best = entry;
      }
    }
    return best;
  }

  @override
  Future<CloudResult<CloudSaveMeta?>> latestMeta() async {
    final fault = _checkFault<CloudSaveMeta?>();
    if (fault != null) return fault;
    return CloudSuccess(_latestDownload()?.meta);
  }

  @override
  Future<CloudResult<CloudSaveDownload?>> download() async {
    final fault = _checkFault<CloudSaveDownload?>();
    if (fault != null) return fault;
    return CloudSuccess(_latestDownload());
  }

  @override
  Future<CloudResult<CloudSaveMeta>> upload(
    CloudSaveUploadRequest request,
  ) async {
    final fault = _checkFault<CloudSaveMeta>();
    if (fault != null) return fault;

    final latest = _latestDownload();
    final currentRevision = latest?.meta.revision ?? 0;

    if (request.expectedBaseRevision != currentRevision) {
      return CloudRejected<CloudSaveMeta>(
        code: 'revision_conflict',
        message:
            'Revisi dasar ${request.expectedBaseRevision} tidak cocok '
            'dengan revisi terbaru $currentRevision.',
        currentRevision: currentRevision,
        isConflict: true,
      );
    }

    if (request.newRevision != currentRevision + 1) {
      return CloudRejected<CloudSaveMeta>(
        code: 'invalid_revision',
        message:
            'newRevision harus ${currentRevision + 1} (diterima ${request.newRevision}).',
        currentRevision: currentRevision,
      );
    }

    if (request.blob.isEmpty || request.blob.length > maxBlobBytes) {
      return const CloudRejected<CloudSaveMeta>(
        code: 'blob_size_out_of_range',
        message: 'Ukuran blob harus > 0 dan <= $maxBlobBytes byte.',
      );
    }

    if (request.blob.length != request.metrics.blobBytes) {
      return const CloudRejected<CloudSaveMeta>(
        code: 'blob_bytes_mismatch',
        message: 'blobBytes tidak sama dengan panjang payload blob.',
      );
    }

    final customRejection = uploadValidatorHook?.call(request, latest?.meta);
    if (customRejection != null) {
      return customRejection;
    }

    final targetSlot = request.targetSlot;
    final meta = CloudSaveMeta(
      revision: request.newRevision,
      slot: targetSlot,
      savedAtServerMs: _serverNowMs(),
      deviceId: request.deviceId,
      appVersion: request.appVersion,
      metrics: request.metrics,
    );
    _slots[targetSlot] = CloudSaveDownload(
      meta: meta,
      blob: Uint8List.fromList(request.blob),
    );
    return CloudSuccess(meta);
  }

  @override
  Future<CloudResult<int>> serverTimeMs() async {
    final fault = _checkFault<int>();
    if (fault != null) return fault;
    return CloudSuccess(_serverNowMs());
  }
}
