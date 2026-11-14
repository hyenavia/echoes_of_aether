# ECHOES OF AETHER

## GAME DESIGN DOCUMENT — ADDENDUM v1.1 (M8–M11)

**Document Version:** 1.1-addendum
**Basis:** GAME_DESIGN_DOCUMENT v1.0
**Cakupan:** Multi-Dungeon, Level Tanpa Batas, Sistem Kesulitan, Ascension Cycle, Shop, UI Idle RPG
**Status:** Keputusan desain disepakati; siap diimplementasikan lewat M8–M11

---

# 0. CARA MEMBACA DOKUMEN INI

Addendum ini **menimpa** bagian GDD v1.0 yang disebut di tabel 0.1. Bagian GDD v1.0 yang tidak disebut tetap berlaku.

Semua angka bertanda **(baseline)** adalah nilai awal yang boleh disetel lewat balancing, tetapi harus tetap berada di file konfigurasi JSON, bukan konstanta di kode.

## 0.1 Perubahan terhadap GDD v1.0

| GDD v1.0                                         | Addendum v1.1                                                                  |
| ------------------------------------------------ | ------------------------------------------------------------------------------ |
| §3.3 Level naik sampai `max_level = 30`          | Level **tanpa batas** (§5)                                                     |
| §6.5 `Base Damage = max(1, ATK - DEF)`           | Rumus **rasio** (§6)                                                           |
| §8 Satu dungeon (Forgotten Forest)               | **5 dungeon normal + Ascension Dungeon**, siklus endless (§2–§4)               |
| §9.3 Revive gagal → kembali ke Town              | Kembali ke Town dengan **Farm Dungeon** terpilih otomatis (§7)                 |
| §12.1 Mode B memilih dungeon yang pernah selesai | Dungeon normal yang selesai **pada siklus saat ini** (§7)                      |
| §13 UI polos berbasis overlay                    | **UI Idle RPG** (§9)                                                           |
| §15.2 "Trading" dikecualikan dari MVP            | **Shop NPC** diizinkan. Trading antar-pemain dan gacha tetap dikecualikan (§8) |

## 0.2 Istilah

| Istilah               | Definisi                                                                            |
| --------------------- | ----------------------------------------------------------------------------------- |
| **Dungeon Normal**    | Dungeon biasa bernomor 1–5. Bisa dimainkan manual, Auto Farming, dan offline.       |
| **Ascension Dungeon** | Dungeon khusus setelah Dungeon 5 selesai. Hanya manual.                             |
| **Siklus (Cycle)**    | Satu putaran Dungeon 1 → 5 → Ascension Dungeon.                                     |
| **Ascension Rank**    | Jumlah siklus yang sudah diselesaikan. Mulai dari 0. Tanpa batas atas.              |
| **Farm Dungeon**      | Dungeon normal yang dipakai sebagai target farming dan titik kembali setelah kalah. |

---

# 1. ALUR PROGRESI

```
Siklus rank R:
Dungeon 1 → Dungeon 2 → Dungeon 3 → Dungeon 4 → Dungeon 5 (Final Boss)
        → Ascension Dungeon → Ascension Rank menjadi R+1
        → kembali ke Dungeon 1, kesulitan lebih tinggi
```

Yang **dipertahankan** setelah Ascension: level, EXP, gold, skill, specialization, inventory, equipment, riwayat clear seumur hidup.

Yang **di-reset**: status "sudah diselesaikan pada siklus ini" untuk setiap dungeon (hanya Dungeon 1 yang terbuka kembali) dan Farm Dungeon menjadi Dungeon 1.

---

# 2. MULTI-DUNGEON

## 2.1 Daftar Dungeon Normal

Setiap dungeon memakai struktur 5 room yang sama dengan Forgotten Forest: 3 room normal, 1 room elite, 1 room boss.

| #   | ID                 | Nama             | Elite              | Boss                              |
| --- | ------------------ | ---------------- | ------------------ | --------------------------------- |
| 1   | `forgotten_forest` | Forgotten Forest | Corrupted Guardian | Ancient Heart Guardian            |
| 2   | `crystal_cavern`   | Crystal Cavern   | Crystal Warden     | Prism Colossus                    |
| 3   | `ancient_crypt`    | Ancient Crypt    | Crypt Knight       | Crypt Lord                        |
| 4   | `ashen_wasteland`  | Ashen Wasteland  | Ashen Sentinel     | Ash Tyrant                        |
| 5   | `aether_sanctum`   | Aether Sanctum   | Sanctum Guardian   | **Aether Sovereign (Final Boss)** |

Nama monster dan boss di atas adalah **placeholder** dan boleh diganti lewat data tanpa mengubah kode.

## 2.2 Aset

- Layout map memakai ulang 5 map yang sudah ada (`forest_entrance_map`, dan seterusnya).
- Monster baru memakai ulang sprite monster yang sudah ada lewat field data `sprite_ref`, dengan `sprite_tint` opsional agar terlihat berbeda.
- Tidak ada aset gambar atau tileset baru pada M8–M11.

## 2.3 Monster per Dungeon

Setiap dungeon memiliki 3 tipe monster normal, 1 elite, dan 1 boss. Perbedaan antar dungeon berasal dari **stat dan pengali kesulitan**, bukan dari mekanik AI baru.

## 2.4 Aturan Unlock

- Dungeon 1 selalu terbuka.
- Dungeon N+1 terbuka ketika Dungeon N **diselesaikan pada siklus saat ini**.
- Ascension Dungeon terbuka ketika Dungeon 5 diselesaikan pada siklus saat ini.

## 2.5 Level Rekomendasi (baseline)

| Dungeon   | Rank 0 |
| --------- | ------ |
| 1         | 1      |
| 2         | 8      |
| 3         | 16     |
| 4         | 25     |
| 5         | 35     |
| Ascension | 45     |

Untuk rank R, level rekomendasi menjadi `rec(d, 0) + ceil(8 × ln(C(R)) / ln(1.5))`, dengan `C(R)` dari §4. Angka final ditentukan oleh simulator balancing (M8 Stage 6, M9 Stage 5).

UI wajib menampilkan level rekomendasi dan memberi peringatan jelas jika level pemain jauh di bawahnya.

---

# 3. ASCENSION DUNGEON

- Memakai **aset dan struktur room Dungeon 5** (Aether Sanctum), termasuk Final Boss.
- Kesulitan dasar adalah Dungeon 5 × **1.35** (`ascension_multiplier`, hasil tuning M9 Stage 5 dari baseline awal `2.0`), lalu dikalikan pengali siklus.
- **Hanya dimainkan manual.** Tidak ada Auto Farming, tidak ada Continue Dungeon offline.
- Kalah di Ascension Dungeon **tidak menghukum**: Ascension Rank tidak berubah, equipment dan loot yang sudah dikonfirmasi tetap dimiliki, dan pemain kembali ke Town dengan Farm Dungeon yang sama seperti sebelumnya.
- Menyelesaikan Ascension Dungeon:
  1. Ascension Rank bertambah 1 (tepat sekali, idempoten).
  2. Status clear per siklus di-reset (§1).
  3. Pemain mendapat reward ascension: EXP, gold, dan loot `ascension_clear_loot` dengan kualitas drop lebih baik (§4.4).
  4. Pemain kembali ke Town, Farm Dungeon menjadi Dungeon 1.

---

# 4. SISTEM KESULITAN

## 4.1 Pengali Efektif

```
Pengali efektif M = difficulty_scale(dungeon) × C(rank)
```

| Komponen                   | Rumus                                  | Baseline                                     |
| -------------------------- | -------------------------------------- | -------------------------------------------- |
| `difficulty_scale` dungeon | Geometrik, tercatat di `dungeons.json` | D1 1.0, D2 1.5, D3 2.25, D4 3.375, D5 5.0625 |
| Ascension Dungeon          | `difficulty_scale(D5) × 1.35`          | 6.834375                                     |
| `C(rank)`                  | `1 + 6.5 × rank` (linear, Option B)    | rank 0 → 1.0, rank 1 → 7.5, rank 5 → 33.5, rank 10 → 66.0 |

Kurva antar rank sengaja **linear**, bukan eksponensial, agar selalu ada "dinding lunak" yang bisa ditembus dengan level dan equipment lebih tinggi. Pada Option B (NG+ linear ladder), level rekomendasi tiap rank naik seragam `cycle_level_step = 44` (`rec(d, R) = rec(d, 0) + 44 × R`) sehingga Dungeon 1 Rank `R` dimulai tepat di level rekomendasi Ascension Rank `R - 1` (`49` pada Rank 1).

## 4.2 Penerapan ke Stat Monster

Stat monster akhir = stat dasar monster × `statModifier` spawn × pengali stat.

Untuk menjaga keseimbangan Rank 0 sekaligus menyelaraskan rank tinggi dengan kurva level rekomendasi (`rec(d, R)`), pengali stat memisahkan komponen `base_scale` (dungeon dasar) dan `cycle_factor` (`C(rank)`):
`pengali_stat = base_scale ^ stat_exponents × C(rank) ^ cycle_stat_exponents`

| Stat | Eksponen `base_scale` (`stat_exponents`) | Eksponen `C(rank)` (`cycle_stat_exponents`, opsional) |
| ---- | ---------------------------------------- | ----------------------------------------------------- |
| HP   | 1.0                                      | 0.25                                                  |
| ATK  | 1.0                                      | 0.22                                                  |
| DEF  | 0.9                                      | 0.20                                                  |

Pada Rank 0 (`C(0) = 1.0`), `cycle_stat_exponents` bernilai `1.0^e = 1.0` sehingga seluruh dungeon Rank 0 identik dengan kurva awal M8. Pengali diterapkan saat spawn, dan nilai rank disimpan di run saat dimulai agar tidak berubah di tengah run.

## 4.3 Penerapan ke Reward

EXP dan gold monster serta reward room/dungeon dikalikan `M^0.85` (baseline), dibulatkan, dan tidak pernah di bawah 1 jika reward dasarnya lebih dari 0. Reward naik lebih lambat dari stat monster agar dungeon lama tidak otomatis menjadi tempat farming terbaik.

## 4.4 Kualitas Drop per Rank (baseline)

- Peluang drop item rarity Rare ke atas dikalikan `1 + 0.1 × rank`, dengan batas atas pengali 3.0 dan peluang akhir tidak pernah melebihi 1.0.
- Bonus roll stat equipment `+0.02 × rank`, dengan batas atas +0.5.

Ini memberi pemain sumber kekuatan tambahan agar rank tinggi tetap dapat ditembus.

## 4.5 Pengaman

- Pengali dan stat dibatasi nilai maksimum teknis sehingga tidak overflow.
- Level rekomendasi tampil sebelum masuk dungeon, dan **Hard Lock** memblokir pemilihan maupun masuk ke dungeon jika `playerLevel < requiredLevel` (`1` untuk Dungeon 1 di semua rank agar pemain tidak pernah terkunci di Town, `recommendedLevel(d, rank)` untuk Dungeon 2..Ascension).
- Pemain yang sudah mencapai `highestAscensionRank >= 1` dapat berpindah bebas antara `Rank 0 .. highestAscensionRank` lewat **Rank Switcher** di Town untuk farming di rank bawah tanpa menghilangkan progres rank tertinggi.
- Kalah tidak mengurangi progres apa pun yang sudah didapat.

---

# 5. LEVEL TANPA BATAS

- `max_level` dihapus dari perilaku game (konfigurasi menerima `null` yang berarti tanpa batas).
- EXP untuk naik level (baseline): `expToNext(L) = 60 × L^1.8`.
- Pertumbuhan stat per level tetap linear: HP +15, ATK +2, DEF +0.5 (baseline).
- Skill tetap memiliki `maxLevel` sendiri. Keputusan itu terpisah dari level karakter.
- Save lama (level ≤ 30) tetap kompatibel. Karakter yang sebelumnya berada di level 30 dengan EXP 0 melanjutkan dari sana.
- Angka besar ditampilkan dalam format singkat (1.2K, 3.4M, 5.6B).
- Terdapat batas teknis pelindung overflow, tetapi bukan batas desain dan tidak boleh tampil di UI.

---

# 6. RUMUS DAMAGE

Rumus rasio menggantikan pengurangan langsung:

```
Base Damage = max(1, round(ATK × ATK / (ATK + DEF)))
```

Alasan:

- Damage tidak pernah menjadi 0 atau jatuh ke 1 secara paksa saat DEF melampaui ATK.
- Hasil tumbuh stabil ketika kedua sisi tumbuh bersama, cocok untuk game endless.
- Pada angka rendah hasilnya hampir sama dengan rumus lama, misalnya ATK 12 vs DEF 1 menjadi 11 (sebelumnya 11).

Aturan lain tidak berubah: crit mengalikan setelah base damage, skill multiplier mengalikan ATK sebelum perhitungan, magic memakai `magicDefenseFactor`.

Rumus dipilih lewat konfigurasi (`damage.formula`: `ratio` atau `subtractive`). Mode `subtractive` dipertahankan hanya untuk test regresi. Combat online dan offline wajib memakai instance kalkulator yang sama.

---

# 7. DEATH, RESPAWN, DAN AUTO FARMING

## 7.1 Farm Dungeon

- Default: dungeon normal tertinggi yang sudah diselesaikan pada siklus saat ini.
- Pemain boleh memilih dungeon normal yang lebih rendah (jalan keluar jika terlalu sulit).
- Memasuki dungeon normal mana pun memperbarui "dungeon normal terakhir dimasuki".

## 7.2 Kalah (revive gagal saat cooldown aktif)

- Run berakhir dan pemain kembali ke Town.
- Dungeon yang dipilih otomatis di Town adalah **dungeon normal terakhir yang dimasuki**. Jika pemain kalah di Ascension Dungeon, titik kembali tetap dungeon normal terakhir yang dimasuki sebelum ascension.
- Loot dan reward yang sudah dikonfirmasi tetap dimiliki. Room/dungeon yang gagal tidak memberi clear reward.
- Setelah beberapa kekalahan beruntun pada dungeon yang sama (baseline: 3), game menyarankan memilih dungeon yang lebih rendah.

## 7.3 Offline

- **Auto Farming (Mode B):** hanya dungeon normal yang sudah diselesaikan pada siklus saat ini, dengan default Farm Dungeon. Loop berjalan di sana.
- **Continue Dungeon (Mode A):** hanya untuk run dungeon normal. Jika run aktif adalah Ascension Dungeon, offline dipaksa **Pause Progression**.
- Kebijakan `stopOnDefeat` tetap berlaku: satu kekalahan menghentikan Auto Farming offline dan reward yang sah tetap dipertahankan.
- Batas offline 8 jam dan perlindungan reward ganda tidak berubah.

---

# 8. SHOP

Shop adalah NPC di Town. Ini bukan trading antar-pemain.

## 8.1 Beli

- Barang berupa equipment (dan consumable hanya jika consumable sudah memiliki fungsi di game).
- Equipment yang dibeli dibuat sebagai instance baru lewat proses roll yang sama dengan loot drop.
- Pembelian gagal tanpa mengurangi gold jika gold kurang, requirement belum terpenuhi, atau tas penuh.

## 8.2 Jual

- Pemain dapat menjual item dari inventory dan equipment dari tas.
- Equipment yang sedang dipakai tidak bisa dijual.
- Item rarity Rare ke atas meminta konfirmasi.
- Material dapat dijual dalam jumlah banyak sekaligus.
- Harga jual wajib jauh di bawah harga beli (maksimal 40% dari harga beli, baseline).

## 8.3 Harga

**Makin langka rarity, makin besar harga.** Pita harga beli (baseline):

| Rarity    | Harga beli   |
| --------- | ------------ |
| Common    | 10–20        |
| Uncommon  | 40–80        |
| Rare      | 150–400      |
| Epic      | 1.000–2.500  |
| Legendary | 8.000–15.000 |

Harga minimum rarity yang lebih tinggi harus lebih besar dari harga maksimum rarity di bawahnya. Validator konfigurasi menegakkan ini.

## 8.4 Requirement (item rarity tinggi)

| Jenis                | Keterangan                                                                      |
| -------------------- | ------------------------------------------------------------------------------- |
| `min_level`          | Level karakter minimal                                                          |
| `dungeon_cleared`    | Dungeon tertentu pernah diselesaikan seumur hidup (tidak hilang saat ascension) |
| `min_ascension_rank` | Ascension Rank minimal                                                          |

Baseline pemakaian: Rare memakai `min_level`; Epic memakai `min_level` dan `dungeon_cleared`; Legendary memakai `min_ascension_rank ≥ 1` dan harga tertinggi, sehingga Ascension menjadi hadiah nyata. Requirement yang belum terpenuhi harus tampil jelas di UI.

## 8.5 Stok

Stok tetap, dengan `purchase_limit` opsional per barang. Tidak ada rotasi stok berbasis jam perangkat.

---

# 9. UI IDLE RPG

Tujuan: tampilan tidak polos, informasi jelas, tetap tidak mengganggu auto combat (GDD §13). UI tetap bukan sumber kebenaran state gameplay.

- **Navigasi bawah** di Town: Adventure, Hero, Bag, Shop, Settings.
- **Top bar:** level, bar EXP, gold, Ascension Rank.
- **Kartu item** dengan warna rarity dan ikon slot.
- **Panel Hero:** stat, specialization, skill.
- **Pemilih dungeon** berupa daftar berjenjang: terkunci/terbuka, level rekomendasi, status clear.
- **HUD dungeon** yang dirapikan dan **layar hasil** yang lebih informatif.
- Palet mengikuti GDD §14.2 dan nuansa pixel art.
- Tidak ada aset gambar baru yang wajib. Ikon memakai ikon bawaan Flutter atau bentuk sederhana.

---

# 10. ASUMSI YANG DAPAT DIUBAH

| ID  | Asumsi                                                                                                                                                                                             | Dampak jika diubah                                                                                          |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| A-1 | Auto Farming offline tetap berhenti setelah satu kekalahan (`stopOnDefeat`).                                                                                                                       | Mengubahnya ke "lanjut loop" butuh batas kekalahan beruntun agar tidak death loop.                          |
| A-2 | Legendary di shop hanya untuk `min_ascension_rank ≥ 1`.                                                                                                                                            | Bisa dilonggarkan atau Legendary dihapus dari shop.                                                         |
| A-3 | Dungeon baru hanya mengubah stat dan nama, bukan mekanik.                                                                                                                                          | Mekanik baru berarti milestone baru.                                                                        |
| A-4 | Ascension Dungeon = Dungeon 5 × 1.35 (`ascension_multiplier`) pada rank yang sama (di-tune dari baseline awal 2.0 di M9 Stage 5 agar seimbang untuk ketiga kelas di Lv 49).                        | Angka 1.35 ada di konfigurasi `game_config.json`.                                                           |
| A-5 | Pengali siklus `C(rank)` linear `1 + 0.4 × rank` dengan `cycle_stat_exponents` `{hp: 0.25, atk: 0.20, def: 0.18}` khusus faktor rank agar formula `rec(d, R)` tetap dapat ditembus di rank tinggi. | Konfigurasi di `game_config.json` (bila `cycle_stat_exponents` dihapus, jatuh kembali ke `stat_exponents`). |
| A-6 | Respawn kembali ke Town dengan dungeon terakhir terpilih, bukan langsung masuk run baru.                                                                                                           | Mengubahnya menjadi auto-restart perlu persetujuan terpisah.                                                |
| A-7 | Nama monster/dungeon adalah placeholder.                                                                                                                                                           | Hanya perubahan data.                                                                                       |

---

# 11. DI LUAR LINGKUP M8–M11

- Aset visual atau tileset baru per biome.
- Mekanik monster atau boss baru (pola serangan khusus).
- Rotasi stok shop, gacha, trading antar-pemain, crafting, dan pet.
- Server atau fitur online apa pun.

**End of Addendum**
