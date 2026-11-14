import 'dart:ui' as ui;

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

  final Map<String, ui.Image> _images = {};

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

    final grid = _buildCombatantGrid(species: species, pose: pose);
    final img = _bakeGrid(grid, gridSize, gridSize);
    _images[cacheKey] = img;
    return img;
  }

  /// Mengambil tile Forgotten Forest (floor, wall, exit) ukuran 16x16.
  ui.Image tileSprite(String key) {
    final cached = _images['tile_$key'];
    if (cached != null) return cached;
    final grid = _buildTileGrid(key);
    final img = _bakeGrid(grid, gridSize, gridSize);
    _images['tile_$key'] = img;
    return img;
  }

  void dispose() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
  }

  String _playerSpecies(String? specId) {
    switch (specId) {
      case 'vanguard':
        return 'hero_vanguard';
      case 'arcanist':
        return 'hero_arcanist';
      case 'ranger':
        return 'hero_ranger';
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
      case 'corrupted_treant':
        return 'corrupted_treant';
      case 'corrupted_guardian':
        return 'corrupted_guardian';
      case 'ancient_heart_guardian':
        return 'ancient_heart_guardian';
      default:
        return 'enemy_generic';
    }
  }

  ui.Image _bakeGrid(List<String> rows, int width, int height) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..isAntiAlias = false;

    for (var y = 0; y < height && y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < width && x < row.length; x++) {
        final ch = row[x];
        if (ch == '.' || ch == ' ') continue;
        final argb = palette[ch];
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

    final hood = isVanguard ? 's' : (isArcanist ? 'p' : (isRanger ? 'g' : 'c'));
    final trim = isVanguard ? 'y' : (isArcanist ? 'a' : (isRanger ? 'y' : 's'));
    final body = isVanguard ? 's' : (isArcanist ? 'v' : (isRanger ? 'd' : 'a'));
    final weapon = isArcanist ? 'a' : (isRanger ? 'b' : 'w');

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

  List<String> _buildTileGrid(String key) {
    switch (key) {
      case 'floor0':
        return List.generate(16, (y) {
          if (y == 3 || y == 11) return 'dddddddddddddddd';
          return 'ddddgddddddgdddd';
        });
      case 'floor1':
        return List.generate(16, (y) {
          if (y == 5 || y == 12) return 'dddgdmdddddgdddd';
          return 'ddddddddgddddddd';
        });
      case 'floor2':
        return List.generate(16, (y) {
          if (y == 2 || y == 8) return 'ddgddmdddddmdddd';
          if (y == 14) return 'ddddddssdddddddd';
          return 'ddddgddddddddddd';
        });
      case 'wall_tree':
        return [
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
      case 'exit_locked':
        return [
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
      case 'exit_unlocked':
        return [
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
      default:
        return List.filled(16, 'dddddddddddddddd');
    }
  }
}
