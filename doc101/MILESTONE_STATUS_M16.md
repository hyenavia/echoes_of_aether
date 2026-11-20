# ECHOES OF AETHER

## MILESTONE STATUS TRACKER — M16 (HERO ASCENSION, DUNGEON 6 & THE INFINITE SPIRE)

**Project:** Echoes of Aether  
**Document Version:** 1.0  
**Last Updated:** 2026-11-20  
**Current Milestone:** M16 — Hero Ascension, World Rank Cap, Dungeon 6 & The Infinite Spire  
**Overall Status:** M1–M16 COMPLETED  

> Dokumen ini melanjutkan `MILESTONE_STATUS_M15.md`. Simpan berdampingan di folder `doc101/`. Seluruh Update Rules dan konvensi arsitektur tetap berlaku.

**Baseline saat ini:** `flutter test` = 1.061 lulus (0 gagal), `flutter analyze` = 0 issue, Drift `schemaVersion = 11`.

---

# 1. M16 — HERO ASCENSION, WORLD RANK CAP, DUNGEON 6 & THE INFINITE SPIRE

**Status:** COMPLETED (Disetujui Pemilik Project — 2026-11-20)

### Stage 1 — Data Layer & Migrasi: Drift Schema v11, Config JSON & Legacy Save
- [x] Set `"max_level": 90` dan tambahkan skema konfigurasi `"hero_ascension"` di `game_config.json`.
- [x] Buat file konfigurasi `assets/data/infinite_spire.json` (lantai 1 s/d 100+ & hadiah first-clear).
- [x] Buat domain entities: `HeroAscensionPhaseDefinition`, `HeroAscensionCost`, `InfiniteSpireFloorDefinition`.
- [x] Migrasi database Drift v10 $\rightarrow$ v11:
  - [x] Tambah kolom `ascension_phase` pada tabel `players`.
  - [x] Tambah tabel `infinite_spire_progress`.
  - [x] Logika konversi cerdas data pemain lama: pemetaan otomatis level lama ke fase A0..A6 tanpa biaya material.
  - [x] Logika clamp untuk level $> 90$ dan pemberian kompensasi *Aether Legacy Gift*.
  - [x] Clamp `cycle_rank > 5` ke Rank 5 (Peak World Tier).
- [x] Test migrasi komprehensif Drift v10 $\rightarrow$ v11 dengan data riil (`test/data/m16_stage1_ascension_schema_and_migration_test.dart`).

### Stage 2 — Domain Layer: Hero Ascension Service, Cap Logic & Rank 5 World Cap
- [x] Implementasi `HeroAscensionService` (`canAscend`, `ascendHero`, validasi material konsumsi).
- [x] Integrasi batas perolehan EXP di `ProgressionService` saat menyentuh level cap fase aktif.
- [x] Integrasi bonus stat terobosan di `DerivedStatsCalculator` (paritas online & offline).
- [x] Kunci siklus dunia di `maxRank = 5` pada `DungeonProgressionService` & kalibrasi `DifficultyService`.
- [x] Suite unit test domain untuk Hero Ascension dan Rank 5 cap.

### Stage 3 — Content Expansion: Dungeon 6 (The Abyssal Rift), Boss & T6 Gear
- [x] Tambah definisi `abyssal_rift` di `assets/data/dungeons.json` & peta layout di `dungeons.json` (`"maps"`).
- [x] Tambah monster `abyssal_crawler`, `void_weaver`, `shadow_stalker` & bos `abyssal_archon` di `monsters.json`.
- [x] Tambah 8 perlengkapan Tier 6 di `assets/data/items.json`.
- [x] Daftarkan drop `abyssal_remnant` dan `void_essence` di `loot_tables.json`.
- [x] Daftarkan sprite mapping perlengkapan T6 di `item_sprite_registry.dart` dan normalisasi biome di `pixel_sprite_atlas.dart`.
- [x] Verifikasi simulasi tempur D6 di `BalanceSimulator` untuk 10 class dan headless simulation run.

### Stage 4 — End-Game Mode: The Infinite Spire (100 Floors & First-Clear Rewards)
- [x] Implementasi `InfiniteSpireService` (pemrosesan lantai 1..100, tantangan bos per 10 lantai).
- [x] Sistem klaim hadiah first-clear atomik & idempoten.
- [x] Persistensi status lantai tertinggi dan hadiah di Drift SQLite.
- [x] Suite test unit untuk mekanisme Infinite Spire.

### Stage 5 — Presentation Layer, Balance Verification & Full Regression Pass
- [x] UI tombol & dialog "Terobosan" (Ascend) di `CharacterOverlay`.
- [x] UI akses The Infinite Spire dan pemilih lantai di `TownHubView`.
- [x] Jalankan `dart format` pada seluruh file baru/diubah.
- [x] Jalankan `flutter analyze` (target 0 issues).
- [x] Jalankan full regression suite `flutter test` (memastikan seluruh 1.008+ test lulus).

---

# 2. DEVELOPMENT LOG — M16

### 2026-11-20 — Stage 5 Selesai: Presentation Layer, Balance Verification & Full Regression Pass
- Mengimplementasikan [HeroAscensionDialog](file:///e:/myLittleProject/echoes_of_aether/lib/features/dungeon/hero_ascension_dialog.dart):
  - Menampilkan pratinjau transisi fase (`Fase A0` $\rightarrow$ `Fase A1`), peningkatan batas level (`Lv 20` $\rightarrow$ `Lv 40`), breakdown bonus atribut (+HP, +ATK, +DEF, dsb.), checklist biaya Gold & material konsumsi (dengan indikator status tercukupi/kurang), tombol konfirmasi terobosan, serta layar selebrasi terobosan (*Ascended!*) dan tampilan fase maksimal (*A6 - MAX POTENTIAL REACHED*).
- Mengimplementasikan [InfiniteSpireOverlay](file:///e:/myLittleProject/echoes_of_aether/lib/features/dungeon/infinite_spire_overlay.dart):
  - Menampilkan daftar 100 lantai lengkap dengan status *SELESAI* (Centang emas), *TERBUKA* (Tombol 'Tantang'), atau *TERKUNCI* (Gembok).
  - Penanda khusus Lantai Bos per 10 lantai (L10..L90) dengan nama bos terkalibrasi dan Lantai Puncak (L100: Apex Aether Sovereign).
  - Fitur Filter "Bos Saja" untuk mempermudah navigasi lantai bos dan milestone hadiah first-clear.
  - Ringkasan total penyelesaian (*Selesai: X / 100 Lantai*).
- Mengintegrasikan UI pada `CharacterOverlay`:
  - Menambahkan tombol aksi *TEROBOSAN!* (glow emas) saat karakter mencapai level cap fase aktif dan memenuhi syarat terobosan.
  - Menampilkan badge fase (*Fase A0..A5* atau *A6 (MAX)* dengan status aura emas) pada bagian trailing banner profil hero tanpa mengganggu tata letak visual layar.
  - Mengetuk tombol atau badge membuka dialog `HeroAscensionDialog`.
- Mengintegrasikan UI akses cepat pada `TownHubView`:
  - Menambahkan tombol *quick access* `quick_access_infinite_spire` ("Spire", "100 Lantai") pada quick access strip Town Hub.
  - Menghubungkan pembukaan `InfiniteSpireOverlay` dan meneruskan callback eksekusi terobosan hero.
- Mengintegrasikan orkestrasi sesi pada `DungeonScreen` & `GameSessionCoordinator`:
  - `GameSessionCoordinator.startInfiniteSpireRun`: inisialisasi runtime dungeon arena 1-ruangan via `dungeonManager.startRuntimeDungeon` dan penyimpanan snapshot sesi.
  - `GameSessionCoordinator.executeHeroAscension`: eksekusi atomik mutasi Gold, item material, saldo currency, pembaruan fase karakter, persistensi database, serta garansi *in-memory state rollback* jika terjadi kegagalan penyimpanan.
  - `DungeonScreen._handleDungeonCompleted`: penyelesaian hadiah first-clear The Infinite Spire secara atomik via `coordinator.settleInfiniteSpireVictory` dan tampilan ringkasan hasil kemenangan dungeon.
- Menambahkan unit dan widget test suite baru [test/features/m16_stage5_ascension_and_spire_ui_test.dart](file:///e:/myLittleProject/echoes_of_aether/test/features/m16_stage5_ascension_and_spire_ui_test.dart) (12 test menyeluruh mencakup HeroAscensionDialog, CharacterOverlay button & badge, InfiniteSpireOverlay filtering & boss floor, TownHubView quick access button, runtime dungeon launch, dan atomic ascension rollback).
- Memverifikasi regresi penuh proyek:
  - `dart format` dijalankan pada seluruh berkas baru dan yang dimodifikasi.
  - `flutter analyze` = 0 issues (bersih).
  - `flutter test` = 1.061 test lulus (0 gagal) di seluruh rangkaian test suite.
- Baseline: `flutter test` = 1.061 lulus (0 gagal), `flutter analyze` = 0 issue, Drift `schemaVersion = 11`.
- Menambahkan `DungeonKind.infiniteSpire` ke enum `DungeonKind` di [dungeon_definition.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/entities/dungeon_definition.dart) beserta helper getter `isInfiniteSpire`, serta memperbarui exhaustive switches di parser [dungeon_config_parser.dart](file:///e:/myLittleProject/echoes_of_aether/lib/data/models/dungeon_config_parser.dart), [dungeon_progression_service.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/dungeon_progression_service.dart), [offline_dungeon_runner.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/offline_dungeon_runner.dart), [offline_progression_service.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/offline_progression_service.dart), dan test suite [boss_event_service_test.dart](file:///e:/myLittleProject/echoes_of_aether/test/domain/boss_event_service_test.dart).
- Mengimplementasikan [InfiniteSpireService](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/infinite_spire_service.dart):
  - `canChallengeFloor(int floorNumber, InfiniteSpireProgressSnapshot progress)`: penegakan progresi sekuensial (lantai 1 selalu terbuka, lantai <= highestCleared + 1 terbuka, lantai yang sudah ditamatkan dapat diakses untuk latihan, nomor lantai di luar 1..100 ditolak).
  - `buildFloorDungeon({required int floorNumber, required List<String> arenaLayout})`: dynamic 1-room arena runtime generation (`DungeonKind.infiniteSpire`, order: floorNumber, recommendedLevel: floor.recommendedLevel). Untuk boss floor (kelipatan 10), bos utama ditempatkan di `(17, 6)` dengan `isBoss: true, required: true`, minion pendamping di sekitarnya, serta condition `defeatBoss`. Lantai 100 menggunakan biome `abyssal_rift`. Untuk lantai normal, musuh reguler disebar pada grid walkable dengan condition `defeatRequiredEnemies`.
  - `settleFloorVictory`: penyelesaian first-clear rewards (Gold, EXP, Items, Currencies termasuk `aether_shard` dan `soul_prism` dengan namespacing claim ID atomik). Kemenangan kedua kali pada lantai yang sudah selesai bersifat idempoten (tidak ada duplikasi hadiah). Status `highestFloorCleared` dan `claimedFloorRewards` diperbarui secara atomik.
  - `resolveArenaLayout(GameConfig config)`: resolusi fallback map layout dari `dungeons.json` maps.
- Mendaftarkan Riverpod provider `infiniteSpireServiceProvider` di [game_config_provider.dart](file:///e:/myLittleProject/echoes_of_aether/lib/application/providers/game_config_provider.dart).
- Mengintegrasikan [GameSessionCoordinator](file:///e:/myLittleProject/echoes_of_aether/lib/application/services/game_session_coordinator.dart):
  - Memperbarui `LoadedGameSession` dan `saveFromRuntime` untuk memuat dan menyimpan `infiniteSpireProgress` serta persistensi prefix `'infinite_spire:'` ke database Drift SQLite.
  - Mengimplementasikan `prepareInfiniteSpireRun` dan `settleInfiniteSpireVictory` lengkap dengan in-memory state rollback safety jika terjadi kegagalan persistensi ke storage.
- Menegakkan Offline Farming Guard: `OfflineDungeonRunner` dan `OfflineProgressionService` secara ketat menolak `DungeonKind.infiniteSpire` (`OfflineDungeonStopReason.invalidSetup` / `OfflineProgressionStatus.noEligibleEncounter`) sehingga The Infinite Spire murni manual play dan tidak memotong anggaran offline farming 8 jam.
- Menambahkan unit test baru [test/domain/m16_stage4_infinite_spire_service_test.dart](file:///e:/myLittleProject/echoes_of_aether/test/domain/m16_stage4_infinite_spire_service_test.dart) (11 unit test menyeluruh mencakup validasi 100 lantai, canChallengeFloor, runtime arena generation, settlement first-clear atomik & idempoten, coordinator rollback safety, Drift persistence reload, dan offline farming guard).
- Baseline: `flutter test` = 1.049 lulus (0 gagal), `flutter analyze` = 0 issue, Drift `schemaVersion = 11`.

### 2026-11-20 — Stage 3 Selesai: Content Expansion: Dungeon 6 (The Abyssal Rift), Boss & T6 Gear
- Mendaftarkan Dungeon 6 `abyssal_rift` di [assets/data/dungeons.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/dungeons.json) (order: 6, recommendedLevel: 65, difficultyScale: 4.5, 5 rooms sekuensial, completion reward: EXP 450, Gold 220, loot: `abyssal_clear_loot`).
- Mendaftarkan 5 layout ruangan khusus di `"maps"` dari `dungeons.json`: `abyssal_entrance_map`, `abyssal_chasm_map`, `abyssal_depths_map`, `abyssal_sanctum_map`, `abyssal_core_map`.
- Memperbarui `ascension_sanctum` dari order 6 menjadi order 7 untuk menjaga sekuens integritas order tanpa duplikat / celah (`GameConfigValidator`).
- Mendaftarkan 4 monster baru di [assets/data/monsters.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/monsters.json): `abyssal_crawler` (Lv 60), `void_weaver` (Lv 62), `shadow_stalker` (Lv 65 elite), dan `abyssal_archon` (Lv 68 dungeon boss, Base HP 2.800, Base ATK 35, Base DEF 10, `is_final_boss: false`).
- Mendaftarkan 8 item perlengkapan Tier 6 (Abyssal Set) di [assets/data/items.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/items.json): 4 Epic (`abyssal_blade`, `abyssal_bow`, `abyssal_staff`, `abyssal_cowl`) dan 4 Legendary (`void_cleaver`, `void_carapace`, `void_crown`, `abyssal_eye`) dengan stat di atas Tier 5 dan fixed stat roll bonus.
- Mendaftarkan 4 loot table di [assets/data/loot_tables.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/loot_tables.json): `abyssal_normal_loot`, `abyssal_elite_loot`, `abyssal_boss_loot`, dan `abyssal_clear_loot` (dengan drop bergaransi 100% `abyssal_remnant` dan 20% `void_essence`).
- Mendaftarkan sprite mapping seluruh 8 item T6 di [ItemSpriteRegistry](file:///e:/myLittleProject/echoes_of_aether/lib/features/shared/assets/item_sprite_registry.dart) dan normalisasi biome `abyssal_rift` di [PixelSpriteAtlas](file:///e:/myLittleProject/echoes_of_aether/lib/game/visuals/pixel_sprite_atlas.dart).
- Memperbarui isolasi perlengkapan T6 di `tool/src/balance_simulator.dart` (`_isAbyssalTierItem`, `isAbyssal: dungeon.order >= 6`) agar dungeon D1..D5 dan boss event tidak terdistorsi kalibrasinya.
- Menambahkan test suite konten baru [test/domain/m16_stage3_dungeon6_content_test.dart](file:///e:/myLittleProject/echoes_of_aether/test/domain/m16_stage3_dungeon6_content_test.dart) (8 test komprehensif mencakup validasi config, struktur graph 5 room, monster & boss, gear T6, loot drops, dan headless combat simulation run).
- Menyesuaikan regression test lama: `test/data/stage5_five_dungeons_content_test.dart` (mencakup 6 normal dungeon), `test/domain/ascension_dungeon_stage2_test.dart` (`order` Ascension Sanctum = 7), `test/balance/balance_simulator_test.dart` (42 rows rank safety, isolasi gear T1..T5), `test/balance/economy_qa_test.dart` (6 normal dungeon), dan `test/features/ascension_stage2_ui_test.dart` (label title '7. Ascension: Aether Sanctum').
- Baseline: `flutter test` = 1.038 passed, `flutter analyze` = 0 issues, Drift `schemaVersion = 11`.

### 2026-11-20 — Stage 2 Selesai: Domain Layer Hero Ascension & Rank 5 Peak World Tier
- Mengimplementasikan [HeroAscensionService](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/hero_ascension_service.dart) dengan dukungan evaluasi kelayakan terobosan (`canAscend`), eksekusi transaksi atomik konsumsi material (`ascendHero`), serta helper snapshot (`ascendSnapshot`).
- Menambahkan metode akumulasi stat terobosan `cumulativeStatBoostForPhase` dan status aura emas `hasGoldenAuraForPhase` pada [HeroAscensionConfig](file:///e:/myLittleProject/echoes_of_aether/lib/domain/entities/hero_ascension.dart).
- Mengintegrasikan logika level capping dan batas EXP di [ProgressionService](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/progression_service.dart): karakter pada level cap fase aktif tidak bisa naik level sebelum melakukan terobosan, sisa EXP dibatasi pada 100% (`isAscendReady`), dan pada Level 90 (A6 / Hard Cap) EXP disetel ke 0.
- Mengintegrasikan bonus atribut terobosan ke dalam [DerivedStatsCalculator](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/derived_stats_calculator.dart) dan [PlayerCharacter](file:///e:/myLittleProject/echoes_of_aether/lib/domain/entities/player_character.dart) (100% paritas online dan offline).
- Mengunci siklus dunia pada Rank 5 (`kPeakWorldRank = 5`) di [DungeonProgressionService](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/dungeon_progression_service.dart), [AscensionService](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/ascension_service.dart), dan [CycleProgress](file:///e:/myLittleProject/echoes_of_aether/lib/domain/entities/cycle_progress.dart). Menamatkan Ascension Dungeon pada Rank 5 tidak lagi mereset dungeon normal (`clearedInCycleRank` tetap utuh), menyematkan status *Peak World Tier* dan gelar *Aether Ascendant*.
- Menambahkan Riverpod provider `heroAscensionServiceProvider` di `game_config_provider.dart` dan menyambungkan konfigurasi terobosan di `GameSessionCoordinator`.
- Menambahkan unit test baru [test/domain/m16_stage2_hero_ascension_service_test.dart](file:///e:/myLittleProject/echoes_of_aether/test/domain/m16_stage2_hero_ascension_service_test.dart) (15 unit test baru, seluruhnya lulus).
- Baseline: `flutter test` = 1.030 passed, `flutter analyze` = 0 issues, Drift `schemaVersion = 11`.

### 2026-11-20 — Stage 1 Selesai: Data Layer & Migrasi Drift Schema v11
- Mengonfigurasi `assets/data/game_config.json`: menetapkan `"max_level": 90` dan menambahkan konfigurasi `"hero_ascension"` (A0 s/d A6 lengkap dengan stat boost, cost material, dan level cap per fase).
- Mendaftarkan item material terobosan `abyssal_remnant` dan `void_essence` di `assets/data/items.json` dan sprite registry `ItemSpriteRegistry`.
- Membuat `assets/data/infinite_spire.json` dengan 100 lantai lengkap, rekomendasi level terkalibrasi, bos per 10 lantai dengan modifier affix, dan hadiah first-clear terstruktur.
- Membuat domain entities: `HeroAscensionPhaseDefinition`, `HeroAscensionCost`, `HeroAscensionStatBoost`, `HeroAscensionConfig`, `HeroAscensionState`, `InfiniteSpireFloorDefinition`, `InfiniteSpireReward`, `InfiniteSpireConfig`, dan `InfiniteSpireProgressSnapshot`.
- Mengimplementasikan `InfiniteSpireConfigParser` dan parser/validator ekstensi di `GameConfigParser`, `GameConfigValidator`, dan `GameConfigRepository`.
- Memperbarui domain snapshot: menambahkan `ascensionPhase` di `PlayerProgress` dan `infiniteSpireProgress` di `PlayerSaveSnapshot`.
- Memperbarui `SaveSnapshotCodec`: kanonisasi dan validasi field M16 untuk serialisasi save data.
- Migrasi database Drift dari schemaVersion 10 ke 11:
  - Menambahkan kolom `ascension_phase` pada tabel `players`.
  - Menambahkan tabel `infinite_spire_progress`.
  - Mengonversi data legacy: pemetaan level lama ke fase A0..A6 secara adil tanpa memotong level, clamping level > 90 ke 90 dengan paket kompensasi *Aether Legacy Gift* (Gold, Soul Shard, Soul Prism proporsional), dan clamping cycle rank > 5 ke 5.
- Memperbarui `DriftPlayerSaveRepository` untuk mendukung persistensi `ascensionPhase` dan `infiniteSpireProgress`.
- Menambahkan suite test migrasi menyeluruh `test/data/m16_stage1_ascension_schema_and_migration_test.dart` (7 unit test baru).
- Baseline: `flutter test` = 1.015 passed, `flutter analyze` = 0 issues, Drift `schemaVersion = 11`.

### 2026-11-20 — Perancangan Milestone 16 Selesai
- Menyusun dokumen spesifikasi desain [DESIGN_ADDENDUM_v1.5_HERO_ASCENSION_AND_SPIRE.md](file:///e:/myLittleProject/echoes_of_aether/doc101/DESIGN_ADDENDUM_v1.5_HERO_ASCENSION_AND_SPIRE.md).
- Menyusun roadmap resmi [MASTER_DEVELOPMENT_ROADMAP_M16.md](file:///e:/myLittleProject/echoes_of_aether/doc101/MASTER_DEVELOPMENT_ROADMAP_M16.md).
- Menetapkan skema migrasi cerdas dan rebalance perlindungan data pemain lama (pemetaan level lama ke A0..A6, clamping level > 90 dengan paket kompensasi Aether Legacy Gift, dan clamping rank > 5).
- Baseline: `flutter test` = 1.008 passed, `flutter analyze` = 0 issues, Drift `schemaVersion = 10`.
