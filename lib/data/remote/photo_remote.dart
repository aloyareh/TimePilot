import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_storage.dart';

/// Unggah/hapus thumbnail foto profil dan ambil foto penulis kesan & pesan
/// (lihat schema_photo.sql). Best-effort: foto asli tetap tersimpan lokal.
class PhotoRemote {
  PhotoRemote({SupabaseClient? client, SessionStorage? storage})
    : _client = client ?? Supabase.instance.client,
      _storage = storage ?? const SessionStorage();

  final SupabaseClient _client;
  final SessionStorage _storage;

  Future<void> upload(Uint8List jpeg) =>
      _call('app_photo_set', {'p_photo': base64Encode(jpeg)});

  Future<void> delete() => _call('app_photo_delete', {});

  /// Peta id kesan & pesan -> foto penulisnya. Kosong bila gagal/offline.
  Future<Map<String, Uint8List>> fetchForFeedbacks() async {
    final out = <String, Uint8List>{};
    try {
      final token = await _storage.readToken();
      if (token == null) return out;
      final res = await _client.rpc(
        'app_feedback_photos',
        params: {'p_token': token},
      );
      for (final row in res as List) {
        try {
          final m = Map<String, dynamic>.from(row as Map);
          out[m['feedback_id'] as String] = base64Decode(m['photo'] as String);
        } catch (_) {
          // satu foto rusak tidak boleh menggagalkan yang lain
        }
      }
    } catch (_) {}
    return out;
  }

  Future<void> _call(String fn, Map<String, dynamic> params) async {
    try {
      final token = await _storage.readToken();
      if (token == null) return;
      await _client.rpc(fn, params: {'p_token': token, ...params});
    } catch (_) {}
  }
}

final photoRemoteProvider = Provider<PhotoRemote>((ref) => PhotoRemote());