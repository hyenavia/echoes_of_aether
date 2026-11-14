# AGENTS.md — Echoes of Aether

Panduan ini wajib diikuti oleh AI coding agents saat menganalisis, mengembangkan, memperbaiki, menguji, dan menyiapkan rilis proyek **Echoes of Aether**.

Dokumen ini menjadi aturan kerja proyek. Jika instruksi pengguna secara eksplisit berbeda dari aturan di sini, ikuti instruksi pengguna kecuali bertentangan dengan keamanan, integritas data, atau batasan teknis yang tidak dapat diabaikan. Jika terdapat konflik dengan dokumentasi desain atau implementasi aktual, jelaskan konflik tersebut dan minta keputusan bila berdampak pada desain game.

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

Jangan mengubah keputusan desain inti secara diam-diam. Jika perubahan diperlukan, jelaskan alasan, dampak terhadap sistem yang sudah ada, alternatif, dan dokumentasi yang perlu diperbarui.

## 2. Alur Kerja Sebelum Coding

### 2.1 Pahami konteks terlebih dahulu

Sebelum mengubah kode:
1. Baca bagian relevan dari `AGENTS.md`.
2. Periksa `docs/GAME_DESIGN_DOCUMENT.md`.
3. Periksa `docs/TECHNICAL_DESIGN_DOCUMENT.md`.
4. Periksa `docs/MASTER_DEVELOPMENT_ROADMAP.md`.
5. Periksa `docs/MILESTONE_STATUS.md`.
6. Audit implementasi yang sudah ada sebelum menyimpulkan suatu fitur belum tersedia.

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
1. Domain tidak boleh bergantung pada Flutter atau Flame.
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

## 5. Panduan Milestone 5 — Dungeon System

Milestone 5 berfokus pada implementasi dungeon room-based dan integrasinya dengan combat serta progression yang telah dibuat.

### 5.1 Desain yang sudah ditetapkan
- Dungeon menggunakan room-based structure.
- MVP memakai jalur linear; data model boleh mendukung graph/branch di masa depan, tetapi jangan membangun branching gameplay sebelum diminta.
- Biome pertama: **Forgotten Forest**.
- Urutan room MVP:
  1. Forest Entrance
  2. Ancient Path
  3. Ruined Shrine
  4. Hidden Chamber
  5. Ancient Heart
- Monster MVP:
  - Aether Slime
  - Forest Wolf
  - Corrupted Treant
  - Corrupted Guardian (elite)
  - Ancient Heart Guardian (boss)

### 5.2 Tanggung jawab dungeon system

Audit dan implementasikan sesuai kebutuhan:
- Dungeon definitions dan room definitions berbasis konfigurasi.
- Dungeon start dan session state.
- Room loading dan room lifecycle.
- Spawn configuration dan spawn points.
- Room completion conditions.
- Room transition.
- Elite encounter.
- Boss encounter.
- Dungeon completion.
- Reward handoff ke progression/reward system.
- Penanganan player downed, revive, dan run ended sesuai aturan yang sudah ditetapkan.
- Save/resume behavior jika didukung desain dan persistence saat ini.

Room configuration sebaiknya memuat data yang dibutuhkan seperti ID, map configuration, entry/exit positions, spawn configuration, completion condition, dan reward reference. Sesuaikan dengan model yang sudah ada; jangan membuat duplikasi schema.

### 5.3 Aturan implementasi Milestone 5
- Audit kode M1–M4 terlebih dahulu.
- Gunakan sistem combat, reward, inventory, equipment, stats, dan persistence yang sudah ada.
- Jangan mengimplementasikan ulang sistem yang sudah stabil.
- Jangan mengikat dungeon progression ke widget atau Flame component.
- Dungeon manager/orchestrator mengoordinasikan alur; aturan domain tetap berada di domain/application.
- Jangan membuat procedural dungeon, multiplayer, guild, PvP, trading, gacha, atau online sync sebagai bagian milestone ini kecuali diminta secara eksplisit.
- Jangan menambahkan biome lain sebelum Forgotten Forest MVP selesai dan diverifikasi.
- Jangan menambahkan monster baru di luar scope MVP tanpa persetujuan.
- Pastikan satu room completion dan satu dungeon completion tidak dapat diproses dua kali.
- Pastikan transisi room tidak menggandakan spawn, reward, atau event listener.
- Tangani kondisi aplikasi ditutup atau dipulihkan sesuai kemampuan save/session design yang sudah disepakati.

### 5.4 Acceptance criteria Milestone 5

Milestone 5 belum boleh dinyatakan selesai sebelum hal-hal berikut diverifikasi:
- Dungeon dapat dimulai.
- Room yang tepat dapat dimuat.
- Spawn configuration bekerja.
- Room completion condition bekerja.
- Transisi antar-room bekerja.
- Elite encounter dapat dijalankan.
- Boss encounter dapat dijalankan.
- Dungeon completion dan reward berjalan satu kali.
- Kematian/revive/run-ended mengikuti aturan game.
- Integrasi combat dan progression tidak mengalami regresi.
- State dungeon yang perlu dipersistenkan konsisten.
- Test domain/application/data/game yang relevan lulus.
- `flutter analyze` lulus tanpa issue baru yang tidak dijelaskan.

Jika sebagian acceptance criteria belum termasuk implementasi milestone berdasarkan roadmap aktual, tandai secara eksplisit sebagai belum dikerjakan; jangan menyatakan selesai berdasarkan asumsi.

## 6. Coding Standards dan Konfigurasi

- Ikuti lint rules dan format yang sudah digunakan repository.
- Gunakan `dart format` pada file Dart yang berubah.
- Hindari hardcoded gameplay values jika nilai tersebut merupakan konfigurasi desain yang perlu diseimbangkan.
- Static configuration harus divalidasi saat dimuat.
- Tangani missing ID, duplicate ID, invalid range, dan referensi konfigurasi yang tidak ditemukan.
- Jangan menelan exception tanpa logging atau error handling yang sesuai.
- Jangan menggunakan `dynamic` secara luas untuk menghindari pemodelan tipe.
- Hindari dependency baru jika standard library atau dependency yang sudah tersedia cukup.
- Jangan mengubah versi Flutter/Dart, Gradle, Kotlin, Android Gradle Plugin, atau package besar tanpa alasan teknis dan penjelasan dampak.

## 7. Testing dan Kriteria Sukses

Sebelum menyatakan tugas selesai:
1. Jalankan test terkait sebelum perubahan jika memungkinkan.
2. Tambahkan test yang mereproduksi bug jika tugasnya perbaikan bug dan hal itu wajar.
3. Jalankan `dart format` pada file yang berubah.
4. Jalankan `flutter analyze`.
5. Jalankan `flutter test` atau test terarah selama iterasi.
6. Jalankan regression tests yang relevan.
7. Untuk perubahan build/platform, jalankan build atau uji perangkat jika lingkungan mendukung.

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
- Jangan commit `.env`, keystore, credential, atau file rahasia.
- Jangan menghapus atau mereset save pemain sebagai solusi default.
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
- Perbarui `docs/MILESTONE_STATUS.md` berdasarkan hasil yang benar-benar diverifikasi.
- Jangan menandai milestone/phase selesai hanya karena kode sudah ditulis; gunakan acceptance criteria dan test.

Dokumentasi utama:
- `docs/GAME_DESIGN_DOCUMENT.md`
- `docs/TECHNICAL_DESIGN_DOCUMENT.md`
- `docs/MASTER_DEVELOPMENT_ROADMAP.md`
- `docs/MILESTONE_STATUS.md`

Jika file atau struktur dokumentasi aktual berbeda, audit terlebih dahulu dan jangan membuat duplikat dengan nama yang hampir sama.

## 10. Git dan Release Safety

- **AI agent dilarang menjalankan `git push` (termasuk `git push --force`) dalam kondisi apa pun.** Hanya pengguna yang boleh menjalankan `git push` secara manual.
- Jangan melakukan destructive Git operation seperti `reset --hard`, menghapus branch, atau menghapus perubahan lokal tanpa persetujuan eksplisit.
- Jangan membuat commit atas nama pengguna kecuali diminta.
- Sebelum perubahan besar, periksa status Git agar perubahan pengguna yang belum di-commit tidak tertimpa.
- Jangan mengubah workflow release atau signing configuration tanpa menjelaskan dampaknya.
- Jika push ke branch utama memicu build/release otomatis, beri tahu pengguna sebelum tindakan tersebut.

## 11. Aturan UI dan Asset

- Pertahankan identitas visual fantasy pixel-art Echoes of Aether.
- Gunakan pixel density dan skala aset yang konsisten.
- Pixel art harus menggunakan nearest-neighbor scaling; hindari blur/anti-aliasing yang merusak pixel edges.
- Jangan membuat aset final sebagai syarat untuk melanjutkan logic jika placeholder cukup.
- Jangan mengganti atau menghapus aset yang ada tanpa memeriksa referensi penggunaannya.
- UI Flutter dan visual game Flame harus memiliki batas tanggung jawab yang jelas.
- Jangan menambahkan UI atau fitur kosmetik di luar scope tugas tanpa persetujuan.
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
- Online sync/server-dependent progression.
- Social features.

Fitur-fitur tersebut dapat dipertimbangkan setelah MVP stabil dan pengguna menyetujuinya.

## 13. Format Laporan Setelah Tugas

Setelah tugas selesai, berikan laporan ringkas namun dapat diverifikasi:
1. **Audit awal** — kondisi implementasi sebelum perubahan.
2. **Perubahan** — file yang dibuat/diubah dan alasannya.
3. **Implementasi** — perilaku atau sistem yang berhasil dibuat.
4. **Arsitektur** — dampak terhadap batas layer dan integrasi.
5. **Testing** — perintah yang dijalankan dan hasil aktual.
6. **Regression** — fitur lama yang diperiksa.
7. **Dokumentasi** — file dokumentasi yang diperbarui.
8. **Risiko/technical debt** — hal yang belum terselesaikan.
9. **Status** — selesai, sebagian selesai, atau terblokir.
10. **Langkah berikutnya** — hanya rekomendasi yang sesuai roadmap.

Jangan menyatakan tugas selesai jika kriteria sukses belum terpenuhi. Bedakan dengan jelas antara implementasi selesai, test lulus, build berhasil, dan pengujian manual di perangkat.

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
