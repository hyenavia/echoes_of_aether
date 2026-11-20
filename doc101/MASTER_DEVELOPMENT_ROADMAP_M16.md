# ECHOES OF AETHER

## MASTER DEVELOPMENT ROADMAP — M16 (HERO ASCENSION, DUNGEON 6 & THE INFINITE SPIRE)

**Document Version:** 1.0  
**Melanjutkan:** M1–M15 Selesai & Global Game Balance Stage 1 Selesai  
**Baseline Saat Ini:** Drift Schema v10, 1.008 Tests Passing, 0 Analyzer Issue  
**Dokumen Pendamping:** DESIGN_ADDENDUM_v1.5_HERO_ASCENSION_AND_SPIRE  
**Status:** DRAFT RANCANGAN ROADMAP RESMI  
**Last Updated:** 2026-11-20  

---

# 1. ATURAN PENGEMBANGAN (AGENTS.MD ALIGNMENT)

1. **Disiplin Stage:** Satu stage per sesi. Agent berhenti dan melapor di akhir tiap stage untuk verifikasi dan persetujuan pemilik project.
2. **Integritas Save Pemain Lama:** Data pemain lama dilindungi secara mutlak. Migrasi skema Drift v10 $\rightarrow$ v11 wajib mengonversi level pemain lama ke fase Ascension yang setara tanpa kehilangan progres atau level. Jika level $> 90$, clamp ke 90 dengan paket kompensasi *Aether Legacy Gift*.
3. **Paritas Online & Offline:** Seluruh perhitungan stat dari bonus Hero Ascension wajib berlaku identik di pertempuran real-time online (`CombatSimulation`) maupun di simulasi offline (`OfflineDungeonRunner`).
4. **Pencegahan Breaking Balance:** Stat dasar monster D1–D5 yang telah diseimbangkan pada Stage 1 tetap dipertahankan. Pengali rank dikalibrasi agar Rank 5 pas mencapai puncaknya di Level 90–95.
5. **UI Fungsional Minimal:** UI tombol Terobosan (Ascend) dan antarmuka Infinite Spire dibuat modular di berkas terpisah tanpa merusak tampilan yang sudah dirancang pemilik project.

---

# 2. RANCANGAN TAHAPAN MILESTONE 16

```
+--------------------------------------------------------------------------+
| MILESTONE 16: HERO ASCENSION, WORLD RANK CAP, D6 & INFINITE SPIRE        |
+--------------------------------------------------------------------------+
                                     |
                                     v
  [Stage 1] Data Layer & Migration: Drift Schema v11, Config JSON & Legacy Save
                                     |
                                     v
  [Stage 2] Domain Layer: Hero Ascension Service, Cap Logic & Rank 5 World Cap
                                     |
                                     v
  [Stage 3] Content Expansion: Dungeon 6 (The Abyssal Rift), Boss & T6 Gear
                                     |
                                     v
  [Stage 4] End-Game Mode: The Infinite Spire (100 Floors & First-Clear Rewards)
                                     |
                                     v
  [Stage 5] Presentation Layer, Balance Verification & Full Regression Pass
```

---

### Stage 1 — Data Layer & Migrasi: Drift Schema v11, Config JSON & Legacy Save

**Tujuan:** Mempersiapkan model data statis dan skema database Drift v11 dengan backward compatibility 100% untuk pemain lama.

* **Pekerjaan:**
  1. **Konfigurasi JSON:**
     - Perbarui [assets/data/game_config.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/game_config.json): set `"max_level": 90` dan tambahkan blok konfigurasi `"hero_ascension"` (definisi A0 s/d A6, level cap per fase, material cost, dan bonus stat).
     - Buat berkas baru [assets/data/infinite_spire.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/infinite_spire.json) (daftar lantai 1..100, susunan spawn musuh/bos, dan reward first-clear).
  2. **Domain Entities:**
     - Buat entity `HeroAscensionPhaseDefinition`, `HeroAscensionCost`, `HeroAscensionState`.
     - Buat entity `InfiniteSpireFloorDefinition`, `InfiniteSpireProgressSnapshot`.
  3. **Drift Schema Migration (v10 $\rightarrow$ v11):**
     - Tambahkan kolom `ascension_phase` pada tabel `players` (INTEGER NOT NULL DEFAULT 0).
     - Tambahkan tabel baru `infinite_spire_progress` (player_id, highest_floor_cleared, claimed_rewards_blob).
     - Buat migrasi cerdas: menghitung dan mengisi `ascension_phase` otomatis dari kolom `level` pemain eksisting (Lv 1–20 $\rightarrow$ A0, Lv 21–40 $\rightarrow$ A1, ..., Lv 81–90 $\rightarrow$ A6). Clamp level $> 90$ ke 90 dan clamp `cycle_rank > 5` ke 5.
  4. **Testing & Verifikasi:**
     - Unit test migrasi Drift v10 $\rightarrow$ v11 dengan data terisi nyata (memverifikasi konversi level lama, data pity gacha, dan data barter shop tetap utuh).
* **Kriteria Sukses:**
  - Migrasi skema database Drift v10 $\rightarrow$ v11 lulus 100% tanpa data loss.
  - Parser JSON memvalidasi seluruh konfigurasi baru.

---

### Stage 2 — Domain Layer: Hero Ascension Service, Cap Logic & Rank 5 World Cap

**Tujuan:** Membangun core domain logic untuk terobosan level karakter dan pembatasan siklus dunia di Rank 5.

* **Pekerjaan:**
  1. **ProgressionService & Level Capping:**
     - Batasi penambahan EXP saat karakter menyentuh level cap fase aktif.
     - Sediakan method `canAscend(player, inventory)` dan `ascendHero(player, inventory)`.
     - Validasi konsumsi material (Boss Remnant, Scrap, Gold, Aether Shard) secara atomik.
     - Tambahkan bonus stat terobosan ke dalam kalkulasi atribut di `DerivedStatsCalculator`.
  2. **DungeonProgressionService & Rank 5 Cap:**
     - Kunci batas siklus dunia di `maxRank = 5`.
     - Saat menamatkan Ascension Dungeon pada Rank 5, aktifkan status `isPeakWorldTier = true`, berikan status `Aether Ascendant`, dan jangan reset unlock status dungeon.
     - Kalibrasi kurva `DifficultyService` agar Rank 5 pas dihadapi oleh karakter Level 90.
  3. **Testing & Paritas:**
     - Test unit untuk transaksi Ascension, penolakan kenaikan level sebelum terobosan, lonjakan stat, dan paritas formula combat online vs offline.
* **Kriteria Sukses:**
  - Karakter tidak bisa naik level melampaui level cap sebelum melakukan terobosan.
  - Siklus dungeon berhenti me-reset di Rank 5 dan terkunci pada tingkat kesulitan puncak.

---

### Stage 3 — Content Expansion: Dungeon 6 (The Abyssal Rift), Boss & T6 Gear

**Tujuan:** Menghadirkan dungeon reguler ke-6 sebagai konten petualangan baru dan sumber material Ascension A5 & A6.

* **Pekerjaan:**
  1. **Definisi Dungeon & Peta:**
     - Tambahkan `abyssal_rift` di [assets/data/dungeons.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/dungeons.json) (order: 6, recommendedLevel: 65, rooms: 5 ruangan).
     - Daftarkan layout map baru di [assets/data/map_layouts.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/map_layouts.json).
  2. **Monster & Boss Baru:**
     - Tambahkan monster baru di [assets/data/monsters.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/monsters.json): `abyssal_crawler`, `void_weaver`, `shadow_stalker`.
     - Tambahkan bos baru `abyssal_archon` (Base HP 2.800, Base ATK 35, Base DEF 10, skill Void Nova).
  3. **Perlengkapan Tier 6 (Abyssal Set):**
     - Tambahkan 8 item baru Tier 6 (Rarity Epic & Legendary) di [assets/data/items.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/items.json).
     - Daftarkan item drop `abyssal_remnant` dan `void_essence` di [assets/data/loot_tables.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/loot_tables.json).
  4. **Testing & Simulator:**
     - Verifikasi simulasi tempur D6 di `BalanceSimulator` untuk seluruh 10 class.
* **Kriteria Sukses:**
  - Dungeon 6 dapat dimainkan manual dan auto farming dengan win rate yang wajar pada level rekomendasi.
  - Drop material terobosan terdistribusi secara akurat.

---

### Stage 4 — End-Game Mode: The Infinite Spire (100 Floors & First-Clear Rewards)

**Tujuan:** Mengimplementasikan arena tantangan menara lantai 1 s/d 100+ bagi karakter Level 90.

* **Pekerjaan:**
  1. **Spire Runtime & Engine:**
     - Service `InfiniteSpireService`: memproses progres pemanjatan lantai, evaluasi timer tantangan, dan pencatatan lantai tertinggi.
     - Penanganan lantai khusus (*Boss Floor* setiap 10 lantai dengan modifier kesulitan unik).
  2. **Sistem Hadiah First-Clear:**
     - Penyerahan hadiah sekali seumur hidup (*one-time claim*) per lantai.
     - Persistensi status klaim lantai di database Drift SQLite.
  3. **Testing:**
     - Test unit pemanjatan lantai 1..100, pencegahan klaim hadiah ganda, dan penanganan timeout/kematian tanpa penalti.
* **Kriteria Sukses:**
  - Seluruh 100 lantai tervalidasi aman dari infinite loop, crash, atau error matematika.
  - Hadiah first-clear bersifat idempoten dan atomik.

---

### Stage 5 — Presentation Layer, Balance Verification & Full Regression Pass

**Tujuan:** Menyediakan antarmuka visual yang nyaman bagi pemain, verifikasi simulasi menyeluruh, dan regression pass.

* **Pekerjaan:**
  1. **UI Hero Ascension:**
     - Tambahkan tombol **"Terobosan" / "Ascend"** di `CharacterOverlay` saat level cap tersentuh.
     - Dialog konfirmasi terobosan menampilkan rincian material yang dibutuhkan dan preview kenaikan stat.
     - Animasi/efek teks visual "ASCENDED!" yang membanggakan.
  2. **UI The Infinite Spire:**
     - Tambahkan gerbang akses pintas ke The Infinite Spire di `TownHubView`.
     - Tampilan pemilihan lantai (*Floor Selector*) dengan indikator status cleared dan tombol tantang lantai berikutnya.
  3. **Pengujian Regresi Menyeluruh:**
     - Jalankan `dart format`.
     - Jalankan `flutter analyze` (target: 0 issues).
     - Jalankan `flutter test` (memastikan seluruh 1.008+ test lulus 100%).
     - Perbarui tracker `MILESTONE_STATUS_M16.md`.
* **Kriteria Sukses:**
  - UI fungsional, bersih, dan bebas overflow di layar mobile maupun tablet.
  - 100% regression suite lulus hijau.
