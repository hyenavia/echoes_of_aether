import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/providers/notification_provider.dart';
import '../features/dungeon/dungeon_screen.dart';
import '../features/shared/widgets/branding/aether_splash_screen.dart';
import '../features/shared/widgets/perf_frame_overlay.dart';
import 'theme/echoes_theme.dart';

class EchoesApp extends ConsumerStatefulWidget {
  const EchoesApp({super.key, this.showSplash = true});

  final bool showSplash;

  @override
  ConsumerState<EchoesApp> createState() => _EchoesAppState();
}

class _EchoesAppState extends ConsumerState<EchoesApp> {
  late bool _splashFinished = !widget.showSplash;

  @override
  Widget build(BuildContext context) {
    ref.watch(appLifecycleNotificationObserverProvider);
    return MaterialApp(
      title: 'Echoes of Aether',
      debugShowCheckedModeBanner: false,
      theme: EchoesTheme.dark(),
      builder: (context, child) =>
          PerfFrameOverlay(child: child ?? const SizedBox.shrink()),
      home: _splashFinished
          ? const DungeonScreen()
          : AetherSplashScreen(
              onComplete: () {
                if (mounted) {
                  setState(() => _splashFinished = true);
                }
              },
            ),
    );
  }
}
