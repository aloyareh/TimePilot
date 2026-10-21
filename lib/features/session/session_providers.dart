import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/notifications/notification_service.dart';
import '../../data/local/models/task.dart';
import '../../data/local/models/work_session.dart';
import '../../data/repositories/work_session_repository.dart';
import '../blockchain/chain_repository.dart';
import '../profile/profile_providers.dart';
import '../tasks/task_providers.dart';
import 'session_money.dart';

final workSessionRepositoryProvider = Provider<WorkSessionRepository>(
  (ref) => WorkSessionRepository(),
);

/// Menit terlambat = selisih (dibulatkan ke bawah) antara mulai sesi dan jadwal.
/// Mulai sebelum/tepat jadwal = 0.
int computeLateMinutes({
  required DateTime startedUtc,
  required DateTime scheduledUtc,
}) {
  if (!startedUtc.isAfter(scheduledUtc)) return 0;
  return startedUtc.difference(scheduledUtc).inMinutes;
}

/// "01:05:09". Durasi negatif dianggap nol.
String formatHms(Duration d) {
  final x = d.isNegative ? Duration.zero : d;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(x.inHours)}:${two(x.inMinutes.remainder(60))}:${two(x.inSeconds.remainder(60))}';
}

/// Sesi kerja yang sedang berjalan (null jika tidak ada). Disimpan di Hive dengan
/// endedAtUtc == null sehingga tetap berjalan walau app ditutup.
class SessionNotifier extends Notifier<WorkSession?> {
  WorkSessionRepository get _repo => ref.read(workSessionRepositoryProvider);

  /// Sesi yang berjalan hanya dicari milik pengguna yang sedang login:
  /// WorkSession belum punya ownerId, jadi kepemilikan diturunkan dari tugasnya.
  /// Memantau currentUserIdProvider agar state ikut berganti saat akun berganti.
  @override
  WorkSession? build() {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return null;
    final tasks = ref.read(taskRepositoryProvider);
    for (final s in _repo.getAll()) {
      if (s.endedAtUtc != null) continue;
      if (tasks.getById(s.taskId)?.ownerId == uid) return s;
    }
    return null;
  }

  Future<WorkSession> start(Task task) async {
    if (state != null) throw StateError('Masih ada sesi yang berjalan.');
    final now = DateTime.now().toUtc();
    final session = WorkSession(
      id: const Uuid().v4(),
      taskId: task.id,
      clientId: task.clientId,
      startedAtUtc: now,
      lateMinutes: computeLateMinutes(
        startedUtc: now,
        scheduledUtc: task.deadlineUtc,
      ),
      updatedAt: now,
    );
    await _repo.save(session);
    await ref.read(tasksProvider.notifier).setStatus(task, TaskStatus.inProgress);
    state = session;
    return session;
  }

  /// Mengakhiri sesi, menyimpan durasi, dan (default) menandai tugas selesai.
  Future<WorkSession> stop({bool markDone = true}) async {
    final s = state;
    if (s == null) throw StateError('Tidak ada sesi yang berjalan.');
    final now = DateTime.now().toUtc();
    final finished = WorkSession(
      id: s.id,
      taskId: s.taskId,
      clientId: s.clientId,
      startedAtUtc: s.startedAtUtc,
      endedAtUtc: now,
      durationSeconds: now.difference(s.startedAtUtc).inSeconds,
      lateMinutes: s.lateMinutes,
      updatedAt: now,
    );
    await _repo.save(finished);
    state = null;
    // Catat ke blockchain (PBI-21). Kegagalan di sini tidak boleh membatalkan sesi.
    try {
      final client = ref.read(clientRepositoryProvider).getById(s.clientId);
      final money = computeSessionMoney(
        durationSeconds: finished.durationSeconds,
        lateMinutes: finished.lateMinutes,
        hourlyRate: client?.hourlyRate ?? 0,
        currency: client?.currency ?? 'IDR',
      );
      await ref.read(chainProvider.notifier).addForSession(finished, money);
    } catch (e) {
      logChainError(e);
    }
    ref.read(challengeClearedProvider.notifier).reset(s.taskId);
    if (markDone) {
      final task = ref.read(taskRepositoryProvider).getById(s.taskId);
      if (task != null) {
        await ref.read(tasksProvider.notifier).setStatus(task, TaskStatus.done);
      }
    }
    return finished;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, WorkSession?>(
  SessionNotifier.new,
);

/// Tugas yang tantangannya sudah selesai (membuka tombol Start). Disimpan di memori.
class ChallengeClearedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  /// Dipanggil saat tantangan sukses: membuka Start dan mematikan alarm yang berbunyi.
  Future<void> clear(String taskId) async {
    state = {...state, taskId};
    try {
      final svc = ref.read(notificationServiceProvider);
      await svc.init();
      await svc.cancel(taskAlarmId(taskId));
    } catch (_) {}
  }

  void reset(String taskId) => state = {...state}..remove(taskId);
}

final challengeClearedProvider =
    NotifierProvider<ChallengeClearedNotifier, Set<String>>(
      ChallengeClearedNotifier.new,
    );