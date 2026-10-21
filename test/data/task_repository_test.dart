import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:time_pilot/data/local/hive_boxes.dart';
import 'package:time_pilot/data/local/models/task.dart';
import 'package:time_pilot/data/repositories/task_repository.dart';
import 'package:time_pilot/hive_registrar.g.dart';

void main() {
  late Directory tempDir;
  late TaskRepository repo;

  Task buildTask(String id) {
    return Task(
      id: id,
      title: 'Meeting klien London',
      clientId: 'client-1',
      deadlineUtc: DateTime.utc(2026, 10, 20, 8),
      createdAt: DateTime.utc(2026, 10, 19),
      updatedAt: DateTime.utc(2026, 10, 19),
    );
  }

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('time_pilot_test_');
    Hive.init(tempDir.path);
    await Hive.openBox<Task>(HiveBoxes.tasks);
    repo = TaskRepository();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('simpan lalu baca kembali', () async {
    await repo.save(buildTask('t1'));

    final result = repo.getById('t1');

    expect(result, isNotNull);
    expect(result!.title, 'Meeting klien London');
    expect(result.clientId, 'client-1');
    expect(result.deadlineUtc.toUtc(), DateTime.utc(2026, 10, 20, 8));
  });

  test('hapus menyembunyikan data', () async {
    await repo.save(buildTask('t1'));

    await repo.delete('t1');

    expect(repo.getById('t1'), isNull);
    expect(repo.getAll('u1'), isEmpty);
  });

  test('data tetap ada setelah box ditutup dan dibuka lagi', () async {
    await repo.save(buildTask('t1'));

    await Hive.close();
    await Hive.openBox<Task>(HiveBoxes.tasks);

    expect(repo.getById('t1'), isNotNull);
  });
}