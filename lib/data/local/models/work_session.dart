import 'package:hive_ce/hive.dart';

part 'work_session.g.dart';

@HiveType(typeId: 3)
class WorkSession {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String taskId;

  @HiveField(2)
  final String clientId; 

  @HiveField(3)
  final DateTime startedAtUtc;

  @HiveField(4)
  final DateTime? endedAtUtc; 

  @HiveField(5)
  final int durationSeconds;

  @HiveField(6)
  final int lateMinutes;

  @HiveField(7)
  final DateTime updatedAt;

  @HiveField(8)
  final bool isDeleted;

  const WorkSession({
    required this.id,
    required this.taskId,
    required this.clientId,
    required this.startedAtUtc,
    this.endedAtUtc,
    this.durationSeconds = 0,
    this.lateMinutes = 0,
    required this.updatedAt,
    this.isDeleted = false,
  });
}