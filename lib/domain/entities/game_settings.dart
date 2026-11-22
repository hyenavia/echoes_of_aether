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
    this.notifyAbyssalSpireReset = false,
    this.notifyEventShopEnding = false,
    this.autoSalvageOfflineEquipment = false,
    this.lastSeenUpdateNoticeVersion = 0,
  }) : bgmVolume = bgmVolume < 0 ? 0.0 : (bgmVolume > 1 ? 1.0 : bgmVolume),
       sfxVolume = sfxVolume < 0 ? 0.0 : (sfxVolume > 1 ? 1.0 : sfxVolume);

  final bool bgmEnabled;
  final bool sfxEnabled;
  final double bgmVolume;
  final double sfxVolume;
  final bool notifyAutoFarmingFull;
  final bool notifyDailyBossReminder;
  final bool notifyWeeklyBossReminder;
  final bool notifyAbyssalSpireReset;
  final bool notifyEventShopEnding;
  final bool autoSalvageOfflineEquipment;
  final int lastSeenUpdateNoticeVersion;

  bool get anyNotificationCategoryEnabled =>
      notifyAutoFarmingFull ||
      notifyDailyBossReminder ||
      notifyWeeklyBossReminder ||
      notifyAbyssalSpireReset ||
      notifyEventShopEnding;

  GameSettingsData copyWith({
    bool? bgmEnabled,
    bool? sfxEnabled,
    double? bgmVolume,
    double? sfxVolume,
    bool? notifyAutoFarmingFull,
    bool? notifyDailyBossReminder,
    bool? notifyWeeklyBossReminder,
    bool? notifyAbyssalSpireReset,
    bool? notifyEventShopEnding,
    bool? autoSalvageOfflineEquipment,
    int? lastSeenUpdateNoticeVersion,
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
    notifyAbyssalSpireReset:
        notifyAbyssalSpireReset ?? this.notifyAbyssalSpireReset,
    notifyEventShopEnding: notifyEventShopEnding ?? this.notifyEventShopEnding,
    autoSalvageOfflineEquipment:
        autoSalvageOfflineEquipment ?? this.autoSalvageOfflineEquipment,
    lastSeenUpdateNoticeVersion:
        lastSeenUpdateNoticeVersion ?? this.lastSeenUpdateNoticeVersion,
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
          notifyAbyssalSpireReset == other.notifyAbyssalSpireReset &&
          notifyEventShopEnding == other.notifyEventShopEnding &&
          autoSalvageOfflineEquipment == other.autoSalvageOfflineEquipment &&
          lastSeenUpdateNoticeVersion == other.lastSeenUpdateNoticeVersion;

  @override
  int get hashCode => Object.hash(
    bgmEnabled,
    sfxEnabled,
    bgmVolume.toStringAsFixed(3),
    sfxVolume.toStringAsFixed(3),
    notifyAutoFarmingFull,
    notifyDailyBossReminder,
    notifyWeeklyBossReminder,
    notifyAbyssalSpireReset,
    notifyEventShopEnding,
    autoSalvageOfflineEquipment,
    lastSeenUpdateNoticeVersion,
  );
}
