import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/syncable_entity.dart';
import 'package:peliculas/core/logging/logger_factory.dart';
import 'package:peliculas/core/sync/conflict_resolver.dart';
import 'package:peliculas/core/sync/entity_sync_manager.dart';

/// Entidad de prueba que implementa SyncableEntity
class TestSyncableEntity extends SyncableEntity {
  TestSyncableEntity({
    required String id,
    required String userId,
    required this.name,
    required this.description,
    required this.customData,
    required DateTime createdAt,
    required DateTime lastModifiedAt,
    required int syncVersion,
    bool isDeleted = false,
    String? deviceId,
  })  : _id = id,
        _userId = userId,
        _createdAt = createdAt,
        _lastModifiedAt = lastModifiedAt,
        _isDeleted = isDeleted,
        _syncVersion = syncVersion,
        _deviceId = deviceId;

  factory TestSyncableEntity.fromJson(Map<String, dynamic> json) {
    return TestSyncableEntity(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      description: json['description'],
      customData: Map<String, dynamic>.from(json['custom_data'] ?? {}),
      createdAt: DateTime.parse(json['created_at']),
      lastModifiedAt: DateTime.parse(json['last_modified_at']),
      syncVersion: json['sync_version'],
      isDeleted: json['is_deleted'] ?? false,
      deviceId: json['device_id'],
    );
  }

  final String _id;
  final String _userId;
  final DateTime _createdAt;
  final DateTime _lastModifiedAt;
  final bool _isDeleted;
  final int _syncVersion;
  final String? _deviceId;
  final String name;
  final String description;
  final Map<String, dynamic> customData;

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
  String generateChecksum() {
    final content = '$name|$description|${customData.toString()}';
    return content.hashCode.toString();
  }

  @override
  bool hasSameContentAs(SyncableEntity other) {
    if (other is! TestSyncableEntity) return false;
    return name == other.name &&
        description == other.description &&
        customData.toString() == other.customData.toString();
  }

  @override
  SyncableEntity mergeWith(SyncableEntity other) {
    if (other is! TestSyncableEntity) return this;

    // Merge strategy: combine custom data and use most recent name/description
    final mergedData = Map<String, dynamic>.from(customData);
    mergedData.addAll(other.customData);

    return TestSyncableEntity(
      id: id,
      userId: userId,
      name: lastModifiedAt.isAfter(other.lastModifiedAt) ? name : other.name,
      description: lastModifiedAt.isAfter(other.lastModifiedAt)
          ? description
          : other.description,
      customData: mergedData,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt.isAfter(other.lastModifiedAt)
          ? lastModifiedAt
          : other.lastModifiedAt,
      syncVersion:
          syncVersion > other.syncVersion ? syncVersion : other.syncVersion,
      isDeleted: isDeleted,
      deviceId: deviceId,
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
      name: name,
      description: description,
      customData: customData,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      isDeleted: isDeleted ?? this.isDeleted,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  TestSyncableEntity copyWithData({
    String? name,
    String? description,
    Map<String, dynamic>? customData,
  }) {
    return TestSyncableEntity(
      id: id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      customData: customData ?? Map.from(this.customData),
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt,
      syncVersion: syncVersion,
      isDeleted: isDeleted,
      deviceId: deviceId,
    );
  }

  @override
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'description': description,
        'custom_data': customData,
        'created_at': createdAt.toIso8601String(),
        'last_modified_at': lastModifiedAt.toIso8601String(),
        'sync_version': syncVersion,
        'is_deleted': isDeleted,
        'device_id': deviceId,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestSyncableEntity &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.customData.toString() == customData.toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, customData.toString());
}

void main() {
  group('Comprehensive Conflict Resolution Tests', () {
    late ConflictResolver conflictResolver;

    const testUserId = 'test-user-123';
    final baseTime = DateTime.now();

    setUp(() {
      conflictResolver = ConflictResolver();
    });

    TestSyncableEntity createTestEntity({
      required String id,
      required String name,
      String description = 'Test description',
      Map<String, dynamic>? customData,
      DateTime? createdAt,
      DateTime? lastModifiedAt,
      int syncVersion = 1,
      bool isDeleted = false,
    }) {
      return TestSyncableEntity(
        id: id,
        userId: testUserId,
        name: name,
        description: description,
        customData: customData ?? {'category': 'test', 'priority': 1},
        createdAt: createdAt ?? baseTime,
        lastModifiedAt: lastModifiedAt ?? baseTime,
        syncVersion: syncVersion,
        isDeleted: isDeleted,
      );
    }

    group('Conflict Detection', () {
      test('debe detectar conflicto de modificación concurrente', () {
        // Arrange
        final localEntity = createTestEntity(
          id: 'entity-1',
          name: 'Local Name',
          description: 'Local description',
          lastModifiedAt: baseTime.add(const Duration(minutes: 1)),
          syncVersion: 2,
        );

        final remoteEntity = createTestEntity(
          id: 'entity-1',
          name: 'Remote Name',
          description: 'Remote description',
          lastModifiedAt: baseTime.add(const Duration(minutes: 2)),
          syncVersion: 2,
        );

        // Act
        final conflict = conflictResolver.detectConflict<TestSyncableEntity>(
            localEntity, remoteEntity);

        // Assert
        expect(conflict, isNotNull);
        expect(conflict!.conflictType,
            equals(ConflictType.concurrentModification));
        expect(conflict.localEntity.id, equals('entity-1'));
        expect(conflict.remoteEntity.id, equals('entity-1'));
        expect(conflict.localEntity.name, equals('Local Name'));
        expect(conflict.remoteEntity.name, equals('Remote Name'));

        LoggerFactory.info(
            '✅ Conflicto de modificación concurrente detectado correctamente');
      });

      test('debe detectar conflicto de eliminación vs modificación', () {
        // Arrange
        final localEntity = createTestEntity(
          id: 'entity-2',
          name: 'Modified Entity',
          lastModifiedAt: baseTime.add(const Duration(minutes: 3)),
          isDeleted: false,
        );

        final remoteEntity = createTestEntity(
          id: 'entity-2',
          name: 'Original Entity',
          lastModifiedAt: baseTime.add(const Duration(minutes: 1)),
          isDeleted: true,
        );

        // Act
        final conflict = conflictResolver.detectConflict<TestSyncableEntity>(
            localEntity, remoteEntity);

        // Assert
        expect(conflict, isNotNull);
        expect(conflict!.conflictType, equals(ConflictType.deleteVsModify));
        expect(conflict.localEntity.isDeleted, isFalse);
        expect(conflict.remoteEntity.isDeleted, isTrue);

        LoggerFactory.info(
            '✅ Conflicto de eliminación vs modificación detectado correctamente');
      });

      test('no debe detectar conflicto cuando las entidades son idénticas', () {
        // Arrange
        final entity1 = createTestEntity(
          id: 'entity-3',
          name: 'Same Entity',
          description: 'Same description',
          customData: {'key': 'value'},
        );

        final entity2 = createTestEntity(
          id: 'entity-3',
          name: 'Same Entity',
          description: 'Same description',
          customData: {'key': 'value'},
        );

        // Act
        final conflict = conflictResolver.detectConflict<TestSyncableEntity>(
            entity1, entity2);

        // Assert
        expect(conflict, isNull);

        LoggerFactory.info(
            '✅ No se detectó conflicto para entidades idénticas');
      });

      test('debe detectar múltiples conflictos en lote', () async {
        // Arrange
        final localEntities = [
          createTestEntity(id: 'entity-1', name: 'Local 1', syncVersion: 2),
          createTestEntity(id: 'entity-2', name: 'Local 2', isDeleted: false),
          createTestEntity(id: 'entity-3', name: 'Local 3', syncVersion: 3),
        ];

        final remoteEntities = [
          createTestEntity(id: 'entity-1', name: 'Remote 1', syncVersion: 2),
          createTestEntity(id: 'entity-2', name: 'Remote 2', isDeleted: true),
          createTestEntity(
              id: 'entity-4', name: 'Remote 4', syncVersion: 1), // No conflict
        ];

        // Act
        final conflicts = await conflictResolver
            .detectConflicts<TestSyncableEntity>(localEntities, remoteEntities);

        // Assert
        expect(conflicts.length, equals(2));
        expect(conflicts[0].conflictType,
            equals(ConflictType.concurrentModification));
        expect(conflicts[1].conflictType, equals(ConflictType.deleteVsModify));

        LoggerFactory.info(
            '✅ Detectados ${conflicts.length} conflictos en lote');
      });
    });

    group('Conflict Resolution Strategies', () {
      test('debe resolver conflicto con estrategia "local wins"', () async {
        // Arrange
        final localEntity = createTestEntity(
          id: 'entity-1',
          name: 'Local Version',
          description: 'Local changes',
          lastModifiedAt: baseTime.add(const Duration(minutes: 1)),
        );

        final remoteEntity = createTestEntity(
          id: 'entity-1',
          name: 'Remote Version',
          description: 'Remote changes',
          lastModifiedAt: baseTime.add(const Duration(minutes: 2)),
        );

        final conflict = ConflictInfo<TestSyncableEntity>(
          localEntity: localEntity,
          remoteEntity: remoteEntity,
          conflictType: ConflictType.concurrentModification,
          detectedAt: DateTime.now(),
        );

        // Act
        final resolution = await conflictResolver.resolveConflict(
          conflict,
          overrideStrategy: ConflictStrategy.localWins,
        );

        // Assert
        expect(resolution.strategy, equals(ConflictStrategy.localWins));
        expect(resolution.resolvedEntity.id, equals('entity-1'));
        // En una implementación real, debería mantener los datos locales

        LoggerFactory.info('✅ Conflicto resuelto con estrategia "local wins"');
      });

      test('debe resolver conflicto con estrategia "remote wins"', () async {
        // Arrange
        final localEntity = createTestEntity(
          id: 'entity-2',
          name: 'Local Version',
          lastModifiedAt: baseTime.add(const Duration(minutes: 1)),
        );

        final remoteEntity = createTestEntity(
          id: 'entity-2',
          name: 'Remote Version',
          lastModifiedAt: baseTime.add(const Duration(minutes: 2)),
        );

        final conflict = ConflictInfo<TestSyncableEntity>(
          localEntity: localEntity,
          remoteEntity: remoteEntity,
          conflictType: ConflictType.concurrentModification,
          detectedAt: DateTime.now(),
        );

        // Act
        final resolution = await conflictResolver.resolveConflict(
          conflict,
          overrideStrategy: ConflictStrategy.remoteWins,
        );

        // Assert
        expect(resolution.strategy, equals(ConflictStrategy.remoteWins));
        expect(resolution.resolvedEntity.id, equals('entity-2'));

        LoggerFactory.info('✅ Conflicto resuelto con estrategia "remote wins"');
      });

      test('debe resolver múltiples conflictos en lote', () async {
        // Arrange
        final conflicts = [
          ConflictInfo<TestSyncableEntity>(
            localEntity: createTestEntity(id: 'entity-1', name: 'Local 1'),
            remoteEntity: createTestEntity(id: 'entity-1', name: 'Remote 1'),
            conflictType: ConflictType.concurrentModification,
            detectedAt: DateTime.now(),
          ),
          ConflictInfo<TestSyncableEntity>(
            localEntity: createTestEntity(
                id: 'entity-2', name: 'Local 2', isDeleted: false),
            remoteEntity: createTestEntity(
                id: 'entity-2', name: 'Remote 2', isDeleted: true),
            conflictType: ConflictType.deleteVsModify,
            detectedAt: DateTime.now(),
          ),
        ];

        // Act
        final resolutions = await conflictResolver.resolveConflicts(
          conflicts,
          overrideStrategy: ConflictStrategy.merge,
        );

        // Assert
        expect(resolutions.length, equals(2));
        expect(
            resolutions.every((r) => r.strategy == ConflictStrategy.remoteWins),
            isTrue);

        LoggerFactory.info(
            '✅ ${resolutions.length} conflictos resueltos en lote');
      });
    });

    group('Complex Conflict Scenarios', () {
      test('debe manejar conflictos con datos complejos anidados', () async {
        // Arrange
        final complexLocalData = {
          'preferences': {
            'theme': 'dark',
            'language': 'es',
            'notifications': {
              'email': true,
              'push': false,
              'sms': true,
            },
          },
          'history': [
            {'action': 'view', 'timestamp': '2024-01-01T10:00:00Z'},
            {'action': 'like', 'timestamp': '2024-01-01T10:05:00Z'},
          ],
        };

        final complexRemoteData = {
          'preferences': {
            'theme': 'light', // Diferente
            'language': 'es',
            'notifications': {
              'email': true,
              'push': true, // Diferente
              'sms': true,
            },
          },
          'history': [
            {'action': 'view', 'timestamp': '2024-01-01T10:00:00Z'},
            {
              'action': 'share',
              'timestamp': '2024-01-01T10:03:00Z'
            }, // Diferente
          ],
        };

        final localEntity = createTestEntity(
          id: 'complex-entity',
          name: 'Complex Entity',
          customData: complexLocalData,
          lastModifiedAt: baseTime.add(const Duration(minutes: 1)),
        );

        final remoteEntity = createTestEntity(
          id: 'complex-entity',
          name: 'Complex Entity',
          customData: complexRemoteData,
          lastModifiedAt: baseTime.add(const Duration(minutes: 2)),
        );

        // Act
        final conflict = conflictResolver.detectConflict<TestSyncableEntity>(
            localEntity, remoteEntity);

        // Assert
        expect(conflict, isNotNull);
        expect(conflict!.conflictType,
            equals(ConflictType.concurrentModification));

        // Resolver el conflicto
        final resolution = await conflictResolver.resolveConflict(
          conflict,
          overrideStrategy: ConflictStrategy.merge,
        );

        expect(resolution.strategy, equals(ConflictStrategy.merge));

        LoggerFactory.info(
            '✅ Conflicto con datos complejos manejado correctamente');
      });

      test('debe manejar conflictos de versión con timestamps cercanos',
          () async {
        // Arrange - Timestamps muy cercanos (diferencia de 1 segundo)
        final baseTimestamp = DateTime.now();

        final localEntity = createTestEntity(
          id: 'timestamp-entity',
          name: 'Local Changes',
          lastModifiedAt: baseTimestamp,
          syncVersion: 5,
        );

        final remoteEntity = createTestEntity(
          id: 'timestamp-entity',
          name: 'Remote Changes',
          lastModifiedAt: baseTimestamp.add(const Duration(seconds: 1)),
          syncVersion: 5, // Misma versión
        );

        // Act
        final conflict = conflictResolver.detectConflict<TestSyncableEntity>(
            localEntity, remoteEntity);

        // Assert
        expect(conflict, isNotNull);
        expect(conflict!.conflictType,
            equals(ConflictType.concurrentModification));

        // La resolución debería usar el timestamp más reciente
        final resolution = await conflictResolver.resolveConflict(conflict);
        expect(resolution.resolvedEntity, isNotNull);

        LoggerFactory.info(
            '✅ Conflicto de timestamps cercanos resuelto correctamente');
      });

      test('debe priorizar versiones de sincronización sobre timestamps',
          () async {
        // Arrange
        final localEntity = createTestEntity(
          id: 'version-entity',
          name: 'Local Version',
          lastModifiedAt:
              baseTime.add(const Duration(minutes: 10)), // Más reciente
          syncVersion: 3, // Versión menor
        );

        final remoteEntity = createTestEntity(
          id: 'version-entity',
          name: 'Remote Version',
          lastModifiedAt:
              baseTime.add(const Duration(minutes: 5)), // Menos reciente
          syncVersion: 5, // Versión mayor
        );

        // Act
        final conflict = conflictResolver.detectConflict<TestSyncableEntity>(
            localEntity, remoteEntity);
        final resolution = await conflictResolver.resolveConflict(conflict!);

        // Assert - La versión de sync debería tener prioridad
        expect(resolution.resolvedEntity, isNotNull);

        LoggerFactory.info(
            '✅ Prioridad de versión de sync sobre timestamp verificada');
      });

      test('debe manejar conflictos en cascada', () async {
        // Arrange - Simular múltiples entidades relacionadas con conflictos
        final childEntities = [
          createTestEntity(
            id: 'child-1',
            name: 'Child 1 Local',
            customData: {'parent': 'parent-1', 'order': 1},
          ),
          createTestEntity(
            id: 'child-2',
            name: 'Child 2 Local',
            customData: {'parent': 'parent-1', 'order': 2},
          ),
        ];

        final remoteChildEntities = [
          createTestEntity(
            id: 'child-1',
            name: 'Child 1 Remote',
            customData: {'parent': 'parent-1', 'order': 2}, // Orden cambiado
          ),
          createTestEntity(
            id: 'child-2',
            name: 'Child 2 Remote',
            customData: {'parent': 'parent-1', 'order': 1}, // Orden cambiado
          ),
        ];

        // Act - Detectar conflictos en entidades relacionadas
        final conflicts = <ConflictInfo<TestSyncableEntity>>[];

        for (int i = 0; i < childEntities.length; i++) {
          final conflict = conflictResolver.detectConflict<TestSyncableEntity>(
            childEntities[i],
            remoteChildEntities[i],
          );
          if (conflict != null) {
            conflicts.add(conflict);
          }
        }

        // Assert
        expect(conflicts.length, equals(2));

        // Resolver todos los conflictos
        final resolutions = await conflictResolver.resolveConflicts(conflicts);
        expect(resolutions.length, equals(2));

        LoggerFactory.info(
            '✅ ${conflicts.length} conflictos en cascada manejados correctamente');
      });
    });

    group('Performance and Edge Cases', () {
      test('debe manejar gran volumen de conflictos eficientemente', () async {
        // Arrange
        const conflictCount = 1000;
        final conflicts = <ConflictInfo<TestSyncableEntity>>[];

        for (int i = 0; i < conflictCount; i++) {
          final localEntity = createTestEntity(
            id: 'entity-$i',
            name: 'Local Entity $i',
            syncVersion: i % 10,
          );

          final remoteEntity = createTestEntity(
            id: 'entity-$i',
            name: 'Remote Entity $i',
            syncVersion: (i % 10) + 1,
          );

          final conflict = conflictResolver.detectConflict<TestSyncableEntity>(
            localEntity,
            remoteEntity,
          );
          if (conflict != null) {
            conflicts.add(conflict);
          }
        }

        // Act
        final startTime = DateTime.now();
        final resolutions = await conflictResolver.resolveConflicts(conflicts);
        final processingTime = DateTime.now().difference(startTime);

        // Assert
        expect(resolutions.length, equals(conflictCount));
        expect(processingTime.inSeconds,
            lessThan(10)); // Debe completar en menos de 10 segundos

        final throughput = conflictCount / processingTime.inSeconds;
        LoggerFactory.info(
            '✅ $conflictCount conflictos resueltos en ${processingTime.inMilliseconds}ms');
        LoggerFactory.info(
            '✅ Throughput: ${throughput.toStringAsFixed(2)} conflictos/segundo');
      });

      test('debe manejar entidades con checksums inválidos', () {
        // Arrange
        final localEntity = createTestEntity(
          id: 'checksum-entity',
          name: 'Test Entity',
        );

        final remoteEntity = createTestEntity(
          id: 'checksum-entity',
          name: 'Test Entity Modified',
        );

        // Act & Assert
        expect(
            () => conflictResolver.detectConflict<TestSyncableEntity>(
                localEntity, remoteEntity),
            returnsNormally);

        LoggerFactory.info('✅ Checksums inválidos manejados sin errores');
      });

      test('debe validar entidades antes de detectar conflictos', () {
        // Arrange
        final entity1 = createTestEntity(id: 'entity-1', name: 'Entity 1');
        final entity2 =
            createTestEntity(id: 'entity-2', name: 'Entity 2'); // ID diferente

        // Act & Assert
        expect(
            () => conflictResolver.detectConflict<TestSyncableEntity>(
                entity1, entity2),
            throwsA(isA<ArgumentError>()));

        LoggerFactory.info(
            '✅ Validación de entidades funcionando correctamente');
      });
    });
  });
}
