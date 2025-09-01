// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_operation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncOperationAdapter extends TypeAdapter<SyncOperation> {
  @override
  final int typeId = 10;

  @override
  SyncOperation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncOperation(
      id: fields[0] as String,
      type: fields[1] as SyncOperationType,
      data: (fields[2] as Map).cast<String, dynamic>(),
      createdAt: fields[3] as DateTime,
      lastAttemptAt: fields[4] as DateTime?,
      retryCount: fields[5] as int,
      maxRetries: fields[6] as int,
      status: fields[7] as SyncOperationStatus,
      errorMessage: fields[8] as String?,
      priority: fields[9] as int,
      batchId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SyncOperation obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.data)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.lastAttemptAt)
      ..writeByte(5)
      ..write(obj.retryCount)
      ..writeByte(6)
      ..write(obj.maxRetries)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.errorMessage)
      ..writeByte(9)
      ..write(obj.priority)
      ..writeByte(10)
      ..write(obj.batchId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOperationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SyncOperationTypeAdapter extends TypeAdapter<SyncOperationType> {
  @override
  final int typeId = 11;

  @override
  SyncOperationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncOperationType.addFavorite;
      case 1:
        return SyncOperationType.removeFavorite;
      case 2:
        return SyncOperationType.markWatched;
      case 3:
        return SyncOperationType.unmarkWatched;
      case 4:
        return SyncOperationType.createCustomList;
      case 5:
        return SyncOperationType.updateCustomList;
      case 6:
        return SyncOperationType.deleteCustomList;
      case 7:
        return SyncOperationType.addMovieToList;
      case 8:
        return SyncOperationType.removeMovieFromList;
      default:
        return SyncOperationType.addFavorite;
    }
  }

  @override
  void write(BinaryWriter writer, SyncOperationType obj) {
    switch (obj) {
      case SyncOperationType.addFavorite:
        writer.writeByte(0);
        break;
      case SyncOperationType.removeFavorite:
        writer.writeByte(1);
        break;
      case SyncOperationType.markWatched:
        writer.writeByte(2);
        break;
      case SyncOperationType.unmarkWatched:
        writer.writeByte(3);
        break;
      case SyncOperationType.createCustomList:
        writer.writeByte(4);
        break;
      case SyncOperationType.updateCustomList:
        writer.writeByte(5);
        break;
      case SyncOperationType.deleteCustomList:
        writer.writeByte(6);
        break;
      case SyncOperationType.addMovieToList:
        writer.writeByte(7);
        break;
      case SyncOperationType.removeMovieFromList:
        writer.writeByte(8);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOperationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SyncOperationStatusAdapter extends TypeAdapter<SyncOperationStatus> {
  @override
  final int typeId = 12;

  @override
  SyncOperationStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncOperationStatus.pending;
      case 1:
        return SyncOperationStatus.processing;
      case 2:
        return SyncOperationStatus.completed;
      case 3:
        return SyncOperationStatus.failed;
      case 4:
        return SyncOperationStatus.retrying;
      default:
        return SyncOperationStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, SyncOperationStatus obj) {
    switch (obj) {
      case SyncOperationStatus.pending:
        writer.writeByte(0);
        break;
      case SyncOperationStatus.processing:
        writer.writeByte(1);
        break;
      case SyncOperationStatus.completed:
        writer.writeByte(2);
        break;
      case SyncOperationStatus.failed:
        writer.writeByte(3);
        break;
      case SyncOperationStatus.retrying:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOperationStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncOperation _$SyncOperationFromJson(Map<String, dynamic> json) =>
    SyncOperation(
      id: json['id'] as String,
      type: $enumDecode(_$SyncOperationTypeEnumMap, json['type']),
      data: json['data'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAttemptAt: json['lastAttemptAt'] == null
          ? null
          : DateTime.parse(json['lastAttemptAt'] as String),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      maxRetries: (json['maxRetries'] as num?)?.toInt() ?? 3,
      status:
          $enumDecodeNullable(_$SyncOperationStatusEnumMap, json['status']) ??
              SyncOperationStatus.pending,
      errorMessage: json['errorMessage'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      batchId: json['batchId'] as String?,
    );

Map<String, dynamic> _$SyncOperationToJson(SyncOperation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$SyncOperationTypeEnumMap[instance.type]!,
      'data': instance.data,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastAttemptAt': instance.lastAttemptAt?.toIso8601String(),
      'retryCount': instance.retryCount,
      'maxRetries': instance.maxRetries,
      'status': _$SyncOperationStatusEnumMap[instance.status]!,
      'errorMessage': instance.errorMessage,
      'priority': instance.priority,
      'batchId': instance.batchId,
    };

const _$SyncOperationTypeEnumMap = {
  SyncOperationType.addFavorite: 'addFavorite',
  SyncOperationType.removeFavorite: 'removeFavorite',
  SyncOperationType.markWatched: 'markWatched',
  SyncOperationType.unmarkWatched: 'unmarkWatched',
  SyncOperationType.createCustomList: 'createCustomList',
  SyncOperationType.updateCustomList: 'updateCustomList',
  SyncOperationType.deleteCustomList: 'deleteCustomList',
  SyncOperationType.addMovieToList: 'addMovieToList',
  SyncOperationType.removeMovieFromList: 'removeMovieFromList',
};

const _$SyncOperationStatusEnumMap = {
  SyncOperationStatus.pending: 'pending',
  SyncOperationStatus.processing: 'processing',
  SyncOperationStatus.completed: 'completed',
  SyncOperationStatus.failed: 'failed',
  SyncOperationStatus.retrying: 'retrying',
};
