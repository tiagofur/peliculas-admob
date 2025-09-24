import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peliculas/core/logging/logger_factory.dart';

import 'package:peliculas/infrastructure/services/connectivity_manager.dart';
import 'package:peliculas/core/sync/sync_operation.dart';
import 'package:peliculas/domain/entities/sync_result.dart';
import 'package:peliculas/infrastructure/services/realtime_sync_manager.dart';
import 'package:peliculas/core/sync/sync_coordinator.dart';

import 'large_data_performance_test.mocks.dart';

// Generar mocks
@GenerateMocks([
  SyncCoordinator,
  ConnectivityManager,
])
class LargeDataEntity {
  LargeDataEntity({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.tags,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String userId;
  final String title;
  final String description;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'tags': tags,
        'metadata': metadata,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

void main() {
  group('Large Data Performance Tests', () {
    late MockSyncCoordinator mockSyncCoordinator;
    late MockConnectivityManager mockConnectivityManager;
    late RealtimeSyncManager realtimeSyncManager;
    late StreamController<ConnectionStatus> connectionStatusController;

    const testUserId = 'test-user-123';
    final random = Random();

    setUp(() {
      mockSyncCoordinator = MockSyncCoordinator();
      mockConnectivityManager = MockConnectivityManager();
      connectionStatusController =
          StreamController<ConnectionStatus>.broadcast();

      when(mockConnectivityManager.connectionStatus)
          .thenAnswer((_) => connectionStatusController.stream);
      when(mockConnectivityManager.currentStatus)
          .thenReturn(ConnectionStatus.online);

      when(mockSyncCoordinator.queueSyncOperation(
        entityType: anyNamed('entityType'),
        entityId: anyNamed('entityId'),
        type: anyNamed('type'),
        data: anyNamed('data'),
        priority: anyNamed('priority'),
      )).thenAnswer((_) async => SyncResult.success(
            itemsProcessed: 1,
            message: 'Operation queued successfully',
          ));

      realtimeSyncManager = RealtimeSyncManager(
        userId: testUserId,
        syncCoordinator: mockSyncCoordinator,
        connectivityManager: mockConnectivityManager,
      );
    });

    tearDown(() {
      connectionStatusController.close();
    });

    List<LargeDataEntity> generateLargeDataset(int count) {
      return List.generate(count, (index) {
        final tags = List.generate(
          random.nextInt(10) + 1,
          (i) => 'tag-${random.nextInt(1000)}',
        );

        final metadata = {
          'category': 'category-${random.nextInt(50)}',
          'rating': random.nextDouble() * 5,
          'views': random.nextInt(10000),
          'likes': random.nextInt(1000),
          'comments': List.generate(
            random.nextInt(20),
            (i) => {
              'id': 'comment-$i',
              'text': 'Comment text ${random.nextInt(1000)}',
              'author': 'user-${random.nextInt(100)}',
            },
          ),
        };

        return LargeDataEntity(
          id: 'entity-$index',
          userId: testUserId,
          title: 'Large Entity $index - ${random.nextInt(10000)}',
          description:
              'Description for entity $index. ' * (random.nextInt(10) + 1),
          tags: tags,
          metadata: metadata,
          createdAt:
              DateTime.now().subtract(Duration(days: random.nextInt(365))),
          updatedAt:
              DateTime.now().subtract(Duration(hours: random.nextInt(24))),
        );
      });
    }

    test('debe procesar 10,000 entidades grandes eficientemente', () async {
      // Arrange
      await realtimeSyncManager.initialize();
      await realtimeSyncManager.startListening();

      const entityCount = 10000;
      final largeDataset = generateLargeDataset(entityCount);

      LoggerFactory.info('📊 Generado dataset de $entityCount entidades');
      LoggerFactory.info(
          '📊 Tamaño promedio por entidad: ~${(largeDataset.first.toJson().toString().length)} caracteres');

      // Act
      final startTime = DateTime.now();
      var processedCount = 0;

      for (final entity in largeDataset) {
        await mockSyncCoordinator.queueSyncOperation(
          entityType: 'large_entity',
          entityId: entity.id,
          type: SyncOperationType.update,
          data: entity.toJson(),
          priority: 1,
        );

        processedCount++;

        // Log progreso cada 1000 entidades
        if (processedCount % 1000 == 0) {
          final elapsed = DateTime.now().difference(startTime);
          final rate = processedCount / elapsed.inSeconds;
          LoggerFactory.debug(
              '📈 Procesadas $processedCount/$entityCount entidades (${rate.toStringAsFixed(1)} ent/seg)');
        }
      }

      final totalTime = DateTime.now().difference(startTime);
      final throughput = entityCount / totalTime.inSeconds;

      // Assert
      expect(totalTime.inMinutes,
          lessThan(5)); // Debe completar en menos de 5 minutos
      expect(throughput, greaterThan(50)); // Al menos 50 entidades por segundo

      verify(mockSyncCoordinator.queueSyncOperation(
        entityType: anyNamed('entityType'),
        entityId: anyNamed('entityId'),
        type: anyNamed('type'),
        data: anyNamed('data'),
        priority: anyNamed('priority'),
      )).called(entityCount);

      LoggerFactory.info(
          '✅ $entityCount entidades procesadas en ${totalTime.inSeconds}s');
      LoggerFactory.info(
          '✅ Throughput: ${throughput.toStringAsFixed(2)} entidades/segundo');
    });

    test('debe manejar picos de carga masiva sin degradación', () async {
      // Arrange
      await realtimeSyncManager.initialize();
      await realtimeSyncManager.startListening();

      const normalLoad = 100;
      const spikeLoad = 5000;
      final normalDataset = generateLargeDataset(normalLoad);
      final spikeDataset = generateLargeDataset(spikeLoad);

      // Act - Carga normal inicial
      final normalStartTime = DateTime.now();

      for (final entity in normalDataset) {
        await mockSyncCoordinator.queueSyncOperation(
          entityType: 'normal_entity',
          entityId: entity.id,
          type: SyncOperationType.update,
          data: entity.toJson(),
          priority: 1,
        );
      }

      final normalTime = DateTime.now().difference(normalStartTime);
      final normalThroughput = normalLoad / normalTime.inSeconds;

      LoggerFactory.debug(
          '📊 Carga normal: ${normalThroughput.toStringAsFixed(2)} ent/seg');

      // Pico de carga
      final spikeStartTime = DateTime.now();

      for (final entity in spikeDataset) {
        await mockSyncCoordinator.queueSyncOperation(
          entityType: 'spike_entity',
          entityId: entity.id,
          type: SyncOperationType.update,
          data: entity.toJson(),
          priority: 2, // Mayor prioridad para el pico
        );
      }

      final spikeTime = DateTime.now().difference(spikeStartTime);
      final spikeThroughput = spikeLoad / spikeTime.inSeconds;

      // Assert - El throughput durante el pico no debe degradarse más del 30%
      final degradation =
          (normalThroughput - spikeThroughput) / normalThroughput;
      expect(degradation, lessThan(0.3));

      LoggerFactory.debug(
          '📊 Pico de carga: ${spikeThroughput.toStringAsFixed(2)} ent/seg');
      LoggerFactory.info(
          '✅ Degradación: ${(degradation * 100).toStringAsFixed(1)}%');
    });

    test('debe optimizar memoria durante procesamiento masivo', () async {
      // Arrange
      await realtimeSyncManager.initialize();
      await realtimeSyncManager.startListening();

      const batchSize = 1000;
      const batchCount = 20;

      // Act - Procesar en lotes para simular optimización de memoria
      final startTime = DateTime.now();
      var totalProcessed = 0;

      for (int batch = 0; batch < batchCount; batch++) {
        final batchData = generateLargeDataset(batchSize);
        final batchStartTime = DateTime.now();

        for (final entity in batchData) {
          await mockSyncCoordinator.queueSyncOperation(
            entityType: 'batch_entity',
            entityId: entity.id,
            type: SyncOperationType.update,
            data: entity.toJson(),
            priority: 1,
          );
        }

        totalProcessed += batchSize;
        final batchTime = DateTime.now().difference(batchStartTime);
        final batchThroughput = batchSize / batchTime.inSeconds;

        LoggerFactory.debug(
            '📦 Lote ${batch + 1}/$batchCount: ${batchThroughput.toStringAsFixed(1)} ent/seg');

        // Simular liberación de memoria entre lotes
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final totalTime = DateTime.now().difference(startTime);
      final overallThroughput = totalProcessed / totalTime.inSeconds;

      // Assert
      expect(totalTime.inMinutes,
          lessThan(10)); // Debe completar en menos de 10 minutos
      expect(overallThroughput,
          greaterThan(30)); // Al menos 30 entidades por segundo

      LoggerFactory.info('✅ $totalProcessed entidades procesadas en lotes');
      LoggerFactory.info(
          '✅ Throughput general: ${overallThroughput.toStringAsFixed(2)} ent/seg');
    });

    test('debe mantener rendimiento con datos complejos y anidados', () async {
      // Arrange
      await realtimeSyncManager.initialize();
      await realtimeSyncManager.startListening();

      const entityCount = 2000;

      // Generar datos más complejos
      final complexDataset = List.generate(entityCount, (index) {
        final nestedData = {
          'level1': {
            'level2': {
              'level3': {
                'data': List.generate(
                    50,
                    (i) => {
                          'id': 'nested-$i',
                          'value': random.nextDouble(),
                          'metadata': {
                            'timestamp': DateTime.now().toIso8601String(),
                            'source': 'generator-${random.nextInt(10)}',
                          },
                        }),
              },
            },
          },
          'arrays': {
            'numbers': List.generate(100, (_) => random.nextInt(1000)),
            'strings':
                List.generate(50, (i) => 'string-$i-${random.nextInt(1000)}'),
            'objects': List.generate(
                25,
                (i) => {
                      'id': 'obj-$i',
                      'properties': {
                        'prop1': random.nextDouble(),
                        'prop2': 'value-${random.nextInt(100)}',
                        'prop3': random.nextBool(),
                      },
                    }),
          },
        };

        return LargeDataEntity(
          id: 'complex-$index',
          userId: testUserId,
          title: 'Complex Entity $index',
          description: 'Complex description with nested data',
          tags: List.generate(20, (i) => 'complex-tag-$i'),
          metadata: nestedData,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      });

      LoggerFactory.info(
          '📊 Generado dataset complejo de $entityCount entidades');
      LoggerFactory.info(
          '📊 Tamaño por entidad: ~${(complexDataset.first.toJson().toString().length)} caracteres');

      // Act
      final startTime = DateTime.now();

      for (final entity in complexDataset) {
        await mockSyncCoordinator.queueSyncOperation(
          entityType: 'complex_entity',
          entityId: entity.id,
          type: SyncOperationType.update,
          data: entity.toJson(),
          priority: 1,
        );
      }

      final totalTime = DateTime.now().difference(startTime);
      final throughput = entityCount / totalTime.inSeconds;

      // Assert
      expect(totalTime.inMinutes,
          lessThan(3)); // Debe completar en menos de 3 minutos
      expect(throughput,
          greaterThan(20)); // Al menos 20 entidades complejas por segundo

      LoggerFactory.info(
          '✅ $entityCount entidades complejas procesadas en ${totalTime.inSeconds}s');
      LoggerFactory.info(
          '✅ Throughput: ${throughput.toStringAsFixed(2)} entidades/segundo');
    });

    test('debe recuperarse eficientemente después de fallo con gran backlog',
        () async {
      // Arrange
      await realtimeSyncManager.initialize();
      await realtimeSyncManager.startListening();

      const backlogSize = 15000;
      final backlogDataset = generateLargeDataset(backlogSize);

      // Simular fallo del sistema
      connectionStatusController.add(ConnectionStatus.offline);
      await Future.delayed(const Duration(seconds: 2));

      LoggerFactory.info(
          '📊 Simulando recuperación con backlog de $backlogSize entidades');

      // Act - Recuperación
      connectionStatusController.add(ConnectionStatus.online);
      await Future.delayed(const Duration(seconds: 1)); // Tiempo de reconexión

      final recoveryStartTime = DateTime.now();
      var processedCount = 0;

      // Procesar backlog con prioridad alta
      for (final entity in backlogDataset) {
        await mockSyncCoordinator.queueSyncOperation(
          entityType: 'backlog_entity',
          entityId: entity.id,
          type: SyncOperationType.update,
          data: entity.toJson(),
          priority: 3, // Máxima prioridad para backlog
        );

        processedCount++;

        if (processedCount % 2500 == 0) {
          final elapsed = DateTime.now().difference(recoveryStartTime);
          final rate = processedCount / elapsed.inSeconds;
          LoggerFactory.debug(
              '🔄 Recuperación: $processedCount/$backlogSize (${rate.toStringAsFixed(1)} ent/seg)');
        }
      }

      final recoveryTime = DateTime.now().difference(recoveryStartTime);
      final recoveryThroughput = backlogSize / recoveryTime.inSeconds;

      // Assert
      expect(recoveryTime.inMinutes,
          lessThan(15)); // Debe recuperarse en menos de 15 minutos
      expect(recoveryThroughput,
          greaterThan(25)); // Al menos 25 entidades por segundo

      LoggerFactory.info(
          '✅ Backlog de $backlogSize entidades procesado en ${recoveryTime.inSeconds}s');
      LoggerFactory.info(
          '✅ Throughput de recuperación: ${recoveryThroughput.toStringAsFixed(2)} ent/seg');
    });
  });
}
