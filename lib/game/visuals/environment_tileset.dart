import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/perf/perf_tracer.dart';
import 'pixel_sprite_atlas.dart';

/// Konfigurasi tileset lingkungan berbasis gambar untuk satu biome.
class EnvironmentTilesetConfig {
  const EnvironmentTilesetConfig({
    required this.biomeId,
    required this.name,
    required this.sourcePack,
    required this.floor0,
    required this.floor1,
    required this.floor2,
    required this.wall,
    this.wallTop,
    this.wallFace,
    this.decorPillar,
    this.exitSprite,
  });

  final String biomeId;
  final String name;
  final String sourcePack; // 'fantasy_dreamland' | 'mines_caves' | 'procedural'
  final ui.Image floor0;
  final ui.Image floor1;
  final ui.Image floor2;
  final ui.Image wall;
  final ui.Image? wallTop;
  final ui.Image? wallFace;
  final ui.Image? decorPillar;
  final ui.Image? exitSprite;

  void dispose() {
    floor0.dispose();
    floor1.dispose();
    floor2.dispose();
    wall.dispose();
    wallTop?.dispose();
    wallFace?.dispose();
    decorPillar?.dispose();
    exitSprite?.dispose();
  }
}

/// Registry singleton terpusat untuk mengelola tileset lingkungan eksternal.
///
/// Jika registry dinonaktifkan (`enabled = false`) atau belum memuat aset untuk
/// biome tertentu, sistem rendering visual otomatis fallback ke procedural
/// [PixelSpriteAtlas], menjaga kompatibilitas penuh dan kemampuan kembali ke
/// tampilan dungeon sebelumnya tanpa merusak gameplay state.
class EnvironmentTilesetRegistry {
  EnvironmentTilesetRegistry._();

  static final EnvironmentTilesetRegistry instance =
      EnvironmentTilesetRegistry._();

  /// Saklar toggle untuk mengaktifkan/menonaktifkan tileset eksternal secara global.
  bool enabled = true;

  final Map<String, EnvironmentTilesetConfig> _tilesets = {};

  bool get isLoaded => _tilesets.isNotEmpty;

  void register(EnvironmentTilesetConfig config) {
    final existing = _tilesets[config.biomeId];
    if (existing != null && !identical(existing, config)) {
      existing.dispose();
    }
    _tilesets[config.biomeId] = config;
  }

  EnvironmentTilesetConfig? get(String biomeId) {
    final normalized = PixelSpriteAtlas.normalizeBiome(biomeId);
    return _tilesets[normalized];
  }

  bool hasTileset(String biomeId) {
    final normalized = PixelSpriteAtlas.normalizeBiome(biomeId);
    return _tilesets.containsKey(normalized);
  }

  void unregister(String biomeId) {
    final normalized = PixelSpriteAtlas.normalizeBiome(biomeId);
    final removed = _tilesets.remove(normalized);
    if (removed == null) return;

    // Kumpulkan semua image yang masih dipakai oleh biome lain agar tidak dispose ganda.
    final stillUsed = <ui.Image>{};
    for (final config in _tilesets.values) {
      stillUsed.add(config.floor0);
      stillUsed.add(config.floor1);
      stillUsed.add(config.floor2);
      stillUsed.add(config.wall);
      if (config.wallTop != null) stillUsed.add(config.wallTop!);
      if (config.wallFace != null) stillUsed.add(config.wallFace!);
      if (config.decorPillar != null) stillUsed.add(config.decorPillar!);
      if (config.exitSprite != null) stillUsed.add(config.exitSprite!);
    }

    for (final img in [
      removed.floor0,
      removed.floor1,
      removed.floor2,
      removed.wall,
      removed.wallTop,
      removed.wallFace,
      removed.decorPillar,
      removed.exitSprite,
    ]) {
      if (img != null && !stillUsed.contains(img)) {
        img.dispose();
      }
    }
  }

  void clear() {
    final images = <ui.Image>{};
    for (final config in _tilesets.values) {
      images.add(config.floor0);
      images.add(config.floor1);
      images.add(config.floor2);
      images.add(config.wall);
      if (config.wallTop != null) images.add(config.wallTop!);
      if (config.wallFace != null) images.add(config.wallFace!);
      if (config.decorPillar != null) images.add(config.decorPillar!);
      if (config.exitSprite != null) images.add(config.exitSprite!);
    }
    for (final img in images) {
      img.dispose();
    }
    _tilesets.clear();
  }

  /// Mengambil sprite tile eksternal jika tersedia dan aktif.
  /// Mengembalikan `null` jika tidak ditemukan atau [enabled] false.
  ui.Image? tileSprite(String key, {required String biome}) {
    if (!enabled) return null;

    final config = get(biome);
    if (config == null) return null;

    return switch (key) {
      'floor0' => config.floor0,
      'floor1' => config.floor1,
      'floor2' => config.floor2,
      'wall' || 'wall_tree' => config.wall,
      'wall_top' => config.wallTop ?? config.wall,
      'wall_face' => config.wallFace ?? config.wall,
      'decor_pillar' => config.decorPillar,
      'exit' || 'exit_locked' || 'exit_unlocked' => config.exitSprite,
      _ => null,
    };
  }

  /// Helper untuk membuat tile 16x16 warna solid untuk keperluan pengujian.
  static ui.Image bakeSolidColorTile(
    int argb, {
    int width = 16,
    int height = 16,
  }) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..color = ui.Color(argb)
      ..isAntiAlias = false;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    final img = picture.toImageSync(width, height);
    picture.dispose();
    return img;
  }

  /// Memuat aset PNG kurasi dari asset bundle ke dalam registry.
  Future<bool> loadCuratedAssetPacks({AssetBundle? bundle}) =>
      PerfTracer.traceAsync('Startup.loadCuratedAssetPacks', () async {
        final effectiveBundle = bundle ?? rootBundle;

        try {
          const paths = [
            // 0..7: Fantasy Dreamland (Forgotten Forest)
            'assets/environment/fantasy_dreamland/floor_stone_0.png',
            'assets/environment/fantasy_dreamland/floor_stone_1.png',
            'assets/environment/fantasy_dreamland/floor_stone_2.png',
            'assets/environment/fantasy_dreamland/wall_stone.png',
            'assets/environment/fantasy_dreamland/wall_stone_top.png',
            'assets/environment/fantasy_dreamland/wall_stone_face.png',
            'assets/environment/fantasy_dreamland/decor_pillar.png',
            'assets/environment/fantasy_dreamland/exit_arch.png',
            // 8..14: Mines & Caves (Crystal Cavern)
            'assets/environment/mines_caves/floor_crystal_0.png',
            'assets/environment/mines_caves/floor_crystal_1.png',
            'assets/environment/mines_caves/floor_crystal_2.png',
            'assets/environment/mines_caves/wall_crystal.png',
            'assets/environment/mines_caves/wall_crystal_top.png',
            'assets/environment/mines_caves/stalagmite_crystal.png',
            'assets/environment/mines_caves/exit_cave_stairs.png',
            // 15..19: Ancient Crypt
            'assets/environment/fantasy_dreamland/floor_crypt_0.png',
            'assets/environment/fantasy_dreamland/floor_crypt_1.png',
            'assets/environment/fantasy_dreamland/floor_crypt_2.png',
            'assets/environment/fantasy_dreamland/wall_crypt.png',
            'assets/environment/fantasy_dreamland/wall_crypt_top.png',
            // 20..25: Ashen Wasteland
            'assets/environment/mines_caves/floor_magma_0.png',
            'assets/environment/mines_caves/floor_magma_1.png',
            'assets/environment/mines_caves/floor_magma_2.png',
            'assets/environment/mines_caves/wall_magma.png',
            'assets/environment/mines_caves/wall_magma_top.png',
            'assets/environment/mines_caves/stalagmite_magma.png',
            // 26..30: Aether Sanctum
            'assets/environment/mines_caves/floor_sanctum_0.png',
            'assets/environment/mines_caves/floor_sanctum_1.png',
            'assets/environment/mines_caves/floor_sanctum_2.png',
            'assets/environment/mines_caves/wall_sanctum.png',
            'assets/environment/mines_caves/wall_sanctum_top.png',
          ];

          final imgs = await Future.wait([
            for (final p in paths) _loadUiImage(effectiveBundle, p),
          ]);

          register(
            EnvironmentTilesetConfig(
              biomeId: 'forgotten_forest',
              name: 'Fantasy Dreamland Dungeon',
              sourcePack: 'fantasy_dreamland',
              floor0: imgs[0],
              floor1: imgs[1],
              floor2: imgs[2],
              wall: imgs[3],
              wallTop: imgs[4],
              wallFace: imgs[5],
              decorPillar: imgs[6],
              exitSprite: imgs[7],
            ),
          );

          register(
            EnvironmentTilesetConfig(
              biomeId: 'crystal_cavern',
              name: 'Mines & Caves Crystal Cavern',
              sourcePack: 'mines_caves',
              floor0: imgs[8],
              floor1: imgs[9],
              floor2: imgs[10],
              wall: imgs[11],
              wallTop: imgs[12],
              decorPillar: imgs[13],
              exitSprite: imgs[14],
            ),
          );

          register(
            EnvironmentTilesetConfig(
              biomeId: 'ancient_crypt',
              name: 'Fantasy Dreamland Crypt',
              sourcePack: 'fantasy_dreamland',
              floor0: imgs[15],
              floor1: imgs[16],
              floor2: imgs[17],
              wall: imgs[18],
              wallTop: imgs[19],
              decorPillar: imgs[6],
              exitSprite: imgs[7],
            ),
          );

          register(
            EnvironmentTilesetConfig(
              biomeId: 'ashen_wasteland',
              name: 'Mines & Caves Magma Depths',
              sourcePack: 'mines_caves',
              floor0: imgs[20],
              floor1: imgs[21],
              floor2: imgs[22],
              wall: imgs[23],
              wallTop: imgs[24],
              decorPillar: imgs[25],
              exitSprite: imgs[14],
            ),
          );

          register(
            EnvironmentTilesetConfig(
              biomeId: 'aether_sanctum',
              name: 'Aether Sanctum Temple',
              sourcePack: 'hybrid_mines_caves_sanctum',
              floor0: imgs[26],
              floor1: imgs[27],
              floor2: imgs[28],
              wall: imgs[29],
              wallTop: imgs[30],
              decorPillar: imgs[6],
              exitSprite: imgs[7],
            ),
          );

          return true;
        } catch (e, st) {
          debugPrint(
            'EnvironmentTilesetRegistry: Asset loading skipped/failed ($e)',
          );
          debugPrint('$st');
          return false;
        }
      });

  static Future<ui.Image> _loadUiImage(
    AssetBundle bundle,
    String assetPath,
  ) async {
    final byteData = await bundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }
}
