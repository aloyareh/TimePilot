import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/data/local/models/client.dart';
import 'package:time_pilot/data/local/models/task.dart';
import 'package:time_pilot/data/local/models/work_session.dart';
import 'package:time_pilot/features/blockchain/chain.dart';
import 'package:time_pilot/features/sync/sync_mappers.dart';

Block _b(int i, Block? prev, String sid) => Block.create(
  prev: prev,
  endedAtUtc: DateTime.utc(2026, 10, 22, 9 + i),
  sessionId: sid,
  taskId: 't$sid',
  clientId: 'c1',
  durationSeconds: 100 * (i + 1),
  lateMinutes: 0,
  currency: 'USD',
  netMinor: 500,
);

void main() {
  group('Task JSON', () {
    test('bolak-balik sama dan kepemilikan diisi dari pemanggil', () {
      final t = Task(
        id: 't1',
        title: 'Desain',
        clientId: 'c1',
        deadlineUtc: DateTime.utc(2026, 10, 23, 9),
        status: TaskStatus.inProgress,
        createdAt: DateTime.utc(2026, 10, 20),
        updatedAt: DateTime.utc(2026, 10, 21, 5, 30, 15),
        isDeleted: true,
        ownerId: 'lain',
      );
      final back = taskFromJson(taskToJson(t), 'u1');
      expect(back.id, 't1');
      expect(back.title, 'Desain');
      expect(back.status, TaskStatus.inProgress);
      expect(back.deadlineUtc, t.deadlineUtc);
      expect(back.updatedAt, t.updatedAt);
      expect(back.isDeleted, isTrue);
      expect(back.ownerId, 'u1');
    });

    test('tarik dari server: timestamp berformat Postgres dan is_deleted hilang', () {
      final t = taskFromJson({
        'id': 't1',
        'title': 'X',
        'client_id': 'c1',
        'deadline_utc': '2026-10-23T09:00:00+00:00',
        'status': 'todo',
        'created_at': '2026-10-22T01:00:00.123456+00:00',
        'updated_at': '2026-10-22T01:00:00+00:00',
      }, 'u1');
      expect(t.deadlineUtc, DateTime.utc(2026, 10, 23, 9));
      expect(t.isDeleted, isFalse);
    });
  });

  group('WorkSession JSON', () {
    test('sesi selesai bolak-balik sama', () {
      final s = WorkSession(
        id: 's1',
        taskId: 't1',
        clientId: 'c1',
        startedAtUtc: DateTime.utc(2026, 10, 22, 3),
        endedAtUtc: DateTime.utc(2026, 10, 22, 4),
        durationSeconds: 3600,
        lateMinutes: 5,
        updatedAt: DateTime.utc(2026, 10, 22, 4),
      );
      final back = sessionFromJson(sessionToJson(s));
      expect(back.durationSeconds, 3600);
      expect(back.lateMinutes, 5);
      expect(back.endedAtUtc, s.endedAtUtc);
    });

    test('ended_at_utc null tetap null', () {
      final j = sessionToJson(
        WorkSession(
          id: 's1',
          taskId: 't1',
          clientId: 'c1',
          startedAtUtc: DateTime.utc(2026, 10, 22, 3),
          updatedAt: DateTime.utc(2026, 10, 22, 3),
        ),
      );
      expect(j['ended_at_utc'], isNull);
      expect(sessionFromJson(j).endedAtUtc, isNull);
    });
  });

  group('shouldApplyRemote (last-write-wins)', () {
    final t0 = DateTime.utc(2026, 10, 22, 1);
    test('tidak ada data lokal: terapkan', () {
      expect(shouldApplyRemote(null, t0), isTrue);
    });
    test('server lebih baru: terapkan', () {
      expect(shouldApplyRemote(t0, t0.add(const Duration(seconds: 1))), isTrue);
    });
    test('server lebih lama atau sama: pertahankan lokal', () {
      expect(shouldApplyRemote(t0, t0.subtract(const Duration(seconds: 1))), isFalse);
      expect(shouldApplyRemote(t0, t0), isFalse);
    });
  });

  group('diffChains', () {
    final b0 = _b(0, null, 's0');
    final b1 = _b(1, b0, 's1');
    final b2 = _b(2, b1, 's2');

    test('identik: konsisten', () {
      final c = diffChains([b0, b1, b2], [b0, b1, b2]);
      expect(c.consistent, isTrue);
      expect(c.localCount, 3);
      expect(c.serverCount, 3);
    });

    test('blok lokal diubah: terdeteksi sebagai berbeda', () {
      final c = diffChains([b0, b1.tampered(durationSeconds: 1), b2], [b0, b1, b2]);
      expect(c.mismatched, [1]);
      expect(c.consistent, isFalse);
    });

    test('isi diubah lalu hash dihitung ulang: tetap berbeda dari server', () {
      final forged = Block.create(
        prev: b0,
        endedAtUtc: DateTime.utc(2026, 10, 22, 10),
        sessionId: 's1',
        taskId: 'ts1',
        clientId: 'c1',
        durationSeconds: 99999,
        lateMinutes: 0,
        currency: 'USD',
        netMinor: 500,
      );
      expect(diffChains([b0, forged, b2], [b0, b1, b2]).mismatched, [1]);
    });

    test('blok lokal belum di server: missingOnServer', () {
      final c = diffChains([b0, b1, b2], [b0, b1]);
      expect(c.missingOnServer, [2]);
      expect(c.mismatched, isEmpty);
    });

    test('rantai lokal terpotong: serverOnly', () {
      final c = diffChains([b0], [b0, b1, b2]);
      expect(c.serverOnly, [1, 2]);
      expect(c.consistent, isFalse);
    });
  });

  group('profileFromJson / clientFromJson', () {
    test('profil dari server (nilai numerik dan zona waktu)', () {
      final p = profileFromJson({
        'role': 'Web Developer',
        'home_timezone': 'Asia/Jakarta',
        'main_currency': 'IDR',
        'work_start_minutes': 540,
        'work_end_minutes': 1020,
        'challenge_type': 'shake',
        'challenge_difficulty': 2,
        'updated_at': '2026-10-22T01:00:00+00:00',
      }, 'u1');
      expect(p.id, 'u1');
      expect(p.role, 'Web Developer');
      expect(p.workEndMinutes, 1020);
      expect(p.challengeDifficulty, 2);
    });

    test('klien dari server: tarif numeric bisa int atau double', () {
      Client c(num rate) => clientFromJson({
        'id': 'c1',
        'name': 'Acme',
        'timezone_id': 'Europe/London',
        'hourly_rate': rate,
        'currency': 'GBP',
        'is_deleted': false,
        'updated_at': '2026-10-22T01:00:00+00:00',
      }, 'u1');
      expect(c(20).hourlyRate, 20.0);
      expect(c(12.5).hourlyRate, 12.5);
      expect(c(20).ownerId, 'u1');
    });
  });

  group('planClientPush', () {
    final t0 = DateTime.utc(2026, 10, 22, 1);
    Client mk(String id, DateTime at, {bool deleted = false}) => Client(
      id: id,
      name: id,
      timezoneId: 'Asia/Jakarta',
      hourlyRate: 10,
      currency: 'IDR',
      updatedAt: at,
      isDeleted: deleted,
      ownerId: 'u1',
    );

    test('klien baru (belum di server) dikirim', () {
      final p = planClientPush([mk('c1', t0)], {}, {});
      expect(p.save.map((c) => c.id), ['c1']);
    });

    test('lokal lebih baru dikirim; sama atau lebih lama tidak', () {
      final remote = {'c1': t0, 'c2': t0, 'c3': t0};
      final p = planClientPush([
        mk('c1', t0.add(const Duration(minutes: 1))),
        mk('c2', t0),
        mk('c3', t0.subtract(const Duration(minutes: 1))),
      ], remote, {});
      expect(p.save.map((c) => c.id), ['c1']);
    });

    test('penghapusan lokal yang lebih baru memanggil hapus di server', () {
      final p = planClientPush(
        [mk('c1', t0.add(const Duration(minutes: 1)), deleted: true)],
        {'c1': t0},
        {},
      );
      expect(p.deleteIds, ['c1']);
      expect(p.save, isEmpty);
    });

    test('sudah terhapus di server atau tidak pernah ada: tidak ada aksi', () {
      final p = planClientPush(
        [
          mk('c1', t0.add(const Duration(minutes: 1)), deleted: true),
          mk('c2', t0, deleted: true),
        ],
        {'c1': t0},
        {'c1'},
      );
      expect(p.deleteIds, isEmpty);
      expect(p.save, isEmpty);
    });

    test('server lebih baru dari penghapusan lokal: tidak menghapus', () {
      final p = planClientPush(
        [mk('c1', t0, deleted: true)],
        {'c1': t0.add(const Duration(minutes: 5))},
        {},
      );
      expect(p.deleteIds, isEmpty);
    });
  });
}