// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MovieAdapter extends TypeAdapter<Movie> {
  @override
  final int typeId = 0;

  @override
  Movie read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Movie(
      adult: fields[0] as bool,
      backdropPath: fields[1] as String,
      genreIds: (fields[2] as List).cast<String>(),
      id: fields[3] as int,
      originalLanguage: fields[4] as String,
      originalTitle: fields[5] as String,
      overview: fields[6] as String,
      popularity: fields[7] as double,
      posterPath: fields[8] as String,
      releaseDate: fields[9] as DateTime,
      title: fields[10] as String,
      video: fields[11] as bool,
      voteAverage: fields[12] as double,
      voteCount: fields[13] as int,
      runtime: fields[14] as int?,
      budget: fields[15] as int?,
      revenue: fields[16] as int?,
      homepage: fields[17] as String?,
      imdbId: fields[18] as String?,
      status: fields[19] as String?,
      tagline: fields[20] as String?,
      productionCompanies: (fields[21] as List?)?.cast<String>(),
      productionCountries: (fields[22] as List?)?.cast<String>(),
      spokenLanguages: (fields[23] as List?)?.cast<String>(),
      belongsToCollection: fields[24] as String?,
      watchProviders: fields[25] as WatchProviders?,
    );
  }

  @override
  void write(BinaryWriter writer, Movie obj) {
    writer
      ..writeByte(26)
      ..writeByte(0)
      ..write(obj.adult)
      ..writeByte(1)
      ..write(obj.backdropPath)
      ..writeByte(2)
      ..write(obj.genreIds)
      ..writeByte(3)
      ..write(obj.id)
      ..writeByte(4)
      ..write(obj.originalLanguage)
      ..writeByte(5)
      ..write(obj.originalTitle)
      ..writeByte(6)
      ..write(obj.overview)
      ..writeByte(7)
      ..write(obj.popularity)
      ..writeByte(8)
      ..write(obj.posterPath)
      ..writeByte(9)
      ..write(obj.releaseDate)
      ..writeByte(10)
      ..write(obj.title)
      ..writeByte(11)
      ..write(obj.video)
      ..writeByte(12)
      ..write(obj.voteAverage)
      ..writeByte(13)
      ..write(obj.voteCount)
      ..writeByte(14)
      ..write(obj.runtime)
      ..writeByte(15)
      ..write(obj.budget)
      ..writeByte(16)
      ..write(obj.revenue)
      ..writeByte(17)
      ..write(obj.homepage)
      ..writeByte(18)
      ..write(obj.imdbId)
      ..writeByte(19)
      ..write(obj.status)
      ..writeByte(20)
      ..write(obj.tagline)
      ..writeByte(21)
      ..write(obj.productionCompanies)
      ..writeByte(22)
      ..write(obj.productionCountries)
      ..writeByte(23)
      ..write(obj.spokenLanguages)
      ..writeByte(24)
      ..write(obj.belongsToCollection)
      ..writeByte(25)
      ..write(obj.watchProviders);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovieAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
