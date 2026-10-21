import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/time_service.dart';
import '../auth/auth_controller.dart';
import 'client_list_section.dart';
import 'profile_providers.dart';

/// Form User Persona: Pekerjaan (wajib), zona waktu rumah, dan daftar klien.
///
/// [onboarding] = true: dipakai setelah registrasi lewat PersonaGate. Tidak
/// bisa dilewati / ditutup sebelum Pekerjaan disimpan. Setelah tersimpan,
/// PersonaGate otomatis berpindah ke aplikasi utama.
/// [onboarding] = false: mode ubah dari tab Profile.
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
      // Onboarding: PersonaGate melihat profil terisi dan pindah sendiri.
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: const Text(
                  'Keluar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (onboarding) ...[
                Text(
                  'Satu langkah lagi',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Isi pekerjaanmu dan tambahkan klien agar jadwal dan tarif '
                  'bisa dihitung dengan benar.',
                ),
                const SizedBox(height: 20),
              ],
              TextFormField(
                controller: _role,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Pekerjaan',
                  hintText: 'Contoh: Web Developer, UI Designer',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Pekerjaan wajib diisi.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _homeZone,
                decoration: const InputDecoration(
                  labelText: 'Zona waktu kamu',
                  prefixIcon: Icon(Icons.public),
                ),
                items: [
                  for (final z in AppZones.all)
                    DropdownMenuItem(value: z, child: Text(AppZones.label(z))),
                ],
                onChanged: (v) => setState(() => _homeZone = v ?? _homeZone),
              ),
              const SizedBox(height: 24),
              ClientListSection(homeZone: _homeZone),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(onboarding ? 'Simpan & Lanjut' : 'Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
