# ECHOES OF AETHER

## MILESTONE STATUS TRACKER — M15 (GACHA SYSTEM & MYTHICAL EXPANSION)

**Project:** Echoes of Aether  
**Document Version:** 7.5  
**Last Updated:** 2026-11-19  
**Current Milestone:** M15 — Gacha System (Sistem Gacha Class & Senjata Mythical)  
**Overall Status:** M1–M15 COMPLETED

> Dokumen ini melanjutkan `MILESTONE_STATUS_M14.md`. Simpan berdampingan di folder `doc101/`. Seluruh Update Rules dan konvensi arsitektur tetap berlaku.

**Baseline saat ini:** `flutter test` = 1008 lulus (0 gagal), `flutter analyze` = 0 issue, Drift `schemaVersion = 10`.

---

# 1. M15 — GACHA SYSTEM & MYTHICAL EXPANSION

**Status:** COMPLETED (Disetujui Pemilik Project — 2026-11-19)

### Stage 1 — Domain Entities, Config JSON & Database Schema v10

- [x] Tambah `ItemRarity.mythical` di entity domain, parser, theme tokens, dan widget rarity label/border.
- [x] Tambah 6 Senjata Mythical di `assets/data/items.json` dengan `signature_class_id` dan `resonance_description`.
- [x] Tambah 6 Class Mythical di `assets/data/specializations.json` dengan `rarity: mythical` dan `signature_weapon_id`.
- [x] Berikan label `rarity: legendary` pada 3 Starter Class (Vanguard, Arcanist, Ranger).
- [x] Daftarkan mata uang `soul_prism` di `assets/data/game_config.json`.
- [x] Buat konfigurasi `assets/data/gacha_banners.json` (siklus 21 hari, cost 30/300, banner class pity 40, banner weapon pity 30, rate-up 50/50, sanctuary exchange).
- [x] Parser `GachaConfigParser` dan integrasi validasi di `GameConfigValidator`.
- [x] Entity `GachaConfig`, `GachaBannerDefinition`, `GachaPityState`, `GachaPullResult`, `SanctuaryExchangeConfig`.
- [x] Update `SaveSnapshotCodec` untuk `gachaPityStates` dan `unlockedSpecializations` (mendukung backward compatibility & fallback class dasar).
- [x] Migrasi schema Drift v9 -> v10 (`gacha_pity_states` dan `unlocked_specializations`) di `app_database.dart` dengan seeding awal class dasar.
- [x] Integrasi load & save di `DriftPlayerSaveRepository`.
- [x] Pemetaan 6 senjata Mythical di `ItemSpriteRegistry`.
- [x] Suite test komprehensif `test/data/m15_stage1_gacha_schema_and_config_test.dart` (8/8 PASS) & verifikasi regresi migrasi schema v1-v9.

### Stage 2 — Domain Gacha Engine, Pity & Toko Sanctuary

- [x] Interface & implementasi `GachaService` (`pullOnce`, `pullTen`, `exchangeSanctuaryWeapon`, `exchangeSanctuaryClass`) di `lib/domain/services/gacha_service.dart`.
- [x] Logika banner rotasi 21-hari terpusat via `PeriodService` (`getActiveBannerInfo`, `getCycleIndex`, `getNextResetMs`).
- [x] Logika roll deterministik: Base Rate (Class 1.5%, Weapon 2.0%), Hard Pity Counter (40 Class / 30 Weapon), 50/50 Rate-up Guarantee & Pity Carryover.
- [x] Deteksi duplikasi Class Mythical -> konversi otomatis menjadi 1x `Soul Prism`.
- [x] State management Pity: persistensi `pull_count` dan `is_guaranteed` per banner type di `PlayerSaveSnapshot`.
- [x] Toko Sanctuary permanen (2 Soul Prism -> 1 Senjata Mythical pilihan, 3 Soul Prism -> 1 Class Mythical pilihan dengan perlindungan alreadyOwned).
- [x] Riverpod provider `gachaServiceProvider` di `lib/application/providers/game_config_provider.dart`.
- [x] Test unit komprehensif `test/domain/gacha_service_test.dart` (15/15 PASS, rotasi siklus 0..6, deterministik 50/50, duplikat prism, sanctuary, dan simulasi 1000 pull).

### Stage 3 — Signature Weapon Resonance & Combat Trait System

- [x] Integrasi Resonance Trait di `DerivedStatsCalculator` dan `CombatSimulation`.
- [x] Resonansi Paladin (_Dawn's Aegis Blade_): Retaliation Holy Nova + Heal 5% Max HP + 35% DEF AoE (cooldown 3s).
- [x] Resonansi Voidblade (_Shadowfang Twinblade_): Shadow Mark pada critical hit + True Damage (100% DEF bypass).
- [x] Resonansi Chronomancer (_Hourglass of Eternity_): Timestop/Freeze 2 detik tiap 4 skill cast pada monster biasa (boss immune).
- [x] Resonansi Gunslinger (_Aether Railgun_): Attack Range +2 petak & Piercing Beam basic attack menembus garis lurus.
- [x] Resonansi Necromancer (_Scythe of the Harvester_): Lifesteal +8% pasif & Shadow Minion (50% HP/ATK, max 2) saat musuh gugur.
- [x] Resonansi Stormcaller (_Thunderlord's Scepter_): Chain Lightning menyambar ke +2 musuh ekstra & Shock status effect (+15% damage 4s).
- [x] Test paritas online (`CombatSimulation`) & offline (`OfflineDungeonRunner`).

### Stage 4 — Weekly Shop Barter Revamp & Salvage System

- [x] Hapus konsumsi Aether Shard pada Weekly Event Shop (`currency_id: "barter"`).
- [x] Konversi Weekly Shop menjadi Barter: Gold + Boss Remnants (`boss_remnant`) + Aether Scrap (`aether_scrap`).
- [x] Fitur Salvage / Bongkar Equipment di Blacksmith (`BlacksmithService.salvageEquipment` & tab `Bongkar` di `BlacksmithOverlay`) untuk menghasilkan Aether Scrap.
- [x] Migrasi & perlindungan kuota Weekly Shop lama (`EventShopPurchases` tetap terjaga lintas transisi barter serta perbaikan persistensi `gold` di `saveEventShopTransaction`).
- [x] Test unit & integration untuk Barter Shop, Salvage, persistensi Drift, dan UI (`test/domain/m15_stage4_barter_and_salvage_test.dart`).

### Stage 5 — Gacha UI, Banner Showcase, Animasi Pull & Polishing

- [x] Banner Switcher UI (Tab Class Awakening, Mythical Armory, dan Sanctuary di `GachaOverlay`).
- [x] Animasi Pull Pixel Art (1x Pull & 10x Pull reveal card dengan `TweenAnimationBuilder`).
- [x] Gacha Result Dialog dengan rarity border, badge Featured, & notifikasi konversi duplikat ke Soul Prism.
- [x] Menu Sanctuary Exchange UI (2 Soul Prism -> Senjata Mythical, 3 Soul Prism -> Class Mythical).
- [x] Tombol pintas Gacha di Town Hub View (`quick_access_gacha`) serta integrasi persistensi `gachaPityStates` & `unlockedSpecializations` di `DungeonScreen`, `GameSessionCoordinator`, dan `CharacterOverlay`.
- [x] Verifikasi responsive layout di resolusi mobile sempit (320x640) & tablet (800x1024) via `test/features/gacha_ui_test.dart`.

### Global Game Balance Polish — Stage 1 (Implementation)

**Status:** COMPLETED (Disetujui Pemilik Project — 2026-11-19)

- [x] **REC-01:** AI Aggro fix pada hit valid > 0 (chase & counter-attack penyerang out-of-range) di `CombatSimulation` & `OfflineCombatRuntime`.
- [x] **REC-02:** Kalibrasi Base HP Ash Tyrant (D4 Boss) ke 1.250 (Effective HP 4.218).
- [x] **REC-03:** Kalibrasi Base HP (1.900) & ATK (28) Aether Sovereign (D5 Boss).
- [x] **REC-05:** Voidblade Shadow Mark disesuaikan ke 50% DEF bypass (mempertahankan True Damage pada `void_execution`).
- [x] **REC-06/07:** Cooldown Paladin Holy Nova disesuaikan ke 5.0 detik dan heal ke 3% Max HP.
- [x] **REC-08:** Kalibrasi Base ATK & Secondary Stats 6 Senjata Mythical berbasis arketipe role.
- [x] **REC-09:** Kalibrasi `magicDefenseFactor = 0.80` pada formula damage magic.
- [x] **REC-10..12 (KEEP):** Mempertahankan tanpa perubahan: Gacha rate/pity, early game EXP, dan batas offline 8 jam.

---

# 2. DEVELOPMENT LOG — M15

### 2026-11-18 — Stage 1 Selesai

- **Perubahan Konfigurasi & Schema:**
  - Menambahkan file konfigurasi gacha: `assets/data/gacha_banners.json`.
  - Memperbarui `assets/data/specializations.json` dengan 6 class Mythical dan penandaan `rarity: legendary` pada starter classes.
  - Memperbarui `assets/data/items.json` dengan 6 senjata Mythical dan signature resonance traits.
  - Menambahkan mata uang `soul_prism` pada `assets/data/game_config.json`.
  - Menaikkan versi database Drift dari v9 ke v10, menambahkan tabel `gacha_pity_states` dan `unlocked_specializations`.
  - Mengupdate `ItemSpriteRegistry` dengan sprite untuk 6 senjata Mythical.
- **Hasil Verifikasi:**
  - `flutter analyze`: 0 issues found.
  - `test/data/m15_stage1_gacha_schema_and_config_test.dart`: 8/8 tests passed.
  - Full test suite: 955 tests passed (100%).

### 2026-11-18 — Stage 2 Selesai

- **Implementasi Domain Engine & Sanctuary:**
  - Menambahkan service domain murni `GachaService` di `lib/domain/services/gacha_service.dart`.
  - Menghitung active banner rotation per 21 hari secara deterministik memanfaatkan `PeriodService` (`dayIndex`, `cycleIndex`, `nextResetMs`).
  - Mengimplementasikan roll deterministik dengan dual hard pity (40 Class / 30 Weapon), base rate (1.5% / 2.0%), rate-up 50/50 guarantee, dan reset pity ke 0 setelah 5★ hit.
  - Mengimplementasikan otomatisasi konversi duplikat class ke 1x `Soul Prism` jika class sudah berada di `unlockedSpecializations`.
  - Mengimplementasikan Toko Sanctuary (2 Soul Prism -> 1 Senjata Mythical, 3 Soul Prism -> 1 Class Mythical dengan validasi pencegahan duplikat).
  - Menyediakan `gachaServiceProvider` di `lib/application/providers/game_config_provider.dart`.
  - Menambahkan `copyWith` pada `PlayerCharacterSnapshot` dan `PlayerSaveSnapshot`.
- **Hasil Verifikasi:**
  - `flutter analyze`: 0 issues found.
  - `test/domain/gacha_service_test.dart`: 15/15 tests passed (mencakup rotasi siklus 0..6, pity 40/30, guarantee 50/50, duplikasi prism, toko sanctuary, dan Monte Carlo 1000 pull).
  - Full test suite: 970 tests passed (100%).

### 2026-11-18 — Stage 3 Selesai

- **Resonance Detection & Domain Integration:**
  - Menambahkan `WeaponResonanceService` (`lib/domain/services/weapon_resonance_service.dart`) untuk mengecek keselarasan `hero.specializationId == weapon.signatureClassId` serta menyediakan deskripsi resmi untuk ke-6 class Mythical.
  - Menghubungkan `PlayerCharacter` dan `GameSessionCoordinator` dengan `itemCatalog` sehingga `activeResonanceClassId` dapat dievaluasi secara dinamis saat pergantian senjata atau spesialisasi.
  - Memperbarui `DerivedStatsCalculator` untuk menyuntikkan stat modifier resonansi: Gunslinger (+2.0 attack range) dan Necromancer (+0.08 lifesteal).
- **Mekanik Tempur Dual-Pipeline (Online & Offline):**
  - Mengimplementasikan seluruh 6 trait resonansi di `CombatSimulation`:
    - Paladin: Holy Nova retaliation heal 5% Max HP & 35% DEF AoE damage (radius 2 petak, cooldown 3s).
    - Voidblade: Shadow Mark pada critical hit (6 detik) & True Damage bypass 100% DEF.
    - Chronomancer: Freeze status (2 detik) tiap 4x cast skill pada monster biasa (boss immune).
    - Gunslinger: Piercing Beam menembus semua musuh dalam satu garis proyektil.
    - Necromancer: Pemanggilan Shadow Minion (50% HP & ATK hero, batas 2 minion aktif) saat membunuh musuh.
    - Stormcaller: Chain Lightning menyambar 2 musuh ekstra & Shock status (+15% damage received selama 4 detik).
  - Mengimplementasikan seluruh 6 trait resonansi di `_OfflineCombatRuntime` (`OfflineDungeonRunner`) dengan akurasi 1:1, sinkronisasi `defeated` roster dan evaluasi trigger Holy Nova saat menerima serangan musuh.
  - Visual feedback: Menambahkan FloatingText "RESONANCE!" emas di `CombatSystem` saat resonansi aktif memicu efek khusus.
- **Hasil Verifikasi:**
  - `flutter analyze`: 0 issues found.
  - `test/domain/signature_resonance_combat_test.dart`: 12/12 tests passed (mencakup deteksi resonansi, stat calculation, 6 mekanik combat simulation, paritas online vs offline Forgotten Forest).
  - Full test suite: 982 tests passed (100%).

### 2026-11-18 — Stage 4 Selesai

- **Material Baru & Boss Drops:**
  - Menambahkan item material `aether_scrap` dan `boss_remnant` ke `assets/data/items.json` serta mendaftarkannya pada `ItemSpriteRegistry`.
  - Menambahkan drop `boss_remnant` (100% chance) pada 5 boss loot table dungeon (`boss_loot`, `crystal_boss_loot`, `crypt_boss_loot`, `ashen_boss_loot`, `sanctum_boss_loot`) di `assets/data/loot_tables.json`.
- **Weekly Shop Barter Revamp:**
  - Memperbarui `assets/data/event_shop.json`: mengganti `currency_id` dari `aether_shard` menjadi `barter` (`gold_price` + `material_costs` berupa `boss_remnant` dan `aether_scrap`).
  - Memperbarui `EventShopEntry`, `EventShopConfigParser`, `GameConfigValidator`, `EventShopService`, `EventShopView`, dan `DungeonScreen` untuk mendukung skema barter atomik dengan rollback penuh.
  - Menemukan dan memperbaiki bug persistensi pada `DriftPlayerSaveRepository.saveEventShopTransaction` yang sebelumnya belum memperbarui kolom `gold` pada tabel `players`.
- **Blacksmith Salvage System:**
  - Menambahkan `BlacksmithService.salvageEquipment()` dan `getSalvageScrapYield()` (yield bertingkat Common..Legendary + bonus enhancement level, menolak item terpasang dan Mythical).
  - Menambahkan tab `Bongkar` (Salvage) di `BlacksmithOverlay` dan menyambungkan handler `_handleSalvageEquipment` di `DungeonScreen` & `TownHubView`.
- **Hasil Verifikasi:**
  - `flutter analyze`: 0 issues found.
  - `test/domain/m15_stage4_barter_and_salvage_test.dart`: 5/5 tests passed.
  - Full test suite: 987 tests passed (100%).

### 2026-11-18 — Stage 5 Selesai

- **Gacha UI, Sanctuary Exchange & Integrasi Penuh:**
  - Membuat `GachaOverlay` (`lib/features/dungeon/gacha_overlay.dart`) dengan 3 tab (`Class`, `Senjata`, `Sanctuary`), indikator saldo Aether Shard & Soul Prism, rate-up showcase, pity counter independen, indikator `50/50 Guaranteed!`, tombol `Tarik 1x` & `Tarik 10x`, serta `_GachaResultDialog` beranimasi.
  - Menambahkan tombol quick-access `Gacha` (`quick_access_gacha`) pada `TownHubView` dan menyambungkan seluruh handler pull/sanctuary & overlay pada `DungeonScreen`.
  - Menghubungkan `gachaPityStates` dan `unlockedSpecializations` secara end-to-end pada `GameSessionCoordinator`, `DungeonScreen`, `InventoryViews`, dan `CharacterOverlay` sehingga Class Mythical yang terbuka dapat dipilih dan tersimpan persisten di Drift.
- **Hasil Verifikasi:**
  - `flutter analyze`: 0 issues found.
  - `test/features/gacha_ui_test.dart`: 3/3 widget & responsive layout tests passed (termasuk resolusi 320x640 dan 800x1024 tanpa overflow).
  - Full test suite: 990 tests passed (100%).
- **Tambahan Pasca-Review (Skill Khusus 6 Class Mythical):**
  - Menambahkan 18 skill baru (1 Pasif + 2 Aktif untuk setiap Class Mythical) pada [assets/data/skills.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/skills.json), memperbarui `skill_affinities` di [assets/data/specializations.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/specializations.json), serta mendaftarkan sprite ke-18 skill pada `ItemSpriteRegistry.skillSprites`.
  - Verifikasi: `flutter analyze` = 0 issues, `test/data/skill_parser_test.dart` = 15/15 PASS, `test/data/m15_stage1_gacha_schema_and_config_test.dart` & `test/domain/signature_resonance_combat_test.dart` PASS.

### 2026-11-19 — Visual Assets Update (10 Class Character Sheets & Crest Icons)

- **Pemotongan & Ekstraksi Aset Visual (tool/slice_character_assets.py):**
  - Mengekstrak 10 ilustrasi portrait karakter resolusi tinggi berlatar transparan ke [assets/char/](file:///e:/myLittleProject/echoes_of_aether/assets/char/): `hero_base.png` (Adventurer), `hero_vanguard.png`, `hero_arcanist.png`, `hero_ranger.png`, `hero_paladin.png`, `hero_voidblade.png`, `hero_chronomancer.png`, `hero_gunslinger.png`, `hero_necromancer.png`, `hero_stormcaller.png`.
  - Mengekstrak 60 frame gameplay in-engine ke [assets/char/frames/](file:///e:/myLittleProject/echoes_of_aether/assets/char/frames/): mencakup 6 pose animasi (`idle0`, `idle1`, `walk0`, `walk1`, `attack`, `downed`) untuk ke-10 karakter.
  - Mengekstrak 10 lambang lambang class (_crest icon_) ke [assets/icons/class/](file:///e:/myLittleProject/echoes_of_aether/assets/icons/class/) dan mendaftarkannya pada [pubspec.yaml](file:///e:/myLittleProject/echoes_of_aether/pubspec.yaml).
- **Integrasi Domain & Engine:**
  - Memperbarui `CharacterVisualSpec.resolve` di [game_assets.dart](file:///e:/myLittleProject/echoes_of_aether/lib/features/shared/assets/game_assets.dart) untuk memetakan spesifikasi visual resmi (judul, subjudul, warna primer, aksen, aura, weapon style, pose summary, dan assetPath) seluruh 10 class.
  - Memperbarui `PixelSpriteAtlas._playerSpecies` dan `_heroGrid` di [pixel_sprite_atlas.dart](file:///e:/myLittleProject/echoes_of_aether/lib/game/visuals/pixel_sprite_atlas.dart) untuk mendukung 6 class Mythical dengan palet warna dan siluet sesuai lembar referensi.
- **Hasil Verifikasi:**
  - Unit test baru `test/features/shared/character_visual_spec_test.dart` (12/12 PASS).
  - Regresi `test/game/pixel_combatant_sprites_test.dart` diperluas dan lulus 100% untuk 10 class.
  - `flutter analyze`: 0 issues found (bersih).
  - Full test suite: **1007 / 1007 tests passed (100%)**.

### 2026-11-19 — Global Game Balance Stage 1 Implementation (REC-01 s/d REC-09)

- **Implementasi Balancing Disetujui (Stage 0C Final Reconciliation):**
  - **REC-01 (Aggro Target Fix):** `CombatSimulation` dan `OfflineCombatRuntime` (`OfflineDungeonRunner`) kini memicu aggro (`aggroed = true`, `targetId = attacker.id`, `aiState = chase`) ketika monster menerima damage valid > 0, menyelesaikan isu musuh pasif terhadap serangan jarak jauh di luar detection range.
  - **REC-02 (Ash Tyrant D4 Boss Base HP):** Dinaikkan dari 465 menjadi 1.250 di `assets/data/monsters.json` (Effective HP 4.218 pada rank 0), menjaga ATK 23 dan DEF 7.
  - **REC-03 (Aether Sovereign D5 Boss Base HP & ATK):** Base HP dinaikkan dari 480 menjadi 1.900, Base ATK dinaikkan dari 24 menjadi 28 di `assets/data/monsters.json` (Effective HP 9.618, Effective ATK 141), menjaga DEF 8.
  - **REC-05 (Voidblade Armor Penetration):** Shadow Mark DEF bypass disesuaikan dari 100% menjadi 50% (`(defenderDef * 0.5).round()`) di pipeline combat online & offline, menjaga True Damage pada skill aktif `void_execution`.
  - **REC-06/07 (Paladin Holy Nova Cooldown & Heal):** Cooldown disesuaikan menjadi 5.0 detik (100 ticks) dan healing disesuaikan menjadi 3% Max HP (dari 5%) di pipeline combat online & offline.
  - **REC-08 (Mythical Weapon ATK Calibration):** Mengkalibrasi ulang base ATK 6 senjata Mythical di `assets/data/items.json`:
    - Dawn's Aegis Blade: ATK 28, DEF 20, DEF% 10%, HP% 8%.
    - Shadowfang Twinblade: ATK 34, Crit Rate 10%, Crit DMG 25%.
    - Hourglass of Eternity: ATK 28, Skill Haste 20%, Mana Regen 15%.
    - Aether Railgun: ATK 36, Attack Speed 15%, Crit Rate 8%.
    - Scythe of the Harvester: ATK 30, Lifesteal 8%, Max HP 200.
    - Thunderlord's Scepter: ATK 32, Magic DMG% 15%, Skill Haste 12%.
  - **REC-09 (Magic Defense Factor Calibration):** Mengatur default `magicDefenseFactor = 0.80` pada `DamageConfig` dan `DamageCalculator` sehingga serangan magic menghitung DEF musuh secara proporsional.
  - **REC-10..12 (KEEP):** Mempertahankan tanpa perubahan: Gacha rates & pity system (M15), kurva EXP early game (Lv 1..5), dan 8-hour offline auto farming cap.
- **Hasil Verifikasi:**
  - `flutter analyze`: 0 issues found (bersih).
  - `dart format`: 13 file diformat rapi sesuai pedoman repository.
  - Full test suite: **1008 / 1008 tests passed (100%)**.
