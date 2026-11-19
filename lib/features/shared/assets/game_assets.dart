import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';

/// Konvensi struktur direktori aset Echoes of Aether.
///
/// Catatan penting:
/// Project saat ini menggunakan vektor `CustomPainter` sebagai placeholder
/// terstruktur hingga artwork PNG final ditambahkan ke `pubspec.yaml`.
/// Jangan mendaftarkan folder kosong ke `pubspec.yaml`.
abstract final class GameAssetDirectories {
  static const String characters = 'assets/images/characters/';
  static const String backgrounds = 'assets/images/backgrounds/';
  static const String biomes = 'assets/images/biomes/';
  static const String items = 'assets/images/items/';
  static const String ui = 'assets/images/ui/';
  static const String fonts = 'assets/fonts/';
}

/// Lokasi jalur aset target ketika artwork PNG / SVG final tersedia.
abstract final class GameAssetPaths {
  static const String campBackground =
      '${GameAssetDirectories.backgrounds}camp_living_aether.png';

  static String characterPortrait(String specializationId) =>
      '${GameAssetDirectories.characters}hero_${_normalizeId(specializationId)}.png';

  static String biomeArtwork(String biomeId) =>
      '${GameAssetDirectories.biomes}biome_${_normalizeId(biomeId)}.png';

  static String itemIcon(String itemId) =>
      '${GameAssetDirectories.items}item_${_normalizeId(itemId)}.png';

  static String uiOrnament(String ornamentId) =>
      '${GameAssetDirectories.ui}ui_${_normalizeId(ornamentId)}.png';

  static String _normalizeId(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]+'),
      '_',
    );
    return normalized.isEmpty ? 'base' : normalized;
  }
}

/// Lokasi berkas aset branding resmi Echoes of Aether.
abstract final class BrandingAssetPaths {
  static const String appIconFull =
      'assets/branding/app_icon/app_icon_full.png';
  static const String logoPrimary =
      'assets/branding/logo/logo_primary_horizontal.png';
  static const String logoCompact = 'assets/branding/logo/logo_compact.png';
  static const String logoWinged = 'assets/branding/logo/logo_winged.png';
  static const String symbolMark = 'assets/branding/symbol/symbol_mark.png';
  static const String symbolBadge = 'assets/branding/symbol/symbol_badge.png';
  static const String logoMonoWhite =
      'assets/branding/monochrome/logo_mono_white.png';
  static const String logoMonoDark =
      'assets/branding/monochrome/logo_mono_dark.png';
  static const String symbolMonoWhite =
      'assets/branding/monochrome/symbol_mono_white.png';
  static const String symbolMonoDark =
      'assets/branding/monochrome/symbol_mono_dark.png';
  static const String splashBranding =
      'assets/branding/splash/splash_branding.png';
}

/// Spesifikasi visual kelas karakter untuk ilustrasi menu & placeholder vektor.
@immutable
class CharacterVisualSpec {
  const CharacterVisualSpec({
    required this.classId,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.accentColor,
    required this.auraColor,
    required this.weaponStyle,
    required this.poseSummary,
    required this.assetPath,
  });

  final String classId;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final Color accentColor;
  final Color auraColor;
  final String weaponStyle;
  final String poseSummary;
  final String assetPath;

  static CharacterVisualSpec resolve(String specializationId) {
    final key = specializationId.trim().toLowerCase();
    return switch (key) {
      'vanguard' => _vanguard,
      'arcanist' => _arcanist,
      'ranger' => _ranger,
      'paladin' => _paladin,
      'voidblade' => _voidblade,
      'chronomancer' => _chronomancer,
      'gunslinger' => _gunslinger,
      'necromancer' => _necromancer,
      'stormcaller' => _stormcaller,
      _ => _base,
    };
  }

  static const CharacterVisualSpec _base = CharacterVisualSpec(
    classId: 'base',
    title: 'Adventurer',
    subtitle: 'New Player Starting Class (Adventurer)',
    primaryColor: AppColors.forestGreen,
    accentColor: AppColors.antiqueGold,
    auraColor: AppColors.aetherBlue,
    weaponStyle: 'Traveler Blade & Scarf',
    poseSummary: 'A brave wanderer, ready to explore the world of Aether',
    assetPath: '${GameAssetDirectories.characters}hero_base.png',
  );

  static const CharacterVisualSpec _vanguard = CharacterVisualSpec(
    classId: 'vanguard',
    title: 'Vanguard',
    subtitle: 'Frontline Warrior',
    primaryColor: AppColors.antiqueGold,
    accentColor: AppColors.emberRed,
    auraColor: AppColors.campAmber,
    weaponStyle: 'Aether Bastion Shield & Broadsword',
    poseSummary: '3/4 heroic guard, plated pauldrons, planted kite shield',
    assetPath: '${GameAssetDirectories.characters}hero_vanguard.png',
  );

  static const CharacterVisualSpec _arcanist = CharacterVisualSpec(
    classId: 'arcanist',
    title: 'Arcanist',
    subtitle: 'Arcane Mage',
    primaryColor: AppColors.aetherBlue,
    accentColor: AppColors.arcaneViolet,
    auraColor: AppColors.aetherBlue,
    weaponStyle: 'Floating Aether Grimoire & Runestaff',
    poseSummary: '3/4 poised casting stance, flowing arcane mantle',
    assetPath: '${GameAssetDirectories.characters}hero_arcanist.png',
  );

  static const CharacterVisualSpec _ranger = CharacterVisualSpec(
    classId: 'ranger',
    title: 'Ranger',
    subtitle: 'Precision Archer',
    primaryColor: AppColors.mossGreen,
    accentColor: AppColors.antiqueGold,
    auraColor: AppColors.success,
    weaponStyle: 'Enchanted Recurve Bow & Quiver',
    poseSummary: '3/4 agile crouch-ready stance, drawn bowstring glow',
    assetPath: '${GameAssetDirectories.characters}hero_ranger.png',
  );

  static const CharacterVisualSpec _paladin = CharacterVisualSpec(
    classId: 'paladin',
    title: 'Paladin',
    subtitle: 'Holy Knight',
    primaryColor: AppColors.antiqueGold,
    accentColor: AppColors.campAmber,
    auraColor: AppColors.antiqueGold,
    weaponStyle: 'Radiant Bastion Shield & Holy Blade',
    poseSummary: 'Resolute holy knight guard, gold & white plated armor, radiant cross shield',
    assetPath: '${GameAssetDirectories.characters}hero_paladin.png',
  );

  static const CharacterVisualSpec _voidblade = CharacterVisualSpec(
    classId: 'voidblade',
    title: 'Voidblade',
    subtitle: 'Shadow Assassin',
    primaryColor: AppColors.arcaneViolet,
    accentColor: AppColors.aetherBlue,
    auraColor: AppColors.arcaneViolet,
    weaponStyle: 'Twin Nether Blades',
    poseSummary: 'Low agile assassin stance, silver spiky hair, glowing purple void daggers',
    assetPath: '${GameAssetDirectories.characters}hero_voidblade.png',
  );

  static const CharacterVisualSpec _chronomancer = CharacterVisualSpec(
    classId: 'chronomancer',
    title: 'Chronomancer',
    subtitle: 'Time Mage',
    primaryColor: AppColors.aetherBlue,
    accentColor: AppColors.antiqueGold,
    auraColor: AppColors.aetherBlue,
    weaponStyle: 'Temporal Scepter & Hourglass of Aether',
    poseSummary: 'Graceful temporal casting stance, flowing cyan hair, hourglass artifact',
    assetPath: '${GameAssetDirectories.characters}hero_chronomancer.png',
  );

  static const CharacterVisualSpec _gunslinger = CharacterVisualSpec(
    classId: 'gunslinger',
    title: 'Gunslinger',
    subtitle: 'Aether Gunner',
    primaryColor: AppColors.earthBrown,
    accentColor: AppColors.emberRed,
    auraColor: AppColors.campAmber,
    weaponStyle: 'Dual Aether Revolvers & Outlaw Rifle',
    poseSummary: 'Goggled marksman stance, long leather duster coat, drawn aether pistol',
    assetPath: '${GameAssetDirectories.characters}hero_gunslinger.png',
  );

  static const CharacterVisualSpec _necromancer = CharacterVisualSpec(
    classId: 'necromancer',
    title: 'Necromancer',
    subtitle: 'Soul Summoner',
    primaryColor: AppColors.deepForest,
    accentColor: AppColors.mossGreen,
    auraColor: AppColors.success,
    weaponStyle: 'Grim Soul Scythe & Relic Skull',
    poseSummary: 'Shrouded necromantic stance, deep cowl, curved soul scythe with green wisp',
    assetPath: '${GameAssetDirectories.characters}hero_necromancer.png',
  );

  static const CharacterVisualSpec _stormcaller = CharacterVisualSpec(
    classId: 'stormcaller',
    title: 'Stormcaller',
    subtitle: 'Lightning Mage',
    primaryColor: AppColors.aetherBlue,
    accentColor: AppColors.antiqueGold,
    auraColor: AppColors.aetherBlue,
    weaponStyle: 'Lightning Conduit Staff',
    poseSummary:
        'Electrified magus stance, wild silver-blue hair, crackling storm rod',
    assetPath: '${GameAssetDirectories.characters}hero_stormcaller.png',
  );
}

/// Spesifikasi visual biome untuk latar belakang dan kartu dungeon.
@immutable
class BiomeVisualSpec {
  const BiomeVisualSpec({
    required this.biomeId,
    required this.skyTop,
    required this.skyBottom,
    required this.terrainColor,
    required this.accentColor,
    required this.atmosphereColor,
    required this.assetPath,
  });

  final String biomeId;
  final Color skyTop;
  final Color skyBottom;
  final Color terrainColor;
  final Color accentColor;
  final Color atmosphereColor;
  final String assetPath;

  static BiomeVisualSpec resolve(String biomeId, {bool isAscension = false}) {
    if (isAscension) return _ascensionSanctum;
    return switch (biomeId.trim().toLowerCase()) {
      'forgotten_forest' => _forgottenForest,
      'crystal_cavern' => _crystalCavern,
      'ancient_crypt' => _ancientCrypt,
      'ashen_wasteland' => _ashenWasteland,
      'aether_sanctum' => _aetherSanctum,
      _ => _forgottenForest,
    };
  }

  static const BiomeVisualSpec _forgottenForest = BiomeVisualSpec(
    biomeId: 'forgotten_forest',
    skyTop: Color(0xFF0C1C17),
    skyBottom: Color(0xFF1A382D),
    terrainColor: Color(0xFF28493A),
    accentColor: AppColors.mossGreen,
    atmosphereColor: AppColors.aetherBlue,
    assetPath: '${GameAssetDirectories.biomes}biome_forgotten_forest.png',
  );

  static const BiomeVisualSpec _crystalCavern = BiomeVisualSpec(
    biomeId: 'crystal_cavern',
    skyTop: Color(0xFF0B1826),
    skyBottom: Color(0xFF153147),
    terrainColor: Color(0xFF1D435C),
    accentColor: AppColors.aetherBlue,
    atmosphereColor: Color(0xFF9DE2FF),
    assetPath: '${GameAssetDirectories.biomes}biome_crystal_cavern.png',
  );

  static const BiomeVisualSpec _ancientCrypt = BiomeVisualSpec(
    biomeId: 'ancient_crypt',
    skyTop: Color(0xFF161322),
    skyBottom: Color(0xFF27213B),
    terrainColor: Color(0xFF352F4B),
    accentColor: AppColors.arcaneViolet,
    atmosphereColor: Color(0xFFCBB2F0),
    assetPath: '${GameAssetDirectories.biomes}biome_ancient_crypt.png',
  );

  static const BiomeVisualSpec _ashenWasteland = BiomeVisualSpec(
    biomeId: 'ashen_wasteland',
    skyTop: Color(0xFF1E1111),
    skyBottom: Color(0xFF38201E),
    terrainColor: Color(0xFF4C2B27),
    accentColor: AppColors.emberRed,
    atmosphereColor: AppColors.campAmber,
    assetPath: '${GameAssetDirectories.biomes}biome_ashen_wasteland.png',
  );

  static const BiomeVisualSpec _aetherSanctum = BiomeVisualSpec(
    biomeId: 'aether_sanctum',
    skyTop: Color(0xFF151926),
    skyBottom: Color(0xFF263345),
    terrainColor: Color(0xFF324558),
    accentColor: AppColors.antiqueGold,
    atmosphereColor: AppColors.aetherBlue,
    assetPath: '${GameAssetDirectories.biomes}biome_aether_sanctum.png',
  );

  static const BiomeVisualSpec _ascensionSanctum = BiomeVisualSpec(
    biomeId: 'ascension_sanctum',
    skyTop: Color(0xFF1A1426),
    skyBottom: Color(0xFF2B2848),
    terrainColor: Color(0xFF3A355B),
    accentColor: AppColors.antiqueGold,
    atmosphereColor: AppColors.arcaneViolet,
    assetPath: '${GameAssetDirectories.biomes}biome_ascension_sanctum.png',
  );
}

/// Registry terpusat untuk memudahkan transisi placeholder vektor -> PNG final.
///
/// Ketika PNG final sudah ditambahkan ke direktori `assets/images/...` dan
/// didaftarkan di `pubspec.yaml`, aktifkan asset path pada set ini tanpa
/// mengubah widget layar.
abstract final class GameAssetRegistry {
  static const Set<String> bundledRasterAssets = <String>{};

  static bool hasRasterAsset(String assetPath) =>
      bundledRasterAssets.contains(assetPath);
}
