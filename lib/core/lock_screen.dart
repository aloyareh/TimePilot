import 'package:flutter/services.dart';

/// Jembatan ke MainActivity.kt untuk alur alarm di atas layar kunci.
class LockScreen {
  static const _channel = MethodChannel('time_pilot/lockscreen');

  /// Dipanggil setelah tantangan alarm selesai. Bila HP masih terkunci, Android
  /// meminta buka kunci (PIN/sidik jari); jika dibatalkan, app disembunyikan di
  /// belakang layar kunci. Bila layar sudah terbuka, tidak berbuat apa-apa.
  static Future<void> leave() async {
    try {
      await _channel.invokeMethod<void>('leave');
    } catch (_) {
      // Platform tanpa implementasi (mis. tes): abaikan.
    }
  }
}