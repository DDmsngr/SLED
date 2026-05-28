// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_session_model.dart';

class TrackSessionModelAdapter extends TypeAdapter<TrackSessionModel> {
  @override
  final int typeId = 0;

  @override
  TrackSessionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrackSessionModel()
      ..id               = fields[0]  as String
      ..title            = fields[1]  as String
      ..startedAt        = fields[2]  as DateTime
      ..finishedAt       = fields[3]  as DateTime?
      ..lats             = (fields[4]  as List).cast<double>()
      ..lngs             = (fields[5]  as List).cast<double>()
      ..timestampsMs     = (fields[6]  as List).cast<int>()
      ..speeds           = (fields[7]  as List).cast<double>()
      ..accuracies       = (fields[8]  as List).cast<double>()
      ..photoIds         = (fields[9]  as List).cast<String>()
      ..distanceMeters   = fields[10] as double
      ..activityTypeIndex = fields[11] == null ? 0     : fields[11] as int
      ..pausedDurationMs  = fields[12] == null ? 0     : fields[12] as int
      ..isSharedRoute     = fields[13] == null ? false : fields[13] as bool
      ..routeDescription  = fields[14] == null ? ''    : fields[14] as String
      ..altitudes         = fields[15] == null ? <double>[] : (fields[15] as List).cast<double>();
  }

  @override
  void write(BinaryWriter writer, TrackSessionModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)  ..write(obj.id)
      ..writeByte(1)  ..write(obj.title)
      ..writeByte(2)  ..write(obj.startedAt)
      ..writeByte(3)  ..write(obj.finishedAt)
      ..writeByte(4)  ..write(obj.lats)
      ..writeByte(5)  ..write(obj.lngs)
      ..writeByte(6)  ..write(obj.timestampsMs)
      ..writeByte(7)  ..write(obj.speeds)
      ..writeByte(8)  ..write(obj.accuracies)
      ..writeByte(9)  ..write(obj.photoIds)
      ..writeByte(10) ..write(obj.distanceMeters)
      ..writeByte(11) ..write(obj.activityTypeIndex)
      ..writeByte(12) ..write(obj.pausedDurationMs)
      ..writeByte(13) ..write(obj.isSharedRoute)
      ..writeByte(14) ..write(obj.routeDescription)
      ..writeByte(15) ..write(obj.altitudes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackSessionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
