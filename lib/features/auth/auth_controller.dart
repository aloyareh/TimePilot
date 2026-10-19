import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/biometric_service.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AppUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AppUser?> build() async {
    // Biometrik aktif: jangan masuk otomatis, paksa lewat layar login.
    if (await _repo.isBiometricEnabled()) return null;
    return _repo.restoreSession();
  }

  Future<void> loginWithBiometric() async {
    final bio = ref.read(biometricServiceProvider);
    if (!await bio.authenticate('Masuk ke Time Pilot')) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _repo.restoreSession();
      if (user == null) throw const AuthException('SESSION_INVALID');
      return user;
    });
  }

  Future<bool> enableBiometric() async {
    final bio = ref.read(biometricServiceProvider);
    if (!await bio.isAvailable()) return false;
    if (!await bio.authenticate('Aktifkan login biometrik')) return false;
    await _repo.setBiometricEnabled(true);
    return true;
  }

  Future<void> disableBiometric() => _repo.setBiometricEnabled(false);

  Future<void> register(
    String username,
    String password,
    String? fullName,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.register(
        username: username,
        password: password,
        fullName: fullName,
      ),
    );
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}
