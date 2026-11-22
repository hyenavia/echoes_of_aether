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

  CharacterClassAssetManifest get manifest =>
      CharacterAssetCatalog.forClass(classId);

  String get emblemPath => manifest.emblemPath;
  String get portraitPath => manifest.portraitPath;
  String get showcasePath => manifest.showcasePath;
  String? get nameplatePath => manifest.nameplatePath;
  String? get subtitleImagePath => manifest.subtitleImagePath;
  String? get combatVfxGroupPath => manifest.combatVfxGroupPath;
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

/// Urutan animasi karakter sesuai asset manifest & gameplay state.
enum CharacterAnimationSequence {
  idle('idle', true),
  idleAlternate('idle_alternate', true),
  walk('walk', true),
  run('run', true),
  attack('attack', false),
  skillSpecial('skill_special', false),
  downed('downed', false);

  const CharacterAnimationSequence(this.key, this.loops);

  final String key;
  final bool loops;
}

/// Manifest aset karakter, ikon, showcase, dan frame animasi per class.
@immutable
class CharacterClassAssetManifest {
  const CharacterClassAssetManifest({
    required this.classId,
    required this.emblemPath,
    required this.portraitPath,
    required this.showcasePath,
    this.nameplatePath,
    this.subtitleImagePath,
    this.combatVfxGroupPath,
    required this.sequences,
  });

  final String classId;
  final String emblemPath;
  final String portraitPath;
  final String showcasePath;
  final String? nameplatePath;
  final String? subtitleImagePath;
  final String? combatVfxGroupPath;
  final Map<CharacterAnimationSequence, List<String>> sequences;

  /// Ambil frame sequence [sequence] dengan fallback aman bila sequence kosong/hilang.
  List<String> framesForSequence(CharacterAnimationSequence sequence) {
    final direct = sequences[sequence];
    if (direct != null && direct.isNotEmpty) return direct;

    switch (sequence) {
      case CharacterAnimationSequence.idleAlternate:
        return framesForSequence(CharacterAnimationSequence.idle);
      case CharacterAnimationSequence.run:
        final walk = sequences[CharacterAnimationSequence.walk];
        if (walk != null && walk.isNotEmpty) return walk;
        return framesForSequence(CharacterAnimationSequence.idle);
      case CharacterAnimationSequence.skillSpecial:
        final attack = sequences[CharacterAnimationSequence.attack];
        if (attack != null && attack.isNotEmpty) return attack;
        return framesForSequence(CharacterAnimationSequence.idle);
      case CharacterAnimationSequence.walk:
      case CharacterAnimationSequence.attack:
      case CharacterAnimationSequence.downed:
        final idle = sequences[CharacterAnimationSequence.idle];
        if (idle != null && idle.isNotEmpty) return idle;
        return <String>[portraitPath];
      case CharacterAnimationSequence.idle:
        return <String>[portraitPath];
    }
  }

  /// Ambil path frame ke-[frameIndex] dengan loop/clamp sesuai jenis sequence.
  String frameFor(CharacterAnimationSequence sequence, int frameIndex) {
    final frames = framesForSequence(sequence);
    if (frames.isEmpty) return portraitPath;
    if (frameIndex < 0) return frames.first;
    final index = sequence.loops
        ? frameIndex % frames.length
        : frameIndex.clamp(0, frames.length - 1);
    return frames[index];
  }

  /// Daftar seluruh asset path unik yang direferensikan class ini.
  List<String> get allAssetPaths {
    final seen = <String>{};
    final out = <String>[];
    void addPath(String? path) {
      if (path != null && path.isNotEmpty && seen.add(path)) {
        out.add(path);
      }
    }

    addPath(emblemPath);
    addPath(portraitPath);
    addPath(showcasePath);
    addPath(nameplatePath);
    addPath(subtitleImagePath);
    addPath(combatVfxGroupPath);
    for (final frames in sequences.values) {
      for (final frame in frames) {
        addPath(frame);
      }
    }
    return out;
  }
}

/// Katalog terpusat aset hasil ekstraksi di `assets/characters/`,
/// `assets/icons/class/`, dan `assets/char/` untuk Adventurer + 9 class.
abstract final class CharacterAssetCatalog {
  static const List<String> playableClassIds = <String>[
    'base',
    'vanguard',
    'arcanist',
    'ranger',
    'paladin',
    'voidblade',
    'chronomancer',
    'gunslinger',
    'necromancer',
    'stormcaller',
  ];

  static const Map<String, CharacterClassAssetManifest>
  manifests = <String, CharacterClassAssetManifest>{
    'base': CharacterClassAssetManifest(
      classId: 'base',
      emblemPath:
          'assets/characters/adventurer/icons/adventurer_class_compass.png',
      portraitPath: 'assets/char/frames/hero_base_idle0.png',
      showcasePath:
          'assets/characters/adventurer/showcase/adventurer_showcase.png',
      nameplatePath: 'assets/characters/adventurer/ui/adventurer_nameplate.png',
      subtitleImagePath:
          'assets/characters/adventurer/ui/adventurer_class_description.png',
      sequences: <CharacterAnimationSequence, List<String>>{
        CharacterAnimationSequence.idle: <String>[
          'assets/characters/adventurer/animations/idle/adventurer_idle_01.png',
          'assets/characters/adventurer/animations/idle/adventurer_idle_02.png',
          'assets/characters/adventurer/animations/idle/adventurer_idle_03.png',
          'assets/characters/adventurer/animations/idle/adventurer_idle_04.png',
        ],
        CharacterAnimationSequence.idleAlternate: <String>[
          'assets/characters/adventurer/animations/idle_alternate/adventurer_idle_alternate_01.png',
          'assets/characters/adventurer/animations/idle_alternate/adventurer_idle_alternate_02.png',
          'assets/characters/adventurer/animations/idle_alternate/adventurer_idle_alternate_03.png',
          'assets/characters/adventurer/animations/idle_alternate/adventurer_idle_alternate_04.png',
        ],
        CharacterAnimationSequence.walk: <String>[
          'assets/characters/adventurer/animations/walk/adventurer_walk_01.png',
          'assets/characters/adventurer/animations/walk/adventurer_walk_02.png',
          'assets/characters/adventurer/animations/walk/adventurer_walk_03.png',
          'assets/characters/adventurer/animations/walk/adventurer_walk_04.png',
        ],
        CharacterAnimationSequence.run: <String>[
          'assets/characters/adventurer/animations/run/adventurer_run_01.png',
          'assets/characters/adventurer/animations/run/adventurer_run_02.png',
          'assets/characters/adventurer/animations/run/adventurer_run_03.png',
          'assets/characters/adventurer/animations/run/adventurer_run_04.png',
        ],
        CharacterAnimationSequence.attack: <String>[
          'assets/characters/adventurer/animations/attack/adventurer_attack_01.png',
          'assets/characters/adventurer/animations/attack/adventurer_attack_02.png',
          'assets/characters/adventurer/animations/attack/adventurer_attack_03.png',
          'assets/characters/adventurer/animations/attack/adventurer_attack_04.png',
        ],
        CharacterAnimationSequence.skillSpecial: <String>[
          'assets/characters/adventurer/animations/skill_special/adventurer_skill_special_01.png',
          'assets/characters/adventurer/animations/skill_special/adventurer_skill_special_02.png',
          'assets/characters/adventurer/animations/skill_special/adventurer_skill_special_03.png',
          'assets/characters/adventurer/animations/skill_special/adventurer_skill_special_04.png',
        ],
        CharacterAnimationSequence.downed: <String>[
          'assets/characters/adventurer/animations/downed/adventurer_downed_01.png',
          'assets/characters/adventurer/animations/downed/adventurer_downed_02.png',
        ],
      },
    ),
    'vanguard': CharacterClassAssetManifest(
      classId: 'vanguard',
      emblemPath: 'assets/icons/class/crest_vanguard.png',
      portraitPath: 'assets/char/hero_vanguard.png',
      showcasePath: 'assets/characters/classes/vanguard/showcase/vanguard_showcase_group_02.png',
      nameplatePath:
          'assets/characters/classes/vanguard/ui/vanguard_nameplate_01.png',
      combatVfxGroupPath: 'assets/characters/classes/vanguard/animations/attack/vanguard_combat_group_07.png',
      sequences: <CharacterAnimationSequence, List<String>>{
        CharacterAnimationSequence.idle: <String>[
          'assets/characters/classes/vanguard/sprites/vanguard_pose_08.png',
          'assets/characters/classes/vanguard/sprites/vanguard_sprite_03.png',
        ],
        CharacterAnimationSequence.idleAlternate: <String>[
          'assets/characters/classes/vanguard/sprites/vanguard_sprite_04.png',
          'assets/characters/classes/vanguard/sprites/vanguard_sprite_03.png',
        ],
        CharacterAnimationSequence.walk: <String>[
          'assets/characters/classes/vanguard/sprites/vanguard_sprite_05.png',
          'assets/characters/classes/vanguard/sprites/vanguard_sprite_06.png',
        ],
        CharacterAnimationSequence.run: <String>[
          'assets/characters/classes/vanguard/sprites/vanguard_sprite_05.png',
          'assets/characters/classes/vanguard/sprites/vanguard_sprite_04.png',
          'assets/characters/classes/vanguard/sprites/vanguard_sprite_06.png',
        ],
        CharacterAnimationSequence.attack: <String>[
          'assets/char/frames/hero_vanguard_attack.png',
          'assets/characters/classes/vanguard/sprites/vanguard_pose_08.png',
        ],
        CharacterAnimationSequence.skillSpecial: <String>[
          'assets/char/frames/hero_vanguard_attack.png',
          'assets/characters/classes/vanguard/sprites/vanguard_sprite_04.png',
        ],
        CharacterAnimationSequence.downed: <String>[
          'assets/characters/classes/vanguard/sprites/vanguard_pose_09.png',
        ],
      },
    ),
    'arcanist': CharacterClassAssetManifest(
      classId: 'arcanist',
      emblemPath: 'assets/icons/class/crest_arcanist.png',
      portraitPath: 'assets/char/hero_arcanist.png',
      showcasePath: 'assets/characters/classes/arcanist/sprites/arcanist_sprite_group_03.png',
      nameplatePath:
          'assets/characters/classes/arcanist/ui/arcanist_nameplate_01.png',
      subtitleImagePath:
          'assets/characters/classes/arcanist/ui/arcanist_subtitle_02.png',
      combatVfxGroupPath: 'assets/characters/classes/arcanist/animations/attack/arcanist_combat_group_09.png',
      sequences: <CharacterAnimationSequence, List<String>>{
        CharacterAnimationSequence.idle: <String>[
          'assets/characters/classes/arcanist/sprites/arcanist_sprite_05.png',
          'assets/characters/classes/arcanist/sprites/arcanist_sprite_06.png',
        ],
        CharacterAnimationSequence.idleAlternate: <String>[
          'assets/characters/classes/arcanist/sprites/arcanist_sprite_06.png',
          'assets/characters/classes/arcanist/sprites/arcanist_sprite_05.png',
        ],
        CharacterAnimationSequence.walk: <String>[
          'assets/characters/classes/arcanist/sprites/arcanist_sprite_07.png',
          'assets/characters/classes/arcanist/sprites/arcanist_sprite_08.png',
        ],
        CharacterAnimationSequence.run: <String>[
          'assets/characters/classes/arcanist/sprites/arcanist_sprite_07.png',
          'assets/characters/classes/arcanist/sprites/arcanist_sprite_06.png',
          'assets/characters/classes/arcanist/sprites/arcanist_sprite_08.png',
        ],
        CharacterAnimationSequence.attack: <String>[
          'assets/char/frames/hero_arcanist_attack.png',
          'assets/characters/classes/arcanist/sprites/arcanist_sprite_06.png',
        ],
        CharacterAnimationSequence.skillSpecial: <String>[
          'assets/char/frames/hero_arcanist_attack.png',
          'assets/characters/classes/arcanist/sprites/arcanist_sprite_05.png',
        ],
        CharacterAnimationSequence.downed: <String>[
          'assets/characters/classes/arcanist/sprites/arcanist_pose_10.png',
        ],
      },
    ),
    'ranger': CharacterClassAssetManifest(
      classId: 'ranger',
      emblemPath: 'assets/icons/class/crest_ranger.png',
      portraitPath: 'assets/char/hero_ranger.png',
      showcasePath:
          'assets/characters/classes/ranger/sprites/ranger_sprite_group_03.png',
      nameplatePath:
          'assets/characters/classes/ranger/ui/ranger_nameplate_01.png',
      subtitleImagePath:
          'assets/characters/classes/ranger/ui/ranger_subtitle_02.png',
      combatVfxGroupPath: 'assets/characters/classes/ranger/animations/attack/ranger_combat_group_08.png',
      sequences: <CharacterAnimationSequence, List<String>>{
        CharacterAnimationSequence.idle: <String>[
          'assets/characters/classes/ranger/sprites/ranger_sprite_04.png',
          'assets/characters/classes/ranger/sprites/ranger_sprite_05.png',
        ],
        CharacterAnimationSequence.idleAlternate: <String>[
          'assets/characters/classes/ranger/sprites/ranger_sprite_05.png',
          'assets/characters/classes/ranger/sprites/ranger_sprite_04.png',
        ],
        CharacterAnimationSequence.walk: <String>[
          'assets/characters/classes/ranger/sprites/ranger_sprite_06.png',
          'assets/characters/classes/ranger/sprites/ranger_sprite_07.png',
        ],
        CharacterAnimationSequence.run: <String>[
          'assets/characters/classes/ranger/sprites/ranger_sprite_06.png',
          'assets/characters/classes/ranger/sprites/ranger_sprite_05.png',
          'assets/characters/classes/ranger/sprites/ranger_sprite_07.png',
        ],
        CharacterAnimationSequence.attack: <String>[
          'assets/char/frames/hero_ranger_attack.png',
          'assets/characters/classes/ranger/sprites/ranger_sprite_05.png',
        ],
        CharacterAnimationSequence.skillSpecial: <String>[
          'assets/char/frames/hero_ranger_attack.png',
          'assets/characters/classes/ranger/sprites/ranger_sprite_04.png',
        ],
        CharacterAnimationSequence.downed: <String>[
          'assets/characters/classes/ranger/sprites/ranger_pose_09.png',
        ],
      },
    ),
    'paladin': CharacterClassAssetManifest(
      classId: 'paladin',
      emblemPath: 'assets/icons/class/crest_paladin.png',
      portraitPath: 'assets/char/hero_paladin.png',
      showcasePath: 'assets/characters/classes/paladin/showcase/paladin_showcase_group_02.png',
      nameplatePath:
          'assets/characters/classes/paladin/ui/paladin_nameplate_01.png',
      combatVfxGroupPath: 'assets/characters/classes/paladin/animations/attack/paladin_combat_group_08.png',
      sequences: <CharacterAnimationSequence, List<String>>{
        CharacterAnimationSequence.idle: <String>[
          'assets/characters/classes/paladin/sprites/paladin_sprite_04.png',
          'assets/characters/classes/paladin/sprites/paladin_sprite_05.png',
        ],
        CharacterAnimationSequence.idleAlternate: <String>[
          'assets/characters/classes/paladin/sprites/paladin_sprite_05.png',
          'assets/characters/classes/paladin/sprites/paladin_sprite_04.png',
        ],
        CharacterAnimationSequence.walk: <String>[
          'assets/characters/classes/paladin/sprites/paladin_sprite_06.png',
          'assets/characters/classes/paladin/sprites/paladin_sprite_07.png',
        ],
        CharacterAnimationSequence.run: <String>[
          'assets/characters/classes/paladin/sprites/paladin_sprite_06.png',
          'assets/characters/classes/paladin/sprites/paladin_sprite_05.png',
          'assets/characters/classes/paladin/sprites/paladin_sprite_07.png',
        ],
        CharacterAnimationSequence.attack: <String>[
          'assets/char/frames/hero_paladin_attack.png',
          'assets/characters/classes/paladin/sprites/paladin_sprite_05.png',
        ],
        CharacterAnimationSequence.skillSpecial: <String>[
          'assets/char/frames/hero_paladin_attack.png',
          'assets/characters/classes/paladin/sprites/paladin_sprite_04.png',
        ],
        CharacterAnimationSequence.downed: <String>[
          'assets/characters/classes/paladin/sprites/paladin_pose_09.png',
        ],
      },
    ),
    'voidblade': CharacterClassAssetManifest(
      classId: 'voidblade',
      emblemPath: 'assets/icons/class/crest_voidblade.png',
      portraitPath: 'assets/char/hero_voidblade.png',
      showcasePath: 'assets/char/hero_voidblade.png',
      nameplatePath:
          'assets/characters/classes/voidblade/ui/voidblade_nameplate_01.png',
      subtitleImagePath:
          'assets/characters/classes/voidblade/ui/voidblade_subtitle_02.png',
      combatVfxGroupPath: 'assets/characters/classes/voidblade/animations/attack/voidblade_combat_group_07.png',
      sequences: <CharacterAnimationSequence, List<String>>{
        CharacterAnimationSequence.idle: <String>[
          'assets/characters/classes/voidblade/sprites/voidblade_sprite_03.png',
          'assets/characters/classes/voidblade/sprites/voidblade_sprite_04.png',
        ],
        CharacterAnimationSequence.idleAlternate: <String>[
          'assets/characters/classes/voidblade/sprites/voidblade_sprite_04.png',
          'assets/characters/classes/voidblade/sprites/voidblade_sprite_03.png',
        ],
        CharacterAnimationSequence.walk: <String>[
          'assets/characters/classes/voidblade/sprites/voidblade_sprite_05.png',
          'assets/characters/classes/voidblade/sprites/voidblade_sprite_06.png',
        ],
        CharacterAnimationSequence.run: <String>[
          'assets/characters/classes/voidblade/sprites/voidblade_sprite_05.png',
          'assets/characters/classes/voidblade/sprites/voidblade_sprite_04.png',
          'assets/characters/classes/voidblade/sprites/voidblade_sprite_06.png',
        ],
        CharacterAnimationSequence.attack: <String>[
          'assets/char/frames/hero_voidblade_attack.png',
          'assets/characters/classes/voidblade/sprites/voidblade_sprite_04.png',
        ],
        CharacterAnimationSequence.skillSpecial: <String>[
          'assets/char/frames/hero_voidblade_attack.png',
          'assets/characters/classes/voidblade/sprites/voidblade_sprite_03.png',
        ],
        CharacterAnimationSequence.downed: <String>[
          'assets/characters/classes/voidblade/sprites/voidblade_pose_08.png',
        ],
      },
    ),
    'chronomancer': CharacterClassAssetManifest(
      classId: 'chronomancer',
      emblemPath: 'assets/icons/class/crest_chronomancer.png',
      portraitPath: 'assets/char/hero_chronomancer.png',
      showcasePath: 'assets/characters/classes/chronomancer/showcase/chronomancer_showcase_group_03.png',
      nameplatePath: 'assets/characters/classes/chronomancer/ui/chronomancer_nameplate_01.png',
      subtitleImagePath: 'assets/characters/classes/chronomancer/ui/chronomancer_subtitle_02.png',
      combatVfxGroupPath: 'assets/characters/classes/chronomancer/animations/attack/chronomancer_combat_group_08.png',
      sequences: <CharacterAnimationSequence, List<String>>{
        CharacterAnimationSequence.idle: <String>[
          'assets/characters/classes/chronomancer/sprites/chronomancer_sprite_04.png',
          'assets/characters/classes/chronomancer/sprites/chronomancer_sprite_05.png',
        ],
        CharacterAnimationSequence.idleAlternate: <String>[
          'assets/characters/classes/chronomancer/sprites/chronomancer_sprite_05.png',
          'assets/characters/classes/chronomancer/sprites/chronomancer_sprite_04.png',
        ],
        CharacterAnimationSequence.walk: <String>[
          'assets/characters/classes/chronomancer/sprites/chronomancer_sprite_06.png',
          'assets/characters/classes/chronomancer/sprites/chronomancer_sprite_07.png',
        ],
        CharacterAnimationSequence.run: <String>[
          'assets/characters/classes/chronomancer/sprites/chronomancer_sprite_06.png',
          'assets/characters/classes/chronomancer/sprites/chronomancer_sprite_05.png',
          'assets/characters/classes/chronomancer/sprites/chronomancer_sprite_07.png',
        ],
        CharacterAnimationSequence.attack: <String>[
          'assets/char/frames/hero_chronomancer_attack.png',
          'assets/characters/classes/chronomancer/sprites/chronomancer_sprite_05.png',
        ],
        CharacterAnimationSequence.skillSpecial: <String>[
          'assets/char/frames/hero_chronomancer_attack.png',
          'assets/characters/classes/chronomancer/sprites/chronomancer_sprite_04.png',
        ],
        CharacterAnimationSequence.downed: <String>[
          'assets/characters/classes/chronomancer/sprites/chronomancer_pose_09.png',
        ],
      },
    ),
    'gunslinger': CharacterClassAssetManifest(
      classId: 'gunslinger',
      emblemPath: 'assets/icons/class/crest_gunslinger.png',
      portraitPath: 'assets/char/hero_gunslinger.png',
      showcasePath: 'assets/characters/classes/gunslinger/sprites/gunslinger_sprite_group_02.png',
      nameplatePath:
          'assets/characters/classes/gunslinger/ui/gunslinger_nameplate_01.png',
      combatVfxGroupPath: 'assets/characters/classes/gunslinger/animations/attack/gunslinger_combat_group_08.png',
      sequences: <CharacterAnimationSequence, List<String>>{
        CharacterAnimationSequence.idle: <String>[
          'assets/characters/classes/gunslinger/sprites/gunslinger_sprite_04.png',
          'assets/characters/classes/gunslinger/sprites/gunslinger_sprite_05.png',
        ],
        CharacterAnimationSequence.idleAlternate: <String>[
          'assets/characters/classes/gunslinger/sprites/gunslinger_sprite_05.png',
          'assets/characters/classes/gunslinger/sprites/gunslinger_sprite_04.png',
        ],
        CharacterAnimationSequence.walk: <String>[
          'assets/characters/classes/gunslinger/sprites/gunslinger_sprite_06.png',
          'assets/characters/classes/gunslinger/sprites/gunslinger_sprite_07.png',
        ],
        CharacterAnimationSequence.run: <String>[
          'assets/characters/classes/gunslinger/sprites/gunslinger_sprite_06.png',
          'assets/characters/classes/gunslinger/sprites/gunslinger_sprite_05.png',
          'assets/characters/classes/gunslinger/sprites/gunslinger_sprite_07.png',
        ],
        CharacterAnimationSequence.attack: <String>[
          'assets/char/frames/hero_gunslinger_attack.png',
          'assets/characters/classes/gunslinger/sprites/gunslinger_sprite_05.png',
        ],
        CharacterAnimationSequence.skillSpecial: <String>[
          'assets/char/frames/hero_gunslinger_attack.png',
          'assets/characters/classes/gunslinger/sprites/gunslinger_sprite_04.png',
        ],
        CharacterAnimationSequence.downed: <String>[
          'assets/characters/classes/gunslinger/sprites/gunslinger_pose_09.png',
        ],
      },
    ),
    'necromancer': CharacterClassAssetManifest(
      classId: 'necromancer',
      emblemPath: 'assets/icons/class/crest_necromancer.png',
      portraitPath: 'assets/char/hero_necromancer.png',
      showcasePath: 'assets/characters/classes/necromancer/showcase/necromancer_showcase_group_03.png',
      nameplatePath: 'assets/characters/classes/necromancer/ui/necromancer_nameplate_01.png',
      subtitleImagePath: 'assets/characters/classes/necromancer/ui/necromancer_subtitle_02.png',
      combatVfxGroupPath: 'assets/characters/classes/necromancer/animations/attack/necromancer_combat_group_07.png',
      sequences: <CharacterAnimationSequence, List<String>>{
        CharacterAnimationSequence.idle: <String>[
          'assets/characters/classes/necromancer/sprites/necromancer_sprite_04.png',
          'assets/char/frames/hero_necromancer_idle1.png',
        ],
        CharacterAnimationSequence.idleAlternate: <String>[
          'assets/char/frames/hero_necromancer_idle1.png',
          'assets/characters/classes/necromancer/sprites/necromancer_sprite_04.png',
        ],
        CharacterAnimationSequence.walk: <String>[
          'assets/characters/classes/necromancer/sprites/necromancer_sprite_06.png',
          'assets/char/frames/hero_necromancer_walk1.png',
        ],
        CharacterAnimationSequence.run: <String>[
          'assets/char/frames/hero_necromancer_walk0.png',
          'assets/characters/classes/necromancer/sprites/necromancer_sprite_06.png',
          'assets/char/frames/hero_necromancer_walk1.png',
        ],
        CharacterAnimationSequence.attack: <String>[
          'assets/char/frames/hero_necromancer_attack.png',
          'assets/char/frames/hero_necromancer_idle1.png',
        ],
        CharacterAnimationSequence.skillSpecial: <String>[
          'assets/char/frames/hero_necromancer_attack.png',
          'assets/characters/classes/necromancer/sprites/necromancer_sprite_04.png',
        ],
        CharacterAnimationSequence.downed: <String>[
          'assets/characters/classes/necromancer/sprites/necromancer_pose_08.png',
        ],
      },
    ),
    'stormcaller': CharacterClassAssetManifest(
      classId: 'stormcaller',
      emblemPath: 'assets/icons/class/crest_stormcaller.png',
      portraitPath: 'assets/char/hero_stormcaller.png',
      showcasePath: 'assets/char/hero_stormcaller.png',
      nameplatePath: 'assets/characters/classes/stormcaller/ui/stormcaller_nameplate_01.png',
      combatVfxGroupPath: 'assets/characters/classes/stormcaller/animations/attack/stormcaller_combat_group_06.png',
      sequences: <CharacterAnimationSequence, List<String>>{
        CharacterAnimationSequence.idle: <String>[
          'assets/characters/classes/stormcaller/sprites/stormcaller_sprite_02.png',
          'assets/characters/classes/stormcaller/sprites/stormcaller_sprite_03.png',
        ],
        CharacterAnimationSequence.idleAlternate: <String>[
          'assets/characters/classes/stormcaller/sprites/stormcaller_sprite_03.png',
          'assets/characters/classes/stormcaller/sprites/stormcaller_sprite_02.png',
        ],
        CharacterAnimationSequence.walk: <String>[
          'assets/characters/classes/stormcaller/sprites/stormcaller_sprite_04.png',
          'assets/characters/classes/stormcaller/sprites/stormcaller_sprite_05.png',
        ],
        CharacterAnimationSequence.run: <String>[
          'assets/characters/classes/stormcaller/sprites/stormcaller_sprite_04.png',
          'assets/characters/classes/stormcaller/sprites/stormcaller_sprite_03.png',
          'assets/characters/classes/stormcaller/sprites/stormcaller_sprite_05.png',
        ],
        CharacterAnimationSequence.attack: <String>[
          'assets/char/frames/hero_stormcaller_attack.png',
          'assets/characters/classes/stormcaller/sprites/stormcaller_sprite_03.png',
        ],
        CharacterAnimationSequence.skillSpecial: <String>[
          'assets/char/frames/hero_stormcaller_attack.png',
          'assets/characters/classes/stormcaller/sprites/stormcaller_sprite_02.png',
        ],
        CharacterAnimationSequence.downed: <String>[
          'assets/characters/classes/stormcaller/sprites/stormcaller_pose_07.png',
        ],
      },
    ),
  };

  static CharacterClassAssetManifest forClass(String specializationId) {
    final key = specializationId.trim().toLowerCase();
    if (key == 'adventurer' || key.isEmpty) {
      return manifests['base']!;
    }
    return manifests[key] ?? manifests['base']!;
  }

  /// Seluruh asset path unik yang perlu di-preload oleh runtime karakter.
  static List<String> get allCharacterAssetPaths {
    final seen = <String>{};
    final out = <String>[];
    for (final manifest in manifests.values) {
      for (final path in manifest.allAssetPaths) {
        if (seen.add(path)) out.add(path);
      }
    }
    return out;
  }

  /// Frame animasi gameplay (tanpa UI banner) untuk preload atlas Flame.
  static List<String> get gameplaySpriteFramePaths {
    final seen = <String>{};
    final out = <String>[];
    for (final manifest in manifests.values) {
      for (final frames in manifest.sequences.values) {
        for (final path in frames) {
          if (seen.add(path)) out.add(path);
        }
      }
      if (seen.add(manifest.portraitPath)) out.add(manifest.portraitPath);
    }
    return out;
  }
}
