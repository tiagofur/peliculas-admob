import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/sync_operation.dart';
import 'package:peliculas/core/services/batch_operations_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mockito/mockito.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('BatchOperationsManager Tests', () {
    late BatchOperationsManager batchManager;
    late MockSupabaseClient mockSupabaseClient;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      batchManager = BatchOperationsManager(mockSupabaseClient);
    });

    group('Batch Processing Tests', () {
      test('should process empty operations list', () async {
        final result = await batchManager.processBatch([]);
        expect(result.results, isEmpty);
        expect(result.processingTime, equals(Duration.zero));
      });

      test('should process single operation', () async {
        final operations = [
          SyncOperation(
            id: 'single-op',
            type: SyncOperationType.addFavorite,
            data: {
              'movieId': 123,
              'userId': 'user-1',
              'timestamp': DateTime.now().toIso8601String(),
            },
            createdAt: DateTime.now(),
            priority: 1,
          ),
        ];

        final result = await batchManager.processBatch(operations);
        expect(result.results.length, equals(1));
        expect(result.results.first.operationId, equals('single-op'));
      });
    });

    group('Multiple Operations Processing', () {
      test('should process multiple operations of different types', () async {
        final operations = [
          SyncOperation(
            id: 'fav-1',
            type: SyncOperationType.addFavorite,
            data: {
              'movieId': 123,
              'userId': 'user-1',
              'timestamp': DateTime.now().toIso8601String(),
            },
            createdAt: DateTime.now(),
            priority: 1,
          ),
          SyncOperation(
            id: 'watched-1',
            type: SyncOperationType.markWatched,
            data: {
              'movieId': 789,
              'userId': 'user-1',
              'timestamp': DateTime.now().toIso8601String(),
            },
            createdAt: DateTime.now(),
            priority: 1,
          ),
        ];

        final result = await batchManager.processBatch(operations);
        expect(result.results.length, equals(2));
        expect(result.results.map((r) => r.operationId).toList(), 
               containsAll(['fav-1', 'watched-1']));
      });
    });

    group('Error Handling Tests', () {
      test('should handle processing errors gracefully', () async {
        final operations = [
          SyncOperation(
            id: 'invalid-op',
            type: SyncOperationType.addFavorite,
            data: {}, // Invalid data
            createdAt: DateTime.now(),
            priority: 1,
          ),
        ];

        final result = await batchManager.processBatch(operations);
        expect(result.results.length, equals(1));
        expect(result.results.first.operationId, equals('invalid-op'));
      });

      test('should handle mixed operation types', () async {
        final operations = [
          SyncOperation(
            id: 'fav-1',
            type: SyncOperationType.addFavorite,
            data: {
              'movieId': 123,
              'userId': 'user-1',
              'timestamp': DateTime.now().toIso8601String(),
            },
            createdAt: DateTime.now(),
            priority: 1,
          ),
          SyncOperation(
            id: 'remove-fav-1',
            type: SyncOperationType.removeFavorite,
            data: {
              'movieId': 456,
              'userId': 'user-1',
              'timestamp': DateTime.now().toIso8601String(),
            },
            createdAt: DateTime.now(),
            priority: 1,
          ),
        ];

        final result = await batchManager.processBatch(operations);
        expect(result.results.length, equals(2));
        expect(result.results.map((r) => r.operationId).toList(),
               containsAll(['fav-1', 'remove-fav-1']));
      });
    });

    group('Performance Tests', () {
      test('should handle large batch of operations', () async {
        final operations = List.generate(100, (index) => 
          SyncOperation(
            id: 'op-$index',
            type: SyncOperationType.addFavorite,
            data: {
              'movieId': index,
              'userId': 'user-1',
              'timestamp': DateTime.now().toIso8601String(),
            },
            createdAt: DateTime.now(),
            priority: 1,
          ),
        );

        final result = await batchManager.processBatch(operations);
        expect(result.results.length, equals(100));
      });
    });

    group('Timing Tests', () {
      test('should track processing time', () async {
        final operations = [
          SyncOperation(
            id: 'timed-op',
            type: SyncOperationType.addFavorite,
            data: {
              'movieId': 123,
              'userId': 'user-1',
              'timestamp': DateTime.now().toIso8601String(),
            },
            createdAt: DateTime.now(),
            priority: 1,
          ),
        ];

        final result = await batchManager.processBatch(operations);
        expect(result.processingTime, isA<Duration>());
        expect(result.processingTime.inMicroseconds, greaterThanOrEqualTo(0));
      });
    });
  });
}