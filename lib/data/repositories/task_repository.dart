import 'package:hive_ce_flutter/hive_flutter.dart';

import '../local/hive_boxes.dart';
import '../local/models/task.dart';

class TaskRepository {
  Box<Task> get _box => Hive.box<Task>(HiveBoxes.tasks);

  Future<void> save(Task task) => _box.put(task.id, task);

  Task? getById(String id) {
    final task = _box.get(id);
    if (task == null || task.isDeleted) return null;
    return task;
  }

  /// Hanya tugas milik [ownerId] yang belum dihapus.
  List<Task> getAll(String ownerId) =>
      _box.values.where((t) => !t.isDeleted && t.ownerId == ownerId).toList();

  Future<void> delete(String id) async {
    final t = _box.get(id);
    if (t == null) return;
    await _box.put(
      id,
      Task(
        id: t.id,
        title: t.title,
        clientId: t.clientId,
        deadlineUtc: t.deadlineUtc,
        status: t.status,
        createdAt: t.createdAt,
        updatedAt: DateTime.now().toUtc(),
        isDeleted: true,
        ownerId: t.ownerId,
      ),
    );
  }
}
