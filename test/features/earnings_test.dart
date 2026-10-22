import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/data/local/models/client.dart';
import 'package:time_pilot/data/local/models/work_session.dart';
import 'package:time_pilot/features/earnings/earnings_providers.dart';

WorkSession _s(String id, String clientId, int secs, int late, {bool ended = true, bool deleted = false}) =>
    WorkSession(
      id: id,
      taskId: 't$id',
      clientId: clientId,
      startedAtUtc: DateTime.utc(2026, 10, 22, 9),
      endedAtUtc: ended ? DateTime.utc(2026, 10, 22, 10) : null,
      durationSeconds: secs,
      lateMinutes: late,
      updatedAt: DateTime.utc(2026, 10, 22, 10),
      isDeleted: deleted,
    );

Client _c(String id, String name, double rate, String cur) => Client(
  id: id,
  name: name,
  timezoneId: 'Europe/London',
  hourlyRate: rate,
  currency: cur,
  updatedAt: DateTime.utc(2026, 10, 22),
);

void main() {
  final clients = {
    'c1': _c('c1', 'Acme', 20, 'GBP'),
    'c2': _c('c2', 'Globex', 10, 'USD'),
  };

  test('tanpa sesi: kosong', () {
    expect(buildEarnings([], clients), isEmpty);
  });

  test('menjumlahkan per klien: dua sesi 1 jam, satu telat 15 menit', () {
    final r = buildEarnings([_s('1', 'c1', 3600, 15), _s('2', 'c1', 3600, 0)], clients);
    expect(r, hasLength(1));
    expect(r.first.sessionCount, 2);
    expect(r.first.gross, closeTo(40, 1e-9));
    expect(r.first.penalty, closeTo(5, 1e-9));
    expect(r.first.net, closeTo(35, 1e-9));
    expect(r.first.lateMinutes, 15);
    expect(r.first.totalSeconds, 7200);
  });

  test('sesi yang masih berjalan atau terhapus tidak dihitung', () {
    final r = buildEarnings([
      _s('1', 'c1', 3600, 0, ended: false),
      _s('2', 'c1', 3600, 0, deleted: true),
    ], clients);
    expect(r, isEmpty);
  });

  test('bersih dihitung per sesi, sesi sangat telat tidak mengurangi sesi lain', () {
    final r = buildEarnings([_s('1', 'c2', 60, 600), _s('2', 'c2', 3600, 0)], clients);
    // sesi 1: kotor 0.1667, denda 100 -> bersih 0; sesi 2: bersih 10
    expect(r.first.net, closeTo(10, 1e-9));
  });

  test('klien tidak ditemukan: tarif 0 dan nama pengganti', () {
    final r = buildEarnings([_s('1', 'hilang', 3600, 0)], clients);
    expect(r.first.clientName, 'Klien tidak ditemukan');
    expect(r.first.net, 0);
  });

  test('diurutkan dari bersih terbesar', () {
    final r = buildEarnings([_s('1', 'c1', 3600, 0), _s('2', 'c2', 3600, 0)], clients);
    expect(r.map((e) => e.clientId), ['c1', 'c2']); // 20 > 10 (nominal)
  });
}