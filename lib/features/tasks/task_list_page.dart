import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency_service.dart';
import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';
import '../../data/local/models/task.dart';
import '../session/task_session_page.dart';
import 'task_form_page.dart';
import 'task_providers.dart';

/// Daftar tugas (Beranda) dengan pencarian dan filter. Punya Scaffold sendiri,
/// jadi bisa dipasang sebagai tab bottom navigation.
class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({super.key});

  @override
  ConsumerState<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends ConsumerState<TaskListPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String?>(
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(tasksProvider);
    final tasks = ref.watch(filteredTasksProvider);
    final clients = ref.watch(clientsProvider);
    final filter = ref.watch(taskFilterProvider);
    final home = ref.watch(homeZoneProvider);
    final byId = {for (final c in clients) c.id: c};
    final notifier = ref.read(taskFilterProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Tugas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TaskFormPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Tugas baru'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: notifier.setQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Cari tugas atau klien…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: filter.query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              notifier.setQuery('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _dropdown(
                      label: 'Status',
                      value: filter.status,
                      onChanged: notifier.setStatus,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Semua')),
                        DropdownMenuItem(value: TaskStatus.todo, child: Text('Belum')),
                        DropdownMenuItem(
                          value: TaskStatus.inProgress,
                          child: Text('Berjalan'),
                        ),
                        DropdownMenuItem(value: TaskStatus.done, child: Text('Selesai')),
                      ],
                    ),
                    _dropdown(
                      label: 'Klien',
                      value: filter.clientId,
                      onChanged: notifier.setClient,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Semua')),
                        for (final c in clients)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                    ),
                    _dropdown(
                      label: 'Mata uang',
                      value: filter.currency,
                      onChanged: notifier.setCurrency,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Semua')),
                        for (final c in Currencies.all)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            all.isEmpty
                                ? 'Belum ada tugas.\nKetuk "Tugas baru" untuk menambahkan.'
                                : 'Tidak ada tugas yang cocok.',
                            textAlign: TextAlign.center,
                          ),
                          if (filter.isActive) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                _search.clear();
                                notifier.reset();
                              },
                              child: const Text('Reset filter'),
                            ),
                          ],
                        ],
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
          ),
        ],
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
    final running = task.status == TaskStatus.inProgress;
    final overdue = task.status == TaskStatus.todo &&
        task.deadlineUtc.isBefore(DateTime.now().toUtc());
    final clientZone = client?.timezoneId ?? homeZone;
    final dual = TimeService.dual(
      task.deadlineUtc,
      homeZone: homeZone,
      clientZone: clientZone,
    );
    final sameZone = clientZone == homeZone;
    final c = client;

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
                c == null
                    ? 'Klien tidak ditemukan'
                    : '${c.name} · ${formatMoney(c.hourlyRate, c.currency)}/jam',
              ),
              if (sameZone)
                Text(dual.home)
              else ...[
                Text('Klien: ${dual.client}'),
                Text('Kamu:  ${dual.home}'),
              ],
              if (running)
                Text(
                  'Sedang berjalan',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!done)
              IconButton(
                icon: Icon(
                  running ? Icons.timer : Icons.play_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                tooltip: running ? 'Buka timer' : 'Mulai sesi',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TaskSessionPage(taskId: task.id),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}