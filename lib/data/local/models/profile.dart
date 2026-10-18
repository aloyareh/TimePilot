import 'package:hive_ce/hive.dart';

part 'profile.g.dart';

abstract class ChallengeType {
  static const shake = 'shake';
  static const balance = 'balance';
  static const memory = 'memory';
  static const math = 'math';
}

@HiveType(typeId: 0)
class Profile {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String role;

  @HiveField(2)
  final String homeTimezone; 

  @HiveField(3)
  final String mainCurrency;

  @HiveField(4)
  final int workStartMinutes; 

  @HiveField(5)
  final int workEndMinutes;

  @HiveField(6)
  final String challengeType;

  @HiveField(7)
  final int challengeDifficulty;

  @HiveField(8)
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.role,
    required this.homeTimezone,
    required this.mainCurrency,
    required this.workStartMinutes,
    required this.workEndMinutes,
    required this.challengeType,
    required this.challengeDifficulty,
    required this.updatedAt,
  });
}