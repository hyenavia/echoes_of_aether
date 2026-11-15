# ECHOES OF AETHER

## MILESTONE STATUS TRACKER — LANJUTAN (M12–M14)

**Project:** Echoes of Aether
**Document Version:** 3.12
**Last Updated:** 2026-11-15
**Current Milestone:** M12 & M13 Completed — Siap lanjut ke M14 (Cloud Sync & Anti-Cheat)
**Overall Status:** M1–M13 Completed (682 test pada verifikasi M13 Stage 4, 0 analyze issue, Drift v7, APK release `60.0MB` terverifikasi di emulator `Pixel_7a`); `B-M12-01` (notifikasi aktual & uji perangkat fisik) tersisa dan tidak memblokir M14

> Dokumen ini melanjutkan `MILESTONE_STATUS_M8_M11.md` (v2.24, M1–M11 Completed). Simpan berdampingan di folder dokumen. Seluruh Update Rules sebelumnya tetap berlaku.

---

# 1. PROJECT OVERVIEW

| Milestone | Name                                       | Status                                                                         |
| --------- | ------------------------------------------ | ------------------------------------------------------------------------------ |
| M1–M11    | Foundation sampai UI Revamp                | Completed (545 test, 0 analyze issue)                                          |
| M12       | Time, Currency, Boss Quest & Notifications | COMPLETED (diverifikasi emulator; pengiriman notifikasi dan uji perangkat fisik tersisa sebagai B-M12-01, tidak memblokir M14) |
| M13       | Weekly Event Shop & Percentage Stats       | COMPLETED (diverifikasi emulator; pengiriman notifikasi dan uji perangkat fisik tersisa sebagai B-M12-01, tidak memblokir M14) |
| M14       | Cloud Sync & Anti-Cheat                    | Not Started (garis besar)                                                      |

**Baseline pengukuran:** `flutter test` = 545 lulus, `flutter analyze` = 0 issue, Drift `schemaVersion = 5`.

---

# 2. M12 — TIME, CURRENCY, BOSS QUEST & NOTIFICATIONS

**Status:** COMPLETED (diverifikasi emulator; pengiriman notifikasi dan uji perangkat fisik tersisa sebagai B-M12-01, tidak memblokir M14)

### Stage 1 — Lapisan Waktu, Schema v6, Pemangkasan ClaimedRewards

- [x] Audit pemakaian waktu dan `ClaimedRewards`
- [x] `GameClock` dan penggantian `DateTime.now()` yang memengaruhi logika
- [x] Konfigurasi `time` + parser + validator
- [x] `PeriodService` (kunci harian/mingguan, indeks, reset berikutnya)
- [x] `ClockGuard` (jam mundur, pencatatan lonjakan maju)
- [x] Drift v6: `ClockStates`, `Currencies`, `PeriodicQuestStates`
- [x] Test migrasi dari v1–v5 dengan data nyata
- [x] Pemangkasan `ClaimedRewards` + test tanpa reward ganda
- [x] Test batas periode, zona waktu, pergantian tahun

### Stage 2 — Aether Shard

- [x] Konfigurasi `currencies`
- [x] `CurrencyService` (grant idempoten, spend atomik, clamp)
- [x] Persistensi lewat snapshot/save queue
- [x] Tampilan jumlah shard (minimal)
- [x] Test grant/spend/clamp/idempotensi

### Stage 3 — Boss Events (Domain dan Runtime)

- [x] `boss_events.json` + parser + validator
- [x] `DungeonKind` baru dan penanganan di semua `switch`
- [x] `BossEventService` (rotasi deterministik)
- [x] Resolusi dungeon acuan + `DifficultyService.profileForBoss`
- [x] Pembangunan dungeon boss satu ruangan
- [x] Run boss manual-only (offline dipaksa Pause)
- [x] Recovery sesi run boss
- [x] Test rotasi, acuan, recovery, offline

### Stage 4 — Boss Quest dan Hadiah

- [x] `BossQuestService` + `PeriodicQuestStates`
- [x] Hadiah otomatis sekali per periode (shard, gold, EXP)
- [x] Aturan kemenangan ulang, sebelum reset, dan run melewati reset
- [x] UI fungsional layar boss (status, hitung mundur, rekomendasi)
- [x] Test idempotensi, batas reset, jam mundur, atomisitas

### Stage 5 — Notifikasi

- [x] Persetujuan dependensi tercatat
- [x] `NotificationPlanner` + test murni
- [x] Adapter platform + izin manifest
- [x] Observer lifecycle tingkat aplikasi
- [x] Notifikasi Auto Farming 8 jam
- [x] Pengingat Daily/Weekly Boss bersyarat
- [x] Pengaturan (toggle per kategori, jam tenang)
- [~] Verifikasi notifikasi di perangkat (emulator `Pixel_7a` via `dumpsys alarm` memverifikasi penjadwalan `RTC_WAKEUP` `18:00:00` ke `ScheduledNotificationReceiver`; delivery banner aktual saat jam jatuh tempo & uji di perangkat fisik belum dijalankan)

### Stage 6 — Balancing dan QA

- [x] Simulator boss (rank 0, 1, 5, 10, 50)
- [ ] Target win rate tercapai di Rank 0. Rank 1–50: target −10 level < 50% TIDAK tercapai (menang 100%; penyebab: pertumbuhan pemain pada kurva M9 lebih cepat dari monster). Menunggu keputusan desain.
- [x] Laporan reward boss terhadap farming dan pendapatan shard (seluruh Gold/EXP quest < 1 jam farming acuan; shard = 120/minggu)
- [x] `flutter analyze` 0 issue, seluruh test hijau
- [~] APK debug (`x86_64`) dan APK release bertanda tangan (`build\app\outputs\flutter-apk\app-release.apk`, `60.0MB`) terverifikasi di emulator `Pixel_7a` (upgrade v6->v7, Daily/Weekly Boss pertama & ulang, recovery sesi, offline/background, transisi jam Senin/Selasa, serta smoke test render & navigasi Town/Boss Events/Event Shop pada APK release); uji APK release di perangkat fisik belum dijalankan karena perangkat tidak terhubung

---

# 3. M13 — WEEKLY EVENT SHOP & PERCENTAGE STATS

**Status:** COMPLETED (diverifikasi emulator; pengiriman notifikasi dan uji perangkat fisik tersisa sebagai B-M12-01, tidak memblokir M14)

### Stage 1 — Stat Persentase dan Schema v7

- [x] Audit penyimpanan `EquipmentInstance` (terbukti via JSON `rolled_stats_json`, bukan kolom per stat)
- [x] `EquipmentStats` + `hpPct/atkPct/defPct` di semua operasi (`+`, `scaled`, `roll`, `isEmpty`, JSON encode/decode; `applyTo` tetap flat-only)
- [x] `DerivedStatsCalculator` + cap konfigurasi (`pct_caps` dari `game_config.json`, wired ke `PlayerCharacter.statsCalculator` di `GameSessionCoordinator` & `BalanceSimulator`)
- [x] Parser/validator item (`hp_pct`, `atk_pct`, `def_pct`, `fixed_stats`, `sellable` + penegakan `!sellable` di `ShopService`)
- [x] Tampilan teks dan perbandingan stat (`describeEquipmentStats` & `computeEquipmentStatDeltas` di `equipment_text.dart`)
- [x] Drift v7 (`EventShopPurchases`, JSON `hpPct/atkPct/defPct` di `rolled_stats_json`) + test migrasi v1–v6 -> v7 (`database_v7_migration_test.dart`)
- [x] Test paritas online/offline (`percentage_stats_test.dart`)

### Stage 2 — Data Event dan Rotasi

- [x] 8 item event di `items.json`
- [x] `event_shop.json` + validator
- [x] `EventRotation` deterministik
- [x] Test rotasi (tiap item sekali per siklus, pasangan beda slot, lintas siklus)

### Stage 3 — Event Shop Service dan UI

- [x] `EventShopService` (shard, batas mingguan, requirement, non-sellable)
- [x] Persistensi pembelian per periode
- [x] UI fungsional event shop
- [x] Notifikasi event berganti
- [x] Test kegagalan tanpa efek samping, idempotensi, jam mundur

### Stage 4 — Balancing Ekonomi dan QA

- [x] Simulator shard terhadap harga
- [x] Dampak satu set event penuh terhadap win rate
- [x] Uji exploit (jam, dua kali beli, jual diblokir, overflow shard, gagal persistensi, konsistensi rotasi post-restart/v6->v7)
- [~] `flutter analyze` 0 issue, seluruh test hijau, APK debug dan APK release terverifikasi di emulator `Pixel_7a` (`flutter analyze` 0 issue, `flutter test` 682/682 lulus termasuk migrasi v1–v6->v7, uji manual emulator `Pixel_7a` untuk v6->v7, pembelian Event Shop, equip + stat %, blokir jual, rotasi minggu Senin `16 Nov`, serta `flutter build apk --release` (`60.0MB`) terverifikasi `apksigner` dan lolos smoke test Town/Boss Events/Event Shop di emulator `Pixel_7a`; uji APK release di perangkat fisik belum dijalankan karena perangkat tidak terhubung)

---

# 4. M14 — CLOUD SYNC & ANTI-CHEAT (GARIS BESAR)

**Status:** Not Started. M12 & M13 telah disetujui `COMPLETED`; checklist rinci M14 siap ditulis saat memulai tahap berikutnya.

- [ ] Stage 0 (manual): project Firebase siap
- [ ] Stage 1: `CloudSaveRepository`, ekspor/impor, schema v8
- [ ] Stage 2: Cloud Functions dan validasi
- [ ] Stage 3: Integrasi klien dan sinkronisasi
- [ ] Stage 4: QA dan uji manipulasi

---

# 5. DEVELOPMENT LOG

| Tanggal    | Milestone/Stage                                          | Catatan                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Test                                                    | Analyze                                                                    |
| ---------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------- | -------------------------------------------------------------------------- |
| 2026-11-15 | M12 Stage 1                                              | `GameClock`, `PeriodService`, `ClockGuard`, `time` & `claimed_rewards` config, Drift schema v6 (`ClockStates`, `Currencies`, `PeriodicQuestStates`), migrasi v1–v5->v6, pemangkasan `ClaimedRewards` konservatif (uji 100.000 baris).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | 574/574                                                 | 0 issue                                                                    |
| 2026-11-15 | M12 Stage 2                                              | Konfigurasi `currencies` (`aether_shard`), `CurrencyService` (grant idempoten, spend atomik, clamp `max_amount`), persistensi `Currencies` dalam transaksi `saveSnapshot`/save queue, chip minimal `Aether Shard: N` di `TownTopBar` memakai `NumberFormatter`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | 584/584                                                 | 0 issue                                                                    |
| 2026-11-15 | M12 Stage 3                                              | `assets/data/boss_events.json` + parser + validator, `DungeonKind.bossDaily`/`bossWeekly`, `BossEventService` (rotasi deterministik, resolusi acuan, `buildBossDungeon`), `DifficultyService.profileForBoss`, run boss manual-only di `DungeonManager`/`GameSessionCoordinator`, recovery `bossEventId`/`periodKeyAtStart`, offline pause enforcement.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | 594/594                                                 | 0 issue                                                                    |
| 2026-11-15 | M12 Stage 4                                              | `PeriodicQuestState` + persistensi `PeriodicQuestStates` di `DriftPlayerSaveRepository`, `BossQuestService` (`bossquest:{questId}:{periodKey}`, shard+gold+EXP atomik + rollback kegagalan persistensi), tombol `Boss` di `TownHubView`, `BossEventsOverlay` (Daily & Weekly tanpa hard lock, status Belum/Selesai, hitung mundur), serta pesan hasil quest di `DungeonCompletedOverlay`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | 600/600                                                 | 0 issue                                                                    |
| 2026-11-15 | M12 Stage 5                                              | `NotificationConfig` + parser + validator (`notifications` di `game_config.json`), `NotificationPlanner` (8j auto-farming, daily/weekly boss bersyarat, jam tenang, `max_per_day`), `LocalNotificationScheduler` (`flutter_local_notifications: ^21.0.0`, `timezone: ^0.11.2`, `inexactAllowWhileIdle`, tanpa exact alarm), `AppLifecycleNotificationObserver` di `EchoesApp`, 4 toggle notifikasi di `GameSettings`/`SettingsOverlay`, izin & receiver `AndroidManifest.xml` + core library desugaring `2.1.4`, serta `flutter build apk --debug`. Verifikasi perangkat fisik/emulator tertunda.                                                                                                                                                                                                                                                            | 610/610                                                 | 0 issue                                                                    |
| 2026-11-15 | M12 Stage 6                                              | Perluasan `BalanceSimulator` (`simulateBossScenario`, `simulateBossQuestComparison`, `--boss`), penyetelan `daily.power_factor` (`1.0 -> 1.25`) dan `base_stats` 3 Daily Boss di `assets/data/boss_events.json` (plus pembaruan ekspektasi `boss_events_config_test.dart` `1.0 -> 1.25`), QA `balance_simulator_test.dart` (12/12) & `database_v6_migration_test.dart` (6/6). M12 ditandai `READY FOR REVIEW`.                                                                                                                                                                                                                                                                                                                                                                                                                                               | 616/616                                                 | 0 issue                                                                    |
| 2026-11-15 | M12 Bugfix (`B-M12-03`)                                  | Audit 7 hipotesis reset Weekly Boss/Quest: seluruh jalur domain, coordinator, rotasi, DB, pruner, dan `nextResetMs` sudah memakai `Period.weekly` (Senin 00:00); gejala di perangkat hari ini (`2026-11-15`, Minggu) terjadi karena reset harian dan mingguan memang bertepatan di Senin `2026-11-16 00:00`. Penguatan single source of truth `Period` di `BossTierConfig`/`BossEventsConfig` (`tierFor`, `periodForQuestId`, `periodForBossId`, `periodForSession` tanpa fallback diam-diam ke `Period.daily`), sinkronisasi `ClockGuard` di `DungeonScreen._buildBossEventsOverlay` lewat `GameSessionCoordinator.effectiveClockMs`, validasi `daily.quest_id != weekly.quest_id`, dan 4 test regresi integrasi (`test/application/weekly_boss_reset_regression_test.dart`).                                                                               | 620/620                                                 | 0 issue                                                                    |
| 2026-11-15 | M13 Stage 1                                              | Stat persentase equipment (`hpPct`, `atkPct`, `defPct`), `fixed_stats` & `sellable`, `equipment.pct_caps` di `game_config.json`, `DerivedStatsCalculator` (`(base + flat) * (1 + min(sumPct, cap))`, parity 0% & online/offline), `ShopService` menolak `!sellable`, `equipment_text.dart`, serta Drift v7 (`EventShopPurchases`, JSON `hpPct`/`atkPct`/`defPct` di `rolled_stats_json` tanpa mengubah kolom `equipment_instances`). Test lama diubah: ekspektasi `db.schemaVersion` `6 -> 7` di 4 file (`database_initialization_test.dart`, `database_v3_migration_test.dart`, `database_v6_migration_test.dart`, `m10_stage1_shop_schema_migration_test.dart`).                                                                                                                                                                                           | 642/642                                                 | 0 issue                                                                    |
| 2026-11-15 | M13 Stage 2                                              | 8 item event di `items.json` (`fixed_stats: true`, `sellable: false`, `sell_value: 0`), `assets/data/event_shop.json`, `EventShopConfigParser` & `GameConfigValidator._validateEventShop` (pool genap, seimbang epic/legendary, per slot lengkap, bebas dari loot/shop regular), `EventRotation` deterministik (urutan kanonis, `xorshift32` seeded per `cycleIndex`, cyclic shift + swap fallback untuk beda slot), pembaruan `AssetGameConfigRepository` & `BalanceSimulator.buildGearProfileForRarity` (`includeNonSellable: false`), perbaikan argumen ganda `statsCalculator:` di `game_session_coordinator.dart`, serta 17 test baru (`event_shop_config_test.dart`, `event_rotation_test.dart`).                                                                                                                                                      | 659/659                                                 | 0 issue                                                                    |
| 2026-11-15 | M13 Stage 3                                              | Ekstraksi `RequirementEvaluator` bersama (Opsi b: `EventShopService` terpisah agar `ShopService` gold tidak berubah), `EventShopService` (rotasi mingguan via `PeriodService.weekIndex`, shard `CurrencyService.spend`, batas mingguan `(entryId, periodKey)`, `fixed_stats`, idempotensi `actionId`), persistensi atomik `EventShopPurchaseRepository` + `ClaimedRewards` prefix `eventshop:` + integrasi `ClaimedRewardsPruner`, tab `Event` (`EventShopView`) + seksi `Tidak Dapat Dijual` di tab `Jual` `ShopOverlay` & wiring `DungeonScreen`, serta kategori notifikasi `eventShopEnding` (`NotificationPlanner`, `AppLifecycleNotificationObserver`, `SettingsOverlay` toggle `notifyEventShopEnding`).                                                                                                                                               | 672/672                                                 | 0 issue                                                                    |
| 2026-11-15 | M13 Stage 4                                              | Perluasan `BalanceSimulator` & `balance_report.dart --event` (ekonomi shard 120/80/50 per minggu, batas `pct_caps` HP 38%/60% ATK 26%/50% DEF 28%/50%, dampak 4-slot Epic & Legendary Event Set di D1–D5, Daily/Weekly Boss, & Ascension Rank 0..50 bebas overflow/NaN; tidak ada angka JSON diubah), 4 uji exploit di `m13_exploit_regression_test.dart` (jam mundur/maju+ClockStates, double-buy, sell blocked, shard max clamp, persistence failure rollback, rotasi identik restart & upgrade v6->v7), 2 test simulator M13 di `balance_simulator_test.dart`, serta `flutter build apk --debug` (`app-debug.apk` sukses; release signing gagal sesuai `B-M12-02`). M13 ditandai `READY FOR REVIEW`.                                                                                                                                                      | 682/682                                                 | 0 issue                                                                    |
| 2026-11-15 | M12–M13 Device QA (Emulator) & Signing Audit             | Uji manual APK debug (`x86_64`) di emulator `Pixel_7a`: upgrade live DB `v6 -> v7` (`PRAGMA user_version = 7`, `event_shop_purchases` terbuat), pembelian Event Shop (`Ember Ring` 100 shard, `Bulwark Plate` 180 shard), equip & kenaikan stat persen (`HP 1.1K -> 1.3K`, `ATK 153`, `DEF 45`, `CRIT 18%`, `HASTE 5%`), blokir jual di tab `Jual`, Daily & Weekly Boss pertama + ulang (`Tidak ada hadiah`), recovery sesi saat boss run, offline/background saat boss run, `dumpsys alarm` (`18:00:00` `RTC_WAKEUP`), serta ganti tanggal ke Senin `2026-11-16` & Selasa `2026-11-17` (Weekly reset Senin dan bertahan `Selesai` di Selasa, Event Shop rotasi ke `Dawn Blade` & limit `0/1`) lalu dikembalikan otomatis. Audit awal `B-M12-02`: `android/key.properties` berisi placeholder `...` dan password keystore lama di luar repo tidak ditemukan. | Emulator QA                                             | -                                                                          |
| 2026-11-15 | Konfigurasi Keystore Rilis Baru & Smoke Test APK Release | Atas persetujuan pengguna, dibuat keystore rilis baru `android/echoes-release.jks` (`2648` bytes, PKCS12, RSA 2048-bit, alias `echoes`, SHA384withRSA, validitas 10.000 hari) dan `android/key.properties` lokal (keduanya ter-gitignore). `flutter build apk --release` berhasil (`build\app\outputs\flutter-apk\app-release.apk`, `60.0MB`), terverifikasi `apksigner verify --print-certs` (SHA-256 `281a298e125fba0da0efca4de3067590168023fb2657687c49b40ce1f48547a1`, SHA-1 `d47226e35bb1d92d410ae8c60f43c5d21926c10f`), dan terverifikasi install + launch + Town/Boss Events/Event Shop di emulator `Pixel_7a`.                                                                                                                                                                                                                                       | `flutter build apk --release`, `apksigner`, Emulator QA | `android/echoes-release.jks`, `android/key.properties` (lokal, gitignored) |
| 2026-11-15 | Persetujuan M12 & M13 + Pencatatan `TD-M12-04`           | Atas keputusan pengguna, M12 dan M13 ditandai `COMPLETED` (diverifikasi emulator; pengiriman notifikasi aktual dan uji perangkat fisik tersisa sebagai `B-M12-01`, tidak memblokir M14). Menambahkan `TD-M12-04` untuk refresh `BossEventsOverlay` saat melewati tengah malam di background.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | -                                                       | -                                                                          |

# 6. BLOCKERS AND KNOWN ISSUES

| ID       | Deskripsi                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Milestone                    | Status                                                                                   |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------- | ---------------------------------------------------------------------------------------- |
| B-M12-01 | Uji manual M12 & M13 pada APK debug dan smoke test APK release sudah dijalankan di emulator `Pixel_7a` (termasuk `v6 -> v7`, ganti jam Senin/Selasa lalu dikembalikan, dan `dumpsys alarm` untuk jadwal `18:00:00`). Tersisa: uji APK release di perangkat fisik saat perangkat terhubung & verifikasi banner notifikasi aktual saat alarm `18:00:00` jatuh tempo.                                                                                                                                                                               | M12 Stage 5–6; M13 Stage 3–4 | Partial (Emulator debug + release verified; physical device & live 18:00 banner pending; tidak memblokir M14) |
| B-M12-02 | Keystore rilis baru `android/echoes-release.jks` (PKCS12, RSA 2048-bit, alias `echoes`, 10.000 hari) dan `android/key.properties` lokal (gitignored) dikonfigurasi atas persetujuan pengguna. `flutter build apk --release` menghasilkan `build\app\outputs\flutter-apk\app-release.apk` (`60.0MB`), lolos verifikasi `apksigner verify --print-certs` (SHA-256 `281a298e125fba0da0efca4de3067590168023fb2657687c49b40ce1f48547a1`), dan lolos smoke test di emulator `Pixel_7a`. Keystore + `key.properties` wajib di-backup aman di luar repo. | M12 Stage 6; M13 Stage 4     | Fixed                                                                                    |
| B-M12-03 | Gejala uji perangkat: hitung mundur Weekly Boss sama dengan Daily Boss pada Minggu `2026-11-15` (bertepatan dengan Senin `00:00`), serta celah tanpa single source of truth `Period` (fallback diam-diam ke `Period.daily` di `_settleBossQuestVictory` bila `dungeonDef == null` dan jam mentah di `_buildBossEventsOverlay`). Diperbaiki di `BossEventsConfig`/`BossTierConfig`/`BossEventsConfigParser`/`GameConfigValidator`/`BossEventService`/`GameSessionCoordinator`/`DungeonScreen` + test regresi integrasi `a`–`f`.                   | M12 Stage 3–4                | Fixed                                                                                    |

# 7. TECHNICAL DEBT

| ID        | Deskripsi                                                                                                                                  | Asal        | Rencana                   |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ----------- | ------------------------- |
| TD-M12-01 | Boss Rank >= 1 sangat mudah (mati < 10 pukulan di rank tinggi); Weekly tidak lebih sulit dari Daily                                        | M12 Stage 6 | Menunggu keputusan desain |
| TD-M12-02 | `difficultyProfileOverride` ditambahkan di `DungeonManager`/`OfflineDungeonRunRequest` (kode produksi) pada Stage 6; default tidak berubah | M12 Stage 6 | Catat saja                |
| TD-M12-03 | `daily.power_factor` `1.0 -> 1.25` dan stat dasar Daily Boss naik ~20%; Addendum v1.2 (B-7) belum diperbarui                               | M12 Stage 6 | Perbarui dokumen          |
| TD-M12-04 | `BossEventsOverlay` tidak menyegarkan status/hitung mundur bila dibiarkan terbuka saat aplikasi di-background melewati tengah malam; baru terbarui setelah overlay dibuka ulang | M12 Stage 4 | Perbaiki saat perombakan UI |

# 8. CHANGE HISTORY

| Versi | Tanggal    | Perubahan                                                                                                                                                                            |
| ----- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 3.0   | 2026-11-14 | Dokumen M12–M14 dibuat                                                                                                                                                               |
| 3.1   | 2026-11-15 | M12 Stage 1 selesai (Lapisan Waktu, Schema v6, Pemangkasan ClaimedRewards)                                                                                                           |
| 3.2   | 2026-11-15 | M12 Stage 2 selesai (Aether Shard & CurrencyService)                                                                                                                                 |
| 3.3   | 2026-11-15 | M12 Stage 3 selesai (Boss Events: data, rotasi, acuan kesulitan, dan run boss manual)                                                                                                |
| 3.4   | 2026-11-15 | M12 Stage 4 selesai (Boss Quest: hadiah otomatis sekali per periode dan UI fungsional layar boss)                                                                                    |
| 3.5   | 2026-11-15 | M12 Stage 5 selesai kecuali verifikasi perangkat (Notifikasi lokal Auto Farming 8 jam & Daily/Weekly Boss)                                                                           |
| 3.6   | 2026-11-15 | M12 Stage 6 selesai (Balancing Boss & QA Akhir M12) — M12 ditandai READY FOR REVIEW                                                                                                  |
| 3.7   | 2026-11-15 | Audit & perbaikan `B-M12-03` (single source of truth `Period` di `BossEventsConfig`/`BossTierConfig`, sinkronisasi `effectiveClockMs` overlay, & test regresi integrasi Weekly Boss) |
| 3.8   | 2026-11-15 | M13 Stage 1 selesai (Stat Persentase pada Equipment & Migrasi Drift v7)                                                                                                              |
| 3.9   | 2026-11-15 | M13 Stage 2 selesai (8 Item Event, `event_shop.json`, Validator, dan `EventRotation`)                                                                                                |
| 3.10  | 2026-11-15 | M13 Stage 3 selesai (`EventShopService`, persistensi pembelian mingguan atomik, tab `Event` di `ShopOverlay`, & notifikasi event berganti)                                           |
| 3.11  | 2026-11-15 | M13 Stage 4 selesai (Balancing Ekonomi Shard, Dampak Stat Persen, Uji Exploit & QA Akhir M13) — M13 ditandai READY FOR REVIEW                                                        |
| 3.12  | 2026-11-15 | M12 dan M13 disetujui `COMPLETED` (diverifikasi emulator; `B-M12-01` tidak memblokir M14), `B-M12-02` selesai, dan `TD-M12-04` dicatat                                               |

# 9. UPDATE RULES

1. Perbarui status milestone dan checklist sesuai implementasi aktual.
2. Tambahkan catatan pada Development Log setiap stage.
3. Catat blockers dan technical debt.
4. Verifikasi acceptance criteria sebelum menandai Completed.
5. Jangan menandai fitur Completed hanya karena kode sudah dibuat; fitur harus diuji.
6. Jangan mengubah status milestone lain tanpa audit.
7. Catat setiap test lama yang diubah beserta alasannya.
8. Catat setiap migrasi schema dan breaking change.
9. Catat setiap perubahan angka balancing beserta bukti simulasinya.

**End of Document**
