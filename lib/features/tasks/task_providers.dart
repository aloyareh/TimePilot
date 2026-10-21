import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/time/time_service.dart';
import '../../data/local/models/client.dart';
import '../../data/local/models/task.dart';
import '../../data/remote/persona_remote.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../profile/profile_providers.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(),
);
final clientRepositoryProvider = Provider<ClientRepository>(
  (ref) => ClientRepository(),
);

/// Zona waktu rumah pengguna, diambil dari profil (User Persona).
final homeZoneProvider = Provider<String>(
  (ref) => ref.watch(profileProvider)?.homeTimezone ?? AppZones.wib,
);

/// ID notifikasi yang stabil dari ID tugas (uuid) -> int 28-bit.
int taskAlarmId(String taskId) {
  final hex = taskId.replaceAll('-', '');
  if (hex.length >= 7) {
    final v = int.tryParse(hex.substring(0, 7), radix: 16);
    if (v != null) {
      return v;
    }
  }
  return taskId.hashCode & 0x7fffffff;
}

class ClientsNotifier extends Notifier<List<Client>> {
  ClientRepository get _repo => ref.read(clientRepositoryProvider);

  String get _uid {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      throw StateError('Belum login.');
    }
    return uid;
  }

  @override
  List<Client> build() {
    final uid = ref.watch(currentUserIdProvider);
    return uid == null ? const <Client>[] : _repo.getAll(uid);
  }

  /// Tambah ATAU ubah (id sama = timpa). Pemilik selalu diset ke pengguna
  /// yang sedang login.
  Future<void> add(Client client) async {
    final uid = _uid;
    final owned = client.withOwner(uid);
    await _repo.save(owned);
    state = _repo.getAll(uid);
    ref.read(personaRemoteProvider).pushClient(owned); // best-effort
  }

  Future<void> remove(String id) async {
    final uid = _uid;
    await _repo.delete(id);
    state = _repo.getAll(uid);
    ref.read(personaRemoteProvider).deleteClient(id); // best-effort
  }
}

final clientsProvider = NotifierProvider<ClientsNotifier, List<Client>>(
  ClientsNotifier.new,
);

class TasksNotifier extends Notifier<List<Task>> {
  TaskRepository get _repo => ref.read(taskRepositoryProvider);

  String get _uid {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      throw StateError('Belum login.');
    }
    return uid;
  }

  @override
  List<Task> build() {
    final uid = ref.watch(currentUserIdProvider);
    return uid == null ? const <Task>[] : _sorted(_repo.getAll(uid));
  }

  static List<Task> _sorted(List<Task> list) {
    final copy = [...list];
    copy.sort((a, b) {
      final da = a.status == TaskStatus.done ? 1 : 0;
      final db = b.status == TaskStatus.done ? 1 : 0;
      if (da != db) {
        return da - db;
      }
      return a.deadlineUtc.compareTo(b.deadlineUtc);
    });
    return copy;
  }

  Future<void> save(Task task) async {
    final uid = _uid;
    final owned = task.withOwner(uid);
    await _repo.save(owned);
    await _syncAlarm(owned);
    state = _sorted(_repo.getAll(uid));
  }

  Future<void> setStatus(Task task, String status) =>
      save(_copy(task, status: status));

  Future<void> remove(String id) async {
    final uid = _uid;
    await _repo.delete(id);
    try {
      final svc = ref.read(notificationServiceProvider);
      await svc.init();
      await svc.cancel(taskAlarmId(id));
    } catch (_) {}
    state = _sorted(_repo.getAll(uid));
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
    ownerId: t.ownerId,
  );

  /// Alarm berbunyi pada deadlineUtc hanya untuk tugas yang belum dimulai.
  /// Gagal menjadwalkan tidak boleh menggagalkan penyimpanan tugas (offline-first).
  Future<void> _syncAlarm(Task t) async {
    try {
      final svc = ref.read(notificationServiceProvider);
      await svc.init();
      final id = taskAlarmId(t.id);
      if (t.isDeleted ||
          t.status == TaskStatus.done ||
          t.status == TaskStatus.inProgress) {
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
      if (!scheduled) {
        // Waktu sudah lewat: hapus alarm lama.
        await svc.cancel(id);
      }
    } catch (_) {}
  }
}

final tasksProvider = NotifierProvider<TasksNotifier, List<Task>>(
  TasksNotifier.new,
);
