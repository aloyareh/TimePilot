import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/local/models/feedback_entry.dart';
import '../remote/session_storage.dart';

class FeedbackException implements Exception {
  const FeedbackException(this.code);
  final String code;

  String get message => switch (code) {
    'SESSION_INVALID' => 'Sesi berakhir. Masuk ulang untuk melanjutkan.',
    'FEEDBACK_INVALID' =>
      'Kesan dan pesan harus diisi (maksimal 500 karakter).',
    'NOT_FOUND' => 'Pesan tidak ditemukan atau bukan milikmu.',
    'NETWORK' => 'Tidak ada koneksi internet.',
    _ => 'Terjadi kesalahan. Coba lagi.',
  };

  @override
  String toString() => 'FeedbackException($code)';
}

/// CRUD Kesan & Pesan lewat RPC Supabase (lihat schema_feedback.sql).
/// Data bersama antar pengguna, jadi sengaja online-only (tanpa cache Hive).
class FeedbackRepository {
  FeedbackRepository({SupabaseClient? client, SessionStorage? storage})
    : _client = client ?? Supabase.instance.client,
      _storage = storage ?? const SessionStorage();

  final SupabaseClient _client;
  final SessionStorage _storage;

  Future<List<FeedbackEntry>> list() async {
    final res = await _rpc('app_feedback_list', {});
    return (res as List)
        .map((e) => FeedbackEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> create({required String impression, required String message}) =>
      _rpc('app_feedback_create', {
        'p_impression': impression.trim(),
        'p_message': message.trim(),
      });

  Future<void> update({
    required String id,
    required String impression,
    required String message,
  }) => _rpc('app_feedback_update', {
    'p_id': id,
    'p_impression': impression.trim(),
    'p_message': message.trim(),
  });

  Future<void> delete(String id) => _rpc('app_feedback_delete', {'p_id': id});

  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) async {
    final token = await _storage.readToken();
    if (token == null) throw const FeedbackException('SESSION_INVALID');
    try {
      return await _client.rpc(fn, params: {'p_token': token, ...params});
    } on PostgrestException catch (e) {
      throw FeedbackException(e.message);
    } catch (_) {
      throw const FeedbackException('NETWORK');
    }
  }
}
