import 'package:flutter/material.dart';

/// Palet & Konfigurasi Tema Dark Fantasy — Echoes of Aether.
///
/// Menggantikan palet hijau flat sebelumnya dengan nuansa Dark Fantasy:
/// - Background: Deep Navy / Slate
/// - Aksen Utama: Magical Gold (#FFD700), Arcane Purple (#9D4EDD), Cyan Glow (#00F5D4)
/// - Visual Feedback: Drop shadows tebal, glossy highlights, dan glow effects khas RPG premium.
abstract final class AppTheme {
  // ===========================================================================
  // 1. BACKGROUND & SURFACES (Deep Navy / Slate)
  // ===========================================================================
  /// Latar belakang terdalam (Deep Navy / Void).
  static const Color background = Color(0xFF090D16);

  /// Latar belakang layer kedua (Slate Navy).
  static const Color backgroundSecondary = Color(0xFF0F1523);

  /// Permukaan kartu/panel dasar (Deep Slate).
  static const Color surface = Color(0xFF141C2B);

  /// Permukaan kartu/panel terangkat (Elevated Slate).
  static const Color surfaceElevated = Color(0xFF1C263B);

  /// Border panel default (Slate Subdued).
  static const Color panelBorder = Color(0xFF28364F);

  /// Border panel dengan highlight kontras.
  static const Color panelBorderHighlight = Color(0xFF3F557C);

  /// Border panel emas ornamen.
  static const Color panelBorderGold = Color(0xFFD4AF37);

  // ===========================================================================
  // 2. AKSEN UTAMA (Gold, Arcane Purple, Cyan Glow)
  // ===========================================================================
  /// Magical Gold (#FFD700) — Aksen utama kemenangan, koin, dan tombol utama.
  static const Color gold = Color(0xFFFFD700);
  static const Color goldLight = Color(0xFFFFEE88);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color goldDeep = Color(0xFF8A6218);

  /// Arcane Purple (#9D4EDD) — Aksen sihir, rank, dan spesialisasi arcanist.
  static const Color arcanePurple = Color(0xFF9D4EDD);
  static const Color arcaneLight = Color(0xFFC77DFF);
  static const Color arcaneDark = Color(0xFF5A189A);
  static const Color arcaneDeep = Color(0xFF3C096C);

  /// Cyan Glow (#00F5D4) — Efek menyala (glow), EXP, dan intisari aether.
  static const Color cyanGlow = Color(0xFF00F5D4);
  static const Color cyanLight = Color(0xFF70FFF0);
  static const Color cyanDark = Color(0xFF00B4D8);
  static const Color cyanDeep = Color(0xFF0077B6);

  // ===========================================================================
  // 3. SEMANTIK STATUS & COMBAT
  // ===========================================================================
  /// Health Point (HP) & Danger.
  static const Color hpRed = Color(0xFFE63946);
  static const Color hpRedLight = Color(0xFFFF6B6B);
  static const Color hpRedDark = Color(0xFF800F2F);

  /// Mana & Magic Resource.
  static const Color manaBlue = Color(0xFF3B82F6);
  static const Color manaBlueLight = Color(0xFF60A5FA);

  /// Experience (EXP) Bar.
  static const Color expCyan = cyanGlow;

  /// Status Feedback.
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color locked = Color(0xFF64748B);

  // ===========================================================================
  // 4. WARNA TINGKAT KELANGKAAN (Item Rarity)
  // ===========================================================================
  /// Common: Abu-abu Slate
  static const Color rarityCommon = Color(0xFF94A3B8);

  /// Uncommon: Hijau Giok
  static const Color rarityUncommon = Color(0xFF10B981);

  /// Rare: Biru Arcane
  static const Color rarityRare = Color(0xFF3B82F6);

  /// Epic: Ungu Arcane
  static const Color rarityEpic = Color(0xFF9D4EDD);

  /// Legendary: Emas Menyala
  static const Color rarityLegendary = Color(0xFFFFD700);

  /// Mythical: Crimson Glow
  static const Color rarityMythical = Color(0xFFFF2A6D);

  // ===========================================================================
  // 5. TEKS & KONTRAS
  // ===========================================================================
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF8896AB);
  static const Color textDark = Color(0xFF090D16);

  // ===========================================================================
  // 6. GRADIEN MEWAH RPG
  // ===========================================================================
  /// Gradien Emas Berkilau (Tombol Utama, Header Juara, VIP).
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFEA79), Color(0xFFFFD700), Color(0xFFB8860B)],
  );

  /// Gradien Ungu Arcane (Tombol Sihir, Rank Up, Boss).
  static const LinearGradient arcaneGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFC77DFF), Color(0xFF9D4EDD), Color(0xFF5A189A)],
  );

  /// Gradien Cyan Menyala (EXP, Tombol Info, Aether Tech).
  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF70FFF0), Color(0xFF00F5D4), Color(0xFF0096C7)],
  );

  /// Gradien HP Merah Darah (Health Bar & Tombol Danger).
  static const LinearGradient hpGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF6B6B), Color(0xFFE63946), Color(0xFF800F2F)],
  );

  /// Gradien Slate Gelap (Tombol Sekunder, Background Slot).
  static const LinearGradient slateGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF28364F), Color(0xFF1B2436), Color(0xFF101624)],
  );

  /// Gradien Panel Dalam (Backing Layer).
  static const LinearGradient darkPanelGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A2338), Color(0xFF111726), Color(0xFF0C101A)],
  );

  // ===========================================================================
  // 7. SHADOWS & GLOW EFFECTS
  // ===========================================================================
  static List<BoxShadow> get goldGlowShadow => [
    BoxShadow(
      color: gold.withValues(alpha: 0.45),
      blurRadius: 14,
      spreadRadius: 1,
    ),
  ];

  static List<BoxShadow> get arcaneGlowShadow => [
    BoxShadow(
      color: arcanePurple.withValues(alpha: 0.5),
      blurRadius: 14,
      spreadRadius: 1,
    ),
  ];

  static List<BoxShadow> get cyanGlowShadow => [
    BoxShadow(
      color: cyanGlow.withValues(alpha: 0.5),
      blurRadius: 14,
      spreadRadius: 1,
    ),
  ];

  static List<BoxShadow> get panelDropShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.75),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get buttonDropShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.65),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  // ===========================================================================
  // 8. TIPOGRAFI FANTASI & STATS
  // ===========================================================================
  static const String fantasyFontFamily = 'Cinzel';
  static const List<String> fantasyFontFallback = [
    'MedievalSharp',
    'Trajan',
    'Georgia',
    'serif',
  ];

  static const String statsFontFamily = 'Montserrat';
  static const List<String> statsFontFallback = [
    'Roboto',
    'Segoe UI',
    'sans-serif',
  ];

  /// Tipografi khusus judul/header bernuansa fantasi dengan bayangan tebal.
  static TextStyle headingFantasy({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color color = gold,
    double letterSpacing = 1.0,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: fantasyFontFamily,
      fontFamilyFallback: fantasyFontFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      shadows:
          shadows ??
          [
            Shadow(
              color: Colors.black.withValues(alpha: 0.9),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
            Shadow(
              color: color.withValues(alpha: 0.35),
              offset: const Offset(0, 0),
              blurRadius: 8,
            ),
          ],
    );
  }

  /// Tipografi angka statistik yang rapi dan mudah dibaca (tabular figures).
  static TextStyle statNumber({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textPrimary,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: statsFontFamily,
      fontFamilyFallback: statsFontFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows:
          shadows ??
          [
            Shadow(
              color: Colors.black.withValues(alpha: 0.85),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
    );
  }

  /// Tipografi body text fantasi bersih.
  static TextStyle body({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.normal,
    Color color = textSecondary,
  }) {
    return TextStyle(
      fontFamily: statsFontFamily,
      fontFamilyFallback: statsFontFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );
  }

  // ===========================================================================
  // 9. THEMEDATA BUILDER
  // ===========================================================================
  /// Membuat `ThemeData` Dark Fantasy lengkap untuk aplikasi.
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: gold,
        secondary: arcanePurple,
        tertiary: cyanGlow,
        error: danger,
        onSurface: textPrimary,
        onPrimary: textDark,
        onSecondary: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: panelBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: panelBorderHighlight, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundSecondary,
        selectedItemColor: gold,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(
        color: panelBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
