// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_place.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedPlaceAdapter extends TypeAdapter<SavedPlace> {
  @override
  final int typeId = 3;

  @override
  SavedPlace read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedPlace(
      id: fields[0] as String,
      name: fields[1] as String,
      latitude: fields[2] as double,
      longitude: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SavedPlace obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.latitude)
      ..writeByte(3)
      ..write(obj.longitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedPlaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
