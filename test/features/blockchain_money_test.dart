import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/features/blockchain/chain.dart';
import 'package:time_pilot/features/session/session_money.dart';

Block _chain3() {
  var prev = Block.create(
    endedAtUtc: DateTime.utc(2026, 10, 21, 9),
    sessionId: 's0',
    taskId: 't0',
    clientId: 'c1',
    durationSeconds: 1800,
    lateMinutes: 0,
    currency: 'USD',
    netMinor: 1000,
  );
  return prev;
}

List<Block> _build() {
  final b0 = _chain3();
  final b1 = Block.create(
    prev: b0,
    endedAtUtc: DateTime.utc(2026, 10, 22, 9),
    sessionId: 's1',
    taskId: 't1',
    clientId: 'c1',
    durationSeconds: 3600,
    lateMinutes: 15,
    currency: 'USD',
    netMinor: 1500,
  );
  final b2 = Block.create(
    prev: b1,
    endedAtUtc: DateTime.utc(2026, 10, 23, 9),
    sessionId: 's2',
    taskId: 't2',
    clientId: 'c1',
    durationSeconds: 600,
    lateMinutes: 0,
    currency: 'USD',
    netMinor: 300,
  );
  return [b0, b1, b2];
}

void main() {
  group('computeSessionMoney', () {
    test('1 jam, tarif 20, telat 15 menit: kotor 20, denda 5, bersih 15', () {
      final m = computeSessionMoney(
        durationSeconds: 3600,
        lateMinutes: 15,
        hourlyRate: 20,
        currency: 'GBP',
      );
      expect(m.gross, closeTo(20, 1e-9));
      expect(m.penalty, closeTo(5, 1e-9));
      expect(m.net, closeTo(15, 1e-9));
      expect(m.netMinor, 1500);
    });

    test('tepat waktu: tanpa denda', () {
      final m = computeSessionMoney(
        durationSeconds: 1800,
        lateMinutes: 0,
        hourlyRate: 10,
        currency: 'USD',
      );
      expect(m.penalty, 0);
      expect(m.net, closeTo(5, 1e-9));
    });

    test('denda lebih besar dari pendapatan: bersih dibatasi 0', () {
      final m = computeSessionMoney(
        durationSeconds: 60,
        lateMinutes: 120,
        hourlyRate: 10,
        currency: 'USD',
      );
      expect(m.net, 0);
      expect(m.netMinor, 0);
    });
  });

  group('blockchain', () {
    test('vektor hash tetap (dihitung terpisah dengan SHA-256 di Python)', () {
      final b = Block.create(
        endedAtUtc: DateTime.utc(2026, 10, 21, 9),
        sessionId: 's1',
        taskId: 't1',
        clientId: 'c1',
        durationSeconds: 3600,
        lateMinutes: 15,
        currency: 'GBP',
        netMinor: 1500,
      );
      expect(b.index, 0);
      expect(b.prevHash, genesisHash);
      expect(
        b.hash,
        'b7f1573be6c0850e44db80828ee684b82280381bed9d77f8242a4bc61c77055b',
      );
    });

    test('rantai utuh valid, rantai kosong valid', () {
      expect(firstInvalidIndex(_build()), isNull);
      expect(firstInvalidIndex([]), isNull);
    });

    test('mengubah isi blok lama terdeteksi di blok itu', () {
      final c = _build();
      c[1] = c[1].tampered(durationSeconds: 9999);
      expect(firstInvalidIndex(c), 1);
    });

    test('mengubah isi lalu menghitung ulang hash memutus blok berikutnya', () {
      final c = _build();
      final b = c[0].tampered(netMinor: 999999);
      c[0] = Block(
        index: b.index,
        prevHash: b.prevHash,
        timestampMs: b.timestampMs,
        sessionId: b.sessionId,
        taskId: b.taskId,
        clientId: b.clientId,
        durationSeconds: b.durationSeconds,
        lateMinutes: b.lateMinutes,
        currency: b.currency,
        netMinor: b.netMinor,
        hash: b.recompute(),
      );
      expect(firstInvalidIndex(c), 1); // blok 0 konsisten, tautan blok 1 putus
    });

    test('menghapus blok tengah terdeteksi', () {
      final c = _build()..removeAt(1);
      expect(firstInvalidIndex(c), 1);
    });

    test('urutan tertukar terdeteksi', () {
      final c = _build();
      final t = c[1];
      c[1] = c[2];
      c[2] = t;
      expect(firstInvalidIndex(c), 1);
    });

    test('toJson dan fromJson bolak-balik sama', () {
      final b = _build()[1];
      final back = Block.fromJson(b.toJson());
      expect(back.hash, b.hash);
      expect(back.recompute(), b.hash);
    });
  });
}