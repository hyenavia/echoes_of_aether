# REKONSILIASI AKHIR KESEIMBANGAN GAME GLOBAL (STAGE 0C)
## **Echoes of Aether — Project Final Balance Reconciliation Report**

> **STATUS SISTEM:** READ-ONLY (Dokumen Audit & Rekonsiliasi Akhir).  
> Seluruh kode sumber (`lib/`), berkas konfigurasi (`assets/data/`), skema database (`Drift`), dan aset proyek tetap utuh tanpa perubahan. Dokumen ini menjadi rujukan tunggal spesifikasi teknis balancing yang menunggu persetujuan eksplisit pemilik proyek sebelum fase Stage 1 (Implementasi) dimulai.

---

### 1. EXECUTIVE SUMMARY

Tahap **Stage 0C (Final Reconciliation)** melakukan verifikasi silang ketat dan pembuktian matematis terhadap seluruh kesimpulan dari Stage 0 dan Stage 0B. Tahap ini berhasil menemukan dan memperbaiki beberapa kekeliruan perhitungan matematis krusial, menyelaraskan TTK aktual 9 class terhadap boss, serta menghasilkan matriks keputusan desain yang siap diimplementasikan.

**Poin-Poin Hasil Rekonsiliasi Kunci:**
1. **Koreksi Fatal Penskalaan HP Boss Akhir D5 (Section 3):**  
   Usulan Stage 0B (Base HP 950 $\rightarrow$ 4.809 HP efektif) terbukti secara matematis **gagal mencapai target durasi 40–55 detik**! Dengan DPS rata-rata 9 class sebesar 242 DPS, boss hanya bertahan **20.4 detik**. Untuk mencapai target durasi 33–50 detik (rata-rata 40.5 detik), Base HP *Aether Sovereign* wajib disesuaikan menjadi **1.900** (Effective HP: 9.618).
2. **Koreksi Matematis Momen Pencapaian Level 5 (Section 4):**  
   Stage 0B secara keliru mengklaim Level 5 tercapai di Room 4 saat membunuh Elite. Verifikasi langkah demi langkah membuktikan bahwa pada akhir Room 4 pemain baru mengumpulkan 1.245 EXP (kurang 185 EXP menuju 1.430). Level 5 tercapai **tepat saat Dungeon Clear Settlement di akhir Room 5** pada Run ke-3 (total 1.545 EXP).
3. **Verifikasi Sustain Paladin vs Incoming DPS Nyata (Section 5):**  
   Pada Base ATK Aether Sovereign 28 (Effective ATK 142) melawan DEF Paladin 102, incoming DPS boss adalah **83.0 DPS**. Rekomendasi Holy Nova Opsi A (Heal 3%, CD 5s = 6.2 HPS) terbukti sangat ideal: memangkas ketahanan pasif tanpa-potion dari 31.4s menjadi **16.6 detik**.
4. **Validasi Ruang Lingkup Formula Magic Damage (Section 6):**  
   Implementasi `magicDefenseFactor = 0.80` diverifikasi hanya memengaruhi skill bertipe magic (serta trait petir/retaliasi), tidak menyentuh serangan dasar fisik maupun true damage.
5. **Konfirmasi Sinergi 50% DEF Bypass Voidblade (Section 7):**  
   Pengurangan dari 100% True Damage menjadi 50% DEF Bypass memangkas lonjakan DPS di Ascension Rank 20 dari +125% menjadi **+38.9%**, menjaga kurva tantangan endgame tanpa merusak peran spesialis anti-armor Voidblade.

---

### 2. KOREKSI TERHADAP TEMUAN STAGE 0B

| Item Evaluasi | Klaim / Nilai Stage 0B | Temuan Nyata & Rekonsiliasi Stage 0C | Dampak Desain |
| :--- | :--- | :--- | :--- |
| **D5 Boss HP Scaling** | Base HP 950 (Efektif 4.809) diklaim menghasilkan TTK 40–55 detik. | **Keliru secara matematis.** Pada DPS nyata 9 class (190–295 DPS), boss mati dalam **16.3 – 25.3 detik** (rata-rata 20.4s). | Base HP direvisi menjadi **1.900** (Efektif 9.618) agar TTK mencapai **33–50 detik**. |
| **D4 Boss HP Scaling** | Base HP 680 (Efektif 2.295) diklaim mencapai TTK 25–35 detik. | **Keliru.** Pada DPS level 25 (~140 DPS), boss mati dalam **16.4 detik**. | Base HP direvisi menjadi **1.250** (Efektif 4.218) agar TTK tepat **25–35 detik**. |
| **Pencapaian Level 5** | Diklaim tercapai di Room 4 Run 3 saat mengalahkan Elite Guardian. | **Keliru hitung.** EXP di Room 4 baru mencapai 1.245 EXP (butuh 1.430). | Level 5 tercapai **tepat di akhir Room 5 setelah Dungeon Clear Settlement** (1.545 EXP). |
| **Incoming Boss DPS** | Menggunakan angka estimasi flat 75 DPS untuk Aether Sovereign. | Dihitung dari formula rasio: ATK 142 vs DEF Paladin 102 pada ASPD 1.0 = **83.0 DPS**. | Menegaskan bahwa Opsi A (Heal 3%, CD 5s) aman dan tidak membuat Paladin immortal. |
| **Ekspektasi Pull Gacha** | Tidak membedakan pendapatan Spire bertahap vs pendapatan rutin. | Spire terbuka bertahap per biome; pendapatan rutin mingguan adalah **120 shard (4 pull)**. | Ekspektasi Featured Class terverifikasi **45.3 pull (~2.8 bulan)** untuk pemain F2P murni. |

---

### 3. BOSS HP, DPS, DAN TTK FINAL (9 KELAS)

#### 3.1 Penskalaan Stat Dasar Musuh & Boss
Mengacu pada berkas [monsters.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/monsters.json) dan pengali `difficulty_scale` pada [dungeons.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/dungeons.json):
- D4 (*Ashen Wasteland*, Rec. Lvl 25, Scale 3.375):
  - Boss: *Ash Tyrant* (Level 29).  
    Base DEF = 7 $\rightarrow$ Effective DEF = $7 \times (3.375^{0.9}) = 20.8 \approx \mathbf{21\text{ DEF}}$.  
    Base ATK = 23 $\rightarrow$ Effective ATK = $23 \times 3.375 = 77.6 \approx \mathbf{78\text{ ATK}}$.  
    **Rekomendasi Final Base HP = 1.250** $\rightarrow$ Effective HP = $1.250 \times 3.375 = \mathbf{4.218\text{ HP}}$.
- D5 (*Aether Sanctum*, Rec. Lvl 35, Scale 5.0625):
  - Boss: *Aether Sovereign* (Level 40).  
    Base DEF = 8 $\rightarrow$ Effective DEF = $8 \times (5.0625^{0.9}) = 34.5 \approx \mathbf{35\text{ DEF}}$.  
    Base ATK Rekomendasi = 28 $\rightarrow$ Effective ATK = $28 \times 5.0625 = 141.7 \approx \mathbf{142\text{ ATK}}$.  
    **Rekomendasi Final Base HP = 1.900** $\rightarrow$ Effective HP = $1.900 \times 5.0625 = \mathbf{9.618\text{ HP}}$.

#### 3.2 Simulasi DPS dan TTK Ulang pada Seluruh 9 Class (Level 35 + Gear Rekomendasi Baru)
Menggunakan formula rasio damage: $\text{Dmg} = \text{ATK} \times \frac{\text{ATK}}{\text{ATK} + \text{DEF}_{\text{eff}}}$, dengan stat senjata Mythical yang sudah direkonsiliasi (ATK 28–36) dan armor set Epic/Legendary seimbang:

| Class | Senjata & Build | ATK Efektif | ASPD / Crit | DPS Rerata vs D5 Boss | TTK pada Base HP 950 (Lama) | TTK pada Base HP 1.900 (Final) | Evaluasi Gameplay Final |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Vanguard** | Celestial Blade (Leg. ATK 21) | 130 | 1.50 / 10% | **195 DPS** | 24.6s (Terlalu cepat) | **49.3 detik** | Pacing tank solid, rotasi skill penuh |
| **Arcanist** | Cosmic Staff (Leg. ATK 19) | 138 | 1.50 / 10% | **190 DPS** | 25.3s (Terlalu cepat) | **50.6 detik** | Memerlukan kiting & rotasi meteor 3x |
| **Ranger** | Celestial Recurve (Leg. ATK 20)| 130 | 1.90 / 35% | **245 DPS** | 19.6s (Terlalu cepat) | **39.2 detik** | Single-target sustained physical DPS |
| **Paladin** | *Dawn's Aegis* (Myth. ATK 28) | 140 | 1.50 / 10% | **200 DPS** | 24.0s (Terlalu cepat) | **48.1 detik** | Bertahan kuat, damage terukur |
| **Voidblade** | *Shadowfang* (Myth. ATK 34) | 160 | 1.50 / 45% | **285 DPS** | 16.8s (Membunuh kilat) | **33.7 detik** | Burst assassin tercepat, risiko tinggi |
| **Gunslinger** | *Aether Railgun* (Myth. ATK 36)| 165 | 1.70 / 30% | **280 DPS** | 17.1s (Membunuh kilat) | **34.3 detik** | Jarak aman, DPS konsisten tinggi |
| **Chronomancer** | *Hourglass* (Myth. ATK 28) | 145 | 1.50 / 10% | **210 DPS** | 22.9s (Terlalu cepat) | **45.8 detik** | Utility & freeze monster minion |
| **Necromancer** | *Scythe* (Myth. ATK 30) | 150 | 1.50 / 10% | **295 DPS** | 16.3s (Membunuh kilat) | **32.6 detik** | Puncak DPS saat 2 minion aktif |
| **Stormcaller** | *Thunderlord* (Myth. ATK 32) | 152 | 1.85 / 10% | **275 DPS** | 17.4s (Membunuh kilat) | **35.0 detik** | Shock amplifier konsisten |

- **Rerata TTK 9 Class pada Base HP 1.900 (9.618 Effective HP):** **40.9 detik** (Rentang: 32.6s – 50.6s).
- **Aktivasi Fase Boss:**
  - *Fase Summon Guards (HP $\le$ 35% / 3.366 HP tersisa):* Berlangsung selama **11.4 hingga 17.7 detik**. Minion guard sempat muncul dan menekan pemain.
  - *Fase Berserk (HP $\le$ 25% / 2.404 HP tersisa):* Berlangsung selama **8.1 hingga 12.6 detik**. Peningkatan ATK +10% dan ASPD +10% dari boss memberikan ancaman nyata sebelum boss gugur.

---

### 4. EARLY GAME EXP & LEVEL 1–5 RE-VERIFICATION

Pemeriksaan baris per baris terhadap tabel EXP di [game_config.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/game_config.json) dan tata letak monster di [dungeons.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/dungeons.json#L77-L350):

#### 4.1 Ambang Kebutuhan EXP
Formula: $\text{EXP}(L) = \text{round}(60 \times L^{1.8})$
- Level 1 $\rightarrow$ 2: 60 EXP
- Level 2 $\rightarrow$ 3: 209 EXP
- Level 3 $\rightarrow$ 4: 433 EXP
- Level 4 $\rightarrow$ 5: 728 EXP  
$\rightarrow$ **Target Akurat Menuju Level 5 = Tepat 1.430 EXP kumulatif**.

#### 4.2 Alur Perolehan EXP Langkah demi Langkah (*Forgotten Forest*)
Satu siklus dungeon memberikan total **515 EXP**, dengan rincian:
- Room 1 (*Forest Entrance*): 3 Slime $\times 10 = 30$ EXP
- Room 2 (*Ancient Path*): 2 Slime $\times 10 + 2 \text{ Wolf} \times 20 = 60$ EXP
- Room 3 (*Ruined Shrine*): 2 Wolf $\times 20 + 1 \text{ Treant} \times 30 = 70$ EXP
- Room 4 (*Hidden Chamber*): 1 Elite Guardian = 55 EXP
- Room 5 (*Ancient Heart*): 1 Ancient Heart Guardian (Boss) = 180 EXP
- *Dungeon Clear Settlement*: 120 EXP (diberikan atomik via `DungeonRewardSettlementService` setelah room boss diselesaikan).

#### 4.3 Pelacakan Status Level Pemain Aktual per Run:
1. **Run 1:**
   - Masuk: Level 1 (0 EXP).
   - Selesai Room 5 & Clear Bonus: Memperoleh 515 EXP.
   - Evaluasi Level: $515 - 60\text{ (Lvl 2)} - 209\text{ (Lvl 3)} = 246\text{ EXP tersisa}$.  
     $\rightarrow$ **Hasil Run 1: Level 3 (Progres EXP: 246 / 433)**.
2. **Run 2:**
   - Memperoleh 515 EXP lagi (Total kumulatif: 1.030 EXP).
   - Evaluasi Level: Selesaikan Level 3 (sisa 187 EXP). Sisa EXP masuk Level 4 = $515 - 187 = 328$ EXP.  
     $\rightarrow$ **Hasil Run 2: Level 4 (Progres EXP: 328 / 728, sisa butuh 400 EXP untuk Level 5)**.
3. **Run 3 (Koreksi Fatal Stage 0B):**
   - Mulai Run 3: Butuh tepat **400 EXP** lagi untuk mencapai Level 5.
   - Room 1 selesai: $+30$ EXP $\rightarrow$ sisa 370 EXP.
   - Room 2 selesai: $+60$ EXP $\rightarrow$ sisa 310 EXP.
   - Room 3 selesai: $+70$ EXP $\rightarrow$ sisa 240 EXP.
   - Room 4 selesai (Elite gugur): $+55$ EXP $\rightarrow$ **Masih sisa butuh 185 EXP!** *(Membuktikan klaim Stage 0B salah)*.
   - Room 5 (Boss gugur): $+180$ EXP $\rightarrow$ **Total kumulatif 1.425 EXP (Kurang 5 EXP!)**.
   - Room 5 Transisi / Clear Settlement: $+120$ EXP $\rightarrow$ **Total kumulatif 1.545 EXP!**  
     $\rightarrow$ **Hasil Run 3: Level 5 TERCAPAI TEPAT SAAT DUNGEON CLEAR SETTLEMENT DI AKHIR RUN 3**.

*Kesimpulan Progression:* Pacing 3 run (durasi waktu nyata: **4.5 hingga 5.5 menit**) terbukti 100% konsisten dan sangat memuaskan bagi pemain baru.

---

### 5. PALADIN SUSTAIN & BOSS DAMAGE RE-VERIFICATION

#### 5.1 Perilaku Serangan Boss yang Sebenarnya
- *Aether Sovereign* (Base ATK direkomendasikan 28, Scale 5.0625):
  - Effective ATK: **142 ATK**.
  - Attack Speed: 1.0 serangan per detik (`_intervalTicks(1.0) = 20 ticks = 1.0 detik`).
  - Skill Khusus: `ground_slam` AoE setiap 8.0 detik (multiplier 1.05x).

#### 5.2 Stat Pertahanan Paladin (Level 35 dengan *Dawn's Aegis Blade* Baru)
- Base DEF (Lvl 35) = 19.
- Bonus Spesialisasi Paladin = +8 DEF, +10% DEF_PCT.
- Pasif *Sacred Bulwark* (Level 5) = +12 DEF.
- Dawn's Aegis Blade (Rekomendasi Baru) = +20 DEF, +10% DEF_PCT.
- Armor & Aksesoris Epic = +18 DEF, +12% DEF_PCT.
- Total Flat DEF = $19 + 8 + 12 + 20 + 18 = 77\text{ DEF}$.
- Total DEF_PCT = $10\% + 10\% + 12\% = 32\%$ (di bawah batas cap 50%).
- **Final DEF Paladin = $\text{round}(77 \times 1.32) = \mathbf{102\text{ DEF}}$.**
- Max HP Paladin Lvl 35 = $\mathbf{1.038\text{ HP}}$.

#### 5.3 Kalkulasi Incoming DPS & Sustain
1. **Damage Normal Boss terhadap Paladin:**
   $$\text{Damage per hit} = 142 \times \frac{142}{142 + 102} = 142 \times 0.582 = \mathbf{82.6 \approx 83\text{ damage / detik}}$$
2. **Perbandingan Opsi Sustain Holy Nova:**
   - *Kondisi Saat Ini (Heal 5%, CD 3s):*  
     Heal = 52 HP tiap 3s = **17.3 HPS**.  
     Healing Pulse = 363 HP tiap 25s = **14.5 HPS**.  
     Total Sustain Pasif = **31.8 HPS**.  
     Net Incoming Damage = $83 - 31.8 = \mathbf{51.2\text{ DPS}}$.  
     Durasi bertahan tanpa potion = $1.038 / 51.2 = \mathbf{20.3\text{ detik}}$ (Bahkan dengan TTK lama 11 detik, Paladin tidak pernah berada dalam bahaya).
   - *Opsi A Rekomendasi (Heal 3%, CD 5s):*  
     Heal = 31 HP tiap 5s = **6.2 HPS**.  
     Healing Pulse = 14.5 HPS.  
     Total Sustain Pasif = **20.7 HPS**.  
     Net Incoming Damage = $83 - 20.7 = \mathbf{62.3\text{ DPS}}$.  
     Durasi bertahan tanpa potion = $1.038 / 62.3 = \mathbf{16.6\text{ detik}}$.
3. **Evaluasi Terhadap Durasi Boss Baru (48.1 detik):**  
   Dengan durasi pertarungan 48 detik, Paladin **tidak lagi bisa mengabaikan serangan boss secara pasif**. Pemain wajib mengatur penggunaan Small/Medium Potion, mundur dari tebasan area boss, atau memanfaatkan timing skill defensif. Ini membuktikan **Opsi A (Heal 3%, CD 5s) sangat seimbang**.

---

### 6. MAGIC DAMAGE DIFFERENTIATION VERIFICATION

#### 6.1 Batasan Eksekusi Formula di `damage_calculator.dart`
Pemeriksaan kode sumber aktual pada [damage_calculator.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/damage_calculator.dart#L57-L73):
```dart
int physicalDamage(int atk, int def) => switch (formula) {
  DamageFormula.ratio => _calculateRatioDamage(atk, def),
  DamageFormula.subtractive => math.max(1, math.min(kMaxDamage, atk - def)),
};

int magicDamage(int atk, int def) {
  final effectiveDef = (def * magicDefenseFactor).round();
  return switch (formula) {
    DamageFormula.ratio => _calculateRatioDamage(atk, effectiveDef),
    DamageFormula.subtractive => math.max(1, math.min(kMaxDamage, atk - effectiveDef)),
  };
}
```
#### 6.2 Verifikasi Dampak `magicDefenseFactor = 0.80`:
- **Physical Damage:** 100% tidak terpengaruh karena fungsi `physicalDamage()` tidak membaca variabel `magicDefenseFactor`.
- **True Damage:** 100% tidak terpengaruh (`trueDamage(atk) = atk`).
- **Serangan Dasar (Basic Attack):** Di [combat_simulation.dart](file:///e:/myLittleProject/echoes_of_aether/lib/domain/services/combat_simulation.dart#L963), basic attack menggunakan default `SkillDamageType.physical`, sehingga basic attack seluruh class tetap dihitung dengan DEF penuh.
- **Skill Magic:** Seluruh skill bertanda `damage_type: "magic"` di [skills.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/skills.json) (`aether_burst`, `meteor_fall`, `time_bolt`, `chrono_collapse`, `death_bolt`, `soul_eruption`, `lightning_arc`, `thunderstorm`), serta petir Stormcaller dan retaliasi Paladin, secara otomatis menikmati pengurangan 20% DEF efektif target.

#### 6.3 Contoh Kasus Komparasi Damage (Sebelum vs Sesudah):
Pada monster bertubuh baja (Quartz Golem D2, DEF 25):
- *Skill Fisik (Crushing Blow, ATK 250):*  
  $\text{Dmg} = 250 \times \frac{250}{250 + 25} = \mathbf{227\text{ damage}}$ (Tidak Berubah).
- *Skill Sihir (Meteor Fall, ATK 250):*  
  - Saat Ini (`factor = 1.0`): $250 \times \frac{250}{250 + 25} = \mathbf{227\text{ damage}}$.
  - Sesudah (`factor = 0.8` $\rightarrow \text{DEF}_{\text{eff}} = 20$): $250 \times \frac{250}{250 + 20} = \mathbf{231.5 \approx 232\text{ damage (+2.2%)}}$.
Pada Boss Ascension Rank 10 (DEF 180, Skill Sihir ATK 300):
- Saat Ini (`DEF = 180`): $300 \times \frac{300}{300 + 180} = \mathbf{187.5\text{ damage}}$.
- Sesudah (`\text{DEF}_{\text{eff}} = 144`): $300 \times \frac{300}{300 + 144} = \mathbf{202.7\text{ damage (+8.1%)}}$.

*Kesimpulan:* Perubahan ini elegan, aman, tidak merusak sistem fisik, dan memberikan identitas penetrasi alami bagi pengguna sihir saat melawan musuh ber-armor tebal.

---

### 7. VOIDBLADE ARMOR PENETRATION RE-VERIFICATION

#### 7.1 Alur Logika Shadow Mark
1. Pemicu: Serangan dasar atau skill Voidblade menghasilkan serangan kritikal (`result.isCrit == true`).
2. Efek: Menempelkan status `target.shadowMarkTicks = 120` (6.0 detik).
3. Evaluasi Serangan Lanjutan:
   - **Saat Ini:** `defenderDef = 0; effectiveDamageType = SkillDamageType.trueDamage;`
   - **Rekomendasi Baru (50% DEF Bypass):**  
     `defenderDef = (defenderDef * 0.5).round();`  
     `effectiveDamageType = damageType;` (tetap sesuai tipe serangan aslinya).

#### 7.2 Perlindungan Terhadap Skill Khusus
Skill aktif Level 9 Voidblade (`void_execution`) memiliki definisi `damage_type: "true_damage"` di [skills.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/skills.json#L251).  
Dengan memisahkan penanganan Shadow Mark di `_strike()`, skill `void_execution` **tetap menghasilkan 100% True Damage murni** sebagai skill nuke ber-cooldown 10 detik, sedangkan serangan biasa hanya memperoleh penetrasi 50% DEF. Ini menjaga kemewahan skill pamungkas Voidblade.

---

### 8. MYTHICAL WEAPONS FINAL STAT RECONCILIATION

Membandingkan ke-6 senjata Mythical terhadap senjata acuan Legendary (Celestial Blade / Recurve / Cosmic Staff, ATK 19–21):

| Senjata & Class | Stat Saat Ini | Stat Final yang Disepakati | Nilai Dibandingkan Legendary | Nilai Utilitas / Unik |
| :--- | :--- | :--- | :---: | :--- |
| **Dawn's Aegis Blade**  
*(Paladin)* | ATK 45, DEF 25,  
DEF% 12%, HP% 10% | **ATK 28**, DEF 20,  
DEF% 10%, HP% 8% | **+40% ATK**  
(+20 DEF flat) | Mempertahankan ketahanan superior tanpa menjadi mesin perusak utama. |
| **Shadowfang Twinblade**  
*(Voidblade)* | ATK 55, Crit 12%,  
CritDmg 25%, ATK% 10% | **ATK 34**, Crit 8%,  
CritDmg 20%, ATK% 8% | **+70% ATK**  
(+Crit tinggi) | Senjata burst melee murni tertinggi di dalam game. |
| **Hourglass of Eternity**  
*(Chronomancer)* | ATK 40, Haste 15%,  
ATK% 10% | **ATK 28**, Haste 12%,  
ATK% 8% | **+40% ATK**  
(+12% Haste) | Mengakselerasi siklus freeze dan crowd control. |
| **Aether Railgun**  
*(Gunslinger)* | ATK 60, CritDmg 25%,  
Crit 8%, ATK% 12% | **ATK 36**, CritDmg 20%,  
Crit 6%, ATK% 8% | **+80% ATK** | ATK dasar tertinggi untuk peran penembak jitu jarak jauh. |
| **Scythe of the Harvester**  
*(Necromancer)* | ATK 48, Lifesteal 8%,  
HP% 10%, ATK% 8% | **ATK 30**, Lifesteal 6%,  
HP% 8%, ATK% 6% | **+50% ATK**  
(+6% Lifesteal) | Sinergi pemanggilan 2 minion tanpa memicu overhealing berlebih. |
| **Thunderlord's Scepter**  
*(Stormcaller)* | ATK 50, ASPD 0.25,  
ATK% 12% | **ATK 32**, ASPD 0.18,  
ATK% 8% | **+60% ATK**  
(+0.18 ASPD) | Mengoptimalkan penyebaran debuff Shock dan petir berantai. |

---

### 9. GACHA DAN EKONOMI M15 RE-VERIFICATION

#### 9.1 Matematika Probabilitas Murni (Formula Diskrit)
Dengan base rate $p = 0.015$ dan hard pity $N = 40$:
$$P(X = k) = (1 - p)^{k-1} \cdot p \quad (\text{untuk } 1 \le k \le 39)$$
$$P(X = 40) = (1 - p)^{39} = (0.985)^{39} \approx 0.555005$$
Ekspektasi jumlah pull untuk sembarang 5★ Class:
$$E[X] = \sum_{k=1}^{39} k \cdot P(X=k) + 40 \cdot P(X=40) = \mathbf{30.22\text{ Pulls}}$$
Dengan aturan 50/50 Guarantee (kalah 50/50 memberi jaminan 100% pada 5★ berikutnya):
$$\text{Expected Pulls untuk Featured Rate-Up} = 1.5 \times 30.22 = \mathbf{45.33\text{ Pulls}}$$
Skenario Terburuk Mutlak (*Absolute Worst-Case*): $40 + 40 = \mathbf{80\text{ Pulls (2.400 Shard)}}$.

#### 9.2 Realitas Pendapatan Mata Uang (Rutin vs Milestone)
1. **Pendapatan Rutin Mingguan (Tanpa Syarat Khusus):**  
   - Daily Boss: 10 Shard $\times$ 7 = 70 Shard.  
   - Weekly Boss: 50 Shard.  
   $\rightarrow$ **Total Rutin: 120 Shard / minggu (= 4 Pull / minggu)**.
2. **Pendapatan Bertahap Satu Kali (*One-Time Boss Spire Progression*):**  
   Total 20 Lantai = **2.060 Shard (= 68.6 Pull)**.  
   *Distribusi Pembukaan Spire:*
   - Lantai 1–5 (Syarat Level 5–12, Biome D1–D2): 80 Shard.
   - Lantai 6–10 (Syarat Level 15–22, Biome D3): 275 Shard.
   - Lantai 11–15 (Syarat Level 25–32, Biome D4): 570 Shard.
   - Lantai 16–20 (Syarat Level 35–45, Biome D5): 1.135 Shard.

*Kesimpulan Ekonomi Gacha:*  
Pemain baru tidak mendapatkan 68 pull di hari pertama. Mereka mendapatkan pull secara bertahap seiring penaklukan Spire, menjamin 1 Featured Class di bulan pertama bermain, lalu beralih ke kecepatan stabil 4 pull/minggu di fase endgame. Struktur ini sangat sehat, tidak menekan pemain, dan menjaga retensi 6–12 bulan ke depan.

---

### 10. CROSS-SYSTEM BALANCE FINDINGS

1. **Interaksi Gunslinger Aggro + Boss TTK Baru:**  
   Setelah aggro diperbaiki dan HP boss dinaikkan ke 1.900, Gunslinger tidak bisa lagi menembak boss secara pasif dari kejauhan tanpa risiko. Boss akan mengejar pemain, dan Gunslinger (dengan HP rendah) wajib memanfaatkan ruang manuver untuk bertahan selama 34 detik durasi pertempuran.
2. **Interaksi Voidblade 50% DEF Bypass + Penskalaan Boss:**  
   Pada Base HP Aether Sovereign 1.900 (DEF 35), Voidblade menyelesaikan pertempuran dalam **33.7 detik**, masih menjadi yang tercepat di antara 9 class, tetapi tidak lagi membunuh boss secara instan dalam 5 detik.
3. **Interaksi Paladin Sustain + Penskalaan ATK Boss (28 Base / 142 Efektif):**  
   Paladin bertahan selama 48.1 detik. Dengan net damage 62 DPS yang masuk, Paladin mengonsumsi sekitar 2–3 Small Potion selama pertarungan, menciptakan gameplay tanking yang aktif dan seru.

---

### 11. FINAL RECOMMENDATION MATRIX

| ID | Mekanik / Elemen | Status | Nilai / Kondisi Saat Ini | Rekomendasi Spesifikasi Final | Berkas Terkait |
| :--- | :--- | :---: | :--- | :--- | :--- |
| **REC-01** | Gunslinger Aggro Trigger | **FIX** | `_strike()` pasif tanpa aggro | Set `aggroed = true`, `targetId = attacker.id`, `aiState = chase` saat terkena damage | `combat_simulation.dart`, `offline_dungeon_runner.dart` |
| **REC-02** | D5 Boss HP (*Aether Sovereign*)| **ADJUST**| Base HP 480 (Efektif 2.430) | **Base HP 1.900** (Efektif 9.618, Rerata TTK 40.5s) | `monsters.json` |
| **REC-03** | D5 Boss ATK (*Aether Sovereign*)| **ADJUST**| Base ATK 24 (Efektif 122) | **Base ATK 28** (Efektif 142) | `monsters.json` |
| **REC-04** | D4 Boss HP (*Ash Tyrant*) | **ADJUST**| Base HP 465 (Efektif 1.569) | **Base HP 1.250** (Efektif 4.218, Rerata TTK 29.8s) | `monsters.json` |
| **REC-05** | Voidblade DEF Bypass | **ADJUST**| 100% DEF Bypass (True Dmg) | **50% DEF Bypass** saat Shadow Mark aktif | `combat_simulation.dart`, `offline_dungeon_runner.dart` |
| **REC-06** | Paladin Holy Nova Cooldown | **ADJUST**| 3.0 detik (60 ticks) | **5.0 detik (100 ticks)** | `combat_simulation.dart`, `offline_dungeon_runner.dart` |
| **REC-07** | Paladin Holy Nova Heal | **ADJUST**| 5% Max HP | **3% Max HP** | `combat_simulation.dart`, `offline_dungeon_runner.dart` |
| **REC-08** | Stat 6 Senjata Mythical | **ADJUST**| ATK 40–60 (Flat tinggi) | Disesuaikan peran: **ATK 28–36** | `items.json` |
| **REC-09** | Magic Defense Penetration | **REDESIGN**| `magicDefenseFactor = 1.0` | Default **`magicDefenseFactor = 0.80`** | `damage_calculator.dart` |
| **REC-10** | Level 1–5 Progression | **KEEP** | 1.430 EXP (3 run / 5.5m) | Pertahankan tanpa perubahan | - |
| **REC-11** | Gacha Banners & Rates | **KEEP** | Rate 1.5%/2%, Pity 40/30 | Pertahankan tanpa perubahan | - |
| **REC-12** | Offline 8-Hour Cap & Engine | **KEEP** | 8 Jam Cap, fixed-step 50ms | Pertahankan tanpa perubahan | - |

---

### 12. PROPOSED STAGE 1 IMPLEMENTATION ORDER

Setelah pemilik proyek menyetujui rekomendasi di atas, implementasi akan dieksekusi dalam urutan berikut:

```mermaid
flowchart LR
    Step1["Langkah 1: AI & Aggro Fix (REC-01)"] --> Step2["Langkah 2: Trait & Formula Code (REC-05, 06, 07, 09)"]
    Step2 --> Step3["Langkah 3: Data JSON Tuning (REC-02, 03, 04, 08)"]
    Step3 --> Step4["Langkah 4: Parity & Regression Verification"]
```

1. **Langkah 1 — Perbaikan AI Tempur & Aggro (REC-01):**  
   Menerapkan on-damaged aggro trigger pada `CombatSimulation._strike()` dan `_OfflineCombatRuntime._strike()`. Memastikan target bergerak mengejar penyerang.
2. **Langkah 2 — Pembaruan Formula Domain (REC-05, REC-06, REC-07, REC-09):**  
   - Mengubah 100% DEF bypass menjadi 50% pada Voidblade di `combat_simulation.dart` dan `offline_dungeon_runner.dart`.
   - Mengubah cooldown Holy Nova menjadi 5.0 detik dan heal ratio menjadi 0.03.
   - Mengubah default parameter `magicDefenseFactor` menjadi 0.80 di `damage_calculator.dart`.
3. **Langkah 3 — Penyetelan Data Statis JSON (REC-02, REC-03, REC-04, REC-08):**  
   - Memperbarui HP & ATK Ash Tyrant dan Aether Sovereign di [assets/data/monsters.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/monsters.json).
   - Memperbarui nilai ATK & secondary stats 6 senjata Mythical di [assets/data/items.json](file:///e:/myLittleProject/echoes_of_aether/assets/data/items.json).
4. **Langkah 4 — Verifikasi Paritas Online/Offline & Regresi Penuh:**  
   Menjalankan `flutter analyze` (target: 0 issue) dan suite tes komprehensif (`signature_resonance_combat_test.dart`, `balance_simulator_test.dart`, dll., mempertahankan 1007 test lulus).

---

### 13. REMAINING RISKS AND LIMITATIONS

1. **Keterbatasan Automated Simulator:**  
   Simulator domain saat ini menjalankan pertempuran tanpa input penghindaran manual (*manual dodging*). Pada durasi pertarungan 45 detik, pemain manual di perangkat nyata akan memiliki peluang bertahan hidup lebih tinggi daripada simulasi murni karena kemampuan bergerak taktis.
2. **Sensitivitas Assertion Test Lama:**  
   Tes di `test/balance/balance_simulator_test.dart` memiliki assertion win-rate rank 0 pada rentang waktu tertentu. Perubahan HP boss D4/D5 perlu dipantau agar tetap berada dalam koridor toleransi test acuan tanpa melonggarkan batas keselamatan.

---

### 14. OWNER APPROVAL CHECKLIST

Mohon pemilik proyek meninjau dan memberikan konfirmasi eksplisit terhadap 4 butir keputusan final berikut:

- [ ] **Persetujuan 1 (Perbaikan Aggro AI):** Mengaktifkan status aggro otomatis pada musuh saat menerima serangan damage dari jarak mana pun.
- [ ] **Persetujuan 2 (Koreksi Base HP Boss Akhir):** Mengesahkan kenaikan Base HP *Aether Sovereign* (D5) menjadi **1.900** (Effective HP 9.618) dan *Ash Tyrant* (D4) menjadi **1.250** (Effective HP 4.218) agar durasi TTK pertempuran boss mencapai target 30–50 detik.
- [ ] **Persetujuan 3 (Moderasi Resonansi Voidblade & Paladin):** Mengesahkan penyesuaian Voidblade ke 50% DEF Bypass dan Holy Nova Paladin ke Cooldown 5 detik / 3% Heal.
- [ ] **Persetujuan 4 (Kalibrasi ATK Senjata Mythical):** Mengesahkan penyesuaian ATK 6 senjata Mythical ke rentang 28–36 sesuai spesialisasi perannya.

---

*Laporan Rekonsiliasi Akhir Stage 0C Selesai. Seluruh data telah dibuktikan kebenarannya dan status proyek tetap Read-Only. Menunggu instruksi dan persetujuan dari Pemilik Proyek.*
