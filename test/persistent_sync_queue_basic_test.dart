import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:peliculas/domain/entities/sync_operation.dart';

void main() {
  group('PersistentSyncQueue Basic Tests', () {
    late Directory tempDir;
    late Box<SyncOperation> operationsBox;

    setUpAll(() async {
      // Configurar Hive para testing
      tempDir = await Directory.systemTemp.createTemp('hive_test_');
      Hive.init(tempDir.path);

      // Registrar adaptadores
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(SyncOperationAdapter());
      }
      if (!Hive.isAdapterRegistered(11)) {
        Hive.registerAdapter(SyncOperationTypeAdapter());
      }
      if (!Hive.isAdapterRegistered(12)) {
        Hive.registerAdapter(SyncOperationStatusAdapter());
      }
    });

    setUp(() async {
      operationsBox = await Hive.openBox<SyncOperation>('test_sync_operations');
    });

    tearDown(() async {
      await operationsBox.clear();
      await operationsBox.close();
    });

    tearDownAll(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should store and retrieve sync operations', () async {
      final operation = SyncOperation(
        id: 'test-1',
        type: SyncOperationType.addFavorite,
        data: {'movieId': 123},
        createdAt: DateTime.now(),
      );

      // Almacenar operación
      await operationsBox.put(operation.id, operation);

      // Recuperar operación
      final retrieved = operationsBox.get(operation.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('test-1'));
      expect(retrieved.type, equals(SyncOperationType.addFavorite));
      expect(retrieved.data['movieId'], equals(123));
    });

    test('should store multiple operations', () async {
      final operations = {
        'op-1': SyncOperation(
          id: 'op-1',
          type: SyncOperationType.addFavorite,
          data: {'movieId': 123},
          createdAt: DateTime.now(),
        ),
        'op-2': SyncOperation(
          id: 'op-2',
          type: SyncOperationType.removeFavorite,
          data: {'movieId': 456},
          createdAt: DateTime.now(),
        ),
      };

      // Almacenar múltiples operaciones
      await operationsBox.putAll(operations);

      // Verificar que se almacenaron correctamente
      expect(operationsBox.length, equals(2));
      expect(operationsBox.get('op-1')?.type,
          equals(SyncOperationType.addFavorite));
      expect(operationsBox.get('op-2')?.type,
          equals(SyncOperationType.removeFavorite));
    });

    test('should filter operations by status', () async {
      final operations = {
        'pending-1': SyncOperation(
          id: 'pending-1',
          type: SyncOperationType.addFavorite,
          data: {'movieId': 123},
          createdAt: DateTime.now(),
          status: SyncOperationStatus.pending,
        ),
        'completed-1': SyncOperation(
          id: 'completed-1',
          type: SyncOperationType.removeFavorite,
          data: {'movieId': 456},
          createdAt: DateTime.now(),
          status: SyncOperationStatus.completed,
        ),
        'failed-1': SyncOperation(
          id: 'failed-1',
          type: SyncOperationType.markWatched,
          data: {'movieId': 789},
          createdAt: DateTime.now(),
          status: SyncOperationStatus.failed,
        ),
      };

      await operationsBox.putAll(operations);

      // Filtrar operaciones pendientes
      final pendingOps = operationsBox.values
          .where((op) => op.status == SyncOperationStatus.pending)
          .toList();

      expect(pendingOps.length, equals(1));
      expect(pendingOps.first.id, equals('pending-1'));

      // Filtrar operaciones completadas
      final completedOps = operationsBox.values
          .where((op) => op.status == SyncOperationStatus.completed)
          .toList();

      expect(completedOps.length, equals(1));
      expect(completedOps.first.id, equals('completed-1'));
    });

    test('should calculate basic statistics', () async {
      final operations = {
        'pending-1': SyncOperation(
          id: 'pending-1',
          type: SyncOperationType.addFavorite,
          data: {'movieId': 123},
          createdAt: DateTime.now(),
          status: SyncOperationStatus.pending,
        ),
        'pending-2': SyncOperation(
          id: 'pending-2',
          type: SyncOperationType.removeFavorite,
          data: {'movieId': 456},
          createdAt: DateTime.now(),
          status: SyncOperationStatus.pending,
        ),
        'completed-1': SyncOperation(
          id: 'completed-1',
          type: SyncOperationType.markWatched,
          data: {'movieId': 789},
          createdAt: DateTime.now(),
          status: SyncOperationStatus.completed,
        ),
        'failed-1': SyncOperation(
          id: 'failed-1',
          type: SyncOperationType.unmarkWatched,
          data: {'movieId': 999},
          createdAt: DateTime.now(),
          status: SyncOperationStatus.failed,
        ),
      };

      await operationsBox.putAll(operations);

      final allOps = operationsBox.values.toList();
      final pendingCount = allOps.where((op) => op.status == SyncOperationStatus.pending).length;
      final completedCount = allOps
          .where((op) => op.status == SyncOperationStatus.completed)
          .length;
      final failedCount =
          allOps.where((op) => op.status == SyncOperationStatus.failed).length;
      final totalCount = allOps.length;

      expect(totalCount, equals(4));
      expect(pendingCount, equals(2));
      expect(completedCount, equals(1));
      expect(failedCount, equals(1));

      final successRate = completedCount / totalCount;
      expect(successRate, equals(0.25));
    });

    test('should clear all operations', () async {
      final operations = {
        'op-1': SyncOperation(
          id: 'op-1',
          type: SyncOperationType.addFavorite,
          data: {'movieId': 123},
          createdAt: DateTime.now(),
        ),
        'op-2': SyncOperation(
          id: 'op-2',
          type: SyncOperationType.removeFavorite,
          data: {'movieId': 456},
          createdAt: DateTime.now(),
        ),
      };

      await operationsBox.putAll(operations);
      expect(operationsBox.length, equals(2));

      // Limpiar todas las operaciones
      await operationsBox.clear();
      expect(operationsBox.length, equals(0));
    });
  });
}
