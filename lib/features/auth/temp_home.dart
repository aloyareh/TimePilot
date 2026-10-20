import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../blockchain/blockchain_page.dart';
import '../dev/alarm_spike_page.dart';
import '../tasks/task_list_page.dart';
import 'auth_controller.dart';
import 'biometric_toggle_tile.dart';

/// SEMENTARA: pengganti beranda sampai Bottom Navigation (PBI-05) masuk.
/// Hapus file ini setelah halaman asli tersambung ke AuthGate.
class TempHome extends ConsumerWidget {
  const TempHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Time Pilot')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(user?.fullName ?? user?.username ?? '-'),
            subtitle: Text('@${user?.username ?? '-'}'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: const Text('Daftar tugas'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TaskListPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Blockchain sesi'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BlockchainPage()),
            ),
          ),
          const BiometricToggleTile(),
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('Spike alarm (sementara)'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AlarmSpikePage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Keluar'),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}