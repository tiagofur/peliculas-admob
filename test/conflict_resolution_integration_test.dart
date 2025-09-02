import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';
import 'package:peliculas/domain/entities/syncable_watchlist_movie.dart';
import 'package:peliculas/domain/entities/syncable_user_movie_rating.dart';
import 'package:peliculas/domain/entities/watchlist_movie.dart';
import 'package:peliculas/services/conflict_resolution_service.dart';

/// Test de integración para verificar que el sistema de resolución de conflictos
/// funciona end-to-end con las nuevas estrategias
void main() {
  group('Conflict Resolution Integration Test', () {
    late MultiplataformConflictResolver resolver;

    setUp(() {
      resolver = MultiplataformConflictResolver();
      ConflictResolutionService.registerAllStrategies(resolver);
    });

    test('should demonstrate complete watchlist conflict resolution workflow', () {
      // Simular escenario: Usuario modifica prioridad en dispositivo A,
      // mientras simultáneamente modifica en dispositivo B
      
      final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
      
      // Estado en dispositivo A (local)
      final localWatchlistItem = SyncableWatchlistMovie(
        id: 'watchlist_movie_123',
        userId: 'user_456',
        movieId: 123,
        movieTitle: 'Inception',
        moviePosterPath: '/inception.jpg',
        priority: WatchlistPriority.alta, // Usuario cambió a alta prioridad
        addedAt: baseTime,
        updatedAt: baseTime.add(const Duration(minutes: 5)), // Actualizado hace 5 min
      );

      // Estado en dispositivo B (remoto)
      final remoteWatchlistItem = SyncableWatchlistMovie(
        id: 'watchlist_movie_123',
        userId: 'user_456',
        movieId: 123,
        movieTitle: 'Inception',
        moviePosterPath: '/inception.jpg',
        priority: WatchlistPriority.normal, // Usuario cambió a normal
        addedAt: baseTime,
        updatedAt: baseTime.add(const Duration(minutes: 3)), // Actualizado hace 3 min
      );

      // Resolver conflicto usando last-write-wins
      final result = resolver.resolveConflict(
        localWatchlistItem,
        remoteWatchlistItem,
        ConflictType.simultaneousModification,
      );

      // Verificar que el resultado usa last-write-wins (local gana porque es más reciente)
      expect(result.resolvedItem.priority, equals(WatchlistPriority.alta));
      expect(result.dataLoss, isFalse);
      expect(result.requiresManualIntervention, isFalse);
      expect(result.resolution, contains('most recent timestamp'));
      
      // Verificar que los metadatos están correctos
      expect(result.conflictType, equals(ConflictType.simultaneousModification));
      expect(result.severity, equals(ConflictSeverity.low));
    });

    test('should demonstrate ratings conflict resolution with note merging', () {
      final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
      
      // Usuario actualiza rating en dispositivo A
      final localRating = SyncableUserMovieRating(
        id: 'rating_movie_456',
        userId: 'user_789',
        movieId: 456,
        movieTitle: 'The Matrix',
        rating: 5,
        personalNote: 'Incredible movie with amazing effects and deep philosophy',
        createdAt: baseTime,
        updatedAt: baseTime.add(const Duration(minutes: 8)), // Más reciente
      );

      // Usuario actualiza rating en dispositivo B
      final remoteRating = SyncableUserMovieRating(
        id: 'rating_movie_456',
        userId: 'user_789',
        movieId: 456,
        movieTitle: 'The Matrix',
        rating: 4,
        personalNote: 'Great movie with amazing effects',
        createdAt: baseTime,
        updatedAt: baseTime.add(const Duration(minutes: 4)), // Más antiguo
      );

      // Resolver conflicto
      final result = resolver.resolveConflict(
        localRating,
        remoteRating,
        ConflictType.simultaneousModification,
      );

      // Verificar que last-write-wins funciona para ratings
      expect(result.resolvedItem.rating, equals(5)); // Rating más reciente
      expect(result.resolvedItem.personalNote, equals('Incredible movie with amazing effects and deep philosophy')); // Nota más reciente y completa
      expect(result.dataLoss, isFalse); // No hubo pérdida de datos
      expect(result.requiresManualIntervention, isFalse); // Diferencia de rating no es crítica
    });

    test('should detect when manual intervention is required for ratings', () {
      final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
      
      // Ratings muy diferentes que deberían requerir intervención manual
      final localRating = SyncableUserMovieRating(
        id: 'rating_movie_789',
        userId: 'user_999',
        movieId: 789,
        movieTitle: 'Controversial Movie',
        rating: 5,
        personalNote: 'Best movie ever made! Absolutely brilliant!',
        createdAt: baseTime,
        updatedAt: baseTime.add(const Duration(minutes: 2)), // Muy reciente
      );

      final remoteRating = SyncableUserMovieRating(
        id: 'rating_movie_789',
        userId: 'user_999',
        movieId: 789,
        movieTitle: 'Controversial Movie',
        rating: 1,
        personalNote: 'Worst movie I have ever seen. Complete waste of time.',
        createdAt: baseTime,
        updatedAt: baseTime.add(const Duration(minutes: 1)), // También muy reciente
      );

      final result = resolver.resolveConflict(
        localRating,
        remoteRating,
        ConflictType.simultaneousModification,
      );

      // Debería requerir intervención manual debido a la gran diferencia
      expect(result.requiresManualIntervention, isTrue);
      expect(result.dataLoss, isTrue); // Pérdida significativa de contexto
      expect(result.severity, equals(ConflictSeverity.medium));
    });

    test('should handle deletion conflicts correctly for watchlist', () {
      final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
      
      // Item modificado localmente
      final localItem = SyncableWatchlistMovie(
        id: 'watchlist_deletion_test',
        userId: 'user_delete',
        movieId: 999,
        movieTitle: 'Movie to Delete',
        priority: WatchlistPriority.alta, // Usuario cambió prioridad
        addedAt: baseTime,
        updatedAt: baseTime.add(const Duration(minutes: 5)),
      );

      // Item eliminado remotamente
      final remoteItem = SyncableWatchlistMovie(
        id: 'watchlist_deletion_test',
        userId: 'user_delete',
        movieId: 999,
        movieTitle: 'Movie to Delete',
        priority: WatchlistPriority.normal,
        addedAt: baseTime,
        updatedAt: baseTime.add(const Duration(minutes: 7)),
        deletedAt: baseTime.add(const Duration(minutes: 7)), // Eliminado
      );

      final result = resolver.resolveConflict(
        localItem,
        remoteItem,
        ConflictType.modificationVsDeletion,
      );

      // La eliminación debería ganar
      expect(result.resolvedItem.isDeleted, isTrue);
      expect(result.dataLoss, isTrue); // Se perdió la modificación local
      expect(result.severity, equals(ConflictSeverity.medium));
    });

    test('should get conflict statistics correctly', () {
      // Resolver varios conflictos para generar estadísticas
      final baseTime = DateTime.now().subtract(const Duration(minutes: 10));
      
      // Conflicto 1: Watchlist modification
      final watchlistLocal = SyncableWatchlistMovie(
        id: 'stats_test_1',
        userId: 'user_stats',
        movieId: 111,
        movieTitle: 'Stats Movie 1',
        priority: WatchlistPriority.alta,
        addedAt: baseTime,
        updatedAt: baseTime.add(const Duration(minutes: 5)),
      );
      
      final watchlistRemote = SyncableWatchlistMovie(
        id: 'stats_test_1',
        userId: 'user_stats',
        movieId: 111,
        movieTitle: 'Stats Movie 1',
        priority: WatchlistPriority.normal,
        addedAt: baseTime,
        updatedAt: baseTime.add(const Duration(minutes: 3)),
      );

      resolver.resolveConflict(
        watchlistLocal,
        watchlistRemote,
        ConflictType.simultaneousModification,
      );

      // Conflicto 2: Rating with data loss
      final ratingLocal = SyncableUserMovieRating(
        id: 'stats_rating_1',
        userId: 'user_stats',
        movieId: 222,
        movieTitle: 'Stats Movie 2',
        rating: 5,
        personalNote: 'Amazing!',
        createdAt: baseTime,
        updatedAt: baseTime.add(const Duration(minutes: 2)),
      );

      final ratingRemote = SyncableUserMovieRating(
        id: 'stats_rating_1',
        userId: 'user_stats',
        movieId: 222,
        movieTitle: 'Stats Movie 2',
        rating: 1,
        personalNote: 'Terrible!',
        createdAt: baseTime,
        updatedAt: baseTime.add(const Duration(minutes: 1)),
      );

      resolver.resolveConflict(
        ratingLocal,
        ratingRemote,
        ConflictType.simultaneousModification,
      );

      // Obtener estadísticas
      final stats = resolver.getConflictStats();
      
      expect(stats['totalConflicts'], equals(2));
      expect(stats['conflictsByType']['simultaneousModification'], equals(2));
      expect(stats['dataLossIncidents'], greaterThan(0));
    });
  });
}