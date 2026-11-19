# AGENTS.md — Echoes of Aether

Panduan ini wajib diikuti oleh AI coding agents saat menganalisis, mengembangkan, memperbaiki, menguji, dan menyiapkan rilis proyek **Echoes of Aether**.

Dokumen ini menjadi aturan kerja proyek. Jika instruksi pengguna secara eksplisit berbeda dari aturan di sini, ikuti instruksi pengguna kecuali bertentangan dengan keamanan, integritas data, atau batasan teknis yang tidak dapat diabaikan. Jika terdapat konflik dengan dokumentasi desain atau implementasi aktual, jelaskan konflik tersebut dan minta keputusan bila berdampak pada desain game.

Aturan khusus milestone atau stage di prompt tugas melengkapi dokumen ini, tidak menggantikannya. Dokumen ini memuat aturan yang berlaku lintas milestone; status terkini proyek ada di tracker (lihat bagian 2.1), bukan di sini.

## 1. Identitas dan Prinsip Proyek

Echoes of Aether adalah **2D Top-down Pixel Art Idle Dungeon RPG** dengan karakter utama tunggal yang dapat memilih class specialization.

Prinsip desain yang sudah ditetapkan:
- Combat berlangsung otomatis dan real-time.
- Pergerakan karakter sepenuhnya otomatis.
- Pemain menggunakan satu karakter dengan specialization, bukan karakter terpisah untuk setiap class.
- Dungeon menggunakan struktur room-based.
- MVP berorientasi single-player dan offline-first.
- Auto-revive mengikuti aturan game yang telah ditetapkan di Game Design Document.
- Batas offline reward maksimal 8 jam.
- Android menjadi platform prioritas; jangan menganggap dukungan platform lain sudah siap tanpa verifikasi.
- Aplikasi dikunci portrait. Pada tablet, konten berada di kolom tengah dengan lebar maksimal, bukan melar penuh layar.
- Cloud (M14) memakai Firebase paket Spark untuk cadangan, pemulihan, dan sinkronisasi, dengan validasi lewat Firestore Security Rules. Database lokal tetap sumber kebenaran, dan game harus berjalan penuh tanpa internet maupun tanpa Firebase.

Jangan mengubah keputusan desain inti secara diam-diam. Jika perubahan diperlukan, jelaskan alasan, dampak terhadap sistem yang sudah ada, alternatif, dan dokumentasi yang perlu diperbarui.

## 2. Alur Kerja Sebelum Coding

### 2.1 Pahami konteks terlebih dahulu

Sebelum mengubah kode:
1. Baca bagian relevan dari `AGENTS.md`.
2. Baca tracker terbaru: berkas `MILESTONE_STATUS_*.md` dengan versi tertinggi di folder dokumen. Isinya status milestone, blocker, baseline test dan analyze, dan versi schema database.
3. Baca prompt tugas, roadmap, dan addendum desain yang relevan: GDD dan TDD awal, addendum v1.1, v1.2, v1.3, serta roadmap M8–M11, M12–M14, dan M14.
4. Audit implementasi yang sudah ada sebelum menyimpulkan suatu fitur belum tersedia.

Folder dokumen aktual adalah `doc101/`. Periksa dulu; jangan membuat folder `docs/` baru atau berkas duplikat dengan nama yang hampir sama.

Prioritas dokumen: addendum terbaru lebih tinggi dari addendum lama, dan addendum lebih tinggi dari dokumen awal. Kode dan konfigurasi nyata menang atas dokumen; laporkan setiap selisih sebelum mengubah kode.

Jangan mengasumsikan status milestone hanya dari percakapan atau nama branch. Gunakan repository aktual, test, dan dokumentasi yang tersedia sebagai bukti.

### 2.2 Nyatakan asumsi dan rencana
- Nyatakan asumsi yang memengaruhi hasil.
- Jika permintaan memiliki beberapa interpretasi yang berbeda secara material, jelaskan pilihannya dan tanyakan bila perlu.
- Pilih solusi paling sederhana yang memenuhi kebutuhan.
- Untuk tugas multi-langkah, berikan rencana singkat dan kriteria keberhasilan yang dapat diverifikasi.
- Jangan memulai implementasi besar sebelum memahami dampak terhadap sistem yang sudah ada.

### 2.3 Perubahan terarah
- Ubah hanya bagian yang relevan dengan tugas.
- Jangan melakukan refactor besar, mengganti arsitektur, atau mengubah format file yang tidak terkait tanpa alasan kuat.
- Jangan menghapus fitur, komentar, konfigurasi, atau dead code lama hanya karena dianggap tidak diperlukan.
- Hapus hanya import, variabel, atau fungsi yang menjadi tidak terpakai akibat perubahan yang sedang dilakukan.
- Pertahankan gaya penulisan dan konvensi repository.
- Jangan menambahkan dependency, abstraksi, sistem, atau konfigurasi spekulatif yang tidak diperlukan.
- Jangan menutupi kegagalan dengan menonaktifkan test, mengurangi assertion, atau mengabaikan error.

## 3. Arsitektur dan Batas Tanggung Jawab

Stack dan pembagian tanggung jawab proyek:
- Flutter: aplikasi dan UI.
- Flame: rendering dan interaksi game.
- Riverpod: state management pada layer aplikasi/UI.
- Drift/SQLite: persistence lokal.
- JSON: static game configuration.
- Flame Audio: audio game jika sudah diintegrasikan.

Struktur konseptual:
- `presentation`: UI dan tampilan.
- `application`: koordinasi use case, controller, dan alur aplikasi.
- `domain`: aturan game, entity, value object, repository contract, dan domain service.
- `game`: rendering, komponen Flame, input, dan adapter gameplay.
- `data`: database, datasource, model persistence, dan repository implementation.

Aturan wajib:
1. Domain tidak boleh bergantung pada Flutter, Flame, Drift, atau `dart:io`.
2. Flame components bukan sumber authoritative untuk state atau aturan gameplay.
3. Damage calculation, reward calculation, progression, dan aturan penting game harus berada pada layer yang tepat, bukan tersebar di komponen visual.
4. UI menampilkan state dan mengirim intent; UI bukan sumber kebenaran data game.
5. Hindari circular dependency.
6. Gunakan repository interface yang sudah tersedia sebelum membuat interface baru.
7. Pisahkan static definitions dari player-owned/runtime state.
8. Hindari dua sumber kebenaran untuk data yang sama.
9. Jangan memindahkan aturan domain ke widget atau Flame component hanya demi kemudahan implementasi.
10. Jangan membuat Riverpod provider menerima update setiap frame. Gunakan event/command bridge atau pembaruan UI dengan frekuensi yang sesuai.

### 3.1 Simulasi game
- Fixed simulation timestep yang ditetapkan proyek adalah 50 ms (20 ticks per second).
- Cooldown gameplay berbasis tick harus menggunakan simulation ticks, bukan timer UI atau animation timer.
- Jangan memanggil render Flame secara manual untuk menjalankan simulasi.
- Pisahkan navigation grid dari visual tilemap.
- Pathfinding dan pemilihan posisi serang harus menghormati walkable cells, obstacle, collision, dan attack range.
- Active gameplay dan offline simulation memiliki mekanisme berbeda. Jangan menjalankan Flame ketika aplikasi tertutup.

## 4. Aturan Gameplay dan Integrasi Sistem

### 4.1 Sumber kebenaran stat karakter

Final stats harus dihitung melalui satu mekanisme terpusat berdasarkan sumber modifier yang valid:

`Base Stats + Equipment Modifiers + Specialization Modifiers + Passive Skill Modifiers`

- Jangan menambahkan modifier berulang kali ke final stats yang sudah dimodifikasi.
- Recalculation harus deterministik dan aman dipanggil berulang.
- Combat dan skill execution harus menggunakan final stats yang benar.
- Jika base stats, equipment, specialization, atau passive skill berubah, hitung ulang dengan mekanisme yang sama.
- Jangan menyimpan derived stats sebagai sumber kebenaran jika dapat direkonstruksi dari state dasar dan modifier.

### 4.2 Combat dan reward
- Combat simulation menjadi sumber event gameplay yang relevan, bukan pengelola langsung seluruh inventory atau UI.
- Satu kematian monster hanya boleh menghasilkan satu reward event.
- Reward processing harus idempotent atau memiliki perlindungan duplicate processing.
- EXP, gold, loot, dan dungeon rewards harus mengikuti konfigurasi dan aturan domain.
- Gunakan deterministic random source pada unit test untuk sistem probabilistik seperti loot.
- Jangan mengubah formula damage, target priority, skill priority, revive, atau reward tanpa memeriksa GDD/TDD.

### 4.3 Player state dan persistence
- Simpan player-owned state, bukan menyalin static game definitions ke database.
- Gunakan transaksi untuk operasi multi-data yang harus konsisten.
- Hindari negative gold, negative quantity, invalid equipment reference, duplicate item, dan duplicate reward.
- Save tidak boleh dijalankan setiap frame.
- Load harus merekonstruksi runtime state dan derived stats tanpa menggandakan modifier.
- Migration harus aman dan tidak boleh mereset data pemain secara otomatis saat gagal.
- Offline reward maksimal 8 jam sesuai desain.
- Tangani timestamp negatif/tidak valid/masa depan secara eksplisit.
- Jangan mengklaim anti-cheat sempurna untuk game offline lokal.

## 5. Aturan Sistem Lanjutan (sejak M8)

### 5.1 Disiplin tugas
- Kerjakan satu stage atau satu tugas per sesi. Berhenti di akhir dan lapor; jangan memulai stage berikutnya.
- Tandai milestone `READY FOR REVIEW`, bukan `COMPLETED`, sampai pemilik project menyetujui.
- Perbarui tracker (checklist, Development Log, blocker, technical debt) di akhir setiap tugas.
- Jika uji perangkat tidak dapat dijalankan, nyatakan dengan jelas dan catat sebagai blocker terbuka.

### 5.2 Paritas online dan offline
Jalur online (`CombatSystem`/`CombatSimulation`) dan offline (`OfflineDungeonRunner`) adalah dua implementasi. Setiap perubahan pada combat, stat, reward, difficulty, atau drop wajib diterapkan di kedua jalur dan dibuktikan dengan test paritas.

### 5.3 Waktu dan acak
- Waktu disuntikkan lewat `GameClock`; periode memakai `PeriodService`, dan jam dijaga `ClockGuard`. Jangan memanggil `DateTime.now()` langsung di logika game.
- `Random` disuntikkan dan deterministik pada test.

### 5.4 Hadiah, pembelian, dan mata uang
- Semua pemberian hadiah, pembelian, dan perubahan mata uang bersifat idempotent (id klaim) dan atomik: validasi seluruh kondisi sebelum mutasi, satu transaksi, dan kegagalan tidak meninggalkan efek samping.
- Hadiah periodik (quest, boss, event shop) dihitung dari kunci periode, bukan dari kondisi UI.

### 5.5 Schema dan migrasi
- Setiap perubahan schema memakai migrasi bertahap (`from < N`) dalam satu transaksi, dengan test migrasi dari SETIAP versi lama berisi data nyata dan catatan breaking change.
- Versi schema saat ini ada di `app_database.dart` dan tracker; jangan mengandalkan angka dari dokumen lama.

### 5.6 Balancing
- Angka balancing berada di JSON konfigurasi dan divalidasi, bukan konstanta di kode.
- Setiap perubahan angka dicatat: nilai lama, nilai baru, alasan, dan bukti simulasi.
- Jangan melonggarkan target atau vektor uji agar test lulus. Jika target tidak tercapai, laporkan sebagai selisih.

### 5.7 Konten berbasis data
- Dungeon, monster, boss, item, dan shop didefinisikan lewat JSON. Jangan meng-hardcode id konten di logika.
- Saat menambah nilai pada enum yang dipakai di banyak tempat (misalnya `DungeonKind`), perbarui semua `switch` dan percabangan terkait.

### 5.8 Platform cloud
- Firebase paket Spark saja. Jangan menambah Cloud Functions, App Check, atau paket Blaze tanpa persetujuan eksplisit.
- Pemulihan save dari cloud tidak pernah otomatis: selalu atas konfirmasi pemain dan dengan cadangan lokal terlebih dahulu.
- Agent tidak men-deploy ke Firebase; siapkan berkas dan perintahnya untuk pemilik.

## 6. Coding Standards dan Konfigurasi

- Ikuti lint rules dan format yang sudah digunakan repository.
- Gunakan `dart format` pada file Dart yang berubah.
- Hindari hardcoded gameplay values jika nilai tersebut merupakan konfigurasi desain yang perlu diseimbangkan.
- Static configuration harus divalidasi saat dimuat.
- Tangani missing ID, duplicate ID, invalid range, dan referensi konfigurasi yang tidak ditemukan.
- Jangan menelan exception tanpa logging atau error handling yang sesuai.
- Jangan menggunakan `dynamic` secara luas untuk menghindari pemodelan tipe.
- Hindari dependency baru jika standard library atau dependency yang sudah tersedia cukup.
- Jangan mengubah versi Flutter/Dart, Gradle, Kotlin, Android Gradle Plugin, atau package besar tanpa alasan teknis dan penjelasan dampak. Dependensi atau plugin yang disetujui tertulis di prompt tugas (misalnya plugin Firebase) boleh ditambahkan dengan penjelasan dampak, termasuk perubahan `minSdk`.
- Dependensi baru hanya jika disetujui tertulis di prompt tugas.

## 7. Testing dan Kriteria Sukses

Sebelum menyatakan tugas selesai:
1. Jalankan test terkait sebelum perubahan jika memungkinkan.
2. Tambahkan test yang mereproduksi bug jika tugasnya perbaikan bug dan hal itu wajar.
3. Jalankan `dart format` pada file yang berubah.
4. Jalankan `flutter analyze`.
5. Jalankan `flutter test` atau test terarah selama iterasi.
6. Jalankan regression tests yang relevan.
7. Untuk perubahan build/platform, jalankan build atau uji perangkat jika lingkungan mendukung.
8. Baseline: jumlah test dan hasil analyze terakhir di tracker harus tetap terpenuhi. Jika terpaksa mengubah test lama, daftarkan tiap perubahan dan alasannya di laporan.

Jangan mengklaim test/build berhasil jika belum dijalankan.

Jika perintah gagal:
- Sertakan perintah yang dijalankan.
- Sertakan error penting yang relevan.
- Bedakan error kode dari masalah environment, emulator, Gradle, atau tooling.
- Jangan mengubah banyak hal secara spekulatif untuk menghilangkan error.

Untuk fitur game, prioritaskan unit test domain dan application. Tambahkan integration test untuk alur lintas sistem dan game-level test bila relevan.

## 8. Database, Keamanan, dan Data Pemain

Area sensitif proyek meliputi:
- Drift/SQLite schema dan migration.
- Save/load dan recovery.
- Inventory, equipment, gold, EXP, loot, dan reward transaction.
- File konfigurasi yang memengaruhi progression.
- Secret, signing key, keystore, API key, token, dan credential.
- Build/release workflow.

Aturan:
- Jangan hardcode secret, API key, token, atau credential.
- Jangan membaca, menampilkan, atau meng-commit `key.properties`, `*.jks`, `*.keystore`, atau kata sandi. `google-services.json` diletakkan pemilik project; jangan membuat atau mengubah isinya, dan jangan di-commit kecuali pemilik menyetujui.
- Jangan commit `.env`, keystore, credential, atau file rahasia.
- Jangan menghapus atau mereset save pemain sebagai solusi default. Pengecualian: pemulihan dari cloud atas konfirmasi pemain dengan cadangan lokal.
- Jangan melonggarkan validasi data atau constraint database tanpa alasan dan persetujuan yang sesuai.
- Perubahan schema wajib memiliki migration yang aman dan test.
- Perubahan reward/economy wajib memeriksa kemungkinan duplikasi, exploit tidak sengaja, dan kehilangan data.
- Jika perubahan berisiko merusak save pemain atau memerlukan keputusan desain/economy yang belum ditetapkan, berhenti dan jelaskan risiko sebelum implementasi.
- Jangan mengklaim bahwa penyimpanan lokal kebal dari manipulasi perangkat atau perubahan jam sistem.

## 9. Versioning, Changelog, dan Dokumentasi

### 9.1 Versioning
- Jangan bump versi aplikasi untuk setiap iterasi lokal, eksperimen, atau commit internal.
- Bump versi ketika menyiapkan rilis, ketika pengguna meminta, atau ketika workflow proyek mensyaratkannya.
- Ikuti format versi yang sudah digunakan di `pubspec.yaml`: `X.Y.Z+BUILD`.
- Naikkan build number untuk setiap build rilis baru.
- Gunakan semantic versioning secara konsisten:
  - Major: perubahan fundamental atau breaking change.
  - Minor: fitur baru yang kompatibel.
  - Patch: bug fix dan perbaikan kecil.
- Jangan mengarang nomor versi; periksa versi aktual terlebih dahulu.

### 9.2 Changelog dan docs
Jika perubahan merupakan fitur, perbaikan, atau perubahan desain yang bermakna:
- Perbarui `CHANGELOG.md` jika file tersebut tersedia atau telah ditetapkan sebagai bagian workflow proyek.
- Gunakan format Keep a Changelog dengan kategori `Added`, `Changed`, `Fixed`, dan `Removed`.
- Bahasa changelog mengikuti konvensi file yang sudah ada; jika belum ada, gunakan Bahasa Inggris.
- Perbarui dokumen desain/teknis/roadmap yang terdampak.
- Perbarui tracker terbaru (`MILESTONE_STATUS_*.md` dengan versi tertinggi) berdasarkan hasil yang benar-benar diverifikasi.
- Jangan menandai milestone/phase selesai hanya karena kode sudah ditulis; gunakan acceptance criteria dan test.

Dokumentasi berada di folder dokumen (`doc101/`): GDD dan TDD awal, addendum desain, roadmap per rentang milestone, tracker `MILESTONE_STATUS_*.md`, dan `PROGRESS_REPORT_TEMPLATE.md`.

Jika file atau struktur dokumentasi aktual berbeda, audit terlebih dahulu dan jangan membuat duplikat dengan nama yang hampir sama.

## 10. Git dan Release Safety

- **AI agent dilarang menjalankan `git push` (termasuk `git push --force`) dalam kondisi apa pun.** Hanya pengguna yang boleh menjalankan `git push` secara manual.
- Jangan melakukan destructive Git operation seperti `reset --hard`, menghapus branch, atau menghapus perubahan lokal tanpa persetujuan eksplisit.
- Jangan membuat commit atas nama pengguna kecuali diminta.
- Sebelum perubahan besar, periksa status Git agar perubahan pengguna yang belum di-commit tidak tertimpa.
- Jangan mengubah workflow release atau signing configuration tanpa menjelaskan dampaknya.
- Jangan men-deploy ke layanan eksternal (misalnya Firebase). Siapkan berkas dan perintahnya agar pemilik yang menjalankan.
- Jika push ke branch utama memicu build/release otomatis, beri tahu pengguna sebelum tindakan tersebut.

## 11. Aturan UI dan Asset

- Pertahankan identitas visual fantasy pixel-art Echoes of Aether.
- Gunakan pixel density dan skala aset yang konsisten.
- Pixel art harus menggunakan nearest-neighbor scaling; hindari blur/anti-aliasing yang merusak pixel edges.
- Jangan membuat aset final sebagai syarat untuk melanjutkan logic jika placeholder cukup.
- Jangan mengganti atau menghapus aset yang ada tanpa memeriksa referensi penggunaannya.
- UI Flutter dan visual game Flame harus memiliki batas tanggung jawab yang jelas.
- Jangan menambahkan UI atau fitur kosmetik di luar scope tugas tanpa persetujuan.
- Pemilik project merancang tampilan sendiri. Untuk fitur baru, buat UI fungsional minimal (daftar, tombol, teks status) di berkas widget terpisah. Jangan membuat sistem tema, mengubah navigasi, atau me-restyle layar yang ada kecuali diminta.
- Jangan mengarang aset, font, atau lisensi pihak ketiga. Catat sumber/lisensi jika menggunakan aset eksternal.

## 12. Fitur yang Ditunda

Kecuali pengguna secara eksplisit mengubah prioritas, jangan memasukkan fitur berikut ke milestone inti yang sedang dikerjakan:
- Multiplayer real-time.
- Guild.
- PvP.
- Trading/player marketplace.
- Gacha.
- Procedural dungeon generation.
- Pet system.
- Complex crafting.
- Multiple playable characters.
- Progres yang bergantung server (server-authoritative), Cloud Functions, App Check, dan paket Blaze. Cloud backup dan sinkronisasi dengan Firebase Spark diizinkan hanya dalam lingkup milestone M14.
- Social features.

Fitur-fitur tersebut dapat dipertimbangkan setelah MVP stabil dan pengguna menyetujuinya.

## 13. Format Laporan Setelah Tugas

Gunakan format `PROGRESS_REPORT_TEMPLATE.md` (di folder dokumen) sebagai format laporan utama. Isinya sudah mencakup audit awal, pekerjaan selesai, file diubah, test (baru dan lama yang diubah), analyzer, verifikasi perangkat, angka balancing, konflik desain, technical debt, dan pembaruan tracker.

Aturan tambahan:
- Bedakan dengan jelas **IMPLEMENTED** (kode ada), **TESTED** (test lulus), dan **VERIFIED** (dijalankan di perangkat atau simulasi). Jangan menyatakan tugas selesai jika kriteria sukses belum terpenuhi.
- Laporkan hasil perintah yang benar-benar dijalankan, bukan perkiraan.
- Rekomendasi langkah berikutnya hanya yang sesuai roadmap.

## 14. Prinsip Akhir

Utamakan:
1. Integritas data pemain.
2. Konsistensi aturan gameplay.
3. Arsitektur yang jelas dan mudah diuji.
4. Perubahan minimal dan terarah.
5. Test dan bukti sebelum klaim selesai.
6. Dokumentasi yang sinkron.
7. Keputusan desain tetap berada pada pengguna.

**Jangan mengejar banyaknya kode atau fitur. Bangun sistem yang konsisten, dapat diuji, dan sesuai dengan desain Echoes of Aether.**
