// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_provider.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WatchProviderAdapter extends TypeAdapter<WatchProvider> {
  @override
  final int typeId = 10;

  @override
  WatchProvider read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatchProvider(
      providerId: fields[0] as int,
      providerName: fields[1] as String,
      logoPath: fields[2] as String,
      displayPriority: fields[3] as int,
      link: fields[4] as String?,
      presentationType: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WatchProvider obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.providerId)
      ..writeByte(1)
      ..write(obj.providerName)
      ..writeByte(2)
      ..write(obj.logoPath)
      ..writeByte(3)
      ..write(obj.displayPriority)
      ..writeByte(4)
      ..write(obj.link)
      ..writeByte(5)
      ..write(obj.presentationType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchProviderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
