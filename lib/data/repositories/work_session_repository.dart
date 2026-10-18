import 'package:hive_ce_flutter/hive_flutter.dart';

import '../local/hive_boxes.dart';
import '../local/models/work_session.dart';

class WorkSessionRepository {
  Box<WorkSession> get _box => Hive.box<WorkSession>(HiveBoxes.sessions);

  Future<void> save(WorkSession session) => _box.put(session.id, session);

  WorkSession? getById(String id) {
    final s = _box.get(id);
    if (s == null || s.isDeleted) return null;
    return s;
  }

  List<WorkSession> getAll() =>
      _box.values.where((s) => !s.isDeleted).toList();

  Future<void> delete(String id) async {
    final s = _box.get(id);
    if (s == null) return;
    await _box.put(
      id,
      WorkSession(
        id: s.id,
        taskId: s.taskId,
        clientId: s.clientId,
        startedAtUtc: s.startedAtUtc,
        endedAtUtc: s.endedAtUtc,
        durationSeconds: s.durationSeconds,
        lateMinutes: s.lateMinutes,
        updatedAt: DateTime.now().toUtc(),
        isDeleted: true,
      ),
    );
  }
}