// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watched_episode.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WatchedEpisodeAdapter extends TypeAdapter<WatchedEpisode> {
  @override
  final int typeId = 7;

  @override
  WatchedEpisode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatchedEpisode(
      serieId: fields[0] as int,
      seasonNumber: fields[1] as int,
      episodeNumber: fields[2] as int,
      watchedDate: fields[3] as DateTime,
      lastModifiedAt: fields[4] as DateTime,
      serieName: fields[5] as String,
      posterPath: fields[6] as String,
      isDeleted: fields[7] as bool,
      syncStatus: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WatchedEpisode obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.serieId)
      ..writeByte(1)
      ..write(obj.seasonNumber)
      ..writeByte(2)
      ..write(obj.episodeNumber)
      ..writeByte(3)
      ..write(obj.watchedDate)
      ..writeByte(4)
      ..write(obj.lastModifiedAt)
      ..writeByte(5)
      ..write(obj.serieName)
      ..writeByte(6)
      ..write(obj.posterPath)
      ..writeByte(7)
      ..write(obj.isDeleted)
      ..writeByte(8)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchedEpisodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
