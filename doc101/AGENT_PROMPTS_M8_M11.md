# ECHOES OF AETHER — PROMPT AI AGENT M8–M11

## CARA PAKAI

1. Letakkan semua dokumen ini di folder `docs/` project: `GAME_DESIGN_ADDENDUM_v1.1.md`, `TECHNICAL_DESIGN_ADDENDUM_v1.1.md`, `MASTER_DEVELOPMENT_ROADMAP_M8_M11.md`, `MILESTONE_STATUS_M8_M11.md`, bersama dokumen lama (GDD, TDD, Roadmap, Milestone Status).
2. Untuk setiap sesi dengan agent: tempel **ATURAN GLOBAL** terlebih dahulu, lalu tempel **satu** prompt stage. Jangan menggabungkan beberapa stage dalam satu sesi.
3. Setelah agent selesai, minta laporan memakai format di `PROGRESS_REPORT_TEMPLATE.md`, lalu kirim laporan itu kepadaku untuk diperiksa sebelum stage berikutnya.
4. Urutan wajib: M8 S1 → S2 → S3 → S4 → S5 → S6 → M9 S1 → … → M11 S5. Jangan melompat.

---

## ATURAN GLOBAL (tempel di awal setiap sesi)

```text
Kamu adalah AI Agent yang mengembangkan game "Echoes of Aether" (Flutter, Flame, Riverpod, Drift/SQLite, Freezed). M1–M7 sudah selesai dan terverifikasi. Kamu sekarang mengerjakan M8–M11.

WAJIB DIBACA SEBELUM MENGERJAKAN APA PUN (di folder docs/):
- GAME_DESIGN_ADDENDUM_v1.1.md dan GAME_DESIGN_DOCUMENT.md
- TECHNICAL_DESIGN_ADDENDUM_v1.1.md dan TECHNICAL_DESIGN_DOCUMENT.md
- MASTER_DEVELOPMENT_ROADMAP_M8_M11.md dan MASTER_DEVELOPMENT_ROADMAP.md (Section 6: Governance berlaku penuh)
- MILESTONE_STATUS_M8_M11.md

ATURAN:
1. Kerjakan HANYA stage yang diminta. Berhenti di akhir stage dan buat laporan. Jangan mulai stage berikutnya.
2. Audit repository dulu. Verifikasi asumsi di TDD Addendum Section 1 terhadap kode nyata. Jika ada yang berbeda, laporkan sebelum mengubah kode.
3. Pertahankan fitur yang sudah berjalan. Jangan membangun ulang sistem yang bekerja tanpa justifikasi tertulis.
4. Ikuti Clean Architecture: Domain tidak boleh bergantung pada Flutter, Flame, atau Drift. Domain/Application adalah sumber kebenaran; Flame dan UI hanya adapter.
5. Semua angka balancing harus berada di file JSON konfigurasi dan divalidasi oleh GameConfigValidator. Jangan hardcode.
6. Perubahan yang menyentuh combat, reward, difficulty, atau drop WAJIB diterapkan dan dites di DUA jalur: online (CombatSystem / CombatSimulation) dan offline (OfflineDungeonRunner). Tambahkan test paritas.
7. Jangan menambah dependency tanpa justifikasi tertulis dan persetujuan.
8. Jangan mengubah desain inti (model combat, gerak otomatis, satu karakter dengan specialization, offline-first). Jika menemukan konflik desain, BERHENTI, laporkan, dan minta keputusan.
9. Jangan memakai logika placeholder dan menyebutnya selesai.
10. Test baseline: 366 test harus tetap hijau. Jika kamu terpaksa mengubah test lama, daftarkan tiap perubahan dan alasannya di laporan.
11. Jalankan `flutter analyze` (target 0 issue) dan `flutter test` di akhir stage. Laporkan hasil sebenarnya, bukan perkiraan.
12. Setiap perubahan schema database wajib punya migrasi bertahap (blok from < N dalam satu transaksi), test migrasi dari database versi lama berisi data nyata, dan catatan breaking change.
13. Bedakan dengan jelas di laporan: IMPLEMENTED (kode ada), TESTED (test lulus), VERIFIED (dijalankan di perangkat atau simulasi). Jangan menandai Completed hanya karena file ada.
14. Perbarui MILESTONE_STATUS_M8_M11.md sesuai kondisi aktual (checklist, Development Log, blockers, technical debt).
15. Akhiri dengan laporan sesuai format PROGRESS_REPORT_TEMPLATE.md.
```

---

# MILESTONE 8 — MULTI-DUNGEON & DIFFICULTY

## M8 — Stage 1: Rumus Damage Rasio

```text
TUGAS: M8 Stage 1 — Rumus Damage Rasio.
Rujukan: GAME_DESIGN_ADDENDUM §6; TECHNICAL_DESIGN_ADDENDUM §2.1 dan §3.1.

AUDIT DULU (laporkan sebelum mengubah kode):
- Temukan semua tempat damage dihitung. Mulai dari lib/domain/services/damage_calculator.dart, combat_simulation.dart (DamageCalculator diinjeksi, default const), offline_dungeon_runner.dart (sekitar baris 160 dan 812), lalu cari "atk -", "physicalDamage", "magicDamage", "baseDamage" di seluruh lib/.
- Daftar test yang bergantung pada rumus max(1, ATK-DEF).
- Cek apakah monster menyerang pemain lewat kalkulator yang sama.

KERJAKAN:
1. Tambah enum DamageFormula { ratio, subtractive }.
2. Tambah blok "damage": {"formula": "ratio"} di assets/data/game_config.json. Perbarui game_config_parser.dart, GameConfig, dan GameConfigValidator (nilai tidak dikenal ditolak dengan pesan jelas; default "ratio" jika blok tidak ada).
3. Implementasikan rumus: Base Damage = max(1, round(ATK*ATK / (ATK + max(0, DEF)))). Untuk magic, DEF efektif tetap memakai magicDefenseFactor. Penjaga: ATK <= 0 tidak boleh menghasilkan NaN atau Infinity; hasil di-clamp ke batas maksimum teknis; crit dan skill multiplier tetap bekerja seperti sekarang.
4. Pertahankan mode subtractive hanya agar test regresi bisa memilihnya.
5. Buat SATU provider/titik pembuatan DamageCalculator dari konfigurasi dan teruskan ke CombatSimulation dan OfflineDungeonRunner di semua wiring produksi. Tidak boleh ada jalur produksi yang masih memakai default const DamageCalculator() yang berbeda dari konfigurasi.

TEST YANG HARUS DITAMBAH:
- Tabel nilai: (12,1)->11, (5,2)->4 (periksa angkanya sendiri dan jelaskan pembulatan), (70,16), (70,100), (300,2000).
- Monotonisitas: ATK naik tidak menurunkan damage; DEF naik tidak menaikkan damage.
- Batas: tidak pernah < 1; ATK/DEF sangat besar (mis. 1e9) tidak overflow/NaN.
- Mode subtractive tetap memberi hasil lama.
- Paritas: dengan seed dan input sama, jalur online dan offline menghasilkan damage identik.

JANGAN: mengubah stat, crit, skill, atau formula EXP/reward.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md, termasuk daftar test lama yang diubah.
```

## M8 — Stage 2: Level Tanpa Batas

```text
TUGAS: M8 Stage 2 — Level Tanpa Batas.
Rujukan: GAME_DESIGN_ADDENDUM §5; TECHNICAL_DESIGN_ADDENDUM §2.1 dan §3.2.

AUDIT DULU:
- Temukan SEMUA tempat yang memakai maxLevel/max_level untuk level karakter (bukan maxLevel skill): progression_service.dart (loop while), progression_config.dart, player_character.dart (isMaxLevel, restore ~baris 263), drift_player_save_repository.dart (dua tempat ~baris 117 dan ~388), game_config_parser.dart (~baris 39), serta UI yang menampilkan level.
- Catat bahwa saat ini EXP di-reset ke 0 pada level maksimum dan expToNext memakai pow(growth, level-1).

KERJAKAN:
1. ProgressionConfig.maxLevel menjadi int? (null = tanpa batas). Parser dan validator: "max_level" opsional; null atau tidak ada berarti tanpa batas.
2. Tambah tipe kurva EXP di konfigurasi: "exp": {"type": "polynomial", "base": 60, "exponent": 1.8}. Tipe "exponential" (base, growth) dipertahankan hanya untuk test regresi. Default di assets/data/game_config.json: polynomial, max_level null.
3. expToNext(level) harus aman: hasil di-clamp ke batas teknis, tidak boleh NaN, Infinity, atau negatif.
4. isMaxLevel = false jika maxLevel null. Perilaku "EXP di-reset ke 0 di level maksimum" hanya berlaku jika maxLevel != null.
5. ProgressionService: loop naik level diberi batas iterasi per panggilan (baseline 10.000). Sisa EXP tidak boleh hilang; teruskan sebagai carry. Jelaskan pilihan implementasimu.
6. DriftPlayerSaveRepository dan PlayerCharacter.restore: clamp level hanya jika maxLevel tidak null, plus batas pelindung teknis kTechnicalMaxLevel = 1.000.000 (bukan batas desain; jangan tampil di UI).
7. Buat NumberFormatter (1.2K, 3.4M, 5.6B) di core/utils dan pakai di UI yang menampilkan level/EXP/gold/stat besar (hud_overlay, character_overlay, town_hub_view, inventory_views). Jangan mengubah tata letak.

TEST YANG HARUS DITAMBAH:
- Save lama (level <= 30, termasuk level 30 dengan EXP 0) termuat dan bisa lanjut naik level.
- Level 31, 100, 1000 dihitung benar dan tanpa overflow.
- Reward EXP sangat besar naik banyak level tanpa hang dan tanpa kehilangan EXP.
- Jalur offline: levelsGained besar tetap benar.
- Mode exponential + max_level 30 masih berperilaku seperti lama (regresi).
- NumberFormatter: batas 999, 1.000, 1.000.000, nilai negatif, nilai sangat besar.

JANGAN: mengubah pertumbuhan stat per level, skill maxLevel, atau formula damage.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md.
```

## M8 — Stage 3: Skema Data dan Layanan Kesulitan

```text
TUGAS: M8 Stage 3 — Skema Data dan Layanan Kesulitan.
Rujukan: GAME_DESIGN_ADDENDUM §2.4, §4; TECHNICAL_DESIGN_ADDENDUM §2.1–§2.3, §3.3, §3.4.

AUDIT DULU:
- Konfirmasi difficulty_scale sudah di-parse (dungeon_config_parser.dart ~baris 116) tetapi belum dipakai logika mana pun.
- Konfirmasi titik penerapan SpawnStatModifier di EncounterTracker (~baris 379).
- Temukan SEMUA titik reward: kill monster (CombatSystem ~baris 565, eventId 'enemy:...'), reward room, reward dungeon (DungeonRewardSettlementService), dan padanannya di OfflineDungeonRunner.
- Catat bahwa parser dungeon menolak key tidak dikenal (_dungeonKeys dan konstanta key lain).

KERJAKAN:
1. dungeons.json: dukung field baru per dungeon: kind ("normal" | "ascension"), order, recommended_level, unlock_requires_dungeon_id. Untuk kind "ascension": base_dungeon_id (room dibangun dari dungeon dasar; difficultyScale = skala dasar x difficulty.ascension_multiplier). Parser ascension boleh disiapkan tetapi TIDAK ada dungeon ascension di data pada stage ini.
2. monsters.json: dukung field opsional sprite_ref, sprite_tint, is_final_boss (hanya parsing dan penyimpanan di EnemyDefinition; render dikerjakan di Stage 5).
3. game_config.json: tambah blok "difficulty" sesuai TDD Addendum §2.1 (cycle_per_rank, ascension_multiplier, stat_exponents, reward_exponent, drop, max_multiplier) dan blok "farming". Validator menolak nilai tidak masuk akal.
4. Validator dungeon: order unik dan berurutan, unlock_requires menunjuk dungeon dengan order lebih kecil, tidak ada siklus, hanya satu dungeon ascension, base_dungeon_id valid.
5. DifficultyService (domain murni) -> DifficultyProfile { multiplier, hp/atk/def multiplier, rewardMultiplier, rareDropChanceMultiplier, equipmentRollBonus } dari (DungeonDefinition, cycleRank). Pada stage ini cycleRank selalu 0 di wiring produksi, tetapi API sudah menerimanya. Semua hasil di-clamp ke max_multiplier. Reward dibulatkan dan minimal 1 jika reward dasar > 0.
6. DungeonProgressionService: isUnlocked, isClearedInCurrentCycle, resolveFarmDungeonId, recommendedLevel(dungeon, cycleRank) memakai rumus GDD Addendum §2.5.
7. Terapkan profil kesulitan: (a) stat monster di EncounterTracker setelah statModifier.applyTo; (b) EXP dan gold kill, reward room, reward dungeon di jalur online DAN offline.
8. Pastikan perilaku untuk Forgotten Forest (difficulty_scale 1.0, rank 0) IDENTIK dengan sebelumnya.

TEST YANG HARUS DITAMBAH:
- Parser/validator: semua aturan di atas, termasuk kasus invalid.
- DifficultyService: nilai untuk beberapa (skala, rank), clamp, tidak NaN/Infinity.
- Forest rank 0: stat dan reward identik dengan sebelum perubahan.
- Dungeon dengan skala 2.0: stat dan reward sesuai rumus di online dan offline (paritas).
- DungeonProgressionService: unlock berurutan, farm dungeon default, rekomendasi level.

JANGAN: membuat konten dungeon baru, mengubah DB, atau membuat UI pemilih.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md.
```

## M8 — Stage 4: Runtime Multi-Dungeon dan Migrasi v3

```text
TUGAS: M8 Stage 4 — Runtime Multi-Dungeon dan Migrasi Database v3.
Rujukan: TECHNICAL_DESIGN_ADDENDUM §3.4, §4.1, §5; GAME_DESIGN_ADDENDUM §2.4, §7.

AUDIT DULU:
- features/dungeon/dungeon_screen.dart: defaultDungeonId (~baris 45), _enterDungeon (~baris 595), _selectAutoFarming (~baris 337), pemakaian _dungeon.clearsCount dan _dungeonProgresses.
- features/dungeon/town_hub_view.dart: bagaimana progres dan Auto Farming ditampilkan.
- data/database/app_database.dart (schemaVersion 2, onUpgrade hanya from < 2), DungeonProgresses (PK playerId+dungeonId), repository dan snapshot progres.
- Cara DungeonManager.startDungeon dan ActiveDungeonSessionSnapshot menyimpan dungeonId.

KERJAKAN:
1. Database v3: tabel CycleProgresses (playerId PK + FK cascade, ascensionRank default 0, lastNormalDungeonId nullable, updatedAtMs) dan kolom DungeonProgresses.clearedInCycleRank (default -1). Migrasi from < 3 dalam satu transaksi: buat tabel, tambah kolom, UPDATE dungeon_progresses SET cleared_in_cycle_rank = 0 WHERE clears_count > 0. Regenerasi kode Drift. Naikkan schemaVersion ke 3.
2. Repository dan snapshot: baca/tulis CycleProgress (default jika baris belum ada) dan clearedInCycleRank. Saat dungeon normal selesai, set clearedInCycleRank = ascensionRank saat ini dan tambah clearsCount. clearsCount tetap menghitung seumur hidup.
3. Hapus DungeonScreen.defaultDungeonId. Tambah state "dungeon terpilih" (disimpan sebagai lastNormalDungeonId di CycleProgress). _enterDungeon memakai dungeon terpilih.
4. DungeonProgressionService (dari Stage 3) dipakai untuk unlock. Dungeon N+1 terbuka setelah N selesai pada siklus saat ini.
5. UI fungsional (bukan restyle): daftar dungeon di Town Hub dengan status terkunci/terbuka/selesai, level rekomendasi, dan peringatan teks jika level pemain jauh di bawah rekomendasi. Tombol masuk hanya untuk dungeon terbuka.
6. Auto Farming offline: pemilih target per dungeon, hanya dungeon normal yang clearedInCycleRank sama dengan rank saat ini. Default = resolveFarmDungeonId. Pastikan OfflineDungeonRunner/OfflineProgressionService memakai dungeon target yang dipilih, bukan nilai tetap.
7. Pastikan ActiveDungeonSessionSnapshot dan recovery sesi memuat dungeonId yang benar untuk dungeon mana pun.

TEST YANG HARUS DITAMBAH:
- Migrasi dari database v2 berisi data nyata (level, EXP, gold, inventory, equipment, progres dungeon dengan clears_count > 0 dan = 0): tidak ada data hilang, nilai default benar.
- Instalasi baru (onCreate) membuat semua tabel.
- Unlock berurutan; dungeon terkunci tidak bisa dimasuki.
- Penyelesaian dungeon menyimpan clearedInCycleRank dan clearsCount.
- Recovery sesi untuk dungeon selain Forgotten Forest.
- Auto Farming menolak dungeon yang belum selesai pada siklus saat ini.

JANGAN: membuat dungeon ascension, mengubah kesulitan, atau me-restyle UI.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md, termasuk catatan breaking change migrasi.
```

## M8 — Stage 5: Konten 5 Dungeon

```text
TUGAS: M8 Stage 5 — Konten Lima Dungeon (data-driven).
Rujukan: GAME_DESIGN_ADDENDUM §2.1–§2.3; TECHNICAL_DESIGN_ADDENDUM §2.2–§2.3.

AUDIT DULU:
- assets/data/dungeons.json (5 map reusable, struktur 5 room Forgotten Forest), monsters.json, loot_tables.json, items.json.
- game/visuals/pixel_sprite_atlas.dart: _enemySpecies(definitionId) dengan fallback enemy_generic; game/components/enemies/enemy_component.dart: cara sprite digambar.

KERJAKAN:
1. Render: PixelSpriteAtlas memakai EnemyDefinition.spriteRef jika ada (fallback ke id monster, perilaku lama dipertahankan). Jika sprite_tint ada, terapkan sebagai color filter saat menggambar sprite monster. Ini satu-satunya perubahan render yang diizinkan. Jika color filter terbukti bermasalah di rendering sprite saat ini, laporkan dan jangan memaksakan.
2. Tambah 4 dungeon: crystal_cavern, ancient_crypt, ashen_wasteland, aether_sanctum, masing-masing 5 room (3 normal, 1 elite, 1 boss) dengan map_ref yang sudah ada dan id room unik per dungeon. difficulty_scale: 1.5, 2.25, 3.375, 5.0625. unlock_requires_dungeon_id berantai. order 2–5. recommended_level baseline: 8, 16, 25, 35. Forgotten Forest diberi kind "normal", order 1, recommended_level 1.
3. Per dungeon baru: 3 monster normal, 1 elite, 1 boss. Gunakan nama placeholder dari GAME_DESIGN_ADDENDUM §2.1 dan sprite_ref ke sprite yang ada (aether_slime, forest_wolf, corrupted_treant, corrupted_guardian, ancient_heart_guardian) dengan sprite_tint berbeda per dungeon. Stat dasar monster baru boleh mirip monster forest (pengali kesulitan yang membedakan). Boss Dungeon 5 (Aether Sovereign) bertanda is_final_boss.
4. Loot table dan completion reward per dungeon: pakai ulang pola yang ada; reward dungeon naik wajar. Pastikan item Epic/Legendary yang sudah ada (aether_blade, heart_of_aether) tetap hanya dari boss/dungeon yang sesuai. Jangan membuat item baru kecuali perlu; jika perlu, minimal dan sesuai rarity.
5. Final Boss: pada penyelesaian Dungeon 5, overlay hasil memberi label Final Boss (teks fungsional saja).
6. Validator konfigurasi harus lulus untuk seluruh data.

TEST YANG HARUS DITAMBAH:
- Seluruh dungeons.json dimuat dan lulus validator.
- Setiap dungeon dapat dimulai dan diselesaikan dalam simulasi headless (seed tetap).
- spriteRef dan fallback sprite (unit test pada pemetaan species, tanpa merender).
- Final Boss hanya ada di Dungeon 5.

JANGAN: menambah aset gambar/tileset, mekanik monster baru, atau mengubah rumus balancing.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md.
```

## M8 — Stage 6: Simulator Balancing dan QA

```text
TUGAS: M8 Stage 6 — Simulator Balancing dan QA Akhir M8.
Rujukan: TECHNICAL_DESIGN_ADDENDUM §6 dan §8; GAME_DESIGN_ADDENDUM §2.5, §4.

AUDIT DULU:
- Sambung dengan CombatSimulation dan OfflineDungeonRunner yang sudah headless. Cek test balance 8 jam Mode B dari M7 untuk dipakai ulang.

KERJAKAN:
1. Bangun simulator di test/balance/ (assertion) dan tool/balance_report.dart (tabel laporan). Masukan: level pemain, profil gear per tier (dibangun dari items.json menurut rarity), dungeon, cycleRank, jumlah seed. Keluaran: win rate, HP tersisa rata-rata, durasi run, EXP/gold per run, run per level.
2. Definisikan profil gear per dungeon secara eksplisit dan terdokumentasi (mis. D1 common/uncommon, D3 rare, D5 epic). Profil ini adalah asumsi test, bukan perubahan game.
3. Verifikasi target (rank 0): level rekomendasi -> win rate >= 85%; 10 level di bawah rekomendasi -> < 50%; 10 level di atas -> >= 99% tanpa kondisi damage selalu 1.
4. Jika target tidak tercapai, setel HANYA angka konfigurasi (difficulty_scale, recommended_level, stat dasar monster, reward) lewat JSON. Dokumentasikan setiap perubahan angka dan alasannya. Jangan mengubah rumus.
5. Isi recommended_level final di dungeons.json berdasarkan hasil simulasi.
6. Laporkan juga: berapa run per level di tiap dungeon pada level rekomendasi, dan reward Auto Farming 8 jam di tiap dungeon (cek tidak ada lonjakan tidak wajar).
7. QA akhir: flutter analyze, flutter test, build dan jalankan APK di perangkat Android; uji manual alur Dungeon 1 sampai 5, recovery sesi, offline Auto Farming.
8. Perbarui MILESTONE_STATUS_M8_M11.md. Tandai M8 READY FOR REVIEW (bukan COMPLETED) sampai aku menyetujui laporan.

OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md, dengan tabel hasil simulator terlampir.
```

---

# MILESTONE 9 — ASCENSION CYCLE

## M9 — Stage 1: Domain Siklus

```text
TUGAS: M9 Stage 1 — Domain Siklus (CycleProgress, AscensionService, Farm Dungeon).
Rujukan: GAME_DESIGN_ADDENDUM §1, §3, §7; TECHNICAL_DESIGN_ADDENDUM §3.4.
Prasyarat: M8 selesai dan disetujui.

AUDIT DULU:
- Konfirmasi tabel CycleProgresses dan DungeonProgresses.clearedInCycleRank dari M8 Stage 4 sudah dipakai repository dan snapshot dengan benar.
- Temukan di mana run berakhir (selesai/kalah) dan di mana reward dungeon diproses (DungeonRewardSettlementService, eventId dungeonEventId(runId)).

KERJAKAN:
1. Lengkapi CycleProgress (ascensionRank >= 0, lastNormalDungeonId) sebagai entitas domain dan repository method yang atomik.
2. AscensionService (domain murni): canEnterAscension (Dungeon 5 clear pada siklus saat ini); complete({runId, ...}) yang IDEMPOTEN dengan eventId 'ascension:{runId}' lewat mekanisme ClaimedRewards: menaikkan ascensionRank tepat satu kali, mereset penanda clear siklus (hanya Dungeon 1 terbuka), mengatur lastNormalDungeonId ke Dungeon 1. TIDAK menyentuh level, EXP, gold, skill, specialization, inventory, equipment, dan clearsCount seumur hidup.
3. DungeonProgressionService: resolveFarmDungeonId mengembalikan dungeon normal terakhir yang dimasuki; jika run kalah di Ascension, titik kembali tetap dungeon normal terakhir yang dimasuki sebelum ascension.
4. Persistensi lewat save queue yang sudah ada; seluruh perubahan satu transaksi.

TEST YANG HARUS DITAMBAH:
- complete dipanggil dua kali dengan runId sama: rank hanya naik sekali.
- Setelah complete: hanya Dungeon 1 terbuka; level/EXP/gold/skill/equipment/inventory identik dengan sebelumnya; clearsCount seumur hidup tetap.
- Rank besar (1000) tidak overflow.
- Persistensi dan restore.
- Titik kembali setelah kalah di dungeon normal dan di ascension.

JANGAN: membuat konfigurasi atau UI Ascension Dungeon (Stage 2–3).
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md.
```

## M9 — Stage 2: Ascension Dungeon

```text
TUGAS: M9 Stage 2 — Ascension Dungeon (konfigurasi, runtime, aturan manual-only).
Rujukan: GAME_DESIGN_ADDENDUM §3, §4, §7.3; TECHNICAL_DESIGN_ADDENDUM §2.2, §3.3, §5.

AUDIT DULU:
- Parser ascension dari M8 Stage 3 (base_dungeon_id) dan DifficultyService.
- DungeonManager.startDungeon dan ActiveDungeonSessionSnapshot: apa yang disimpan saat ini.
- OfflineProgressionService/OfflineDungeonRunner: validasi target dan mode Continue Dungeon.

KERJAKAN:
1. Tambah dungeon ascension_sanctum (kind "ascension", base_dungeon_id "aether_sanctum", order 6) beserta completion_reward dan loot table ascension_clear_loot. difficultyScale = skala Dungeon 5 x difficulty.ascension_multiplier.
2. Run menyimpan cycleRank saat dimulai, dan DifficultyProfile dihitung dari (dungeon, cycleRank) tersebut. Simpan cycleRank dan dungeonId di DungeonSession dan ActiveDungeonSessionSnapshot sehingga recovery sesi memberi kesulitan identik. Hubungkan cycleRank nyata ke EncounterTracker dan jalur reward (online dan offline).
3. Manual-only: Auto Farming menolak target ascension (validator dan UI); jika run aktif bertipe ascension saat aplikasi ditutup, mode offline dipaksa pauseProgression dan alasannya dicatat di OfflineSummarySnapshot.
4. Ascension hanya bisa dimulai jika canEnterAscension. Level rekomendasi ascension ditampilkan di UI fungsional (teks).

TEST YANG HARUS DITAMBAH:
- Ascension terkunci sebelum Dungeon 5 selesai pada siklus saat ini.
- Kesulitan ascension = skala D5 x 2 x C(rank) di online dan offline (paritas).
- Recovery sesi di tengah ascension mempertahankan rank awal run walaupun rank di database berubah.
- Auto Farming menolak ascension; offline dipaksa Pause saat run ascension aktif.

JANGAN: menyelesaikan alur penyelesaian ascension (Stage 3) atau mengubah drop (Stage 4).
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md.
```

## M9 — Stage 3: Alur Penyelesaian dan Respawn

```text
TUGAS: M9 Stage 3 — Alur Penyelesaian Ascension, Respawn, dan Perlindungan Death Loop.
Rujukan: GAME_DESIGN_ADDENDUM §3, §7; TECHNICAL_DESIGN_ADDENDUM §3.4.

AUDIT DULU:
- features/dungeon/dungeon_completed_overlay.dart dan run_ended_overlay.dart, serta alur pasca-run di dungeon_screen.dart.
- Alur kalah (revive gagal) dan perilaku kembali ke Town.

KERJAKAN:
1. Saat Ascension Dungeon selesai: panggil AscensionService.complete tepat satu kali per run, proses reward ascension lewat RewardProcessor dengan eventId unik, kembali ke Town, Farm Dungeon menjadi Dungeon 1. Overlay hasil fungsional menampilkan rank baru.
2. Kalah di Ascension: rank tidak berubah, loot terkonfirmasi tetap, kembali ke Town dengan dungeon normal terakhir yang dimasuki terpilih. Kalah di dungeon normal: kembali ke Town dengan dungeon itu terpilih.
3. Perlindungan death loop: hitung kekalahan beruntun per dungeon (disimpan di sesi atau CycleProgress sesuai pilihanmu; jelaskan pilihannya). Setelah ambang (farming.death_loop_suggest_after, default 3), Town menampilkan saran memilih dungeon yang lebih rendah. Hitungan di-reset saat menang.
4. Offline Auto Farming tetap memakai stopOnDefeat.
5. Pastikan tidak ada jalur yang menaikkan rank di luar AscensionService.

TEST YANG HARUS DITAMBAH:
- Penyelesaian ascension end-to-end (headless): rank +1, reset siklus, reward diberikan sekali, state pemain tetap.
- Menutup dan membuka aplikasi tepat saat/setelah penyelesaian tidak menaikkan rank dua kali.
- Alur kalah di ascension dan di dungeon normal.
- Penghitung kekalahan beruntun: naik, saran muncul, reset saat menang.

JANGAN: mengubah rumus kesulitan atau drop (Stage 4).
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md.
```

## M9 — Stage 4: Skala Reward dan Drop per Rank

```text
TUGAS: M9 Stage 4 — Skala Reward dan Kualitas Drop per Rank.
Rujukan: GAME_DESIGN_ADDENDUM §4.3–§4.4; TECHNICAL_DESIGN_ADDENDUM §2.1 (difficulty.drop), §3.3.

AUDIT DULU:
- LootService (peluang drop), EquipmentFactory (roll stat dan roll_variance), dan jalur kill/room/dungeon reward di online dan offline.

KERJAKAN:
1. Pastikan pengali reward (M^reward_exponent) berlaku pada rank > 0 di semua titik reward online dan offline.
2. LootService: peluang drop item rarity Rare ke atas dikalikan (1 + rare_chance_per_rank x rank), dibatasi max_chance_multiplier, dan peluang akhir <= 1.0. Item di bawah Rare tidak berubah.
3. EquipmentFactory: tambahkan bonus roll (roll_bonus_per_rank x rank, dibatasi max_roll_bonus) pada stat yang di-roll; jelaskan cara menerapkannya tanpa merusak distribusi roll_variance.
4. Pastikan determinisme: seed sama menghasilkan hasil sama.
5. Pastikan rank 0 menghasilkan hasil IDENTIK dengan sebelum perubahan.

TEST YANG HARUS DITAMBAH:
- Rank 0: drop dan roll identik dengan baseline.
- Rank 1, 5, 10, 1000: pengali sesuai rumus dan batas atas; peluang tidak pernah > 1.
- Paritas online/offline untuk reward dan drop.
- Distribusi roll tetap dalam rentang wajar.

JANGAN: mengubah item atau loot table kecuali diperlukan untuk ascension_clear_loot; jangan menyentuh shop.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md.
```

## M9 — Stage 5: Balancing Rank dan QA

```text
TUGAS: M9 Stage 5 — Balancing Rank dan QA Akhir M9.
Rujukan: TECHNICAL_DESIGN_ADDENDUM §6, §8, §9; GAME_DESIGN_ADDENDUM §2.5.

KERJAKAN:
1. Perluas simulator M8 Stage 6 ke rank 0, 1, 5, 10, 50, 1000 dan ke Ascension Dungeon. Profil gear untuk rank > 0 memperhitungkan bonus kualitas drop (jelaskan asumsinya).
2. Verifikasi target: level rekomendasi -> win rate >= 85%; -10 level -> < 50%; +10 level -> >= 99%; tidak ada overflow, NaN, atau Infinity pada stat, reward, dan EXP di semua rank; reward Auto Farming 8 jam terbatas dan tidak overflow di semua rank.
3. Kalibrasi rumus rekomendasi level untuk rank (GAME_DESIGN_ADDENDUM §2.5) berdasarkan hasil simulasi; usulkan koreksi jika perlu, jangan mengubah desain tanpa persetujuan.
4. Laporkan apakah pertumbuhan kekuatan pemain (level + gear + bonus drop) cukup mengejar kurva rank sampai rank 50. Jika ada dinding keras, laporkan angka dan usulan penyetelan konfigurasi.
5. QA akhir: flutter analyze, flutter test, APK di perangkat; uji manual satu siklus penuh sampai kembali ke Dungeon 1 dengan kesulitan lebih tinggi, kalah di ascension, recovery sesi, dan offline di setiap kondisi.
6. Perbarui MILESTONE_STATUS_M8_M11.md. Tandai M9 READY FOR REVIEW sampai aku menyetujui.

OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md dengan tabel simulator.
```

---

# MILESTONE 10 — SHOP & ECONOMY

## M10 — Stage 1: Data Shop dan Migrasi v4

```text
TUGAS: M10 Stage 1 — Data Shop, Validator, dan Migrasi Database v4.
Rujukan: GAME_DESIGN_ADDENDUM §8; TECHNICAL_DESIGN_ADDENDUM §2.4, §3.5, §4.2.
Prasyarat: M9 selesai dan disetujui.

AUDIT DULU:
- items.json (field sell_value, rarity, category, equipment), ItemDefinition.sellValue, item_config_parser.dart, game_config_validator.dart, loader konfigurasi (game_config_repository dan provider).
- Apakah consumable (small_potion) memiliki fungsi nyata di game. Jika belum, JANGAN memasukkannya ke shop dan laporkan.

KERJAKAN:
1. Buat assets/data/shop.json sesuai TDD Addendum §2.4 dan daftarkan di pubspec, loader, parser, dan GameConfig.
2. Entitas: ShopEntry, ShopCatalog, SellRules, PurchaseRequirement (sealed: MinLevel, DungeonCleared, MinAscensionRank).
3. Isi katalog baseline dari equipment yang ada (tanpa membuat item baru kecuali perlu dan minimal). Pita harga baseline: Common 10–20, Uncommon 40–80, Rare 150–400, Epic 1.000–2.500, Legendary 8.000–15.000. Requirement baseline: Rare memakai min_level; Epic memakai min_level + dungeon_cleared; Legendary memakai min_ascension_rank >= 1.
4. Validator: item_id ada; id entri unik; pita harga monoton (harga minimum rarity lebih tinggi > harga maksimum rarity di bawahnya); sell_value <= max_sell_ratio x price untuk item yang dijual di shop; requirement valid (dungeon_id ada); consumable hanya jika berfungsi. Sesuaikan sell_value item di items.json bila melanggar rasio, dan catat perubahannya.
5. Database v4: tabel ShopPurchases (playerId, entryId, purchasedCount; PK playerId+entryId), migrasi from < 4, regenerasi kode Drift, naikkan schemaVersion ke 4.

TEST YANG HARUS DITAMBAH:
- Parser dan validator, termasuk kasus invalid (harga tidak monoton, item tidak ada, rasio jual terlampaui).
- Migrasi v3 -> v4 dengan data nyata; instalasi baru.

JANGAN: membuat logika beli/jual atau UI (Stage 2–3).
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md.
```

## M10 — Stage 2: Logika Beli/Jual dan Requirement

```text
TUGAS: M10 Stage 2 — ShopService, Requirement, dan Persistensi Atomik.
Rujukan: GAME_DESIGN_ADDENDUM §8; TECHNICAL_DESIGN_ADDENDUM §3.5.

AUDIT DULU:
- PlayerCharacter.spendGold/canAfford/receiveReward, Inventory (add, remove, addEquipment, removeEquipment, kapasitas maxStackSlots/maxEquipmentCapacity), EquipmentFactory, EquipmentLoadout (item yang sedang dipakai), DriftPlayerSaveRepository dan save queue.
- Apakah ada operasi tambah gold yang aman untuk penjualan (jika belum, buat dengan validasi dan clamp, tanpa melewati jalur reward).

KERJAKAN:
1. ShopService (domain murni): check(entry, context), buy(...), sell(...), sellEquipment(...), sellMaterialBulk(...). Hasil sealed: Success, InsufficientGold, RequirementNotMet (dengan daftar requirement yang gagal), InventoryFull, LimitReached, NotFound, NotSellable (mis. equipment sedang dipakai).
2. Validasi SEMUA kondisi sebelum mengubah state apa pun. Beli: kurangi gold dan tambah item sebagai satu unit; jika penambahan gagal, state tidak berubah. Equipment yang dibeli dibuat lewat EquipmentFactory (roll sama dengan loot).
3. Requirement: min_level (level karakter), dungeon_cleared (clearsCount seumur hidup > 0, tidak hilang saat ascension), min_ascension_rank (CycleProgress).
4. Persistensi: perubahan gold, inventory, equipment, dan ShopPurchases dalam satu transaksi Drift lewat repository/save queue yang ada. purchase_limit ditegakkan lewat ShopPurchases.
5. Pengaman exploit: harga jual tidak pernah melebihi 40% harga beli; jual-beli berulang tidak pernah menghasilkan keuntungan gold.

TEST YANG HARUS DITAMBAH:
- Setiap hasil sealed, dan bahwa kegagalan tidak mengubah gold/inventory/purchases.
- Beli lalu jual item yang sama: gold bersih selalu berkurang.
- Tas penuh, gold tepat pas, gold kurang satu.
- Equipment terpasang tidak dapat dijual.
- Requirement kombinasi (Epic: level + dungeon_cleared) dan Legendary (rank).
- Persistensi dan restore setelah transaksi; purchase_limit setelah restart.
- Idempotensi terhadap pengulangan tap (satu aksi, satu transaksi).

JANGAN: membuat UI (Stage 3) atau mengubah harga di data kecuali ada bug.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md.
```

## M10 — Stage 3: UI Shop Fungsional

```text
TUGAS: M10 Stage 3 — UI Shop Fungsional (akan di-restyle di M11).
Rujukan: GAME_DESIGN_ADDENDUM §8, §9; TECHNICAL_DESIGN_ADDENDUM §7.

AUDIT DULU:
- game/overlays.dart (GameOverlays.panels), features/dungeon/inventory_overlay.dart, equipment_overlay.dart, town_hub_view.dart, game/hud/inventory_views.dart, game/echoes_game.dart (registrasi overlay).

KERJAKAN:
1. ShopOverlay (atau panel setara) yang mengikuti pola overlay yang sudah ada dan dibuka dari Town Hub. Dua tab: Beli dan Jual.
2. Beli: daftar entri dengan nama, rarity (teks/warna sederhana), stat, harga (NumberFormatter), dan status requirement. Requirement yang belum terpenuhi tampil jelas beserta alasannya dan tombol beli nonaktif. Hasil beli/gagal tampil sebagai pesan jelas.
3. Jual: daftar item dan equipment di tas dengan harga jual. Konfirmasi untuk item rarity >= confirm_min_rarity. Jual massal material dengan konfirmasi. Equipment terpasang tidak muncul atau ditandai tidak bisa dijual.
4. UI hanya memanggil ShopService lewat provider/coordinator; tidak ada logika harga atau requirement di widget. State setelah transaksi diambil dari domain.
5. Gaya visual sederhana dan fungsional. Jangan membuat sistem tema baru (itu M11).

TEST YANG HARUS DITAMBAH:
- Widget test: requirement tidak terpenuhi menonaktifkan tombol dan menampilkan alasan; konfirmasi item langka; jual massal.
- Test bahwa widget tidak menyimpan state gameplay sendiri.

JANGAN: mengubah ShopService, harga, atau me-restyle layar lain.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md dengan tangkapan layar jika tersedia.
```

## M10 — Stage 4: Balancing Ekonomi dan QA

```text
TUGAS: M10 Stage 4 — Balancing Ekonomi dan QA Akhir M10.
Rujukan: TECHNICAL_DESIGN_ADDENDUM §6, §9; GAME_DESIGN_ADDENDUM §8.

KERJAKAN:
1. Simulator ekonomi: gold per jam (online dan Auto Farming 8 jam) di tiap dungeon dan rank 0, 1, 5, 10 dibandingkan dengan harga shop per rarity. Hitung estimasi waktu untuk membeli item Rare, Epic, Legendary.
2. Uji exploit: beli-jual berulang, jual material massal, pembelian dengan batas, tas penuh, kegagalan di tengah transaksi (simulasikan error persistensi dan pastikan state konsisten).
3. Jika waktu beli tidak wajar (terlalu cepat atau mustahil), usulkan penyetelan harga di shop.json dengan data; setel hanya konfigurasi dan dokumentasikan.
4. Pastikan sell_value item hasil drop tidak membuat Auto Farming offline menghasilkan gold tak wajar saat dijual massal.
5. QA akhir: flutter analyze, flutter test, APK di perangkat; uji manual beli/jual, requirement, restart aplikasi, dan upgrade dari save M9.
6. Perbarui MILESTONE_STATUS_M8_M11.md. Tandai M10 READY FOR REVIEW sampai aku menyetujui.

OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md dengan tabel ekonomi.
```

---

# MILESTONE 11 — UI REVAMP IDLE RPG

## M11 — Stage 1: Tema dan Komponen

```text
TUGAS: M11 Stage 1 — Token Tema dan Komponen Bersama.
Rujukan: GAME_DESIGN_ADDENDUM §9 dan GDD §14.2 (palet); TECHNICAL_DESIGN_ADDENDUM §7.
Prasyarat: M10 selesai dan disetujui.

AUDIT DULU:
- lib/app/app.dart dan lib/app/theme/ (jika ada), gaya yang tersebar di features/dungeon/*.dart (warna, ukuran teks, padding hardcode), font yang tersedia di assets/fonts/.

KERJAKAN:
1. Token desain: warna (dari palet GDD §14.2 plus warna rarity Common/Uncommon/Rare/Epic/Legendary), tipografi, spacing, radius, elevasi. Bangun ThemeData dan ThemeExtension di lib/app/theme/.
2. Komponen bersama (satu file per komponen, di lokasi sesuai struktur repository): ItemCard (warna rarity, ikon slot, nama, stat ringkas), StatBar (HP/EXP), ResourceChip (gold, rank), PrimaryButton/SecondaryButton, PanelFrame (bingkai ala pixel/RPG sederhana), SectionHeader, LockedBadge, RarityLabel.
3. Dokumentasikan penggunaan komponen secara singkat (komentar dokumentasi atau docs/UI_COMPONENTS.md).
4. Jangan mengganti layar yang ada pada stage ini kecuali satu layar contoh kecil untuk membuktikan komponen bekerja (mis. Settings).
5. Tidak ada dependency baru. Ikon memakai Icons bawaan Flutter atau bentuk sederhana.

TEST YANG HARUS DITAMBAH:
- Widget test dan golden/snapshot sederhana untuk tiap komponen (semua rarity, state terkunci, teks panjang, angka besar).
- Test bahwa komponen tidak overflow pada lebar kecil (mis. 320 dp) dan skala teks besar.

JANGAN: mengubah logika gameplay atau menyentuh domain.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md.
```

## M11 — Stage 2: Navigasi dan Town

```text
TUGAS: M11 Stage 2 — Navigasi Bawah, Top Bar, dan Layout Town/Adventure.
Rujukan: GAME_DESIGN_ADDENDUM §9.

AUDIT DULU:
- features/dungeon/town_hub_view.dart (371 baris), dungeon_screen.dart (917 baris) dan alurnya (Town -> dungeon -> kembali), overlay yang ada di game/overlays.dart.

KERJAKAN:
1. Shell navigasi bawah di Town dengan lima tab: Adventure, Hero, Bag, Shop, Settings. Tab Hero/Bag/Shop/Settings pada stage ini boleh membuka panel yang sudah ada; restyle penuh di Stage 3–4.
2. Top bar: level, bar EXP, gold, Ascension Rank (memakai NumberFormatter dan komponen Stage 1).
3. Layout Adventure: pemilih dungeon (fungsional dari M8 Stage 4), Farm Dungeon terpilih, Auto Farming/offline, tombol masuk.
4. Jika perlu memecah dungeon_screen.dart, lakukan sebagai ekstraksi murni tanpa perubahan perilaku, di langkah terpisah, dan jalankan seluruh test sebelum dan sesudah.
5. Overlay in-dungeon dan HUD tetap berfungsi seperti sebelumnya.

TEST YANG HARUS DITAMBAH:
- Widget test navigasi antar tab; state tab tidak menghilangkan state gameplay.
- Test top bar pada angka besar dan rank tinggi.
- Seluruh test lama tetap hijau.

JANGAN: mengubah logika gameplay, DB, atau konfigurasi.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md.
```

## M11 — Stage 3: Panel Hero dan Bag

```text
TUGAS: M11 Stage 3 — Restyle Hero (stat, specialization, skill) dan Bag (inventory, equipment).
Rujukan: GAME_DESIGN_ADDENDUM §9.

AUDIT DULU:
- features/dungeon/character_overlay.dart, inventory_overlay.dart, equipment_overlay.dart, equipment_text.dart, skill_text.dart, game/hud/inventory_views.dart.

KERJAKAN:
1. Hero: ringkasan karakter, stat akhir, specialization, daftar skill dengan level/upgrade/biaya (logika upgrade tetap di domain), memakai komponen bersama.
2. Bag: inventory dan equipment dalam grid/daftar dengan ItemCard berwarna rarity, filter/sort dasar (sesuai fitur yang sudah ada), slot equipment (Weapon, Head, Body, Accessory) yang jelas, perbandingan stat sederhana saat memilih item.
3. Semua aksi memakai service domain yang sudah ada (EquipmentService, ProgressionService, dsb.). Tidak ada logika baru di widget.

TEST YANG HARUS DITAMBAH:
- Widget test: equip/unequip, upgrade skill, tas penuh, daftar kosong, teks panjang.
- Test lama untuk inventory_views dan equipment_text tetap hijau (atau diubah dengan alasan tercatat).

JANGAN: mengubah aturan equipment/skill atau domain.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md.
```

## M11 — Stage 4: Shop, Dungeon Select, HUD, dan Hasil

```text
TUGAS: M11 Stage 4 — Restyle Shop, Pemilih Dungeon, HUD Dungeon, dan Overlay Hasil.
Rujukan: GAME_DESIGN_ADDENDUM §2.5, §3, §8, §9.

AUDIT DULU:
- ShopOverlay (M10 Stage 3), pemilih dungeon (M8 Stage 4), hud_overlay.dart, dungeon_completed_overlay.dart, run_ended_overlay.dart, offline_summary_overlay.dart.

KERJAKAN:
1. Shop: restyle dengan komponen bersama; requirement tampil dengan badge terkunci dan alasan; konfirmasi dan pesan hasil konsisten.
2. Pemilih dungeon berjenjang: kartu per dungeon (nama, status terkunci/terbuka/selesai, level rekomendasi, pengali kesulitan, peringatan jika level jauh di bawah rekomendasi), kartu Ascension Dungeon dengan status dan peringatan manual-only, saran turun dungeon setelah kekalahan beruntun.
3. HUD dungeon: HP, EXP, skill cooldown, nama dungeon/room, indikator elite/boss/Final Boss, tanpa mengganggu area combat.
4. Overlay hasil: dungeon selesai, kalah, ascension (rank baru, reward), dan ringkasan offline dengan tampilan konsisten.
5. Semua informasi diambil dari state domain/Application. UI bukan sumber kebenaran.

TEST YANG HARUS DITAMBAH:
- Widget test untuk setiap kondisi (terkunci, terbuka, selesai, rekomendasi jauh, ascension, kalah beruntun, Final Boss).
- Test lama gameplay tetap hijau.

JANGAN: mengubah aturan shop, dungeon, atau kesulitan.
OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md dengan tangkapan layar.
```

## M11 — Stage 5: Polish, Performa, dan QA Akhir

```text
TUGAS: M11 Stage 5 — Polish, Performa, dan Verifikasi Akhir.
Rujukan: ROADMAP M11 Acceptance Criteria; TECHNICAL_DESIGN_ADDENDUM §8.

KERJAKAN:
1. Konsistensi lintas layar: spacing, tipografi, warna rarity, label, bahasa teks, dan pesan error/kosong.
2. Layout: uji di beberapa ukuran layar dan skala teks (kecil, sedang, besar); perbaiki overflow.
3. Aksesibilitas dasar: ukuran target sentuh memadai, kontras teks terhadap latar, label semantik pada tombol utama.
4. Performa: bandingkan dengan baseline M7 (frame time saat 20+ musuh, waktu muat Town, penggunaan memori). Laporkan angka sebelum dan sesudah. Perbaiki regresi.
5. Bersihkan kode UI mati, gaya duplikat, dan TODO. Jangan menghapus fitur.
6. QA akhir: flutter analyze (0 issue), flutter test (semua hijau), build dan jalankan APK release di perangkat; uji manual lengkap: instalasi baru, upgrade dari save M10, Dungeon 1–5, Ascension, beberapa siklus, shop, offline, pengaturan.
7. Perbarui MILESTONE_STATUS_M8_M11.md. Tandai M11 READY FOR REVIEW sampai aku menyetujui.

OUTPUT: laporan format PROGRESS_REPORT_TEMPLATE.md dengan tabel performa dan tangkapan layar.
```

---

**End of Document**
