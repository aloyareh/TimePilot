import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:time_pilot/data/local/hive_boxes.dart';
import 'package:time_pilot/data/local/models/client.dart';
import 'package:time_pilot/data/local/models/profile.dart';
import 'package:time_pilot/data/local/models/task.dart';
import 'package:time_pilot/data/repositories/client_repository.dart';
import 'package:time_pilot/data/repositories/profile_repository.dart';
import 'package:time_pilot/data/repositories/task_repository.dart';
import 'package:time_pilot/hive_registrar.g.dart';

void main() {
  late Directory tempDir;
  late ProfileRepository profiles;
  late ClientRepository clients;
  late TaskRepository tasks;

  Profile buildProfile(String userId, String role) => Profile(
    id: userId,
    role: role,
    homeTimezone: 'Asia/Jakarta',
    mainCurrency: 'IDR',
    workStartMinutes: 540,
    workEndMinutes: 1020,
    challengeType: ChallengeType.shake,
    challengeDifficulty: 1,
    updatedAt: DateTime.utc(2026, 10, 14),
  );

  Client buildClient(String id, {double rate = 20, String? owner = 'u1'}) =>
      Client(
        id: id,
        name: 'Studio London',
        timezoneId: 'Europe/London',
        hourlyRate: rate,
        currency: 'USD',
        updatedAt: DateTime.utc(2026, 10, 14),
        ownerId: owner,
      );

  Task buildTask(String id, {String? owner = 'u1'}) => Task(
    id: id,
    title: 'Meeting',
    clientId: 'c1',
    deadlineUtc: DateTime.utc(2026, 10, 20, 8),
    createdAt: DateTime.utc(2026, 10, 19),
    updatedAt: DateTime.utc(2026, 10, 19),
    ownerId: owner,
  );

  setUpAll(() {
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('time_pilot_persona_');
    Hive.init(tempDir.path);
    await Hive.openBox<Profile>(HiveBoxes.profile);
    await Hive.openBox<Client>(HiveBoxes.clients);
    await Hive.openBox<Task>(HiveBoxes.tasks);
    profiles = ProfileRepository();
    clients = ClientRepository();
    tasks = TaskRepository();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('ProfileRepository.getByUserId', () {
    test('mengembalikan profil milik user yang cocok', () async {
      await profiles.save(buildProfile('u1', 'Web Developer'));

      expect(profiles.getByUserId('u1')?.role, 'Web Developer');
    });

    test('null untuk user lain di HP yang sama', () async {
      await profiles.save(buildProfile('u1', 'Web Developer'));

      expect(profiles.getByUserId('u2'), isNull);
    });

    test('simpan ulang memperbarui, bukan menambah', () async {
      await profiles.save(buildProfile('u1', 'Web Developer'));
      await profiles.save(buildProfile('u1', 'UI Designer'));

      expect(profiles.getByUserId('u1')?.role, 'UI Designer');
    });
  });

  group('ClientRepository (CRUD klien)', () {
    test('tambah lalu baca zona waktu & tarif', () async {
      await clients.save(buildClient('c1'));

      final c = clients.getById('c1');
      expect(c?.timezoneId, 'Europe/London');
      expect(c?.hourlyRate, 20);
    });

    test('ubah: simpan dengan id sama menimpa data', () async {
      await clients.save(buildClient('c1'));
      await clients.save(buildClient('c1', rate: 35));

      expect(clients.getAll('u1'), hasLength(1));
      expect(clients.getById('c1')?.hourlyRate, 35);
    });

    test('hapus menyembunyikan klien dari daftar', () async {
      await clients.save(buildClient('c1'));
      await clients.save(buildClient('c2'));

      await clients.delete('c1');

      expect(clients.getById('c1'), isNull);
      expect(clients.getAll('u1').map((c) => c.id), ['c2']);
    });

    test('hapus mempertahankan pemilik', () async {
      await clients.save(buildClient('c1'));
      await clients.delete('c1');

      expect(clients.getAll('u2'), isEmpty);
      expect(clients.getAll('u1'), isEmpty);
    });
  });

  group('Isolasi data antar pengguna', () {
    test('klien user A tidak muncul untuk user B', () async {
      await clients.save(buildClient('c1', owner: 'uA'));
      await clients.save(buildClient('c2', owner: 'uB'));

      expect(clients.getAll('uA').map((c) => c.id), ['c1']);
      expect(clients.getAll('uB').map((c) => c.id), ['c2']);
    });

    test('tugas user A tidak muncul untuk user B', () async {
      await tasks.save(buildTask('t1', owner: 'uA'));
      await tasks.save(buildTask('t2', owner: 'uB'));

      expect(tasks.getAll('uA').map((t) => t.id), ['t1']);
      expect(tasks.getAll('uB').map((t) => t.id), ['t2']);
    });

    test('data lama tanpa pemilik tidak tampil untuk siapa pun', () async {
      await clients.save(buildClient('c1', owner: null));
      await tasks.save(buildTask('t1', owner: null));

      expect(clients.getAll('uA'), isEmpty);
      expect(tasks.getAll('uA'), isEmpty);
    });

    test('ownerId tersimpan setelah box ditutup dan dibuka lagi', () async {
      await clients.save(buildClient('c1', owner: 'uA'));

      await Hive.close();
      await Hive.openBox<Client>(HiveBoxes.clients);

      expect(clients.getAll('uA'), hasLength(1));
    });
  });
}
