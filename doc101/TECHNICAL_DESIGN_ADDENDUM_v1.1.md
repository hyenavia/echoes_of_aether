# ECHOES OF AETHER

## TECHNICAL DESIGN DOCUMENT — ADDENDUM v1.1 (M8–M11)

**Document Version:** 1.1-addendum
**Basis:** TECHNICAL_DESIGN_DOCUMENT (Drift `schemaVersion = 2`, 366 test, 0 analyzer issue)
**Pasangan dari:** GAME_DESIGN_ADDENDUM_v1.1

---

# 0. PRINSIP YANG TIDAK BERUBAH

- Clean Architecture: Domain tidak boleh bergantung pada Flutter, Flame, atau Drift.
- Domain/Application adalah sumber kebenaran state gameplay. Flame component dan UI hanya adapter.
- Simulasi deterministik dengan `Random` yang disuntikkan.
- Semua nilai balancing berada di JSON konfigurasi dan divalidasi `GameConfigValidator`.
- Reward idempoten per `eventId` lewat `RewardProcessor` dan `ClaimedRewards`.
- Tidak ada dependency baru tanpa justifikasi tertulis.

# 1. TITIK INTEGRASI YANG SUDAH TERVERIFIKASI DI KODE

| Temuan | Lokasi | Implikasi |
|---|---|---|
| `difficulty_scale` sudah di-parse tetapi belum dipakai | `dungeon_config_parser.dart`, `DungeonDefinition.difficultyScale` | Hook kesulitan tinggal dihubungkan. |
| `SpawnStatModifier` diterapkan saat spawn | `EncounterTracker` (sekitar baris 379): `config.statModifier.applyTo(definition.stats)` | Titik penerapan pengali kesulitan. |
| Dungeon di-hardcode | `DungeonScreen.defaultDungeonId` dan `_enterDungeon` | Harus diganti state dungeon terpilih. |
| Progres clear sudah **per dungeon** | Tabel `DungeonProgresses`, PK `(playerId, dungeonId)` | Cukup ditambah penanda siklus. |
| Rumus damage terpusat | `DamageCalculator`; diinjeksi ke `CombatSimulation` dan `OfflineDungeonRunner` (default `const DamageCalculator()`) | Wajib satu instance dari konfigurasi untuk online dan offline. |
| Cap level tersebar | `ProgressionService`, `PlayerCharacter`, `DriftPlayerSaveRepository` (2 tempat), `game_config_parser.dart`, `character_overlay` (skill, bukan level) | Semua harus diubah serentak. EXP saat ini di-reset ke 0 pada level maksimum. |
| Sprite dipilih dari id monster | `PixelSpriteAtlas._enemySpecies(definitionId)` dengan fallback `enemy_generic` | Monster baru butuh `sprite_ref`. |
| Offline runner terpisah dari `CombatSystem` | `offline_dungeon_runner.dart` | Setiap perubahan reward/difficulty harus dipasang di **kedua** jalur. |
| Migrasi Drift hanya menangani `from < 2` | `AppDatabase.onUpgrade` | Tambahkan blok `from < 3` dan `from < 4`. |

Agent wajib **memverifikasi ulang** tabel ini terhadap repository sebelum memakainya.

---

# 2. KONFIGURASI

## 2.1 `game_config.json` (penambahan)

```json
{
  "damage": { "formula": "ratio" },
  "progression": {
    "max_level": null,
    "exp": { "type": "polynomial", "base": 60, "exponent": 1.8 },
    "per_level": { "hp": 15, "atk": 2, "def": 0.5 }
  },
  "difficulty": {
    "cycle_per_rank": 6.5,
    "ascension_multiplier": 1.35,
    "cycle_level_step": 44,
    "stat_exponents": { "hp": 1.0, "atk": 1.0, "def": 0.9 },
    "cycle_stat_exponents": { "hp": 0.25, "atk": 0.22, "def": 0.20 },
    "reward_exponent": 0.85,
    "drop": {
      "rare_chance_per_rank": 0.1,
      "max_chance_multiplier": 3.0,
      "roll_bonus_per_rank": 0.02,
      "max_roll_bonus": 0.5
    },
    "max_multiplier": 1000000000
  },
  "farming": { "death_loop_suggest_after": 3 }
}
```

Ketentuan:
- `progression.exp.type` menerima `polynomial` (default baru) dan `exponential` (`base`, `growth`, hanya untuk test regresi).
- `damage.formula` menerima `ratio` (default) dan `subtractive`.
- `max_level` opsional; `null` atau tidak ada berarti tanpa batas.
- Validator menolak nilai negatif, eksponen tidak masuk akal, dan `max_multiplier` yang bisa menyebabkan overflow.

## 2.2 `dungeons.json` (penambahan field per dungeon)

```json
{
  "id": "crystal_cavern",
  "name": "Crystal Cavern",
  "biome": "crystal_cavern",
  "kind": "normal",
  "order": 2,
  "difficulty_scale": 1.5,
  "recommended_level": 8,
  "unlock_requires_dungeon_id": "forgotten_forest",
  "start_room_id": "cc_entrance",
  "completion_reward": { "exp_reward": 160, "gold_reward": 80, "loot_table_id": "dungeon_clear_loot" },
  "rooms": []
}
```

Ascension Dungeon tidak menyalin room, tetapi mereferensikan dungeon dasar:

```json
{
  "id": "ascension_sanctum",
  "name": "Ascension: Aether Sanctum",
  "kind": "ascension",
  "order": 6,
  "base_dungeon_id": "aether_sanctum",
  "completion_reward": { "exp_reward": 800, "gold_reward": 400, "loot_table_id": "ascension_clear_loot" }
}
```

`DungeonConfigParser` membangun `DungeonDefinition` ascension dari room dasar. `difficultyScale` hasilnya = skala dasar × `difficulty.ascension_multiplier`. Parser saat ini menolak key yang tidak dikenal, jadi daftar key (`_dungeonKeys`) harus diperbarui.

Validator memeriksa: `order` unik dan berurutan; `unlock_requires_dungeon_id` menunjuk dungeon yang ada dengan `order` lebih kecil; tepat satu dungeon `ascension`; `base_dungeon_id` valid dan bertipe normal; tidak ada siklus unlock.

## 2.3 `monsters.json` (penambahan field)

```json
{ "id": "crystal_slime", "sprite_ref": "aether_slime", "sprite_tint": "#65BFE8", "is_final_boss": false }
```

- `sprite_ref` opsional; jika ada, `PixelSpriteAtlas` memakainya menggantikan id monster. Jika tidak ada, perilaku lama berlaku.
- `sprite_tint` opsional (hex); dipakai sebagai color filter saat render.
- `is_final_boss` opsional, hanya untuk label UI.

## 2.4 `shop.json` (file baru, M10)

```json
{
  "entries": [
    {
      "id": "shop_iron_helm",
      "item_id": "iron_helm",
      "price": 60,
      "purchase_limit": null,
      "requirements": [ { "type": "min_level", "value": 4 } ]
    }
  ],
  "sell": {
    "sellable_categories": ["equipment", "material", "consumable"],
    "confirm_min_rarity": "rare",
    "equipped_sellable": false,
    "max_sell_ratio": 0.4
  }
}
```

Jenis requirement: `min_level`, `dungeon_cleared` (`dungeon_id`), `min_ascension_rank`. Validator menegakkan: `item_id` ada; entri equipment valid; pita harga monoton per rarity; `sell_value` ≤ `max_sell_ratio` × `price`; id entri unik; consumable hanya jika memiliki fungsi.

---

# 3. DOMAIN

## 3.1 `DamageCalculator`

```dart
enum DamageFormula { ratio, subtractive }

int physicalDamage(int atk, int def) => switch (formula) {
  DamageFormula.ratio => math.max(1, (atk * atk / (atk + math.max(0, def))).round()),
  DamageFormula.subtractive => math.max(1, atk - def),
};
```

Aturan: tidak boleh ada NaN atau `Infinity`; penjaga `atk <= 0`; aman untuk nilai besar (gunakan `double`, lalu clamp ke `kMaxDamage`). `magicDamage` memakai DEF efektif seperti sekarang. Instance dibuat dari konfigurasi lewat satu provider dan diteruskan ke `CombatSimulation` dan `OfflineDungeonRunner`.

## 3.2 Level tanpa batas

- `ProgressionConfig.maxLevel` menjadi `int?`.
- `expToNext(level)` memakai `type`. Hasil di-clamp ke `kMaxExpToNext` dan tidak boleh `NaN`, `Infinity`, atau negatif.
- `PlayerCharacter.isMaxLevel` bernilai `false` jika `maxLevel == null`. Perilaku "EXP di-reset ke 0 pada level maksimum" hanya berlaku jika `maxLevel != null`.
- `ProgressionService.applyExp`: loop naik level dengan batas iterasi per panggilan (baseline 10.000). Sisa EXP tidak hilang dan diteruskan ke panggilan berikutnya.
- `DriftPlayerSaveRepository` (dua tempat) dan `PlayerCharacter.restore`: clamp level memakai `maxLevel` hanya jika tidak null, dan batas pelindung teknis `kTechnicalMaxLevel = 1_000_000`.
- UI: utilitas `NumberFormatter` (K/M/B).

## 3.3 Kesulitan

```dart
class DifficultyProfile {
  final double multiplier;          // M efektif
  final double hpMultiplier, atkMultiplier, defMultiplier;
  final double rewardMultiplier;    // M^reward_exponent
  final double rareDropChanceMultiplier;
  final double equipmentRollBonus;
}

class DifficultyService {
  DifficultyProfile profileFor(DungeonDefinition dungeon, int cycleRank);
  int scaleExp(int base, DifficultyProfile p);
  int scaleGold(int base, DifficultyProfile p);
}
```

`DifficultyService` murni Dart. Perhitungan pengali stat memisahkan `base_scale` (`dungeon.difficultyScale`) memakai `stat_exponents` dan `cycle_factor` (`1 + cycle_per_rank × rank`) memakai `cycle_stat_exponents` opsional (fallback ke `stat_exponents` jika null; di Rank 0 `cycle_factor == 1.0` sehingga identik dengan kurva M8), lalu di-clamp ke `max_multiplier`. Titik penerapan:
1. Stat monster: `EncounterTracker` setelah `statModifier.applyTo`.
2. EXP/gold monster, reward room, dan reward dungeon: di jalur `CombatSystem` dan `OfflineDungeonRunner` (kedua jalur, dengan test paritas).
3. Drop dan roll: `LootService` dan `EquipmentFactory`.

Profil dihitung saat run dimulai dan disimpan di `DungeonSession` / `ActiveDungeonSessionSnapshot` (`cycleRank`, `dungeonId`), sehingga recovery sesi menghasilkan kesulitan yang sama.

## 3.4 Progres dungeon dan siklus

```dart
class CycleProgress {
  final int ascensionRank;          // rank aktif (0 .. highestAscensionRank)
  final int highestAscensionRank;   // rank tertinggi yang pernah dicapai
  final String? lastNormalDungeonId;
}

class DungeonProgressionService {
  bool isUnlocked(DungeonDefinition d, CycleProgress c, Map<String, DungeonProgressSnapshot> p, {int? playerLevel});
  bool isClearedInCurrentCycle(String dungeonId, ...);
  String? resolveFarmDungeonId(...);   // default: normal tertinggi yang clear pada siklus ini
  int recommendedLevel(DungeonDefinition d, int cycleRank);
  int requiredLevel(DungeonDefinition d, int cycleRank); // 1 untuk D1 di semua rank, else recommendedLevel
  bool meetsLevelRequirement(DungeonDefinition d, int cycleRank, int playerLevel);
}

class AscensionService {
  bool canEnterAscension(...);
  AscensionResult complete({required String runId, ...}); // idempoten, event `ascension:{runId}`
}
```

`AscensionService.complete`: menaikkan `ascensionRank` tepat satu kali, mengatur ulang penanda clear siklus, mengatur `lastNormalDungeonId` ke dungeon 1. Tidak menyentuh level, EXP, gold, skill, specialization, inventory, dan equipment.

## 3.5 Shop

```dart
sealed class PurchaseRequirement { ... }   // MinLevel, DungeonCleared, MinAscensionRank
class ShopEntry { id, itemId, price, purchaseLimit, requirements }
class ShopCatalog { entries, sellRules }

class ShopService {
  RequirementCheck check(ShopEntry e, PlayerContext ctx);
  ShopBuyResult buy(...);     // validasi semua dulu, baru mutasi
  ShopSellResult sell(...);
}
```

Atomisitas: `buy` memvalidasi seluruh kondisi (entri ada, requirement, gold cukup, kapasitas tas, batas pembelian) **sebelum** mengubah state. Mutasi dan persistensi berada dalam satu transaksi Drift. Hasil bertipe sealed (`Success`, `InsufficientGold`, `RequirementNotMet`, `InventoryFull`, `LimitReached`, `NotFound`).

---

# 4. PERSISTENSI DAN MIGRASI

## 4.1 Schema v3 (M8 Stage 4)

- **Tabel baru `CycleProgresses`:** `playerId` (PK, FK ke `Players`, cascade), `ascensionRank` (int, default 0), `lastNormalDungeonId` (text, nullable), `updatedAtMs` (int).
- **Kolom baru `DungeonProgresses.clearedInCycleRank`** (int, default -1). Dungeon dianggap clear pada siklus saat ini jika nilainya sama dengan `ascensionRank`. `clearsCount` tetap menghitung seumur hidup.
- Migrasi `from < 3`: buat tabel, tambah kolom, lalu `UPDATE dungeon_progresses SET cleared_in_cycle_rank = 0 WHERE clears_count > 0`.

## 4.2 Schema v4 (M10 Stage 1)

- **Tabel baru `ShopPurchases`:** `playerId`, `entryId`, `purchasedCount`; PK `(playerId, entryId)`.

## 4.3 Aturan migrasi

- `onCreate` tetap `createAll`; `onUpgrade` memakai blok `from < N` berurutan dan berada dalam satu transaksi.
- Setiap migrasi punya test: mulai dari database v2 yang berisi data nyata (level, inventory, equipment, progres dungeon), migrasi, lalu cek tidak ada data hilang dan nilai default benar.
- Baris `CycleProgresses` yang belum ada diperlakukan sebagai default (`ascensionRank = 0`) oleh repository.
- Semua perubahan wajib punya catatan breaking change di `MILESTONE_STATUS`.

---

# 5. OFFLINE

- `OfflineActivityMode.autoFarming`: target tervalidasi sebagai dungeon `kind == normal` dan clear pada siklus saat ini. Target ascension ditolak.
- `continueDungeon`: jika run aktif bertipe ascension, mode dipaksa `pauseProgression` dan alasannya dicatat di ringkasan.
- Kebijakan `stopOnDefeat` dipertahankan.
- `OfflineDungeonRunner` memakai `DifficultyService` dan `DamageCalculator` yang sama dengan jalur online. Wajib ada test paritas (seed sama, hasil sama untuk satu run).
- `OfflineSummarySnapshot` menambahkan `cycleRank`.

---

# 6. BALANCE SIMULATOR

Dibangun di atas `CombatSimulation` / `OfflineDungeonRunner` yang sudah headless.

- Lokasi: `test/balance/` untuk assertion dan `tool/balance_report.dart` untuk laporan tabel.
- Masukan: level pemain, profil gear per tier (dibangun dari `items.json` menurut rarity), dungeon, rank, jumlah seed.
- Keluaran: win rate, rata-rata HP tersisa, durasi run, EXP/gold per run, run per level.

Target baseline (boleh disetel, tetapi harus lewat konfigurasi atau konstanta test yang jelas):

| Kondisi | Target |
|---|---|
| Level rekomendasi, gear tier wajar | Win rate ≥ 85% |
| 10 level di bawah rekomendasi | Win rate < 50% |
| 10 level di atas rekomendasi | Win rate ≥ 99%, tanpa kondisi damage selalu 1 |
| Rank 0, 1, 5, 10, 50, 1000 | Tidak ada overflow, NaN, atau Infinity pada stat, reward, atau EXP |
| 8 jam Auto Farming per dungeon | Reward terhitung, terbatas, dan tidak overflow |

---

# 7. UI ARSITEKTUR (M11)

- Token tema (warna, tipografi, spacing, radius) di `lib/app/theme/`.
- Widget bersama (kartu item, bar, tombol, panel) di `lib/features/shared/widgets/` atau lokasi setara sesuai struktur repository.
- Navigasi bawah membungkus Town Hub; overlay in-dungeon tetap bekerja.
- `dungeon_screen.dart` (±900 baris) boleh dipecah hanya sebagai pekerjaan ekstraksi tanpa mengubah perilaku, dan perubahan itu dicatat.
- Tidak ada state gameplay yang hidup di widget.
- Tidak ada dependency UI baru kecuali disetujui.

---

# 8. STRATEGI PENGUJIAN

- Baseline: 366 test harus tetap hijau. Test yang sengaja diubah harus didaftar beserta alasannya di laporan.
- Setiap stage menambah test untuk logika baru.
- `flutter analyze` wajib 0 issue di akhir setiap stage.
- Test paritas online/offline untuk damage, kesulitan, dan reward.
- Test migrasi v2→v3 dan v3→v4 dengan data nyata.
- Test idempotensi: Ascension tidak menaikkan rank dua kali, pembelian tidak mengurangi gold dua kali.
- Verifikasi APK pada perangkat di akhir M8, M9, M10, dan M11.

# 9. REGISTER RISIKO

| Risiko | Mitigasi |
|---|---|
| Rumus rasio mengubah rasa bermain awal | Test regresi nilai rendah, mode `subtractive` tetap tersedia, perubahan terisolasi di `DamageCalculator` |
| Jalur online dan offline divergen | Satu `DamageCalculator` dan satu `DifficultyService`, test paritas wajib |
| Overflow di rank/level tinggi | Clamp, batas teknis, test rank 1000 dan level besar |
| Migrasi merusak save | Test dari DB v2 nyata, transaksi tunggal |
| Death loop | Saran turun dungeon, pemilih Farm Dungeon, `stopOnDefeat` offline |
| Inflasi gold | Reward eksponen 0.85, pita harga shop, laporan simulator |
| Shop dieksploitasi | Validasi sebelum mutasi, transaksi atomik, rasio jual maksimal 0.4 |
| Refactor UI besar merusak fitur | Ekstraksi tanpa perubahan perilaku, test sebelum dan sesudah |

**End of Addendum**
