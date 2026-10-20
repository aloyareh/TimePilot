import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/data/local/models/client.dart';
import 'package:time_pilot/data/local/models/task.dart';
import 'package:time_pilot/features/session/session_providers.dart';
import 'package:time_pilot/features/tasks/task_providers.dart';

Task _task(String id, String title, String clientId, String status) => Task(
  id: id,
  title: title,
  clientId: clientId,
  deadlineUtc: DateTime.utc(2026, 10, 23, 9),
  status: status,
  createdAt: DateTime.utc(2026, 10, 20),
  updatedAt: DateTime.utc(2026, 10, 20),
);

Client _client(String id, String name, String currency) => Client(
  id: id,
  name: name,
  timezoneId: 'Europe/London',
  hourlyRate: 20,
  currency: currency,
  updatedAt: DateTime.utc(2026, 10, 20),
);

void main() {
  group('computeLateMinutes', () {
    final scheduled = DateTime.utc(2026, 10, 23, 9, 0);

    test('mulai sebelum jadwal = 0', () {
      expect(
        computeLateMinutes(
          startedUtc: DateTime.utc(2026, 10, 23, 8, 50),
          scheduledUtc: scheduled,
        ),
        0,
      );
    });

    test('tepat jadwal = 0', () {
      expect(
        computeLateMinutes(startedUtc: scheduled, scheduledUtc: scheduled),
        0,
      );
    });

    test('terlambat 15 menit = 15', () {
      expect(
        computeLateMinutes(
          startedUtc: DateTime.utc(2026, 10, 23, 9, 15),
          scheduledUtc: scheduled,
        ),
        15,
      );
    });

    test('terlambat 14 menit 59 detik dibulatkan ke bawah = 14', () {
      expect(
        computeLateMinutes(
          startedUtc: DateTime.utc(2026, 10, 23, 9, 14, 59),
          scheduledUtc: scheduled,
        ),
        14,
      );
    });
  });

  group('formatHms', () {
    test('contoh', () {
      expect(formatHms(const Duration(hours: 1, minutes: 5, seconds: 9)), '01:05:09');
      expect(formatHms(Duration.zero), '00:00:00');
      expect(formatHms(const Duration(hours: 25)), '25:00:00');
    });

    test('negatif dianggap nol', () {
      expect(formatHms(const Duration(seconds: -5)), '00:00:00');
    });
  });

  group('taskAlarmId', () {
    test('stabil dan di dalam rentang int 32-bit positif', () {
      const id = '07357767-40bd-4a41-8910-880d77abe6e3';
      expect(taskAlarmId(id), taskAlarmId(id));
      expect(taskAlarmId(id), 0x0735776);
      expect(taskAlarmId(id), lessThan(0x7fffffff));
    });

    test('ID pendek tetap menghasilkan angka non-negatif', () {
      expect(taskAlarmId('abc'), greaterThanOrEqualTo(0));
    });
  });

  group('applyTaskFilter', () {
    final clients = {
      'c1': _client('c1', 'Acme Ltd', 'GBP'),
      'c2': _client('c2', 'Globex', 'USD'),
    };
    final tasks = [
      _task('1', 'Desain landing page', 'c1', TaskStatus.todo),
      _task('2', 'Revisi logo', 'c2', TaskStatus.done),
      _task('3', 'Meeting mingguan', 'c1', TaskStatus.inProgress),
    ];

    List<String> ids(TaskFilter f) =>
        applyTaskFilter(tasks, clients, f).map((t) => t.id).toList();

    test('tanpa filter: semua', () {
      expect(ids(const TaskFilter()), ['1', '2', '3']);
    });

    test('cari judul, tidak peka huruf besar', () {
      expect(ids(const TaskFilter(query: 'LOGO')), ['2']);
    });

    test('cari nama klien', () {
      expect(ids(const TaskFilter(query: 'acme')), ['1', '3']);
    });

    test('filter status', () {
      expect(ids(const TaskFilter(status: TaskStatus.done)), ['2']);
    });

    test('filter klien', () {
      expect(ids(const TaskFilter(clientId: 'c1')), ['1', '3']);
    });

    test('filter mata uang', () {
      expect(ids(const TaskFilter(currency: 'USD')), ['2']);
    });

    test('kombinasi (AND)', () {
      expect(
        ids(const TaskFilter(clientId: 'c1', status: TaskStatus.inProgress)),
        ['3'],
      );
      expect(ids(const TaskFilter(query: 'logo', currency: 'GBP')), isEmpty);
    });
  });
}