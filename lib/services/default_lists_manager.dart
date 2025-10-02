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
  ///
  /// [userId] - ID del usuario. Si no se proporciona, se obtiene de Supabase.instance
  /// [force] - Fuerza la inicialización aunque ya estén inicializadas
  Future<void> initializeDefaultLists({
    String? userId,
    bool force = false,
  }) async {
    try {
      final isInitialized =
          _prefs.getBool(_defaultListsInitializedKey) ?? false;
      final currentVersion = _prefs.getInt(_defaultListsVersionKey) ?? 0;

      if (force ||
          !isInitialized ||
          currentVersion < _currentDefaultListsVersion) {
        // Obtener el usuario actual
        final String? effectiveUserId =
            userId ?? Supabase.instance.client.auth.currentUser?.id;

        if (effectiveUserId != null) {
          await _createDefaultLists(effectiveUserId);
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
            list.defaultType == config.defaultType && list.userId == userId);

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
  /// MIGRADO: movieIds deprecated, items van en list_items table
  CustomList _createDefaultListFromConfig(
      DefaultListConfig config, String userId) {
    return CustomList(
      id: '', // Se generará en el servidor
      name: config.name,
      description: config.description,
      emoji: config.emoji,
      colorHex: config.color,
      movieIds: [], // Deprecated - items en list_items table
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
      const DefaultListConfig(
        localId: 'quiero-ver',
        name: 'Quiero Ver',
        description: 'Películas que quiero ver próximamente',
        emoji: '🍿',
        color: '#3B82F6',
        defaultType: 'watchlist',
      ),
      const DefaultListConfig(
        localId: 'para-el-fin-de-semana',
        name: 'Para el Fin de Semana',
        description: 'Películas perfectas para relajarse',
        emoji: '🛋️',
        color: '#10B981',
        defaultType: 'weekend',
      ),
      const DefaultListConfig(
        localId: 'noche-de-citas',
        name: 'Noche de Citas',
        description: 'Películas románticas para ver en pareja',
        emoji: '💕',
        color: '#EF4444',
        defaultType: 'date-night',
      ),
      const DefaultListConfig(
        localId: 'con-amigos',
        name: 'Con Amigos',
        description: 'Películas divertidas para ver en grupo',
        emoji: '👥',
        color: '#F59E0B',
        defaultType: 'with-friends',
      ),
      const DefaultListConfig(
        localId: 'clasicos-pendientes',
        name: 'Clásicos Pendientes',
        description: 'Películas clásicas que debo ver',
        emoji: '🎭',
        color: '#8B5CF6',
        defaultType: 'classics',
      ),
      const DefaultListConfig(
        localId: 'accion-y-aventura',
        name: 'Acción y Aventura',
        description: 'Para cuando quiero adrenalina',
        emoji: '💥',
        color: '#D97706',
        defaultType: 'action',
      ),
      const DefaultListConfig(
        localId: 'documentales',
        name: 'Documentales',
        description: 'Para aprender algo nuevo',
        emoji: '📚',
        color: '#06B6D4',
        defaultType: 'documentaries',
      ),
      const DefaultListConfig(
        localId: 'cuando-llueve',
        name: 'Cuando Llueve',
        description: 'Películas perfectas para días lluviosos',
        emoji: '🌧️',
        color: '#64748B',
        defaultType: 'rainy-day',
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
        // MIGRADO: No modificamos movieIds, se vaciarán desde repository
        await _repository.clearListMovies(existingList.id);
        final resetList = existingList.copyWith(
          name: config.name,
          description: config.description,
          emoji: config.emoji,
          colorHex: config.color,
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
  /// MIGRADO: Usa repository methods en lugar de movieIds array
  Future<void> _updateTrendingList() async {
    try {
      final trendingList = await getDefaultListByType('trending');
      if (trendingList != null) {
        // Aquí se integraría con la API de TMDB para obtener trending
        // Por ahora, usamos una lista estática
        final trendingMovieIds = await _fetchTrendingMovieIds();

        // MIGRADO: Limpiar y repoblar usando repository
        await _repository.clearListMovies(trendingList.id);
        for (int i = 0; i < trendingMovieIds.length; i++) {
          await _repository.addMovieToList(trendingList.id, trendingMovieIds[i],
              position: i);
        }

        // Actualizar timestamp
        final updatedList = trendingList.copyWith(
          lastModifiedAt: DateTime.now(),
        );
        await _repository.updateList(updatedList);
      }
    } catch (e) {
      // Error al actualizar lista de tendencias: $e
    }
  }

  /// Actualiza la lista de vistas recientemente
  /// MIGRADO: Usa repository methods en lugar de movieIds array
  Future<void> _updateRecentlyWatchedList() async {
    try {
      final recentlyWatchedList =
          await getDefaultListByType('recently_watched');
      if (recentlyWatchedList != null) {
        // Obtener películas vistas recientemente del historial del usuario
        final recentMovieIds = await _getRecentlyWatchedMovieIds();

        // MIGRADO: Limpiar y repoblar usando repository
        await _repository.clearListMovies(recentlyWatchedList.id);
        for (int i = 0; i < recentMovieIds.length; i++) {
          await _repository.addMovieToList(
              recentlyWatchedList.id, recentMovieIds[i],
              position: i);
        }

        // Actualizar timestamp
        final updatedList = recentlyWatchedList.copyWith(
          lastModifiedAt: DateTime.now(),
        );
        await _repository.updateList(updatedList);
      }
    } catch (e) {
      // Error al actualizar lista de vistas recientemente: $e
    }
  }

  /// Actualiza la lista de recomendaciones
  /// MIGRADO: Usa repository methods en lugar de movieIds array
  Future<void> _updateRecommendationsList() async {
    try {
      final recommendationsList = await getDefaultListByType('recommendations');
      if (recommendationsList != null) {
        // Generar recomendaciones basadas en el historial del usuario
        final recommendedMovieIds = await _generateRecommendations();

        // MIGRADO: Limpiar y repoblar usando repository
        await _repository.clearListMovies(recommendationsList.id);
        for (int i = 0; i < recommendedMovieIds.length; i++) {
          await _repository.addMovieToList(
              recommendationsList.id, recommendedMovieIds[i],
              position: i);
        }

        // Actualizar timestamp
        final updatedList = recommendationsList.copyWith(
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
      // MIGRADO: Contar movies desde repository en lugar de movieIds array
      int totalMovies = 0;
      for (final list in defaultLists) {
        final items = await _repository.getListItems(list.id);
        totalMovies += items.length;
      }
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
