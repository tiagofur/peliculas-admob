import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Gestor avanzado de caché para diferentes tipos de contenido
class AdvancedCacheManager {
  AdvancedCacheManager._();
  static const String _moviePostersKey = 'movie_posters';
  static const String _movieDataKey = 'movie_data';
  static const String _userDataKey = 'user_data';
  static const String _searchResultsKey = 'search_results';

  static AdvancedCacheManager? _instance;

  /// Singleton instance
  static AdvancedCacheManager get instance {
    _instance ??= AdvancedCacheManager._();
    return _instance!;
  }

  /// Cache manager específico para posters de películas
  static CacheManager get moviePosters => CacheManager(
        Config(
          _moviePostersKey,
          stalePeriod: const Duration(days: 30), // 30 días para imágenes
          maxNrOfCacheObjects: 1000, // Máximo 1000 imágenes
          repo: JsonCacheInfoRepository(databaseName: _moviePostersKey),
        ),
      );

  /// Cache manager para datos de películas (JSON)
  static CacheManager get movieData => CacheManager(
        Config(
          _movieDataKey,
          stalePeriod: const Duration(hours: 6), // 6 horas para datos
          maxNrOfCacheObjects: 500,
          repo: JsonCacheInfoRepository(databaseName: _movieDataKey),
        ),
      );

  /// Cache manager para datos de usuario
  static CacheManager get userData => CacheManager(
        Config(
          _userDataKey,
          stalePeriod:
              const Duration(minutes: 30), // 30 minutos para datos de usuario
          maxNrOfCacheObjects: 100,
          repo: JsonCacheInfoRepository(databaseName: _userDataKey),
        ),
      );

  /// Cache manager para resultados de búsqueda
  static CacheManager get searchResults => CacheManager(
        Config(
          _searchResultsKey,
          stalePeriod: const Duration(minutes: 15), // 15 minutos para búsquedas
          maxNrOfCacheObjects: 200,
          repo: JsonCacheInfoRepository(databaseName: _searchResultsKey),
        ),
      );

  /// Limpia selectivamente los caches
  static Future<void> clearExpiredCaches() async {
    await Future.wait([
      moviePosters.emptyCache(),
      movieData.emptyCache(),
      userData.emptyCache(),
      searchResults.emptyCache(),
    ]);
  }

  /// Limpia cache por tipo según prioridad
  static Future<void> manageCacheSizes() async {
    // Obtener información de cache de cada manager
    try {
      // Limpiar en orden de prioridad (menos importantes primero)

      // 1. Limpiar búsquedas (datos más volátiles)
      final searchFiles = await searchResults.getFileFromCache('');
      if (searchFiles == null) {
        await searchResults.emptyCache();
      }

      // 2. Limpiar datos de usuario antiguos
      await userData.emptyCache();

      // Operación completada silenciosamente para evitar logs innecesarios
    } catch (e) {
      // Error manejado silenciosamente
    }
  }

  /// Limpia todos los caches de manera controlada
  static Future<void> performMaintenance() async {
    try {
      await Future.wait([
        searchResults.emptyCache(),
        // Mantener movie posters y movie data por performance
      ]);
      // Mantenimiento completado
    } catch (e) {
      // Error en mantenimiento manejado silenciosamente
    }
  }
}
