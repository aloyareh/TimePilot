import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lock_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';
import '../../data/local/models/task.dart';
import '../profile/profile_providers.dart';
import '../tasks/task_providers.dart';
import 'challenge_registry.dart';
import 'session_providers.dart';
import 'session_summary_page.dart';
import '../../features/challenges/challenges_picker.dart';

class TaskSessionPage extends ConsumerWidget {
  const TaskSessionPage({
    super.key,
    required this.taskId,
    this.autoStart = false,
  });

  final String taskId;
  final bool autoStart;

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
      await LockScreen.leave();
    }
  }

  Future<void> _start(BuildContext context, WidgetRef ref, Task task) async {
    try {
      await ref.read(sessionProvider.notifier).start(task);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa memulai sesi. Selesaikan sesi lain dulu.'),
        ),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Akhiri'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final finished = await ref.read(sessionProvider.notifier).stop();
    if (!context.mounted) return;
    final client = ref
        .read(clientRepositoryProvider)
        .getById(finished.clientId);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SessionSummaryPage(session: finished, client: client),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.r24),
    boxShadow: AppShadows.soft,
  );

  Widget _infoBox(ThemeData theme, IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
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
    final type = ref.watch(assignedChallengeProvider(taskId));
    final difficulty = profile?.challengeDifficulty ?? 1;
    final available = challengeBuilders.containsKey(type);

    final children = <Widget>[
      Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: _cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                const Icon(
                  Icons.business_center_outlined,
                  size: 16,
                  color: AppColors.navInactive,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    client?.name ?? 'Klien tidak ditemukan',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.s24),
            if (clientZone == home)
              Text(dual.home, style: theme.textTheme.bodyMedium)
            else ...[
              Text('Klien: ${dual.client}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.s4),
              Text('Kamu:  ${dual.home}', style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.s16),
    ];

    if (runningHere) {
      final session = active;
      final late = session.lateMinutes > 0;
      children.addAll([
        Center(child: _ElapsedTimer(startedUtc: session.startedAtUtc)),
        const SizedBox(height: AppSpacing.s16),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: (late ? AppColors.error : AppColors.success).withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(AppRadius.r24),
            ),
            child: Text(
              late ? 'Terlambat ${session.lateMinutes} menit' : 'Tepat waktu',
              style: theme.textTheme.labelLarge?.copyWith(
                color: late ? AppColors.error : AppColors.success,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => _stop(context, ref),
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Akhiri sesi'),
        ),
      ]);
    } else if (runningElsewhere) {
      children.add(
        _infoBox(
          theme,
          Icons.info_outline,
          AppColors.warning,
          'Sesi untuk tugas lain sedang berjalan. Akhiri dulu sebelum memulai yang ini.',
        ),
      );
    } else if (task.status == TaskStatus.done) {
      children.add(
        _infoBox(
          theme,
          Icons.check_circle_outline,
          AppColors.success,
          'Tugas ini sudah selesai.',
        ),
      );
    } else {
      if (!cleared) {
        if (autoStart && available) {
          children.add(
            _RunOnce(
              onRun: () => _runChallenge(context, ref, type, difficulty),
            ),
          );
        }
        children.add(
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: _cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.r12),
                      ),
                      child: const Icon(
                        Icons.sports_esports_outlined,
                        color: AppColors.orange,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        'Tantangan: ${challengeLabel(type)}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  'Selesaikan tantangan ini untuk mematikan alarm dan membuka sesi kerja.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.s16),
                OutlinedButton.icon(
                  onPressed: available
                      ? () => _runChallenge(context, ref, type, difficulty)
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Mulai tantangan'),
                ),
                if (!available) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Tantangan ini belum tersedia di versi ini.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (!available || kDebugMode) ...[
                  const SizedBox(height: AppSpacing.s4),
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
        );
      } else {
        children.add(
          _infoBox(
            theme,
            Icons.check_circle_outline,
            AppColors.success,
            'Tantangan selesai. Alarm dimatikan.',
          ),
        );
      }
      children.addAll([
        const SizedBox(height: AppSpacing.s16),
        FilledButton.icon(
          onPressed: cleared ? () => _start(context, ref, task) : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Work Session'),
        ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sesi kerja')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: children,
        ),
      ),
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
        return Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.blue, width: 8),
            boxShadow: AppShadows.medium,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatHms(elapsed),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'Bekerja\u2026',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RunOnce extends StatefulWidget {
  const _RunOnce({required this.onRun});

  final VoidCallback onRun;

  @override
  State<_RunOnce> createState() => _RunOnceState();
}

class _RunOnceState extends State<_RunOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRun();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
