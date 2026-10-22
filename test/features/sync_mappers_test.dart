import 'package:flutter_test/flutter_test.dart';
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
}