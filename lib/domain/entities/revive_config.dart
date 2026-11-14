/// Parameter auto-revive (GDD 5.1). Dimuat dari game_config.json.
class ReviveConfig {
  const ReviveConfig({
    this.delaySeconds = 3.0,
    this.hpPercent = 0.3,
    this.invulnerabilitySeconds = 2.0,
    this.cooldownSeconds = 90.0,
  });

  /// Lama karakter berada di state Downed sebelum hidup kembali.
  final double delaySeconds;

  /// Persentase maximum HP saat hidup kembali (0.3 = 30%).
  final double hpPercent;

  /// Lama invulnerability setelah revive.
  final double invulnerabilitySeconds;

  /// Cooldown revive, dihitung sejak karakter hidup kembali.
  final double cooldownSeconds;
}
