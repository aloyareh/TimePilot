import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';
import '../../data/local/models/task.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(),
);
final clientRepositoryProvider = Provider<ClientRepository>(
  (ref) => ClientRepository(),
);

/// Zona waktu rumah pengguna. Sampai halaman Profil (PBI-07) ada: WIB.
final homeZoneProvider = Provider<String>(
  (ref) => ProfileRepository().getCurrent()?.homeTimezone ?? AppZones.wib,
);

/// ID notifikasi yang stabil dari ID tugas (uuid) -> int 28-bit.
int taskAlarmId(String taskId) {
  final hex = taskId.replaceAll('-', '');
  if (hex.length >= 7) {
    final v = int.tryParse(hex.substring(0, 7), radix: 16);
    if (v != null) return v;
  }
  return taskId.hashCode & 0x7fffffff;
}

class ClientsNotifier extends Notifier<List<Client>> {
  ClientRepository get _repo => ref.read(clientRepositoryProvider);

  @override
  List<Client> build() => _repo.getAll();

  Future<void> add(Client client) async {
    await _repo.save(client);
    state = _repo.getAll();
  }
}

final clientsProvider = NotifierProvider<ClientsNotifier, List<Client>>(
  ClientsNotifier.new,
);

class TasksNotifier extends Notifier<List<Task>> {
  TaskRepository get _repo => ref.read(taskRepositoryProvider);

  @override
  List<Task> build() => _sorted(_repo.getAll());

  static List<Task> _sorted(List<Task> list) {
    final copy = [...list];
    copy.sort((a, b) {
      final da = a.status == TaskStatus.done ? 1 : 0;
      final db = b.status == TaskStatus.done ? 1 : 0;
      if (da != db) return da - db;
      return a.deadlineUtc.compareTo(b.deadlineUtc);
    });
    return copy;
  }

  Future<void> save(Task task) async {
    await _repo.save(task);
    await _syncAlarm(task);
    state = _sorted(_repo.getAll());
  }

  Future<void> setStatus(Task task, String status) => save(_copy(task, status: status));

  Future<void> remove(String id) async {
    await _repo.delete(id);
    try {
      final svc = ref.read(notificationServiceProvider);
      await svc.init();
      await svc.cancel(taskAlarmId(id));
    } catch (_) {}
    state = _sorted(_repo.getAll());
  }

  Task _copy(Task t, {String? status}) => Task(
    id: t.id,
    title: t.title,
    clientId: t.clientId,
    deadlineUtc: t.deadlineUtc,
    status: status ?? t.status,
    createdAt: t.createdAt,
    updatedAt: DateTime.now().toUtc(),
    isDeleted: t.isDeleted,
  );

  /// Alarm berbunyi pada deadlineUtc. Gagal menjadwalkan tidak boleh
  /// menggagalkan penyimpanan tugas (offline-first).
  Future<void> _syncAlarm(Task t) async {
    try {
      final svc = ref.read(notificationServiceProvider);
      await svc.init();
      final id = taskAlarmId(t.id);
      if (t.isDeleted || t.status == TaskStatus.done) {
        await svc.cancel(id);
        return;
      }
      final client = ref.read(clientRepositoryProvider).getById(t.clientId);
      final scheduled = await svc.scheduleAt(
        id: id,
        whenUtc: t.deadlineUtc,
        title: t.title,
        body: client == null ? null : 'Klien: ${client.name}',
        payload: t.id,
      );
      if (!scheduled) await svc.cancel(id); // waktu sudah lewat: hapus alarm lama
    } catch (_) {}
  }
}

final tasksProvider = NotifierProvider<TasksNotifier, List<Task>>(
  TasksNotifier.new,
);