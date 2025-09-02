import '../../core/sync/conflict_resolution/multiplatform_conflict_resolver.dart';
import '../../core/sync/conflict_resolution/strategies/ratings_conflict_strategy.dart';
import '../../core/sync/conflict_resolution/strategies/watchlist_conflict_strategy.dart';
import '../../domain/entities/syncable_user_movie_rating.dart';
import '../../domain/entities/syncable_watchlist_movie.dart';

/// Servicio para registrar las estrategias de resolución de conflictos
/// en repositorios que manejan sincronización
class ConflictResolutionService {
  /// Registra todas las estrategias de conflicto disponibles en un resolver
  static void registerAllStrategies(MultiplataformConflictResolver resolver) {
    // Registrar estrategia para watchlist
    resolver.registerStrategy<SyncableWatchlistMovie>(
      WatchlistConflictStrategy(),
    );

    // Registrar estrategia para ratings
    resolver.registerStrategy<SyncableUserMovieRating>(
      RatingsConflictStrategy(),
    );
  }

  /// Registra solo la estrategia de watchlist
  static void registerWatchlistStrategy(MultiplataformConflictResolver resolver) {
    resolver.registerStrategy<SyncableWatchlistMovie>(
      WatchlistConflictStrategy(),
    );
  }

  /// Registra solo la estrategia de ratings
  static void registerRatingsStrategy(MultiplataformConflictResolver resolver) {
    resolver.registerStrategy<SyncableUserMovieRating>(
      RatingsConflictStrategy(),
    );
  }
}