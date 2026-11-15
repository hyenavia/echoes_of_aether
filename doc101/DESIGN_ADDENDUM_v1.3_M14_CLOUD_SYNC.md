# ECHOES OF AETHER

## DESIGN ADDENDUM v1.3 — M14: CLOUD SYNC (PAKET SPARK)

**Document Version:** 1.3-addendum
**Basis:** GDD/TDD + Addendum v1.1, v1.2; kondisi kode setelah M13 (Drift `schemaVersion = 7`, 682 test)
**Cakupan:** Akun, cadangan cloud, pemulihan, sinkronisasi, validasi dengan Firestore Security Rules, jam server
**Status:** Keputusan disepakati; siap diimplementasikan

Dokumen ini menggabungkan sisi perilaku (GDD) dan sisi teknis (TDD) karena M14 hampir seluruhnya tentang perilaku sistem.

---

# 0. KEPUTUSAN YANG DIKUNCI

| Topik | Keputusan |
|---|---|
| Paket Firebase | **Spark (gratis), tanpa Blaze, tanpa Cloud Functions** |
| Database | Cloud Firestore |
| Akun | Login anonim, lalu tautkan akun Google agar save bisa dipulihkan di perangkat lain |
| Sumber kebenaran | Database lokal (Drift). Game tetap jalan penuh tanpa internet dan tanpa Firebase. |
| Validasi | Firestore **Security Rules** pada metrik skalar, bukan pemeriksaan isi save |
| Sinkronisasi | Saat aplikasi dibuka, saat masuk latar belakang, setelah Ascension, dan tombol manual |
| App Check | Ditunda (tidak ada di M14) |
| Dependensi baru | `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`, `crypto` |

## 0.1 Model Keamanan yang Jujur

Tanpa server, Security Rules hanya dapat memeriksa **angka** yang dikirim klien. Rules tidak dapat membuka isi save.

| Jenis kecurangan | Tertangkap? |
|---|---|
| Mengedit database lokal (root, SQLite) lalu sinkronisasi dengan aplikasi asli | **Ya.** Aplikasi menghitung metrik dari save yang diedit, dan angka yang tidak wajar ditolak. |
| Memajukan jam perangkat untuk membuka quest lebih awal | **Terbatas.** Jam server dipakai bila online. Di cloud, kenaikan dibatasi oleh selisih waktu server. Secara lokal masih mungkin saat offline. |
| Aplikasi yang dimodifikasi dan berbohong tentang metrik | **Tidak.** |
| Isi inventory atau equipment yang dimanipulasi (tanpa mengubah metrik) | **Tidak.** |
| Upload pertama (belum ada pembanding) | **Tidak**, hanya batas mutlak. |

Tujuannya adalah mencegah kecurangan paling umum dan menjaga cloud sebagai catatan yang tidak bisa melompat. Ini bukan keamanan penuh. Bila suatu hari beralih ke Blaze, validator server dapat memakai metrik yang sama.

---

# 1. PERILAKU SISTEM

## 1.1 Akun

- Saat pertama kali tersambung, aplikasi membuat akun anonim otomatis.
- Pemain dapat menautkan akun Google di Pengaturan. Tanpa tautan, save cloud ikut hilang bila aplikasi di-uninstall.
- Jika akun Google yang dipilih sudah terhubung ke save lain, aplikasi masuk ke akun itu lalu menjalankan alur konflik (§1.5). Aplikasi tidak menggabungkan dua save.

## 1.2 Yang Disinkronkan

| Disinkronkan | Tidak disinkronkan |
|---|---|
| Karakter, skill, specialization, inventory, equipment | Pengaturan (volume, toggle notifikasi) |
| Progres dungeon, `CycleProgress`, mata uang, quest periodik, pembelian shop dan event shop | Sesi dungeon yang sedang berjalan |
| Id klaim yang permanen (`ascension:*`, `shop:*`, `bossquest:*`, `eventshop:*`) | Id klaim sementara (`offline_kill:*`, `room_clear:*`, `dungeon_clear:*`, `offline:*`) |
| `ClockState` (waktu terlihat tertinggi) | Jangkar dan mode offline (di-reset saat pemulihan) |

Alasan: data sementara hanya berguna untuk pemulihan crash di satu perangkat dan akan membengkakkan ukuran save.

## 1.3 Pemicu Sinkronisasi

| Pemicu | Syarat |
|---|---|
| Aplikasi dibuka | Setelah pemrosesan offline selesai |
| Aplikasi masuk latar belakang | Hanya jika ada perubahan |
| Setelah Ascension | Selalu |
| Tombol "Sinkronkan sekarang" | Selalu |

Sinkronisasi otomatis dibatasi satu kali per 5 menit (konfigurasi). Tombol manual dan Ascension mengabaikan batas itu. Unggahan hanya terjadi jika hash save berbeda dari yang terakhir tersinkron.

## 1.4 Status yang Terlihat Pemain

`Belum masuk akun`, `Tersinkron (waktu)`, `Ada perubahan belum tersinkron`, `Offline`, `Ditolak: (alasan)`, `Konflik`, `Menyinkronkan...`. Pengaturan menampilkan akun, waktu sinkron terakhir, dan alasan penolakan terakhir.

## 1.5 Konflik dan Pemulihan

Setiap save cloud punya nomor **revisi** yang naik terus. Aplikasi menyimpan `lastSyncedRevision`.

| Kondisi | Perilaku |
|---|---|
| Revisi cloud = `lastSyncedRevision`, lokal berubah | Unggah |
| Revisi cloud lebih baru, lokal tidak berubah | Tawarkan pemulihan (butuh konfirmasi, tidak pernah otomatis) |
| Revisi cloud lebih baru, lokal juga berubah (konflik) | Dialog: **Pulihkan dari cloud** (progres lokal dibuang) atau **Batal** (lanjut bermain lokal tanpa sinkronisasi) |
| Perangkat baru, belum ada save lokal berarti | Tawarkan pemulihan |

Cloud menolak save yang **lebih mundur** (angka monotonik turun), jadi tidak ada pilihan "timpa cloud dengan lokal yang lebih lama". Keputusan ini disengaja agar rollback tidak bisa dipakai sebagai celah.

Sebelum pemulihan, aplikasi menyimpan salinan save lokal ke tabel cadangan lokal (3 salinan terakhir), tanpa dependensi penyimpanan berkas. Pemulihan mengganti seluruh data pemain dalam satu transaksi, mengosongkan sesi dungeon aktif, menyetel jangkar offline ke waktu pemulihan (tanpa kredit offline untuk jeda), dan mempertahankan pengaturan lokal.

## 1.6 Penolakan

Jika Firestore menolak unggahan, game tetap berjalan lokal. Aplikasi menampilkan alasan yang dihitung di sisi klien (metrik mana yang melampaui batas, memakai fungsi batas yang sama dengan rules), tidak mengulang otomatis selama satu jam (konfigurasi), dan cloud tetap menyimpan save valid terakhir.

---

# 2. MODEL DATA FIRESTORE

## 2.1 Struktur

```
saves/{uid}/slots/{slot}        slot = "0" atau "1"
saves/{uid}/clock/ping          untuk jam server
```

Penulisan bergantian antar dua slot: revisi `r` ditulis ke slot `r % 2`. Revisi sebelumnya selalu tetap utuh di slot lain, sehingga satu unggahan yang buruk tidak menghilangkan save valid.

## 2.2 Dokumen Slot

| Field | Tipe | Keterangan |
|---|---|---|
| `revision` | int | `revisi sebelumnya + 1`; revisi pertama = 1 |
| `savedAt` | timestamp | harus sama dengan `request.time` |
| `schemaVersion`, `codecVersion` | int | tidak boleh turun |
| `deviceId`, `appVersion` | string | id acak instalasi |
| `level`, `gold`, `shards` | int | |
| `highestAscensionRank` | int | monotonik |
| `lifetimeClears` | int | jumlah `clearsCount` seluruh dungeon, monotonik |
| `dailyQuestDone`, `weeklyQuestDone` | int | banyak baris quest selesai, monotonik |
| `eventPurchasesLifetime` | int | monotonik |
| `equipmentCount` | int | |
| `blobBytes`, `blobSha256` | int, string | |
| `blob` | bytes | JSON kanonis terkompresi gzip |

Rules menolak field tambahan (`hasOnly`) dan tipe yang salah.

## 2.3 Aturan Validasi (ringkas)

Rules mengizinkan baca dan tulis hanya untuk pemilik (`request.auth.uid == uid`), tidak mengizinkan hapus, dan memvalidasi tiap penulisan terhadap slot lain (`prev`, revisi terbaru yang diterima), dengan `dt` = detik server sejak `prev.savedAt`.

**Mutlak (juga untuk unggahan pertama):** `level` ≤ `ABS_MAX_LEVEL`, `gold` dan `shards` dalam rentang, `highestAscensionRank` ≤ `ABS_MAX_RANK`, `blob.size()` ≤ 900.000 byte, `equipmentCount` ≤ kapasitas.

**Struktur dan monotonik:** `revision == prev.revision + 1`, slot = `revision % 2`, `savedAt == request.time`, `schemaVersion`/`codecVersion` tidak turun, serta `level`, `highestAscensionRank`, `lifetimeClears`, `dailyQuestDone`, `weeklyQuestDone`, `eventPurchasesLifetime` tidak turun.

**Periodik (eksak):**
- `dailyQuestDone − prev ≤ floor(dt / 86400) + 2`
- `weeklyQuestDone − prev ≤ floor(dt / 604800) + 2`
- `eventPurchasesLifetime − prev ≤ 2 × (floor(dt / 604800) + 2)`
- `0 ≤ shards ≤ DAILY_SHARD × dailyQuestDone + WEEKLY_SHARD × weeklyQuestDone` (nilai hadiah dari `boss_events.json`)

**Kontinu (plafon dengan faktor aman, dibangun dari simulator):** dengan `grace` = batas offline (8 jam) dan `SAFETY` = faktor aman,
- `rank − prev.rank ≤ floor(dt / MIN_CYCLE_SECONDS) + 1`
- `gold − prev.gold ≤ GOLD_PER_SEC(rank) × (dt + grace) × SAFETY + GOLD_BASE`
- `level − prev.level ≤ (EXP_PER_SEC(rank) × (dt + grace) × SAFETY) / (60 × prev.level^1.8) + 1`
- `lifetimeClears − prev ≤ (dt + grace) / MIN_RUN_SECONDS + 1`

`GOLD_PER_SEC`, `EXP_PER_SEC`, `MIN_CYCLE_SECONDS`, dan `MIN_RUN_SECONDS` dibangun oleh skrip dari keluaran simulator balancing (§3.3). `SAFETY` awal sengaja longgar (baseline 5) dan dikencangkan setelah data nyata terkumpul.

## 2.4 Jam Server

Klien menulis `saves/{uid}/clock/ping` dengan `t = serverTimestamp()` (rules: `t == request.time`, hanya field `t`), lalu membacanya dari server. Selisihnya dipakai sebagai `serverOffsetMs`. Jika offset melebihi toleransi (baseline 5 menit), `ClockGuard` memakai waktu server untuk periode quest, boss, dan event shop, dan offline progression dihitung dari waktu server selama online. Saat offline, jam perangkat tetap dipakai (dengan pengaman `ClockGuard` yang ada).

---

# 3. ARSITEKTUR KLIEN

## 3.1 Lapisan

| Lapisan | Komponen |
|---|---|
| Domain | `SaveSnapshotCodec` (snapshot ⇄ JSON kanonis), `SaveMetrics`, `CloudLimits` (fungsi batas, cermin rules), `SyncPlanner` (keputusan unggah/pulihkan/konflik, murni) |
| Application | `CloudSyncService` (orkestrasi, satu proses sekali jalan, backoff), `AccountService` |
| Data | `CloudSaveRepository` (interface) dengan implementasi Firestore dan implementasi memori untuk test, `CloudSyncStatesDao`, `replaceSnapshot` pada repository Drift |
| UI | Bagian Pengaturan minimal: akun, tautkan Google, sinkronkan sekarang, pulihkan, status |

Aplikasi harus berjalan normal jika Firebase gagal diinisialisasi atau perangkat tanpa Google Play services.

## 3.2 Persistensi (schema v8)

Tabel `CloudSyncStates`: `playerId` (PK), `deviceId`, `lastSyncedRevision` (default 0), `lastSyncedBlobSha256`, `lastSyncAtMs`, `lastRejectCode`, `lastRejectAtMs`, `serverOffsetMs`, `serverOffsetAtMs`. Tabel `LocalSaveBackups` (`id`, `createdAtMs`, `reason`, `schemaVersion`, `blobSha256`, `blob`) menyimpan cadangan sebelum pemulihan dan hanya mempertahankan 3 terakhir. Migrasi `from < 8` dalam satu transaksi, dengan test dari setiap versi lama.

## 3.3 Pembangkit Batas

Skrip `tool/export_cloud_limits.dart` membaca keluaran simulator balancing dan konfigurasi (`boss_events.json`, batas offline), lalu menghasilkan:
- `firebase/firestore.rules` (dari templat) dengan konstanta dan fungsi plafon,
- `firebase/limits.json`,
- `firebase/test_vectors.json` (kasus uji yang sama dipakai test Dart dan test rules).

Setiap titik data simulator yang sah harus berada di bawah plafon yang dihasilkan, dan ini diverifikasi oleh test.

## 3.4 Konfigurasi Firebase Android

- Aplikasi debug memakai `applicationIdSuffix = ".debug"`, jadi **dua** aplikasi Android didaftarkan di Firebase (rilis dan debug), masing-masing dengan sidik jari SHA kuncinya. `google-services.json` harus memuat keduanya.
- Plugin Gradle `com.google.gms.google-services` ditambahkan. Agent memeriksa `settings.gradle.kts` dan memastikan `minSdk` ≥ yang disyaratkan plugin Firebase terbaru.
- `google-services.json` bukan rahasia kriptografis, tetapi keamanan datanya bergantung sepenuhnya pada rules. Jangan menyimpan kunci service account di repository (tidak diperlukan di paket Spark).

---

# 4. KUOTA SPARK

Satu sinkronisasi ≈ 1 tulis + beberapa baca (termasuk `get()` di rules). Kuota gratis harian (sekitar 20 ribu tulis dan 50 ribu baca, bisa berubah) jauh di atas pemakaian beberapa pemain. Jika kuota habis, permintaan gagal sampai reset, tanpa tagihan. Cek halaman harga resmi untuk angka terbaru.

---

# 5. RISIKO

| Risiko | Mitigasi |
|---|---|
| Rules menolak pemain sah (plafon terlalu ketat) | `SAFETY` awal longgar (5), penolakan dilaporkan dengan alasan, dikencangkan bertahap |
| Rules dan fungsi Dart berbeda | Satu pembangkit dan satu set vektor uji untuk keduanya |
| Pemangkasan baris `PeriodicQuestStates` merusak metrik monotonik | Test bahwa tidak ada pemangkasan baris itu |
| Snapshot melebihi 1 MiB | Hanya data permanen disinkronkan, kompresi gzip, ukuran diukur dan dibatasi |
| Pemulihan merusak save lokal | Cadangan lokal otomatis, transaksi tunggal, validasi blob (hash, versi kodek) sebelum diterapkan |
| Aplikasi crash jika Firebase gagal | Inisialisasi toleran kegagalan, test tanpa Firebase |
| Divergensi dua perangkat | Cloud menolak mundur, pilihan pemulihan, tidak ada penggabungan |
| Unggahan pertama tidak terverifikasi | Batas mutlak; keterbatasan diterima |

# 6. ASUMSI YANG DAPAT DIUBAH

| ID | Asumsi |
|---|---|
| C-1 | Batas sinkronisasi otomatis 5 menit; jeda setelah penolakan 1 jam |
| C-2 | `SAFETY` awal 5 |
| C-3 | Toleransi jam server 5 menit |
| C-4 | Pemulihan menyetel jangkar offline ke waktu pemulihan |
| C-5 | Region Firestore terdekat (Jakarta jika tersedia) |
| C-6 | Tidak ada App Check dan tidak ada Cloud Functions |

# 7. DI LUAR LINGKUP

Cloud Functions, App Check, penggabungan dua save, leaderboard, sinkronisasi pengaturan, dan peningkatan ke validasi server.

**End of Addendum**
