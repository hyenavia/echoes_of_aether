/// Pengaturan aplikasi & audio yang persisten (menggunakan tabel `GameSettings`).
class GameSettingsData {
  const GameSettingsData({
    this.bgmEnabled = true,
    this.sfxEnabled = true,
    double bgmVolume = 0.45,
    double sfxVolume = 0.75,
  }) : bgmVolume = bgmVolume < 0 ? 0.0 : (bgmVolume > 1 ? 1.0 : bgmVolume),
       sfxVolume = sfxVolume < 0 ? 0.0 : (sfxVolume > 1 ? 1.0 : sfxVolume);

  final bool bgmEnabled;
  final bool sfxEnabled;
  final double bgmVolume;
  final double sfxVolume;

  GameSettingsData copyWith({
    bool? bgmEnabled,
    bool? sfxEnabled,
    double? bgmVolume,
    double? sfxVolume,
  }) => GameSettingsData(
    bgmEnabled: bgmEnabled ?? this.bgmEnabled,
    sfxEnabled: sfxEnabled ?? this.sfxEnabled,
    bgmVolume: bgmVolume ?? this.bgmVolume,
    sfxVolume: sfxVolume ?? this.sfxVolume,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameSettingsData &&
          bgmEnabled == other.bgmEnabled &&
          sfxEnabled == other.sfxEnabled &&
          (bgmVolume - other.bgmVolume).abs() < 1e-6 &&
          (sfxVolume - other.sfxVolume).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(
    bgmEnabled,
    sfxEnabled,
    bgmVolume.toStringAsFixed(3),
    sfxVolume.toStringAsFixed(3),
  );
}
