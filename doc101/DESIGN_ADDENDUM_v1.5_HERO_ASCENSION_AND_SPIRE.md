# ECHOES OF AETHER

## DESIGN ADDENDUM v1.5 — MILESTONE 16
### HERO ASCENSION BREAKTHROUGH, WORLD RANK CAP, THE ABYSSAL RIFT & THE INFINITE SPIRE

**Document Version:** 1.5-addendum  
**Basis:** GAME_DESIGN_DOCUMENT v1.0, ADDENDUM v1.1–v1.4, GLOBAL_GAME_BALANCE_STAGE_1  
**Status:** DRAFT RANCANGAN DESAIN & ARSITEKTUR M16  
**Last Updated:** 2026-11-20  

---

# 1. LATAR BELAKANG & TUJUAN DESAIN

Milestone M1 sampai M15 telah membangun sistem inti yang lengkap: 10 Class Karakter, Gacha, Senjata Signature Mythical, Sistem Barter, dan Keseimbangan Tempur (1.008 test passing). Namun, dua hal mendasar dalam pengalaman jangka panjang pemain masih belum optimal:

1. **Ketiadaan Batas Level Karakter (*Infinite Leveling*):** Tanpa level cap, pemain kehilangan momen kepuasan terobosan (*breakthrough*) dan risiko overleveling di awal game merusak keseruan pertempuran bos.
2. **Siklus Dungeon Tanpa Ujung (*Infinite NG+ Cycle*):** Siklus dungeon berputar terus hingga Rank 1000 tanpa garis finish yang jelas, membuat pemain merasa game tidak pernah bisa "ditamatkan".

Milestone 16 memperkenalkan sistem **Hero Ascension (Level Cap ala Genshin / Wuthering Waves)**, **World Rank Cap (Rank 5 Peak)**, **Dungeon 6 (The Abyssal Rift)**, serta **The Infinite Spire (End-Game Challenge)** dengan perlindungan dan rebalance penuh untuk data pemain lama.

---

# 2. SISTEM HERO ASCENSION (LEVEL CAP & BREAKTHROUGH)

Batas level karakter dikunci pada **Level 90 (Hard Cap Mutlak)** yang terbagi ke dalam **6 Fase Ascension (A0 s/d A6)**.

### 2.1 Matriks Fase Ascension

| Phase | Level Range | Level Cap | Syarat Material Terobosan (Ascension Cost) | Bonus Terobosan (*Breakthrough Boost*) |
|---|---|---|---|---|
| **A0** | 1 – 20 | **20** | Karakter awal | Base stat dasar |
| **A1** | 20 – 40 | **40** | 3x D1 Boss Remnant + 500 Gold | +50 Max HP, +8 ATK, +3 DEF |
| **A2** | 40 – 50 | **50** | 4x D2–D3 Boss Remnant + 10x Aether Scrap + 1.500 Gold | +75 Max HP, +12 ATK, +5 DEF, +2% Crit Rate |
| **A3** | 50 – 60 | **60** | 5x D4 Boss Remnant (Ash Tyrant) + 20x Scrap + 3.000 Gold | +100 Max HP, +15 ATK, +6 DEF, +3% Attack Speed |
| **A4** | 60 – 70 | **70** | 5x D5 Boss Remnant (Aether Sovereign) + 30x Scrap + 5.000 Gold | +150 Max HP, +20 ATK, +8 DEF, +5% Crit DMG |
| **A5** | 70 – 80 | **80** | 5x D6 Boss Remnant (Abyssal Archon) + 40x Scrap + 8.000 Gold | +200 Max HP, +25 ATK, +10 DEF, +5% Skill Haste |
| **A6 (MAX)** | 80 – 90 | **90 (MAX)**| 5x Void Essence + 50x Scrap + 100 Aether Shard + 15.000 Gold | **Max Potential:** +300 HP, +35 ATK, +15 DEF, Golden Aura Status |

### 2.2 Aturan Kenaikan Level & EXP
* Ketika EXP karakter mencapai batas level fase (misal Lv 20, EXP 100%), perolehan EXP akan **terhenti** (*capped*) dan UI menampilkan label **"Ascend Ready"**.
* Pemain membuka menu Karakter dan menekan tombol **"Terobosan" (Ascend)**.
* Setelah konfirmasi transaksi material, level cap baru terbuka dan bonus stat terobosan langsung diterapkan secara permanen.
* Pada Level 90, bar EXP digantikan teks **"MAX"** dan karakter dinyatakan mencapai batas puncak kekuatannya.

---

# 3. SISTEM WORLD RANK CAP (PEAK WORLD TIER)

Alih-alih New Game+ siklus berputar tanpa batas hingga Rank 1000:
* Siklus dungeon dibatasi hingga **Rank 5 (Peak World Tier)**.
* **Rank 0 (Siklus Awal):** Dungeon 1 s/d 5 (Level Rekomendasi 1–50).
* **Rank 1:** Tingkat kesulitan disesuaikan untuk karakter Level 50–60 (A3).
* **Rank 2:** Tingkat kesulitan disesuaikan untuk karakter Level 60–70 (A4).
* **Rank 3:** Tingkat kesulitan disesuaikan untuk karakter Level 70–80 (A5), Dungeon 6 terbuka.
* **Rank 4:** Tingkat kesulitan disesuaikan untuk karakter Level 80–85 (A5/A6).
* **Rank 5 (FINAL / PEAK WORLD TIER):**
  * Tingkat kesulitan puncak (Level Rekomendasi 85–95).
  * Menamatkan Ascension Dungeon di Rank 5 memberikan gelar bergengsi **"Aether Ascendant"**.
  * **Dunia Tidak Di-Reset Lagi:** Seluruh Dungeon 1 sampai 6 tetap terbuka permanen pada tingkat kesulitan Rank 5 dengan drop rate dan roll bonus perlengkapan terbaik.

---

# 4. REBALANCE & MIGRASI DATA PEMAIN LAMA (BACKWARD COMPATIBILITY)

Sesuai aturan kerja proyek (AGENTS.md §4.3 & §8), data pemain lama **wajib dilindungi 100% tanpa reset, tanpa kehilangan progres, dan tanpa menghapus level yang sudah dicapai**.

### 4.1 Pemetaan Level & Otomatisasi Grant Fase Ascension
Saat aplikasi diperbarui ke Milestone 16, fungsi migrasi database Drift (v10 $\rightarrow$ v11) akan membaca level pemain lama dan secara otomatis memberikan fase Ascension yang setara tanpa memungut biaya material:

| Level Pemain di Save Data Lama | Fase Ascension Baru yang Diberikan | Level Cap Baru | Penjelasan |
|---|---|---|---|
| **Level 1 – 20** | **Phase 0 (A0)** | 20 | Pemain pemula, melanjutkan alur A0 normal. |
| **Level 21 – 40** | **Phase 1 (A1)** | 40 | Di-grant A1 gratis (hemat 3 Boss Remnant). |
| **Level 41 – 50** | **Phase 2 (A2)** | 50 | Di-grant A2 gratis. |
| **Level 51 – 60** | **Phase 3 (A3)** | 60 | Di-grant A3 gratis. |
| **Level 61 – 70** | **Phase 4 (A4)** | 70 | Di-grant A4 gratis. |
| **Level 71 – 80** | **Phase 5 (A5)** | 80 | Di-grant A5 gratis. |
| **Level 81 – 90** | **Phase 6 (A6)** | 90 | Di-grant A6 gratis. |

### 4.2 Penanganan Pemain yang Levelnya > 90 (Overleveled Legacy)
Jika ada pemain lama yang memanfaatkan sistem tanpa cap sebelumnya hingga mencapai Level $> 90$ (misal Level 98):
1. **Level Di-clamp Aman ke 90:** Karakter disetel ke Level 90 (Max Level) dan Fase A6.
2. **Kompensasi "Aether Legacy Gift":**
   Kelebihan EXP di atas Level 90 tidak dibuang begitu saja, melainkan dikonversi menjadi paket kompensasi resmi di dalam inventaris atau pesan selamat datang:
   $$\text{Bonus Gold} = (\text{Level Lama} - 90) \times 5.000$$
   $$\text{Bonus Aether Shard} = (\text{Level Lama} - 90) \times 20$$
   $$\text{Bonus Soul Prism} = \lfloor(\text{Level Lama} - 90) / 10\rfloor$$
   Pemain lama merasa dihargai atas dedikasi bermain mereka sebelumnya.

### 4.3 Pemetaan Cycle Rank Lama
* Jika pemain memiliki `cycle_rank <= 5`: Nilai rank dipertahankan apa adanya.
* Jika pemain memiliki `cycle_rank > 5`: Nilai rank disetel ke **5 (Peak World Tier)**, status tamat *Aether Ascendant* langsung terbuka, dan seluruh Dungeon 1–6 terbuka penuh.

### 4.4 Migrasi Database Drift v10 $\rightarrow$ v11
* Tambah kolom `ascension_phase INTEGER NOT NULL DEFAULT 0` pada tabel `players`.
* Skrip migrasi menghitung nilai awal `ascension_phase` berdasarkan kolom `level` eksisting.
* Buat tabel baru `infinite_spire_progress` (player_id, highest_floor, claimed_floors_blob).
* Buat test suite migrasi komprehensif `test/data/m16_stage1_ascension_schema_and_migration_test.dart` yang menguji save data v1 s/d v10 dengan data terisi nyata.

---

# 5. KONTEN BARU: DUNGEON 6 & THE INFINITE SPIRE

### 5.1 Dungeon 6 — The Abyssal Rift
* **Biome:** Jurang Kehampaan / Kristal Void Ungu Gelap.
* **Struktur:** 4 Ruangan Tempur + 1 Ruang Bos (Total 5 Room).
* **Musuh Biasa:** `void_larva`, `abyssal_weaver`, `shadow_stalker`.
* **Bos Dungeon:** `abyssal_archon` (Bos berukuran besar dengan serangan Void Nova dan barrier sementara).
* **Tier Perlengkapan Baru (T6 - Abyssal Set):** Senjata & armor Tier 6 (Rarity Epic & Legendary) dengan stat dasar lebih tinggi dari T5.
* **Drop Spesial:** `abyssal_remnant` (100% dari bos) & `void_essence` (drop langka 20%).

### 5.2 The Infinite Spire (Tower of Trials)
* **Akses:** Gedung/Portal baru di Town Hub.
* **Mekanisme Tantangan:**
  * Terdiri dari Lantai 1 sampai 100+ (bertahap).
  * Pemain memanjat lantai demi lantai; pertempuran berbasis arena tunggal.
  * Setiap 10 lantai adalah *Boss Floor* (Lantai 10: Goblin Chief + Minion, Lantai 50: Dual Boss, Lantai 100: Abyssal Emperor).
* **Sistem Hadiah (First-Clear Reward):**
  * Hadiah hanya dapat diklaim satu kali per lantai seumur hidup.
  * Menghasilkan Gold, Aether Scrap, Aether Shard, dan Soul Prism.
* **Independen dari Auto Farming:** Tidak memotong jatah waktu 8 jam offline farming reguler.

---

# 6. PENUTUP & KESEPAKATAN DESAIN

Rancangan ini menyempurnakan siklus hidup game:
1. Menghadirkan batas akhir yang membanggakan (Level 90 MAX, Rank 5 Peak).
2. Mempertahankan seluruh 1.008 test dan formula balancing yang sudah ada.
3. Memberikan perlindungan dan hadiah kompensasi yang adil bagi pemilik save data lama.
