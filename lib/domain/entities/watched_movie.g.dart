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
    );
  }

  @override
  void write(BinaryWriter writer, WatchedMovie obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.movie)
      ..writeByte(1)
      ..write(obj.watchedDate);
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
