// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'achievement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AchievementAdapter extends TypeAdapter<Achievement> {
  @override
  final int typeId = 2;

  @override
  Achievement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Achievement(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      iconName: fields[3] as String,
      targetValue: fields[4] as int,
      currentValue: fields[5] as int,
      isUnlocked: fields[6] as bool,
      unlockedDate: fields[7] as DateTime?,
      category: fields[8] as AchievementCategory,
      type: fields[9] as AchievementType,
      rarity: fields[10] as AchievementRarity,
      points: fields[11] as int,
      unlockMessage: fields[12] as String?,
      isRepeatable: fields[13] as bool,
      isHidden: fields[14] as bool,
      prerequisites: (fields[15] as List).cast<String>(),
      metadata: (fields[16] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Achievement obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.iconName)
      ..writeByte(4)
      ..write(obj.targetValue)
      ..writeByte(5)
      ..write(obj.currentValue)
      ..writeByte(6)
      ..write(obj.isUnlocked)
      ..writeByte(7)
      ..write(obj.unlockedDate)
      ..writeByte(8)
      ..write(obj.category)
      ..writeByte(9)
      ..write(obj.type)
      ..writeByte(10)
      ..write(obj.rarity)
      ..writeByte(11)
      ..write(obj.points)
      ..writeByte(12)
      ..write(obj.unlockMessage)
      ..writeByte(13)
      ..write(obj.isRepeatable)
      ..writeByte(14)
      ..write(obj.isHidden)
      ..writeByte(15)
      ..write(obj.prerequisites)
      ..writeByte(16)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AchievementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AchievementTypeAdapter extends TypeAdapter<AchievementType> {
  @override
  final int typeId = 51;

  @override
  AchievementType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AchievementType.moviesWatched;
      case 1:
        return AchievementType.genreExplorer;
      case 2:
        return AchievementType.yearStreak;
      case 3:
        return AchievementType.socialInteraction;
      case 4:
        return AchievementType.qualityViewer;
      case 5:
        return AchievementType.timeSpent;
      case 6:
        return AchievementType.discovery;
      default:
        return AchievementType.moviesWatched;
    }
  }

  @override
  void write(BinaryWriter writer, AchievementType obj) {
    switch (obj) {
      case AchievementType.moviesWatched:
        writer.writeByte(0);
        break;
      case AchievementType.genreExplorer:
        writer.writeByte(1);
        break;
      case AchievementType.yearStreak:
        writer.writeByte(2);
        break;
      case AchievementType.socialInteraction:
        writer.writeByte(3);
        break;
      case AchievementType.qualityViewer:
        writer.writeByte(4);
        break;
      case AchievementType.timeSpent:
        writer.writeByte(5);
        break;
      case AchievementType.discovery:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AchievementTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AchievementRarityAdapter extends TypeAdapter<AchievementRarity> {
  @override
  final int typeId = 52;

  @override
  AchievementRarity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AchievementRarity.common;
      case 1:
        return AchievementRarity.uncommon;
      case 2:
        return AchievementRarity.rare;
      case 3:
        return AchievementRarity.epic;
      case 4:
        return AchievementRarity.legendary;
      default:
        return AchievementRarity.common;
    }
  }

  @override
  void write(BinaryWriter writer, AchievementRarity obj) {
    switch (obj) {
      case AchievementRarity.common:
        writer.writeByte(0);
        break;
      case AchievementRarity.uncommon:
        writer.writeByte(1);
        break;
      case AchievementRarity.rare:
        writer.writeByte(2);
        break;
      case AchievementRarity.epic:
        writer.writeByte(3);
        break;
      case AchievementRarity.legendary:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AchievementRarityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AchievementCategoryAdapter extends TypeAdapter<AchievementCategory> {
  @override
  final int typeId = 3;

  @override
  AchievementCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AchievementCategory.movies;
      case 1:
        return AchievementCategory.favorites;
      case 2:
        return AchievementCategory.exploration;
      case 3:
        return AchievementCategory.social;
      default:
        return AchievementCategory.movies;
    }
  }

  @override
  void write(BinaryWriter writer, AchievementCategory obj) {
    switch (obj) {
      case AchievementCategory.movies:
        writer.writeByte(0);
        break;
      case AchievementCategory.favorites:
        writer.writeByte(1);
        break;
      case AchievementCategory.exploration:
        writer.writeByte(2);
        break;
      case AchievementCategory.social:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AchievementCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
