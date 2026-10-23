import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/sync_service.dart';
import 'persona_setup_page.dart';
import 'profile_providers.dart';

/// Memaksa pengguna mengisi User Persona sebelum masuk ke aplikasi
/// (PBI-03 / PBI-07: setelah register wajib set persona, tidak bisa dilewati).
/// Letakkan di dalam AuthGate dan SyncLifecycle:
/// AuthGate(child: SyncLifecycle(child: PersonaGate(child: MainShell()))).
class PersonaGate extends ConsumerWidget {
  const PersonaGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (profile == null || profile.role.trim().isEmpty) {
      // Di perangkat baru profil belum ada di HP tapi mungkin sudah ada di server.
      // Tunggu sinkron pertama selesai (berhasil atau gagal) sebelum meminta persona.
      final sync = ref.watch(syncProvider);
      final firstSyncPending = sync.lastSyncAt == null && sync.error == null;
      if (firstSyncPending) {
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Menyiapkan akun…'),
              ],
            ),
          ),
        );
      }
      return const PersonaSetupPage(onboarding: true);
    }
    return child;
  }
}
