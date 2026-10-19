import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../remote/session_storage.dart';

class AuthException implements Exception {
  const AuthException(this.code);
  final String code;

  String get message => switch (code) {
    'USERNAME_INVALID' =>
      'Username 3–30 karakter: huruf, angka, titik, atau garis bawah.',
    'PASSWORD_INVALID' => 'Password harus 8–72 karakter.',
    'USERNAME_TAKEN' => 'Username sudah dipakai.',
    'INVALID_CREDENTIALS' => 'Username atau password salah.',
    'NETWORK' => 'Tidak ada koneksi internet.',
    'SESSION_INVALID' => 'Sesi berakhir. Masuk dengan password.',
    _ => 'Terjadi kesalahan. Coba lagi.',
  };

  @override
  String toString() => 'AuthException($code)';
}

class AuthRepository {
  AuthRepository({SupabaseClient? client, SessionStorage? storage})
    : _client = client ?? Supabase.instance.client,
      _storage = storage ?? const SessionStorage();

  final SupabaseClient _client;
  final SessionStorage _storage;

  Future<AppUser> register({
    required String username,
    required String password,
    String? fullName,
  }) async {
    final res = await _call('app_register', {
      'p_username': username,
      'p_password': password,
      'p_full_name': fullName,
    });
    return _saveSession(res);
  }

  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final res = await _call('app_login', {
      'p_username': username,
      'p_password': password,
    });
    return _saveSession(res);
  }

  Future<AppUser?> restoreSession() async {
    final token = await _storage.readToken();
    if (token == null) return null;
    try {
      final res = await _client.rpc('app_me', params: {'p_token': token});
      final user = AppUser.fromJson(Map<String, dynamic>.from(res as Map));
      await _storage.save(token, user);
      return user;
    } on PostgrestException catch (e) {
      if (e.message == 'SESSION_INVALID') {
        await _storage.clear();
        return null;
      }
      return _storage.readUser();
    } catch (_) {
      return _storage.readUser();
    }
  }

  Future<void> logout() async {
    final token = await _storage.readToken();
    if (token != null) {
      try {
        await _client.rpc('app_logout', params: {'p_token': token});
      } catch (_) {
        // Offline: sesi di server kedaluwarsa sendiri.
      }
    }
    await _storage.clear();
  }

  Future<Map<String, dynamic>> _call(
    String fn,
    Map<String, dynamic> params,
  ) async {
    try {
      final res = await _client.rpc(fn, params: params);
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      throw AuthException(e.message);
    } catch (_) {
      throw const AuthException('NETWORK');
    }
  }

  Future<AppUser> _saveSession(Map<String, dynamic> res) async {
    final user = AppUser.fromJson(
      Map<String, dynamic>.from(res['user'] as Map),
    );
    await _storage.save(res['token'] as String, user);
    return user;
  }

  Future<bool> isBiometricEnabled() => _storage.readBiometricEnabled();
  Future<void> setBiometricEnabled(bool value) =>
      _storage.saveBiometricEnabled(value);
}
