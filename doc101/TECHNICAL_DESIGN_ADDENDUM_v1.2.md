# ECHOES OF AETHER

## TECHNICAL DESIGN DOCUMENT — ADDENDUM v1.2 (M12–M14)

**Document Version:** 1.2-addendum
**Basis:** TDD + TDD Addendum v1.1; kondisi kode setelah M11 (Drift `schemaVersion = 5`, 545 test, 0 analyze issue)
**Pasangan dari:** GAME_DESIGN_ADDENDUM_v1.2

---

# 0. PRINSIP YANG TIDAK BERUBAH

- Clean Architecture: Domain tidak bergantung pada Flutter, Flame, atau Drift.
- Domain/Application adalah sumber kebenaran; UI dan Flame hanya adapter.
- Simulasi deterministik, `Random` dan **waktu** disuntikkan.
- Semua angka balancing berada di JSON dan divalidasi `GameConfigValidator`.
- Reward idempoten per id klaim.
- Perubahan yang menyentuh combat, reward, atau stat diterapkan dan dites di jalur online **dan** offline.
- Tidak ada dependency baru tanpa persetujuan eksplisit (persetujuan untuk M12 Stage 5 tertulis di prompt).
- UI hanya fungsional minimal (GDD Addendum v1.2 §0.2).

# 1. TITIK INTEGRASI YANG SUDAH TERVERIFIKASI

| Temuan | Lokasi | Implikasi |
|---|---|---|
| Jam sudah dapat disuntikkan sebagian | `GameSessionCoordinator(nowMs)`; offline punya status `invalidClock` | Seragamkan menjadi satu `GameClock` |
| Ada pemakaian langsung `DateTime.now()` | `drift_player_save_repository.dart` (~baris 138), `audio_service.dart` | Ganti yang memengaruhi logika game |
| `DungeonKind { normal, ascension }` | `domain/entities/dungeon_definition.dart` (~baris 218) | Tambah `bossDaily`, `bossWeekly`; parser/validator ikut |
| Event reward di tiga titik | `combat_system.dart` (~613), `offline_dungeon_runner.dart` (~476), `DungeonRewardSettlementService` | Boss hanya online, tetapi pola id klaim sama |
| `ClaimedRewards` tidak dipangkas | Tabel `ClaimedRewards`; id dimuat ke memori saat startup | Pangkas di M12 Stage 1 |
| Stat equipment: 9 field angka tetap | `EquipmentStats` (`equipment.dart`): `+`, `scaled`, `roll`, `applyTo`, `isEmpty` | Tambah `hpPct`, `atkPct`, `defPct` di semua operasi |
| Stat akhir pemain dihitung di satu tempat | `DerivedStatsCalculator.calculate` dipakai `PlayerCharacter.stats` | Titik penerapan stat persen (online dan offline otomatis sama) |
| Equipment terpasang dijumlah | `EquipmentLoadout.totalBonus` | Mengembalikan `EquipmentStats` |
| Shop hanya mata uang gold | `ShopService`, `ShopEntry`, `shop.json` (14 entri) | Perlu generalisasi mata uang atau service terpisah |
| Observer lifecycle hanya di layar dungeon | `dungeon_screen.dart` (~baris 127) | Notifikasi butuh observer tingkat aplikasi |
| Mode offline | `OfflineActivityMode { pauseProgression, continueDungeon, autoFarming }` | Penjadwalan notifikasi 8 jam bergantung pada mode |

Agent wajib memverifikasi ulang tabel ini terhadap repository sebelum memakainya.

---

# 2. KONFIGURASI

## 2.1 `game_config.json` (penambahan)

```json
{
  "time": {
    "reset_hour": 0,
    "week_start": "monday",
    "epoch_monday": "2026-11-16",
    "forward_jump_record_threshold_hours": 48
  },
  "currencies": {
    "aether_shard": { "name": "Aether Shard", "max_amount": 1000000 }
  },
  "claimed_rewards": { "retention_days": 14 },
  "equipment": {
    "pct_caps": { "hp_pct": 0.6, "atk_pct": 0.5, "def_pct": 0.5 }
  },
  "notifications": {
    "daily_reminder_hour": 18,
    "weekly_reminder_weekday": "sunday",
    "weekly_reminder_hour": 18,
    "quiet_hours": { "start": 23, "end": 7 },
    "max_per_day": 3
  }
}
```

Nilai `equipment` dan `notifications` bergabung dengan blok yang sudah ada, tidak menimpanya. Validator menolak jam di luar 0–23, nilai negatif, dan `epoch_monday` yang bukan hari Senin.

## 2.2 `boss_events.json` (baru, M12)

```json
{
  "daily": {
    "quest_id": "daily_boss",
    "power_factor": 1.0,
    "reward": { "currency": { "aether_shard": 10 }, "exp": 120, "gold": 60 },
    "pool": [
      { "id": "daily_ash_tyrant", "name": "Ash Tyrant", "sprite_ref": "ancient_heart_guardian", "sprite_tint": "#C86432", "base_stats": { "hp": 600, "atk": 40, "def": 12 } }
    ]
  },
  "weekly": {
    "quest_id": "weekly_boss",
    "power_factor": 1.5,
    "reward": { "currency": { "aether_shard": 50 }, "exp": 600, "gold": 300 },
    "pool": []
  },
  "arena_map_ref": "ancient_heart_map"
}
```

Ketentuan: pool harian minimal 1 (baseline 3), mingguan minimal 1 (baseline 2); `id` unik; `sprite_ref` valid; reward ≥ 0; `arena_map_ref` ada di `dungeons.json`. Stat dasar boss baseline boleh disetel simulator.

## 2.3 `event_shop.json` (baru, M13)

```json
{
  "pool": [
    { "id": "evt_dawn_blade", "item_id": "event_dawn_blade", "tier": "epic", "price": 100,
      "requirements": [ { "type": "dungeon_cleared", "dungeon_id": "ancient_crypt" } ] },
    { "id": "evt_eclipse_blade", "item_id": "event_eclipse_blade", "tier": "legendary", "price": 180,
      "requirements": [ { "type": "min_ascension_rank", "value": 1 } ] }
  ],
  "weekly_purchase_limit": 1,
  "currency_id": "aether_shard"
}
```

Validator: ukuran pool genap; jumlah item tier `epic` sama dengan `legendary`; tiap slot memiliki kedua tier; `item_id` ada dan non-sellable; harga > 0.

## 2.4 `items.json` (penambahan M13)

Field stat baru `hp_pct`, `atk_pct`, `def_pct` pada `equipment.stats`; field opsional `fixed_stats: true` (tanpa roll) dan `sellable: false`. Parser saat ini menolak key tidak dikenal, jadi daftar key diperbarui.

---

# 3. DOMAIN

## 3.1 Waktu

```dart
abstract interface class GameClock { int get nowMs; }

enum Period { daily, weekly }

class PeriodService {
  String keyFor(Period p, int nowMs, {Duration? Function()? offset});
  int weekIndex(int nowMs);   // sejak epoch_monday
  int dayIndex(int nowMs);    // sejak epoch_monday
  int nextResetMs(Period p, int nowMs);
}

class ClockGuard {
  // lastSeenAtMs hanya naik. resolve() mengembalikan max(raw, lastSeen).
  ClockReading resolve(int rawNowMs); // { effectiveMs, wentBack, forwardJumpMs }
}
```

`ClockGuard` menyimpan `lastSeenAtMs`, jumlah lonjakan maju, dan lonjakan terbesar di tabel `ClockStates`. Logika offline `invalidClock` tetap dan diselaraskan dengan `ClockGuard`.

Detail penting: kunci periode dihitung dari tanggal **lokal** setelah dikurangi `reset_hour`. Test wajib mencakup batas 23:59:59 dan 00:00:00, Minggu→Senin, pergantian tahun, dan offset zona waktu yang berbeda (offset disuntikkan agar test deterministik).

## 3.2 Mata Uang

```dart
class CurrencyService {
  int balance(String currencyId);
  CurrencyResult grant(String currencyId, int amount, {required String claimId});
  CurrencyResult spend(String currencyId, int amount);   // validasi dulu, tanpa efek samping jika gagal
}
```

Jumlah di-clamp ke `max_amount`. `grant` idempoten lewat `claimId`. Semua mutasi dipersistensikan dalam transaksi yang sama dengan perubahan state lain lewat save queue yang ada.

## 3.3 Boss dan Quest

```dart
class BossEvent { id, name, spriteRef, spriteTint, baseStats }
class BossEventService {
  BossEvent bossFor(Period p, int periodIndex);          // deterministik: index % pool.length
  BossReference resolveReference(CycleProgress, Map<String, DungeonProgressSnapshot>);
  DungeonDefinition buildBossDungeon(BossEvent, Period, BossReference); // satu ruangan boss
}

class BossReference { DungeonDefinition dungeon; int cycleRank; }
```

- **Acuan:** dungeon normal dengan `order` tertinggi yang `clearedInCycleRank == rank terpilih` (default Dungeon 1); rank = `ascensionRank` terpilih.
- `DifficultyService.profileForBoss(reference, powerFactor)` memakai profil yang sudah ada dan menambah `power_factor`.
- Run boss menyimpan `bossEventId`, `periodKeyAtStart`, `dungeonId` di snapshot sesi.

```dart
class BossQuestService {
  QuestState stateOf(String questId, String periodKey);
  BossQuestResult onBossDefeated({required String questId, required String periodKeyAtStart, required String currentPeriodKey});
}
```

Aturan: hadiah diberikan jika `periodKeyAtStart == currentPeriodKey` dan quest belum selesai untuk periode itu. Id klaim: `bossquest:{questId}:{periodKey}`. Hadiah gold dan EXP dikalikan `rewardMultiplier` dari profil acuan, shard sesuai konfigurasi, semuanya dalam satu transaksi atomik.

## 3.4 Stat Persentase

`EquipmentStats` mendapat `hpPct`, `atkPct`, `defPct`, dan operasi `+`, `scaled`, `roll`, `isEmpty` diperbarui. Item `fixed_stats` melewati `roll`. `DerivedStatsCalculator.calculate`:

```
rawHp  = (base.maxHp + flatHp) * (1 + min(totalHpPct,  cap))
rawAtk = (base.atk   + flatAtk) * (1 + min(totalAtkPct, cap))
rawDef = (base.def   + flatDef) * (1 + min(totalDefPct, cap))
```

Dibulatkan dan di-clamp seperti sekarang. `EquipmentStats.applyTo` tetap untuk stat angka tetap. Tampilan teks equipment dan perbandingan stat (`computeEquipmentStatDeltas`) ikut menampilkan persen.

## 3.5 Event Shop

```dart
class EventRotation {
  // Murni dan deterministik.
  List<EventShopEntry> entriesForWeek(int weekIndex, List<EventShopEntry> pool);
}
```

Algoritma: `cycleLength = pool.length / 2`; `cycleIndex = weekIndex ~/ cycleLength`; `slotInCycle = weekIndex % cycleLength`. Kocok item tier Epic dengan seed dari `cycleIndex`; pasangkan dengan item Legendary yang digeser secara deterministik hingga setiap pasangan berbeda slot. Setiap item tampil tepat sekali per siklus.

`EventShopService` menggunakan ulang inti `ShopService` dengan mata uang sebagai parameter (atau service terpisah jika refaktor terlalu invasif; agent mengusulkan dan melaporkan). Syarat: validasi sebelum mutasi, transaksi atomik, batas pembelian per `(entryId, periodKey)`, item non-sellable, hasil bertipe sealed.

## 3.6 Notifikasi

```dart
class PlannedNotification { int id; String channel; int fireAtMs; String title; String body; }

class NotificationPlanner {          // murni, mudah dites
  List<PlannedNotification> plan(NotificationInputs inputs);
}

abstract interface class NotificationScheduler {   // adapter platform
  Future<void> replaceAll(List<PlannedNotification> planned);
  Future<void> cancelAll();
  Future<bool> requestPermission();
}
```

`NotificationInputs`: waktu efektif, pengaturan (toggle per kategori, jam tenang), mode offline dan jangkar offline, status Daily/Weekly Quest, waktu reset, batas offline dari konfigurasi. Implementasi platform memakai `flutter_local_notifications` dan `timezone`, dengan penjadwalan tidak tepat waktu. Observer lifecycle tingkat aplikasi memanggil `plan` dan `replaceAll` saat `paused` dan `cancelAll` saat `resumed`.

Manifest: `POST_NOTIFICATIONS` dan `RECEIVE_BOOT_COMPLETED`, tanpa izin alarm tepat waktu. Tidak ada FCM.

---

# 4. PERSISTENSI DAN MIGRASI

| Versi | Milestone/Stage | Perubahan |
|---|---|---|
| v6 | M12 Stage 1 | Tabel `ClockStates` (playerId PK, lastSeenAtMs, forwardJumpCount, maxForwardJumpMs), `Currencies` (playerId, currencyId, amount; PK gabungan), `PeriodicQuestStates` (playerId, questId, periodKey, completedAtMs; PK gabungan) |
| v7 | M13 Stage 1 | Tabel `EventShopPurchases` (playerId, entryId, periodKey, purchasedCount; PK gabungan) dan kolom stat persen pada penyimpanan `EquipmentInstance` jika stat disimpan per kolom (agent memeriksa; jika berupa JSON, tidak ada kolom baru) |
| v8 | M14 | Metadata sinkronisasi cloud |

Aturan migrasi sama dengan v1.1: blok `from < N` berurutan dalam satu transaksi, test dari **setiap** versi lama (v1–v5 untuk v6, dan seterusnya) dengan data nyata, catatan breaking change.

Tabel dibuat di stage pertama yang memerlukannya dalam satu migrasi, walau penggunaannya baru di stage berikutnya, agar satu milestone tidak menaikkan versi berkali-kali.

## 4.1 Pemangkasan `ClaimedRewards`

Kebijakan konservatif (agent mengonfirmasi setelah audit): id klaim milik run yang sudah selesai dan lebih tua dari `retention_days` dihapus; id aktif tidak pernah dihapus (run berjalan, periode berjalan untuk `bossquest:`/`shop:`/`eventshop:`, dan ascension). Test wajib membuktikan tidak ada reward ganda setelah pemangkasan pada skenario recovery sesi, masuk ulang offline, ascension dua kali, dan pembelian shop ulang.

---

# 5. OFFLINE

- Run boss **tidak** diproses offline. Jika run aktif bertipe boss saat aplikasi ditutup, mode offline dipaksa `pauseProgression` (pola yang sama dengan Ascension Dungeon).
- Auto Farming tidak pernah menargetkan dungeon boss.
- Notifikasi Auto Farming penuh dijadwalkan dari jangkar offline + batas offline (konfigurasi yang ada).

---

# 6. BALANCE SIMULATOR (PERLUASAN)

- **Boss:** win rate pada level rekomendasi dungeon acuan, 10 level di bawah dan di atasnya, untuk rank 0, 1, 5, 10, 50, boss harian dan mingguan. Target: ≥ 85% (Daily), ≥ 80% (Weekly), < 50% pada −10 level.
- **Reward boss:** perbandingan gold dan EXP quest terhadap farming reguler (laporkan; tidak boleh melebihi sekitar satu jam farming di dungeon acuan, baseline).
- **Shard:** pendapatan per minggu terhadap harga event shop.
- **Dampak stat persen:** efek satu set event penuh terhadap win rate boss, dungeon, dan ascension; total persen tidak melampaui cap.
- Seluruh keluaran tidak boleh overflow atau `NaN`.

---

# 7. STRATEGI PENGUJIAN

- Baseline 545 test tetap hijau; perubahan test lama dicatat beserta alasannya.
- `flutter analyze` 0 issue di akhir setiap stage.
- Test periode dan jam (batas, zona waktu, jam mundur, lonjakan maju dicatat).
- Test idempotensi: hadiah quest, pembelian shop, grant shard.
- Test paritas online/offline untuk stat persen.
- Test deterministik rotasi boss dan event shop (identik di setiap pemanggilan, lintas batas siklus).
- Test migrasi v1–v5 → v6, dan v1–v6 → v7.
- Verifikasi perangkat di akhir M12 dan M13, termasuk notifikasi terjadwal (lihat prompt Stage 5).

# 8. REGISTER RISIKO

| Risiko | Mitigasi |
|---|---|
| Manipulasi jam maju mereset quest | Dicatat; divalidasi server di M14 |
| Hadiah ganda saat recovery atau pemangkasan | Id klaim, test skenario, kebijakan pemangkasan konservatif |
| Boss terlalu sulit dan tidak mungkin dikalahkan | Acuan mengikuti kemajuan, tanpa batas percobaan, simulator dengan target win rate |
| Stat persen mengubah keseimbangan | Cap di konfigurasi, simulator, tidak ada roll |
| Pool event 8 item habis dibeli | Pool dapat diperluas lewat data; dicatat sebagai keterbatasan konten |
| Notifikasi tidak muncul di perangkat tertentu | Penjadwalan tidak tepat waktu dan penghemat baterai vendor adalah batasan platform; dicatat |
| Dependensi baru | Persetujuan tertulis hanya untuk `flutter_local_notifications` dan `timezone` |
| Run melewati batas reset | Kasus tepi didokumentasikan: tidak ada hadiah |

**End of Addendum**
