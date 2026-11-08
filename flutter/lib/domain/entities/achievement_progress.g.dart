// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'achievement_progress.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AchievementProgressAdapter extends TypeAdapter<AchievementProgress> {
  @override
  final int typeId = 54;

  @override
  AchievementProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AchievementProgress(
      achievementId: fields[0] as String,
      userId: fields[1] as String,
      currentValue: fields[2] as int,
      isUnlocked: fields[3] as bool,
      unlockedDate: fields[4] as DateTime?,
      progressHistory: (fields[5] as List).cast<ProgressEntry>(),
      lastUpdated: fields[6] as DateTime?,
      metadata: (fields[7] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, AchievementProgress obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.achievementId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.currentValue)
      ..writeByte(3)
      ..write(obj.isUnlocked)
      ..writeByte(4)
      ..write(obj.unlockedDate)
      ..writeByte(5)
      ..write(obj.progressHistory)
      ..writeByte(6)
      ..write(obj.lastUpdated)
      ..writeByte(7)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AchievementProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProgressEntryAdapter extends TypeAdapter<ProgressEntry> {
  @override
  final int typeId = 55;

  @override
  ProgressEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgressEntry(
      timestamp: fields[0] as DateTime,
      progressAmount: fields[1] as int,
      triggerEvent: fields[2] as String?,
      metadata: (fields[3] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, ProgressEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.progressAmount)
      ..writeByte(2)
      ..write(obj.triggerEvent)
      ..writeByte(3)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
