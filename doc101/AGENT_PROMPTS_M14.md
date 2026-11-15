# ECHOES OF AETHER — PROMPT AI AGENT M14 (CLOUD SYNC, PAKET SPARK)

## CARA PAKAI

1. Letakkan dokumen ini di folder dokumen project: `DESIGN_ADDENDUM_v1.3_M14_CLOUD_SYNC.md`, `MASTER_DEVELOPMENT_ROADMAP_M14.md`, `MILESTONE_STATUS_M14.md`, dan file ini. Dokumen M8–M13 tetap dipakai. `PROGRESS_REPORT_TEMPLATE.md` tetap dipakai.
2. Untuk setiap sesi: tempel **ATURAN GLOBAL v3**, lalu **satu** prompt stage.
3. **Stage 0 dikerjakan olehmu** (bukan agent): ikuti checklist di `MASTER_DEVELOPMENT_ROADMAP_M14.md` bagian 2. Stage 1 boleh dimulai tanpa Stage 0. Stage 2 butuh Node.js dan JDK. Stage 3 butuh `google-services.json`.
4. Urutan wajib: Stage 1 → 2 → 3 → 4. Kirim laporan tiap stage kepadaku sebelum lanjut.
5. Agent **tidak dapat men-deploy** ke Firebase. Kamu yang menjalankan `firebase deploy --only firestore:rules` dari folder `firebase/` setelah test rules lulus.
6. Commit ke git setelah laporan sebuah stage kusetujui.

---

## ATURAN GLOBAL v3 (tempel di awal setiap sesi)

```text
Kamu adalah AI Agent yang mengembangkan game "Echoes of Aether" (Flutter, Flame, Riverpod, Drift/SQLite, Freezed). M1–M13 sudah selesai. Kamu sekarang mengerjakan M14 (Cloud Sync, paket Firebase Spark).

WAJIB DIBACA SEBELUM MENGERJAKAN APA PUN (di folder dokumen):
- DESIGN_ADDENDUM_v1.3_M14_CLOUD_SYNC.md
- MASTER_DEVELOPMENT_ROADMAP_M14.md dan MILESTONE_STATUS_M14.md
- GAME_DESIGN_ADDENDUM_v1.2.md, TECHNICAL_DESIGN_ADDENDUM_v1.2.md, serta dokumen M8–M11 dan awal
Prioritas: Addendum v1.3 > v1.2 > v1.1 > dokumen awal. Kode dan konfigurasi nyata menang atas dokumen; laporkan selisihnya.

ATURAN:
1. Kerjakan HANYA stage yang diminta. Berhenti di akhir stage dan buat laporan.
2. Audit repository dulu dan laporkan temuan yang berbeda dari dokumen sebelum mengubah kode.
3. Pertahankan fitur yang sudah berjalan. Jangan membangun ulang sistem yang bekerja.
4. Clean Architecture: Domain tidak bergantung pada Flutter, Flame, Drift, atau dart:io. Domain/Application adalah sumber kebenaran; UI hanya adapter.
5. Database lokal (Drift) adalah SUMBER KEBENARAN. Aplikasi harus berjalan penuh tanpa internet dan tanpa Firebase (inisialisasi gagal, tanpa Google Play services). Tidak ada jalur yang memblokir gameplay karena cloud.
6. Tidak ada Cloud Functions, App Check, atau paket Blaze. Validasi hanya lewat Firestore Security Rules dan fungsi batas di klien.
7. Tidak ada rahasia di repository: kunci service account, kata sandi, keystore, key.properties. Jangan membuat atau mengubah isi google-services.json (diletakkan pemilik project); tambahkan ke .gitignore kecuali pemilik menyetujui di-commit.
8. Kamu tidak dapat men-deploy ke Firebase. Siapkan berkas dan perintahnya; pemilik yang menjalankannya.
9. Tidak ada dependensi baru kecuali disetujui tertulis di prompt stage.
10. UI: hanya fungsional minimal, berkas widget terpisah, tanpa restyle layar yang ada. Tidak ada logika gameplay atau cloud di widget.
11. Pemulihan dari cloud TIDAK BOLEH terjadi otomatis atau diam-diam; selalu dengan konfirmasi pemain dan cadangan lokal terlebih dulu.
12. Perubahan schema: migrasi bertahap (from < N) dalam satu transaksi, test migrasi dari SETIAP versi lama berisi data nyata, catatan breaking change. Schema saat ini v7; verifikasi di app_database.dart.
13. Waktu disuntikkan (GameClock); jangan memanggil DateTime.now() langsung di logika.
14. Semua angka batas/balancing berada di konfigurasi atau hasil pembangkit, bukan konstanta tersebar di kode.
15. Test baseline: 682 test harus tetap hijau. Jika terpaksa mengubah test lama, daftarkan tiap perubahan dan alasannya.
16. Jalankan `flutter analyze` (target 0 issue) dan `flutter test` di akhir stage. Laporkan hasil nyata.
17. Bedakan di laporan: IMPLEMENTED, TESTED, VERIFIED. Jangan menandai Completed hanya karena kode ada.
18. Jangan mengubah desain inti. Jika menemukan konflik desain, BERHENTI, laporkan, dan minta keputusan.
19. Perbarui MILESTONE_STATUS_M14.md (checklist, Development Log, blockers, technical debt).
20. Akhiri dengan laporan sesuai format PROGRESS_REPORT_TEMPLATE.md.
```

---

# MILESTONE 14 — CLOUD SYNC

## M14 — Stage 1: Kodek, Metrik, Schema v8, dan Repository Cloud

```text
TUGAS: M14 Stage 1 — Kodek save, SaveMetrics, schema v8, replaceSnapshot, CloudSaveRepository (interface + memori), SyncPlanner. TANPA Firebase dan TANPA UI.
Rujukan: DESIGN_ADDENDUM_v1.3 §1, §2.2, §3.1, §3.2.

DEPENDENSI YANG DISETUJUI: crypto (untuk SHA-256). Gzip memakai dart:io HANYA di lapisan data, tidak di domain.

AUDIT DULU (laporkan sebelum mengubah kode):
- PlayerSaveSnapshot (lib/domain/entities/player_save_snapshot.dart) dan semua snapshot komponennya: PlayerCharacterSnapshot, InventorySnapshot, EquipmentInstance (termasuk stat persen M13), DungeonProgressSnapshot, CycleProgress, GameSessionSnapshot, OfflineActivitySnapshot, ActiveDungeonSessionSnapshot, EventShopPurchaseRecord, PeriodicQuestState, ClockState. Konfirmasi bahwa belum ada toJson/fromJson.
- DriftPlayerSaveRepository.saveSnapshot: apakah MENGGANTI total (menghapus baris yang tidak ada di snapshot, mis. item yang sudah dijual) atau hanya upsert? Ini menentukan desain replaceSnapshot. Tunjukkan kodenya.
- Seluruh format id di ClaimedRewards yang dibuat di kode (kill, room, dungeon, offline, shop, ascension, bossquest, eventshop, lainnya) dan klasifikasikan: PERMANEN (ascension:, shop:, bossquest:, eventshop:) vs SEMENTARA. Bandingkan dengan ClaimedRewardsPruner.
- Tabel GameSettings (dikecualikan dari sinkronisasi) dan apakah ada tabel pemain lain yang belum tercakup snapshot.
- Apakah baris PeriodicQuestStates pernah dihapus oleh kode mana pun (harus tidak, karena menjadi metrik monotonik).
- Kapasitas inventory (maxStackSlots, maxEquipmentCapacity) dan ukuran umum equipment instance.
- Pola test migrasi (database_all_versions_migration_test.dart).

KERJAKAN:
1. SaveSnapshotCodec (domain murni): snapshot -> Map JSON kanonis dan sebaliknya, codecVersion = 1. Hasil deterministik: kunci diurutkan, Set dan List diurutkan menurut kunci stabil. Disertakan/dikecualikan sesuai DESIGN §1.2: kecualikan activeDungeonSession, id klaim sementara, jangkar/mode offline, dan pengaturan; sertakan ClockState. Dokumentasikan daftar final di komentar kode dan laporan.
2. Decode ketat: codecVersion lebih baru dari yang didukung -> error bertipe; struktur salah, id item/dungeon/skill tidak dikenal oleh konfigurasi, nilai negatif, level < 1 -> error bertipe dan SELURUH blob ditolak (tanpa perbaikan sebagian).
3. SaveBlobPacker (lapisan data): JSON -> UTF-8 -> gzip -> bytes, plus SHA-256 hex. Verifikasi hash saat membuka.
4. SaveMetrics (domain murni): level, gold, shards (aether_shard), highestAscensionRank, lifetimeClears (jumlah clearsCount semua dungeon), dailyQuestDone dan weeklyQuestDone (jumlah baris PeriodicQuestStates per quest_id dari boss_events.json), eventPurchasesLifetime (jumlah seluruh pembelian event), equipmentCount (tas + terpasang), blobBytes, blobSha256, schemaVersion, codecVersion.
5. replaceSnapshot di repository Drift: SATU transaksi yang menghapus dan memasukkan ulang seluruh data pemain yang tercakup snapshot, TANPA menyentuh GameSettings; mengosongkan activeDungeonSession; menyetel jangkar offline ke restoredAtMs (parameter) dan mode offline ke pause; ClockState hasil = max(lastSeen terpulihkan, lastSeen lokal). Gagal di tengah = tidak ada perubahan.
6. Drift v8: tabel CloudSyncStates (playerId PK, deviceId, lastSyncedRevision default 0, lastSyncedBlobSha256, lastSyncAtMs, lastRejectCode, lastRejectAtMs, serverOffsetMs, serverOffsetAtMs) dan tabel LocalSaveBackups (id autoincrement, createdAtMs, reason, schemaVersion, blobSha256, blob bytes). LocalBackupService menyimpan cadangan sebelum pemulihan dan hanya mempertahankan 3 terakhir. Migrasi from < 8, naikkan schemaVersion ke 8. deviceId dibuat acak (Random.secure) saat pertama kali dibutuhkan.
7. CloudSaveRepository (interface di domain/application): latestMeta(), download(), upload(request), serverTimeMs(). Hasil bertipe sealed (sukses, ditolak, jaringan, butuh login, kuota). Sediakan implementasi memori yang meniru dua slot, revisi, dan hook untuk mensimulasikan penolakan, jaringan putus, dan konflik.
8. SyncPlanner (domain murni): masukan = state lokal (lastSyncedRevision, hash terakhir, hash saat ini, waktu sinkron terakhir), meta cloud, status login, jenis pemicu (buka, latar belakang, ascension, manual), batas 5 menit dan jeda penolakan 1 jam dari konfigurasi. Keluaran sealed: Upload, OfferRestore, Conflict, Skip(alasan), RequireSignIn. Aturan sesuai DESIGN §1.3 dan §1.5. Tambahkan blok konfigurasi "cloud" di game_config.json (auto_sync_min_interval_minutes, reject_backoff_minutes, server_time_tolerance_minutes) dengan parser dan validator.

TEST YANG HARUS DITAMBAH:
- Round-trip: snapshot kaya (semua field, banyak mata uang, equipment dengan stat persen, id klaim permanen dan sementara) -> encode -> decode menghasilkan JSON kanonis identik (kecuali bagian yang sengaja dikecualikan, buktikan).
- Determinisme: snapshot yang sama menghasilkan byte dan hash yang sama, tidak bergantung urutan Set/Map.
- Decode error: codecVersion terlalu baru, JSON rusak, id item tidak dikenal, hash tidak cocok.
- Ukuran: snapshot "berat" (kapasitas penuh, banyak progres dungeon, id klaim permanen realistis) -> laporkan byte mentah dan setelah gzip; harus jauh di bawah 900.000.
- replaceSnapshot: baris yang tidak ada di snapshot (mis. item terjual) terhapus; GameSettings utuh; sesi aktif kosong; jangkar offline = restoredAtMs; kegagalan di tengah tidak mengubah apa pun.
- SaveMetrics: nilai benar, termasuk lifetimeClears lintas dungeon dan hitungan quest.
- Migrasi dari v1, v2, v3, v4, v5, v6, v7 ke v8 dengan data nyata; instalasi baru.
- SyncPlanner: tabel keputusan lengkap (tidak ada perubahan, throttle, konflik, tawaran pemulihan, belum login, jeda penolakan, manual mengabaikan batas).
- Repository memori: revisi dan slot bergantian, penolakan, jaringan putus.
- Seluruh 682 test lama hijau.

JANGAN: menambah dependensi Firebase, memanggil jaringan, atau membuat UI.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md, termasuk temuan semantik saveSnapshot, daftar final disertakan/dikecualikan, dan ukuran blob.
```

## M14 — Stage 2: Security Rules, Pembangkit Batas, dan Test Rules

```text
TUGAS: M14 Stage 2 — Pembangkit batas, firestore.rules, fungsi batas Dart, dan test rules dengan emulator Firestore.
Rujukan: DESIGN_ADDENDUM_v1.3 §2, §3.3; roadmap M14 bagian 2.
Prasyarat: Node.js LTS dan JDK terpasang di mesin ini (checklist Stage 0 A). Jika tidak, BERHENTI dan laporkan.

DEPENDENSI YANG DISETUJUI (hanya untuk folder firebase/): paket npm @firebase/rules-unit-testing dan firebase (peer yang dibutuhkan), serta runner test bawaan Node (node --test). Firebase CLI dipakai dari instalasi global pemilik. Tidak ada dependensi Dart baru.

AUDIT DULU:
- Keluaran simulator balancing: tool/balance_report.dart (opsi --economy, --boss), test/balance, BalanceSimulator. Tentukan cara mendapatkan, per rank, pendapatan gold per detik dan EXP per detik MAKSIMAL yang sah (di semua dungeon, termasuk Ascension), waktu minimum sebuah run, dan waktu minimum satu siklus penuh.
- boss_events.json (nilai hadiah shard Daily dan Weekly, quest_id), batas offline, kurva EXP (expToNext), kapasitas inventory, konfigurasi "cloud" dari Stage 1.
- SaveMetrics dari Stage 1 sebagai definisi field slot.

KERJAKAN:
1. Folder firebase/ di root repo: firebase.json (rules + emulator Firestore), firestore.rules.template, firestore.rules (dihasilkan), firestore.indexes.json (kosong), package.json, test/, README.md (perintah menjalankan test emulator dan deploy untuk pemilik).
2. tool/export_cloud_limits.dart: membaca keluaran simulator dan konfigurasi, menghasilkan firestore.rules (dari templat), firebase/limits.json, dan firebase/test_vectors.json. Opsi --safety-factor (default 5) dan --check (gagal bila berkas hasil tidak mutakhir). Keluaran deterministik.
3. Fungsi plafon (bentuk tertutup, tanpa array/loop karena bahasa rules terbatas): GOLD_PER_SEC(rank) dan EXP_PER_SEC(rank) berbentuk A*pow(1 + B*rank, C), dicocokkan ke data simulator di rank {0, 1, 2, 5, 10, 20, 50} dan diskalakan sehingga SETIAP titik data sah berada di bawah fungsi pada semua rank sampel; ekstrapolasi di luar rentang sampel konservatif (monoton naik). Laporkan galat pencocokan dan margin di setiap titik. MIN_RUN_SECONDS dan MIN_CYCLE_SECONDS dari nilai minimum simulator dibagi faktor aman.
4. firestore.rules sesuai DESIGN §2.1–§2.4: akses hanya pemilik (request.auth.uid == uid); dokumen slot di saves/{uid}/slots/{slot}; tidak ada delete; hasOnly untuk field dan pemeriksaan tipe; savedAt == request.time; revisi == prev.revision + 1 dan slot == revisi % 2 (revisi pertama = 1 tanpa prev); batas mutlak (level, gold, shards, rank, ukuran blob <= 900000, equipmentCount); monotonik (level, highestAscensionRank, lifetimeClears, dailyQuestDone, weeklyQuestDone, eventPurchasesLifetime, schemaVersion, codecVersion tidak turun); periodik eksak (dailyQuestDone, weeklyQuestDone, eventPurchasesLifetime dibatasi oleh dt server, serta shards <= DAILY_SHARD*dailyQuestDone + WEEKLY_SHARD*weeklyQuestDone dan >= 0); kontinu (rank, gold, level, lifetimeClears) memakai plafon; dokumen saves/{uid}/clock/ping hanya boleh berisi t == request.time. Semua jalur lain ditolak. Perhatikan batas jumlah get() per permintaan dan ukuran rules.
5. CloudLimits (Dart, domain murni): fungsi yang sama untuk klien, plus explainViolation(prev, next, dtSeconds) yang mengembalikan daftar pelanggaran (nama metrik, nilai, batas) untuk pesan di UI.
6. test_vectors.json: kasus {nama, prev (atau null), next, dtSeconds, harapan: terima/tolak, alasan}. Wajib mencakup: save sah dari simulator pada rank 0, 1, 5, 10, 50; kasus mepet batas; kecurangan (gold x1000, lompatan level, rank +5 dalam semenit, shard melebihi rumus quest, dailyQuestDone +10 dalam satu jam, angka monotonik turun, field tambahan, tipe salah, blob terlalu besar, slot/revisi salah, savedAt tidak sama, unggahan pertama dengan nilai melampaui batas mutlak).
7. Test emulator (firebase/test/*.test.js): untuk tiap vektor, benihkan prev lewat withSecurityRulesDisabled dengan savedAt = sekarang - dtSeconds, lalu coba tulis next dengan serverTimestamp() sebagai pengguna terautentikasi. Tambahkan: tanpa login ditolak, uid lain ditolak, delete ditolak, list oleh bukan pemilik ditolak, ping jam dengan nilai salah ditolak. Jalankan dengan: firebase emulators:exec --only firestore "node --test" dari folder firebase/.
8. Test Dart: jalankan CloudLimits terhadap vektor yang SAMA dan pastikan keputusan identik dengan harapan.
9. Verifikasi bahwa semua keluaran simulator yang sah diterima pada SAFETY default dan laporkan headroom pada SAFETY 2.

JANGAN: men-deploy, mengubah logika game, atau memakai Cloud Functions. Jangan melonggarkan vektor kecurangan agar test lulus; jika rules tidak dapat mengekspresikan sebuah aturan, laporkan.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md, termasuk tabel galat pencocokan plafon dan hasil test emulator.
```

## M14 — Stage 3: Integrasi Klien

```text
TUGAS: M14 Stage 3 — Dependensi Firebase, akun, repository Firestore, CloudSyncService, jam server, dan UI Pengaturan minimal.
Rujukan: DESIGN_ADDENDUM_v1.3 §1, §2.4, §3.
Prasyarat: android/app/google-services.json sudah diletakkan pemilik (Stage 0). Jika tidak ada, BERHENTI dan laporkan.

DEPENDENSI YANG DISETUJUI: firebase_core, firebase_auth, cloud_firestore, google_sign_in (versi stabil terbaru yang kompatibel dengan Flutter/Dart project; laporkan versi yang dipilih). TIDAK: cloud_functions, firebase_app_check.

AUDIT DULU:
- pubspec.yaml; android/app/build.gradle.kts (nilai nyata flutter.minSdkVersion dan syarat minSdk plugin Firebase terbaru; applicationIdSuffix ".debug" pada build debug) dan android/settings.gradle.kts (blok plugins). Tinjau dokumentasi resmi paket yang dipilih, bukan ingatan.
- main.dart dan urutan inisialisasi; observer lifecycle tingkat aplikasi dari M12; SettingsOverlay; GameSessionCoordinator (titik setelah pemrosesan offline selesai, dan setelah Ascension); ClockGuard dan penyuntikan waktu.
- Layanan yang dibuat di Stage 1 dan 2 (codec, metrik, planner, CloudLimits, repository memori).

KERJAKAN:
1. Gradle: tambahkan plugin com.google.gms.google-services sesuai dokumentasi, dan pastikan minSdk memenuhi syarat plugin (jika perlu dinaikkan, gunakan maxOf(flutter.minSdkVersion, N) dan laporkan). Pertahankan logika release signing yang ada. Tambahkan google-services.json ke .gitignore (kecuali pemilik menyetujui sebaliknya).
2. Inisialisasi Firebase dengan try/catch dan batas waktu; jika gagal, status CloudUnavailable dan aplikasi berjalan normal. Jangan membuat firebase_options.dart jika google-services.json cukup di Android.
3. AccountService: masuk anonim secara lazy (saat pemicu sinkronisasi pertama atau pemain membuka bagian akun); tautkan Google (google_sign_in sesuai API versi terpilih; serverClientId = Web client ID dari pemilik, jangan di-hardcode di berkas yang tidak boleh publik — letakkan sebagai konfigurasi build/dart-define atau konstanta yang kamu laporkan untuk persetujuan); tangani credential-already-in-use dengan masuk ke akun itu dan menandai status konflik (save lokal TIDAK diunggah ke akun yang sudah ada secara otomatis); keluar akun tidak menghapus save lokal.
4. FirestoreCloudSaveRepository: baca kedua slot (sumber server) dan pilih revisi tertinggi; upload menulis slot revisi % 2 dengan field sesuai DESIGN §2.2 (blob sebagai Blob, savedAt = serverTimestamp); download memverifikasi SHA-256 dan ukuran; serverTimeMs lewat dokumen ping (tulis serverTimestamp lalu baca dari server, hitung offset dengan titik tengah waktu lokal). Petakan error: permission-denied -> ditolak, unavailable/deadline-exceeded -> jaringan, unauthenticated -> butuh login, resource-exhausted -> kuota.
5. CloudSyncService (application): pemicu = aplikasi dibuka (setelah offline progression), masuk latar belakang (hanya jika berubah), setelah Ascension, manual. Satu proses sekali jalan; batas 5 menit untuk otomatis; backoff untuk jaringan (1, 5, 30 menit); setelah penolakan tidak mengulang otomatis selama reject_backoff_minutes tetapi manual tetap boleh; hash tidak berubah = tidak mengunggah. Alur sesuai SyncPlanner. Pesan penolakan memakai CloudLimits.explainViolation. Setelah sukses perbarui CloudSyncStates.
6. Pemulihan (hanya atas konfirmasi pemain): unduh -> verifikasi hash dan codecVersion -> LocalBackupService menyimpan cadangan -> replaceSnapshot -> muat ulang state sesi di coordinator -> perbarui CloudSyncStates. Pemulihan DIBLOKIR dengan pesan jelas bila ada run dungeon aktif. Kegagalan di mana pun meninggalkan save lokal utuh.
7. Jam server: saat online ketika aplikasi dibuka, panggil serverTimeMs (batas 3 detik). Simpan offset. Jika |offset| melebihi server_time_tolerance_minutes, ClockGuard memakai waktu perangkat + offset untuk periode quest/boss/event shop, dan offline progression dihitung dari waktu efektif selama online. Jika offset kecil atau tidak online, perilaku lama tidak berubah. Dokumentasikan batasan: jam offline masih dapat dimanipulasi secara lokal.
8. UI minimal di bagian Pengaturan (berkas widget baru): status akun (belum masuk/anonim/Google), tombol Tautkan Google, Sinkronkan sekarang, Pulihkan dari cloud (dengan dialog konfirmasi dan peringatan), baris status (terakhir sinkron, belum tersinkron, offline, ditolak beserta alasan, konflik), dialog konflik (Pulihkan dari cloud / Batal) dan dialog tawaran pemulihan. Tidak ada logika di widget.
9. Hook debug-saja: --dart-define=FIREBASE_EMULATOR=true mengarahkan Auth dan Firestore ke emulator (host 10.0.2.2 untuk emulator Android). Harus nonaktif secara default dan tidak ada di jalur rilis.

TEST YANG HARUS DITAMBAH (memakai repository dan akun palsu, tanpa jaringan):
- Semua keputusan alur: unggah pertama, tidak ada perubahan, throttle, konflik, tawaran pemulihan, pemulihan sukses (data terganti, cadangan dibuat), pemulihan diblokir saat run aktif, penolakan (tanpa pengulangan otomatis tetapi manual jalan), jaringan putus dan backoff, butuh login, kuota habis.
- Aplikasi berjalan saat inisialisasi Firebase gagal dan saat offline; tidak ada pengecualian tak tertangani.
- AccountService: anonim, tautan sukses, credential-already-in-use.
- Jam server: offset kecil (perilaku lama), offset besar (waktu efektif dipakai), tidak online (perilaku lama), kombinasi dengan ClockGuard jam mundur.
- Widget test: status, dialog konfirmasi, dialog konflik; widget tidak menyimpan state gameplay.
- Seluruh test lama hijau; flutter build apk --debug berhasil.

JANGAN: Cloud Functions, App Check, mengubah rules, menyimpan rahasia, memulihkan otomatis, menyinkronkan pengaturan, atau me-restyle layar lain.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md, termasuk versi dependensi, diff Gradle, dan keputusan minSdk.
```

## M14 — Stage 4: QA dan Pengencangan

```text
TUGAS: M14 Stage 4 — QA otomatis dan emulator, daftar uji manual untuk pemilik, kuota, dan rencana pengencangan batas.
Rujukan: roadmap M14 Acceptance Criteria; DESIGN_ADDENDUM_v1.3 §4, §5.

AUDIT DULU:
- Hasil Stage 1–3, dan apakah Node.js dan JDK tersedia untuk menjalankan emulator Firebase (Auth dan Firestore).

KERJAKAN:
1. Jalankan seluruh suite: flutter analyze, flutter test, test rules emulator (firebase emulators:exec --only firestore "node --test"), dan dart run tool/export_cloud_limits.dart --check. Laporkan hasil nyata.
2. QA emulator Android dengan Firebase Emulator Suite (Auth dan Firestore) memakai --dart-define=FIREBASE_EMULATOR=true: (a) unggah pertama; (b) ubah save lokal lalu sinkron berikutnya; (c) pulihkan di instalasi bersih; (d) konflik dua instalasi (dua emulator atau dua data aplikasi); (e) mode pesawat lalu sinkron ulang; (f) TAMPER: ubah gold dan level di database lokal build debug (adb run-as atau alat debug yang sudah ada) lalu sinkronkan: harus ditolak dengan alasan yang benar, game lokal tetap jalan, dan cloud tetap menyimpan revisi valid terakhir; (g) shard melebihi rumus quest ditolak; (h) upgrade dari save M13 (database v7) ke v8 tanpa kehilangan data.
3. Verifikasi build rilis: flutter build apk --release (butuh key.properties milik pemilik; jika tidak tersedia, laporkan) tidak mengandung hook emulator aktif (dart-define default mati) dan aplikasi berjalan tanpa jaringan.
4. Estimasi kuota Spark: jumlah tulis dan baca per sinkronisasi (termasuk get() di rules dan ping jam) dan proyeksi untuk N pemain dengan pola pemakaian wajar; bandingkan dengan kuota gratis di halaman harga resmi (catat tanggal pengecekan; angka bisa berubah).
5. Pengencangan: jelaskan rencana menurunkan SAFETY dari 5 ke nilai lebih ketat secara bertahap berdasarkan data penolakan nyata. Jangan mengubah SAFETY default tanpa bukti. Sediakan perintah mengganti SAFETY dan men-deploy ulang (untuk pemilik).
6. Tulis DAFTAR UJI MANUAL untuk pemilik dengan Firebase nyata (setelah firebase deploy --only firestore:rules): login anonim, tautkan Google, sinkron, pulihkan di perangkat kedua, konflik, mode pesawat, dan cara mengamati penolakan.
7. Perbarui MILESTONE_STATUS_M14.md. Tandai M14 READY FOR REVIEW (bukan COMPLETED) sampai pemilik menjalankan uji dengan Firebase nyata dan menyetujui.

OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md, dengan hasil tiap skenario, tabel kuota, dan daftar uji manual.
```

---

**End of Document**
