import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/services/data_migration_service.dart';

/// Test simple para validar el servicio de migración de datos
void main() {
  group('DataMigrationService - Basic Tests', () {
    test('should create LocalDataStatus correctly', () {
      // Arrange & Act
      const status = LocalDataStatus(
        hasWatchedMovies: true,
        hasRatings: false,
        hasCustomLists: true,
        totalWatchedMovies: 5,
        totalRatings: 0,
        totalCustomLists: 2,
      );

      // Assert
      expect(status.hasWatchedMovies, isTrue);
      expect(status.hasRatings, isFalse);
      expect(status.hasCustomLists, isTrue);
      expect(status.hasAnyData, isTrue);
      expect(status.totalWatchedMovies, equals(5));
      expect(status.totalRatings, equals(0));
      expect(status.totalCustomLists, equals(2));
    });

    test('should create empty LocalDataStatus', () {
      // Act
      final status = LocalDataStatus.empty();

      // Assert
      expect(status.hasWatchedMovies, isFalse);
      expect(status.hasRatings, isFalse);
      expect(status.hasCustomLists, isFalse);
      expect(status.hasAnyData, isFalse);
      expect(status.totalWatchedMovies, equals(0));
      expect(status.totalRatings, equals(0));
      expect(status.totalCustomLists, equals(0));
    });

    test('should create successful MigrationResult', () {
      // Act
      final result = MigrationResult.success(
        migratedWatchedMovies: 3,
        migratedRatings: 5,
        migratedCustomLists: 1,
      );

      // Assert
      expect(result.success, isTrue);
      expect(result.migratedWatchedMovies, equals(3));
      expect(result.migratedRatings, equals(5));
      expect(result.migratedCustomLists, equals(1));
      expect(result.totalMigrated, equals(9));
      expect(result.error, isNull);
    });

    test('should create failure MigrationResult', () {
      // Act
      const errorMessage = 'Migration failed';
      final result = MigrationResult.failure(error: errorMessage);

      // Assert
      expect(result.success, isFalse);
      expect(result.migratedWatchedMovies, equals(0));
      expect(result.migratedRatings, equals(0));
      expect(result.migratedCustomLists, equals(0));
      expect(result.totalMigrated, equals(0));
      expect(result.error, equals(errorMessage));
    });
  });
}
