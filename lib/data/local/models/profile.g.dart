// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProfileAdapter extends TypeAdapter<Profile> {
  @override
  final typeId = 0;

  @override
  Profile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Profile(
      id: fields[0] as String,
      role: fields[1] as String,
      homeTimezone: fields[2] as String,
      mainCurrency: fields[3] as String,
      workStartMinutes: (fields[4] as num).toInt(),
      workEndMinutes: (fields[5] as num).toInt(),
      challengeType: fields[6] as String,
      challengeDifficulty: (fields[7] as num).toInt(),
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Profile obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.homeTimezone)
      ..writeByte(3)
      ..write(obj.mainCurrency)
      ..writeByte(4)
      ..write(obj.workStartMinutes)
      ..writeByte(5)
      ..write(obj.workEndMinutes)
      ..writeByte(6)
      ..write(obj.challengeType)
      ..writeByte(7)
      ..write(obj.challengeDifficulty)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
