// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'temporada.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TemporadaAdapter extends TypeAdapter<Temporada> {
  @override
  final int typeId = 5;

  @override
  Temporada read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Temporada(
      serieId: fields[0] as int,
      seasonNumber: fields[1] as int,
      episodeCount: fields[2] as int,
      name: fields[3] as String,
      overview: fields[4] as String,
      posterPath: fields[5] as String,
      airDate: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Temporada obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.serieId)
      ..writeByte(1)
      ..write(obj.seasonNumber)
      ..writeByte(2)
      ..write(obj.episodeCount)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.overview)
      ..writeByte(5)
      ..write(obj.posterPath)
      ..writeByte(6)
      ..write(obj.airDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemporadaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
