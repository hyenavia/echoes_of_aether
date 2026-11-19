import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/cloud/firebase_bootstrap.dart';
import 'game/visuals/environment_tileset.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(FirebaseBootstrap.instance.initialize());
  unawaited(EnvironmentTilesetRegistry.instance.loadCuratedAssetPacks());
  runApp(const ProviderScope(child: EchoesApp()));
}
