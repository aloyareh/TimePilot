import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/time/time_service.dart';
import '../auth/auth_controller.dart';
import 'client_list_section.dart';
import 'profile_providers.dart';

class PersonaSetupPage extends ConsumerStatefulWidget {
  const PersonaSetupPage({super.key, required this.onboarding});

  final bool onboarding;

  @override
  ConsumerState<PersonaSetupPage> createState() => _PersonaSetupPageState();
}

class _PersonaSetupPageState extends ConsumerState<PersonaSetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _role;
  late String _homeZone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    _role = TextEditingController(text: p?.role ?? '');
    _homeZone = p?.homeTimezone ?? AppZones.wib;
  }

  @override
  void dispose() {
    _role.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(profileProvider.notifier)
          .save(role: _role.text, homeTimezone: _homeZone);
      if (!mounted) {
        return;
      }
      if (!widget.onboarding) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Persona disimpan.')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _header(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.blue],
        ),
        borderRadius: BorderRadius.circular(AppRadius.r24),
        boxShadow: AppShadows.medium,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.r16),
            ),
            child: const Icon(
              Icons.person_pin_circle_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Satu langkah lagi',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Isi pekerjaanmu dan tambahkan klien agar jadwal dan tarif '
                  'bisa dihitung dengan benar.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r24),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onboarding = widget.onboarding;
    return PopScope(
      canPop: !onboarding,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !onboarding,
          title: Text(onboarding ? 'Atur User Persona' : 'Ubah Persona'),
          actions: [
            if (onboarding)
              TextButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Keluar'),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              if (onboarding) ...[
                _header(theme),
                const SizedBox(height: AppSpacing.s16),
              ],
              _sectionCard(
                title: 'Profil Pekerjaan',
                children: [
                  TextFormField(
                    controller: _role,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Pekerjaan',
                      hintText: 'Contoh: Web Developer, UI Designer',
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Pekerjaan wajib diisi.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  DropdownButtonFormField<String>(
                    initialValue: _homeZone,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Zona waktu kamu',
                      prefixIcon: Icon(Icons.public),
                    ),
                    items: [
                      for (final z in AppZones.all)
                        DropdownMenuItem(
                          value: z,
                          child: Text(AppZones.label(z)),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _homeZone = v ?? _homeZone),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              ClientListSection(homeZone: _homeZone),
              const SizedBox(height: AppSpacing.s24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(onboarding ? 'Simpan & Lanjut' : 'Simpan'),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],
          ),
        ),
      ),
    );
  }
}
