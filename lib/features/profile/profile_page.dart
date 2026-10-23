import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/time/time_service.dart';
import '../auth/auth_controller.dart';
import '../auth/biometric_toggle_tile.dart';
import '../blockchain/blockchain_page.dart';
import 'client_list_section.dart';
import 'persona_setup_page.dart';
import 'profile_avatar.dart';
import 'profile_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.r24),
    boxShadow: AppShadows.soft,
  );

  void _openPersona(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const PersonaSetupPage(onboarding: false),
    ),
  );

  void _openBlockchain(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const BlockchainPage()));

  Widget _personaCard(
    BuildContext context,
    ThemeData theme,
    String role,
    String zone,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_ind_outlined,
                color: AppColors.navInactive,
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Persona', style: theme.textTheme.bodySmall),
                    Text(role, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.s24),
          _InfoRow(
            icon: Icons.business_center_outlined,
            label: 'Pekerjaan',
            value: role,
          ),
          const SizedBox(height: AppSpacing.s12),
          _InfoRow(icon: Icons.schedule, label: 'Zona waktu', value: zone),
          const SizedBox(height: AppSpacing.s16),
          OutlinedButton.icon(
            onPressed: () => _openPersona(context),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Ubah persona'),
          ),
        ],
      ),
    );
  }

  Widget _blockchainCard(BuildContext context, ThemeData theme) {
    return Container(
      decoration: _cardDecoration,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.r24),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => _openBlockchain(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s4,
          ),
          leading: const Icon(Icons.link, color: AppColors.navInactive),
          title: Text('Blockchain Sesi', style: theme.textTheme.titleSmall),
          subtitle: Text(
            'Verifikasi riwayat jam kerja',
            style: theme.textTheme.bodySmall,
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.navInactive,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).value;
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: _cardDecoration,
            child: Row(
              children: [
                const ProfileAvatar(radius: 32, editable: true),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? user?.username ?? '-',
                        style: theme.textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${user?.username ?? '-'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          _personaCard(
            context,
            theme,
            profile?.role ?? '-',
            profile == null ? '-' : AppZones.label(profile.homeTimezone),
          ),
          const SizedBox(height: AppSpacing.s16),
          ClientListSection(
            homeZone: profile?.homeTimezone,
            editable: false,
            maxVisible: 3,
          ),
          const SizedBox(height: AppSpacing.s16),
          _blockchainCard(context, theme),
          const SizedBox(height: AppSpacing.s16),
          Container(
            decoration: _cardDecoration,
            clipBehavior: Clip.antiAlias,
            child: const BiometricToggleTile(),
          ),
          const SizedBox(height: AppSpacing.s16),
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
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.navInactive),
        const SizedBox(width: AppSpacing.s12),
        Text(label, style: theme.textTheme.bodySmall),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}