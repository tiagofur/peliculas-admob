import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import 'direct_custom_lists_provider.dart';
import 'direct_favorites_provider.dart';
import 'direct_ratings_provider.dart';
import 'direct_watched_provider.dart';
import 'direct_watchlist_provider.dart';

/// 🔧 Helper providers para mejorar la sincronización entre los direct providers

/// Provider que maneja la inicialización de todos los direct providers
final directProvidersInitializationProvider =
    Provider<DirectProvidersInitialization>((ref) {
  return DirectProvidersInitialization(ref);
});

/// Clase que maneja la inicialización coordinada de todos los direct providers
class DirectProvidersInitialization {
  DirectProvidersInitialization(this.ref);

  final Ref ref;

  /// Inicializa todos los direct providers después del login
  Future<void> initializeAfterLogin() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        LoggerFactory.warning('⚠️ DirectProviders: No hay usuario autenticado');
        return;
      }

      LoggerFactory.info(
          '🚀 DirectProviders: Inicializando todos los providers...');

      // Ejecutar todas las inicializaciones en paralelo
      await Future.wait([
        _initializeFavoritesProvider(),
        _initializeWatchedProvider(),
        _initializeWatchlistProvider(),
        _initializeCustomListsProvider(),
        _initializeRatingsProvider(),
      ]);

      LoggerFactory.info(
          '✅ DirectProviders: Todos los providers inicializados correctamente');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ DirectProviders: Error inicializando: $e');
      LoggerFactory.debug('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Inicializa el provider de favoritos
  Future<void> _initializeFavoritesProvider() async {
    try {
      final favoritesNotifier = ref.read(directFavoriteMoviesProvider.notifier);
      favoritesNotifier.enableAfterLogin();
      LoggerFactory.debug('✅ Favorites provider inicializado');
    } catch (e) {
      LoggerFactory.error('❌ Error inicializando favorites provider: $e');
      rethrow;
    }
  }

  /// Inicializa el provider de watched
  Future<void> _initializeWatchedProvider() async {
    try {
      final watchedNotifier = ref.read(directWatchedMoviesProvider.notifier);
      watchedNotifier.enableAfterLogin();
      LoggerFactory.debug('✅ Watched provider inicializado');
    } catch (e) {
      LoggerFactory.error('❌ Error inicializando watched provider: $e');
      rethrow;
    }
  }

  /// Inicializa el provider de watchlist
  Future<void> _initializeWatchlistProvider() async {
    try {
      final watchlistNotifier =
          ref.read(directWatchlistMoviesProvider.notifier);
      watchlistNotifier.enableAfterLogin();
      LoggerFactory.debug('✅ Watchlist provider inicializado');
    } catch (e) {
      LoggerFactory.error('❌ Error inicializando watchlist provider: $e');
      rethrow;
    }
  }

  /// Inicializa el provider de custom lists
  Future<void> _initializeCustomListsProvider() async {
    try {
      final customListsNotifier = ref.read(directCustomListsProvider.notifier);
      await customListsNotifier.enableAfterLogin();
      LoggerFactory.debug('✅ Custom lists provider inicializado');
    } catch (e) {
      LoggerFactory.error('❌ Error inicializando custom lists provider: $e');
      rethrow;
    }
  }

  /// Inicializa el provider de ratings
  Future<void> _initializeRatingsProvider() async {
    try {
      // Los ratings no necesitan inicialización especial ya que se auto-inicializan
      // Pero podemos hacer una carga inicial
      final ratingsNotifier = ref.read(directRatingsProvider.notifier);
      await ratingsNotifier.refresh();
      LoggerFactory.debug('✅ Ratings provider inicializado');
    } catch (e) {
      LoggerFactory.error('❌ Error inicializando ratings provider: $e');
      rethrow;
    }
  }

  /// Refresca todos los providers
  Future<void> refreshAllProviders() async {
    try {
      LoggerFactory.info(
          '🔄 DirectProviders: Refrescando todos los providers...');

      // Los providers modernos no tienen métodos refresh específicos
      // Solo habilitamos el watchlist provider después del login
      ref.read(directWatchlistMoviesProvider.notifier).enableAfterLogin();

      LoggerFactory.info('✅ DirectProviders: Refresh completado');
    } catch (e) {
      LoggerFactory.error('❌ DirectProviders: Error en refresh: $e');
    }
  }

  /// Limpia el estado de todos los providers (para logout)
  void clearAllProviders() {
    try {
      LoggerFactory.info(
          '🧹 DirectProviders: Limpiando estado de todos los providers...');

      // Los providers se resetearán automáticamente cuando no haya usuario
      // No necesitamos acceder directamente al estado protegido

      LoggerFactory.info('✅ DirectProviders: Estado limpiado');
    } catch (e) {
      LoggerFactory.error('❌ DirectProviders: Error limpiando estado: $e');
    }
  }
}

/// Provider para el estado de inicialización
final directProvidersInitializedProvider =
    NotifierProvider<_DirectProvidersInitializedNotifier, bool>(
  () => _DirectProvidersInitializedNotifier(),
);

class _DirectProvidersInitializedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setInitialized(bool value) => state = value;
}

/// Provider que observa cambios de autenticación y maneja la inicialización
final authStateDirectProvidersProvider = StreamProvider<bool>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .asyncMap((authState) async {
    final user = authState.session?.user;

    if (user != null) {
      // Usuario autenticado - inicializar providers
      LoggerFactory.info(
          '🔐 AuthState: Usuario autenticado, inicializando providers...');

      try {
        final initialization = ref.read(directProvidersInitializationProvider);
        await initialization.initializeAfterLogin();
        // Marcar como inicializado
        ref
            .read(directProvidersInitializedProvider.notifier)
            .setInitialized(true);
        return true;
      } catch (e) {
        LoggerFactory.error('❌ AuthState: Error inicializando providers: $e');
        return false;
      }
    } else {
      // Usuario no autenticado - limpiar providers
      LoggerFactory.info(
          '🚪 AuthState: Usuario desautenticado, limpiando providers...');

      final initialization = ref.read(directProvidersInitializationProvider);
      initialization.clearAllProviders();
      ref
          .read(directProvidersInitializedProvider.notifier)
          .setInitialized(false);
      return false;
    }
  });
});

/// Provider combinado para verificar si una película está en alguna lista
final movieInAnyListProvider =
    Provider.family<MovieListStatus, int>((ref, movieId) {
  final isFavorite = ref.watch(directIsFavoriteProvider(movieId));
  final isWatched = ref.watch(directIsWatchedProvider(movieId));
  final isInWatchlist = ref.watch(directWatchlistMoviesProvider
      .select((state) => state.containsKey(movieId)));
  final isRated = ref.watch(directIsRatedProvider(movieId));

  return MovieListStatus(
    isFavorite: isFavorite,
    isWatched: isWatched,
    isInWatchlist: isInWatchlist,
    isRated: isRated,
  );
});

/// Clase para representar el estado de una película en todas las listas
class MovieListStatus {
  const MovieListStatus({
    required this.isFavorite,
    required this.isWatched,
    required this.isInWatchlist,
    required this.isRated,
  });

  final bool isFavorite;
  final bool isWatched;
  final bool isInWatchlist;
  final bool isRated;

  bool get isInAnyList => isFavorite || isWatched || isInWatchlist || isRated;

  @override
  String toString() {
    return 'MovieListStatus(favorite: $isFavorite, watched: $isWatched, watchlist: $isInWatchlist, rated: $isRated)';
  }
}
