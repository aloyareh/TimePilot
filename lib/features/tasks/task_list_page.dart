import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency_service.dart';
import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';
import '../../data/local/models/task.dart';
import 'task_form_page.dart';
import 'task_providers.dart';

/// Daftar tugas (Beranda). Bisa dipakai sebagai tab: punya Scaffold sendiri.
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final clients = ref.watch(clientsProvider);
    final home = ref.watch(homeZoneProvider);
    final byId = {for (final c in clients) c.id: c};

    return Scaffold(
      appBar: AppBar(title: const Text('Tugas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TaskFormPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Tugas baru'),
      ),
      body: tasks.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada tugas.\nKetuk "Tugas baru" untuk menambahkan.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: tasks.length,
              itemBuilder: (context, i) => _TaskCard(
                task: tasks[i],
                client: byId[tasks[i].clientId],
                homeZone: home,
              ),
            ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({
    required this.task,
    required this.client,
    required this.homeZone,
  });

  final Task task;
  final Client? client;
  final String homeZone;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus tugas?'),
        content: Text('"${task.title}" akan dihapus beserta alarmnya.'),
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
    if (ok == true) await ref.read(tasksProvider.notifier).remove(task.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final done = task.status == TaskStatus.done;
    final overdue = !done && task.deadlineUtc.isBefore(DateTime.now().toUtc());
    final clientZone = client?.timezoneId ?? homeZone;
    final dual = TimeService.dual(
      task.deadlineUtc,
      homeZone: homeZone,
      clientZone: clientZone,
    );
    final sameZone = clientZone == homeZone;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => TaskFormPage(task: task)),
        ),
        leading: Checkbox(
          value: done,
          onChanged: (v) => ref
              .read(tasksProvider.notifier)
              .setStatus(task, v == true ? TaskStatus.done : TaskStatus.todo),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client == null
                    ? 'Klien tidak ditemukan'
                    : '${client!.name} · '
                          '${formatMoney(client!.hourlyRate, client!.currency)}/jam',
              ),
              if (sameZone)
                Text(dual.home)
              else ...[
                Text('Klien: ${dual.client}'),
                Text('Kamu:  ${dual.home}'),
              ],
              if (overdue)
                Text(
                  'Terlewat',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Hapus',
          onPressed: () => _confirmDelete(context, ref),
        ),
      ),
    );
  }
}