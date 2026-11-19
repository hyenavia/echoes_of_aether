import 'dart:convert';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/time_config.dart';
import 'package:echoes_of_aether/domain/services/period_service.dart';
import 'package:flutter_test/flutter_test.dart';

int _localMs({
  required int year,
  required int month,
  required int day,
  int hour = 0,
  int minute = 0,
  int second = 0,
  required Duration offset,
}) {
  final wallAsUtc = DateTime.utc(year, month, day, hour, minute, second);
  return wallAsUtc.millisecondsSinceEpoch - offset.inMilliseconds;
}

void main() {
  group('PeriodService', () {
    test('batas harian 23:59:59 vs 00:00:00 pada reset_hour = 0', () {
      const tz = Duration(hours: 7);
      final service = PeriodService(
        config: const TimeConfig(resetHour: 0, epochMonday: '2026-11-16'),
        timeZoneOffset: () => tz,
      );

      final beforeReset = _localMs(
        year: 2026,
        month: 11,
        day: 16,
        hour: 23,
        minute: 59,
        second: 59,
        offset: tz,
      );
      final atReset = _localMs(
        year: 2026,
        month: 11,
        day: 17,
        hour: 0,
        minute: 0,
        second: 0,
        offset: tz,
      );

      expect(service.keyFor(Period.daily, beforeReset), '2026-11-16');
      expect(service.keyFor(Period.daily, atReset), '2026-11-17');
      expect(service.dayIndex(beforeReset), 0);
      expect(service.dayIndex(atReset), 1);
      expect(service.nextResetMs(Period.daily, beforeReset), atReset);
      expect(
        service.nextResetMs(Period.daily, atReset),
        _localMs(year: 2026, month: 11, day: 18, offset: tz),
      );
    });

    test('batas mingguan Minggu 23:59:59 -> Senin 00:00:00', () {
      const tz = Duration(hours: 7);
      final service = PeriodService(
        config: const TimeConfig(resetHour: 0, epochMonday: '2026-11-16'),
        timeZoneOffset: () => tz,
      );

      // 2026-11-22 adalah hari Minggu di minggu epoch_monday (2026-11-16).
      final sundayEnd = _localMs(
        year: 2026,
        month: 11,
        day: 22,
        hour: 23,
        minute: 59,
        second: 59,
        offset: tz,
      );
      // 2026-11-23 adalah hari Senin berikutnya.
      final mondayStart = _localMs(
        year: 2026,
        month: 11,
        day: 23,
        hour: 0,
        minute: 0,
        second: 0,
        offset: tz,
      );

      expect(service.keyFor(Period.weekly, sundayEnd), '2026-11-16');
      expect(service.weekIndex(sundayEnd), 0);
      expect(service.keyFor(Period.weekly, mondayStart), '2026-11-23');
      expect(service.weekIndex(mondayStart), 1);
      expect(service.nextResetMs(Period.weekly, sundayEnd), mondayStart);
    });

    test(
      'pergantian tahun 2026-12-31 -> 2027-01-01 termasuk kunci mingguan',
      () {
        const tz = Duration(hours: 0);
        final service = PeriodService(
          config: const TimeConfig(resetHour: 0, epochMonday: '2026-11-16'),
          timeZoneOffset: () => tz,
        );

        // 2026-12-31 adalah Kamis; Senin minggu itu adalah 2026-12-28.
        final dec31 = _localMs(
          year: 2026,
          month: 12,
          day: 31,
          hour: 23,
          minute: 59,
          second: 59,
          offset: tz,
        );
        // 2027-01-01 adalah Jumat; tetap dalam minggu Senin 2026-12-28.
        final jan1 = _localMs(
          year: 2027,
          month: 1,
          day: 1,
          hour: 0,
          minute: 0,
          second: 0,
          offset: tz,
        );
        // 2027-01-04 adalah Senin pertama di 2027.
        final jan4 = _localMs(year: 2027, month: 1, day: 4, offset: tz);

        expect(service.keyFor(Period.daily, dec31), '2026-12-31');
        expect(service.keyFor(Period.daily, jan1), '2027-01-01');
        expect(service.keyFor(Period.weekly, dec31), '2026-12-28');
        expect(service.keyFor(Period.weekly, jan1), '2026-12-28');
        expect(service.keyFor(Period.weekly, jan4), '2027-01-04');
        expect(service.dayIndex(jan1), service.dayIndex(dec31) + 1);
      },
    );

    test('tiga offset zona waktu berbeda menghasilkan kunci lokal tepat', () {
      // Satu momen UTC: 2026-11-16 20:00:00Z
      // - UTC-5 : 2026-11-16 15:00:00 (Senin)
      // - UTC+0 : 2026-11-16 20:00:00 (Senin)
      // - UTC+9 : 2026-11-17 05:00:00 (Selasa)
      final utcMomentMs = DateTime.utc(
        2026,
        11,
        16,
        20,
        0,
        0,
      ).millisecondsSinceEpoch;
      const service = PeriodService(
        config: TimeConfig(resetHour: 0, epochMonday: '2026-11-16'),
      );

      expect(
        service.keyFor(
          Period.daily,
          utcMomentMs,
          offset: const Duration(hours: -5),
        ),
        '2026-11-16',
      );
      expect(
        service.keyFor(Period.daily, utcMomentMs, offset: Duration.zero),
        '2026-11-16',
      );
      expect(
        service.keyFor(
          Period.daily,
          utcMomentMs,
          offset: const Duration(hours: 9),
        ),
        '2026-11-17',
      );
    });

    test('reset_hour bukan 0 (misal jam 04:00 lokal)', () {
      const tz = Duration(hours: 7);
      final service = PeriodService(
        config: const TimeConfig(resetHour: 4, epochMonday: '2026-11-16'),
        timeZoneOffset: () => tz,
      );

      // Senin 2026-11-23 03:59:59 masih dihitung hari Minggu 2026-11-22 (minggu 2026-11-16).
      final before4am = _localMs(
        year: 2026,
        month: 11,
        day: 23,
        hour: 3,
        minute: 59,
        second: 59,
        offset: tz,
      );
      // Senin 2026-11-23 04:00:00 masuk periode baru.
      final at4am = _localMs(
        year: 2026,
        month: 11,
        day: 23,
        hour: 4,
        minute: 0,
        second: 0,
        offset: tz,
      );

      expect(service.keyFor(Period.daily, before4am), '2026-11-22');
      expect(service.keyFor(Period.weekly, before4am), '2026-11-16');
      expect(service.weekIndex(before4am), 0);

      expect(service.keyFor(Period.daily, at4am), '2026-11-23');
      expect(service.keyFor(Period.weekly, at4am), '2026-11-23');
      expect(service.weekIndex(at4am), 1);
      expect(service.nextResetMs(Period.daily, before4am), at4am);
    });

    test('siklus 2-mingguan: biweekIndex, biweeklyKey, dan nextBiweeklyResetMs tepat pada reset_hour 4 AM', () {
      const tz = Duration(hours: 7);
      final service = PeriodService(
        config: const TimeConfig(resetHour: 4, epochMonday: '2026-11-16'),
        timeZoneOffset: () => tz,
      );

      // Hari pertama siklus 0: 16 Nov 2026 10:00 WIB
      final week0Day1 = _localMs(
        year: 2026,
        month: 11,
        day: 16,
        hour: 10,
        offset: tz,
      );
      expect(service.biweekIndex(week0Day1), 0);
      expect(service.biweeklyKey(week0Day1), '2026-11-16');

      // Akhir minggu pertama (22 Nov): masih di siklus 0
      final week0End = _localMs(
        year: 2026,
        month: 11,
        day: 22,
        hour: 20,
        offset: tz,
      );
      expect(service.biweekIndex(week0End), 0);
      expect(service.biweeklyKey(week0End), '2026-11-16');

      // Minggu kedua (25 Nov): masih di siklus 0
      final week1Mid = _localMs(
        year: 2026,
        month: 11,
        day: 25,
        hour: 12,
        offset: tz,
      );
      expect(service.biweekIndex(week1Mid), 0);
      expect(service.biweeklyKey(week1Mid), '2026-11-16');

      // Sesaat sebelum reset 2-mingguan (30 Nov 03:59:59 WIB)
      final beforeReset = _localMs(
        year: 2026,
        month: 11,
        day: 30,
        hour: 3,
        minute: 59,
        second: 59,
        offset: tz,
      );
      expect(service.biweekIndex(beforeReset), 0);
      expect(service.biweeklyKey(beforeReset), '2026-11-16');

      // Tepat saat reset 2-mingguan (30 Nov 04:00:00 WIB): masuk ke siklus 1!
      final atReset = _localMs(
        year: 2026,
        month: 11,
        day: 30,
        hour: 4,
        minute: 0,
        second: 0,
        offset: tz,
      );
      expect(service.biweekIndex(atReset), 1);
      expect(service.biweeklyKey(atReset), '2026-11-30');

      // nextBiweeklyResetMs sebelum reset menunjuk ke 30 Nov 04:00 WIB
      expect(service.nextBiweeklyResetMs(beforeReset), atReset);

      // nextBiweeklyResetMs saat reset menunjuk ke 14 Dec 04:00 WIB
      final nextNextReset = _localMs(
        year: 2026,
        month: 12,
        day: 14,
        hour: 4,
        minute: 0,
        second: 0,
        offset: tz,
      );
      expect(service.nextBiweeklyResetMs(atReset), nextNextReset);
    });
  });

  group('TimeConfig & ClaimedRewardsConfig parser/validator', () {
    const parser = GameConfigParser();
    const validator = GameConfigValidator();

    GameConfig baseConfig({
      TimeConfig time = const TimeConfig(),
      ClaimedRewardsConfig claimedRewards = const ClaimedRewardsConfig(),
    }) {
      return GameConfig(
        monsters: const {},
        revive: const ReviveConfig(),
        progression: const ProgressionConfig(
          baseStats: CombatStats(maxHp: 100, atk: 12, def: 2),
          perLevel: LevelGrowth(hp: 15, atk: 2, def: 0.5),
        ),
        items: const {},
        lootTables: const {},
        time: time,
        claimedRewards: claimedRewards,
      );
    }

    test('menolak key tidak dikenal, reset_hour di luar 0..23, dan epoch bukan Senin', () {
      expect(
        () => parser.parseTime(
          jsonEncode({
            'time': {'unknown_key': 1},
          }),
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parser.parseTime(
          jsonEncode({
            'time': {'reset_hour': 24},
          }),
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parser.parseTime(
          jsonEncode({
            'time': {'reset_hour': -1},
          }),
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parser.parseTime(
          jsonEncode({
            'time': {'week_start': 'sunday'},
          }),
        ),
        throwsA(isA<ConfigException>()),
      );
      // 2026-11-17 adalah Selasa
      expect(
        () => parser.parseTime(
          jsonEncode({
            'time': {'epoch_monday': '2026-11-17'},
          }),
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parser.parseClaimedRewards(
          jsonEncode({
            'claimed_rewards': {'retention_days': 0},
          }),
        ),
        throwsA(isA<ConfigException>()),
      );

      expect(
        () => validator.validate(
          baseConfig(time: const TimeConfig(resetHour: 24)),
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => validator.validate(
          baseConfig(time: const TimeConfig(epochMonday: '2026-11-17')),
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => validator.validate(
          baseConfig(
            claimedRewards: const ClaimedRewardsConfig(retentionDays: 0),
          ),
        ),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
