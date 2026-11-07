// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_progress.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SeriesProgressAdapter extends TypeAdapter<SeriesProgress> {
  @override
  final int typeId = 9;

  @override
  SeriesProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SeriesProgress(
      serieId: fields[0] as int,
      watchedEpisodeCount: fields[1] as int,
      totalEpisodes: fields[2] as int,
      status: fields[3] as SeriesWatchStatus,
      lastWatchedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SeriesProgress obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.serieId)
      ..writeByte(1)
      ..write(obj.watchedEpisodeCount)
      ..writeByte(2)
      ..write(obj.totalEpisodes)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.lastWatchedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeriesProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SeriesWatchStatusAdapter extends TypeAdapter<SeriesWatchStatus> {
  @override
  final int typeId = 8;

  @override
  SeriesWatchStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SeriesWatchStatus.notStarted;
      case 1:
        return SeriesWatchStatus.watching;
      case 2:
        return SeriesWatchStatus.completed;
      case 3:
        return SeriesWatchStatus.abandoned;
      default:
        return SeriesWatchStatus.notStarted;
    }
  }

  @override
  void write(BinaryWriter writer, SeriesWatchStatus obj) {
    switch (obj) {
      case SeriesWatchStatus.notStarted:
        writer.writeByte(0);
        break;
      case SeriesWatchStatus.watching:
        writer.writeByte(1);
        break;
      case SeriesWatchStatus.completed:
        writer.writeByte(2);
        break;
      case SeriesWatchStatus.abandoned:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeriesWatchStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
