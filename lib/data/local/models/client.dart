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

  /// ID pengguna pemilik klien ini. Data lama (sebelum field ini ada) bernilai
  /// null dan tidak ditampilkan ke siapa pun.
  @HiveField(7)
  final String? ownerId;

  const Client({
    required this.id,
    required this.name,
    required this.timezoneId,
    required this.hourlyRate,
    required this.currency,
    required this.updatedAt,
    this.isDeleted = false,
    this.ownerId,
  });

  Client withOwner(String ownerId) => Client(
    id: id,
    name: name,
    timezoneId: timezoneId,
    hourlyRate: hourlyRate,
    currency: currency,
    updatedAt: updatedAt,
    isDeleted: isDeleted,
    ownerId: ownerId,
  );
}
