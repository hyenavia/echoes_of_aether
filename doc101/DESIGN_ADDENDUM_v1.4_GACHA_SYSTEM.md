# ECHOES OF AETHER

## GAME DESIGN DOCUMENT — ADDENDUM v1.4 (M15 GA CHA ECOSYSTEM)

**Document Version:** 1.4-addendum  
**Basis:** GAME_DESIGN_DOCUMENT v1.0 + ADDENDUM v1.1 + ADDENDUM v1.2 + ADDENDUM v1.3  
**Cakupan:** Sistem Gacha (Specialization Awakening & Mythical Armory), Roster Class Mythical, Senjata Signature, Pity Terpisah, Ekonomi Aether Shard (Daily/Weekly Boss + Menara Spiral Abyss), Duplikat Soul Prism, dan Refactor Weekly Shop.  
**Status:** DRAFT RANCANGAN — Menunggu Konfirmasi Eksekusi Pemilik Project  

---

# 1. LATAR BELAKANG DAN PRINSIP INTI

Penambahan sistem gacha pada *Echoes of Aether* dirancang untuk memberikan variasi progres jangka panjang (*horizontal & vertical progression*) tanpa merusak identitas inti game sebagai **Single-Hero Offline-First RPG**:

1. **Bukan Multi-Character Party:** Pemain tetap mengendalikan **satu karakter utama**. Gacha membuka lisensi spesialisasi baru (**Class Specialization**) yang dapat diganti kapan saja di luar combat.
2. **Kasta Rarity yang Adil:**
   - **Class Bawaan (Starter):** *Vanguard*, *Arcanist*, *Ranger* berstatus **Legendary**. Tetap kompetitif dan dapat menyelesaikan seluruh dungeon normal.
   - **Class Gacha:** Berstatus **Mythical** (6 Class baru dengan visual sprite dan sinergi unik).
   - **Equipment:** Menambahkan tingkat **Mythical** di atas *Legendary* (memiliki *Signature Resonance Trait*).
3. **Ekonomi Terpadu & Sumber Mata Uang Gacha:**
   - Gacha hanya menggunakan **Aether Shard**.
   - Sumber Aether Shard: **Daily Boss Quest** (10/hari), **Weekly Boss Quest** (50/minggu), dan **Menara Spiral Abyss / Abyssal Boss Spire** (hingga 1.960 per siklus 2 mingguan).
4. **Pity Terpisah (Anti-Sakit Hati):**
   - Banner Class dan Banner Senjata memiliki tab dan counter jaminan (pity) independen. Memperoleh senjata tidak akan mereset tabungan pity class.
5. **Konversi Duplikat (Soul Prism):**
   - Mendapatkan duplikat Class otomatis menghasilkan **1x Soul Prism**.
   - Toko Penukaran (*Sanctuary*): 2 Prism = Bebas pilih Senjata Mythical; 3 Prism = Bebas pilih Class Mythical.
6. **Refactor Weekly Shop:**
   - Weekly Shop tidak lagi mengonsumsi Aether Shard.
   - Dialihkan menjadi sistem **Barter Material Dungeon + Gold + Salvage Scrap/Dust** (hasil daur ulang equipment).

---

# 2. EKONOMI AETHER SHARD & SIMULASI PULL

### 2.1 Aliran Pendapatan Aether Shard

| Sumber | Frekuensi / Siklus | Pendapatan Shard |
|---|---|---|
| **Daily Boss Quest** | Harian (7 hari) | 70 Shard / minggu |
| **Weekly Boss Quest** | Mingguan | 50 Shard / minggu |
| **Menara Spiral Abyss (Lantai 1–20)** | 2 Mingguan (Biweekly) | s.d. 1.960 Shard / 2 minggu |
| **Total Pemain Kasual (Spire Lt 1–8)** | Per 2 Minggu | ~500 – 700 Shard (~250 – 350 / minggu) |
| **Total Pemain Endgame (Full Clear Spire)** | Per 2 Minggu | **2.200 Shard** (~1.100 / minggu) |

### 2.2 Biaya Pull & Batas Pity

* **Biaya 1x Pull:** `30 Aether Shard`
* **Biaya 10x Pull:** `300 Aether Shard`
* **Durasi Rotasi Banner:** **3 Minggu (21 Hari)** per banner.
  * Dalam 1 periode banner (3 minggu), pemain endgame mengumpulkan ~**3.300 Shard** (setara **110 Pull**).
  * Pemain midgame mengumpulkan ~**1.200 – 1.800 Shard** (setara **40 – 60 Pull**).
* **Aturan Pity Independen:**
  * **Class Awakening Banner:** Hard Pity di **40 Pull** (1.200 Shard). Dijamin Class 5★ Mythical.
  * **Mythical Armory Banner:** Hard Pity di **30 Pull** (900 Shard). Dijamin Senjata Mythical.
  * **Aturan Rate-Up 50/50:** 50% peluang mendapatkan item banner aktif. Jika kalah 50/50, 5★ berikutnya 100% dijamin item featured banner.
  * **Pity Carryover:** Sisa hitungan pity dan status guarantee tersimpan dan berlanjut ke banner 3 minggu berikutnya.

---

# 3. ROSTER CLASS & SENJATA SIGNATURE

Tersedia 6 Class Mythical yang berotasi bergantian:

| Class | Peran / Archetype | Senjata Signature (Mythical) | Efek Resonansi Khusus (Resonance Trait) |
|---|---|---|---|
| **1. Paladin** | Tank / Holy Bruiser / Sustained | *Dawn's Aegis Blade* | Saat memblokir/terkena serangan, memicu ledakan holy nova yang memulihkan 5% Max HP dan memberikan damage area sebesar 35% DEF. |
| **2. Voidblade** | Melee Burst / Assassin / Agility | *Shadowfang Twinblade* | Serangan kritikal memberi tanda *Shadow Mark*. Menyerang target bertanda menghasilkan True Damage (mengabaikan 100% Armor). |
| **3. Chronomancer** | Magic / Cooldown Control | *Hourglass of Eternity* | Setiap 4x penggunaan skill, membekukan (Freeze) seluruh monster biasa di ruangan selama 2 detik. |
| **4. Gunslinger** | Ranged / Piercing Firearm | *Aether Railgun* | Jangkauan serang +2 petak. Peluru menembus seluruh monster dalam satu garis lurus tanpa pengurangan damage. |
| **5. Necromancer** | Dark Magic / Minion & Lifesteal | *Scythe of the Harvester* | Serangan menghasilkan +8% Lifesteal pasif. Minion bayangan mewarisi 50% HP dan ATK hero. |
| **6. Stormcaller** | AoE Burst / Chain Lightning | *Thunderlord's Scepter* | Serangan petir menyambar ke +2 musuh tambahan dan menyebabkan efek Shock (+15% damage diterima). |

---

# 4. SISTEM DUPLIKAT & TOKO PENUKARAN (SANCTUARY)

Jika pemain menarik Class Mythical yang sudah dimiliki:
1. Tidak ada stat duplikat yang rumit (menghindari power creep berlebihan).
2. Class otomatis terkonversi menjadi **1x Soul Prism**.
3. **Menu Toko Sanctuary (Permanen):**
   - **2x Soul Prism:** Memilih 1 Senjata Mythical mana pun yang pernah rilis.
   - **3x Soul Prism:** Memilih 1 Class Mythical mana pun dari daftar roster.
4. Memberikan jaminan mutlak (*absolute safety net*) bagi pemain yang kurang beruntung dalam gacha.

---

# 5. REFACTOR WEEKLY EVENT SHOP

Untuk menghindari kanibalisasi Aether Shard:
1. **Weekly Shop** berganti nama menjadi **Dungeon Outpost / Exchange Post**.
2. Mata uang pembelian:
   - **Gold** (mata uang standar).
   - **Boss Remnants / Dungeon Core** (drop material dari boss dungeon).
   - **Aether Scrap / Dust** (didapat dari fitur baru: *Salvage / Bongkar Equipment* yang tidak terpakai).
3. Barang dagangan: Material upgrade, consumable langka, dan rotation equipment Epic/Legendary.
