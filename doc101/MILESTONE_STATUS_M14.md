# ECHOES OF AETHER

## MILESTONE STATUS TRACKER — M14 (CLOUD SYNC, PAKET SPARK)

**Project:** Echoes of Aether
**Document Version:** 4.0
**Last Updated:** 2026-11-15
**Current Milestone:** M14 — Cloud Sync (Stage 1 Tested / Stage 2 Pending)
**Overall Status:** M1–M13 Completed (verifikasi emulator); M14 Stage 1 Tested (unit/data tests), Stage 0/2–4 Pending

> Dokumen ini melanjutkan `MILESTONE_STATUS_M12_M14.md`. Simpan berdampingan di folder dokumen. Seluruh Update Rules sebelumnya tetap berlaku.

**Baseline saat ini:** `flutter test` = 708 lulus (682 baseline + 26 Stage 1), `flutter analyze` = 0 issue, Drift `schemaVersion = 8`.

---

# 1. M14 — CLOUD SYNC

**Status:** In Progress (Stage 1 Tested)

### Stage 0 — Persiapan Manual (pemilik project)
- [ ] Node.js, JDK, `firebase-tools`, `firebase login`
- [ ] Project Firebase (Spark) dibuat
- [ ] Dua aplikasi Android didaftarkan (rilis dan debug) dengan SHA
- [ ] Anonymous dan Google diaktifkan; Web client ID dicatat
- [ ] Firestore dibuat (production mode, region dipilih)
- [ ] `google-services.json` (memuat kedua aplikasi) diletakkan di `android/app/`

### Stage 1 — Kodek, Metrik, Schema v8, Repository Cloud
- [x] Audit `PlayerSaveSnapshot`, repository, dan daftar id klaim
- [x] `SaveSnapshotCodec` + daftar yang disertakan/dikecualikan
- [x] `SaveMetrics` (level, gold, shards, rank tertinggi, clears, quest selesai, pembelian event, jumlah equipment)
- [x] `replaceSnapshot` (transaksi tunggal) + cadangan lokal
- [x] Drift v8 `CloudSyncStates` dan `LocalSaveBackups` + test migrasi dari setiap versi lama
- [x] `CloudSaveRepository` (interface + memori) dan `SyncPlanner`
- [x] Ukur ukuran blob pada save besar
- [x] Test round-trip, hash, versi kodek, pemulihan

### Stage 2 — Security Rules dan Pembangkit Batas
- [ ] Audit keluaran simulator dan konfigurasi
- [ ] `tool/export_cloud_limits.dart` (rules, limits, vektor uji)
- [ ] `firebase/firestore.rules`, `firebase.json`
- [ ] Fungsi batas Dart (`CloudLimits`) dan test paritas dengan vektor uji
- [ ] Test rules emulator (terima dan tolak)
- [ ] Verifikasi plafon di atas semua data simulator

### Stage 3 — Integrasi Klien
- [ ] Persetujuan dependensi tercatat
- [ ] Gradle (plugin google-services, `minSdk`) dan inisialisasi toleran kegagalan
- [ ] `AccountService` (anonim, tautan Google, kasus akun sudah dipakai)
- [ ] Implementasi Firestore `CloudSaveRepository`
- [ ] `CloudSyncService` (pemicu, batas, backoff, penolakan)
- [ ] Jam server dan integrasi `ClockGuard`
- [ ] UI Pengaturan minimal (akun, sinkron, pulihkan, status)
- [ ] Dialog konflik dan konfirmasi pemulihan
- [ ] Test tanpa Firebase dan saat offline

### Stage 4 — QA
- [ ] Deploy rules (pemilik) dan uji terhadap Firestore sungguhan
- [ ] Dua perangkat (emulator dan HP): unggah, pulihkan, konflik
- [ ] Mode pesawat dan sinkronisasi ulang
- [ ] Save dimanipulasi ditolak dengan alasan
- [ ] Upgrade dari save M13
- [ ] Estimasi kuota Spark
- [ ] Pengencangan `SAFETY` bertahap
- [ ] `flutter analyze` 0 issue, seluruh test hijau, APK debug dan rilis terverifikasi

---

# 2. DEVELOPMENT LOG

| Tanggal | Stage | Catatan | Test | Analyze |
|---|---|---|---|---|
| 2026-11-15 | M14 Stage 1 | Tambah dependensi `crypto: ^3.0.8`; konfigurasi `"cloud"` (5/60/5) di `game_config.json`; `SaveSnapshotCodec` (v1 kanonis deterministik + validasi ketat), `SaveBlobPacker` (gzip `dart:io` + SHA-256), `SaveMetricsCalculator`, `DriftPlayerSaveRepository.replaceSnapshot`, `AppDatabase` v8 (`CloudSyncStates`, `LocalSaveBackups`, migrasi `v1..v7 -> v8`), `DriftCloudSyncStateRepository`, `LocalBackupService` (retensi 3 terbaru), `CloudSaveRepository` + `InMemoryCloudSaveRepository`, dan `SyncPlanner`. Ukuran blob berat (204 equipment, 284 klaim permanen, 120 quest, 5 dungeon): 86.941 byte mentah -> 5.100 byte gzip. 5 test lama disesuaikan ekspektasi `schemaVersion` (`7 -> 8`). | 708 lulus / 0 gagal (baseline 682 + 26 baru) | 0 issue |

# 3. BLOCKERS AND KNOWN ISSUES

| ID | Deskripsi | Stage | Status |
|---|---|---|---|
| B-M14-01 | Stage 0 (project Firebase Spark, `google-services.json`, SHA debug/release) belum dijalankan pemilik; sengaja belum memblokir Stage 1 offline/in-memory, namun dibutuhkan sebelum verifikasi device Stage 3/4. | Stage 0 / 3–4 | Open |

Item terbuka dari tracker sebelumnya: B-M12-01 (verifikasi pengiriman notifikasi dan perangkat fisik), TD-M12-01, TD-M12-03, TD-M12-04.

# 4. TECHNICAL DEBT

| ID | Deskripsi | Asal | Rencana |
|---|---|---|---|
| TD-M14-01 | `Inventory` di runtime saat ini (`GameSessionCoordinator`) masih menginisialisasi `maxStackSlots: null` & `maxEquipmentCapacity: null` (tanpa batas), berbeda dengan asumsi kapasitas terdefinisi di `DESIGN_ADDENDUM_v1.3 §2.2–§2.3`. Perlu keputusan kapasitas maksimum eksplisit pada Stage 2 saat menentukan batas rules Firestore. | Audit M14 Stage 1 | Evaluasi/putuskan bersama `tool/export_cloud_limits.dart` di Stage 2 |

# 5. CHANGE HISTORY

| Versi | Tanggal | Perubahan |
|---|---|---|
| 4.0 | | Dokumen M14 (Spark) dibuat |
| 4.1 | 2026-11-15 | M14 Stage 1 selesai (Tested): kodek, metrik, schema v8, `replaceSnapshot`, `LocalBackupService`, `InMemoryCloudSaveRepository`, `SyncPlanner` |

# 6. UPDATE RULES

1. Perbarui status dan checklist sesuai implementasi aktual.
2. Tambahkan catatan Development Log setiap stage.
3. Catat blockers dan technical debt.
4. Jangan menandai Completed sebelum acceptance criteria terverifikasi.
5. Catat setiap test lama yang diubah beserta alasannya.
6. Catat setiap migrasi schema dan perubahan angka batas beserta buktinya.

**End of Document**
