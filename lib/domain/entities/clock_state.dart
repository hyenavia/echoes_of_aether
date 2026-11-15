/// State pengaman jam perangkat yang dipersistensikan di tabel `ClockStates`.
/// `lastSeenAtMs` hanya boleh naik; lonjakan maju melebihi ambang dicatat
/// untuk validasi di M14.
class ClockState {
  const ClockState({
    this.lastSeenAtMs = 0,
    this.forwardJumpCount = 0,
    this.maxForwardJumpMs = 0,
  });

  final int lastSeenAtMs;
  final int forwardJumpCount;
  final int maxForwardJumpMs;

  ClockState copyWith({
    int? lastSeenAtMs,
    int? forwardJumpCount,
    int? maxForwardJumpMs,
  }) => ClockState(
    lastSeenAtMs: lastSeenAtMs ?? this.lastSeenAtMs,
    forwardJumpCount: forwardJumpCount ?? this.forwardJumpCount,
    maxForwardJumpMs: maxForwardJumpMs ?? this.maxForwardJumpMs,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClockState &&
          lastSeenAtMs == other.lastSeenAtMs &&
          forwardJumpCount == other.forwardJumpCount &&
          maxForwardJumpMs == other.maxForwardJumpMs;

  @override
  int get hashCode =>
      Object.hash(lastSeenAtMs, forwardJumpCount, maxForwardJumpMs);
}

/// Hasil resolusi pembacaan jam oleh `ClockGuard`.
class ClockReading {
  const ClockReading({
    required this.effectiveMs,
    required this.wentBack,
    required this.forwardJumpMs,
    required this.state,
  });

  final int effectiveMs;
  final bool wentBack;
  final int forwardJumpMs;
  final ClockState state;
}
