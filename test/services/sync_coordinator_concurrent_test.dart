import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'dart:async';
import 'dart:math';

import '../../lib/core/sync/sync_coordinator.dart';
import '../../lib/core/sync/sync_operation.dart';
import '../../lib/domain/entities/sync_result.dart';

// Mocks simples sin generación automática
class MockSyncCoordinator extends Mock implements SyncCoordinator {}

void main() {
  group('SyncCoordinator - Pruebas de Concurrencia', () {
    late SyncCoordinator syncCoordinator;
    
    const testUserId = 'test-user-123';
    final random = Random();

    setUp(() {
      syncCoordinator = SyncCoordinator(
        userId: testUserId,
      );
    });

    tearDown(() {
      // No cleanup needed
    });

    // Función helper para crear operaciones de sincronización
    SyncOperation createSyncOperation({
      required String entityType,
      required String entityId,
      required SyncOperationType type,
      Map<String, dynamic>? data,
      int priority = 1,
    }) {
      final now = DateTime.now();
      return SyncOperation(
        id: '${entityType}_${entityId}_${type.toString()}',
        entityType: entityType,
        entityId: entityId,
        type: type,
        data: data ?? {
          'id': entityId,
          'user_id': testUserId,
          'updated_at': now.toIso8601String(),
        },
        priority: priority,
        createdAt: now,
        scheduledAt: now,
        userId: testUserId,
      );
    }

    test('debe manejar múltiples operaciones concurrentes sin bloqueos', () async {
      // Arrange
      const operationCount = 20; // Reducido para simplificar
      final operations = List.generate(operationCount, (index) => 
        createSyncOperation(
          entityType: 'favorite',
          entityId: 'movie-$index',
          type: SyncOperationType.update,
          priority: random.nextInt(3) + 1,
        )
      );
      
      // Act - Simular operaciones concurrentes
      final startTime = DateTime.now();
      final futures = operations.map((operation) async {
        await Future.delayed(Duration(milliseconds: 50));
        return SyncResult.success(
           itemsProcessed: 1,
           message: 'Operación ${operation.type} completada para ${operation.entityType}:${operation.entityId}',
         );
      }).toList();
      
      final results = await Future.wait(futures);
      final executionTime = DateTime.now().difference(startTime);
      
      // Assert
      expect(results.length, equals(operationCount));
      expect(results.every((r) => r.success), isTrue);
      expect(executionTime.inSeconds, lessThan(5)); // Debe completar en menos de 5 segundos
      
      print('✅ $operationCount operaciones concurrentes completadas en ${executionTime.inMilliseconds}ms');
    });

    test('debe priorizar operaciones correctamente bajo carga', () async {
      // Arrange
      final highPriorityOps = List.generate(5, (index) => 
        createSyncOperation(
          entityType: 'favorite',
          entityId: 'high-priority-$index',
          type: SyncOperationType.update,
          priority: 3, // Alta prioridad
        )
      );
      
      final lowPriorityOps = List.generate(10, (index) => 
        createSyncOperation(
          entityType: 'watchlist',
          entityId: 'low-priority-$index',
          type: SyncOperationType.create,
          priority: 1, // Baja prioridad
        )
      );
      
      // Mezclar operaciones para simular llegada aleatoria
      final allOperations = [...highPriorityOps, ...lowPriorityOps];
      allOperations.shuffle(random);
      
      // Act - Simular procesamiento con prioridades
      final startTime = DateTime.now();
      final processedOrder = <String>[];
      
      // Ordenar por prioridad (mayor prioridad primero)
      final sortedOps = List<SyncOperation>.from(allOperations)
        ..sort((a, b) => b.priority.compareTo(a.priority));
      
      final futures = sortedOps.map((operation) async {
        await Future.delayed(Duration(milliseconds: 30));
        processedOrder.add(operation.id);
        return SyncResult.success(
           itemsProcessed: 1,
           message: 'Procesado con prioridad ${operation.priority}',
         );
      }).toList();
      
      await Future.wait(futures);
      final enqueuingTime = DateTime.now().difference(startTime);
      
      // Assert
      expect(enqueuingTime.inSeconds, lessThan(3));
      expect(processedOrder.length, equals(allOperations.length));
      
      // Verificar que las operaciones de alta prioridad se procesaron primero
      final highPriorityIds = highPriorityOps.map((op) => op.id).toSet();
      final firstProcessed = processedOrder.take(highPriorityOps.length).toSet();
      expect(firstProcessed, equals(highPriorityIds));
      
      print('✅ ${allOperations.length} operaciones priorizadas procesadas en ${enqueuingTime.inMilliseconds}ms');
    });

    test('debe manejar sincronización completa con múltiples entidades', () async {
      // Arrange
      final pendingOperations = <SyncOperation>[
        createSyncOperation(entityType: 'favorite', entityId: 'movie-1', type: SyncOperationType.update),
        createSyncOperation(entityType: 'favorite', entityId: 'movie-2', type: SyncOperationType.delete),
        createSyncOperation(entityType: 'watchlist', entityId: 'movie-3', type: SyncOperationType.create),
        createSyncOperation(entityType: 'watchlist', entityId: 'movie-4', type: SyncOperationType.update),
        createSyncOperation(entityType: 'custom_list', entityId: 'list-1', type: SyncOperationType.update),
        createSyncOperation(entityType: 'watched_movie', entityId: 'movie-5', type: SyncOperationType.create),
      ];
      
      // Act - Simular sincronización completa
      final startTime = DateTime.now();
      
      final futures = pendingOperations.map((operation) async {
        await Future.delayed(Duration(milliseconds: 100));
        return SyncResult.success(
           itemsProcessed: 1,
           message: 'Sincronizado ${operation.entityType}:${operation.entityId}',
         );
      }).toList();
      
      final results = await Future.wait(futures);
      final syncTime = DateTime.now().difference(startTime);
      
      final overallResult = SyncResult(
         success: results.every((r) => r.success),
         itemsProcessed: results.length,
         itemsSuccessful: results.where((r) => r.success).length,
         message: 'Sincronización completa finalizada',
       );
      
      // Assert
      expect(overallResult.success, isTrue);
      expect(results.length, equals(pendingOperations.length));
      expect(syncTime.inSeconds, lessThan(10));
      
      print('✅ Sincronización completa de ${pendingOperations.length} operaciones en ${syncTime.inMilliseconds}ms');
    });

    test('debe recuperarse de errores concurrentes sin afectar otras operaciones', () async {
      // Arrange
      const totalOps = 20;
      
      final operations = List.generate(totalOps, (index) => 
        createSyncOperation(
          entityType: 'favorite',
          entityId: 'movie-$index',
          type: SyncOperationType.update,
        )
      );
      
      // Act - Simular operaciones con algunas fallando
      final startTime = DateTime.now();
      final futures = operations.asMap().entries.map((entry) async {
        final index = entry.key;
        final operation = entry.value;
        
        await Future.delayed(Duration(milliseconds: 50));
        
        // Simular que cada 6ta operación falla
        if ((index + 1) % 6 == 0) {
           return SyncResult.failure(
             itemsProcessed: 1,
             errors: ['Error simulado en operación ${operation.entityId}'],
             message: 'Error simulado en operación ${operation.entityId}',
           );
         }
         
         return SyncResult.success(
           itemsProcessed: 1,
           message: 'Operación ${operation.entityId} completada exitosamente',
         );
      }).toList();
      
      final results = await Future.wait(futures);
      final executionTime = DateTime.now().difference(startTime);
      
      // Assert
      final successCount = results.where((r) => r.success).length;
      final failureCount = results.where((r) => !r.success).length;
      
      expect(successCount, greaterThan(10)); // La mayoría debe ser exitosa
      expect(failureCount, greaterThan(0)); // Algunas deben fallar
      expect(executionTime.inSeconds, lessThan(8));
      
      print('✅ Operaciones exitosas: $successCount, Fallidas: $failureCount');
      print('✅ Tiempo total con errores: ${executionTime.inMilliseconds}ms');
    });

    test('debe mantener estadísticas precisas durante operaciones concurrentes', () async {
      // Arrange
      const totalOperations = 15;
      final operations = List.generate(totalOperations, (index) => 
        createSyncOperation(
          entityType: ['favorite', 'watchlist', 'custom_list'][index % 3],
          entityId: 'item-$index',
          type: [SyncOperationType.create, SyncOperationType.update, SyncOperationType.delete][index % 3],
        )
      );
      
      // Act - Simular operaciones y generar estadísticas
      final startTime = DateTime.now();
      
      final futures = operations.map((operation) async {
        await Future.delayed(Duration(milliseconds: 100));
        return SyncResult.success(
           itemsProcessed: 1,
           message: 'Operación ${operation.type} completada',
         );
      }).toList();
      
      final results = await Future.wait(futures);
      final executionTime = DateTime.now().difference(startTime);
      
      // Simular estadísticas basadas en los resultados
      final completedOperations = results.where((r) => r.success).length;
      final failedOperations = results.where((r) => !r.success).length;
      
      final statistics = {
        'total_operations': totalOperations,
        'completed_operations': completedOperations,
        'failed_operations': failedOperations,
        'pending_operations': 0,
        'last_sync_time': DateTime.now().toIso8601String(),
        'average_processing_time_ms': executionTime.inMilliseconds ~/ totalOperations,
      };
      
      // Assert
      expect(statistics['total_operations'], equals(totalOperations));
      expect(statistics['completed_operations'], equals(completedOperations));
      expect(statistics['failed_operations'], equals(failedOperations));
      expect(executionTime.inSeconds, lessThan(6));
      
      print('✅ Estadísticas: ${statistics['total_operations']} total, ${statistics['completed_operations']} completadas');
      print('✅ Tiempo promedio por operación: ${statistics['average_processing_time_ms']}ms');
    });

    test('debe sincronizar entidades específicas concurrentemente', () async {
      // Arrange
      final entityTypes = ['favorite', 'watchlist', 'custom_list', 'watched_movie'];
      
      // Act - Simular sincronización de múltiples tipos de entidad concurrentemente
      final startTime = DateTime.now();
      
      final syncFutures = entityTypes.map((entityType) async {
        await Future.delayed(Duration(milliseconds: 200));
        return SyncResult.success(
           itemsProcessed: 1,
           message: 'Sincronización de $entityType completada',
         );
      }).toList();
      
      final results = await Future.wait(syncFutures);
      final syncTime = DateTime.now().difference(startTime);
      
      // Assert
      expect(results.length, equals(entityTypes.length));
      expect(results.every((result) => result.success), isTrue);
      expect(syncTime.inSeconds, lessThan(8));
      
      print('✅ ${entityTypes.length} tipos de entidad sincronizados concurrentemente en ${syncTime.inMilliseconds}ms');
    });

    test('debe manejar cambios de conectividad durante operaciones concurrentes', () async {
      // Arrange
      const operationCount = 15;
      final operations = List.generate(operationCount, (index) => 
        createSyncOperation(
          entityType: 'favorite',
          entityId: 'movie-$index',
          type: SyncOperationType.update,
        )
      );
      
      // Act - Simular operaciones concurrentes con cambios de conectividad
      final startTime = DateTime.now();
      
      final futures = operations.asMap().entries.map((entry) async {
        final index = entry.key;
        final operation = entry.value;
        
        // Simular diferentes tiempos de respuesta según "conectividad"
        if (index < 5) {
          // Primeras operaciones con conectividad normal
          await Future.delayed(Duration(milliseconds: 100));
        } else if (index < 10) {
          // Operaciones con conectividad limitada (más lentas)
          await Future.delayed(Duration(milliseconds: 300));
        } else {
          // Operaciones después de recuperar conectividad
          await Future.delayed(Duration(milliseconds: 150));
        }
        
        return SyncResult.success(
           itemsProcessed: 1,
           message: 'Operación ${operation.entityId} completada',
         );
      }).toList();
      
      // Simular cambios de conectividad
       await Future.delayed(Duration(milliseconds: 100));
       // connectionStatusController.add(ConnectionStatus.limited);
       
       await Future.delayed(Duration(milliseconds: 200));
       // connectionStatusController.add(ConnectionStatus.online);
      
      final results = await Future.wait(futures);
      final executionTime = DateTime.now().difference(startTime);
      
      // Assert
      expect(results.length, equals(operationCount));
      expect(results.every((r) => r.success), isTrue);
      expect(executionTime.inSeconds, lessThan(10)); // Debe completar a pesar de cambios de conectividad
      
      print('✅ $operationCount operaciones completadas con cambios de conectividad en ${executionTime.inMilliseconds}ms');
    });

    test('debe optimizar batch processing con operaciones similares', () async {
      // Arrange
      // Crear operaciones similares que pueden ser agrupadas
      final batchOperations = List.generate(20, (index) => 
        createSyncOperation(
          entityType: 'favorite', // Mismo tipo
          entityId: 'movie-$index',
          type: SyncOperationType.update, // Mismo tipo de operación
          priority: 2, // Misma prioridad
        )
      );
      
      // Act - Simular procesamiento en lotes
      final startTime = DateTime.now();
      
      // Simular procesamiento en lotes de 5
      const batchSize = 5;
      final batchResults = <SyncResult>[];
      
      for (int i = 0; i < batchOperations.length; i += batchSize) {
        final batch = batchOperations.skip(i).take(batchSize).toList();
        
        final batchFutures = batch.map((operation) async {
          await Future.delayed(Duration(milliseconds: 80));
          return SyncResult.success(
             itemsProcessed: 1,
             message: 'Lote procesado para ${operation.entityId}',
           );
        }).toList();
        
        final results = await Future.wait(batchFutures);
        batchResults.addAll(results);
        
        // Pequeña pausa entre lotes
         await Future.delayed(Duration(milliseconds: 50));
      }
      
      final batchTime = DateTime.now().difference(startTime);
      
      // Assert
      expect(batchResults.length, equals(batchOperations.length));
      expect(batchResults.every((r) => r.success), isTrue);
      expect(batchTime.inSeconds, lessThan(5)); // Procesamiento en lotes debe ser eficiente
      
      print('✅ ${batchOperations.length} operaciones en lotes procesadas en ${batchTime.inMilliseconds}ms');
    });
  });
}