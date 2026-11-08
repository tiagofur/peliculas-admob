// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_providers.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WatchProvidersAdapter extends TypeAdapter<WatchProviders> {
  @override
  final int typeId = 11;

  @override
  WatchProviders read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatchProviders(
      link: fields[0] as String?,
      flatrate: (fields[1] as List).cast<WatchProvider>(),
      rent: (fields[2] as List).cast<WatchProvider>(),
      buy: (fields[3] as List).cast<WatchProvider>(),
    );
  }

  @override
  void write(BinaryWriter writer, WatchProviders obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.link)
      ..writeByte(1)
      ..write(obj.flatrate)
      ..writeByte(2)
      ..write(obj.rent)
      ..writeByte(3)
      ..write(obj.buy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchProvidersAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
