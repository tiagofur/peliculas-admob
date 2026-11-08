// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_achievements.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAchievementsAdapter extends TypeAdapter<UserAchievements> {
  @override
  final int typeId = 53;

  @override
  UserAchievements read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserAchievements(
      userId: fields[0] as String,
      totalPoints: fields[1] as int,
      unlockedAchievements: (fields[2] as List).cast<String>(),
      achievementProgress: (fields[3] as Map).cast<String, int>(),
      lastUpdated: fields[4] as DateTime?,
      streaks: (fields[5] as Map).cast<String, int>(),
      milestones: (fields[6] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, UserAchievements obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.totalPoints)
      ..writeByte(2)
      ..write(obj.unlockedAchievements)
      ..writeByte(3)
      ..write(obj.achievementProgress)
      ..writeByte(4)
      ..write(obj.lastUpdated)
      ..writeByte(5)
      ..write(obj.streaks)
      ..writeByte(6)
      ..write(obj.milestones);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAchievementsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
