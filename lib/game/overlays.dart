/// Nama overlay Flutter yang ditampilkan di atas game Flame.
class GameOverlays {
  GameOverlays._();

  static const String hud = 'hud';
  static const String menuButtons = 'menuButtons';
  static const String inventory = 'inventory';
  static const String equipment = 'equipment';
  static const String character = 'character';
  static const String settings = 'settings';
  static const String shop = 'shop';
  static const String blacksmith = 'blacksmith';
  static const String altar = 'altar';
  static const String runEnded = 'runEnded';
  static const String dungeonCompleted = 'dungeonCompleted';

  /// Panel yang saling menggantikan (hanya satu terbuka pada satu waktu).
  static const List<String> panels = [
    inventory,
    equipment,
    character,
    settings,
    blacksmith,
    altar,
  ];
}
