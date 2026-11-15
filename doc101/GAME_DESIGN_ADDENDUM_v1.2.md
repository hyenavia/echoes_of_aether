# ECHOES OF AETHER

## GAME DESIGN DOCUMENT — ADDENDUM v1.2 (M12–M14)

**Document Version:** 1.2-addendum
**Basis:** GAME_DESIGN_DOCUMENT v1.0 + GAME_DESIGN_ADDENDUM v1.1 (M8–M11, selesai)
**Cakupan:** Lapisan waktu, Aether Shard, Daily/Weekly Boss dan Quest, notifikasi, Weekly Event Shop, stat persentase, cloud sync (garis besar)
**Status:** Keputusan desain disepakati; M12 dan M13 siap diimplementasikan, M14 baru garis besar

---

# 0. CARA MEMBACA DOKUMEN INI

Addendum ini melengkapi GDD v1.0 dan Addendum v1.1. Jika ada konflik, urutan prioritasnya: **Addendum v1.2 > Addendum v1.1 > GDD v1.0**, dan **kode serta file konfigurasi nyata menang atas dokumen** (agent wajib melaporkan selisihnya).

Angka bertanda **(baseline)** boleh disetel lewat konfigurasi JSON, bukan konstanta di kode.

## 0.1 Sinkronisasi dengan kondisi aktual (setelah M8–M11)

Addendum v1.1 tidak diperbarui selama M9–M11. Fakta berikut berlaku sekarang dan menggantikan angka lama di v1.1:

| Topik | Nilai aktual |
|---|---|
| Pengali Ascension Dungeon | `ascension_multiplier` = 1.35 (bukan 2.0) |
| Kesulitan antar siklus | `cycle_per_rank` = 6.5, `cycle_level_step` = 44, `cycle_stat_exponents` hp 0.25 / atk 0.22 / def 0.20 |
| Eksponen stat antar dungeon | hp 1.0 / atk 1.0 / def 0.9; `reward_exponent` = 0.85 |
| Rank | Ada `ascensionRank` (rank aktif) dan `highestAscensionRank` (rank tertinggi yang pernah dicapai). Pemain dapat memilih rank lebih rendah lewat Rank Switcher. |
| Masuk dungeon | Ada level minimum (Hard Lock) |
| Shop | 14 entri; harga Rare 25.000–30.000, Epic 120.000, Legendary 500.000; requirement memakai `highestAscensionRank` |
| Database | Drift `schemaVersion = 5` |
| Platform | Portrait terkunci, `appCategory = game`, release signing wajib `key.properties` |
| Tipe dungeon | `DungeonKind { normal, ascension }` |

## 0.2 Cakupan UI

Pemilik project merancang ulang tampilan sendiri. Pada M12–M14 setiap fitur baru hanya mendapat **UI fungsional minimal** (daftar, tombol, teks status). Aturannya:
- Semua logika dan state berada di Domain/Application; widget hanya menampilkan dan memanggil service.
- Tidak ada pekerjaan tema, navigasi baru, atau perombakan tata letak.
- Widget baru diletakkan di berkas terpisah agar mudah diganti.

---

# 1. KEPUTUSAN YANG DIKUNCI

| Topik | Keputusan |
|---|---|
| Quest | Hanya dua: **Daily Quest** (kalahkan Daily Boss) dan **Weekly Quest** (kalahkan Weekly Boss). |
| Boss | Dapat dilawan kapan saja tanpa batas percobaan. Hadiah hanya untuk kemenangan pertama pada periode berjalan. |
| Mata uang baru | **Aether Shard**, jumlah tetap (tidak diskalakan dengan rank). |
| Weekly Event Shop | 2 item per minggu, rotasi dari pool 8 item selama siklus 4 minggu. |
| Stat item event | **Persentase** (HP, ATK, DEF) plus stat pecahan yang sudah ada. |
| Notifikasi | Lokal; termasuk pengingat **Auto Farming 8 jam**. |
| Kemenangan ulang | Tidak memberi hadiah pada periode yang sama. |

---

# 2. LAPISAN WAKTU

## 2.1 Periode

| Periode | Reset | Kunci periode |
|---|---|---|
| Harian | 00:00 waktu lokal perangkat | tanggal `YYYY-MM-DD` |
| Mingguan | Senin 00:00 waktu lokal | tanggal Senin `YYYY-MM-DD` |

Jam reset dan awal pekan berada di konfigurasi. Indeks minggu dihitung dari satu Senin acuan tetap (`epoch_monday`, baseline `2026-11-16`).

## 2.2 Pengaman Jam

- Waktu yang dipakai game adalah `max(waktu perangkat, waktu terlihat terakhir)`. Jam yang mundur tidak memicu reset, tidak memendekkan cooldown, dan tidak membuka quest.
- Lonjakan jam ke depan tidak bisa dibedakan dari waktu normal. Game hanya **mencatatnya** (jumlah dan lonjakan terbesar) agar dapat divalidasi server di M14.
- **Risiko yang diterima sampai M14:** memajukan jam perangkat dapat mereset quest lebih awal. Untuk sejumlah pemain yang saling dikenal, risiko ini dapat diterima.

---

# 3. AETHER SHARD

- Mata uang khusus untuk Weekly Event Shop. Tidak dapat dijual, ditukar ke gold, atau dibeli.
- Sumber: hadiah Daily Quest dan Weekly Quest. Jumlah per hadiah tetap (baseline: Daily 10, Weekly 50, sekitar 120 per minggu).
- Penggunaan: hanya Weekly Event Shop.
- Batas jumlah maksimum di konfigurasi sebagai pengaman overflow.
- Gold tetap berada di data pemain yang ada, tidak dipindahkan.

---

# 4. DAILY BOSS DAN WEEKLY BOSS

## 4.1 Aturan Umum

- Dilawan **manual saja** dari Town. Tidak ada Auto Farming, Continue Dungeon, atau offline untuk boss.
- **Tanpa batas percobaan.** Kalah tidak menghukum: tidak ada yang hilang dan tidak ada cooldown percobaan. Mekanik revive yang sudah ada di dalam run tetap berlaku.
- Layar boss menampilkan level rekomendasi sebagai peringatan, **tanpa Hard Lock**, karena kalah tidak berbiaya.
- Satu ruangan boss tanpa monster tambahan (memakai ulang peta ruang boss yang ada).
- Boss memakai sprite yang sudah ada dengan `sprite_ref` dan `sprite_tint`. Tidak ada aset baru.

## 4.2 Rotasi Boss

Boss dipilih deterministik dari indeks periode (hari atau minggu sejak `epoch_monday`) modulo ukuran pool di data. Pool awal (baseline): Daily 3 boss, Weekly 2 boss. Pool dapat diperluas lewat data.

## 4.3 Kekuatan Boss

Kekuatan mengikuti **kemajuan pemain di siklus saat ini**, bukan level karakter:

- **Dungeon acuan:** dungeon normal dengan urutan tertinggi yang sudah diselesaikan pada siklus dan rank yang sedang dipilih (default Dungeon 1 jika belum ada).
- Stat boss = stat dasar boss × profil kesulitan dungeon acuan pada rank terpilih × `power_factor` boss.
- `power_factor` (baseline): Daily 1.0, Weekly 1.5.
- Dengan begitu pemain yang sudah mampu menyelesaikan dungeon acuan umumnya dapat mengalahkan Daily Boss, dan Weekly Boss lebih sulit tetapi tetap dapat dicapai dengan lebih banyak level dan equipment.

Target keseimbangan (diverifikasi simulator): pemain di level rekomendasi dungeon acuan menang ≥ 85% (Daily) dan ≥ 80% (Weekly).

## 4.4 Quest dan Hadiah

| Quest | Syarat | Reset |
|---|---|---|
| Daily Quest | Kalahkan Daily Boss hari ini | Harian |
| Weekly Quest | Kalahkan Weekly Boss minggu ini | Mingguan |

- Quest "terbuka" saat reset. Kemenangan **sebelum** reset tidak dihitung.
- Hadiah **diberikan otomatis** saat kemenangan pertama pada periode itu (tanpa tombol klaim, sehingga tidak ada hadiah yang hangus). Aman terhadap pengulangan lewat id klaim `bossquest:{questId}:{periodKey}`.
- Kemenangan berikutnya pada periode yang sama tidak memberi hadiah apa pun.
- Jika sebuah run dimulai sebelum reset dan selesai sesudahnya, kemenangannya tidak memberi hadiah (kasus tepi yang didokumentasikan).
- Hadiah (baseline): Daily = 10 Aether Shard + gold dan EXP; Weekly = 50 Aether Shard + gold dan EXP lebih besar. Gold dan EXP diskalakan dengan pengali reward dungeon acuan.

---

# 5. WEEKLY EVENT SHOP

## 5.1 Struktur

- **Pool 8 item equipment**, 2 per slot (Senjata, Armor, Helm, Aksesoris): satu tingkat Epic dan satu tingkat Legendary per slot.
- **Siklus 4 minggu** (panjang siklus = ukuran pool ÷ 2). Tiap minggu menampilkan **2 item**. Dalam satu siklus setiap item tampil tepat sekali.
- Susunan dikocok secara deterministik dari nomor siklus: setiap pasangan terdiri dari satu item Epic dan satu Legendary dari **slot berbeda**. Hasilnya identik di semua perangkat dan dapat diverifikasi server.
- Pool boleh diperluas dalam kelipatan 2 lewat data, dan panjang siklus menyesuaikan.

## 5.2 Cara Beli (tidak semurah dan semudah shop biasa)

- Harga dalam **Aether Shard** (baseline: tingkat Epic 100, tingkat Legendary 180).
- Batas pembelian 1 per item per kemunculan (per minggu).
- Requirement (baseline): Epic memerlukan `dungeon_cleared` Ancient Crypt; Legendary memerlukan `min_ascension_rank` ≥ 1 (memakai `highestAscensionRank`).
- Konfirmasi sebelum membeli.
- **Item tidak dapat dijual** untuk gold.
- Dengan pendapatan sekitar 120 shard per minggu, pemain dapat membeli satu item per minggu atau menabung.

## 5.3 Stat Persentase

Item event menambah stat dalam bentuk persentase agar tetap relevan di level dan rank berapa pun:

- Stat baru: `hp_pct`, `atk_pct`, `def_pct`. Stat pecahan yang sudah ada (crit rate, crit damage, attack speed, skill haste) tetap dipakai.
- Rumus: stat akhir = (dasar + bonus angka tetap) × (1 + total persen), dengan batas total persen di konfigurasi.
- Stat item event bersifat **tetap**, tanpa roll acak.

Tabel baseline (boleh disetel):

| Slot | Epic | Legendary |
|---|---|---|
| Senjata | atk 10%, crit damage +0.15 | atk 16%, crit rate +0.05, crit damage +0.20 |
| Armor | hp 12%, def 8% | hp 20%, def 12% |
| Helm | def 10%, hp 6% | def 16%, hp 10%, skill haste +0.05 |
| Aksesoris | atk 6%, crit rate +0.04, skill haste +0.05 | atk 10%, hp 8%, crit rate +0.06 |

Nama item placeholder: `event_dawn_blade`, `event_eclipse_blade`, `event_aegis_mail`, `event_bulwark_plate`, `event_warden_helm`, `event_crown_of_dusk`, `event_ember_ring`, `event_aether_pendant`.

## 5.4 Catatan Konten

Dengan 8 item, pemain yang rajin akan memiliki seluruh isi shop dalam beberapa bulan, dan pembelian ulang menghasilkan duplikat. Pool sengaja dapat diperluas lewat data. Perluasan konten bukan bagian M13.

---

# 6. NOTIFIKASI

Semua notifikasi lokal (tanpa server). Setiap kategori dapat dimatikan di Pengaturan.

| Kategori | Kapan | Syarat |
|---|---|---|
| Auto Farming penuh | 8 jam setelah aplikasi masuk latar belakang | Mode offline Auto Farming atau Continue Dungeon |
| Pengingat Daily Boss | 18:00 waktu lokal | Daily Quest belum selesai |
| Pengingat Weekly Boss | Minggu 18:00 waktu lokal | Weekly Quest belum selesai |
| Event Shop berganti (M13) | Minggu 18:00 waktu lokal | Ada item event yang belum dibeli |

Aturan:
- Maksimal 3 notifikasi per hari. Jam tenang (baseline 23:00–07:00) menggeser notifikasi ke akhir jam tenang.
- Teks notifikasi Auto Farming bersifat netral karena perhitungan offline baru berjalan saat aplikasi dibuka: *"Batas offline 8 jam tercapai. Hasil farming siap diklaim."*
- Jadwal dibatalkan saat aplikasi dibuka dan dijadwalkan ulang saat masuk latar belakang atau setelah perangkat restart.
- Memakai penjadwalan tidak tepat waktu (tanpa izin alarm tepat waktu). Waktu tampil dapat meleset.
- Izin notifikasi diminta saat pemain pertama kali mengaktifkan sebuah kategori, bukan saat aplikasi dibuka.

---

# 7. CLOUD SYNC (M14, GARIS BESAR)

Keputusan yang sudah disepakati: Firestore, login anonim yang dapat ditautkan ke Google, paket Spark awalnya, sinkronisasi saat aplikasi dibuka, masuk latar belakang, setelah Ascension, dan tombol manual. Anti-cheat ketat: klien tidak menulis save langsung, Cloud Function memvalidasi isi save dengan batas kewajaran berdasarkan waktu server, App Check dengan Play Integrity, dan paket Blaze diperlukan. Detail ditulis setelah M13 selesai karena bergantung pada bentuk data M12–M13 (shard, quest, boss, shop event).

---

# 8. ASUMSI YANG DAPAT DIUBAH

| ID | Asumsi |
|---|---|
| B-1 | Reset harian 00:00 dan mingguan Senin 00:00 waktu lokal |
| B-2 | Kemenangan ulang tidak memberi hadiah |
| B-3 | Hadiah quest diberikan otomatis, bukan klaim manual |
| B-4 | Pool boss awal: Daily 3, Weekly 2 |
| B-5 | Reward: Daily 10 shard, Weekly 50 shard |
| B-6 | Harga event shop: Epic 100, Legendary 180 |
| B-7 | `power_factor` Daily 1.0 dan Weekly 1.5 |
| B-8 | Boss tanpa Hard Lock |
| B-9 | Jam tenang notifikasi 23:00–07:00, maksimal 3 per hari |
| B-10 | Pengingat quest pukul 18:00 |

---

# 9. DI LUAR LINGKUP M12–M14

Tipe quest lain, poin aktivitas dan peti, boss berbasis damage-tier, pengurangan batas percobaan boss, penukaran shard ke gold, perluasan pool item event, serta seluruh perancangan ulang UI (beranda, Hero Showcase, HUD dungeon) yang dikerjakan pemilik project sendiri.

**End of Addendum**
