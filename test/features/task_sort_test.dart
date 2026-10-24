import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/data/local/models/task.dart';
import 'package:time_pilot/features/tasks/task_providers.dart';

Task _task(String id, DateTime deadline, {String status = TaskStatus.todo}) =>
    Task(
      id: id,
      title: id,
      clientId: 'c',
      deadlineUtc: deadline,
      status: status,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  test(
    'terlama dulu: deadline terjauh di atas, tugas selesai tetap di bawah',
    () {
      final a = _task('a', DateTime.utc(2026, 11, 1));
      final b = _task('b', DateTime.utc(2026, 11, 3));
      final c = _task('c', DateTime.utc(2026, 11, 2));
      final d = _task('d', DateTime.utc(2026, 11, 9), status: TaskStatus.done);
      final sorted = sortTasksLatestFirst([a, d, b, c]);
      expect(sorted.map((t) => t.id).toList(), ['b', 'c', 'a', 'd']);
    },
  );

  test('tidak mengubah daftar asli', () {
    final a = _task('a', DateTime.utc(2026, 11, 1));
    final b = _task('b', DateTime.utc(2026, 11, 3));
    final input = [a, b];
    sortTasksLatestFirst(input);
    expect(input.map((t) => t.id).toList(), ['a', 'b']);
  });
}
