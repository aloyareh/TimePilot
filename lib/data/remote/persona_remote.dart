import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/models/client.dart';
import '../local/models/profile.dart';
import 'session_storage.dart';

/// Mengirim Profil & Klien ke Supabase (RPC app_save_profile, app_save_client,
/// app_delete_client; lihat schema_persona.sql).
///
/// Sifatnya best-effort: Hive adalah sumber utama (offline-first), jadi
/// kegagalan jaringan diabaikan. Antrian sync yang lengkap (retry, tarik data
/// dari server) dikerjakan di PBI-22.
class PersonaRemote {
  PersonaRemote({SupabaseClient? client, SessionStorage? storage})
    : _client = client ?? Supabase.instance.client,
      _storage = storage ?? const SessionStorage();

  final SupabaseClient _client;
  final SessionStorage _storage;

  Future<void> pushProfile(Profile p) => _call('app_save_profile', {
    'p_role': p.role,
    'p_home_timezone': p.homeTimezone,
    'p_main_currency': p.mainCurrency,
    'p_work_start_minutes': p.workStartMinutes,
    'p_work_end_minutes': p.workEndMinutes,
    'p_challenge_type': p.challengeType,
    'p_challenge_difficulty': p.challengeDifficulty,
    'p_updated_at': p.updatedAt.toUtc().toIso8601String(),
  });

  Future<void> pushClient(Client c) => _call('app_save_client', {
    'p_id': c.id,
    'p_name': c.name,
    'p_timezone_id': c.timezoneId,
    'p_hourly_rate': c.hourlyRate,
    'p_currency': c.currency,
    'p_updated_at': c.updatedAt.toUtc().toIso8601String(),
  });

  Future<void> deleteClient(String id) =>
      _call('app_delete_client', {'p_id': id});

  Future<void> _call(String fn, Map<String, dynamic> params) async {
    try {
      final token = await _storage.readToken();
      if (token == null) return;
      await _client.rpc(fn, params: {'p_token': token, ...params});
    } catch (_) {
      // Offline / server error: data tetap aman di Hive.
    }
  }
}

final personaRemoteProvider = Provider<PersonaRemote>((ref) => PersonaRemote());
