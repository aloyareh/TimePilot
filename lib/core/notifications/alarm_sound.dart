import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Suara alarm hasil impor pengguna. [uri] adalah alamat `content://` di
/// MediaStore (folder Alarms), supaya bisa dibaca sistem saat alarm berbunyi.
class AlarmSound {
  const AlarmSound({required this.uri, required this.name});

  final String uri;
  final String name;

  Map<String, dynamic> toJson() => {'uri': uri, 'name': name};

  factory AlarmSound.fromJson(Map<String, dynamic> json) =>
      AlarmSound(uri: json['uri'] as String, name: json['name'] as String);

  /// Bagian akhir alamat (id MediaStore), dipakai untuk nama channel notifikasi.
  String get channelSuffix =>
      uri.split('/').last.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
}

/// Pilihan suara disimpan per perangkat (channel notifikasi memang per
/// perangkat), bukan per akun.
class AlarmSoundStore {
  const AlarmSoundStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _key = 'alarm_sound';

  Future<AlarmSound?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      return AlarmSound.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(AlarmSound? sound) => sound == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: jsonEncode(sound.toJson()));
}

final alarmSoundStoreProvider = Provider<AlarmSoundStore>(
  (ref) => const AlarmSoundStore(),
);

/// Jembatan ke MainActivity.kt (channel "time_pilot/alarm_sound").
abstract class AlarmSoundChannel {
  static const _channel = MethodChannel('time_pilot/alarm_sound');

  /// Membuka pemilih file audio sistem, menyalin pilihan ke MediaStore, lalu
  /// mengembalikan hasilnya. null = dibatalkan. Gagal -> PlatformException.
  static Future<AlarmSound?> pickAndImport() async {
    final res = await _channel.invokeMapMethod<String, String>('pickAndImport');
    if (res == null) return null;
    return AlarmSound(uri: res['uri']!, name: res['name']!);
  }

  static Future<void> preview(String uri) =>
      _channel.invokeMethod<void>('preview', {'uri': uri});

  static Future<void> stopPreview() =>
      _channel.invokeMethod<void>('stopPreview');

  /// Menghapus file hasil impor dari MediaStore (hanya milik app ini).
  static Future<void> remove(String uri) async {
    try {
      await _channel.invokeMethod<void>('remove', {'uri': uri});
    } catch (_) {}
  }
}