import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';
import '../../data/local/models/profile.dart';
import '../../data/local/models/task.dart';
import '../profile/profile_providers.dart';
import '../tasks/task_providers.dart';
import 'challenge_registry.dart';
import 'session_providers.dart';
import 'session_summary_page.dart';

/// Pusat alur: alarm -> tantangan -> Start Work Session -> timer -> Stop.
/// Dibuka dari ketukan notifikasi atau tombol Mulai di kartu tugas.
class TaskSessionPage extends ConsumerWidget {
  const TaskSessionPage({super.key, required this.taskId});

  final String taskId;

  Future<void> _runChallenge(
    BuildContext context,
    WidgetRef ref,
    String type,
    int difficulty,
  ) async {
    final builder = challengeBuilders[type];
    if (builder == null) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (ctx) => builder(ctx, difficulty)),
    );
    if (ok == true) {
      await ref.read(challengeClearedProvider.notifier).clear(taskId);
    }
  }

  Future<void> _start(BuildContext context, WidgetRef ref, Task task) async {
    try {
      await ref.read(sessionProvider.notifier).start(task);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa memulai sesi. Selesaikan sesi lain dulu.')),
      );
    }
  }

  Future<void> _stop(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Akhiri sesi?'),
        content: const Text('Timer dihentikan dan tugas ditandai selesai.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Lanjut kerja'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Akhiri'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final finished = await ref.read(sessionProvider.notifier).stop();
    if (!context.mounted) return;
    final client = ref.read(clientRepositoryProvider).getById(finished.clientId);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SessionSummaryPage(session: finished, client: client),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final taskMatches = ref.watch(tasksProvider).where((t) => t.id == taskId);
    if (taskMatches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sesi kerja')),
        body: const Center(child: Text('Tugas tidak ditemukan.')),
      );
    }
    final task = taskMatches.first;

    final clientMatches = ref
        .watch(clientsProvider)
        .where((c) => c.id == task.clientId);
    final Client? client = clientMatches.isEmpty ? null : clientMatches.first;
    final home = ref.watch(homeZoneProvider);
    final clientZone = client?.timezoneId ?? home;
    final dual = TimeService.dual(
      task.deadlineUtc,
      homeZone: home,
      clientZone: clientZone,
    );

    final active = ref.watch(sessionProvider);
    final runningHere = active != null && active.taskId == taskId;
    final runningElsewhere = active != null && !runningHere;
    final cleared = ref.watch(challengeClearedProvider).contains(taskId);

    final profile = ref.watch(profileProvider);
    final type = profile?.challengeType ?? ChallengeType.shake;
    final difficulty = profile?.challengeDifficulty ?? 1;
    final available = challengeBuilders.containsKey(type);

    final children = <Widget>[
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(client?.name ?? 'Klien tidak ditemukan'),
              const SizedBox(height: 8),
              if (clientZone == home)
                Text(dual.home)
              else ...[
                Text('Klien: ${dual.client}'),
                Text('Kamu:  ${dual.home}'),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];

    if (runningHere) {
      final session = active;
      children.addAll([
        Center(child: _ElapsedTimer(startedUtc: session.startedAtUtc)),
        const SizedBox(height: 8),
        Center(
          child: Text(
            session.lateMinutes > 0
                ? 'Terlambat ${session.lateMinutes} menit'
                : 'Tepat waktu',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _stop(context, ref),
          icon: const Icon(Icons.stop),
          label: const Text('Akhiri sesi'),
        ),
      ]);
    } else if (runningElsewhere) {
      children.add(
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sesi untuk tugas lain sedang berjalan. Akhiri dulu sebelum memulai yang ini.'),
          ),
        ),
      );
    } else if (task.status == TaskStatus.done) {
      children.add(const Center(child: Text('Tugas ini sudah selesai.')));
    } else {
      if (!cleared) {
        children.add(
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selesaikan tantangan "${challengeLabel(type)}" untuk mematikan alarm dan membuka sesi kerja.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: available
                        ? () => _runChallenge(context, ref, type, difficulty)
                        : null,
                    icon: const Icon(Icons.sports_esports),
                    label: const Text('Mulai tantangan'),
                  ),
                  if (!available) ...[
                    const SizedBox(height: 8),
                    const Text('Tantangan ini belum tersedia di versi ini.'),
                  ],
                  if (!available || kDebugMode) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref
                          .read(challengeClearedProvider.notifier)
                          .clear(taskId),
                      child: const Text('Lewati tantangan (sementara)'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      } else {
        children.add(
          Row(
            children: [
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('Tantangan selesai. Alarm dimatikan.')),
            ],
          ),
        );
      }
      children.addAll([
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: cleared ? () => _start(context, ref, task) : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Work Session'),
        ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sesi kerja')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: children)),
    );
  }
}

class _ElapsedTimer extends StatelessWidget {
  const _ElapsedTimer({required this.startedUtc});

  final DateTime startedUtc;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now().toUtc(),
      ),
      initialData: DateTime.now().toUtc(),
      builder: (context, snap) {
        final elapsed = snap.data!.difference(startedUtc);
        return Text(
          formatHms(elapsed),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}