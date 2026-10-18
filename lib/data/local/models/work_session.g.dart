// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkSessionAdapter extends TypeAdapter<WorkSession> {
  @override
  final typeId = 3;

  @override
  WorkSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkSession(
      id: fields[0] as String,
      taskId: fields[1] as String,
      clientId: fields[2] as String,
      startedAtUtc: fields[3] as DateTime,
      endedAtUtc: fields[4] as DateTime?,
      durationSeconds: fields[5] == null ? 0 : (fields[5] as num).toInt(),
      lateMinutes: fields[6] == null ? 0 : (fields[6] as num).toInt(),
      updatedAt: fields[7] as DateTime,
      isDeleted: fields[8] == null ? false : fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, WorkSession obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.taskId)
      ..writeByte(2)
      ..write(obj.clientId)
      ..writeByte(3)
      ..write(obj.startedAtUtc)
      ..writeByte(4)
      ..write(obj.endedAtUtc)
      ..writeByte(5)
      ..write(obj.durationSeconds)
      ..writeByte(6)
      ..write(obj.lateMinutes)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.isDeleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
