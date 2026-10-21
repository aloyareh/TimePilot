import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/data/local/models/profile_photo_store.dart';

void main() {
  late Directory tempDir;
  late ProfilePhotoStore store;

  Future<File> source(String name, String content) async {
    final f = File('${tempDir.path}/$name');
    await f.writeAsString(content);
    return f;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('time_pilot_photo_');
    store = ProfilePhotoStore(baseDir: () async => tempDir);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('belum ada foto -> find mengembalikan null', () async {
    expect(await store.find('u1'), isNull);
  });

  test(
    'CREATE: simpan lalu find mengembalikan file yang sama isinya',
    () async {
      final src = await source('a.jpg', 'foto-1');

      final saved = await store.save('u1', src.path);
      final found = await store.find('u1');

      expect(found?.path, saved.path);
      expect(await found!.readAsString(), 'foto-1');
    },
  );

  test('UPDATE: simpan lagi mengganti foto, file lama terhapus', () async {
    final first = await store.save('u1', (await source('a.jpg', 'lama')).path);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await store.save('u1', (await source('b.jpg', 'baru')).path);

    expect(second.path, isNot(first.path));
    expect(await first.exists(), isFalse);
    expect(await (await store.find('u1'))!.readAsString(), 'baru');
  });

  test('DELETE: hapus foto menghilangkannya', () async {
    await store.save('u1', (await source('a.jpg', 'x')).path);

    await store.delete('u1');

    expect(await store.find('u1'), isNull);
  });

  test('foto tiap pengguna terpisah', () async {
    await store.save('u1', (await source('a.jpg', 'foto-A')).path);
    await store.save('u2', (await source('b.jpg', 'foto-B')).path);

    expect(await (await store.find('u1'))!.readAsString(), 'foto-A');
    expect(await (await store.find('u2'))!.readAsString(), 'foto-B');

    await store.delete('u1');

    expect(await store.find('u1'), isNull);
    expect(await store.find('u2'), isNotNull);
  });
}
