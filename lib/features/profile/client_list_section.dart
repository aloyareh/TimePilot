import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';
import '../tasks/task_providers.dart';
import 'client_form_dialog.dart';

/// Daftar klien dengan CRUD (tambah, ubah, hapus). Dipakai di layar onboarding
/// persona dan di tab Profile. Berupa Column biasa: taruh di dalam ListView.
class ClientListSection extends ConsumerWidget {
  const ClientListSection({super.key, this.homeZone});

  final String? homeZone;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final c = await showDialog<Client>(
      context: context,
      builder: (_) => ClientFormDialog(homeZone: homeZone),
    );
    if (c != null) {
      await ref.read(clientsProvider.notifier).add(c);
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Client c) async {
    final updated = await showDialog<Client>(
      context: context,
      builder: (_) => ClientFormDialog(initial: c, homeZone: homeZone),
    );
    if (updated != null) {
      await ref.read(clientsProvider.notifier).add(updated);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Client c) async {
    final used = ref
        .read(tasksProvider)
        .where((t) => t.clientId == c.id)
        .length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus klien?'),
        content: Text(
          used == 0
              ? '"${c.name}" akan dihapus.'
              : '"${c.name}" dipakai $used tugas. Tugas tetap ada, tetapi '
                    'klien-nya akan tampil sebagai "tidak ditemukan".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(clientsProvider.notifier).remove(c.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Daftar Klien',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Tambah'),
            ),
          ],
        ),
        if (clients.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Belum ada klien. Tambahkan klien beserta zona waktu dan '
              'tarif per jamnya.',
            ),
          )
        else
          for (final c in clients)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onTap: () => _edit(context, ref, c),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.surfaceGray,
                  child: Icon(
                    Icons.business_center_outlined,
                    color: AppColors.navy,
                  ),
                ),
                title: Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${AppZones.label(c.timezoneId)} · '
                  '${formatMoney(c.hourlyRate, c.currency)}/jam',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Hapus',
                  onPressed: () => _delete(context, ref, c),
                ),
              ),
            ),
      ],
    );
  }
}
