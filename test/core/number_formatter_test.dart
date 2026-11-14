import 'package:echoes_of_aether/core/utils/number_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NumberFormatter', () {
    test('nilai di bawah 1000 ditampilkan sebagai angka utuh', () {
      expect(NumberFormatter.format(0), '0');
      expect(NumberFormatter.format(1), '1');
      expect(NumberFormatter.format(42), '42');
      expect(NumberFormatter.format(999), '999');
    });

    test('kelipatan pas tanpa desimal nol', () {
      expect(NumberFormatter.format(1000), '1K');
      expect(NumberFormatter.format(10000), '10K');
      expect(NumberFormatter.format(100000), '100K');
      expect(NumberFormatter.format(1000000), '1M');
      expect(NumberFormatter.format(1000000000), '1B');
      expect(NumberFormatter.format(1000000000000), '1T');
      expect(NumberFormatter.format(1000000000000000), '1Q');
    });

    test('pembulatan ke 1 desimal saat memiliki sisa pecahan', () {
      expect(NumberFormatter.format(1200), '1.2K');
      expect(NumberFormatter.format(1234), '1.2K');
      expect(NumberFormatter.format(1280), '1.3K');
      expect(NumberFormatter.format(3450000), '3.5M');
      expect(NumberFormatter.format(5600000000), '5.6B');
      expect(NumberFormatter.format(7890000000000), '7.9T');
    });

    test('promosi tier saat pembulatan mendekati 1000', () {
      // 999.950K jika dibulatkan 1 desimal menjadi 1000.0K, harus dipromosikan ke 1M
      expect(NumberFormatter.format(999950), '1M');
      expect(NumberFormatter.format(999950000), '1B');
    });

    test('angka negatif mempertahankan tanda minus', () {
      expect(NumberFormatter.format(-42), '-42');
      expect(NumberFormatter.format(-999), '-999');
      expect(NumberFormatter.format(-1000), '-1K');
      expect(NumberFormatter.format(-1234), '-1.2K');
      expect(NumberFormatter.format(-3450000), '-3.5M');
      expect(NumberFormatter.format(-5600000000), '-5.6B');
    });

    test('penanganan nilai ekstrem: NaN dan Infinity', () {
      expect(NumberFormatter.format(double.nan), '0');
      expect(NumberFormatter.format(double.infinity), 'Infinity');
      expect(NumberFormatter.format(double.negativeInfinity), '-Infinity');
    });
  });
}
