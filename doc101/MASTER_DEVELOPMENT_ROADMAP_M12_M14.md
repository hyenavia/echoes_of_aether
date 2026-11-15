# ECHOES OF AETHER

## MASTER DEVELOPMENT ROADMAP — LANJUTAN (M12–M14)

**Document Version:** 3.0-addendum
**Melanjutkan:** MASTER_DEVELOPMENT_ROADMAP v1 (M1–M7) dan MASTER_DEVELOPMENT_ROADMAP_M8_M11 (M8–M11, Completed)
**Dokumen pendamping:** GAME_DESIGN_ADDENDUM_v1.2, TECHNICAL_DESIGN_ADDENDUM_v1.2, MILESTONE_STATUS_M12_M14, AGENT_PROMPTS_M12_M14

---

# 1. RINGKASAN

| Milestone | Nama | Tujuan Singkat | Schema |
|---|---|---|---|
| M12 | Time, Currency, Boss Quest & Notifications | Lapisan waktu, Aether Shard, Daily/Weekly Boss dan Quest, pemangkasan `ClaimedRewards`, notifikasi | v6 |
| M13 | Weekly Event Shop & Percentage Stats | Stat persentase pada equipment, rotasi event shop mingguan, pembelian dengan Aether Shard | v7 |
| M14 | Cloud Sync & Anti-Cheat | Firestore, akun, validasi server, jam server | v8 |

## 1.1 Keputusan yang Dikunci

Lihat GAME_DESIGN_ADDENDUM_v1.2 §1. Singkatnya: hanya dua quest (kalahkan Daily/Weekly Boss), boss tanpa batas percobaan dengan hadiah sekali per periode, Aether Shard bernilai tetap, event shop 2 item per minggu dari pool 8 dengan siklus 4 minggu, stat item event berupa persentase, notifikasi lokal termasuk Auto Farming 8 jam.

## 1.2 Cakupan UI

Pemilik project merancang ulang UI sendiri. M12–M14 hanya menambah UI fungsional minimal per fitur, dipisahkan dari logika. Tidak ada pekerjaan tema atau navigasi.

## 1.3 Urutan dan Alasan

M12 → M13 → M14. M12 menyediakan Aether Shard dan lapisan waktu yang dipakai M13 dan M14. M13 menambah stat persentase yang harus stabil sebelum cloud memvalidasi save. M14 ditulis rinci setelah M13 selesai karena bergantung pada bentuk data final dan pada project Firebase yang kamu siapkan.

---

# 2. ATURAN UMUM M12–M14

Seluruh Section 6 Master Development Roadmap v1 dan Section 2 roadmap M8–M11 tetap wajib. Tambahan:

1. **Satu stage per task.** Agent berhenti di akhir stage dan melapor.
2. **Audit dahulu** terhadap TDD Addendum v1.2 §1; selisih dengan kode nyata dilaporkan sebelum mengubah kode.
3. **Baseline:** 545 test hijau, `flutter analyze` 0 issue, schema v5.
4. **Dua jalur:** perubahan stat, reward, atau difficulty diterapkan dan dites di online dan offline.
5. **Waktu disuntikkan:** logika game tidak boleh memanggil `DateTime.now()` langsung.
6. **Idempoten:** semua pemberian hadiah dan pembelian memakai id klaim.
7. **Migrasi:** setiap perubahan schema wajib punya test dari setiap versi lama dengan data nyata.
8. **Dependensi baru** hanya yang disetujui tertulis di prompt stage.
9. **UI minimal fungsional** dan terpisah; jangan me-restyle layar yang ada.
10. **Konflik desain:** agent melapor dan meminta keputusan, tidak memutuskan sendiri.

---

# MILESTONE 12 — TIME, CURRENCY, BOSS QUEST & NOTIFICATIONS

## Objective

Menambahkan sistem periode harian dan mingguan, mata uang Aether Shard, Daily/Weekly Boss dengan Quest, dan notifikasi pengingat.

## Scope

### Stage 1 — Lapisan Waktu, Schema v6, dan Pemangkasan ClaimedRewards
- `GameClock`, `PeriodService`, `ClockGuard`, konfigurasi `time`.
- Migrasi v6 (`ClockStates`, `Currencies`, `PeriodicQuestStates`).
- Pemangkasan `ClaimedRewards`.

### Stage 2 — Aether Shard
- `CurrencyService`, persistensi, konfigurasi `currencies`, tampilan jumlah shard.

### Stage 3 — Boss Events (Domain dan Runtime)
- `boss_events.json`, `DungeonKind` baru, rotasi, acuan kesulitan, run boss manual-only.

### Stage 4 — Boss Quest dan Hadiah
- `BossQuestService`, hadiah otomatis sekali per periode, UI fungsional layar boss.

### Stage 5 — Notifikasi
- `NotificationPlanner`, adapter platform, pengaturan, notifikasi Auto Farming 8 jam, pengingat boss.

### Stage 6 — Balancing dan QA
- Simulator boss dan reward, uji perangkat, APK.

## Acceptance Criteria

1. Kunci periode harian dan mingguan benar pada batas reset, pergantian tahun, dan zona waktu berbeda; jam mundur tidak memicu reset.
2. `ClaimedRewards` dipangkas tanpa menyebabkan reward ganda pada skenario recovery sesi, offline, ascension, dan shop.
3. Aether Shard dapat diberikan dan dibelanjakan secara atomik dan idempoten, dengan batas atas.
4. Daily dan Weekly Boss berputar deterministik, dapat dilawan tanpa batas, dan hanya manual.
5. Kekuatan boss mengikuti dungeon acuan pada rank terpilih; simulator memenuhi target win rate.
6. Hadiah quest hanya diberikan pada kemenangan pertama per periode; kemenangan sebelum reset atau ulang tidak memberi hadiah; run yang melewati reset tidak memberi hadiah.
7. Notifikasi Auto Farming muncul 8 jam setelah aplikasi masuk latar belakang pada mode yang berlaku; pengingat quest hanya jika quest belum selesai; setiap kategori dapat dimatikan.
8. Migrasi v1–v5 → v6 aman.
9. `flutter analyze` 0 issue; semua test hijau; APK terverifikasi.

## Exit Condition

Pemain dapat mengalahkan Daily dan Weekly Boss setelah tiap reset, menerima Aether Shard, dan menerima pengingat yang dapat diatur, dengan state yang konsisten dan tidak dapat digandakan.

---

# MILESTONE 13 — WEEKLY EVENT SHOP & PERCENTAGE STATS

## Objective

Menambahkan stat persentase pada equipment dan Weekly Event Shop yang berotasi, dibeli dengan Aether Shard.

## Scope

### Stage 1 — Stat Persentase dan Schema v7
- `EquipmentStats` dengan `hpPct`, `atkPct`, `defPct`; `DerivedStatsCalculator`; cap; persistensi; tampilan teks.
- Migrasi v7 (`EventShopPurchases`, serta kolom stat persen bila diperlukan).

### Stage 2 — Data Event dan Rotasi
- 8 item event, `event_shop.json`, validator, `EventRotation`.

### Stage 3 — Event Shop Service dan UI
- Pembelian dengan shard, batas mingguan, requirement, non-sellable, UI fungsional, notifikasi event berganti.

### Stage 4 — Balancing Ekonomi dan QA
- Simulator shard terhadap harga, dampak stat persen, uji exploit, APK.

## Acceptance Criteria

1. Stat persen diterapkan setelah stat angka tetap, dibatasi cap, dan hasilnya identik di online dan offline.
2. Item event tidak memiliki roll acak dan tidak dapat dijual.
3. Rotasi deterministik: setiap item tampil tepat sekali per siklus 4 minggu, tiap pasangan berbeda slot dan terdiri dari satu Epic dan satu Legendary.
4. Pembelian memakai shard secara atomik; gagal tanpa efek samping; batas 1 per item per minggu; requirement bekerja.
5. Migrasi v1–v6 → v7 aman.
6. Simulator: satu set event penuh tidak merusak keseimbangan (laporan dan batas).
7. `flutter analyze` 0 issue; semua test hijau; APK terverifikasi.

## Exit Condition

Pemain dapat menukar Aether Shard dengan item event yang berganti tiap minggu, dan item itu meningkatkan stat hero secara bermakna pada level dan rank berapa pun.

---

# MILESTONE 14 — CLOUD SYNC & ANTI-CHEAT (GARIS BESAR)

## Objective

Menyimpan save di cloud dengan akun pemain, memvalidasi save di server, dan memakai waktu server.

## Garis Besar Stage

| Stage | Isi |
|---|---|
| 0 (manual) | Pemilik project menyiapkan Firebase: project, aplikasi Android (nama paket dan SHA-1/SHA-256 keystore rilis), login anonim dan Google, Firestore |
| 1 | `CloudSaveRepository`, ekspor/impor snapshot, penanda revisi dan belum tersinkron, schema v8 |
| 2 | Proyek Cloud Functions: validasi isi save, batas kewajaran dari simulator (termasuk shard, quest, boss, event shop), penulisan lewat Admin SDK; paket Blaze |
| 3 | Integrasi klien: Auth, App Check, callable function, orkestrasi sinkronisasi, dialog konflik minimal, jam server |
| 4 | QA dua perangkat, mode pesawat, upgrade dari save M13, uji save yang dimanipulasi |

Rincian ditulis setelah M13 selesai.

---

# 3. KETERGANTUNGAN

| Milestone | Bergantung pada |
|---|---|
| M12 | M1–M11 |
| M13 | M12 (Aether Shard, periode) |
| M14 | M12, M13 |

# 4. KONTROL SCOPE

Dikecualikan: tipe quest lain, poin aktivitas, boss damage-tier, penukaran shard ke gold, aset visual baru, dan perancangan ulang UI.

**End of Document**
