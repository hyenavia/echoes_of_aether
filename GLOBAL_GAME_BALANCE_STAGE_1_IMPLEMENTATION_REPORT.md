# GLOBAL GAME BALANCE STAGE 1 — IMPLEMENTATION REPORT

**Project:** Echoes of Aether  
**Date:** 2026-11-19  
**Status:** COMPLETED (Disetujui Pemilik Project — 2026-11-19)  
**Baseline:** `flutter test` = 1.008 passed, `flutter analyze` = 0 issues, Drift `schemaVersion = 10`  
**Reference Document:** `GLOBAL_GAME_BALANCE_STAGE_0C_FINAL_RECONCILIATION.md`  
**Tracker:** `doc101/MILESTONE_STATUS_M15.md`  

---

## 1. Ringkasan Eksekutif

Implementasi Global Game Balance Stage 1 telah selesai dilakukan secara menyeluruh sesuai dengan spesifikasi yang disetujui pada dokumen rekonsiliasi akhir (`GLOBAL_GAME_BALANCE_STAGE_0C_FINAL_RECONCILIATION.md`). Seluruh rekomendasi balancing (REC-01 sampai REC-09) telah diterapkan secara atomik pada domain entities, static data JSON, pipeline tempur online (`CombatSimulation`), pipeline tempur offline (`OfflineDungeonRunner`), kalkulator damage (`DamageCalculator`), serta weapon resonance service.

Seluruh 1.008 pengujian otomatis (`flutter test`) lulus 100% tanpa kegagalan (bertambah 1 unit test dari baseline 1.007 untuk memverifikasi aggro retaliatory behavior), dan `flutter analyze` bersih dengan 0 issues. Seluruh berkas Dart yang dimodifikasi telah diformat menggunakan `dart format`.

---

## 2. Rincian Implementasi per Rekomendasi (REC-01 s/d REC-09)

### REC-01 — Gunslinger Aggro Behavior Fix
* **Permasalahan:** Ketika musuh diserang dari luar detection range (misalnya oleh Gunslinger dengan jangkauan tembak resonansi 3.5 petak), musuh tetap dalam status pasif/idle dan tidak membalas.
* **Perubahan Kode:**
  * [lib/domain/services/combat_simulation.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/combat_simulation.dart): Pada method `_strike()`, saat monster menerima damage valid (`actualDamage > 0`):
    * Jika `!aggroed`, set `aggroed = true`.
    * Tetapkan `targetId = attacker.id`.
    * Ubah `aiState = MonsterAiState.chase`.
  * [lib/domain/services/offline_dungeon_runner.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/offline_dungeon_runner.dart): Pada method `_attackMonster()`, saat musuh menerima damage valid, trigger aggro aktif (`enemy.aggroed = true`, `enemy.targetId = 'player'`).
* **Verifikasi Paritas:** Musuh kini langsung mengejar dan membalas penyerang setelah menerima pukulan pertama, baik di pertempuran real-time online maupun simulasi offline.
* **Tingkat Bukti:** [IMPLEMENTED] [TESTED] (`test/domain/combat_simulation_test.dart`).

---

### REC-02 — Ash Tyrant (Dungeon 4 Boss) HP Calibration
* **Permasalahan:** Base HP lama (465) menghasilkan TTK hanya 8–14 detik, sehingga boss meleleh sebelum fase pertempuran aktif.
* **Perubahan Konfigurasi:**
  * [assets/data/monsters.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/monsters.json):
    * `ash_tyrant`: Base HP dinaikkan dari `465` -> `1250`.
    * Mempertahankan Base ATK `23` dan Base DEF `7`.
* **Dampak Scaling (Rank 0 D4):**
  * Difficulty Multiplier HP: `3.375x`.
  * Effective HP D4 Boss: **4.218 HP** (sebelumnya 1.569 HP).
  * Target TTK: Berada pada rentang ideal **25–35 detik** di seluruh 9 class.
* **Tingkat Bukti:** [IMPLEMENTED] [TESTED] (`test/data/stage5_five_dungeons_content_test.dart`, `test/balance/balance_simulator_test.dart`).

---

### REC-03 — Aether Sovereign (Dungeon 5 Boss) HP & ATK Calibration
* **Permasalahan:** Base HP lama (480) dan Base ATK (24) terlalu lemah untuk klimaks final dungeon reguler.
* **Perubahan Konfigurasi:**
  * [assets/data/monsters.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/monsters.json):
    * `aether_sovereign`: Base HP dinaikkan dari `480` -> `1900`.
    * Base ATK dinaikkan dari `24` -> `28`.
    * Mempertahankan Base DEF `8`.
* **Dampak Scaling (Rank 0 D5):**
  * Difficulty Multiplier D5: HP `5.0625x`, ATK `5.0625x`.
  * Effective HP D5 Boss: **9.618 HP** (sebelumnya 2.430 HP).
  * Effective ATK D5 Boss: **141 ATK** (sebelumnya 121 ATK).
  * Target TTK: Berada pada rentang ideal **40–55 detik** dengan ancaman wiped out jika pemain tidak memiliki pertahanan memadai.
* **Tingkat Bukti:** [IMPLEMENTED] [TESTED] (`test/data/stage5_five_dungeons_content_test.dart`, `test/balance/balance_simulator_test.dart`).

---

### REC-05 — Voidblade Armor Penetration Calibration
* **Permasalahan:** Shadow Mark lama memberikan 100% DEF bypass (True Damage pada semua serangan critical), membuat DEF boss tidak relevan dan mendistorsi output damage Voidblade hingga +200% dibanding class lain.
* **Perubahan Kode:**
  * [lib/domain/services/combat_simulation.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/combat_simulation.dart):
    * Saat target memiliki debuff `shadow_mark`: `defenderDef = (defenderDef * 0.5).round();`.
    * Serangan tetap mempertahankan damage type aslinya (Physical).
  * [lib/domain/services/offline_dungeon_runner.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/offline_dungeon_runner.dart):
    * Logika kalkulasi damage yang sama diterapkan pada `_OfflineCombatRuntime`.
  * [lib/domain/services/weapon_resonance_service.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/weapon_resonance_service.dart):
    * Deskripsi resonansi diperbarui: *"Serangan critical memberikan debuff Shadow Mark selama 6 detik (musuh kehilangan 50% Armor).*
* **Skill Void Execution:** Skill aktif `void_execution` tetap mempertahankan sifat murninya sebagai True Damage (100% DEF ignore).
* **Tingkat Bukti:** [IMPLEMENTED] [TESTED] (`test/domain/signature_resonance_combat_test.dart`).

---

### REC-06/07 — Paladin Holy Nova Cooldown & Heal Ratio Calibration
* **Permasalahan:** Cooldown 3.0 detik dan heal 5% Max HP membuat Paladin abadi (*infinite sustain tank*) tanpa risiko kekalahan di boss dungeon.
* **Perubahan Kode:**
  * [lib/domain/services/combat_simulation.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/combat_simulation.dart):
    * Cooldown Holy Nova: diubah dari `3.0 detik` (60 ticks) -> `5.0 detik` (100 ticks).
    * Heal Ratio: diubah dari `0.05` (5% Max HP) -> `0.03` (3% Max HP).
    * Retaliation Damage AoE: tetap `0.35 * hero.stats.def` (radius 2 petak).
  * [lib/domain/services/offline_dungeon_runner.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/offline_dungeon_runner.dart):
    * Diperbarui identik pada pipeline offline: cooldown 100 ticks dan heal 3% Max HP.
  * [lib/domain/services/weapon_resonance_service.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/weapon_resonance_service.dart):
    * Deskripsi resonansi diperbarui: *"Memulihkan 3% Max HP hero dan memicu gelombang Holy Nova (cooldown 5 detik).*
* **Tingkat Bukti:** [IMPLEMENTED] [TESTED] (`test/domain/signature_resonance_combat_test.dart`).

---

### REC-08 — Mythical Weapons Role-Based ATK Calibration
* **Permasalahan:** Seluruh 6 senjata Mythical memiliki Base ATK seragam (36 ATK), mengabaikan arketipe role (tank vs glass-cannon vs mage).
* **Perubahan Konfigurasi:**
  * [assets/data/items.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/items.json):
    * `dawns_aegis_blade` (Paladin - Tank): ATK `36` -> `28`, DEF `15` -> `20`, DEF% `10%`, HP% `8%`.
    * `shadowfang_twinblade` (Voidblade - Assassin): ATK `36` -> `34`, Crit Rate `10%`, Crit DMG `25%`.
    * `hourglass_of_eternity` (Chronomancer - Support/Mage): ATK `36` -> `28`, Skill Haste `20%`, Mana Regen `15%`.
    * `aether_railgun` (Gunslinger - Physical Ranged): ATK `36` (tetap), Attack Speed `15%`, Crit Rate `8%`.
    * `scythe_of_the_harvester` (Necromancer - Hybrid Summoner): ATK `36` -> `30`, Lifesteal `8%`, Max HP `200`.
    * `thunderlords_scepter` (Stormcaller - Burst Mage): ATK `36` -> `32`, Magic DMG% `15%`, Skill Haste `12%`.
* **Tingkat Bukti:** [IMPLEMENTED] [TESTED] (`test/data/m15_stage1_gacha_schema_and_config_test.dart`, `test/domain/signature_resonance_combat_test.dart`).

---

### REC-09 — Magic Damage Defense Factor Calibration
* **Permasalahan:** Serangan magic mengabaikan defense musuh secara berlebihan, merusak konsistensi mitigasi pertempuran.
* **Perubahan Kode:**
  * [lib/domain/entities/damage_config.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/entities/damage_config.dart):
    * Default `magicDefenseFactor` diatur menjadi `0.80` (sebelumnya `0.50` atau uncalibrated).
  * [lib/domain/services/damage_calculator.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/damage_calculator.dart):
    * Formula `magicDamage(rawDamage, targetDef)` mengalikan `targetDef * magicDefenseFactor` (default `0.80`), mempertahankan resistensi proporsional terhadap spellcasters.
* **Tingkat Bukti:** [IMPLEMENTED] [TESTED] (`test/domain/damage_calculator_test.dart`).

---

### REC-10, REC-11, REC-12 — Kebijakan "KEEP"
Sesuai persetujuan, mekanik berikut **dipertahankan tanpa perubahan**:
* **REC-10:** Gacha rate (Class 1.5%, Weapon 2.0%), dual hard pity (40 Class / 30 Weapon), rotasi 21-hari, 50/50 rate-up guarantee, dan Sanctuary Exchange.
* **REC-11:** Kurva EXP early game level 1..5 (1.430 total EXP dengan 2x full run + 1st room Forgotten Forest).
* **REC-12:** Batas waktu akumulasi offline reward maksimal 8 jam (28.800 detik / 576.000 ticks).

---

## 3. Berkas yang Diubah

### Domain & Application:
1. [lib/domain/entities/damage_config.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/entities/damage_config.dart) — Default `magicDefenseFactor = 0.80`.
2. [lib/domain/services/damage_calculator.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/damage_calculator.dart) — Formula magic damage memakai `magicDefenseFactor = 0.80`.
3. [lib/domain/services/combat_simulation.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/combat_simulation.dart) — REC-01 Aggro pada damage > 0, REC-05 Voidblade 50% DEF bypass, REC-06/07 Paladin Holy Nova (5s CD, 3% heal).
4. [lib/domain/services/offline_dungeon_runner.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/offline_dungeon_runner.dart) — Paritas offline: REC-01 aggro trigger, REC-05 Voidblade 50% armor bypass, REC-06/07 Paladin Holy Nova (5s CD, 3% heal).
5. [lib/domain/services/weapon_resonance_service.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/weapon_resonance_service.dart) — Deskripsi resmi Paladin & Voidblade diperbarui.

### Static Data JSON:
6. [assets/data/monsters.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/monsters.json) — REC-02 `ash_tyrant` Base HP 1250, REC-03 `aether_sovereign` Base HP 1900 & Base ATK 28.
7. [assets/data/items.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/items.json) — REC-08 Kalibrasi ATK & secondary stats untuk 6 Senjata Mythical.

### Testing & Simulation Tools:
8. [tool/src/balance_simulator.dart](file:///e:/myLittleProject/echoes_of_aether/tool/src/balance_simulator.dart) — Perbaikan gear profile D5 (`isAscension: dungeon.order >= 5 || dungeon.isAscension`) sehingga T5 Legendary gear terpasang dengan benar pada simulasi D5.
9. [test/domain/combat_simulation_test.dart](file:///e:/myLittleProject/echoes_of_aether/test/domain/combat_simulation_test.dart) — Menambahkan test aggro out-of-detection-range.
10. [test/domain/signature_resonance_combat_test.dart](file:///e:/myLittleProject/echoes_of_aether/test/domain/signature_resonance_combat_test.dart) — Penyesuaian assertion Holy Nova (3% heal, 5s CD) dan Voidblade (50% armor bypass).
11. [test/domain/damage_calculator_test.dart](file:///e:/myLittleProject/echoes_of_aether/test/domain/damage_calculator_test.dart) — Penyesuaian assertion `magicDefenseFactor = 0.80`.
12. [test/domain/skill_test.dart](file:///e:/myLittleProject/echoes_of_aether/test/domain/skill_test.dart) — Penyesuaian penanganan `AttackEvent` pada test dummy karena dummy kini membalas setelah menerima hit (REC-01).
13. [test/domain/character_build_test.dart](file:///e:/myLittleProject/echoes_of_aether/test/domain/character_build_test.dart) — Penyesuaian filter `AttackEvent` (REC-01).
14. [test/data/stage5_five_dungeons_content_test.dart](file:///e:/myLittleProject/echoes_of_aether/test/data/stage5_five_dungeons_content_test.dart) — Pembaruan preset gear D4 & D5 agar sesuai tier dungeon masing-masing.
15. [test/balance/balance_simulator_test.dart](file:///e:/myLittleProject/echoes_of_aether/test/balance/balance_simulator_test.dart) — Penyesuaian batas kalibrasi boss D4 & D5 sesuai stat HP baru.

---

## 4. Hasil Verifikasi Kualitas

### A. Format & Static Analyzer
* `dart format`: 13 file diformat rapi tanpa kendala sintaksis.
* `flutter analyze`: **No issues found! (ran in 30.5s)**.

### B. Unit & Regression Tests
* **Perintah:** `flutter test`
* **Hasil:** **1.008 passed, 0 failed, 0 errors** (100% PASS).
* **Paritas Tempur:** Jalur online (`CombatSimulation`) dan offline (`OfflineDungeonRunner`) terverifikasi memiliki perilaku dan formula matematis yang 100% konsisten.

---

## 5. Kesimpulan & Status

Implementasi balancing Stage 1 telah selesai dengan sukses, memulihkan keseimbangan gameplay di early game, mid game, hingga end-game boss encounters tanpa merusak sistem progresi atau ekonomi yang sudah mapan.

Tracker `doc101/MILESTONE_STATUS_M15.md` telah diperbarui dengan baseline 1.008 test dan entri Development Log lengkap.
Status: **COMPLETED** (Disetujui Pemilik Project — 2026-11-19).
