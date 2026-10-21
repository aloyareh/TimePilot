import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/models/profile_photo_store.dart';
import 'profile_providers.dart';

final profilePhotoStoreProvider = Provider<ProfilePhotoStore>(
  (ref) => ProfilePhotoStore(),
);

/// Foto profil milik pengguna yang sedang login (null = belum ada foto).
/// Otomatis berganti saat akun berganti.
class ProfilePhotoNotifier extends AsyncNotifier<File?> {
  ProfilePhotoStore get _store => ref.read(profilePhotoStoreProvider);

  String get _uid {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      throw StateError('Belum login.');
    }
    return uid;
  }

  @override
  Future<File?> build() async {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) {
      return null;
    }
    return _store.find(uid);
  }

  /// Tambah atau ganti foto dari file hasil image picker.
  Future<void> setFromPath(String path) async {
    final file = await _store.save(_uid, path);
    state = AsyncData(file);
  }

  Future<void> remove() async {
    await _store.delete(_uid);
    state = const AsyncData(null);
  }
}

final profilePhotoProvider = AsyncNotifierProvider<ProfilePhotoNotifier, File?>(
  ProfilePhotoNotifier.new,
);
