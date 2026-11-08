// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watched_movie.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WatchedMovieAdapter extends TypeAdapter<WatchedMovie> {
  @override
  final int typeId = 1;

  @override
  WatchedMovie read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatchedMovie(
      movie: fields[0] as Movie,
      watchedDate: fields[1] as DateTime,
      lastModifiedAt: fields[2] as DateTime,
      isDeleted: fields[3] as bool,
      syncStatus: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WatchedMovie obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.movie)
      ..writeByte(1)
      ..write(obj.watchedDate)
      ..writeByte(2)
      ..write(obj.lastModifiedAt)
      ..writeByte(3)
      ..write(obj.isDeleted)
      ..writeByte(4)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchedMovieAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
