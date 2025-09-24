import 'package:flutter_test/flutter_test.dart';

// Test de clases aisladas, copiadas del servicio de migración
class LocalDataStatus {
  const LocalDataStatus({
    required this.hasWatchedMovies,
    required this.hasRatings,
    required this.hasCustomLists,
    required this.totalWatchedMovies,
    required this.totalRatings,
    required this.totalCustomLists,
  });

  factory LocalDataStatus.empty() {
    return const LocalDataStatus(
      hasWatchedMovies: false,
      hasRatings: false,
      hasCustomLists: false,
      totalWatchedMovies: 0,
      totalRatings: 0,
      totalCustomLists: 0,
    );
  }

  final bool hasWatchedMovies;
  final bool hasRatings;
  final bool hasCustomLists;
  final int totalWatchedMovies;
  final int totalRatings;
  final int totalCustomLists;

  bool get hasAnyData => hasWatchedMovies || hasRatings || hasCustomLists;
}

class MigrationResult {
  const MigrationResult({
    required this.success,
    required this.migratedWatchedMovies,
    required this.migratedRatings,
    required this.migratedCustomLists,
    this.error,
  });

  factory MigrationResult.success({
    required int migratedWatchedMovies,
    required int migratedRatings,
    required int migratedCustomLists,
  }) {
    return MigrationResult(
      success: true,
      migratedWatchedMovies: migratedWatchedMovies,
      migratedRatings: migratedRatings,
      migratedCustomLists: migratedCustomLists,
    );
  }

  factory MigrationResult.failure({required String error}) {
    return MigrationResult(
      success: false,
      migratedWatchedMovies: 0,
      migratedRatings: 0,
      migratedCustomLists: 0,
      error: error,
    );
  }

  final bool success;
  final int migratedWatchedMovies;
  final int migratedRatings;
  final int migratedCustomLists;
  final String? error;
}

void main() {
  group('Data Migration Classes - Isolated Tests', () {
    test('LocalDataStatus.empty() should initialize correctly', () {
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

    test('LocalDataStatus.hasAnyData should be false when no data exists', () {
      final status = LocalDataStatus.empty();

      expect(status.hasAnyData, false);
    });

    test('LocalDataStatus.hasAnyData should be true when any data exists', () {
      const statusWithWatched = LocalDataStatus(
        hasWatchedMovies: true,
        hasRatings: false,
        hasCustomLists: false,
        totalWatchedMovies: 1,
        totalRatings: 0,
        totalCustomLists: 0,
      );

      const statusWithRatings = LocalDataStatus(
        hasWatchedMovies: false,
        hasRatings: true,
        hasCustomLists: false,
        totalWatchedMovies: 0,
        totalRatings: 1,
        totalCustomLists: 0,
      );

      const statusWithLists = LocalDataStatus(
        hasWatchedMovies: false,
        hasRatings: false,
        hasCustomLists: true,
        totalWatchedMovies: 0,
        totalRatings: 0,
        totalCustomLists: 1,
      );

      expect(statusWithWatched.hasAnyData, true);
      expect(statusWithRatings.hasAnyData, true);
      expect(statusWithLists.hasAnyData, true);
    });
  });
}
