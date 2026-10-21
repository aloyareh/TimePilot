import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency_service.dart';
import '../../data/local/models/profile.dart';
import '../../data/remote/persona_remote.dart';
import '../../data/repositories/profile_repository.dart';
import '../auth/auth_controller.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(),
);

/// ID pengguna yang sedang login (null = belum login / sudah logout).
/// Provider data lokal (profil, klien, tugas) memantau ini sehingga daftarnya
/// otomatis berganti saat akun berganti.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider.select((a) => a.value?.id)),
);

/// Profil (User Persona) milik pengguna yang sedang login.
/// null = belum mengisi persona -> PersonaGate menampilkan layar onboarding.
class ProfileNotifier extends Notifier<Profile?> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Profile? build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return null;
    }
    return _repo.getByUserId(userId);
  }

  /// Simpan Pekerjaan & zona waktu rumah. Field lain (jam kerja, tantangan,
  /// mata uang utama) mempertahankan nilai lama atau default.
  Future<void> save({
    required String role,
    required String homeTimezone,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      throw StateError('Belum login.');
    }
    final old = state;
    final profile = Profile(
      id: userId,
      role: role.trim(),
      homeTimezone: homeTimezone,
      mainCurrency: old?.mainCurrency ?? Currencies.idr,
      workStartMinutes: old?.workStartMinutes ?? 9 * 60,
      workEndMinutes: old?.workEndMinutes ?? 17 * 60,
      challengeType: old?.challengeType ?? ChallengeType.shake,
      challengeDifficulty: old?.challengeDifficulty ?? 1,
      updatedAt: DateTime.now().toUtc(),
    );
    await _repo.save(profile);
    state = profile;
    ref.read(personaRemoteProvider).pushProfile(profile); // best-effort
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, Profile?>(
  ProfileNotifier.new,
);
