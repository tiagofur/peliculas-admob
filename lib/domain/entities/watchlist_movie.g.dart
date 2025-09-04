// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watchlist_movie.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WatchlistMovieAdapter extends TypeAdapter<WatchlistMovie> {
  @override
  final int typeId = 101;

  @override
  WatchlistMovie read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatchlistMovie(
      id: fields[0] as String,
      movieId: fields[1] as int,
      movieTitle: fields[2] as String,
      moviePosterPath: fields[3] as String?,
      movieBackdropPath: fields[4] as String?,
      movieOverview: fields[5] as String?,
      movieReleaseDate: fields[6] as DateTime?,
      movieVoteAverage: fields[7] as double?,
      priority: fields[8] as WatchlistPriority,
      addedAt: fields[9] as DateTime,
      lastModifiedAt: fields[10] as DateTime,
      isDeleted: fields[11] as bool,
      syncStatus: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WatchlistMovie obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.movieId)
      ..writeByte(2)
      ..write(obj.movieTitle)
      ..writeByte(3)
      ..write(obj.moviePosterPath)
      ..writeByte(4)
      ..write(obj.movieBackdropPath)
      ..writeByte(5)
      ..write(obj.movieOverview)
      ..writeByte(6)
      ..write(obj.movieReleaseDate)
      ..writeByte(7)
      ..write(obj.movieVoteAverage)
      ..writeByte(8)
      ..write(obj.priority)
      ..writeByte(9)
      ..write(obj.addedAt)
      ..writeByte(10)
      ..write(obj.lastModifiedAt)
      ..writeByte(11)
      ..write(obj.isDeleted)
      ..writeByte(12)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchlistMovieAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WatchlistPriorityAdapter extends TypeAdapter<WatchlistPriority> {
  @override
  final int typeId = 100;

  @override
  WatchlistPriority read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return WatchlistPriority.alta;
      case 1:
        return WatchlistPriority.normal;
      case 2:
        return WatchlistPriority.baja;
      default:
        return WatchlistPriority.alta;
    }
  }

  @override
  void write(BinaryWriter writer, WatchlistPriority obj) {
    switch (obj) {
      case WatchlistPriority.alta:
        writer.writeByte(0);
        break;
      case WatchlistPriority.normal:
        writer.writeByte(1);
        break;
      case WatchlistPriority.baja:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchlistPriorityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
