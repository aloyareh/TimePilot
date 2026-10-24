import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/core/time/time_service.dart';

void main() {
  setUpAll(TimeService.init);

  // Sekarang = 24 Okt 2026 05:00 UTC
  // = 12:00 WIB = 13:00 WITA = 14:00 WIT = 06:00 BST
  final now = DateTime.utc(2026, 10, 24, 5, 0);

  bool past(String zone, int hour, int minute) {
    final utc = TimeService.toUtc(
      year: 2026,
      month: 10,
      day: 24,
      hour: hour,
      minute: minute,
      zoneId: zone,
    );
    return TimeService.isPast(utc, now: now);
  }

  test('WIB: 11:00 lewat, 13:00 belum', () {
    expect(past(AppZones.wib, 11, 0), isTrue);
    expect(past(AppZones.wib, 13, 0), isFalse);
  });

  test('WITA: 12:00 lewat, 14:00 belum', () {
    expect(past(AppZones.wita, 12, 0), isTrue);
    expect(past(AppZones.wita, 14, 0), isFalse);
  });

  test('WIT: 13:00 lewat, 15:00 belum', () {
    expect(past(AppZones.wit, 13, 0), isTrue);
    expect(past(AppZones.wit, 15, 0), isFalse);
  });

  test('London (BST): 05:00 lewat, 07:00 belum', () {
    expect(past(AppZones.london, 5, 0), isTrue);
    expect(past(AppZones.london, 7, 0), isFalse);
  });

  test('jam yang sama dengan sekarang dianggap lewat', () {
    expect(past(AppZones.wib, 12, 0), isTrue);
    expect(past(AppZones.wib, 12, 1), isFalse);
  });

  test('jam yang sama bisa lewat di satu zona tapi belum di zona lain', () {
    // 13:00 sudah lewat di WIB (sekarang 12:00)? Tidak. Di London 13:00 belum.
    // 12:30 WIT sudah lewat (sekarang 14:00 WIT), tapi 12:30 London belum.
    expect(past(AppZones.wit, 12, 30), isTrue);
    expect(past(AppZones.london, 12, 30), isFalse);
  });
}
