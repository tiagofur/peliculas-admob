// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episodio.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EpisodioAdapter extends TypeAdapter<Episodio> {
  @override
  final int typeId = 6;

  @override
  Episodio read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Episodio(
      serieId: fields[0] as int,
      seasonNumber: fields[1] as int,
      episodeNumber: fields[2] as int,
      name: fields[3] as String,
      overview: fields[4] as String,
      stillPath: fields[5] as String,
      airDate: fields[6] as DateTime?,
      runtime: fields[7] as int?,
      voteAverage: fields[8] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Episodio obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.serieId)
      ..writeByte(1)
      ..write(obj.seasonNumber)
      ..writeByte(2)
      ..write(obj.episodeNumber)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.overview)
      ..writeByte(5)
      ..write(obj.stillPath)
      ..writeByte(6)
      ..write(obj.airDate)
      ..writeByte(7)
      ..write(obj.runtime)
      ..writeByte(8)
      ..write(obj.voteAverage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpisodioAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
