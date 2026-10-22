import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_providers.dart';
import 'auth_controller.dart';

/// Status "biometrik sudah didaftarkan di aplikasi" (saklar di Profil), dipakai
/// bersama oleh tile Profil dan halaman Pendapatan supaya selalu sama.
/// Flag dihapus saat logout, jadi state dibangun ulang saat akun berganti.
class BiometricEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    ref.watch(currentUserIdProvider);
    return ref.read(authRepositoryProvider).isBiometricEnabled();
  }

  /// Meminta verifikasi biometrik; bila berhasil, saklar menjadi aktif.
  Future<bool> enable() async {
    final ok = await ref.read(authControllerProvider.notifier).enableBiometric();
    if (ok) state = const AsyncData(true);
    return ok;
  }

  Future<void> disable() async {
    await ref.read(authControllerProvider.notifier).disableBiometric();
    state = const AsyncData(false);
  }
}

final biometricEnabledProvider =
    AsyncNotifierProvider<BiometricEnabledNotifier, bool>(
      BiometricEnabledNotifier.new,
    );