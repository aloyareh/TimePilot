import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency/currency_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';
import '../../data/local/models/task.dart';
import '../auth/auth_controller.dart';
import '../blockchain/blockchain_page.dart';
import '../cafes/cafe_entry_card.dart';
import '../earnings/earnings_page.dart';
import '../earnings/earnings_providers.dart';
import '../profile/persona_setup_page.dart';
import '../profile/profile_providers.dart';
import '../session/task_session_page.dart';
import 'task_form_page.dart';
import 'task_providers.dart';

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

  Widget _brand(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.navy, AppColors.blue],
            ),
            borderRadius: BorderRadius.circular(AppRadius.r8),
          ),
          child: const Icon(
            Icons.navigation_rounded,
            size: 20,
            color: AppColors.orange,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Text.rich(
          TextSpan(
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            children: const [
              TextSpan(
                text: 'Time',
                style: TextStyle(color: AppColors.navy),
              ),
              TextSpan(
                text: 'Pilot',
                style: TextStyle(color: AppColors.orange),
              ),
            ],
          ),
        ),
      ],
    );
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

  Widget _filters(
    TaskFilter filter,
    TaskFilterNotifier notifier,
    List<Client> clients,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s16,
        0,
      ),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: notifier.setQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari tugas atau klien\u2026',
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
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              _dropdown(
                label: 'Status',
                value: filter.status,
                onChanged: notifier.setStatus,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Semua')),
                  DropdownMenuItem(
                    value: TaskStatus.todo,
                    child: Text('Belum'),
                  ),
                  DropdownMenuItem(
                    value: TaskStatus.inProgress,
                    child: Text('Berjalan'),
                  ),
                  DropdownMenuItem(
                    value: TaskStatus.done,
                    child: Text('Selesai'),
                  ),
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
    );
  }

  Widget _empty(bool noTasks, TaskFilter filter, TaskFilterNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: 56,
            color: AppColors.navInactive,
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            noTasks
                ? 'Belum ada tugas.\nKetuk "Tugas baru" untuk menambahkan.'
                : 'Tidak ada tugas yang cocok.',
            textAlign: TextAlign.center,
          ),
          if (filter.isActive) ...[
            const SizedBox(height: AppSpacing.s12),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(tasksProvider);
    final tasks = ref.watch(filteredTasksProvider);
    final clients = ref.watch(clientsProvider);
    final filter = ref.watch(taskFilterProvider);
    final home = ref.watch(homeZoneProvider);
    final byId = {for (final c in clients) c.id: c};
    final notifier = ref.read(taskFilterProvider.notifier);

    return Scaffold(
      appBar: AppBar(titleSpacing: AppSpacing.s16, title: _brand(theme)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const TaskFormPage())),
        icon: const Icon(Icons.add),
        label: const Text('Tugas baru'),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _DashboardHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s24,
                AppSpacing.s16,
                0,
              ),
              child: Row(
                children: [
                  Text('Daftar Tugas', style: theme.textTheme.titleMedium),
                  const SizedBox(width: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _filters(filter, notifier, clients)),
          if (tasks.isEmpty)
            SliverToBoxAdapter(
              child: Center(child: _empty(all.isEmpty, filter, notifier)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s12,
                AppSpacing.s16,
                88,
              ),
              sliver: SliverList.builder(
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

class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader();

  String _duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h == 0 ? '${m}m' : '${h}j ${m}m';
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).value;
    final profile = ref.watch(profileProvider);
    final tasks = ref.watch(tasksProvider);
    final earnings = ref.watch(earningsProvider);
    final idrPerUsd = ref.watch(ratesProvider).value?.perUsd['IDR'];

    final name = (user?.fullName ?? user?.username ?? '').trim();
    final done = tasks.where((t) => t.status == TaskStatus.done).length;
    final seconds = earnings.fold<int>(0, (a, e) => a + e.totalSeconds);
    final late = earnings.fold<int>(0, (a, e) => a + e.lateMinutes);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Halo kembali,', style: theme.textTheme.bodySmall),
          Text(
            name.isEmpty ? 'Selamat Datang' : 'Selamat Datang, $name',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.s16),
          const CafeEntryCard(),
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.r24),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ringkasan Statistik', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.check_rounded,
                        color: AppColors.success,
                        label: 'Tugas Selesai',
                        value: '$done / ${tasks.length}',
                        unit: 'Tugas',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.schedule_rounded,
                        color: AppColors.error,
                        label: 'Keterlambatan',
                        value: '$late',
                        unit: 'Menit',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.timer_outlined,
                        color: AppColors.blue,
                        label: 'Waktu Kerja',
                        value: _duration(seconds),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.currency_exchange_rounded,
                        color: AppColors.warning,
                        label: 'Kurs 1 USD',
                        value: idrPerUsd == null
                            ? '-'
                            : formatMoney(idrPerUsd, Currencies.idr),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          Text('Menu Utama', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              Expanded(
                child: _MenuTile(
                  icon: Icons.add_rounded,
                  color: AppColors.blue,
                  title: 'Tambah Tugas',
                  subtitle: 'Buat rencana',
                  onTap: () => _push(context, const TaskFormPage()),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: _MenuTile(
                  icon: Icons.payments_outlined,
                  color: AppColors.success,
                  title: 'Pendapatan',
                  subtitle: 'Terkunci biometrik',
                  onTap: () => _push(context, const EarningsPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              Expanded(
                child: _MenuTile(
                  icon: Icons.person_outline_rounded,
                  color: AppColors.orange,
                  title: 'Atur Persona',
                  subtitle: (profile?.role ?? '').isEmpty
                      ? 'Profil kerja'
                      : profile!.role,
                  onTap: () =>
                      _push(context, const PersonaSetupPage(onboarding: false)),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: _MenuTile(
                  icon: Icons.link_rounded,
                  color: AppColors.navy,
                  title: 'Blockchain',
                  subtitle: 'Verifikasi data',
                  onTap: () => _push(context, const BlockchainPage()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.r12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text.rich(
                  TextSpan(
                    text: value,
                    style: theme.textTheme.titleSmall,
                    children: [
                      if (unit != null)
                        TextSpan(
                          text: ' $unit',
                          style: theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.r16);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          boxShadow: AppShadows.soft,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.r12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
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
    final overdue =
        task.status == TaskStatus.todo &&
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
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
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
          style: theme.textTheme.titleSmall?.copyWith(
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? AppColors.navInactive : AppColors.navy,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c == null
                    ? 'Klien tidak ditemukan'
                    : '${c.name} \u00B7 ${formatMoney(c.hourlyRate, c.currency)}/jam',
                style: theme.textTheme.bodySmall,
              ),
              if (sameZone)
                Text(dual.home, style: theme.textTheme.bodySmall)
              else ...[
                Text('Klien: ${dual.client}', style: theme.textTheme.bodySmall),
                Text('Kamu:  ${dual.home}', style: theme.textTheme.bodySmall),
              ],
              if (running)
                Text(
                  'Sedang berjalan',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (overdue)
                Text(
                  'Terlewat',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.error,
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
                  color: AppColors.blue,
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
              color: AppColors.navInactive,
              tooltip: 'Hapus',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
