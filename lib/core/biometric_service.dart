import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

class BiometricService {
  BiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Untuk gerbang halaman sensitif (Pendapatan): sidik jari/wajah, atau PIN/pola
  /// layar kunci HP sebagai cadangan. Gagal-tertutup: false jika dibatalkan,
  /// gagal, atau HP tidak punya biometrik maupun layar kunci.
  Future<bool> authenticateWithDeviceFallback(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> guard(String reason) async =>
      await isAvailable() ? authenticate(reason) : true;
}