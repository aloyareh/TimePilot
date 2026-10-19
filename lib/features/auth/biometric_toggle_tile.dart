import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

class BiometricToggleTile extends ConsumerStatefulWidget {
  const BiometricToggleTile({super.key});

  @override
  ConsumerState<BiometricToggleTile> createState() =>
      _BiometricToggleTileState();
}

class _BiometricToggleTileState extends ConsumerState<BiometricToggleTile> {
  bool? _enabled; // null = masih memuat
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await ref.read(authRepositoryProvider).isBiometricEnabled();
    if (!mounted) return;
    setState(() => _enabled = enabled);
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    final ctrl = ref.read(authControllerProvider.notifier);
    var result = value;
    if (value) {
      result = await ctrl.enableBiometric();
      if (!result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometrik tidak tersedia, belum didaftarkan di HP, atau dibatalkan.',
            ),
          ),
        );
      }
    } else {
      await ctrl.disableBiometric();
    }
    if (!mounted) return;
    setState(() {
      _enabled = result;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint),
      title: const Text('Login biometrik'),
      subtitle: const Text('Masuk dengan sidik jari / wajah, bukan password.'),
      value: _enabled ?? false,
      onChanged: (_enabled == null || _busy) ? null : _toggle,
    );
  }
}