import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'biometric_provider.dart';

class BiometricToggleTile extends ConsumerStatefulWidget {
  const BiometricToggleTile({super.key});

  @override
  ConsumerState<BiometricToggleTile> createState() =>
      _BiometricToggleTileState();
}

class _BiometricToggleTileState extends ConsumerState<BiometricToggleTile> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    final ctrl = ref.read(biometricEnabledProvider.notifier);
    if (value) {
      final ok = await ctrl.enable();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometrik tidak tersedia, belum didaftarkan di HP, atau dibatalkan.',
            ),
          ),
        );
      }
    } else {
      await ctrl.disable();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(biometricEnabledProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint),
      title: const Text('Biometrik'),
      subtitle: const Text(
        'Aktifkan untuk Login dan buka halaman Pendapatan dengan biometrik',
      ),
      value: enabled.value ?? false,
      onChanged: (enabled.isLoading || _busy) ? null : _toggle,
    );
  }
}