import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/custom_list.dart';
import '../domain/entities/list_item.dart';
import '../domain/repositories/i_custom_lists_repository.dart';

/// Gestor de listas por defecto del sistema
/// Se encarga de crear, mantener y sincronizar las listas predefinidas
class DefaultListsManager {
  const DefaultListsManager(this._repository, this._prefs);

  final ICustomListsRepository _repository;
  final SharedPreferences _prefs;

  // Claves para SharedPreferences
  static const String _defaultListsInitializedKey = 'default_lists_initialized';
  static const String _defaultListsVersionKey = 'default_lists_version';

  // Versión actual de las listas por defecto
  static const int _currentDefaultListsVersion = 1;

  // ========== INICIALIZACIÓN ==========

  /// Inicializa las listas por defecto si es necesario
  Future<void> initializeDefaultLists({bool force = false}) async {
    try {
      final isInitialized =
          _prefs.getBool(_defaultListsInitializedKey) ?? false;
      final currentVersion = _prefs.getInt(_defaultListsVersionKey) ?? 0;

      if (force ||
          !isInitialized ||
          currentVersion < _currentDefaultListsVersion) {
        // Obtener el usuario actual para crear listas con el userId correcto
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          await _createDefaultLists(currentUser.id);
          await _markAsInitialized();
        }
      }
    } catch (e) {
      // Error al inicializar listas por defecto: $e
      rethrow;
    }
  }

  /// Verifica si las listas por defecto están inicializadas
  bool areDefaultListsInitialized() {
    return _prefs.getBool(_defaultListsInitializedKey) ?? false;
  }

  /// Obtiene la versión actual de las listas por defecto
  int getCurrentDefaultListsVersion() {
    return _prefs.getInt(_defaultListsVersionKey) ?? 0;
  }

  // ========== CREACIÓN DE LISTAS POR DEFECTO ==========

  /// Crea todas las listas por defecto del sistema
  Future<void> _createDefaultLists(String userId) async {
    final defaultListsConfig = _getDefaultListsConfiguration();

    for (final config in defaultListsConfig) {
      try {
        // Verificar si la lista ya existe para este usuario específico
        final existingLists = await _repository.getDefaultLists();
        final exists = existingLists.any((list) =>
            list.defaultType == config.defaultType &&
            list.userId == userId);

        if (!exists) {
          final defaultList = _createDefaultListFromConfig(config, userId);
          await _repository.createList(defaultList);
        }
      } catch (e) {
        // Error al crear lista por defecto ${config.name}: $e
      }
    }
  }

  /// Crea una lista por defecto a partir de su configuración
  CustomList _createDefaultListFromConfig(DefaultListConfig config, String userId) {
    return CustomList(
      id: '', // Se generará en el servidor
      name: config.name,
      description: config.description,
      emoji: config.emoji,
      colorHex: config.color,
      movieIds: [],
      isDefault: true,
      defaultType: config.defaultType,
      userId: userId,
      createdAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      syncStatus: 'synced',
    );
  }

  // ========== CONFIGURACIÓN DE LISTAS POR DEFECTO ==========

  /// Obtiene la configuración de todas las listas por defecto
  List<DefaultListConfig> _getDefaultListsConfiguration() {
    return [
      // Lista de Favoritos
      const DefaultListConfig(
        localId: 'favorites',
        name: 'Mis Favoritas',
        description: 'Películas que más me han gustado',
        emoji: '❤️',
        color: '#EF4444',
        defaultType: 'favorites',
      ),

      // Lista de Pendientes por Ver
      const DefaultListConfig(
        localId: 'watchlist',
        name: 'Por Ver',
        description: 'Películas que quiero ver próximamente',
        emoji: '📺',
        color: '#3B82F6',
        defaultType: 'watchlist',
      ),

      // Lista de Vistas Recientemente
      const DefaultListConfig(
        localId: 'recently_watched',
        name: 'Vistas Recientemente',
        description: 'Películas que he visto últimamente',
        emoji: '👁️',
        color: '#10B981',
        defaultType: 'recently_watched',
      ),

      // Lista de Recomendaciones
      const DefaultListConfig(
        localId: 'recommendations',
        name: 'Recomendadas',
        description: 'Películas recomendadas para ti',
        emoji: '🎯',
        color: '#8B5CF6',
        defaultType: 'recommendations',
      ),

      // Lista de Clásicos
      const DefaultListConfig(
        localId: 'classics',
        name: 'Clásicos Imperdibles',
        description: 'Las mejores películas de todos los tiempos',
        emoji: '🏆',
        color: '#F59E0B',
        defaultType: 'classics',
      ),

      // Lista de Trending
      const DefaultListConfig(
        localId: 'trending',
        name: 'Tendencias',
        description: 'Lo más popular del momento',
        emoji: '🔥',
        color: '#EF4444',
        defaultType: 'trending',
      ),
    ];
  }

  /// Obtiene IDs de películas recomendadas
  List<int> _getRecommendedMovieIds() {
    // IDs de películas populares y bien valoradas
    return [
      550, // Fight Club
      238, // The Shawshank Redemption
      680, // Pulp Fiction
      155, // The Dark Knight
      13, // Forrest Gump
      122, // The Lord of the Rings: The Return of the King
      429, // The Good, the Bad and the Ugly
      769, // GoodFellas
      19404, // Dilwale Dulhania Le Jayenge
      278, // The Shawshank Redemption
    ];
  }

  // ========== MÉTODOS PÚBLICOS ==========

  /// Obtiene todas las listas por defecto del usuario
  Future<List<CustomList>> getUserDefaultLists() async {
    return await _repository.getDefaultLists();
  }

  /// Obtiene una lista por defecto específica por tipo
  Future<CustomList?> getDefaultListByType(String defaultType) async {
    final defaultLists = await getUserDefaultLists();
    try {
      return defaultLists.firstWhere(
        (list) => list.defaultType == defaultType,
      );
    } catch (e) {
      return null;
    }
  }

  /// Verifica si una lista por defecto existe
  Future<bool> defaultListExists(String defaultType) async {
    try {
      await getDefaultListByType(defaultType);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Restaura una lista por defecto a su configuración original
  Future<void> resetDefaultList(String defaultType) async {
    try {
      final config = _getDefaultListsConfiguration()
          .firstWhere((c) => c.defaultType == defaultType);

      final existingList = await getDefaultListByType(defaultType);
      if (existingList != null) {
        // Actualizar la lista existente
        final resetList = existingList.copyWith(
          name: config.name,
          description: config.description,
          emoji: config.emoji,
          colorHex: config.color,
          movieIds: [],
          lastModifiedAt: DateTime.now(),
        );

        await _repository.updateList(resetList);
      }
    } catch (e) {
      // Error al restaurar lista por defecto $defaultType: $e
      rethrow;
    }
  }

  /// Actualiza las listas dinámicas (trending, recently watched, etc.)
  Future<void> updateDynamicLists() async {
    try {
      await _updateTrendingList();
      await _updateRecentlyWatchedList();
      await _updateRecommendationsList();
    } catch (e) {
      // Error al actualizar listas dinámicas: $e
    }
  }

  /// Actualiza la lista de tendencias
  Future<void> _updateTrendingList() async {
    try {
      final trendingList = await getDefaultListByType('trending');
      if (trendingList != null) {
        // Aquí se integraría con la API de TMDB para obtener trending
        // Por ahora, usamos una lista estática
        final trendingMovieIds = await _fetchTrendingMovieIds();

        final updatedList = trendingList.copyWith(
          movieIds: trendingMovieIds,
          lastModifiedAt: DateTime.now(),
        );

        await _repository.updateList(updatedList);
      }
    } catch (e) {
      // Error al actualizar lista de tendencias: $e
    }
  }

  /// Actualiza la lista de vistas recientemente
  Future<void> _updateRecentlyWatchedList() async {
    try {
      final recentlyWatchedList =
          await getDefaultListByType('recently_watched');
      if (recentlyWatchedList != null) {
        // Obtener películas vistas recientemente del historial del usuario
        final recentMovieIds = await _getRecentlyWatchedMovieIds();

        final updatedList = recentlyWatchedList.copyWith(
          movieIds: recentMovieIds,
          lastModifiedAt: DateTime.now(),
        );

        await _repository.updateList(updatedList);
      }
    } catch (e) {
      // Error al actualizar lista de vistas recientemente: $e
    }
  }

  /// Actualiza la lista de recomendaciones
  Future<void> _updateRecommendationsList() async {
    try {
      final recommendationsList = await getDefaultListByType('recommendations');
      if (recommendationsList != null) {
        // Generar recomendaciones basadas en el historial del usuario
        final recommendedMovieIds = await _generateRecommendations();

        final updatedList = recommendationsList.copyWith(
          movieIds: recommendedMovieIds,
          lastModifiedAt: DateTime.now(),
        );

        await _repository.updateList(updatedList);
      }
    } catch (e) {
      // Error al actualizar lista de recomendaciones: $e
    }
  }

  // ========== MÉTODOS AUXILIARES ==========

  /// Obtiene IDs de películas trending (simulado)
  Future<List<int>> _fetchTrendingMovieIds() async {
    // En una implementación real, esto consultaría la API de TMDB
    return [
      634649, // Spider-Man: No Way Home
      438631, // Dune
      370172, // No Time to Die
      580489, // Venom: Let There Be Carnage
      524434, // Eternals
      566525, // Shang-Chi and the Legend of the Ten Rings
      460465, // Mortal Kombat
      337404, // Cruella
      399566, // Godzilla vs. Kong
      423108, // The Conjuring: The Devil Made Me Do It
    ];
  }

  /// Obtiene IDs de películas vistas recientemente
  Future<List<int>> _getRecentlyWatchedMovieIds() async {
    // En una implementación real, esto consultaría el historial del usuario
    // Por ahora retornamos una lista vacía
    return [];
  }

  /// Genera recomendaciones basadas en el historial del usuario
  Future<List<int>> _generateRecommendations() async {
    // En una implementación real, esto usaría algoritmos de recomendación
    // Por ahora retornamos las películas recomendadas por defecto
    return _getRecommendedMovieIds();
  }

  /// Marca las listas por defecto como inicializadas
  Future<void> _markAsInitialized() async {
    await _prefs.setBool(_defaultListsInitializedKey, true);
    await _prefs.setInt(_defaultListsVersionKey, _currentDefaultListsVersion);
  }

  /// Permite al usuario personalizar las listas por defecto
  Future<void> customizeDefaultList({
    required String defaultType,
    String? name,
    String? description,
    String? emoji,
    String? colorHex,
  }) async {
    try {
      final list = await getDefaultListByType(defaultType);
      if (list != null) {
        final updatedList = list.copyWith(
          name: name ?? list.name,
          description: description ?? list.description,
          emoji: emoji ?? list.emoji,
          colorHex: colorHex ?? list.colorHex,
          lastModifiedAt: DateTime.now(),
        );

        await _repository.updateList(updatedList);
      }
    } catch (e) {
      // Error al personalizar lista por defecto $defaultType: $e
      rethrow;
    }
  }

  /// Obtiene estadísticas de las listas por defecto
  Future<DefaultListsStats> getDefaultListsStats() async {
    try {
      final defaultLists = await getUserDefaultLists();

      int totalLists = defaultLists.length;
      int totalMovies =
          defaultLists.fold(0, (sum, list) => sum + list.movieIds.length);
      int editableLists = 0;
      int dynamicLists = 0;

      final config = _getDefaultListsConfiguration();
      for (final listConfig in config) {
        // Todas las listas por defecto son editables por el usuario
        editableLists++;
        // Las listas dinámicas son aquellas que se actualizan automáticamente
        if (['trending', 'recommendations', 'recently_watched']
            .contains(listConfig.defaultType)) {
          dynamicLists++;
        }
      }

      return DefaultListsStats(
        totalLists: totalLists,
        totalMovies: totalMovies,
        editableLists: editableLists,
        dynamicLists: dynamicLists,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      // Error al obtener estadísticas de listas por defecto: $e
      rethrow;
    }
  }
}

// ========== CLASES DE DATOS ==========

class DefaultListsStats {
  const DefaultListsStats({
    required this.totalLists,
    required this.totalMovies,
    required this.editableLists,
    required this.dynamicLists,
    required this.lastUpdated,
  });

  final int totalLists;
  final int totalMovies;
  final int editableLists;
  final int dynamicLists;
  final DateTime lastUpdated;
}
