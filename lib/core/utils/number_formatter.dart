/// Utilitas pemformat angka ringkas untuk UI Idle RPG (GDD Addendum §5, TDD Addendum §3.2).
/// Mendukung representasi angka besar: K (ribu), M (juta), B (miliar), T (triliun), Q (kuadriliun).
class NumberFormatter {
  const NumberFormatter._();

  /// Memformat angka [value] menjadi representasi ringkas (mis. 999, 1.2K, 3.4M, 5.6B).
  ///
  /// - Nilai < 1.000 ditampilkan sebagai angka utuh.
  /// - Nilai kelipatan pas tidak memiliki desimal nol (1000 -> 1K, 1000000 -> 1M).
  /// - Nilai desimal dibulatkan ke 1 tempat desimal (1234 -> 1.2K).
  /// - Nilai negatif mempertahankan tanda minus (-999, -1K, -1.2K).
  static String format(num value) {
    if (value.isNaN) return '0';
    if (value.isInfinite) return value.isNegative ? '-Infinity' : 'Infinity';

    final isNeg = value < 0;
    final absVal = value.abs();

    if (absVal < 1000) {
      if (value is int) return '$value';
      final rounded = value.roundToDouble();
      return value == rounded ? value.toStringAsFixed(0) : value.toString();
    }

    double divisor = 1e3;
    String suffix = 'K';
    if (absVal >= 1e15) {
      divisor = 1e15;
      suffix = 'Q';
    } else if (absVal >= 1e12) {
      divisor = 1e12;
      suffix = 'T';
    } else if (absVal >= 1e9) {
      divisor = 1e9;
      suffix = 'B';
    } else if (absVal >= 1e6) {
      divisor = 1e6;
      suffix = 'M';
    }

    var scaled = absVal / divisor;
    var rounded = (scaled * 10).round() / 10;
    if (rounded >= 1000.0) {
      if (suffix == 'K') {
        divisor = 1e6;
        suffix = 'M';
        scaled = absVal / divisor;
        rounded = (scaled * 10).round() / 10;
      } else if (suffix == 'M') {
        divisor = 1e9;
        suffix = 'B';
        scaled = absVal / divisor;
        rounded = (scaled * 10).round() / 10;
      } else if (suffix == 'B') {
        divisor = 1e12;
        suffix = 'T';
        scaled = absVal / divisor;
        rounded = (scaled * 10).round() / 10;
      } else if (suffix == 'T') {
        divisor = 1e15;
        suffix = 'Q';
        scaled = absVal / divisor;
        rounded = (scaled * 10).round() / 10;
      }
    }

    final formatted = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);

    return '${isNeg ? '-' : ''}$formatted$suffix';
  }
}
