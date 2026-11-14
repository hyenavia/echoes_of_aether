import 'package:flutter/material.dart';

import '../features/dungeon/dungeon_screen.dart';
import 'theme/echoes_theme.dart';

class EchoesApp extends StatelessWidget {
  const EchoesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Echoes of Aether',
      debugShowCheckedModeBanner: false,
      theme: EchoesTheme.dark(),
      home: const DungeonScreen(),
    );
  }
}
