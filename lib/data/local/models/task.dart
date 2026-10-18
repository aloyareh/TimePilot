import 'package:hive_ce/hive.dart';

part 'task.g.dart';

abstract class TaskStatus {
  static const todo = 'todo';
  static const inProgress = 'inProgress';
  static const done = 'done';
}

@HiveType(typeId: 2)
class Task {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String clientId; 

  @HiveField(3)
  final DateTime deadlineUtc;

  @HiveField(4)
  final String status; 

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  @HiveField(7)
  final bool isDeleted;

  const Task({
    required this.id,
    required this.title,
    required this.clientId,
    required this.deadlineUtc,
    this.status = TaskStatus.todo,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });
}
