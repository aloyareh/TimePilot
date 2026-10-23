import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';
import '../tasks/task_providers.dart';
import 'client_form_dialog.dart';

class ClientListSection extends ConsumerStatefulWidget {
  const ClientListSection({
    super.key,
    this.homeZone,
    this.editable = true,
    this.maxVisible,
  });

  final String? homeZone;
  final bool editable;
  final int? maxVisible;

  @override
  ConsumerState<ClientListSection> createState() => _ClientListSectionState();
}

class _ClientListSectionState extends ConsumerState<ClientListSection> {
  bool _expanded = false;

  Future<void> _add() async {
    final c = await showDialog<Client>(
      context: context,
      builder: (_) => ClientFormDialog(homeZone: widget.homeZone),
    );
    if (c != null) {
      await ref.read(clientsProvider.notifier).add(c);
    }
  }

  Future<void> _edit(Client c) async {
    final updated = await showDialog<Client>(
      context: context,
      builder: (_) => ClientFormDialog(initial: c, homeZone: widget.homeZone),
    );
    if (updated != null) {
      await ref.read(clientsProvider.notifier).add(updated);
    }
  }

  Future<void> _delete(Client c) async {
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clients = ref.watch(clientsProvider);
    final limit = widget.maxVisible;
    final hasMore = limit != null && clients.length > limit;
    final shown = (hasMore && !_expanded)
        ? clients.take(limit).toList()
        : clients;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r24),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Daftar Klien', style: theme.textTheme.titleMedium),
              const SizedBox(width: AppSpacing.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                ),
                child: Text(
                  '${clients.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.editable)
                TextButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Tambah'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          if (clients.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.r16),
              ),
              child: Text(
                widget.editable
                    ? 'Belum ada klien. Tambahkan klien beserta zona waktu dan '
                          'tarif per jamnya.'
                    : 'Belum ada klien. Tekan Ubah persona untuk menambahkan klien.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            for (final c in shown)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.r16),
                ),
                child: ListTile(
                  onTap: widget.editable ? () => _edit(c) : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                  ),
                  leading: const Icon(
                    Icons.handshake_outlined,
                    color: AppColors.navInactive,
                  ),
                  title: Text(c.name, style: theme.textTheme.titleSmall),
                  subtitle: Text(
                    '${AppZones.label(c.timezoneId)} \u00B7 '
                    '${formatMoney(c.hourlyRate, c.currency)}/jam',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: widget.editable
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: AppColors.navInactive,
                          tooltip: 'Hapus',
                          onPressed: () => _delete(c),
                        )
                      : null,
                ),
              ),
          if (hasMore)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded
                      ? 'Tampilkan lebih sedikit'
                      : 'Lihat selengkapnya (${clients.length - limit} lagi)',
                ),
              ),
            ),
        ],
      ),
    );
  }
}