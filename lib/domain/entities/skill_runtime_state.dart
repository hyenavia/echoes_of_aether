import 'dart:math' as math;

/// State runtime skill milik karakter, terpisah dari definisi statis JSON.
class SkillRuntimeState {
  const SkillRuntimeState({
    required this.skillId,
    this.level = 1,
    this.unlocked = false,
    this.cooldownTicksRemaining = 0,
  }) : assert(level >= 1, 'level skill minimal 1'),
       assert(cooldownTicksRemaining >= 0, 'cooldown tidak boleh negatif');

  /// Timestep tetap simulasi: 50 ms = 20 tick per detik.
  static const int ticksPerSecond = 20;

  /// Mengonversi durasi detik menjadi jumlah simulation ticks (50 ms/tick).
  static int secondsToTicks(double seconds) {
    if (seconds <= 0) return 0;
    return math.max(1, (seconds * ticksPerSecond).round());
  }

  final String skillId;
  final int level;
  final bool unlocked;
  final int cooldownTicksRemaining;

  bool get isReady => unlocked && cooldownTicksRemaining == 0;

  SkillRuntimeState copyWith({
    int? level,
    bool? unlocked,
    int? cooldownTicksRemaining,
  }) => SkillRuntimeState(
    skillId: skillId,
    level: level ?? this.level,
    unlocked: unlocked ?? this.unlocked,
    cooldownTicksRemaining:
        cooldownTicksRemaining ?? this.cooldownTicksRemaining,
  );

  SkillRuntimeState triggerCooldown(int ticks) =>
      copyWith(cooldownTicksRemaining: math.max(0, ticks));

  SkillRuntimeState decrementCooldown() => cooldownTicksRemaining > 0
      ? copyWith(cooldownTicksRemaining: cooldownTicksRemaining - 1)
      : this;

  SkillRuntimeState resetCooldown() => copyWith(cooldownTicksRemaining: 0);
}
