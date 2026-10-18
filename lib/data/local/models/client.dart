import 'package:hive_ce/hive.dart';

part 'client.g.dart';

@HiveType(typeId: 1)
class Client {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String timezoneId;

  @HiveField(3)
  final double hourlyRate;

  @HiveField(4)
  final String currency; 

  @HiveField(5)
  final DateTime updatedAt;

  @HiveField(6)
  final bool isDeleted;

  const Client({
    required this.id,
    required this.name,
    required this.timezoneId,
    required this.hourlyRate,
    required this.currency,
    required this.updatedAt,
    this.isDeleted = false,
  });
}