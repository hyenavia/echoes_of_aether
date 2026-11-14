# ECHOES OF AETHER

## MASTER DEVELOPMENT ROADMAP — LANJUTAN (M8–M11)

**Document Version:** 2.0-addendum
**Melanjutkan:** MASTER_DEVELOPMENT_ROADMAP v1 (M1–M7, status Completed)
**Dokumen pendamping:** GAME_DESIGN_ADDENDUM_v1.1, TECHNICAL_DESIGN_ADDENDUM_v1.1, MILESTONE_STATUS_M8_M11, AGENT_PROMPTS_M8_M11

---

# 1. RINGKASAN

M1–M7 menghasilkan MVP lengkap dengan satu dungeon (Forgotten Forest). M8–M11 memperluasnya menjadi game Idle Dungeon RPG berjenjang dan endless.

| Milestone | Nama | Tujuan Singkat |
|---|---|---|
| M8 | Multi-Dungeon & Difficulty | Rumus damage rasio, level tanpa batas, 5 dungeon normal, sistem kesulitan, simulator balancing |
| M9 | Ascension Cycle | Ascension Dungeon, Ascension Rank endless, reset siklus, aturan respawn dan offline |
| M10 | Shop & Economy | Beli dan jual item, harga berdasarkan rarity, requirement item |
| M11 | UI Revamp Idle RPG | Tema, navigasi, panel, polish, dan verifikasi akhir |

## 1.1 Keputusan yang Dikunci

- Level karakter tanpa batas; Ascension Rank tanpa batas.
- Damage memakai rumus rasio; kesulitan antar rank linear.
- Dungeon baru memakai aset yang sudah ada, hanya stat dan nama yang berbeda.
- Ascension Dungeon hanya manual; Auto Farming dan offline hanya untuk dungeon normal.
- Setelah Ascension, pemain kembali ke Dungeon 1 dengan kesulitan lebih tinggi dan mempertahankan level, equipment, dan gold.
- Makin langka rarity, makin mahal harga di shop; item rarity tinggi punya requirement.
- Risiko minimal: gagal tidak menghukum, ada level rekomendasi, ada jalan keluar dari death loop.

## 1.2 Urutan dan Alasan

M8 → M9 → M10 → M11. UI dikerjakan terakhir agar layar baru (dungeon select, shop, ascension) tidak perlu dibuat dua kali. M10 tetap menyertakan UI shop **fungsional sederhana** agar dapat dites, yang kemudian di-restyle di M11.

---

# 2. ATURAN UMUM M8–M11

Seluruh Section 6 dari Master Development Roadmap v1 (Governance for AI Agents) **tetap wajib**. Tambahan:

1. **Satu stage per task.** Agent berhenti di akhir stage dan melapor.
2. **Audit dahulu.** Setiap stage dimulai dengan memverifikasi kondisi repository terhadap asumsi di TDD Addendum §1.
3. **Test baseline.** 366 test harus tetap hijau. Test yang diubah harus didaftar dan dibenarkan.
4. **Analyzer.** `flutter analyze` harus 0 issue di akhir stage.
5. **Konfigurasi.** Angka balancing tidak boleh di-hardcode.
6. **Dua jalur.** Perubahan yang menyentuh combat, reward, atau difficulty harus diterapkan dan dites di jalur online dan offline.
7. **Konflik desain.** Jika agent menemukan konflik dengan GDD/TDD, ia melapor dan meminta keputusan, bukan memutuskan sendiri.
8. **Migrasi.** Setiap perubahan schema wajib punya test migrasi dan catatan breaking change.

---

# MILESTONE 8 — MULTI-DUNGEON & DIFFICULTY

## Objective

Mengubah game dari satu dungeon menjadi lima dungeon normal berjenjang dengan kesulitan terukur, level tanpa batas, dan rumus damage yang aman untuk progres endless.

## Scope

### Stage 1 — Rumus Damage Rasio
- Konfigurasi `damage.formula`, implementasi rasio, mode `subtractive` untuk regresi.
- Satu instance kalkulator untuk online dan offline.

### Stage 2 — Level Tanpa Batas
- `max_level` opsional, kurva EXP polinomial, batas iterasi level-up, clamp pelindung.
- Perbaikan semua titik cap level dan reset EXP di level maksimum.
- Format angka besar di UI.

### Stage 3 — Skema Data dan Layanan Kesulitan
- Field baru dungeon/monster, parser, validator.
- `DifficultyService` dan `DungeonProgressionService`.
- Penerapan pengali ke stat dan reward di jalur online dan offline.

### Stage 4 — Runtime Multi-Dungeon dan Migrasi v3
- Hapus hardcode `defaultDungeonId`.
- Schema v3 (`CycleProgresses`, `clearedInCycleRank`) dan migrasinya.
- Pemilih dungeon fungsional di Town, unlock berurutan, pemilih Auto Farming per dungeon.

### Stage 5 — Konten 5 Dungeon
- Empat dungeon baru, monster normal, elite, boss, dan Final Boss lewat data.
- `sprite_ref`, `sprite_tint`, loot table, completion reward.

### Stage 6 — Simulator Balancing dan QA
- Simulator, tabel target, penyetelan angka, verifikasi APK.

## Acceptance Criteria

1. Damage memakai rumus rasio dan tidak pernah di bawah 1; online dan offline menghasilkan damage identik untuk input sama.
2. Level dapat naik tanpa batas; tidak ada overflow, `NaN`, atau reset EXP; save lama tetap termuat.
3. Lima dungeon normal dapat dimainkan berurutan; dungeon N+1 terkunci sampai dungeon N selesai.
4. Pengali kesulitan memengaruhi stat dan reward di online dan offline dengan hasil paritas.
5. Final Boss ada di Dungeon 5.
6. Migrasi v2 → v3 mempertahankan seluruh data pemain.
7. Auto Farming offline dapat memilih dungeon yang sudah selesai.
8. Simulator balancing memenuhi target di TDD Addendum §6 untuk rank 0.
9. `flutter analyze` 0 issue; semua test hijau; APK terverifikasi di perangkat.

## Exit Condition

Pemain dapat menyelesaikan Dungeon 1–5 secara berurutan dengan progres tersimpan, dan simulator membuktikan target keseimbangan rank 0.

---

# MILESTONE 9 — ASCENSION CYCLE

## Objective

Menambahkan Ascension Dungeon dan siklus endless dengan Ascension Rank.

## Scope

### Stage 1 — Domain Siklus
- `CycleProgress`, `AscensionService`, resolusi Farm Dungeon, aturan respawn.
- Persistensi rank dan Farm Dungeon lewat repository.

### Stage 2 — Ascension Dungeon
- Konfigurasi `kind: ascension` dan `base_dungeon_id`.
- Pengali kesulitan memakai `cycleRank`, disimpan di snapshot run.
- Enforcement manual-only dan aturan offline.

### Stage 3 — Alur Penyelesaian dan Respawn
- Penyelesaian Ascension: rank bertambah sekali, reset clear siklus, reward ascension.
- Kekalahan di Ascension tanpa hukuman; kembali ke Town dengan dungeon normal terakhir terpilih.
- Saran turun dungeon setelah kekalahan beruntun.

### Stage 4 — Skala Reward dan Drop per Rank
- Pengali reward, peluang drop Rare ke atas, dan bonus roll per rank.
- Paritas online dan offline.

### Stage 5 — Balancing Rank dan QA
- Simulator diperluas ke rank 0, 1, 5, 10, 50, 1000; verifikasi tidak ada overflow; APK.

## Acceptance Criteria

1. Ascension Dungeon terbuka hanya setelah Dungeon 5 selesai pada siklus saat ini.
2. Ascension Dungeon tidak dapat dipilih untuk Auto Farming; offline dipaksa Pause jika run aktif adalah ascension.
3. Menyelesaikan Ascension menaikkan rank tepat satu kali (idempoten) dan mereset clear siklus; level, equipment, gold, skill tetap.
4. Kekalahan di Ascension tidak mengubah rank dan tidak menghapus loot terkonfirmasi.
5. Kesulitan dan reward naik sesuai rank di online dan offline (paritas).
6. Kualitas drop meningkat sesuai rank dengan batas atas.
7. Recovery sesi di tengah Ascension mempertahankan rank yang sama.
8. Tidak ada overflow pada rank 1000.
9. `flutter analyze` 0 issue; semua test hijau; APK terverifikasi.

## Exit Condition

Pemain dapat menyelesaikan siklus penuh, kembali ke Dungeon 1 dengan kesulitan lebih tinggi, dan mengulanginya tanpa batas dengan state konsisten.

---

# MILESTONE 10 — SHOP & ECONOMY

## Objective

Menambahkan shop NPC untuk jual dan beli item dengan harga berdasarkan rarity dan requirement untuk item langka.

## Scope

### Stage 1 — Data Shop dan Migrasi v4
- `shop.json`, entitas, parser, validator (pita harga monoton, rasio jual).
- Tabel `ShopPurchases` dan migrasinya.

### Stage 2 — Logika Beli/Jual dan Requirement
- `ShopService`, evaluator requirement, hasil sealed, transaksi atomik.
- Persistensi pembelian dan batas pembelian.

### Stage 3 — UI Shop Fungsional
- Overlay shop sederhana (daftar beli/jual, requirement tampil jelas, konfirmasi item langka, jual massal material).
- Integrasi dengan inventory dan equipment yang sudah ada.

### Stage 4 — Balancing Ekonomi dan QA
- Simulator ekonomi: gold per jam vs harga; pengaman exploit; APK.

## Acceptance Criteria

1. Harga beli naik monoton mengikuti rarity; harga jual ≤ 40% harga beli.
2. Pembelian gagal tanpa mengurangi gold jika requirement belum terpenuhi, gold kurang, atau tas penuh.
3. Equipment yang dibeli berupa instance baru dengan roll stat.
4. Equipment yang sedang dipakai tidak dapat dijual.
5. Pembelian dan penjualan atomik dan idempoten terhadap pengulangan (tidak double-spend).
6. Requirement `min_level`, `dungeon_cleared`, `min_ascension_rank` bekerja dan tampil di UI.
7. Migrasi v3 → v4 aman; save tetap termuat.
8. `flutter analyze` 0 issue; semua test hijau; APK terverifikasi.

## Exit Condition

Pemain dapat menukar gold dan item secara aman, dan ekonomi tidak menghasilkan exploit beli-jual atau inflasi tak terkendali menurut simulator.

---

# MILESTONE 11 — UI REVAMP IDLE RPG

## Objective

Mengubah tampilan polos menjadi UI bergaya Idle RPG yang konsisten, tanpa mengubah logika gameplay.

## Scope

### Stage 1 — Tema dan Komponen
- Token desain, tipografi, komponen bersama (kartu item, bar, tombol, panel).

### Stage 2 — Navigasi dan Town
- Navigasi bawah, top bar (level, EXP, gold, rank), Town/Adventure layout.

### Stage 3 — Panel Hero dan Bag
- Karakter, skill, specialization, inventory, dan equipment dengan komponen baru.

### Stage 4 — Shop, Dungeon Select, HUD, dan Hasil
- Restyle shop, pemilih dungeon (status, level rekomendasi, peringatan), HUD dungeon, overlay hasil dan ascension.

### Stage 5 — Polish, Performa, dan QA
- Konsistensi, aksesibilitas dasar, performa, verifikasi akhir, APK release.

## Acceptance Criteria

1. Semua layar utama memakai token dan komponen tema yang sama.
2. Navigasi bawah menjangkau Adventure, Hero, Bag, Shop, Settings.
3. Rarity terlihat konsisten lewat warna.
4. Tidak ada perubahan perilaku gameplay; semua test gameplay tetap hijau.
5. Tidak ada overflow layout pada layar umum perangkat Android.
6. Performa gameplay tidak turun dibanding baseline M7.
7. `flutter analyze` 0 issue; APK release terverifikasi di perangkat.

## Exit Condition

Game terasa seperti Idle RPG utuh dan seluruh fitur M8–M10 dapat diakses dari UI yang konsisten.

---

# 3. KETERGANTUNGAN ANTAR MILESTONE

| Milestone | Bergantung pada |
|---|---|
| M8 | M1–M7 selesai |
| M9 | M8 (multi-dungeon, kesulitan, schema v3) |
| M10 | M8 (level/reward), M9 (requirement ascension) |
| M11 | M8, M9, M10 (layar yang akan di-restyle) |

# 4. KONTROL SCOPE

Dikecualikan dari M8–M11: aset visual atau tileset baru, mekanik monster/boss baru, rotasi stok shop, gacha, trading antar-pemain, crafting, pet, dan fitur online.

# 5. PRINSIP AKHIR

Setiap stage kecil, terverifikasi, dan dapat dipertanggungjawabkan. Jangan menganggap fitur selesai karena kodenya ada; fitur selesai ketika diuji.

**End of Document**
