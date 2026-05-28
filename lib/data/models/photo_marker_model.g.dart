// GENERATED CODE - DO NOT MODIFY BY HAND
// Run: dart run build_runner build

part of 'photo_marker_model.dart';

class PhotoMarkerModelAdapter extends TypeAdapter<PhotoMarkerModel> {
  @override
  final int typeId = 1;

  @override
  PhotoMarkerModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhotoMarkerModel()
      ..id = fields[0] as String
      ..sessionId = fields[1] as String
      ..filePath = fields[2] as String
      ..lat = fields[3] as double
      ..lng = fields[4] as double
      ..timestamp = fields[5] as DateTime;
  }

  @override
  void write(BinaryWriter writer, PhotoMarkerModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.lat)
      ..writeByte(4)
      ..write(obj.lng)
      ..writeByte(5)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoMarkerModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
