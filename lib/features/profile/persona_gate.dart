import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persona_setup_page.dart';
import 'profile_providers.dart';

/// Memaksa pengguna mengisi User Persona sebelum masuk ke aplikasi
/// (PBI-03 / PBI-07: setelah register wajib set persona, tidak bisa dilewati).
/// Letakkan di dalam AuthGate: AuthGate(child: PersonaGate(child: MainShell())).
class PersonaGate extends ConsumerWidget {
  const PersonaGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (profile == null || profile.role.trim().isEmpty) {
      return const PersonaSetupPage(onboarding: true);
    }
    return child;
  }
}
