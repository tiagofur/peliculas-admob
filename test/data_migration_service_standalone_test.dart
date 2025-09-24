import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/services/data_migration_service.dart';

void main() {
  group('DataMigrationService - Standalone Tests', () {
    test('LocalDataStatus should initialize correctly', () {
      final status = LocalDataStatus.empty();

      expect(status.hasAnyData, false);
      expect(status.hasWatchedMovies, false);
      expect(status.hasRatings, false);
      expect(status.hasCustomLists, false);
      expect(status.totalWatchedMovies, 0);
      expect(status.totalRatings, 0);
      expect(status.totalCustomLists, 0);
    });

    test('LocalDataStatus with data should work correctly', () {
      const status = LocalDataStatus(
        hasWatchedMovies: true,
        hasRatings: false,
        hasCustomLists: true,
        totalWatchedMovies: 5,
        totalRatings: 0,
        totalCustomLists: 2,
      );

      expect(status.hasAnyData, true);
      expect(status.hasWatchedMovies, true);
      expect(status.hasRatings, false);
      expect(status.hasCustomLists, true);
      expect(status.totalWatchedMovies, 5);
      expect(status.totalRatings, 0);
      expect(status.totalCustomLists, 2);
    });

    test('MigrationResult.success should create successful result', () {
      final result = MigrationResult.success(
        migratedWatchedMovies: 5,
        migratedRatings: 3,
        migratedCustomLists: 2,
      );

      expect(result.success, true);
      expect(result.migratedWatchedMovies, 5);
      expect(result.migratedRatings, 3);
      expect(result.migratedCustomLists, 2);
      expect(result.error, isNull);
    });

    test('MigrationResult.failure should create failure result', () {
      const errorMessage = 'Test error';
      final result = MigrationResult.failure(error: errorMessage);

      expect(result.success, false);
      expect(result.migratedWatchedMovies, 0);
      expect(result.migratedRatings, 0);
      expect(result.migratedCustomLists, 0);
      expect(result.error, errorMessage);
    });
  });
}
