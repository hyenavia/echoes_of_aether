# UI Tokens & Shared Components (M11 Stage 1)

Dokumentasi singkat token desain dan komponen bersama untuk UI Idle RPG **Echoes of Aether**.

## 1. Token Tema (`lib/app/theme/`)

- [`app_tokens.dart`](../lib/app/theme/app_tokens.dart):
  - `AppColors`: palet GDD §14.2 (`forestGreen`, `deepForest`, `mossGreen`, `earthBrown`, `ancientStone`, `aetherBlue`, `arcanePurple`, `warmGold`, `healthRed`), permukaan gelap RPG, dan warna rarity (`Common`..`Legendary`).
  - `AppSpacing`: `xs (4)`, `sm (8)`, `md (12)`, `lg (16)`, `xl (24)`.
  - `AppRadius`: `sm (4)`, `md (6)`, `lg (10)`.
  - `AppElevation`: `none (0)`, `panel (2)`, `overlay (6)`.
- [`echoes_theme.dart`](../lib/app/theme/echoes_theme.dart):
  - `EchoesThemeExtension`: `ThemeExtension` untuk warna semantik (`gold`, `rank`, `hpBar`, `expBar`, `locked`, `colorForRarity(ItemRarity)`).
  - `EchoesTheme.dark()`: `ThemeData` Material 3 gelap yang dipakai di `EchoesApp`.

## 2. Komponen Bersama (`lib/features/shared/widgets/`)

Impor seluruh komponen lewat `package:echoes_of_aether/features/shared/widgets/shared_widgets.dart`.

| Komponen | File | Fungsi Utama |
| -------- | ---- | ------------ |
| `PanelFrame` | `panel_frame.dart` | Bingkai panel RPG gelap dengan border ganda & elevasi. |
| `SectionHeader` | `section_header.dart` | Judul seksi dengan aksen bar emas & trailing opsional. |
| `PrimaryButton` | `primary_button.dart` | Tombol aksi utama (`minHeight: 44dp`, ikon opsional, proteksi overflow). |
| `SecondaryButton` | `secondary_button.dart` | Tombol aksi sekunder (`minHeight: 44dp`, ikon opsional, proteksi overflow). |
| `ResourceChip` | `resource_chip.dart` | Chip ringkas untuk `ResourceChip.gold(amount)`, `ResourceChip.rank(rank)`, dll. |
| `StatBar` | `stat_bar.dart` | Bar progres `StatBar.hp(...)` & `StatBar.exp(...)` dengan `NumberFormatter`. |
| `ItemCard` | `item_card.dart` | Kartu item berwarna rarity, ikon slot/kategori, stat ringkas, & state terkunci. |
| `RarityLabel` | `rarity_label.dart` | Badge teks & warna rarity (`Common`..`Legendary`). |
| `LockedBadge` | `locked_badge.dart` | Badge ikon gembok + alasan terkunci. |
