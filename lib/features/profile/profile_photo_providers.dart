import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/image/avatar_thumbnail.dart';
import '../../data/local/models/profile_photo_store.dart';
import '../../data/remote/photo_remote.dart';
import 'profile_providers.dart';

final profilePhotoStoreProvider = Provider<ProfilePhotoStore>(
  (ref) => ProfilePhotoStore(),
);

/// Foto profil milik pengguna yang sedang login (null = belum ada foto).
/// Otomatis berganti saat akun berganti. Thumbnail-nya ikut diunggah ke server
/// (best-effort) supaya terlihat oleh akun lain di Kesan & Pesan.
class ProfilePhotoNotifier extends AsyncNotifier<File?> {
  ProfilePhotoStore get _store => ref.read(profilePhotoStoreProvider);

  /// Akun yang thumbnail-nya sudah diunggah pada sesi aplikasi ini, supaya
  /// foto lama (dipilih sebelum fitur ini ada) terunggah sekali saja.
  static final _uploaded = <String>{};

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
    final file = await _store.find(uid);
    if (file != null && _uploaded.add(uid)) {
      unawaited(_pushThumbnail(file, uid));
    }
    return file;
  }

  Future<void> _pushThumbnail(File file, String uid) async {
    try {
      final bytes = await file.readAsBytes();
      final thumb = await compute(buildAvatarThumbnail, bytes);
      if (thumb == null) {
        _uploaded.remove(uid);
        return;
      }
      await ref.read(photoRemoteProvider).upload(thumb);
    } catch (_) {
      _uploaded.remove(uid); // coba lagi pada pembangunan berikutnya
    }
  }

  /// Tambah atau ganti foto dari file hasil image picker.
  Future<void> setFromPath(String path) async {
    final uid = _uid;
    final file = await _store.save(uid, path);
    state = AsyncData(file);
    _uploaded.add(uid);
    unawaited(_pushThumbnail(file, uid));
  }

  Future<void> remove() async {
    final uid = _uid;
    await _store.delete(uid);
    _uploaded.remove(uid);
    state = const AsyncData(null);
    unawaited(ref.read(photoRemoteProvider).delete());
  }
}

final profilePhotoProvider = AsyncNotifierProvider<ProfilePhotoNotifier, File?>(
  ProfilePhotoNotifier.new,
);