import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:peliculas/core/sync/conflict_resolver.dart';


import 'package:peliculas/core/sync/entity_sync_manager.dart' as sync_manager;
import 'package:peliculas/domain/entities/syncable_entity.dart';
import 'package:peliculas/infrastructure/services/connectivity_manager.dart';


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

  Map<String, dynamic> toJson() => {
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

    late MockConflictResolver mockConflictResolver;
    late MockConnectivityManager mockConnectivityManager;

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


    });

    test('debe detectar conflicto de versión', () async {
      // Arrange
      final localEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Local Version',
        value: 100,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        lastModifiedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        syncVersion: 1,
      );

      final remoteEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Remote Version',
        value: 200,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        lastModifiedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        syncVersion: 2,
      );

      // Configurar mock para detectar conflicto
      final conflictInfo = sync_manager.ConflictInfo<SyncableEntity>(
          localEntity: localEntity,
          remoteEntity: remoteEntity,
          conflictType: sync_manager.ConflictType.concurrentModification,
          detectedAt: DateTime.now(),
        );
      when(mockConflictResolver.detectConflict<SyncableEntity>(
          localEntity, remoteEntity))
          .thenReturn(conflictInfo);

      when(mockConflictResolver.resolveConflict(
        conflictInfo,
        overrideStrategy: anyNamed('overrideStrategy'),
      )).thenAnswer((_) async => sync_manager.ConflictResolution(
            resolvedEntity: remoteEntity, // Usar versión remota
            strategy: sync_manager.ConflictStrategy.remoteWins,
            resolvedAt: DateTime.now(),
            reason: 'Test resolution',
          ));

      // Act
      final detectedConflict = mockConflictResolver.detectConflict<TestSyncableEntity>(
        localEntity,
        remoteEntity,
      );

      // Assert
      expect(detectedConflict, isNotNull);
      expect(detectedConflict!.conflictType, sync_manager.ConflictType.concurrentModification);
      expect(detectedConflict.localEntity.name, 'Local Version');
      expect(detectedConflict.remoteEntity.name, 'Remote Version');
      verify(mockConflictResolver.detectConflict<TestSyncableEntity>(
          localEntity, remoteEntity)).called(1);
    });

    test('debe resolver conflicto usando estrategia remoteWins', () async {
      // Arrange
      final localEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Local Version',
        value: 100,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        lastModifiedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        syncVersion: 1,
      );

      final remoteEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Remote Version',
        value: 200,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        lastModifiedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        syncVersion: 2,
      );

      final conflictInfo = sync_manager.ConflictInfo<SyncableEntity>(
          localEntity: localEntity,
          remoteEntity: remoteEntity,
          conflictType: sync_manager.ConflictType.concurrentModification,
          detectedAt: DateTime.now(),
        );

      when(mockConflictResolver.resolveConflict<SyncableEntity>(
          conflictInfo,
          overrideStrategy: sync_manager.ConflictStrategy.remoteWins,
        )).thenAnswer((_) async => sync_manager.ConflictResolution(
             strategy: sync_manager.ConflictStrategy.remoteWins,
             resolvedAt: DateTime.now(),
             resolvedEntity: remoteEntity,
             reason: 'Override strategy applied',
           ));

      // Act
      final resolution = await mockConflictResolver.resolveConflict<SyncableEntity>(
          conflictInfo,
          overrideStrategy: sync_manager.ConflictStrategy.remoteWins,
        );

      // Assert
        expect(resolution.strategy, sync_manager.ConflictStrategy.remoteWins);
      expect((resolution.resolvedEntity as TestSyncableEntity).name, 'Remote Version');
      expect((resolution.resolvedEntity as TestSyncableEntity).value, 200);
    });

    test('debe resolver conflicto usando estrategia localWins', () async {
      // Arrange
      final localEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Local Version',
        value: 100,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        lastModifiedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        syncVersion: 2,
      );

      final remoteEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Remote Version',
        value: 200,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        lastModifiedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        syncVersion: 1,
      );

      final conflictInfo = sync_manager.ConflictInfo<SyncableEntity>(
          localEntity: localEntity,
          remoteEntity: remoteEntity,
          conflictType: sync_manager.ConflictType.concurrentModification,
          detectedAt: DateTime.now(),
        );

      when(mockConflictResolver.resolveConflict<SyncableEntity>(
          conflictInfo,
          overrideStrategy: sync_manager.ConflictStrategy.localWins,
        )).thenAnswer((_) async => sync_manager.ConflictResolution(
          strategy: sync_manager.ConflictStrategy.localWins,
          resolvedAt: DateTime.now(),
          resolvedEntity: localEntity,
        ));

      // Act
      final resolution = await mockConflictResolver.resolveConflict<SyncableEntity>(
          conflictInfo,
          overrideStrategy: sync_manager.ConflictStrategy.localWins,
        );

      // Assert
      expect(resolution.strategy, sync_manager.ConflictStrategy.localWins);
      expect((resolution.resolvedEntity as TestSyncableEntity).name, 'Local Version');
      expect((resolution.resolvedEntity as TestSyncableEntity).value, 100);
    });

    test('debe resolver conflicto usando estrategia remoteWins',
        () async {
      // Arrange
      final now = DateTime.now();
      final localEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Local Version',
        value: 100,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        lastModifiedAt: now.subtract(const Duration(minutes: 5)), // Más antiguo
        syncVersion: 1,
      );

      final remoteEntity = TestSyncableEntity(
        id: testEntityId,
        userId: testUserId,
        name: 'Remote Version',
        value: 200,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        lastModifiedAt: now.subtract(const Duration(minutes: 2)), // Más reciente
        syncVersion: 1,
      );

      final conflictInfo = sync_manager.ConflictInfo<SyncableEntity>(
        localEntity: localEntity,
        remoteEntity: remoteEntity,
        conflictType: sync_manager.ConflictType.concurrentModification,
        detectedAt: DateTime.now(),
      );

      when(mockConflictResolver.resolveConflict(
        conflictInfo,
        overrideStrategy: sync_manager.ConflictStrategy.remoteWins,
      )).thenAnswer((_) async => sync_manager.ConflictResolution(
            strategy: sync_manager.ConflictStrategy.remoteWins,
            resolvedAt: DateTime.now(),
            resolvedEntity: remoteEntity, // Remoto es más reciente
          ));

      // Act
      final resolution = await mockConflictResolver.resolveConflict<SyncableEntity>(
        conflictInfo,
        overrideStrategy: sync_manager.ConflictStrategy.remoteWins,
      );

      // Assert
      expect(resolution.strategy, sync_manager.ConflictStrategy.remoteWins);
      expect((resolution.resolvedEntity as TestSyncableEntity).name, 'Remote Version');
      expect(resolution.resolvedEntity.id, 'entity-456');
    });

    test('debe manejar múltiples conflictos concurrentes', () async {
      // Arrange
      final conflicts = List.generate(5, (index) {
          return sync_manager.ConflictInfo<SyncableEntity>(
            localEntity: TestSyncableEntity(
              id: 'local-$index',
              userId: testUserId,
              name: 'Local $index',
              value: index * 10,
              createdAt: DateTime.now().subtract(const Duration(hours: 1)),
              lastModifiedAt: DateTime.now().subtract(Duration(minutes: index)),
              syncVersion: 1,
            ),
            remoteEntity: TestSyncableEntity(
              id: 'remote-$index',
              userId: testUserId,
              name: 'Remote $index',
              value: index * 20,
              createdAt: DateTime.now().subtract(const Duration(hours: 1)),
              lastModifiedAt: DateTime.now(),
              syncVersion: 2,
            ),
            conflictType: sync_manager.ConflictType.concurrentModification,
            detectedAt: DateTime.now(),
          );
        });

      // Configurar mock para resolver todos los conflictos
      for (final conflict in conflicts) {
        when(mockConflictResolver.resolveConflict(
          conflict,
          overrideStrategy: anyNamed('overrideStrategy'),
        )).thenAnswer((invocation) async {
          final conflictInfo = invocation.positionalArguments[0] as sync_manager.ConflictInfo<SyncableEntity>;
          return sync_manager.ConflictResolution(
            strategy: sync_manager.ConflictStrategy.remoteWins,
            resolvedAt: DateTime.now(),
            resolvedEntity: conflictInfo.remoteEntity,
          );
        });
      }

      // Act - Resolver todos los conflictos concurrentemente
      final resolutionFutures =
          conflicts.map((conflict) => mockConflictResolver.resolveConflict<SyncableEntity>(
                conflict,
                overrideStrategy: sync_manager.ConflictStrategy.remoteWins,
              ));

      final resolutions = await Future.wait(resolutionFutures);

      // Assert
      expect(resolutions.length, 5);
      for (int i = 0; i < resolutions.length; i++) {
        expect(resolutions[i].strategy, sync_manager.ConflictStrategy.remoteWins);
        expect((resolutions[i].resolvedEntity as TestSyncableEntity).name, 'Remote $i');
      }

      // Verificar que se llamó para cada conflicto
      for (final conflict in conflicts) {
        verify(mockConflictResolver.resolveConflict(
          conflict,
          overrideStrategy: anyNamed('overrideStrategy'),
        )).called(1);
      }
    });

    test('debe registrar estadísticas de resolución de conflictos', () async {
      // Arrange
      when(mockConflictResolver.getResolutionStats()).thenReturn(<String, int>{
        'favorite_localWins': 5,
        'watchlist_remoteWins': 2,
        'custom_list_userChoice': 1,
      });

      // Act
      final stats = mockConflictResolver.getResolutionStats();

      // Assert
      expect(stats['favorite_localWins'], 5);
      expect(stats['watchlist_remoteWins'], 2);
      expect(stats['custom_list_userChoice'], 1);
      expect(stats.length, 3);
    });
  });
}
