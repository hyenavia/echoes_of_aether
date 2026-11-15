import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers/notification_provider.dart';
import '../features/dungeon/dungeon_screen.dart';
import 'theme/echoes_theme.dart';

class EchoesApp extends ConsumerWidget {
  const EchoesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLifecycleNotificationObserverProvider);
    return MaterialApp(
      title: 'Echoes of Aether',
      debugShowCheckedModeBanner: false,
      theme: EchoesTheme.dark(),
      home: const DungeonScreen(),
    );
  }
}
