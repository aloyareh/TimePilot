import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/core/time/time_service.dart';

void main() {
  setUpAll(TimeService.init);

  group('Zona Indonesia', () {
    final utc = DateTime.utc(2026, 7, 15, 8, 0);

    test('WIB +7, WITA +8, WIT +9', () {
      expect(TimeService.formatHm(utc, AppZones.wib), '15:00 WIB');
      expect(TimeService.formatHm(utc, AppZones.wita), '16:00 WITA');
      expect(TimeService.formatHm(utc, AppZones.wit), '17:00 WIT');
    });

    test('tidak terpengaruh musim (Desember sama)', () {
      final dec = DateTime.utc(2026, 12, 15, 8, 0);
      expect(TimeService.formatHm(dec, AppZones.wib), '15:00 WIB');
      expect(TimeService.formatHm(dec, AppZones.wit), '17:00 WIT');
    });
  });

  group('London BST/GMT', () {
    test('musim panas = BST (+1)', () {
      final utc = DateTime.utc(2026, 7, 15, 8, 0);
      expect(TimeService.formatHm(utc, AppZones.london), '09:00 BST');
    });

    test('musim dingin = GMT (+0)', () {
      final utc = DateTime.utc(2026, 12, 15, 8, 0);
      expect(TimeService.formatHm(utc, AppZones.london), '08:00 GMT');
    });

    test('DST berakhir 25 Okt 2026 (01:00 UTC)', () {
      expect(
        TimeService.formatHm(DateTime.utc(2026, 10, 25, 0, 59), AppZones.london),
        '01:59 BST',
      );
      expect(
        TimeService.formatHm(DateTime.utc(2026, 10, 25, 1, 0), AppZones.london),
        '01:00 GMT',
      );
    });

    test('DST mulai 29 Mar 2026 (01:00 UTC)', () {
      expect(
        TimeService.formatHm(DateTime.utc(2026, 3, 29, 0, 59), AppZones.london),
        '00:59 GMT',
      );
      expect(
        TimeService.formatHm(DateTime.utc(2026, 3, 29, 1, 0), AppZones.london),
        '02:00 BST',
      );
    });
  });

  group('toUtc (waktu dinding -> UTC)', () {
    test('London musim panas 10:00 = 09:00 UTC', () {
      final u = TimeService.toUtc(
        year: 2026, month: 7, day: 15, hour: 10, minute: 0,
        zoneId: AppZones.london,
      );
      expect(u, DateTime.utc(2026, 7, 15, 9, 0));
    });

    test('London musim dingin 10:00 = 10:00 UTC', () {
      final u = TimeService.toUtc(
        year: 2026, month: 12, day: 15, hour: 10, minute: 0,
        zoneId: AppZones.london,
      );
      expect(u, DateTime.utc(2026, 12, 15, 10, 0));
    });

    test('Jakarta 10:00 = 03:00 UTC', () {
      final u = TimeService.toUtc(
        year: 2026, month: 7, day: 15, hour: 10, minute: 0,
        zoneId: AppZones.wib,
      );
      expect(u, DateTime.utc(2026, 7, 15, 3, 0));
    });
  });

  test('US-1: deadline klien London tampil berdampingan dengan WIB', () {
    final deadline = TimeService.toUtc(
      year: 2026, month: 10, day: 23, hour: 10, minute: 0,
      zoneId: AppZones.london,
    );
    final text = TimeService.dual(
      deadline,
      homeZone: AppZones.wib,
      clientZone: AppZones.london,
    );
    expect(text.home, '23/10 16:00 WIB');
    expect(text.client, '23/10 10:00 BST');
  });
}