/// Pengaturan aplikasi & audio yang persisten (menggunakan tabel `GameSettings`).
class GameSettingsData {
  const GameSettingsData({
    this.bgmEnabled = true,
    this.sfxEnabled = true,
    double bgmVolume = 0.45,
    double sfxVolume = 0.75,
    this.notifyAutoFarmingFull = false,
    this.notifyDailyBossReminder = false,
    this.notifyWeeklyBossReminder = false,
    this.notifyEventShopEnding = false,
    this.notifyQuietHoursEnabled = true,
    this.autoSalvageOfflineEquipment = false,
  }) : bgmVolume = bgmVolume < 0 ? 0.0 : (bgmVolume > 1 ? 1.0 : bgmVolume),
       sfxVolume = sfxVolume < 0 ? 0.0 : (sfxVolume > 1 ? 1.0 : sfxVolume);

  final bool bgmEnabled;
  final bool sfxEnabled;
  final double bgmVolume;
  final double sfxVolume;
  final bool notifyAutoFarmingFull;
  final bool notifyDailyBossReminder;
  final bool notifyWeeklyBossReminder;
  final bool notifyEventShopEnding;
  final bool notifyQuietHoursEnabled;
  final bool autoSalvageOfflineEquipment;

  bool get anyNotificationCategoryEnabled =>
      notifyAutoFarmingFull ||
      notifyDailyBossReminder ||
      notifyWeeklyBossReminder ||
      notifyEventShopEnding;

  GameSettingsData copyWith({
    bool? bgmEnabled,
    bool? sfxEnabled,
    double? bgmVolume,
    double? sfxVolume,
    bool? notifyAutoFarmingFull,
    bool? notifyDailyBossReminder,
    bool? notifyWeeklyBossReminder,
    bool? notifyEventShopEnding,
    bool? notifyQuietHoursEnabled,
    bool? autoSalvageOfflineEquipment,
  }) => GameSettingsData(
    bgmEnabled: bgmEnabled ?? this.bgmEnabled,
    sfxEnabled: sfxEnabled ?? this.sfxEnabled,
    bgmVolume: bgmVolume ?? this.bgmVolume,
    sfxVolume: sfxVolume ?? this.sfxVolume,
    notifyAutoFarmingFull: notifyAutoFarmingFull ?? this.notifyAutoFarmingFull,
    notifyDailyBossReminder:
        notifyDailyBossReminder ?? this.notifyDailyBossReminder,
    notifyWeeklyBossReminder:
        notifyWeeklyBossReminder ?? this.notifyWeeklyBossReminder,
    notifyEventShopEnding: notifyEventShopEnding ?? this.notifyEventShopEnding,
    notifyQuietHoursEnabled:
        notifyQuietHoursEnabled ?? this.notifyQuietHoursEnabled,
    autoSalvageOfflineEquipment:
        autoSalvageOfflineEquipment ?? this.autoSalvageOfflineEquipment,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameSettingsData &&
          bgmEnabled == other.bgmEnabled &&
          sfxEnabled == other.sfxEnabled &&
          (bgmVolume - other.bgmVolume).abs() < 1e-6 &&
          (sfxVolume - other.sfxVolume).abs() < 1e-6 &&
          notifyAutoFarmingFull == other.notifyAutoFarmingFull &&
          notifyDailyBossReminder == other.notifyDailyBossReminder &&
          notifyWeeklyBossReminder == other.notifyWeeklyBossReminder &&
          notifyEventShopEnding == other.notifyEventShopEnding &&
          notifyQuietHoursEnabled == other.notifyQuietHoursEnabled &&
          autoSalvageOfflineEquipment == other.autoSalvageOfflineEquipment;

  @override
  int get hashCode => Object.hash(
    bgmEnabled,
    sfxEnabled,
    bgmVolume.toStringAsFixed(3),
    sfxVolume.toStringAsFixed(3),
    notifyAutoFarmingFull,
    notifyDailyBossReminder,
    notifyWeeklyBossReminder,
    notifyEventShopEnding,
    notifyQuietHoursEnabled,
    autoSalvageOfflineEquipment,
  );
}
