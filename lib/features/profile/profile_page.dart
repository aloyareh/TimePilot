import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/time/time_service.dart';
import '../auth/auth_controller.dart';
import '../auth/biometric_toggle_tile.dart';
import '../dev/alarm_spike_page.dart';
import 'client_list_section.dart';
import 'persona_setup_page.dart';
import 'profile_avatar.dart';
import 'profile_providers.dart';

/// Tab Profile (PBI-07): info akun, persona (pekerjaan, zona waktu),
/// CRUD klien, dan pengaturan biometrik.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ProfileAvatar(radius: 32, editable: true),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? user?.username ?? '-',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text('@${user?.username ?? '-'}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _InfoRow(
                    icon: Icons.work_outline,
                    label: 'Pekerjaan',
                    value: profile?.role ?? '-',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.public,
                    label: 'Zona waktu',
                    value: profile == null
                        ? '-'
                        : AppZones.label(profile.homeTimezone),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const PersonaSetupPage(onboarding: false),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Ubah persona'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ClientListSection(homeZone: profile?.homeTimezone),
          const SizedBox(height: 12),
          const Divider(),
          const BiometricToggleTile(),
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.alarm),
              title: const Text('Spike alarm (dev)'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AlarmSpikePage()),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.navInactive),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.navInactive)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
