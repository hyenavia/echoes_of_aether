# ECHOES OF AETHER

## MASTER DEVELOPMENT ROADMAP — M15 (GACHA ECOSYSTEM & SPECIALIZATION AWAKENING)

**Document Version:** 1.0  
**Melanjutkan:** M1–M14 Selesai (Baseline Drift Schema v9, 947 Tests Passing, 0 Analyzer Issue)  
**Dokumen Pendamping:** DESIGN_ADDENDUM_v1.4_GACHA_SYSTEM  
**Status:** DRAFT RANCANGAN ROADMAP  

---

# 1. ATURAN PENGEMBANGAN (AGENTS.MD ALIGNMENT)

1. **Disiplin Stage:** Satu stage per sesi. Agent berhenti dan melapor di akhir tiap stage untuk verifikasi pemilik project.
2. **Offline-First & Deterministic:** Gacha generator menggunakan deterministic PRNG yang dapat diuji dengan seed pada unit test. Semua data tersimpan aman secara lokal di Drift SQLite.
3. **Paritas Online & Offline:** Efek stat Class Mythical dan Signature Resonance Trait wajib bekerja identik baik di `CombatSystem` (real-time Flame) maupun di `OfflineDungeonRunner` (idle simulation).
4. **Keamanan Transaksi & Idempoten:** Penarikan gacha, pengurangan Aether Shard, penerimaan item/class, serta konversi Soul Prism wajib berada dalam satu transaksi database atomik.
5. **Schema Migration Bertahap:** Migrasi Drift `from9To10` wajib memiliki unit test migrasi dari data nyata tanpa menghapus progres pemain yang sudah ada.
6. **UI Fungsional Minimal:** UI Gacha dan Sanctuary dibuat bersih, modular, dan fungsional di berkas terpisah tanpa merusak tampilan yang sudah dirancang pemilik project.

---

# 2. RANCANGAN TAHAPAN MILESTONE 15

```
+--------------------------------------------------------------------------+
| MILESTONE 15: SPECIALIZATION AWAKENING, MYTHICAL ARMORY & GACHA          |
+--------------------------------------------------------------------------+
                                     |
                                     v
  [Stage 1] Data & Config Layer: Drift v10, Entities & Config JSON
                                     |
                                     v
  [Stage 2] Domain Services: GachaService, Independent Pity & Shop Refactor
                                     |
                                     v
  [Stage 3] Presentation Layer: Gacha Altar, 2 Tabs & Sanctuary Shop UI
                                     |
                                     v
  [Stage 4] Combat & Visuals: Signature Resonance Trait (Online/Offline)
                                     |
                                     v
  [Stage 5] End-to-End Testing, Cloud Limits & Full Regression Suite
```

---

### Stage 1 — Domain Entities, Konfigurasi JSON & Database Schema v10

**Tujuan:** Menyiapkan fondasi data statis dan persistensi lokal untuk banner, class mythical, senjata mythical, dan riwayat pity.

* **Pekerjaan:**
  1. Konfigurasi JSON:
     - `assets/data/gacha_banners.json` (jadwal rotasi 21 hari, pool class & weapon, base rate 1.5%, pity limit 40/30).
     - `assets/data/mythical_classes.json` (definisi 6 Class Mythical beserta stat bonus, jangkauan serang, dan affinity skill).
     - Penambahan `ItemRarity.mythical` dan item senjata signature di `assets/data/items.json`.
  2. Domain Entities:
     - `GachaBannerDefinition`, `GachaPullResult`, `GachaPityState`, `SoulPrismExchange`.
  3. Database Schema Migration (Drift v9 → v10):
     - Tabel `GachaPityStates` (banner_type, pull_count, guarantee_active).
     - Tabel `UnlockedSpecializations` (specialization_id, unlocked_at).
     - Tabel `Currencies` pendukung: penambahan `soul_prism`.
     - Test migrasi komprehensif dari v9 ke v10 dengan data terisi.
* **Kriteria Sukses:**
  - Migrasi skema database Drift v9 → v10 lulus tanpa error.
  - JSON parser dan validator memverifikasi integritas seluruh data gacha.

---

### Stage 2 — Gacha Engine, Independent Pity & Weekly Shop Refactor

**Tujuan:** Membangun core domain logic penarikan gacha, jaminan pity terpisah, konversi duplikat, dan pelepasan Aether Shard dari Weekly Shop.

* **Pekerjaan:**
  1. `GachaService`:
     - Algoritma pull deterministik (mendukung injeksi `Random`).
     - Logika Pity Terpisah: Class (40 pull) dan Senjata (30 pull) melacak counter masing-masing tanpa saling mereset.
     - Mekanisme 50/50: Jaminan featured item jika sebelumnya kalah 50/50.
     - Deteksi duplikat: jika class sudah ada di `UnlockedSpecializations`, grant 1 `soul_prism` dan catat riwayatnya.
  2. `SanctuaryService`:
     - Penukaran atomik: 2 `soul_prism` untuk Senjata Mythical, 3 `soul_prism` untuk Class Mythical.
  3. Refactor `EventShopService` (Weekly Shop):
     - Hapus konsumsi Aether Shard.
     - Alihkan harga menjadi Gold + Boss Material / Salvage Dust.
* **Kriteria Sukses:**
  - Unit test memverifikasi determinisme rate, hard pity, jaminan 50/50, dan konversi duplikat.
  - Paritas transaksi atomik terverifikasi: kegagalan penarikan tidak mengurangi Aether Shard.

---

### Stage 3 — Presentation Layer: Gacha Altar, 2 Tabs & Sanctuary UI

**Tujuan:** Menyediakan antarmuka minimal yang responsif dan nyaman bagi pemain untuk melakukan penarikan gacha dan menukarkan Soul Prism.

* **Pekerjaan:**
  1. Quick Access / Tombol Akses di Town Hub ("Altar Pemanggilan" / "Sanctuary").
  2. `GachaOverlay`:
     - Tampilan 2 Tab: **"Class Awakening"** & **"Mythical Armory"**.
     - Indikator Counter Pity real-time (contoh: *Pity: 24/40*, *Pity: 12/30*).
     - Hitung mundur sisa durasi rotasi banner (Siklus 21 Hari).
     - Tombol **Tarik 1x (30 Shard)** dan **Tarik 10x (300 Shard)**.
  3. Dialog Hasil Penarikan:
     - Kartu animasi reveal kartu pixel art.
     - Notifikasi khusus jika terjadi konversi duplikat menjadi Soul Prism.
  4. Tab / Tombol `Sanctuary Shop`:
     - Grid penukaran Soul Prism untuk mengklaim Class atau Senjata langsung.
* **Kriteria Sukses:**
  - Widget test lulus tanpa rendering overflow pada resolusi layar mobile portrait sempit (320dp).

---

### Stage 4 — Runtime Combat & Signature Resonance Trait Integration

**Tujuan:** Mengintegrasikan Class Mythical dan efek sinergi Senjata Signature ke dalam loop pertempuran nyata dan simulasi offline.

* **Pekerjaan:**
  1. Integrasi Specialization Runtime:
     - Memungkinkan pemain memilih Class Mythical yang telah terbuka di menu Karakter.
     - Mapping sprite visual hero sesuai Class Mythical aktif.
  2. Implementasi Signature Resonance Trait:
     - Deteksi kecocokan `activeSpecializationId == weapon.signatureClassId`.
     - Logika efek khusus di `CombatSystem` (Holy Nova Paladin, Shadow Mark Voidblade, Freeze Chronomancer, dll.).
  3. Paritas Offline Simulation:
     - Pastikan `OfflineDungeonRunner` menghitung buff Resonance Trait secara adil pada DPS dan ketahanan karakter.
* **Kriteria Sukses:**
  - Test paritas online vs offline lulus dengan deviasi <= 1%.
  - Recalculation stat karakter deterministik dan bebas duplikasi modifier.

---

### Stage 5 — Balance Simulation, Cloud Limits & Verifikasi Regresi Penuh

**Tujuan:** Memvalidasi keseimbangan ekonomi, sinkronisasi cloud, dan memastikan tidak ada regresi pada seluruh sistem sebelumnya.

* **Pekerjaan:**
  1. Update `tool/export_cloud_limits.dart` & `firestore.rules`:
     - Validasi batas kepemilikan Soul Prism dan konsistensi transaksi Aether Shard di cloud.
  2. Simulasi Ekonomi di `BalanceSimulator`:
     - Verifikasi rasio tabungan Aether Shard (Daily + Weekly + Menara Spiral) terhadap perputaran banner 21 hari.
  3. Full Regression Test:
     - Menjalankan seluruh test suite (baseline 947 tests + test baru M15).
     - Menjalankan `flutter analyze` dengan target 0 issue.
* **Kriteria Sukses:**
  - 100% test lulus, `flutter analyze` 0 issue.
  - Laporan lengkap siap diserahkan ke pemilik project.
