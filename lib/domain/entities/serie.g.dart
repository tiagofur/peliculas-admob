// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'serie.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SerieAdapter extends TypeAdapter<Serie> {
  @override
  final int typeId = 4;

  @override
  Serie read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Serie(
      id: fields[0] as int,
      name: fields[1] as String,
      originalName: fields[2] as String,
      overview: fields[3] as String,
      posterPath: fields[4] as String,
      backdropPath: fields[5] as String,
      firstAirDate: fields[6] as DateTime?,
      originCountry: (fields[7] as List).cast<String>(),
      genreIds: (fields[8] as List).cast<int>(),
      voteAverage: fields[9] as double,
      voteCount: fields[10] as int,
      popularity: fields[11] as double,
      originalLanguage: fields[12] as String,
      numberOfSeasons: fields[13] as int,
      numberOfEpisodes: fields[14] as int,
      episodeRunTime: (fields[15] as List).cast<int>(),
      status: fields[16] as String,
      inProduction: fields[17] as bool,
      type: fields[18] as String,
      networks: (fields[19] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Serie obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.originalName)
      ..writeByte(3)
      ..write(obj.overview)
      ..writeByte(4)
      ..write(obj.posterPath)
      ..writeByte(5)
      ..write(obj.backdropPath)
      ..writeByte(6)
      ..write(obj.firstAirDate)
      ..writeByte(7)
      ..write(obj.originCountry)
      ..writeByte(8)
      ..write(obj.genreIds)
      ..writeByte(9)
      ..write(obj.voteAverage)
      ..writeByte(10)
      ..write(obj.voteCount)
      ..writeByte(11)
      ..write(obj.popularity)
      ..writeByte(12)
      ..write(obj.originalLanguage)
      ..writeByte(13)
      ..write(obj.numberOfSeasons)
      ..writeByte(14)
      ..write(obj.numberOfEpisodes)
      ..writeByte(15)
      ..write(obj.episodeRunTime)
      ..writeByte(16)
      ..write(obj.status)
      ..writeByte(17)
      ..write(obj.inProduction)
      ..writeByte(18)
      ..write(obj.type)
      ..writeByte(19)
      ..write(obj.networks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SerieAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
