// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 0;

  @override
  Note read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Note(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      isDone: fields[3] as bool? ?? false,
      createdAt: fields[4] as DateTime,
      timeAlert: fields[5] as TimeAlert?,
      locationAlert: fields[6] as LocationAlert?,
      isArchived: fields[7] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.isDone)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.timeAlert)
      ..writeByte(6)
      ..write(obj.locationAlert)
      ..writeByte(7)
      ..write(obj.isArchived);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TimeAlertAdapter extends TypeAdapter<TimeAlert> {
  @override
  final int typeId = 1;

  @override
  TimeAlert read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimeAlert(
      dateTime: fields[0] as DateTime,
      isRecurring: fields[1] as bool? ?? false,
      recurringType: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TimeAlert obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.dateTime)
      ..writeByte(1)
      ..write(obj.isRecurring)
      ..writeByte(2)
      ..write(obj.recurringType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeAlertAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocationAlertAdapter extends TypeAdapter<LocationAlert> {
  @override
  final int typeId = 2;

  @override
  LocationAlert read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocationAlert(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      radiusMeters: fields[2] as double,
      locationName: fields[3] as String?,
      triggered: fields[5] as bool? ?? false,
      timeWindowStartMinutes: fields[6] as int?,
      timeWindowEndMinutes: fields[7] as int?,
      dateRangeStart: fields[8] as DateTime?,
      dateRangeEnd: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, LocationAlert obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.radiusMeters)
      ..writeByte(3)
      ..write(obj.locationName)
      ..writeByte(5)
      ..write(obj.triggered)
      ..writeByte(6)
      ..write(obj.timeWindowStartMinutes)
      ..writeByte(7)
      ..write(obj.timeWindowEndMinutes)
      ..writeByte(8)
      ..write(obj.dateRangeStart)
      ..writeByte(9)
      ..write(obj.dateRangeEnd);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationAlertAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
