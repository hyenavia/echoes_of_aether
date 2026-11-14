# ECHOES OF AETHER

## MILESTONE STATUS TRACKER — LANJUTAN (M8–M11)

**Project:** Echoes of Aether
**Document Version:** 2.24
**Last Updated:** 2026-11-14
**Current Milestone:** M8–M11 — COMPLETED
**Overall Status:** M1–M11 COMPLETED (seluruh test lulus, `flutter analyze` 0 issue, APK release teruji lancar di perangkat Android pengguna)

> Dokumen ini melanjutkan `MILESTONE_STATUS.md` v1.17. Gabungkan ke file tersebut atau simpan berdampingan di `docs/`. Seluruh Update Rules v1 (§8) tetap berlaku.

---

# 1. PROJECT OVERVIEW

| Milestone | Name                                    | Status                                                                                |
| --------- | --------------------------------------- | ------------------------------------------------------------------------------------- |
| M1–M7     | Foundation sampai Polish & Optimization | Completed (366 test, 0 analyze issue, APK terverifikasi)                              |
| M8        | Multi-Dungeon & Difficulty              | Completed (Stage 1–6 selesai + teruji di perangkat Android)                           |
| M9        | Ascension Cycle                         | Completed (Stage 1–5 + BAL-M9-01 Resolved + teruji di perangkat Android)              |
| M10       | Shop & Economy                          | Completed (Stage 1–4 selesai + teruji di perangkat Android)                           |
| M11       | UI Revamp Idle RPG                      | Completed (Stage 1–5 selesai + teruji di perangkat Android)                           |

**Status Definitions:** NOT STARTED, IN PROGRESS, BLOCKED, READY FOR REVIEW, COMPLETED. Sebuah milestone hanya COMPLETED jika seluruh acceptance criteria terpenuhi dan terverifikasi.

**Baseline pengukuran:** `flutter test` = 497 lulus (baseline 366), `flutter analyze` = 0 issue, Drift `schemaVersion = 3`.

---

# 2. M8 — MULTI-DUNGEON & DIFFICULTY

**Status:** Completed

### Stage 1 — Rumus Damage Rasio

- [x] Audit titik damage (`DamageCalculator`, `CombatSimulation`, `OfflineDungeonRunner`)
- [x] Konfigurasi `damage.formula` + parser + validator
- [x] Implementasi rasio; mode `subtractive` untuk regresi
- [x] Satu instance kalkulator dari konfigurasi untuk online dan offline
- [x] Test nilai, monotonisitas, batas, nilai besar
- [x] Test paritas online/offline
- [x] Daftar test lama yang diubah dan alasannya

### Stage 2 — Level Tanpa Batas

- [x] Audit semua titik `maxLevel`
- [x] `max_level` opsional di config dan `ProgressionConfig`
- [x] Kurva EXP polinomial + clamp
- [x] Hapus reset EXP pada level maksimum (bila tanpa batas)
- [x] Batas iterasi level-up dengan carry EXP
- [x] Perbaikan `DriftPlayerSaveRepository` dan `PlayerCharacter.restore`
- [x] `NumberFormatter` dan penerapan di UI
- [x] Test save lama level ≤ 30, level sangat besar, offline multi-level

### Stage 3 — Skema Data dan Layanan Kesulitan

- [x] Field baru `dungeons.json` / `monsters.json` + parser + validator
- [x] Blok `difficulty` di `game_config.json`
- [x] `DifficultyService`
- [x] `DungeonProgressionService`
- [x] Penerapan pengali stat di `EncounterTracker`
- [x] Penerapan pengali reward di jalur online dan offline
- [x] Test paritas online/offline

### Stage 4 — Runtime Multi-Dungeon dan Migrasi v3

- [x] Hapus `defaultDungeonId`; state dungeon terpilih
- [x] Drift v3: `CycleProgresses`, `clearedInCycleRank`
- [x] Migrasi dari v2 + test data nyata
- [x] Pemilih dungeon fungsional di Town (terkunci/terbuka, level rekomendasi)
- [x] Unlock berurutan dan persistensi
- [x] Pemilih target Auto Farming per dungeon
- [x] Test unlock, persistensi, recovery sesi

### Stage 5 — Konten 5 Dungeon

- [x] `sprite_ref`, `sprite_tint`, `is_final_boss` di render dan parser
- [x] 4 dungeon baru (room memakai ulang map)
- [x] Monster normal, elite, boss per dungeon
- [x] Final Boss di Dungeon 5
- [x] Loot table dan completion reward per dungeon
- [x] Validator konfigurasi lulus; test memuat seluruh dungeon

### Stage 6 — Simulator Balancing dan QA

- [x] Simulator di `test/balance/` + `tool/balance_report.dart`
- [x] Target win rate tercapai di rank 0
- [x] Level rekomendasi final diisi ke data
- [x] `flutter analyze` 0 issue, seluruh test hijau
- [x] APK terverifikasi di perangkat (dikonfirmasi berjalan lancar di perangkat Android pengguna)

---

# 3. M9 — ASCENSION CYCLE

**Status:** Completed

### Stage 1 — Domain Siklus

- [x] `CycleProgress`, `AscensionService`
- [x] Resolusi Farm Dungeon dan titik respawn
- [x] Persistensi rank dan Farm Dungeon
- [x] Test idempotensi dan reset siklus

### Stage 2 — Ascension Dungeon

- [x] Parser `kind: ascension` + `base_dungeon_id` (`ascension_sanctum` & `ascension_clear_loot` ditambahkan dan lolos `GameConfigValidator`)
- [x] Pengali kesulitan memakai `cycleRank`, tersimpan di snapshot run (`DungeonSession.cycleRank` & `ActiveDungeonSessionSnapshot.cycleRank` + Drift JSON persistensi)
- [x] Manual-only: tolak Auto Farming, paksa Pause offline (`OfflineProgressionService`, `OfflineDungeonRunner`, `GameSessionCoordinator`, `TownHubView`, `DungeonScreen` + syarat `canEnterAscension` & tampilan `Rekomendasi Lv`)
- [x] Test recovery sesi di tengah Ascension (`ascension_dungeon_stage2_test.dart` & `ascension_stage2_ui_test.dart`)

### Stage 3 — Alur Penyelesaian dan Respawn

- [x] Penyelesaian: rank +1 sekali, reset clear siklus, reward ascension (`AscensionService.complete`, `RewardProcessor` key `ascension:{runId}` + `dungeon_clear:{runId}`, `clearedInCycleRank = -1`, `clearsCount` terjaga, respawn ke `forgotten_forest`, idempoten pasca restart di overlay)
- [x] Kekalahan tanpa hukuman, titik kembali = dungeon normal terakhir (`ascensionRank` & confirmed loot utuh saat kalah di Ascension, respawn ke `lastNormalDungeonId`; kalah di dungeon normal tetap ke dungeon tersebut; Offline Auto Farming tetap memakai `OfflineFailurePolicy.stopOnDefeat`)
- [x] Saran turun dungeon setelah kekalahan beruntun (`consecutiveDefeats` & `lastFailedDungeonId` di `GameSessionSnapshot` / `GameSessions.sessionDataJson`, saran di `TownHubView` setelah `farming.death_loop_suggest_after` = 3, reset saat menang)
- [x] Overlay hasil ascension fungsional (`DungeonCompletedOverlay` menampilkan `Ascension Rank X → Rank Y` & menyembunyikan `Run baru`; `RunEndedOverlay` mendukung subtitle respawn)

### Stage 4 — Skala Reward dan Drop per Rank

- [x] Pengali reward per rank
- [x] Peluang drop dan bonus roll per rank dengan batas atas
- [x] Paritas online/offline

### Stage 5 — Balancing Rank dan QA

- [x] Simulator rank 0, 1, 5, 10, 50, 1000 (serta resolusi BAL-M9-01 via Option 1A + Option 2A)
- [x] Tidak ada overflow/NaN/Infinity
- [x] `flutter analyze` 0 issue, seluruh test hijau (`498` lulus / `0` gagal) & build APK release (`build/app/outputs/flutter-apk/app-release.apk`, 55.2MB) berhasil
- [x] APK terverifikasi manual di perangkat Android pengguna (`QA-M9-01` / `QA-M8-01` ditutup)

---

# 4. M10 — SHOP & ECONOMY

**Status:** Completed (Stage 4/4 selesai + teruji di perangkat Android pengguna)

### Stage 1 — Data Shop dan Migrasi v5 (catatan: v4 sudah dipakai oleh Opsi 3 `highest_ascension_rank`)

- [x] `shop.json`, entitas, parser
- [x] Validator (pita harga monoton, rasio jual, penolakan consumable tanpa fungsi gameplay)
- [x] Drift v5 `ShopPurchases` + migrasi + test

### Stage 2 — Logika Beli/Jual dan Requirement

- [x] `ShopService` + evaluator requirement + hasil sealed
- [x] Transaksi atomik dan persistensi
- [x] Batas pembelian
- [x] Test gagal tanpa efek samping, idempotensi, tas penuh

### Stage 3 — UI Shop Fungsional

- [x] Overlay shop beli/jual
- [x] Requirement tampil jelas, konfirmasi item langka, jual massal material
- [x] Integrasi dengan inventory/equipment

### Stage 4 — Balancing Ekonomi dan QA

- [x] Simulator ekonomi
- [x] Uji exploit beli-jual
- [x] `flutter analyze` 0 issue, seluruh test hijau, APK terverifikasi

---

# 5. M11 — UI REVAMP IDLE RPG

**Status:** Completed (Stage 5/5 selesai + teruji lancar di perangkat Android pengguna)

### Stage 1 — Tema dan Komponen

- [x] Token desain dan tipografi
- [x] Komponen bersama (kartu item, bar, tombol, panel)

### Stage 2 — Navigasi dan Town

- [x] Navigasi bawah (Adventure, Hero, Bag, Shop, Settings)
- [x] Top bar (level, EXP, gold, rank)
- [x] Layout Town/Adventure

### Stage 3 — Panel Hero dan Bag

- [x] Hero (stat, specialization, skill)
- [x] Bag (inventory, equipment)

### Stage 4 — Shop, Dungeon Select, HUD, dan Hasil

- [x] Restyle shop
- [x] Pemilih dungeon dengan status dan peringatan
- [x] HUD dungeon
- [x] Overlay hasil dan ascension

### Stage 5 — Polish, Performa, dan QA

- [x] Konsistensi lintas layar
- [x] Verifikasi layout di beberapa ukuran layar
- [x] Perbandingan performa dengan baseline M7
- [x] APK release terverifikasi (`build\app\outputs\flutter-apk\app-release.apk`, 56.9MB; dikonfirmasi berjalan lancar di perangkat Android pengguna)

---

# 6. DEVELOPMENT LOG

| Tanggal    | Milestone/Stage | Catatan                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Test                | Analyze |
| ---------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- | ------- |
| 2026-11-13 | M8 Stage 1      | Rumus damage rasio diimplementasikan terpusat dari GameConfig untuk jalur online dan offline. Mode subtractive dipertahankan untuk regresi.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | 387 lulus / 0 gagal | 0 issue |
| 2026-11-13 | M8 Stage 2      | Level tanpa batas (endless leveling): ProgressionConfig.maxLevel nullable, kurva EXP polinomial 60\*L^1.8, batas iterasi 10.000 dengan carry EXP, Drift & restore clamp ke kTechnicalMaxLevel (1.000.000), NumberFormatter di UI.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | 407 lulus / 0 gagal | 0 issue |
| 2026-11-13 | M8 Stage 3      | Skema data & layanan kesulitan: metadata dungeon (kind, order, recommended_level, unlock_requires_dungeon_id, base_dungeon_id), metadata opsional monster (sprite_ref, sprite_tint hex, is_final_boss), blok difficulty & farming di game_config.json, GameConfigValidator, DifficultyService, DungeonProgressionService, penerapan pengali stat di EncounterTracker serta reward/drop di jalur online (CombatSystem/SettlementService/RewardProcessor) dan offline (OfflineDungeonRunner) dengan paritas penuh & Forgotten Forest identik pra-Stage 3.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | 432 lulus / 0 gagal | 0 issue |
| 2026-11-13 | M8 Stage 4      | Runtime multi-dungeon & migrasi Drift v3: `CycleProgresses` + `DungeonProgresses.clearedInCycleRank` (`from < 3` aman dari v2/v1), `OfflineSummarySnapshot.cycleRank`, penghapusan `DungeonScreen.defaultDungeonId` & isolasi progres per-dungeon di runtime/recovery, pemilih dungeon fungsional di `TownHubView` (terkunci/terbuka/selesai, level rekomendasi, peringatan under-level delta >= 5), unlock berurutan, pemilih & validasi Auto Farming siklus aktif + `resolveFarmDungeonId`, dan penolakan Continue Dungeon pada dungeon ascension -> fallback Pause Progression. Test lama disesuaikan: `database_initialization_test.dart` (`schemaVersion == 3`) serta fixture pre-cleared `clearedInCycleRank: 0` di 6 file test offline/UI M4/M6/M7.                                                                                                                                                                                                                                                                                                                                                                                                                                         | 443 lulus / 0 gagal | 0 issue |
| 2026-11-13 | M8 Stage 5      | Konten 5 dungeon data-driven: render `PixelSpriteAtlas.resolveEnemySpecies` + `parseHexTintColor` & `ColorFilter.mode(..., BlendMode.modulate)` di `CombatantComponent`/`EnemyComponent`/`CombatSystem`, penambahan `crystal_cavern` (order 2, scale 1.5, rec Lv 8), `ancient_crypt` (order 3, scale 2.25, rec Lv 16), `ashen_wasteland` (order 4, scale 3.375, rec Lv 25), dan `aether_sanctum` (order 5, scale 5.0625, rec Lv 35) dengan 5 room reuse map + 20 monster baru + 16 loot table + label `Final Boss` di `DungeonCompletedOverlay` untuk `aether_sovereign` (`is_final_boss: true`). Penyesuaian test lama: `offline_ui_test.dart` memeriksa hilangnya pesan kunci Auto Farming secara spesifik karena card dungeon 3–5 kini muncul di `TownHubView`.                                                                                                                                                                                                                                                                                                                                                                                                                                 | 453 lulus / 0 gagal | 0 issue |
| 2026-11-13 | M8 Stage 6      | Simulator balancing (`tool/src/balance_simulator.dart`, `tool/balance_report.dart`, `test/balance/balance_simulator_test.dart`) & QA akhir M8: penyesuaian `forgotten_forest.recommended_level` dari baseline `1` -> `5` di `assets/data/dungeons.json` (karena Lv 1 Common menghasilkan 0% win rate melawan `ancient_heart_guardian`, sedangkan Lv 5 memberi 100% win rate tanpa menyentuh HP boss `420` atau rumus domain); level rekomendasi final `[5, 8, 16, 25, 35]` memenuhi seluruh target Rank 0 (`>= 85%` di rec, `< 50%` di `-10` clamp Lv 1, `100%` di `+10` dengan damage > 1), safety rank `[0, 1, 5, 10, 50, 1000]` lulus tanpa overflow/NaN/Infinity, serta 8-jam Mode B Auto Farming seluruh dungeon aman & terbatas. Telemetri `finalPlayerHp` & `finalPlayerMaxHp` ditambahkan secara opsional pada `OfflineDungeonRunOutcome`. Build `flutter build apk --release` menghasilkan `build\app\outputs\flutter-apk\app-release.apk` (55.1MB); uji perangkat/emulator Android manual belum berjalan karena tidak ada perangkat `adb` aktif saat `flutter emulators --launch Pixel_7a`. Test Stage 3/5 M8 disesuaikan (`recommendedLevel` `1 -> 5`). M8 ditandai `READY FOR REVIEW`. | 458 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M9 Stage 1      | Domain siklus Ascension: `CycleProgress` (validasi/sanitasi `ascensionRank >= 0`, `hasLastNormalDungeon`, value equality), `AscensionService` (`canEnterAscension` via D5 clear siklus aktif; `complete` idempoten dengan `eventId` `ascension:{runId}` lewat `RewardProcessor`/`claimedEventIds`, reset `clearedInCycleRank = -1` menjaga lifetime `clearsCount` & progres/gear/inventory/skill karakter, guard rank besar termasuk `1000 -> 1001`), `DungeonProgressionService` (`resolveFarmDungeonId` menghormati `cycle.lastNormalDungeonId` yang sudah clear, `recordDungeonEntered` tidak menimpa saat memasuki Ascension, dan `resolveRespawnDungeonId` menjaga titik kembali normal pra-Ascension), serta `CycleProgressRepository` pada `DriftPlayerSaveRepository` + `_saveQueue` & prefix `ascension:` di `GameSessionCoordinator` (`saveCycleProgress`, `saveCycleTransition`, `saveFromRuntime`). | 468 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M9 Stage 2      | Ascension Dungeon (`ascension_sanctum`, `order: 6`, `base_dungeon_id: "aether_sanctum"`, `difficulty_scale: 10.125`, `recommended_level: 49`, `completion_reward`: `exp: 800`, `gold: 400`, `loot_table_id: "ascension_clear_loot"`) & loot table `ascension_clear_loot` ditambahkan dan lolos `GameConfigValidator`. Penambahan `cycleRank` pada `DungeonSession` dan `ActiveDungeonSessionSnapshot` beserta persistensi JSON di `DriftPlayerSaveRepository` (fallback `0` untuk JSON pre-Stage-2 tanpa mengubah `schemaVersion = 3`) dan propagasi recovery pada `DungeonManager.restoreSession`, `OfflineDungeonRunner`, `GameSessionCoordinator`, serta `DungeonScreen` agar difficulty & reward sesi terputus mempertahankan `cycleRank` awal run meski DB `CycleProgress.ascensionRank` berubah. `DungeonScreen._enterDungeon` menegakkan `AscensionService.canEnterAscension` sebelum memulai Ascension Dungeon, dan `TownHubView` menampilkan level rekomendasi Ascension per rank (`Lv 49` Rank 0, `Lv 56` Rank 1) serta memblokir Auto Farming Ascension. Penyesuaian test lama: `test/data/stage5_five_dungeons_content_test.dart` (memfilter `dungeons.where((d) => d.isNormal)` untuk 5 dungeon normal + memverifikasi `ascension_sanctum` terpisah dan mengizinkan `Final Boss` pada `aether_sanctum` maupun varian Ascension-nya) dan `test/balance/balance_simulator_test.dart` (`checkRankSafety` mengikuti `sim.config.dungeons.length` = 6 dungeon x 6 rank = 36 baris aman). | 478 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M9 Stage 3      | Alur penyelesaian Ascension (1x rank +1, reset siklus, reward idempoten, overlay rank), respawn aman pasca-kalah, death loop protection & fix detach listener antar-run. | 485 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M9 Stage 4      | Verifikasi penuh skala reward dan drop per rank (`rewardExponent: 0.85`, `rareChancePerRank: 0.1` max `3.0`, `rollBonusPerRank: 0.02` max `0.5`, bonus roll aditif menjaga sebaran `roll_variance = 0.15`, `Rarity < Rare` tetap unscaled, probabilitas drop ter-clamp `<= 1.0`, identitas Rank 0, paritas penuh antara jalur Headless/Flame Online `EchoesGame` & Offline `OfflineDungeonRunner` Mode A/B + `OfflineProgressionService`, serta penjagaan `activeDifficultyProfile` Rank awal run saat Ascension selesai) lewat 8 test baru pada `test/domain/rank_reward_drop_scaling_test.dart`; tidak diperlukan perubahan `lib/` atau aset JSON karena implementasi Stage 4 sudah terpasang lengkap di domain & runtime. | 493 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M9 Stage 5      | Ekspansi balance simulator (`tool/src/balance_simulator.dart`, `tool/balance_report.dart`, `test/balance/balance_simulator_test.dart`) & `OfflineDungeonRunner.simulateManualRun` untuk mengaudit Ascension Dungeon (`ascension_sanctum`), drop roll bonus (`+2% * rank` cap `+50%` + retensi T5 Legendary lintas siklus), keamanan numerik 36 skenario `[0, 1, 5, 10, 50, 1000]`, serta 8-jam Mode B Auto Farming multi-rank. Hasil empiris: zero overflow/NaN/Infinity di seluruh rank `0..1000`; ditemukan 2 temuan desain yang tidak diubah diam-diam dan diajukan sebagai usulan tuning ke pengguna: (1) `ascension_sanctum` Rank 0 pada `rec = 49` hanya dapat diselesaikan `ranger` (`100%`), sedangkan `vanguard` & `arcanist` `0%` (calibrated min Lv `vanguard` `81`, `arcanist` `66`, `ranger` `42`); (2) formula `rec(d, R) = rec(d, 0) + ceil(8*ln(C(R))/ln(1.5))` hanya bertambah logaritmik (`+61` lv di Rank 50) sementara stat musuh tumbuh linear `C(R) = 1 + 0.4*R` (`21x` di Rank 50), memicu dinding keras mulai D5 Rank 1 (`50%` di formula Lv 42 vs calibrated Lv 50) hingga Rank 50 (`0%` di semua formula; calibrated `D1:146`, `D2:251`, `D3:407`, `D4:639`, `D5:1003`, `Asc:2032`) dengan waktu grind `L^2.8` vs reward `M^0.85`. Build `flutter build apk --release` menghasilkan `build\app\outputs\flutter-apk\app-release.apk` (55.2MB); verifikasi perangkat fisik/emulator pending karena belum ada device `adb` aktif. M9 ditandai `READY FOR REVIEW`. | 497 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M9 Stage 5 (1A+2A) | Penerapan Option 1A & Option 2A (resolusi `BAL-M9-01`): (1) `difficulty.ascension_multiplier` pada `assets/data/game_config.json` & default `DifficultyConfig` / `DungeonConfigParser` diturunkan `2.0 -> 1.35` (`ascension_sanctum.difficultyScale = 6.834375`, rec Lv `49` tetap) sehingga ketiga specialization di Rank 0 lulus `100.0%` (`calMinLv`: `vanguard` `47`, `arcanist` `37`, `ranger` `28`); (2) penambahan field opsional `difficulty.cycle_stat_exponents` (`{hp: 0.25, atk: 0.2, def: 0.18}`) pada `DifficultyConfig`, `GameConfigParser`, `GameConfigValidator`, dan `DifficultyService` sehingga `baseScale` tetap memakai `stat_exponents` M8 sedangkan `C(rank) = 1 + 0.4*rank` memakai `cycle_stat_exponents` (Rank 0 100% identik, D1–D5 & Ascension pada Rank `0, 1, 5, 10, 50` seluruhnya `FormulaWin = 100.0%` dengan `calMinLv <= formulaRec`, zero overflow/NaN/Infinity, serta 8-jam Mode B `Rank 0..1000` `0` gagal). Test disesuaikan mengikuti nilai baru & perilaku `1A+2A`: `stage3_schema_validator_test.dart`, `ascension_dungeon_stage2_test.dart`, `ascension_stage2_ui_test.dart`, dan `balance_simulator_test.dart`, plus unit test baru `cycleStatExponents` di `difficulty_service_test.dart`. Rebuild `flutter build apk --release` menghasilkan `build\app\outputs\flutter-apk\app-release.apk` (55.2MB / 57.831.061 bytes); uji perangkat fisik/emulator Android masih pending. | 498 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M9 Perf + Option B + Hard Lock | (1) **Perbaikan Memory Leak & Frame Drop Android**: mengganti `FlameAudio.play` per-SFX menjadi `AudioPool` reusable + `dispose()` di `AudioService`, cache `TextPainter` (8 bucket opasitas + `dispose()`) di `FloatingTextComponent`, pre-bake static tile/wall/shadow ke `ui.Picture` + `dispose()` di `DebugRoomComponent`, throttle `CombatSystem._publishHud` 10 Hz saat idle dengan flush segera saat ada event combat, serta `hud.dispose()` di `EchoesGame` & `_audioService.dispose()` di `DungeonScreen`; (2) **Option B (NG+ Linear Ladder)**: `cycle_level_step: 44`, `cycle_per_rank: 6.5`, dan `cycle_stat_exponents: {hp: 0.25, atk: 0.22, def: 0.20}` sehingga Rank 1 dimulai di `D1 = Lv 49` (setara `Asc Rank 0 = Lv 49`) dengan `FormulaWin = 100.0%` di seluruh 30 skenario `Rank 0, 1, 5, 10, 50` dan 8-jam Mode B `PASS`; (3) **Hard Lock**: `DungeonProgressionService.requiredLevel` (`1` untuk D1 Rank 0, `recommendedLevel(d, rank)` untuk D2..Asc Rank 0 dan semua dungeon Rank >= 1) + `meetsLevelRequirement`, ditegakkan di `isUnlocked(playerLevel: ...)`, `AscensionService.canEnterAscension(playerLevel: ...)`, `TownHubView`, dan `DungeonScreen`. Test diperbarui + ditambah unit test Option B & Hard Lock (`ascension_dungeon_stage2_test.dart`, `stage3_schema_validator_test.dart`, `rank_reward_drop_scaling_test.dart`, `ascension_stage2_ui_test.dart`, `ascension_stage3_ui_test.dart`, `stage4_dungeon_selector_test.dart`). Rebuild `flutter build apk --release` menghasilkan `build\app\outputs\flutter-apk\app-release.apk` (55.2MB); uji perangkat Android masih pending. | 499 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M9 Opsi 3 (Rank Switcher + D1 Open) | Menjawab temuan uji perangkat (Lv 44 di Rank 1 terkunci di Town): (1) Menambahkan `highestAscensionRank` pada `CycleProgress`, tabel `cycle_progresses` (Drift `schemaVersion = 4` dengan migrasi aman `v3 -> v4` mengisi `highest_ascension_rank = ascension_rank`), `DriftPlayerSaveRepository`, dan `AscensionService.complete` (Ascension di rank bawah memberi reward tanpa menggandakan rank tertinggi atau menghapus progres frontier); (2) Menambahkan kontrol **Rank Switcher** (`Siklus Rank X / Y`, tombol `<` / `>`) di `TownHubView` dan `DungeonScreen._switchCycleRank`, serta `isClearedInCurrentCycle` otomatis menganggap rank `< highestAscensionRank` sudah clear agar pemain bisa turun ke Rank 0 (mis. D5 Rank 0 Lv 35) untuk farming manual/Auto Farming; (3) `DungeonProgressionService.requiredLevel` menjaga D1 (`order == 1 && isNormal`) tetap min `Lv 1` di semua rank (Hard Lock hanya pada `D2..Ascension`). Test baru & migrasi diperbarui; `500/500` lulus, `0` issue analyzer. | 500 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M10 Stage 1 (Data Shop & Drift v5) | Menambahkan domain entities shop (`PurchaseRequirement` sealed, `ShopEntry`, `SellRules`, `ShopCatalog` di `lib/domain/entities/shop_config.dart`), `assets/data/shop.json` (14 equipment MVP; `small_potion`/consumable dikecualikan & ditolak validator karena belum ada fungsi gameplay di `lib/`), `ShopConfigParser`, field `GameConfig.shop`, pemuatan di `AssetGameConfigRepository`, validasi di `GameConfigValidator._validateShop` (referensi item, keunikan ID, pita harga monoton per rarity, `sell_value <= max_sell_ratio * price`, syarat beli valid, tolak consumable), serta tabel Drift `ShopPurchases` + migrasi `schemaVersion = 5` (`if (from < 5)`) + regenerasi `app_database.g.dart`. Test baru `test/data/m10_stage1_shop_schema_migration_test.dart` (`4/4` lulus untuk parse/validate nyata, invalid cases, fresh v5 + `CHECK`, dan migrasi `v3 -> v5` dengan data nyata); `504/504` test lulus, `0` issue analyzer. | 504 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M10 Stage 2 (ShopService & Persistensi Atomik) | Menambahkan `ProgressionService.addGold` + `PlayerCharacter.addGold` (tervalidasi & ter-clamp ke `kMaxGold`, tanpa melewati jalur reward), `ShopService` (`check`, `buy`, `sell`, `sellEquipment`, `sellMaterialBulk`, `effectiveSellUnitPrice` anti-exploit `<= floor(price * maxSellRatio)`, hasil sealed `ShopBuyResult` & `ShopSellResult`, validasi seluruh kondisi sebelum mutasi, idempotensi `actionId`), `ShopPurchaseRepository` + `PlayerSaveSnapshot.shopPurchases` + `LoadedGameSession.shopPurchases`, implementasi atomik `DriftPlayerSaveRepository.saveShopTransaction` (satu transaksi Drift dengan guard `ClaimedRewards` untuk `shop:{actionId}`), dan `GameSessionCoordinator.saveShopTransaction` melalui `_saveQueue`. Ditambah 11 test baru (`test/domain/shop_service_test.dart` dan `test/data/shop_persistence_test.dart`); `515/515` test lulus, `0` issue analyzer. | 515 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M10 Stage 3 (UI Shop Fungsional) | Menambahkan `GameOverlays.shop`, `ShopOverlay` (`lib/features/dungeon/shop_overlay.dart`) dengan tab Beli & Jual yang dibuka dari `TownHubView` (tombol **Toko**), tampilan nama/rarity/stat/harga (`NumberFormatter`), status requirement dengan alasan & tombol beli nonaktif saat syarat belum terpenuhi atau batas tercapai, pesan hasil beli/jual, konfirmasi penjualan item `>= confirmMinRarity` (Rare+), dialog jual massal material (`1`, `1/2`, `Semua`, `-`/`+`), penandaan equipment terpasang tidak dapat dijual, serta integrasi `DungeonScreen` ke `ShopService` & `GameSessionCoordinator.saveShopTransaction` tanpa menyimpan state gameplay di widget. Ditambah 3 widget test pada `test/features/dungeon/shop_overlay_test.dart`; `518/518` test lulus, `0` issue analyzer. | 518 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M10 Stage 4 (Balancing Ekonomi & QA) | Menambahkan `EconomyDungeonMetrics` & `BalanceSimulator.simulateEconomyForRank` di `tool/src/balance_simulator.dart` serta `--economy` di `tool/balance_report.dart` (Rank `0, 1, 5, 10`, online vs 8h Auto Farming + jual loot); menyesuaikan harga `assets/data/shop.json` (Common `1200–1600`, Uncommon `4500–7000`, Rare `25000–30000`, Epic `120000`, Legendary `500000` dengan `sell_value <= 0.4 * price`; target waktu beli Rank 0 D1: Rare `1.06/0.38` jam, Epic `5.10/1.82` jam, Legendary `21.24/7.60` jam; likuidasi loot 8h terukur `<= 43.4%` dari gold langsung Rank 0 dan `< 8%` di Rank 1+); menambahkan `test/balance/economy_qa_test.dart` (3 test: boundedness ekonomi & cap likuidasi, simulasi gagal persistensi & rollback Drift, beli-jual berulang & tas penuh); `flutter analyze` `0` issue, `521/521` test lulus, `flutter build apk --release` sukses (`56.1MB`); uji manual perangkat pending (`QA-M10-01`). | 521 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M11 Stage 1 (Tema & Komponen Bersama) | Menambahkan token desain (`AppColors` palet GDD §14.2 + rarity Common–Legendary, `AppSpacing`, `AppRadius`, `AppElevation` di `lib/app/theme/app_tokens.dart`), `EchoesThemeExtension` & `EchoesTheme.dark()` (`lib/app/theme/echoes_theme.dart`), dan mengaktifkannya di `EchoesApp` (`lib/app/app.dart`). Membangun 9 komponen bersama di `lib/features/shared/widgets/` (`ItemCard`, `StatBar`, `ResourceChip`, `PrimaryButton`, `SecondaryButton`, `PanelFrame`, `SectionHeader`, `LockedBadge`, `RarityLabel` + barrel `shared_widgets.dart`), mendokumentasikan penggunaannya di `doc101/UI_COMPONENTS.md`, dan menerapkannya pada `SettingsOverlay` sebagai contoh tanpa mengubah perilaku. Menambahkan 4 widget test di `test/features/shared/shared_widgets_test.dart` (seluruh rarity, state terkunci, lebar 320dp + skala teks 1.5x tanpa overflow, dan `SettingsOverlay`). `flutter analyze` `0` issue, `529/529` test lulus. | 529 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M11 Stage 2 (Navigasi Bawah, Top Bar, & Layout Town) | Menambahkan `TownTopBar` (`lib/features/dungeon/town_top_bar.dart`: level, bar EXP, gold, Ascension Rank memakai `NumberFormatter`, `PanelFrame`, `StatBar.exp`, `ResourceChip`) dan `TownTab` + `NavigationBar` 5 tab (`Adventure`, `Hero`, `Bag` dengan sub-tab Perlengkapan/Tas, `Shop`, `Settings`) di `TownHubView` (`lib/features/dungeon/town_hub_view.dart`) sambil menjaga seluruh state gameplay, overlay in-dungeon, dan quick-action panel tetap utuh. Memperbaiki scrollabilitas `EquipmentOverlay` & `CharacterOverlay` agar aman pada tinggi layar ringkas di dalam tab. Menambahkan 2 widget test di `test/features/dungeon/town_navigation_test.dart` (navigasi 5 tab menjaga state gameplay & `TownTopBar` angka besar/rank tinggi di `320dp` tanpa overflow); `flutter analyze` `0` issue, `531/531` test lulus. | 531 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M11 Stage 3 (Panel Hero & Bag) | Memperbarui `CharacterOverlay`, `InventoryOverlay`, `EquipmentOverlay`, `equipment_text.dart`, dan `CharacterSnapshot.stats` (opsional di `inventory_views.dart`) memakai komponen bersama Stage 1 (`PanelFrame`, `SectionHeader`, `ResourceChip.gold`, `LockedBadge`, `ItemCard` berwarna per rarity). `CharacterOverlay` kini menampilkan ringkasan `Stat Tempur`, spesialisasi, dan skill tanpa mengubah logika domain; `InventoryOverlay` & `EquipmentOverlay` mendapat opsi pengurutan (`Default`, `Rarity`, `Nama`); `EquipmentOverlay` menampilkan `Perbandingan (<slot>)` (`computeEquipmentStatDeltas` + `formatStatDelta`) saat item tas diketuk. Menambahkan 3 widget test di `test/features/dungeon/hero_bag_stage3_test.dart` (stat/spesialisasi/upgrade/MAX/terkunci + teks panjang di `320dp`, `ItemCard` + `equip/unequip` + perbandingan stat, daftar kosong + urut `Rarity`); `flutter analyze` `0` issue, `534/534` test lulus. | 534 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M11 Stage 4 (Shop, Dungeon Select, HUD, & Hasil) | Restyle `ShopOverlay` (`PanelFrame`, `ResourceChip.gold`, `LockedBadge` untuk requirement/batas), pemilih dungeon berjenjang di `TownHubView` (`PanelFrame`, `SectionHeader`, `LockedBadge`, pengali kesulitan `DifficultyService.profileFor`, peringatan level jauh di bawah rekomendasi, kartu Ascension dengan badge `Ascension` & peringatan `Manual-only`, serta kartu saran kalah beruntun `death_loop_suggestion`), `HudOverlay` (`PanelFrame`, `StatBar` overflow-safe, indikator `ELITE` / `BOSS` / `FINAL BOSS`, skill cooldown opsional `skillCooldownText` di `HudState`), serta 3 overlay hasil (`DungeonCompletedOverlay`, `RunEndedOverlay`, `OfflineSummaryOverlay`) dengan komponen bersama Stage 1 tanpa mengubah aturan domain. Menambahkan 4 widget test di `test/features/dungeon/stage4_ui_revamp_test.dart`; `flutter analyze` `0` issue, `538/538` test lulus. | 538 lulus / 0 gagal | 0 issue |
| 2026-11-14 | M11 Stage 5 (Polish, Performa, & QA Akhir) | Audit UI lintas layar (0 `TODO`/`FIXME`/hardcoded `0xFF` tersisa di `lib/features/`), penambahan `Semantics(button: true, label: label)` pada `PrimaryButton` & `SecondaryButton` (minHeight 44dp), perbaikan overflow 88px di `320dp @ 1.5x` pada `SegmentedButton` sub-tab Bag (`FittedBox`) dan header `ShopOverlay` (`Expanded` + `Align`). Menambahkan 3 test polish/aksesibilitas/performa di `test/features/dungeon/stage5_polish_qa_test.dart` (matriks `320x568 @ 1.5x`, `390x844 @ 1.0x`, `800x600 @ 0.85x` di seluruh tab, minHeight 44dp + Semantics, dan 60 pembaruan `HudOverlay` pada 25 musuh `< 16.6ms` rata-rata/frame). `dart format` 0 berubah, `flutter analyze` `0` issue, `541/541` test lulus, `flutter build apk --release` sukses (`56.9MB`). M11 ditandai `READY FOR REVIEW` (`QA-M11-01` Open untuk uji perangkat Android fisik/emulator). | 541 lulus / 0 gagal | 0 issue |

> **Catatan Schema Migration & Breaking Changes:**
>
> - **Drift v2 -> v3 (M8 Stage 4):** Tabel baru `cycle_progresses` dan kolom `dungeon_progresses.cleared_in_cycle_rank` (default `-1`); migrasi meng-update baris dengan `clears_count > 0` ke `cleared_in_cycle_rank = 0` tanpa menghapus save data pemain.
> - **Auto Farming Gating (M8 Stage 4):** Syarat Auto Farming berubah dari lifetime `clearsCount > 0` menjadi `isNormal && clearedInCycleRank == cycleProgress.ascensionRank`; fixture test M4/M6/M7 diperbarui dengan `clearedInCycleRank: 0` serta teks terkunci siklus di `offline_ui_test.dart`.

# 7. BLOCKERS AND KNOWN ISSUES

| ID       | Deskripsi                                                                                                                                                                                                                                                                                   | Milestone  | Status |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------ |
| QA-M8-01 | Emulator `Pixel_7a` tidak terpasang ke `adb` di lingkungan ini; APK release telah diuji langsung oleh pengguna di perangkat Android dan berjalan lancar. | M8 Stage 6 | Resolved |
| QA-M9-01 | Verifikasi manual perangkat Android untuk alur Ascension telah dikonfirmasi berjalan lancar oleh pengguna. | M9 Stage 5 | Resolved |
| QA-M10-01 | Verifikasi manual perangkat Android untuk alur Shop & Economy telah dikonfirmasi berjalan lancar oleh pengguna. | M10 Stage 4 | Resolved |
| QA-M11-01 | Verifikasi manual perangkat Android untuk seluruh alur UI revamp M11 (`build\app\outputs\flutter-apk\app-release.apk`, `56.9MB`) telah dikonfirmasi berjalan lancar oleh pengguna. | M11 Stage 5 | Resolved |
| BAL-M9-01 | Simulator M9 Stage 5 menunjukkan dua kesenjangan kurva desain: (1) `ascension_sanctum` Rank 0 Lv 49 hanya dilalui `ranger`; (2) formula `rec(d, R)` tertinggal dari scaling `C(R) = 1 + 0.4 * R`. Diselesaikan dengan persetujuan pengguna lewat Option 1A (`ascension_multiplier: 1.35`) + Option 2A (`cycle_stat_exponents: {hp: 0.25, atk: 0.2, def: 0.18}`) — `FormulaWin = 100.0%` di seluruh dungeon `Rank 0..50` dan ketiga kelas Lv 49. | M9 Stage 5 | Resolved |

# 8. TECHNICAL DEBT

| ID       | Deskripsi                                                                         | Asal         | Rencana                                                     |
| -------- | --------------------------------------------------------------------------------- | ------------ | ----------------------------------------------------------- |
| TD-M8-01 | Folder dokumentasi berada di `doc101/` (bukan `docs/` seperti teks rujukan awal). | M8 Orientasi | Tetap gunakan `doc101/` secara konsisten di seluruh M8–M11. |

# 9. CHANGE HISTORY

| Versi | Tanggal    | Perubahan                                                                                                                               |
| ----- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| 2.24  | 2026-11-14 | Penutupan QA Perangkat Android (`QA-M8-01` s/d `QA-M11-01` -> `Resolved`) berdasarkan konfirmasi uji langsung di perangkat Android pengguna; **M8–M11 COMPLETED**. |
| 2.23  | 2026-11-14 | M11 Stage 5 (Polish, Aksesibilitas, Performa, & QA Akhir): `Semantics` pada `PrimaryButton`/`SecondaryButton`, fix overflow `320dp @ 1.5x` di Bag `SegmentedButton` & header `ShopOverlay`, `stage5_polish_qa_test.dart`, `541` test lulus, `0` issue analyzer, APK `56.9MB` sukses; M11 **READY FOR REVIEW** (`QA-M11-01` Open). |
| 2.22  | 2026-11-14 | M11 Stage 4 (Restyle `ShopOverlay`, pemilih dungeon berjenjang + pengali kesulitan + peringatan Ascension manual-only & kalah beruntun di `TownHubView`, `HudOverlay` + `StatBar` overflow-safe + `HudState`, serta `DungeonCompletedOverlay`, `RunEndedOverlay`, `OfflineSummaryOverlay`, & `stage4_ui_revamp_test.dart`); 538 test lulus, 0 issue analyzer. |
| 2.21  | 2026-11-14 | M11 Stage 3 (Restyle Panel Hero & Bag: `CharacterOverlay`, `InventoryOverlay`, `EquipmentOverlay`, `CharacterSnapshot.stats`, perbandingan stat `computeEquipmentStatDeltas`, sort `Default`/`Rarity`/`Nama`, & `hero_bag_stage3_test.dart`); 534 test lulus, 0 issue analyzer. |
| 2.20  | 2026-11-14 | M11 Stage 2 (Navigasi Bawah 5 tab, `TownTopBar`, & layout Town/Adventure di `TownHubView`, plus `town_navigation_test.dart`); 531 test lulus, 0 issue analyzer. |
| 2.19  | 2026-11-14 | M11 Stage 1 (Tema & Komponen Bersama: `app_tokens.dart`, `echoes_theme.dart`, 9 komponen di `lib/features/shared/widgets/`, `UI_COMPONENTS.md`, contoh `SettingsOverlay`, & `shared_widgets_test.dart`); 529 test lulus, 0 issue analyzer. |
| 2.18  | 2026-11-14 | M10 Stage 4 (Balancing Ekonomi & QA): simulator ekonomi (`--economy`), tuning harga `assets/data/shop.json`, uji exploit & rollback Drift (`test/balance/economy_qa_test.dart`), `521` test lulus, `0` issue analyzer, APK `56.1MB` sukses; M10 **READY FOR REVIEW** (`QA-M10-01` Open). |
| 2.17  | 2026-11-14 | M10 Stage 3 (UI Shop Fungsional: `ShopOverlay` tab Beli/Jual, konfirmasi Rare+, jual massal, integrasi Town Hub & `DungeonScreen`); 518 test lulus, 0 issue analyzer. |
| 2.16  | 2026-11-14 | M10 Stage 2 (`ShopService`, `addGold` aman, requirement, dan persistensi transaksi Drift atomik + idempotensi); 515 test lulus, 0 issue analyzer. |
| 2.15  | 2026-11-14 | M10 Stage 1 (Data Shop, Validator, dan Migrasi Drift v5 `ShopPurchases`); `small_potion` dikecualikan (belum ada fungsi gameplay). 504 test lulus, 0 issue analyzer. |
| 2.14  | 2026-11-14 | Opsi 3: Rank Switcher (`0..highestAscensionRank`, Drift schema v4) dan D1 tetap min Lv 1 di semua rank; 500 test lulus, 0 issue analyzer. |
| 2.13  | 2026-11-14 | Perbaikan memory leak & frame drop Android (`AudioPool`, `TextPainter` cache, `ui.Picture` pre-bake, throttle HUD 10 Hz, `dispose`), penerapan Option B (`cycle_level_step: 44`, `cycle_per_rank: 6.5`, `cycle_stat_exponents: 0.25/0.22/0.20`), dan Hard Lock level minimum dungeon; 499 test lulus, 0 issue analyzer, APK 55.2MB direbuild. |
| 2.12  | 2026-11-14 | Resolusi BAL-M9-01 via Option 1A (`ascension_multiplier: 1.35`) & Option 2A (`cycle_stat_exponents`); 498 test lulus, 0 issue analyzer, APK 55.2MB direbuild (`QA-M9-01` perangkat masih Open). |
| 2.11  | 2026-11-14 | M9 Stage 5 (Balancing Rank dan QA) selesai pada level simulator & build APK; M9 READY FOR REVIEW. 497 test lulus, 0 issue analyzer.      |
| 2.10  | 2026-11-14 | M9 Stage 4 (Skala Reward dan Drop per Rank) selesai. 493 test lulus, 0 issue analyzer.                                                  |
| 2.9   | 2026-11-14 | M9 Stage 3 (Alur Penyelesaian Ascension, Respawn, & Perlindungan Death Loop) selesai. 485 test lulus, 0 issue analyzer.                 |
| 2.8   | 2026-11-14 | M9 Stage 2 (Ascension Dungeon) selesai. 478 test lulus, 0 issue analyzer.                                                               |
| 2.7   | 2026-11-14 | M9 Stage 1 (Domain Siklus) selesai. 468 test lulus, 0 issue analyzer.                                                                   |
| 2.6   | 2026-11-13 | M8 Stage 6 (Simulator Balancing dan QA) selesai pada level simulasi & build APK; M8 READY FOR REVIEW. 458 test lulus, 0 issue analyzer. |
| 2.5   | 2026-11-13 | M8 Stage 5 (Konten Lima Dungeon) selesai. 453 test lulus, 0 issue analyzer.                                                             |
| 2.4   | 2026-11-13 | M8 Stage 4 (Runtime Multi-Dungeon dan Migrasi v3) selesai. 443 test lulus, 0 issue analyzer.                                            |
| 2.3   | 2026-11-13 | M8 Stage 3 (Skema Data dan Layanan Kesulitan) selesai. 432 test lulus, 0 issue analyzer.                                                |
| 2.2   | 2026-11-13 | M8 Stage 2 (Level Tanpa Batas) selesai. 407 test lulus, 0 issue analyzer.                                                               |
| 2.1   | 2026-11-13 | M8 Stage 1 (Rumus Damage Rasio) selesai. 387 test lulus, 0 issue analyzer.                                                              |
| 2.0   | 2026-11-13 | Dokumen M8–M11 dibuat                                                                                                                   |

# 10. UPDATE RULES

Setiap kali milestone mengalami perubahan:

1. Perbarui status milestone.
2. Perbarui checklist berdasarkan implementasi aktual.
3. Tambahkan catatan pada Development Log.
4. Catat blockers dan technical debt.
5. Verifikasi acceptance criteria sebelum menandai Completed.
6. Jangan menandai fitur Completed hanya karena kode sudah dibuat; fitur harus diuji.
7. Jangan mengubah status milestone lain tanpa audit.
8. Catat setiap test lama yang diubah beserta alasannya.
9. Catat setiap migrasi schema dan breaking change.

**End of Document**
