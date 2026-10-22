import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Penyimpanan foto profil di folder dokumen aplikasi (lokal, per pengguna).
///
/// Nama file: `<userId>-<timestamp>.jpg`. Tiap simpan memakai nama baru supaya
/// cache gambar Flutter tidak menampilkan foto lama, lalu file lama dihapus.
/// Tidak perlu field tambahan di model Hive: foto dicari lewat awalan nama.
class ProfilePhotoStore {
  ProfilePhotoStore({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;

  Future<Directory> _dir() async {
    final base = await _baseDir();
    final dir = Directory('${base.path}/profile_photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<File>> _filesOf(String userId) async {
    final dir = await _dir();
    final files = <File>[];
    await for (final e in dir.list()) {
      if (e is File && _name(e).startsWith('$userId-')) {
        files.add(e);
      }
    }
    files.sort((a, b) => _name(b).compareTo(_name(a))); // terbaru dulu
    return files;
  }

  static String _name(File f) => f.path.split(RegExp(r'[\\/]')).last;

  /// READ: foto terbaru milik [userId], atau null bila belum ada.
  Future<File?> find(String userId) async {
    final files = await _filesOf(userId);
    return files.isEmpty ? null : files.first;
  }

  /// CREATE / UPDATE: salin [sourcePath] jadi foto profil [userId].
  Future<File> save(String userId, String sourcePath) async {
    final dir = await _dir();
    final dest = File(
      '${dir.path}${Platform.pathSeparator}$userId-${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await File(sourcePath).copy(dest.path);
    for (final old in await _filesOf(userId)) {
      if (_name(old) != _name(dest)) {
        await old.delete();
      }
    }
    return dest;
  }

  /// DELETE: hapus semua foto milik [userId].
  Future<void> delete(String userId) async {
    for (final f in await _filesOf(userId)) {
      await f.delete();
    }
  }
}
