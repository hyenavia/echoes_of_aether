# UI Tokens, Asset Architecture & Shared Components — Living Aether Camp

Dokumentasi token desain, strategi aset visual, dan komponen bersama untuk redesign UI **Echoes of Aether** (**Living Aether Camp — Balanced Fantasy RPG**).

## 1. Token Tema (`lib/app/theme/`)

- [`app_tokens.dart`](../lib/app/theme/app_tokens.dart):
  - `AppColors`:
    - Palet Living Aether Camp: `midnightForest (#10251F)`, `deepTeal (#203B30)`, `antiqueGold (#E9C66D)`, `aetherBlue (#69BFE5)`, `arcaneViolet (#A88AD5)`, `emberRed (#D96868)`.
    - Warna lingkungan & permukaan gelap RPG (`forestGreen`, `deepForest`, `mossGreen`, `earthBrown`, `ancientStone`, `campAmber`, `surfaceDark`, `panelElevated`, `panelBorder`, `panelInnerBorder`).
    - Sumber tunggal pemetaan rarity `AppColors.colorForRarity(ItemRarity)` (`Common`..`Legendary`).
  - `AppTypography`:
    - Fantasy-inspired serif fallback (`displayFontFamily = 'serif'`) untuk `display(...)` dan `headingSerif(...)`.
    - Clean sans-serif untuk body text dan angka tabular (`numeric(...)` dengan `FontFeature.tabularFigures()`).
  - `AppSpacing`: `xs (4)`, `sm (8)`, `md (12)`, `lg (16)`, `xl (24)`, `xxl (32)`.
  - `AppRadius`: `sm (4)`, `md (8)`, `lg (12)`, `xl (16)`.
  - `AppBorders`: `thin (1.0)`, `standard (1.5)`, `accent (2.0)`, `panel(...)`, `inner(...)`.
  - `AppElevation`: `none (0)`, `panel (2)`, `card (4)`, `overlay (8)`.
  - `AppShadows` & `AppDurations`: bayangan panel, subtle glow, dan durasi animasi (`fast`, `normal`, `slow`, `ambient`).
- [`echoes_theme.dart`](../lib/app/theme/echoes_theme.dart):
  - `EchoesThemeExtension`: token semantik tema (`gold`, `rank`, `hpBar`, `expBar`, `locked`, `success`, `warning`, `colorForRarity(ItemRarity)`).
  - `EchoesTheme.dark()`: `ThemeData` Material 3 gelap lengkap dengan tema `Card`, `Dialog`, `BottomSheet`, `Tooltip`, `SnackBar`, `ProgressIndicator`, `NavigationBar`, `SegmentedButton`, dan `Chip`.

## 2. Arsitektur Aset & Artwork Placeholder (`lib/features/shared/assets/` & `artwork/`)

- [`game_assets.dart`](../lib/features/shared/assets/game_assets.dart):
  - `GameAssetDirectories`: konvensi direktori (`assets/images/characters/`, `backgrounds/`, `biomes/`, `items/`, `ui/`, `assets/fonts/`).
  - `GameAssetPaths` & `GameAssetRegistry`: seam transisi dari vector `CustomPainter` placeholder ke `Image.asset` PNG final tanpa mengubah kode layar.
  - `CharacterVisualSpec` & `BiomeVisualSpec`: spesifikasi visual per class (`base`, `vanguard`, `arcanist`, `ranger`) dan per biome (`forgotten_forest`, `crystal_cavern`, `ancient_crypt`, `ashen_wasteland`, `aether_sanctum`, `ascension_sanctum`).
- [`character_illustration.dart`](../lib/features/shared/widgets/artwork/character_illustration.dart):
  - `CharacterIllustration`: ilustrasi menu fantasy ber-layer untuk `base`, `vanguard`, `arcanist`, dan `ranger` (tidak memperbesar sprite pixel art gameplay).
- [`biome_artwork.dart`](../lib/features/shared/widgets/artwork/biome_artwork.dart):
  - `CampBackdrop`: latar Living Aether Camp (hutan malam, tenda petualang, api unggun, kristal Aether).
  - `BiomeArtwork`: ilustrasi visual ber-layer per biome dungeon.

## 3. Komponen Bersama (`lib/features/shared/widgets/`)

Impor seluruh komponen lewat `package:echoes_of_aether/features/shared/widgets/shared_widgets.dart`.

| Komponen | File | Fungsi Utama |
| -------- | ---- | ------------ |
| `PanelFrame` | `panel_frame.dart` | Bingkai panel RPG gelap dengan border ganda, sudut ornamen opsional, radius, & elevasi. |
| `SectionHeader` | `section_header.dart` | Judul seksi dengan aksen bar emas, opsi serif, & trailing opsional. |
| `PrimaryButton` | `primary_button.dart` | Tombol aksi utama (`minHeight: 44dp`, ikon opsional, proteksi overflow). |
| `SecondaryButton` | `secondary_button.dart` | Tombol aksi sekunder (`minHeight: 44dp`, ikon opsional, proteksi overflow). |
| `AppIconButton` | `app_icon_button.dart` | Tombol ikon terstandar (`minSize: 44dp`, semantics, tooltip, status aktif). |
| `InformationCard` | `information_card.dart` | Kartu ringkasan info/metrik dengan ikon, nilai angka tabular, & subtitle. |
| `DungeonCard` | `dungeon_card.dart` | Kartu biome/dungeon dengan `BiomeArtwork`, progress bar room, status, & tombol aksi. |
| `HeroShowcaseCard` | `hero_showcase_card.dart` | Showcase hero Camp/Menu beserta class, level, rank, dan combat power. |
| `ResourceChip` | `resource_chip.dart` | Chip ringkas untuk `ResourceChip.gold(amount)`, `ResourceChip.rank(rank)`, dll. |
| `StatBar` & `ProgressBar` | `stat_bar.dart` | Bar progres `StatBar.hp(...)`, `StatBar.exp(...)`, `StatBar.progress(...)`, & `ProgressBar`. |
| `RarityBorder` | `rarity_border.dart` | Helper dekorasi border & glow berbasis rarity item. |
| `ItemCard` | `item_card.dart` | Kartu item berwarna rarity, ikon slot/kategori, stat ringkas, & state terkunci. |
| `ItemSlot` & `EquipmentSlotTile` | `item_slot.dart` | Slot grid item ringkas serta tile slot perlengkapan (`weapon`, `head`, `body`, `accessory`). |
| `RarityLabel` | `rarity_label.dart` | Badge teks & warna rarity (`Common`..`Legendary`). |
| `LockedBadge` | `locked_badge.dart` | Badge ikon gembok + alasan terkunci. |
| `EchoesBottomNavigation` | `echoes_bottom_navigation.dart` | Navigasi bawah 5 tab bergaya RPG dengan target sentuh >= 44dp & anti-overflow. |
| `EchoesDialog` | `echoes_dialog.dart` | Dialog modal bertema Living Aether Camp (`EchoesDialog`, `showEchoesDialog`). |
| `EchoesBottomSheet` | `echoes_bottom_sheet.dart` | Bottom sheet modal terstandar (`EchoesBottomSheet`, `showEchoesBottomSheet`). |
| `AppNotificationBanner` | `app_notification.dart` | Banner notifikasi & snackbar terpadu (`info`, `success`, `warning`, `danger`). |
| `AppTooltip` | `app_tooltip.dart` | Tooltip terpusat dengan styling tema Living Aether Camp. |
| `EmptyState` | `empty_state.dart` | Kontainer state kosong terpusat untuk inventori/filter/skill kosong. |
| `LoadingState` | `loading_state.dart` | Indikator loading bertema Aether (`compact` atau berbingkai panel). |
| `BiomeStyle` | `biome_style.dart` | Pemetaan label, ikon, dan aksen warna biome dungeon. |

## 4. Implementasi Screen Redesign (Stages 2–4) & Polish (Stage 5)

- **Stage 2 — Town/Camp Home & Adventure Selection**:
  - `TownTopBar` ([`town_top_bar.dart`](../lib/features/dungeon/town_top_bar.dart)): status hero ringkas (`Lv`, `Class`, `Gold`, `Rank`, bar `HP` & `EXP`).
  - `TownHubView` ([`town_hub_view.dart`](../lib/features/dungeon/town_hub_view.dart)): tab `Adventure` menampilkan `HeroShowcaseCard` dengan `CampBackdrop` + `CharacterIllustration` sesuai class aktif sebagai focal point, strip quick access (`Hero`, `Bag`, `Shop`, `Settings`), serta `DungeonCard` berilustrasi biome dengan progres room, status kunci, `Ascension`, dan kontrol `Offline Activity`.
- **Stage 3 — Dungeon Combat Screen & Run Result Overlays**:
  - `HudOverlay` ([`hud_overlay.dart`](../lib/features/dungeon/hud_overlay.dart)): Hero Combat Plate, Boss Encounter Plate (HP bar + nama boss), Combat Feed chip, serta toggle Auto/Menu.
  - `DungeonCompletedOverlay` ([`dungeon_completed_overlay.dart`](../lib/features/dungeon/dungeon_completed_overlay.dart)) & `RunEndedOverlay` ([`run_ended_overlay.dart`](../lib/features/dungeon/run_ended_overlay.dart)): modal serif berbingkai ornamen untuk hasil run (`Reward`, `Ascension`, `Auto-Revive`).
  - Gameplay pixel-art sprite di Flame (`lib/game/**`) tidak diubah atau diganti ilustrasi menu.
- **Stage 4 — Secondary Overlays**:
  - `CharacterOverlay` ([`character_overlay.dart`](../lib/features/dungeon/character_overlay.dart)): profil banner berilustrasi sesuai specialization aktif (`base`, `vanguard`, `arcanist`, `ranger`) + `Combat Power`, ringkasan stat tabular, spesialisasi, dan skill upgrade.
  - `EquipmentOverlay` ([`equipment_overlay.dart`](../lib/features/dungeon/equipment_overlay.dart)), `InventoryOverlay` ([`inventory_overlay.dart`](../lib/features/dungeon/inventory_overlay.dart)), `ShopOverlay` ([`shop_overlay.dart`](../lib/features/dungeon/shop_overlay.dart)), `SettingsOverlay` ([`settings_overlay.dart`](../lib/features/dungeon/settings_overlay.dart)), & `OfflineSummaryOverlay` ([`offline_summary_overlay.dart`](../lib/features/dungeon/offline_summary_overlay.dart)).
- **Stage 5 — Final Polish & Startup States**:
  - State muat & error inisialisasi pada [`dungeon_screen.dart`](../lib/features/dungeon/dungeon_screen.dart) diseragamkan memakai `LoadingState` & `PanelFrame` beraksen `AppColors.emberRed`, serta kontras peringatan `Epic+` pada dialog jual massal [`shop_overlay.dart`](../lib/features/dungeon/shop_overlay.dart) disesuaikan ke palet gelap.

## 5. Spesifikasi Produksi Artwork Final (Checklist Pengganti Placeholder)

Project saat ini **masih menggunakan placeholder vector `CustomPainter`** (`GameAssetRegistry.bundledRasterAssets` kosong; folder gambar kosong belum didaftarkan di `pubspec.yaml`). Spesifikasi berikut menjadi acuan saat artwork PNG final diproduksi:

### A. Character Illustrations (`assets/images/characters/`) — Transparansi Alpha (`RGBA PNG`), min `512x640`

| Target Asset Path | Class | Sudut Pandang & Pose | Senjata & Komposisi | Warna Dominan & Aura |
| ----------------- | ----- | -------------------- | ------------------- | -------------------- |
| `hero_base.png` | Aether Wanderer (`base`) | 3/4 depan, postur siap jalan, jubah berkerudung | Pedang petualang & lentera kecil di sisi | `#355B45` (Forest), `#E9C66D` (Gold), aura `#69BFE5` |
| `hero_vanguard.png` | Vanguard (`vanguard`) | 3/4 heroik bertahan, dada tegap, pelindung bahu baja | Kite shield kokoh di depan & broadsword berukir Aether | `#E9C66D` (Gold), `#D96868` (Ember Red), aura `#F0A25E` |
| `hero_arcanist.png` | Arcanist (`arcanist`) | 3/4 pose merapal mantra, jubah arcane melayang | Runestaff kristal Aether & grimoire melayang | `#69BFE5` (Aether Blue), `#A88AD5` (Violet), aura `#69BFE5` |
| `hero_ranger.png` | Ranger (`ranger`) | 3/4 siap membidik rendah & lincah, syal hutan | Enchanted recurve bow bertali cahaya & quiver | `#71865A` (Moss), `#E9C66D` (Gold), aura hijau rimba |

### B. Camp & Biome Backgrounds (`assets/images/backgrounds/` & `biomes/`) — Opak (`PNG` 16:9 / banner)

| Target Asset Path | Konteks | Komposisi | Palet Utama |
| ----------------- | ------- | --------- | ----------- |
| `camp_living_aether.png` | Hero Showcase Town/Camp | Hutan malam berlapis, tenda petualang, api unggun hangat kanan-bawah, kristal Aether redup sebagai aksen latar (tidak menyaingi karakter) | `#10251F`, `#203B30`, `#F0A25E`, `#69BFE5` |
| `biome_forgotten_forest.png` | Forgotten Forest | Siluet pepohonan purba berkabut dengan sinar Aether tipis | `#0C1C17` -> `#1A382D`, aksen `#71865A` & `#69BFE5` |
| `biome_crystal_cavern.png` | Crystal Cavern | Gua gelap bertabur pilar kristal bercahaya biru | `#0B1826` -> `#153147`, aksen `#69BFE5` & `#9DE2FF` |
| `biome_ancient_crypt.png` | Ancient Crypt | Pilar reruntuhan & altar kuno bermandikan kabut ungu | `#161322` -> `#27213B`, aksen `#A88AD5` & `#CBB2F0` |
| `biome_ashen_wasteland.png` | Ashen Wasteland | Dataran abu vulkanik & bara api retakan tanah | `#1E1111` -> `#38201E`, aksen `#D96868` & `#F0A25E` |
| `biome_aether_sanctum.png` | Aether Sanctum | Kuil kuno melayang dengan rune emas & aliran Aether | `#151926` -> `#263345`, aksen `#E9C66D` & `#69BFE5` |
| `biome_ascension_sanctum.png` | Ascension Cycle | Ruang sanctum kosmik bergetar rune emas-violet | `#1A1426` -> `#2B2848`, aksen `#E9C66D` & `#A88AD5` |
