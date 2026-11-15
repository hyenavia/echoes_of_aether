# ECHOES OF AETHER

## MASTER DEVELOPMENT ROADMAP — M14 (CLOUD SYNC, PAKET SPARK)

**Document Version:** 4.0-addendum
**Melanjutkan:** MASTER_DEVELOPMENT_ROADMAP_M12_M14 (M12–M13 selesai)
**Dokumen pendamping:** DESIGN_ADDENDUM_v1.3_M14_CLOUD_SYNC, MILESTONE_STATUS_M14, AGENT_PROMPTS_M14

Dokumen ini menggantikan garis besar M14 di roadmap M12–M14, yang mengasumsikan Cloud Functions dan paket Blaze.

---

# 1. ATURAN UMUM

Seluruh aturan roadmap sebelumnya tetap berlaku. Tambahan untuk M14:

1. Satu stage per task; agent berhenti dan melapor di akhir stage.
2. Baseline: 682 test hijau, `flutter analyze` 0 issue, Drift schema v7.
3. Aplikasi harus berjalan penuh tanpa internet dan tanpa Firebase.
4. Tidak ada Cloud Functions, App Check, atau paket Blaze.
5. Tidak ada rahasia di repository (service account, kata sandi, keystore).
6. Perubahan schema wajib punya test migrasi dari setiap versi lama dengan data nyata.
7. Dependensi baru hanya yang disetujui di prompt stage.
8. UI hanya fungsional minimal.
9. Agent tidak dapat men-deploy ke Firebase; pemilik project yang menjalankan perintah deploy.

---

# MILESTONE 14 — CLOUD SYNC

## Objective

Mencadangkan save ke cloud dengan akun pemain, memulihkannya di perangkat lain, dan menolak lonjakan angka yang tidak wajar lewat Security Rules, dengan database lokal tetap menjadi sumber kebenaran.

## Stage 0 — Persiapan Manual (dikerjakan pemilik project)

Checklist lengkap ada di bagian 2. Stage 1 boleh dimulai tanpa Stage 0 selesai, tetapi Stage 2 (pengujian emulator) dan Stage 3 membutuhkannya.

## Stage 1 — Kodek, Metrik, Schema v8, dan Repository Cloud (domain dan data)

- `SaveSnapshotCodec`, `SaveMetrics`, `replaceSnapshot`, `CloudSyncStates` dan `LocalSaveBackups` (v8), `CloudSaveRepository` (interface dan implementasi memori), `SyncPlanner`.

## Stage 2 — Security Rules, Pembangkit Batas, dan Test Rules

- `tool/export_cloud_limits.dart`, `firebase/firestore.rules`, vektor uji, test rules dengan emulator Firestore.

## Stage 3 — Integrasi Klien

- Dependensi Firebase, konfigurasi Gradle, inisialisasi toleran kegagalan, `AccountService`, implementasi Firestore, `CloudSyncService`, jam server, UI Pengaturan.

## Stage 4 — QA

- Dua perangkat, mode pesawat, save yang dimanipulasi, upgrade dari save M13, kuota, pengencangan batas.

## Acceptance Criteria

1. Snapshot dapat diekspor dan diimpor tanpa kehilangan data (round-trip), dengan versi kodek dan hash terverifikasi.
2. Pemulihan mengganti seluruh data dalam satu transaksi, membuat cadangan lokal, dan tidak menyentuh pengaturan.
3. Security Rules menolak: field tambahan atau salah tipe, revisi atau slot salah, angka monotonik yang turun, kenaikan quest/pembelian melampaui batas periodik, shard melebihi rumus quest, dan kenaikan kontinu melampaui plafon. Rules menerima save sah dari simulator pada semua rank yang diuji.
4. Fungsi batas Dart dan rules menghasilkan keputusan yang sama pada seluruh vektor uji.
5. Dua perangkat: konflik ditangani dengan dialog, tidak ada penimpaan diam-diam.
6. Penolakan server tidak menghentikan permainan lokal dan menampilkan alasan.
7. Aplikasi berjalan normal saat offline, saat Firebase tidak terinisialisasi, dan tanpa Google Play services.
8. Jam server dipakai bila online dan perbedaan melebihi toleransi.
9. Migrasi v1–v7 → v8 aman.
10. `flutter analyze` 0 issue; semua test hijau; APK debug dan rilis terverifikasi.

## Exit Condition

Pemain dapat mencadangkan dan memulihkan save di perangkat berbeda, save yang diedit secara kasar tidak dapat masuk ke cloud, dan game tetap berfungsi penuh tanpa koneksi.

---

# 2. CHECKLIST STAGE 0 (UNTUK PEMILIK PROJECT)

## A. Alat di komputer

- Node.js versi LTS terbaru dan npm.
- JDK sesuai syarat emulator Firebase di dokumentasi `firebase-tools` terbaru.
- `npm install -g firebase-tools`, lalu `firebase login`.
- (Opsional untuk konfigurasi otomatis) `dart pub global activate flutterfire_cli`.

## B. Project Firebase (paket Spark)

1. Buat project di Firebase Console. **Jangan** upgrade ke Blaze.
2. Tambahkan **dua** aplikasi Android:
   - Rilis: `com.hyenavia.echoes_of_aether`, SHA-1 `d47226e35bb1d92d410ae8c60f43c5d21926c10f` dan SHA-256 `281a298e125fba0da0efca4de3067590168023fb2657687c49b40ce1f48547a1`.
   - Debug: `com.hyenavia.echoes_of_aether.debug`, dengan SHA-1 dan SHA-256 kunci debug komputermu:
     ```
     keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
3. Authentication → aktifkan **Anonymous** dan **Google**. Salin *Web client ID* dari pengaturan penyedia Google.
4. Firestore Database → buat database dalam **production mode**. Pilih region terdekat (Jakarta, `asia-southeast2`, bila tersedia). Region tidak dapat diubah setelahnya.
5. Unduh `google-services.json` **setelah** kedua aplikasi didaftarkan, dan letakkan di `android/app/`.
6. Catat ID project Firebase.

## C. Yang diserahkan ke agent

Web client ID dan ID project (bukan kata sandi atau kunci pribadi).

## D. Setelah Stage 2

Jalankan `firebase deploy --only firestore:rules` dari folder `firebase/` setelah test rules lulus.

---

# 3. KETERGANTUNGAN

| Stage | Bergantung pada |
|---|---|
| 1 | M13 selesai |
| 2 | Stage 1, simulator balancing (M8–M13) |
| 3 | Stage 1–2, Stage 0 selesai |
| 4 | Stage 3 |

# 4. KONTROL SCOPE

Dikecualikan: Cloud Functions, App Check, Blaze, penggabungan dua save, leaderboard, sinkronisasi pengaturan, dan pekerjaan UI di luar bagian Pengaturan minimal.

**End of Document**
