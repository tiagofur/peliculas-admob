import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/syncable_entity.dart';

/// Test implementation of SyncableEntity for testing purposes
class TestSyncableEntity extends SyncableEntity {
  TestSyncableEntity({
    required String id,
    required String userId,
    required DateTime createdAt,
    required DateTime lastModifiedAt,
    required bool isDeleted,
    required int syncVersion,
    required String? deviceId,
    required this.testData,
    required this.testField,
  })  : _id = id,
        _userId = userId,
        _createdAt = createdAt,
        _lastModifiedAt = lastModifiedAt,
        _isDeleted = isDeleted,
        _syncVersion = syncVersion,
        _deviceId = deviceId;
  final String _id;
  final String _userId;
  final DateTime _createdAt;
  final DateTime _lastModifiedAt;
  final bool _isDeleted;
  final int _syncVersion;
  final String? _deviceId;
  final String testData;
  final String testField;

  @override
  String get id => _id;

  @override
  String get userId => _userId;

  @override
  DateTime get createdAt => _createdAt;

  @override
  DateTime get lastModifiedAt => _lastModifiedAt;

  @override
  bool get isDeleted => _isDeleted;

  @override
  int get syncVersion => _syncVersion;

  @override
  String? get deviceId => _deviceId;

  @override
  String get entityType => 'test_entity';

  @override
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': lastModifiedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'sync_version': syncVersion,
      'device_id': deviceId,
      'test_data': testData,
      'test_field': testField,
    };
  }

  TestSyncableEntity copyWithData({
    String? testData,
    String? testField,
  }) {
    return TestSyncableEntity(
      id: id,
      userId: userId,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt,
      isDeleted: isDeleted,
      syncVersion: syncVersion,
      deviceId: deviceId,
      testData: testData ?? this.testData,
      testField: testField ?? this.testField,
    );
  }

  @override
  SyncableEntity copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  }) {
    return TestSyncableEntity(
      id: id,
      userId: userId,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      testData: testData,
      testField: testField,
    );
  }
}

void main() {
  group('SyncableEntity Tests', () {
    late TestSyncableEntity testEntity;
    late DateTime now;

    setUp(() {
      now = DateTime.now();
      testEntity = TestSyncableEntity(
        id: 'test-id-1',
        userId: 'user-123',
        createdAt: now,
        lastModifiedAt: now,
        isDeleted: false,
        syncVersion: 1,
        deviceId: 'device-abc',
        testData: 'sample data',
        testField: 'sample field',
      );
    });

    group('Basic Properties', () {
      test('should have correct initial values', () {
        expect(testEntity.id, equals('test-id-1'));
        expect(testEntity.userId, equals('user-123'));
        expect(testEntity.createdAt, equals(now));
        expect(testEntity.lastModifiedAt, equals(now));
        expect(testEntity.isDeleted, isFalse);
        expect(testEntity.syncVersion, equals(1));
        expect(testEntity.deviceId, equals('device-abc'));
        expect(testEntity.entityType, equals('test_entity'));
      });

      test('should generate consistent checksum', () {
        final checksum1 = testEntity.generateChecksum();
        final checksum2 = testEntity.generateChecksum();
        expect(checksum1, equals(checksum2));
      });
    });

    group('Change Detection', () {
      test('hasChangedSince should work correctly', () {
        final earlierTime = now.subtract(const Duration(hours: 1));
        final laterTime = now.add(const Duration(hours: 1));

        expect(testEntity.hasChangedSince(earlierTime), isTrue);
        expect(testEntity.hasChangedSince(laterTime), isFalse);
      });

      test('needsSync should be true for new entities', () {
        expect(testEntity.needsSync, isTrue);
      });

      test('canAutoSync should be true for valid entities', () {
        expect(testEntity.canAutoSync, isTrue);

        final deletedEntity = testEntity.copyWith(isDeleted: true);
        expect(deletedEntity.canAutoSync, isFalse);
      });
    });

    group('Validation', () {
      test('isValidForSync should return true for valid entity', () {
        expect(testEntity.isValidForSync(), isTrue);
      });

      test(
          'getValidationErrors should return correct errors for invalid entity',
          () {
        final invalidEntity = TestSyncableEntity(
          id: '',
          userId: '',
          createdAt: now,
          lastModifiedAt: now,
          isDeleted: false,
          syncVersion: 0,
          deviceId: null,
          testData: 'test',
          testField: 'test',
        );

        final errors = invalidEntity.getValidationErrors();
        expect(errors, contains('ID cannot be empty'));
        expect(errors, contains('User ID cannot be empty'));
        expect(errors, contains('Sync version must be greater than 0'));
      });
    });

    group('Serialization', () {
      test('toSupabaseJson should include all required fields', () {
        final json = testEntity.toSupabaseJson();
        expect(json['id'], equals('test-id-1'));
        expect(json['user_id'], equals('user-123'));
        expect(json['sync_version'], equals(1));
        expect(json['device_id'], equals('device-abc'));
        expect(json['test_data'], equals('sample data'));
      });

      test('toLocalStorage should work correctly', () {
        final json = testEntity.toLocalStorage();
        expect(json['id'], equals('test-id-1'));
        expect(json['user_id'], equals('user-123'));
      });
    });

    group('Conflict Resolution', () {
      test('hasPrecedenceOver should work with sync versions', () {
        final newerEntity = testEntity.copyWith(syncVersion: 2);
        expect(newerEntity.hasPrecedenceOver(testEntity), isTrue);
        expect(testEntity.hasPrecedenceOver(newerEntity), isFalse);
      });

      test('hasPrecedenceOver should work with timestamps', () {
        final newerEntity = testEntity.copyWith(
          lastModifiedAt: now.add(const Duration(minutes: 1)),
        );
        expect(newerEntity.hasPrecedenceOver(testEntity), isTrue);
        expect(testEntity.hasPrecedenceOver(newerEntity), isFalse);
      });
    });
  });

  group('Enums and Wrapper Tests', () {
    test('SyncItemStatus should have correct values', () {
      expect(SyncItemStatus.synced.value, equals('synced'));
      expect(SyncItemStatus.pendingUpload.value, equals('pending_upload'));
      expect(SyncItemStatus.conflict.value, equals('conflict'));
    });

    test('SyncDirection should have correct values', () {
      expect(SyncDirection.upload.value, equals('upload'));
      expect(SyncDirection.download.value, equals('download'));
      expect(SyncDirection.bidirectional.value, equals('bidirectional'));
    });

    test('SyncableWrapper should work correctly', () {
      final testEntity = TestSyncableEntity(
        id: 'test-1',
        userId: 'user-1',
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        isDeleted: false,
        syncVersion: 1,
        deviceId: 'device-1',
        testData: 'data',
        testField: 'field',
      );

      final wrapper = SyncableWrapper(
        entity: testEntity,
        status: SyncItemStatus.synced,
        lastSyncAttempt: DateTime.now(),
        retryCount: 0,
      );

      expect(wrapper.entity, equals(testEntity));
      expect(wrapper.status, equals(SyncItemStatus.synced));
      expect(wrapper.retryCount, equals(0));
      expect(wrapper.canRetry, isFalse); // No puede reintentar si está synced
    });
  });
}
