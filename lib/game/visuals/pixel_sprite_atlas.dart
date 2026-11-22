import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../features/shared/assets/game_assets.dart';
import 'pixel_sprite_data.dart';

/// Resolusi dasar pixel art untuk tile dan karakter MVP (16x16).
class PixelSpriteAtlas {
  PixelSpriteAtlas._();

  static final PixelSpriteAtlas instance = PixelSpriteAtlas._();

  static const int gridSize = 16;

  static final ui.Paint pixelPaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.none
    ..isAntiAlias = false;

  /// Palet resmi Echoes of Aether (GDD 14.2) + aksen bayangan/outline.
  static const Map<String, int> palette = {
    'g': 0xFF355B45, // Forest Green
    'd': 0xFF243D35, // Deep Forest
    'm': 0xFF71865A, // Moss Green
    'b': 0xFF795B43, // Earth Brown
    'n': 0xFF4F3A2A, // Dark Bark
    's': 0xFF777B79, // Ancient Stone
    't': 0xFF4E5250, // Dark Stone
    'a': 0xFF65BFE8, // Aether Blue
    'c': 0xFF2D7FA8, // Deep Aether
    'p': 0xFF9879CE, // Arcane Purple
    'v': 0xFF523A78, // Deep Arcane
    'y': 0xFFE6BD68, // Warm Gold
    'r': 0xFFD95D5D, // Health Red
    'w': 0xFFF4F7FA, // Highlight
    'l': 0xFFE2C7A8, // Skin / Bone
    'k': 0xFF161B22, // Outline
  };

  static const Map<String, int> _forestPalette = palette;

  static const Map<String, int> _cavernPalette = {
    '.': 0x00000000,
    'd': 0xFF0E1B24, // Deep Cave Slate
    'g': 0xFF162836, // Damp Cavern Stone
    'm': 0xFF1F3A4E, // Cobalt Stone
    's': 0xFF2C4E66, // Chiseled Slate
    't': 0xFF3E6D8F, // Cavern Ledge
    'n': 0xFF3A87B0, // Dark Crystal Facet
    'b': 0xFF69BFE5, // Aether Blue Crystal
    'p': 0xFF4A90E2, // Crystal Core
    'a': 0xFF9DE2FF, // Bright Crystal Cyan
    'y': 0xFFE6BD68, // Mineral Vein
    'r': 0xFFD95D5D, // Red
    'w': 0xFFFFFFFF, // Pure Spark Glint
    'l': 0xFFB4D4E8, // Pale Mineral
    'k': 0xFF0A121A, // Deep Cavern Outline
  };

  static const Map<String, int> _cryptPalette = {
    '.': 0x00000000,
    'd': 0xFF171322, // Dark Tomb Floor
    'g': 0xFF241E34, // Aged Sepulcher Stone
    'm': 0xFF362C4E, // Violet Slate
    's': 0xFF4E406D, // Chiseled Crypt Block
    't': 0xFF2A223B, // Dark Mausoleum Stone
    'n': 0xFF6C5491, // Arcane Shadow
    'b': 0xFFA88AD5, // Arcane Violet Rune
    'p': 0xFF7A58B0, // Crypt Violet
    'a': 0xFFCBB2F0, // Bright Ethereal Spark
    'y': 0xFFD4AF37, // Tarnished Relic Gold
    'r': 0xFF9E3A52, // Dried Crimson
    'w': 0xFFEFEBE9, // Bone Highlight
    'l': 0xFFD7CCC8, // Ancient Skull / Bone
    'k': 0xFF0E0B14, // Obsidian Crypt Outline
  };

  static const Map<String, int> _wastelandPalette = {
    '.': 0x00000000,
    'd': 0xFF1C1110, // Volcanic Ash Black
    'g': 0xFF2D1C1A, // Scorched Basalt
    'm': 0xFF442925, // Charred Rock Crust
    's': 0xFF5E3832, // Iron Basalt Stone
    't': 0xFF38201D, // Hardened Lava Shelf
    'n': 0xFF8C3B30, // Smoldering Crust
    'b': 0xFFD95D5D, // Molten Ember Red
    'p': 0xFF9E2A2B, // Deep Crimson
    'a': 0xFFE6683B, // Vibrant Magma Orange
    'y': 0xFFF5A623, // Molten Yellow Core
    'r': 0xFFD95D5D, // Fire Red
    'w': 0xFFFFF275, // White-Hot Magma Core
    'l': 0xFFCCA299, // Ash Dust
    'k': 0xFF120908, // Obsidian Crag Outline
  };

  static const Map<String, int> _sanctumPalette = {
    '.': 0x00000000,
    'd': 0xFF131926, // Celestial Navy Base
    'g': 0xFF1D2639, // Polished Sanctum Marble
    'm': 0xFF2B3852, // Lapis-veined Stone
    's': 0xFF3E5073, // Marble Bevel Edge
    't': 0xFF222E45, // Arch Shadow
    'n': 0xFF997A38, // Antique Bronze Accent
    'b': 0xFFE6BD68, // Antique Gold Inlay
    'p': 0xFF4A90E2, // Aether Energy Conduit
    'a': 0xFF7FD8FF, // Pure Aether Light
    'y': 0xFFF7DA8B, // Bright Gold Glint
    'r': 0xFFE57373, // Sacred Rose
    'w': 0xFFFFFFFF, // Celestial Spark
    'l': 0xFFD9E2EC, // Pure Marble Inlay
    'k': 0xFF0A0E17, // Temple Shadow Outline
  };

  /// Normalisasi ID biome ke kanonikal biome yang didukung.
  static String normalizeBiome(String? biome) {
    if (biome == null) return 'forgotten_forest';
    return switch (biome.trim().toLowerCase()) {
      'forgotten_forest' => 'forgotten_forest',
      'crystal_cavern' => 'crystal_cavern',
      'ancient_crypt' || 'abyssal_rift' => 'ancient_crypt',
      'ashen_wasteland' => 'ashen_wasteland',
      'aether_sanctum' || 'ascension_sanctum' => 'aether_sanctum',
      _ => 'forgotten_forest',
    };
  }

  /// Palet warna yang selaras dengan tema visual biome.
  static Map<String, int> paletteForBiome(String? biome) {
    return switch (normalizeBiome(biome)) {
      'crystal_cavern' => _cavernPalette,
      'ancient_crypt' => _cryptPalette,
      'ashen_wasteland' => _wastelandPalette,
      'aether_sanctum' => _sanctumPalette,
      _ => _forestPalette,
    };
  }

  final Map<String, ui.Image> _images = {};
  final Map<String, ui.Image> _characterImages = {};
  Future<void>? _preloadFuture;
  bool _disposed = false;

  /// Mengambil frame karakter PNG hasil ekstraksi jika sudah di-preload.
  ui.Image? characterFrameImage(String assetPath) =>
      _characterImages[assetPath];

  /// Memuat seluruh sprite frame karakter & portrait untuk 10 class ke memori GPU.
  Future<void> preloadCharacterAssets([AssetBundle? bundle]) {
    _disposed = false;
    return _preloadFuture ??= _doPreloadCharacterAssets(bundle ?? rootBundle);
  }

  Future<void> _doPreloadCharacterAssets(AssetBundle bundle) async {
    final paths = CharacterAssetCatalog.gameplaySpriteFramePaths;
    for (final path in paths) {
      if (_disposed) return;
      await loadCharacterFrame(path, bundle);
    }
  }

  /// Memuat satu file aset frame karakter secara aman; mengembalikan `null` jika hilang/gagal.
  Future<ui.Image?> loadCharacterFrame(
    String assetPath, [
    AssetBundle? bundle,
  ]) async {
    final existing = _characterImages[assetPath];
    if (existing != null) return existing;
    try {
      final data = await (bundle ?? rootBundle).load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (_disposed) {
        frame.image.dispose();
        return null;
      }
      final current = _characterImages[assetPath];
      if (current != null) {
        frame.image.dispose();
        return current;
      }
      _characterImages[assetPath] = frame.image;
      return frame.image;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PixelSpriteAtlas: gagal memuat aset "$assetPath": $e');
      }
      return null;
    }
  }

  /// Mengambil sprite combatant berdasarkan sequence & index animasi dengan fallback
  /// ke frame idle, portrait class, lalu 16x16 [combatantSprite].
  ui.Image combatantSequenceSprite({
    required bool isPlayer,
    String? specializationId,
    String? definitionId,
    String? spriteRef,
    required CharacterAnimationSequence sequence,
    required int frameIndex,
    required String fallbackPose,
  }) {
    if (isPlayer) {
      final manifest = CharacterAssetCatalog.forClass(
        specializationId ?? 'base',
      );
      final frames = manifest.framesForSequence(sequence);
      if (frames.isNotEmpty) {
        final primaryPath = manifest.frameFor(sequence, frameIndex);
        final direct = _characterImages[primaryPath];
        if (direct != null) return direct;
        for (final candidate in frames) {
          final img = _characterImages[candidate];
          if (img != null) return img;
        }
        final idleFrames = manifest.framesForSequence(
          CharacterAnimationSequence.idle,
        );
        for (final candidate in idleFrames) {
          final img = _characterImages[candidate];
          if (img != null) return img;
        }
        final portrait = _characterImages[manifest.portraitPath];
        if (portrait != null) return portrait;
      }
    }
    return combatantSprite(
      isPlayer: isPlayer,
      specializationId: specializationId,
      definitionId: definitionId,
      spriteRef: spriteRef,
      pose: fallbackPose,
    );
  }

  /// Memetakan sprite monster: memakai [spriteRef] bila tersedia (tidak kosong),
  /// fallback ke [definitionId], dan terakhir `enemy_generic` bila tidak dikenal.
  static String resolveEnemySpecies({String? spriteRef, String? definitionId}) {
    final normalizedRef = spriteRef?.trim();
    final key = (normalizedRef != null && normalizedRef.isNotEmpty)
        ? normalizedRef
        : definitionId;
    return _enemySpecies(key);
  }

  /// Mem-parse hex `#RRGGBB` / `#AARRGGBB` menjadi ARGB int (`null` jika invalid).
  static int? parseHexTintArgb(String? hex) {
    if (hex == null) return null;
    final trimmed = hex.trim();
    if (!trimmed.startsWith('#')) return null;
    final digits = trimmed.substring(1);
    if (digits.length == 6) {
      final rgb = int.tryParse(digits, radix: 16);
      return rgb == null ? null : (0xFF000000 | rgb);
    }
    if (digits.length == 8) {
      return int.tryParse(digits, radix: 16);
    }
    return null;
  }

  /// Mem-parse hex tint ke [ui.Color] (`null` jika invalid atau tidak diisi).
  static ui.Color? parseHexTintColor(String? hex) {
    final argb = parseHexTintArgb(hex);
    return argb == null ? null : ui.Color(argb);
  }

  /// Mengambil sprite karakter/monster yang di-cache.
  /// [key] berbentuk `<species>_<pose>` (mis. `hero_vanguard_walk1`,
  /// `aether_slime_idle0`).
  ui.Image combatantSprite({
    required bool isPlayer,
    String? specializationId,
    String? definitionId,
    String? spriteRef,
    required String pose,
  }) {
    final species = isPlayer
        ? _playerSpecies(specializationId)
        : resolveEnemySpecies(spriteRef: spriteRef, definitionId: definitionId);
    final cacheKey = '${species}_$pose';
    final cached = _images[cacheKey];
    if (cached != null) return cached;

    final frameData = PixelSpriteData.frames[cacheKey];
    if (frameData != null) {
      final img = _bakeFrame(frameData);
      _images[cacheKey] = img;
      return img;
    }

    final grid = _buildCombatantGrid(species: species, pose: pose);
    final img = _bakeGrid(grid, gridSize, gridSize);
    _images[cacheKey] = img;
    return img;
  }

  /// Mengambil tile (floor, wall, exit) ukuran 16x16 untuk [biome] yang diberikan.
  ui.Image tileSprite(String key, {String? biome}) {
    final effectiveBiome = normalizeBiome(biome);
    final cacheKey = key.startsWith('exit_')
        ? 'tile_$key'
        : (key == 'wall_tree'
              ? 'tile_forgotten_forest_wall'
              : (biome == null && (key.startsWith('floor') || key == 'wall')
                    ? 'tile_$key'
                    : 'tile_${effectiveBiome}_$key'));

    final cached = _images[cacheKey];
    if (cached != null) return cached;

    final resolvedKey = key == 'wall_tree' ? 'wall' : key;
    final grid = _buildTileGrid(resolvedKey, biome: effectiveBiome);
    final tilePalette = paletteForBiome(effectiveBiome);
    final img = _bakeGrid(grid, gridSize, gridSize, palette: tilePalette);
    _images[cacheKey] = img;
    return img;
  }

  void dispose() {
    _disposed = true;
    _preloadFuture = null;
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    for (final img in _characterImages.values) {
      img.dispose();
    }
    _characterImages.clear();
  }

  String _playerSpecies(String? specId) {
    switch (specId) {
      case 'vanguard':
        return 'hero_vanguard';
      case 'arcanist':
        return 'hero_arcanist';
      case 'ranger':
        return 'hero_ranger';
      case 'paladin':
        return 'hero_paladin';
      case 'voidblade':
        return 'hero_voidblade';
      case 'chronomancer':
        return 'hero_chronomancer';
      case 'gunslinger':
        return 'hero_gunslinger';
      case 'necromancer':
        return 'hero_necromancer';
      case 'stormcaller':
        return 'hero_stormcaller';
      default:
        return 'hero_base';
    }
  }

  static String _enemySpecies(String? definitionId) {
    switch (definitionId) {
      case 'aether_slime':
      case 'forest_slime':
        return 'aether_slime';
      case 'forest_wolf':
        return 'forest_wolf';
      case 'goblin':
        return 'goblin';
      case 'corrupted_treant':
        return 'corrupted_treant';
      case 'corrupted_guardian':
        return 'corrupted_guardian';
      case 'ancient_heart_guardian':
        return 'ancient_heart_guardian';
      case 'fire_skull':
        return 'fire_skull';
      case 'skelly':
        return 'skelly';
      case 'mummy':
        return 'mummy';
      case 'wraith':
        return 'wraith';
      case 'zombie':
        return 'zombie';
      case 'orc':
        return 'orc';
      default:
        return 'enemy_generic';
    }
  }

  ui.Image _bakeFrame(PixelSpriteFrame frame) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..isAntiAlias = false;
    final palette = frame.palette;
    final rows = frame.rows;

    for (var y = 0; y < gridSize && y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < gridSize && x < row.length; x++) {
        final code = row.codeUnitAt(x);
        if (code == 46) continue; // '.' (period) is transparent
        final index = code <= 57 ? code - 48 : code - 87;
        if (index >= 0 && index < palette.length) {
          paint.color = ui.Color(palette[index]);
          canvas.drawRect(
            ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
            paint,
          );
        }
      }
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(gridSize, gridSize);
    picture.dispose();
    return image;
  }

  ui.Image _bakeGrid(
    List<String> rows,
    int width,
    int height, {
    Map<String, int>? palette,
  }) {
    final activePalette = palette ?? _forestPalette;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..isAntiAlias = false;

    for (var y = 0; y < height && y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < width && x < row.length; x++) {
        final ch = row[x];
        if (ch == '.' || ch == ' ') continue;
        final argb = activePalette[ch];
        if (argb == null) continue;
        paint.color = ui.Color(argb);
        canvas.drawRect(
          ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
          paint,
        );
      }
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    return image;
  }

  List<String> _buildCombatantGrid({
    required String species,
    required String pose,
  }) {
    if (species.startsWith('hero_')) {
      return _heroGrid(species, pose);
    }
    switch (species) {
      case 'aether_slime':
        return _slimeGrid(pose);
      case 'forest_wolf':
        return _wolfGrid(pose);
      case 'corrupted_treant':
        return _treantGrid(pose);
      case 'corrupted_guardian':
        return _guardianGrid(pose);
      case 'ancient_heart_guardian':
        return _bossGrid(pose);
      default:
        return _genericEnemyGrid(pose);
    }
  }

  List<String> _heroGrid(String species, String pose) {
    // Palet per spesialisasi di-remap di atas kerangka ksatria top-down.
    final isVanguard = species == 'hero_vanguard';
    final isArcanist = species == 'hero_arcanist';
    final isRanger = species == 'hero_ranger';
    final isPaladin = species == 'hero_paladin';
    final isVoidblade = species == 'hero_voidblade';
    final isChronomancer = species == 'hero_chronomancer';
    final isGunslinger = species == 'hero_gunslinger';
    final isNecromancer = species == 'hero_necromancer';
    final isStormcaller = species == 'hero_stormcaller';

    final hood = isVanguard
        ? 's'
        : (isArcanist
              ? 'p'
              : (isRanger
                    ? 'g'
                    : (isPaladin
                          ? 'y'
                          : (isVoidblade
                                ? 'w'
                                : (isChronomancer
                                      ? 'a'
                                      : (isGunslinger
                                            ? 't'
                                            : (isNecromancer
                                                  ? 'v'
                                                  : (isStormcaller
                                                        ? 'w'
                                                        : 'c'))))))));

    final trim = isVanguard
        ? 'y'
        : (isArcanist
              ? 'a'
              : (isRanger
                    ? 'y'
                    : (isPaladin
                          ? 'w'
                          : (isVoidblade
                                ? 'p'
                                : (isChronomancer
                                      ? 'y'
                                      : (isGunslinger
                                            ? 'r'
                                            : (isNecromancer
                                                  ? 'm'
                                                  : (isStormcaller
                                                        ? 'y'
                                                        : 's'))))))));

    final body = isVanguard
        ? 's'
        : (isArcanist
              ? 'v'
              : (isRanger
                    ? 'd'
                    : (isPaladin
                          ? 'y'
                          : (isVoidblade
                                ? 'v'
                                : (isChronomancer
                                      ? 'c'
                                      : (isGunslinger
                                            ? 'b'
                                            : (isNecromancer
                                                  ? 'd'
                                                  : (isStormcaller
                                                        ? 'c'
                                                        : 'a'))))))));

    final weapon = isArcanist
        ? 'a'
        : (isRanger
              ? 'b'
              : (isPaladin
                    ? 'w'
                    : (isVoidblade
                          ? 'p'
                          : (isChronomancer
                                ? 'y'
                                : (isGunslinger
                                      ? 'a'
                                      : (isNecromancer
                                            ? 'l'
                                            : (isStormcaller ? 'a' : 'w')))))));

    if (pose == 'downed') {
      return [
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '...kkkkkk.......',
        '..k$hood$hood$hood$hood${trim}kkkk...',
        '.k$hood${hood}ll$body$body$trim$body${body}kk...',
        '.k$body$body$trim$body$body$trim$body${body}kkk...',
        '..kkkkkkkkkkkk..',
        '......kk..kk....',
        '................',
        '................',
        '................',
        '................',
      ];
    }

    final bob = pose == 'idle1' || pose == 'walk1';
    final attack = pose == 'attack';
    final leftFoot = pose == 'walk0' ? 'k' : '.';
    final rightFoot = pose == 'walk1' ? 'k' : '.';

    final topOffset = bob ? 1 : 0;
    final base = <String>[
      '.....kkkkkk.....',
      '....k$hood$hood$hood$hood$hood${hood}k....',
      '...k$hood$hood$hood$trim$trim$hood$hood${hood}k...',
      '...k${hood}kllllk${hood}k...',
      '...kkklkklkkk...',
      '....k$body$body$trim$trim$body${body}k....',
      attack
          ? '..k$body$body$body$trim$trim$body$weapon${weapon}wwwk'
          : '..k$body$body$body$trim$trim$body$body$body$weapon${weapon}k..',
      attack
          ? '..k$body$body$body$body$body$body$weapon${weapon}wwwk.'
          : '..k$body$body$body$body$body$body$body$body$weapon${weapon}k..',
      '...k$body$body$trim$trim$body$body$body${body}k...',
      '...kbbkkkkbbk...',
      '....k${leftFoot}b..b${rightFoot}k....',
      '....kk....kk....',
    ];

    final out = <String>[
      for (var i = 0; i < topOffset + 2; i++) '................',
      ...base,
    ];
    while (out.length < gridSize) {
      out.add('................');
    }
    return out.take(gridSize).toList(growable: false);
  }

  List<String> _slimeGrid(String pose) {
    if (pose == 'downed') {
      return [
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '....kkkkkkkk....',
        '..kkcaaaaaackk..',
        '.kccaaaaaaaaack.',
        '..kkkkkkkkkkkk..',
        '................',
        '................',
        '................',
      ];
    }
    final squat = pose == 'idle1' || pose == 'walk1';
    final attack = pose == 'attack';
    if (attack) {
      return [
        '................',
        '................',
        '................',
        '.....kkkkkk.....',
        '...kkaaaaaakk...',
        '..kawwaaaawwak..',
        '..kaaakaaakaaak.',
        '.kcaaaappppaaack',
        '.kcaaaaaaaaaaack',
        '..kccccccccccck.',
        '...kkkkkkkkkkk..',
        '................',
        '................',
        '................',
        '................',
        '................',
      ];
    }
    if (squat) {
      return [
        '................',
        '................',
        '................',
        '................',
        '................',
        '....kkkkkkkk....',
        '..kkaaaaaaaakk..',
        '.kcawwaaaawwack.',
        '.kcaakaaaakaack.',
        '.kccaappppaacck.',
        '..kccccccccckk..',
        '...kkkkkkkkkk...',
        '................',
        '................',
        '................',
        '................',
      ];
    }
    return [
      '................',
      '................',
      '................',
      '.....kkkkkk.....',
      '....kaaaaaak....',
      '...kawwaawwak...',
      '..kaaakaaakaaak.',
      '..kcaappppaaack.',
      '..kcaaaaaaaaack.',
      '..kccccccccccck.',
      '...kkkkkkkkkkk..',
      '................',
      '................',
      '................',
      '................',
      '................',
    ];
  }

  List<String> _wolfGrid(String pose) {
    if (pose == 'downed') {
      return [
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '................',
        '...kkkkkkkkk....',
        '..kbbbssbbbbk...',
        '.kbbsbbbbssbbk..',
        '..kkkkkkkkkkk...',
        '................',
        '................',
        '................',
        '................',
        '................',
      ];
    }
    final stride = pose == 'walk1';
    final attack = pose == 'attack';
    return [
      '................',
      '................',
      '..kk......kk....',
      '..kbk....kbk....',
      '..kbbkkkkbbk....',
      '..kbbbssbbbk....',
      '.kbbkrbbkrbbk...',
      '.kbbbbssbbbbk...',
      attack ? '..kbbwwwwwwbbk..' : '..kkkbbbbbbkkk..',
      '...kbbssssbbk...',
      '...kbbbbbbbbk...',
      stride ? '..kbk......kbk..' : '...kbk....kbk...',
      stride ? '..kkk......kkk..' : '...kkk....kkk...',
      '................',
      '................',
      '................',
    ];
  }

  List<String> _treantGrid(String pose) {
    final sway = pose == 'idle1' || pose == 'walk1';
    final attack = pose == 'attack';
    final eye = attack ? 'p' : 'r';
    return [
      '....kkkkkkkk....',
      '...kmgmmmmgmk...',
      '..kmggmmmmggmk..',
      '..kmggggggggmk..',
      '...kknnbbnnkk...',
      '..knnbnnnnbbnk..',
      '..knb${eye}nnnn${eye}bnk..',
      '..knnnnnnnnnnk..',
      sway ? '.kknnbppppbnnkk.' : '..knnbppppbnnk..',
      '..knnbbbbbbnnk..',
      '...knnnnnnnnk...',
      '...knbn..nbnk...',
      '...knk....knk...',
      '...kkk....kkk...',
      '................',
      '................',
    ];
  }

  List<String> _guardianGrid(String pose) {
    final glow = pose == 'attack' ? 'w' : 'y';
    final pulse = pose == 'idle1' || pose == 'walk1';
    return [
      '....kkkkkkkk....',
      '...kssyyyyssk...',
      '..kssttttttsk...',
      '..kstrrssrrtsk..',
      '..kstttpppttsk..',
      '.ksssstttssssk..',
      '.ks${glow}stsssssts${glow}k.',
      '.kssstppppstssk.',
      '.ksssttttttstsk.',
      '..ksssstttsssk..',
      '..ktttsssssttk..',
      pulse ? '..kttk....kttk..' : '...ktk....ktk...',
      pulse ? '..kkkk....kkkk..' : '...kkk....kkk...',
      '................',
      '................',
      '................',
    ];
  }

  List<String> _bossGrid(String pose) {
    final attack = pose == 'attack';
    final pulse = pose == 'idle1' || pose == 'walk1';
    final eye = attack ? 'w' : 'a';
    final core = pulse ? 'w' : 'p';
    return [
      '..kk..kkkk..kk..',
      '.kppkkppppkkppk.',
      '.kpvksvvvvskvpk.',
      '..kkssvvvvsskk..',
      '..ksttpppppttsk.',
      '.kss${eye}tpppppt${eye}ssk',
      '.kssstvvvvvtsssk',
      'kysvvv${core}pp${core}vvvsryk',
      'kssvvvp$core${core}pvvvssk.',
      '.ksssvvvvvvsssk.',
      '.kttsssvvvsssttk',
      '..ktttssssstttk.',
      '..ktvk....kvtk..',
      '.kttvk....kvttk.',
      '.kkkkk....kkkkk.',
      '................',
    ];
  }

  List<String> _genericEnemyGrid(String pose) {
    final bob = pose == 'idle1' || pose == 'walk1';
    return [
      '................',
      '................',
      if (bob) '................',
      '....kkkkkkkk....',
      '...krrrrrrrrk...',
      '..krrwrrrrwrrk..',
      '..krrkrrrrkrrk..',
      '..krrrrrrrrrrk..',
      '...krrssssrrk...',
      '...krrrrrrrrk...',
      '....krr..rrk....',
      '....kkk..kkk....',
      if (!bob) '................',
      '................',
      '................',
      '................',
    ];
  }

  List<String> _buildTileGrid(String key, {String biome = 'forgotten_forest'}) {
    if (key == 'exit_locked') {
      return const [
        '................',
        '....kkkkkkkk....',
        '...kssssssssk...',
        '..ksyyyyyyyysk..',
        '..ksyttttttyyk..',
        '..ksytddddtysk..',
        '..ksytdyydtysk..',
        '..ksytddddtysk..',
        '..ksyttttttyyk..',
        '...kssssssssk...',
        '....kkkkkkkk....',
        '................',
        '................',
        '................',
        '................',
        '................',
      ];
    }
    if (key == 'exit_unlocked') {
      return const [
        '................',
        '....kkkkkkkk....',
        '...kssssssssk...',
        '..ksaaaaaaaask..',
        '..ksacwwwwcask..',
        '..ksacwaaacask..',
        '..ksawawwawask..',
        '..ksacwaaacask..',
        '..ksacwwwwcask..',
        '...kssssssssk...',
        '....kkkkkkkk....',
        '................',
        '................',
        '................',
        '................',
        '................',
      ];
    }

    final normalized = normalizeBiome(biome);
    return switch (normalized) {
      'crystal_cavern' => _buildCavernTile(key),
      'ancient_crypt' => _buildCryptTile(key),
      'ashen_wasteland' => _buildWastelandTile(key),
      'aether_sanctum' => _buildSanctumTile(key),
      _ => _buildForestTile(key),
    };
  }

  List<String> _buildForestTile(String key) {
    switch (key) {
      case 'floor0':
        return const [
          'dddddddddddddddd',
          'dddddddddddddddd',
          'ddddgddddddgdddd',
          'dddddddddddddddd',
          'dddddddddddddddd',
          'ddgddddddddddgdd',
          'dddddddddddddddd',
          'dddddddddddddddd',
          'ddddddgddddddddd',
          'dddddddddddddddd',
          'dddddddddddddddd',
          'ddddgddddddgdddd',
          'dddddddddddddddd',
          'dddddddddddddddd',
          'ddgddddddddddddg',
          'dddddddddddddddd',
        ];
      case 'floor1':
        return const [
          'dddddddddddddddd',
          'ddddgmmgdddddddd',
          'dddgmmmmgddddddd',
          'ddddgmmgdddddddd',
          'dddddddddddddddd',
          'ddddddddddgmmgdd',
          'dddddddddgmmmmgd',
          'ddddddddddgmmgdd',
          'dddddddddddddddd',
          'ddgmmgdddddddddd',
          'dgmmmmgddddddddd',
          'ddgmmgddddddssdd',
          'dddddddddddddddd',
          'dddddddddddddddd',
          'ddddddgmmgdddddd',
          'dddddddddddddddd',
        ];
      case 'floor2':
        return const [
          'dddddddddddddddd',
          'ddnddddddddddddd',
          'ddnbddddddssdddd',
          'dddnbbdddddddddd',
          'ddddnbbddddddddd',
          'dddddnnbddddgddd',
          'ddddddnbbddddddd',
          'dddddddnbbdddddd',
          'ddddddddnnbddddd',
          'ddgddddddnbbdddd',
          'ddddddddddnbbddd',
          'ddddssdddddnnbdd',
          'ddddddddddddnbbd',
          'dddddddddddddnbd',
          'ddddddddddddddnd',
          'dddddddddddddddd',
        ];
      case 'wall':
      case 'wall_tree':
      default:
        return const [
          'kkkkkkkkkkkkkkkk',
          'kdddggggggggdddk',
          'kddggmmggmmggddk',
          'kdggmmggggmmggdk',
          'kdgmmmmggmmmmgdk',
          'kdggggggggggggdk',
          'kddggddggddggddk',
          'kddddddddddddddk',
          'knnbbnnbbnnbbnnk',
          'knbbbbnnnnbbbbnk',
          'knnbnnbbbbnnbnnk',
          'kssssssssssssssk',
          'ksttttttttttttsk',
          'kkkkkkkkkkkkkkkk',
          'kttttttttttttttk',
          'kkkkkkkkkkkkkkkk',
        ];
    }
  }

  List<String> _buildCavernTile(String key) {
    switch (key) {
      case 'floor0':
        return const [
          'dddddddddddddddd',
          'dggggddddddggggd',
          'dgssgddddddgssgd',
          'dggggddddddggggd',
          'dddddddddddddddd',
          'ddddddggggdddddd',
          'ddddddgssgdddddd',
          'ddddddggggdddddd',
          'dddddddddddddddd',
          'dggggddddddggggd',
          'dgssgddddddgssgd',
          'dggggddddddggggd',
          'dddddddddddddddd',
          'ddddddggggdddddd',
          'ddddddgssgdddddd',
          'ddddddggggdddddd',
        ];
      case 'floor1':
        return const [
          'dddddddddddddddd',
          'dggggddddddggggd',
          'dgssgddddbbgssgd',
          'dggggdddbaaggggd',
          'dddddddddbwddddd',
          'ddddddggggdddddd',
          'ddddddgssgdddddd',
          'ddddddggggdddddd',
          'dddddddddddddddd',
          'dggggddddddggggd',
          'dgssgdbbdssgssgd',
          'dggggbaadddggggd',
          'dddddbwddddddddd',
          'ddddddggggdddddd',
          'ddddddgssgdddddd',
          'ddddddggggdddddd',
        ];
      case 'floor2':
        return const [
          'dddddddddddddddd',
          'dggggddddddggggd',
          'dgssgddddddgssgd',
          'dggggddddddggggd',
          'ddddddddaddddddd',
          'dddddddaawdddddd',
          'ddddddbaawbddddd',
          'dddddbbaabbddddd',
          'ddddbbbaabbbdddd',
          'ddddddbbbbdddddd',
          'dgssgddbbddgssgd',
          'dggggddddddggggd',
          'dddddddddddddddd',
          'ddddddggggdddddd',
          'ddddddgssgdddddd',
          'ddddddggggdddddd',
        ];
      case 'wall':
      default:
        return const [
          'kkkkkkkkkkkkkkkk',
          'kddggmssssmggddk',
          'kdgmsssttsmggddk',
          'kgmssttaawtsmgdk',
          'kgmsttaawwtsmgdk',
          'kddgssbaawtsgddk',
          'kddgssbbawtsgddk',
          'kdggmsttttsmggdk',
          'kdgmssssssssmgdk',
          'kgmsttaatttsmgdk',
          'kgmsbaawwttsmgdk',
          'kddgssbaawtsgddk',
          'kddddgsssstggddk',
          'kdggmssssssmggdk',
          'kggmmttttttmmggk',
          'kkkkkkkkkkkkkkkk',
        ];
    }
  }

  List<String> _buildCryptTile(String key) {
    switch (key) {
      case 'floor0':
        return const [
          'dddddddddddddddd',
          'dggggdmmmmdggggd',
          'dgssgdmsmmdgssgd',
          'dggggdmmmmdggggd',
          'dddddddddddddddd',
          'dmmmmdggggdmmmmd',
          'dmsmmdgssgdmsmmd',
          'dmmmmdggggdmmmmd',
          'dddddddddddddddd',
          'dggggdmmmmdggggd',
          'dgssgdmsmmdgssgd',
          'dggggdmmmmdggggd',
          'dddddddddddddddd',
          'dmmmmdggggdmmmmd',
          'dmsmmdgssgdmsmmd',
          'dmmmmdggggdmmmmd',
        ];
      case 'floor1':
        return const [
          'dddddddddddddddd',
          'dggggdmmmmdggggd',
          'dgssgdmsmmdgssgd',
          'dggggdbbbbdggggd',
          'ddddddbaabdddddd',
          'dmmmmdbbbbdmmmmd',
          'dmsmmdgssgdmsmmd',
          'dmmmmdggggdmmmmd',
          'dddddddddddddddd',
          'dggggdmmmmdggggd',
          'dgssgdmsmmdgssgd',
          'dggggdbbbbdggggd',
          'ddddddbaabdddddd',
          'dmmmmdbbbbdmmmmd',
          'dmsmmdgssgdmsmmd',
          'dmmmmdggggdmmmmd',
        ];
      case 'floor2':
        return const [
          'dddddddddddddddd',
          'dggggdmmmmdggggd',
          'dgssgddddddgssgd',
          'dggggdwwwwdggggd',
          'dddddwllwwdddddd',
          'dmmmmwlkllwmmmmd',
          'dmsmmwllklwmsmmd',
          'dmmmmdwllwddmmmmd',
          'ddddddwkwddddddd',
          'dggggdmmmmdggggd',
          'dgssgdmsmmdgssgd',
          'dggggdmmmmdggggd',
          'dddddddddddddddd',
          'dmmmmdggggdmmmmd',
          'dmsmmdgssgdmsmmd',
          'dmmmmdggggdmmmmd',
        ];
      case 'wall':
      default:
        return const [
          'kkkkkkkkkkkkkkkk',
          'kddggmssssmggddk',
          'kdgmsssssssmgddk',
          'kgmsssttttsmgddk',
          'kgmsstbbttsmgddk',
          'kgmsstbaatsmgddk',
          'kgmstbaawatsmgdk',
          'kgmstbaawatsmgdk',
          'kgmsstbaatsmgddk',
          'kgmsstbbttsmgddk',
          'kdgmsssssssmgddk',
          'kddgsssttssgdddk',
          'kddddwllwwdddddk',
          'kdggmwlkllwmggdk',
          'kggmmdwllwddmmggk',
          'kkkkkkkkkkkkkkkk',
        ];
    }
  }

  List<String> _buildWastelandTile(String key) {
    switch (key) {
      case 'floor0':
        return const [
          'dddddddddddddddd',
          'dggggddddddggggd',
          'dgssgddddddgssgd',
          'dggggddddddggggd',
          'dddddddddddddddd',
          'ddddddggggdddddd',
          'ddddddgssgdddddd',
          'ddddddggggdddddd',
          'dddddddddddddddd',
          'dggggddddddggggd',
          'dgssgddddddgssgd',
          'dggggddddddggggd',
          'dddddddddddddddd',
          'ddddddggggdddddd',
          'ddddddgssgdddddd',
          'ddddddggggdddddd',
        ];
      case 'floor1':
        return const [
          'dddddddddddddddd',
          'dggggddddbbggggd',
          'dgssgddddbaygggd',
          'dggggddddbbggggd',
          'dddddddddddddddd',
          'ddbbddggggdddddd',
          'dbayddgssgdddddd',
          'ddbbddggggdddddd',
          'dddddddddddddddd',
          'dggggddddddggggd',
          'dgssgddddbbgssgd',
          'dggggddddbaygggd',
          'dddddddddbbddddd',
          'ddddddggggdddddd',
          'ddddddgssgdddddd',
          'ddddddggggdddddd',
        ];
      case 'floor2':
        return const [
          'dddddddddddddddd',
          'dggggddddddggggd',
          'dgssgddbbddgssgd',
          'dggggdbaaddggggd',
          'dddddaywaddddddd',
          'dddddaywaddddddd',
          'dddddbaaddggggdd',
          'ddddddbbddgssgdd',
          'ddddddddddggggdd',
          'dggggddddddddddd',
          'dgssgddbbddddddd',
          'dggggdbaaddggggd',
          'dddddaywaddddddd',
          'dddddaywaddggggd',
          'dddddbbaadgssgd',
          'ddddddbbddggggdd',
        ];
      case 'wall':
      default:
        return const [
          'kkkkkkkkkkkkkkkk',
          'kddggmssssmggddk',
          'kdgmsssssssmgddk',
          'kgmstttttttsmgdk',
          'kgmsttbbtttsmgdk',
          'kgmstbaatttsmgdk',
          'kgmstbayattsmgdk',
          'kgmstbawyattsmgk',
          'kgmstbayattsmgdk',
          'kgmstbaatttsmgdk',
          'kgmsttbbtttsmgdk',
          'kdgmsssssssmgddk',
          'kddgsssttssgdddk',
          'kdggmsttttsmggdk',
          'kggmmttttttmmggk',
          'kkkkkkkkkkkkkkkk',
        ];
    }
  }

  List<String> _buildSanctumTile(String key) {
    switch (key) {
      case 'floor0':
        return const [
          'dddddddddddddddd',
          'dggggggggggggggd',
          'dgmmmmmmmmmmmmgd',
          'dgmssssssssssmgd',
          'dgmssssssssssmgd',
          'dgmssddddddssmgd',
          'dgmssdggggdssmgd',
          'dgmssdggggdssmgd',
          'dgmssdggggdssmgd',
          'dgmssdggggdssmgd',
          'dgmssddddddssmgd',
          'dgmssssssssssmgd',
          'dgmssssssssssmgd',
          'dgmmmmmmmmmmmmgd',
          'dggggggggggggggd',
          'dddddddddddddddd',
        ];
      case 'floor1':
        return const [
          'dddddddddddddddd',
          'dybbggggggggbbyd',
          'dbymmmmmmmmmmybd',
          'dgmssssssssssmgd',
          'dgmssssssssssmgd',
          'dgmssddddddssmgd',
          'dgmssdggggdssmgd',
          'dgmssdggggdssmgd',
          'dgmssdggggdssmgd',
          'dgmssdggggdssmgd',
          'dgmssddddddssmgd',
          'dgmssssssssssmgd',
          'dgmssssssssssmgd',
          'dbymmmmmmmmmmybd',
          'dybbggggggggbbyd',
          'dddddddddddddddd',
        ];
      case 'floor2':
        return const [
          'dddddddddddddddd',
          'dybbggggggggbbyd',
          'dbymmmbaabmmmybd',
          'dgmssbaawabbssmd',
          'dgmssbaawabbssmd',
          'dgmssddbbddssmgd',
          'dgbaadaaaaadaabd',
          'dgwaaddawwaddawd',
          'dgwaaddawwaddawd',
          'dgbaadaaaaadaabd',
          'dgmssddbbddssmgd',
          'dgmssbaawabbssmd',
          'dgmssbaawabbssmd',
          'dbymmmbaabmmmybd',
          'dybbggggggggbbyd',
          'dddddddddddddddd',
        ];
      case 'wall':
      default:
        return const [
          'kkkkkkkkkkkkkkkk',
          'kddggmssssmggddk',
          'kdgybbbbbbbbygdk',
          'kdybbmmmmmmbbydk',
          'kdgmsttttttsmgdk',
          'kdgmstpaaptssmgk',
          'kdgmstpaaptssmgk',
          'kdgmstpaaptssmgk',
          'kdgmstpaaptssmgk',
          'kdgmstpaaptssmgk',
          'kdgmstpaaptssmgk',
          'kdybbmmmmmmbbydk',
          'kdgybbbbbbbbygdk',
          'kdggmssssssmggdk',
          'kggmmttttttmmggk',
          'kkkkkkkkkkkkkkkk',
        ];
    }
  }
}
