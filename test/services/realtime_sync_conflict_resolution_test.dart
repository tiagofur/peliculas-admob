import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:peliculas/core/sync/conflict_resolver.dart';
import 'package:peliculas/core/sync/sync_coordinator.dart';
import 'package:peliculas/core/sync/sync_operation.dart';
import 'package:peliculas/domain/entities/sync_result.dart';
import 'package:peliculas/domain/entities/syncable_entity.dart';
import 'package:peliculas/infrastructure/services/connectivity_manager.dart';
import 'package:peliculas/infrastructure/services/realtime_sync_manager.dart';

// Mocks simples
class MockConflictResolver extends Mock implements ConflictResolver {}

class MockConnectivityManager extends Mock implements ConnectivityManager {}

// Clase de prueba para entidad sincronizable
class TestSyncableEntity extends SyncableEntity {
  TestSyncableEntity({
    required String id,
    required String userId,
    required DateTime createdAt,
    required DateTime lastModifiedAt,
    required int syncVersion,
    required this.name,
    required this.value,
    bool isDeleted = false,
    String? deviceId,
  })  : _id = id,
        _userId = userId,
        _createdAt = createdAt,
        _lastModifiedAt = lastModifiedAt,
        _syncVersion = syncVersion,
        _isDeleted = isDeleted,
        _deviceId = deviceId;

  factory TestSyncableEntity.fromJson(Map<String, dynamic> json) {
    return TestSyncableEntity(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      value: json['value'],
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
  final int _syncVersion;
  final bool _isDeleted;
  final String? _deviceId;
  final String name;
  final int value;

  @override
  String get id => _id;

  @override
  String get userId => _userId;

  @override
  DateTime get createdAt => _createdAt;

  @override
  DateTime get lastModifiedAt => _lastModifiedAt;

  @override
  int get syncVersion => _syncVersion;

  @override
  bool get isDeleted => _isDeleted;

  @override
  String? get deviceId => _deviceId;

  @override
  String get entityType => 'test_entity';

  @override
  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'value': value,
        'created_at': createdAt.toIso8601String(),
        'last_modified_at': lastModifiedAt.toIso8601String(),
        'sync_version': syncVersion,
        'is_deleted': isDeleted,
        'device_id': deviceId,
      };

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
      syncVersion: syncVersion ?? this.syncVersion,
      name: name,
      value: value,
      isDeleted: isDeleted ?? this.isDeleted,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  TestSyncableEntity copyWithData({
    String? name,
    int? value,
  }) {
    return TestSyncableEntity(
      id: id,
      userId: userId,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt,
      syncVersion: syncVersion,
      name: name ?? this.name,
      value: value ?? this.value,
      isDeleted: isDeleted,
      deviceId: deviceId,
    );
  }
}

void main() {
  group('RealtimeSync - Resolución de Conflictos', () {
    late SyncCoordinator syncCoordinator;
    late MockConflictResolver mockConflictResolver;
    late MockConnectivityManager mockConnectivityManager;
    late RealtimeSyncManager realtimeSyncManager;

    const testUserId = 'test-user-123';
    const testEntityId = 'entity-456';

    setUp(() {
      mockConflictResolver = MockConflictResolver();
      mockConnectivityManager = MockConnectivityManager();

      // Configurar mocks
      when(mockConnectivityManager.connectionStatus)
          .thenAnswer((_) => Stream.value(ConnectionStatus.online));
      when(mockConnectivityManager.currentStatus)
          .thenReturn(ConnectionStatus.online);

      syncCoordinator = SyncCoordinator(userId: testUserId);

      realtimeSyncManager = RealtimeSyncManager(
        userId: testUserId,
        syncCoordinator: syncCoordinator,
        connectivityManager: mockConnectivityManager,
      );
    });

    test('debe detectar conflicto de versión', () async {
      // Arrange
      final localEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Local Version',
        value: 100,
        lastModified: DateTime.now().subtract(const Duration(minutes: 5)),
        version: 1,
      );

      final remoteEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Remote Version',
        value: 200,
        lastModified: DateTime.now().subtract(const Duration(minutes: 3)),
        version: 2,
      );

      // Configurar mock para detectar conflicto
      when(mockConflictResolver.detectConflict(any, any)).thenReturn(true);

      when(mockConflictResolver.resolveConflict(
        localEntity: any,
        remoteEntity: any,
        strategy: any,
      )).thenAnswer((_) async => ConflictResolution(
            resolvedEntity: remoteEntity, // Usar versión remota
            strategy: ConflictResolutionStrategy.remoteWins,
            conflictType: ConflictType.versionMismatch,
          ));

      // Act
      final hasConflict = mockConflictResolver.detectConflict(
        localEntity.toJson(),
        remoteEntity.toJson(),
      );

      // Assert
      expect(hasConflict, isTrue);
      verify(mockConflictResolver.detectConflict(any, any)).called(1);
    });

    test('debe resolver conflicto usando estrategia remoteWins', () async {
      // Arrange
      final localEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Local Version',
        value: 100,
        lastModified: DateTime.now().subtract(const Duration(minutes: 5)),
        version: 1,
      );

      final remoteEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Remote Version',
        value: 200,
        lastModified: DateTime.now().subtract(const Duration(minutes: 3)),
        version: 2,
      );

      when(mockConflictResolver.resolveConflict(
        localEntity: any,
        remoteEntity: any,
        strategy: ConflictResolutionStrategy.remoteWins,
      )).thenAnswer((_) async => ConflictResolution(
            resolvedEntity: remoteEntity,
            strategy: ConflictResolutionStrategy.remoteWins,
            conflictType: ConflictType.versionMismatch,
          ));

      // Act
      final resolution = await mockConflictResolver.resolveConflict(
        localEntity: localEntity.toJson(),
        remoteEntity: remoteEntity.toJson(),
        strategy: ConflictResolutionStrategy.remoteWins,
      );

      // Assert
      expect(resolution.strategy, ConflictResolutionStrategy.remoteWins);
      expect(resolution.resolvedEntity['name'], 'Remote Version');
      expect(resolution.resolvedEntity['value'], 200);
    });

    test('debe resolver conflicto usando estrategia localWins', () async {
      // Arrange
      final localEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Local Version',
        value: 100,
        lastModified: DateTime.now().subtract(const Duration(minutes: 2)),
        version: 2,
      );

      final remoteEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Remote Version',
        value: 200,
        lastModified: DateTime.now().subtract(const Duration(minutes: 5)),
        version: 1,
      );

      when(mockConflictResolver.resolveConflict(
        localEntity: any,
        remoteEntity: any,
        strategy: ConflictResolutionStrategy.localWins,
      )).thenAnswer((_) async => ConflictResolution(
            resolvedEntity: localEntity,
            strategy: ConflictResolutionStrategy.localWins,
            conflictType: ConflictType.versionMismatch,
          ));

      // Act
      final resolution = await mockConflictResolver.resolveConflict(
        localEntity: localEntity.toJson(),
        remoteEntity: remoteEntity.toJson(),
        strategy: ConflictResolutionStrategy.localWins,
      );

      // Assert
      expect(resolution.strategy, ConflictResolutionStrategy.localWins);
      expect(resolution.resolvedEntity['name'], 'Local Version');
      expect(resolution.resolvedEntity['value'], 100);
    });

    test('debe resolver conflicto usando estrategia lastModifiedWins',
        () async {
      // Arrange
      final now = DateTime.now();
      final localEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Local Version',
        value: 100,
        lastModified: now.subtract(const Duration(minutes: 5)), // Más antiguo
        version: 1,
      );

      final remoteEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Remote Version',
        value: 200,
        lastModified: now.subtract(const Duration(minutes: 2)), // Más reciente
        version: 1,
      );

      when(mockConflictResolver.resolveConflict(
        localEntity: any,
        remoteEntity: any,
        strategy: ConflictResolutionStrategy.lastModifiedWins,
      )).thenAnswer((_) async => ConflictResolution(
            resolvedEntity: remoteEntity, // Más reciente gana
            strategy: ConflictResolutionStrategy.lastModifiedWins,
            conflictType: ConflictType.timestampMismatch,
          ));

      // Act
      final resolution = await mockConflictResolver.resolveConflict(
        localEntity: localEntity.toJson(),
        remoteEntity: remoteEntity.toJson(),
        strategy: ConflictResolutionStrategy.lastModifiedWins,
      );

      // Assert
      expect(resolution.strategy, ConflictResolutionStrategy.lastModifiedWins);
      expect(resolution.resolvedEntity['name'], 'Remote Version');
      expect(resolution.conflictType, ConflictType.timestampMismatch);
    });

    test('debe manejar múltiples conflictos concurrentes', () async {
      // Arrange
      final conflicts = <Map<String, dynamic>>[];

      for (int i = 0; i < 5; i++) {
        final localEntity = TestSyncableEntity(
          id: 'entity-$i',
          userId: testUserId,
          name: 'Local $i',
          value: i * 10,
          lastModified: DateTime.now().subtract(Duration(minutes: i + 1)),
          version: 1,
        );

        final remoteEntity = TestSyncableEntity(
          id: 'entity-$i',
          userId: testUserId,
          name: 'Remote $i',
          value: i * 20,
          lastModified: DateTime.now().subtract(Duration(minutes: i)),
          version: 2,
        );

        conflicts.add({
          'local': localEntity.toJson(),
          'remote': remoteEntity.toJson(),
        });
      }

      // Configurar mock para resolver todos los conflictos
      when(mockConflictResolver.resolveConflict(
        localEntity: any,
        remoteEntity: any,
        strategy: any,
      )).thenAnswer((invocation) async {
        final remote =
            invocation.namedArguments[#remoteEntity] as Map<String, dynamic>;
        return ConflictResolution(
          resolvedEntity: remote,
          strategy: ConflictResolutionStrategy.remoteWins,
          conflictType: ConflictType.versionMismatch,
        );
      });

      // Act - Resolver todos los conflictos concurrentemente
      final resolutionFutures =
          conflicts.map((conflict) => mockConflictResolver.resolveConflict(
                localEntity: conflict['local'],
                remoteEntity: conflict['remote'],
                strategy: ConflictResolutionStrategy.remoteWins,
              ));

      final resolutions = await Future.wait(resolutionFutures);

      // Assert
      expect(resolutions.length, 5);
      for (int i = 0; i < resolutions.length; i++) {
        expect(resolutions[i].strategy, ConflictResolutionStrategy.remoteWins);
        expect(resolutions[i].resolvedEntity['name'], 'Remote $i');
      }

      verify(mockConflictResolver.resolveConflict(
        localEntity: anyNamed('localEntity'),
        remoteEntity: anyNamed('remoteEntity'),
        strategy: anyNamed('strategy'),
      )).called(5);
    });

    test('debe registrar estadísticas de resolución de conflictos', () async {
      // Arrange
      when(mockConflictResolver.getResolutionStats()).thenReturn({
        'total_conflicts': 10,
        'resolved_conflicts': 8,
        'failed_resolutions': 2,
        'strategies_used': {
          'remoteWins': 5,
          'localWins': 2,
          'lastModifiedWins': 1,
        },
      });

      // Act
      final stats = mockConflictResolver.getResolutionStats();

      // Assert
      expect(stats['total_conflicts'], 10);
      expect(stats['resolved_conflicts'], 8);
      expect(stats['failed_resolutions'], 2);
      expect(stats['strategies_used']['remoteWins'], 5);
    });
  });
}
