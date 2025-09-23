import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/logging/logger_factory.dart';
import '../domain/entities/custom_list.dart';

/// Servicio unificado para gestión de listas predeterminadas
///
/// Este servicio se encarga de:
/// - Crear listas predeterminadas al primer login
/// - Verificar y evitar duplicados
/// - Mantener sincronización entre dispositivos
/// - Manejar actualizaciones de versión
class UnifiedDefaultListsService {
  UnifiedDefaultListsService();

  final _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  // Claves para control de estado
  static const String _defaultListsInitializedKey =
      'unified_default_lists_initialized_v2';
  static const String _defaultListsVersionKey = 'unified_default_lists_version';
  static const String _lastUserInitializedKey =
      'last_user_initialized_default_lists';

  // Versión actual - incrementar cuando cambien las listas
  static const int _currentVersion = 2;

  // ========== MÉTODO PRINCIPAL ==========

  /// Inicializa las listas predeterminadas para el usuario actual
  ///
  /// [forceRecreate] - Si true, elimina y recrea todas las listas
  /// [userId] - ID del usuario (opcional, toma el actual si no se especifica)
  Future<void> initializeDefaultListsForUser({
    bool forceRecreate = false,
    String? userId,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        LoggerFactory.warning(
            '⚠️ No hay usuario autenticado para crear listas predeterminadas');
        return;
      }

      final targetUserId = userId ?? currentUser.id;

      LoggerFactory.info(
          '🎯 Iniciando creación de listas predeterminadas para usuario: $targetUserId');

      // Verificar si ya fueron inicializadas para este usuario
      if (!forceRecreate && await _areListsAlreadyInitialized(targetUserId)) {
        LoggerFactory.info(
            '✅ Listas predeterminadas ya inicializadas para el usuario');
        return;
      }

      // Si es forzado, limpiar listas existentes
      if (forceRecreate) {
        await _cleanupExistingDefaultLists(targetUserId);
      }

      // Crear todas las listas predeterminadas
      final createdLists = await _createAllDefaultLists(targetUserId);

      // Marcar como inicializadas
      await _markAsInitialized(targetUserId);

      LoggerFactory.info(
          '✅ Listas predeterminadas creadas exitosamente: ${createdLists.length} listas');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ Error inicializando listas predeterminadas: $e');
      LoggerFactory.error('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ========== VERIFICACIONES ==========

  /// Verifica si las listas ya fueron inicializadas para el usuario
  Future<bool> _areListsAlreadyInitialized(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Verificar marca local
      final isMarkedLocally =
          prefs.getBool(_defaultListsInitializedKey) ?? false;
      final lastUserInitialized =
          prefs.getString(_lastUserInitializedKey) ?? '';
      final localVersion = prefs.getInt(_defaultListsVersionKey) ?? 0;

      // Si no está marcado localmente o es diferente usuario o versión antigua
      if (!isMarkedLocally ||
          lastUserInitialized != userId ||
          localVersion < _currentVersion) {
        return false;
      }

      // Verificar en Supabase que existan las listas
      final existingLists = await _getExistingDefaultLists(userId);
      final expectedListTypes = _getDefaultListsConfiguration()
          .map((config) => config.defaultType)
          .toSet();
      final existingListTypes =
          existingLists.map((list) => list.defaultType).toSet();

      // Si faltan listas en Supabase, necesitamos recrear
      final missingTypes = expectedListTypes.difference(existingListTypes);
      if (missingTypes.isNotEmpty) {
        LoggerFactory.info('🔍 Faltan listas predeterminadas: $missingTypes');
        return false;
      }

      return true;
    } catch (e) {
      LoggerFactory.error('❌ Error verificando inicialización: $e');
      return false;
    }
  }

  /// Obtiene las listas predeterminadas existentes del usuario
  Future<List<CustomList>> _getExistingDefaultLists(String userId) async {
    try {
      final response = await _supabase
          .from('user_lists')
          .select()
          .eq('user_id', userId)
          .eq('is_default', true)
          .eq('is_deleted', false);

      return (response as List)
          .map((json) => CustomList.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo listas existentes: $e');
      return [];
    }
  }

  // ========== CREACIÓN DE LISTAS ==========

  /// Crea todas las listas predeterminadas
  Future<List<CustomList>> _createAllDefaultLists(String userId) async {
    final createdLists = <CustomList>[];
    final configurations = _getDefaultListsConfiguration();

    for (final config in configurations) {
      try {
        // Verificar si ya existe para evitar duplicados
        final existingList =
            await _findExistingListByType(userId, config.defaultType);

        if (existingList == null) {
          final newList = await _createSingleDefaultList(userId, config);
          createdLists.add(newList);
          LoggerFactory.info('✅ Lista creada: ${config.name}');
        } else {
          LoggerFactory.info('ℹ️ Lista ya existe: ${config.name}');
          createdLists.add(existingList);
        }
      } catch (e) {
        LoggerFactory.error('❌ Error creando lista ${config.name}: $e');
        // Continuar con las demás listas
      }
    }

    return createdLists;
  }

  /// Crea una sola lista predeterminada
  Future<CustomList> _createSingleDefaultList(
      String userId, DefaultListConfiguration config) async {
    final listId = _uuid.v4();
    final now = DateTime.now();

    final listData = {
      'id': listId,
      'user_id': userId,
      'name': config.name,
      'description': config.description,
      'emoji': config.emoji,
      'color_hex': config.colorHex,
      'is_default': true,
      'default_type': config.defaultType,
      'is_public': false,
      'sync_version': 1,
      'is_deleted': false,
      'created_at': now.toIso8601String(),
      'last_modified_at': now.toIso8601String(),
    };

    await _supabase.from('user_lists').insert(listData);

    return CustomList(
      id: listId,
      name: config.name,
      description: config.description,
      emoji: config.emoji,
      colorHex: config.colorHex,
      movieIds: [],
      isDefault: true,
      defaultType: config.defaultType,
      userId: userId,
      createdAt: now,
      lastModifiedAt: now,
      syncStatus: 'synced',
    );
  }

  /// Busca una lista existente por tipo
  Future<CustomList?> _findExistingListByType(
      String userId, String defaultType) async {
    try {
      final response = await _supabase
          .from('user_lists')
          .select()
          .eq('user_id', userId)
          .eq('default_type', defaultType)
          .eq('is_default', true)
          .eq('is_deleted', false)
          .maybeSingle();

      return response != null ? CustomList.fromJson(response) : null;
    } catch (e) {
      return null;
    }
  }

  // ========== CONFIGURACIÓN DE LISTAS ==========

  /// Configuración unificada de todas las listas predeterminadas
  List<DefaultListConfiguration> _getDefaultListsConfiguration() {
    return [
      // Listas principales de uso común
      const DefaultListConfiguration(
        name: 'Quiero Ver',
        description: 'Películas que quiero ver próximamente',
        emoji: '🍿',
        colorHex: '#3B82F6',
        defaultType: 'want_to_watch',
        priority: 1,
      ),
      const DefaultListConfiguration(
        name: 'Mis Favoritas',
        description: 'Películas que más me han gustado',
        emoji: '❤️',
        colorHex: '#EF4444',
        defaultType: 'favorites',
        priority: 2,
      ),
      const DefaultListConfiguration(
        name: 'Vistas Recientemente',
        description: 'Películas que he visto últimamente',
        emoji: '👁️',
        colorHex: '#10B981',
        defaultType: 'recently_watched',
        priority: 3,
      ),

      // Listas temáticas
      const DefaultListConfiguration(
        name: 'Para el Fin de Semana',
        description: 'Películas perfectas para relajarse',
        emoji: '🛋️',
        colorHex: '#8B5CF6',
        defaultType: 'weekend',
        priority: 4,
      ),
      const DefaultListConfiguration(
        name: 'Noche de Citas',
        description: 'Películas románticas para ver en pareja',
        emoji: '💕',
        colorHex: '#EC4899',
        defaultType: 'date_night',
        priority: 5,
      ),
      const DefaultListConfiguration(
        name: 'Con Amigos',
        description: 'Películas divertidas para ver en grupo',
        emoji: '👥',
        colorHex: '#F59E0B',
        defaultType: 'with_friends',
        priority: 6,
      ),
      const DefaultListConfiguration(
        name: 'Clásicos Imperdibles',
        description: 'Las mejores películas de todos los tiempos',
        emoji: '🏆',
        colorHex: '#F97316',
        defaultType: 'classics',
        priority: 7,
      ),
      const DefaultListConfiguration(
        name: 'Cuando Llueve',
        description: 'Películas perfectas para días lluviosos',
        emoji: '🌧️',
        colorHex: '#6366F1',
        defaultType: 'rainy_day',
        priority: 8,
      ),
    ];
  }

  // ========== LIMPIEZA Y MANTENIMIENTO ==========

  /// Limpia listas predeterminadas existentes (para recreación forzada)
  Future<void> _cleanupExistingDefaultLists(String userId) async {
    try {
      LoggerFactory.info('🧹 Limpiando listas predeterminadas existentes...');

      // Marcar como eliminadas (soft delete)
      await _supabase
          .from('user_lists')
          .update({
            'is_deleted': true,
            'last_modified_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_default', true);

      // También limpiar items de esas listas
      await _supabase.from('user_list_items').update({
        'is_deleted': true,
        'last_modified_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      LoggerFactory.info('✅ Limpieza completada');
    } catch (e) {
      LoggerFactory.error('❌ Error en limpieza: $e');
    }
  }

  /// Marca las listas como inicializadas
  Future<void> _markAsInitialized(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_defaultListsInitializedKey, true);
      await prefs.setInt(_defaultListsVersionKey, _currentVersion);
      await prefs.setString(_lastUserInitializedKey, userId);

      LoggerFactory.info(
          '✅ Listas marcadas como inicializadas para usuario: $userId');
    } catch (e) {
      LoggerFactory.error('❌ Error marcando como inicializadas: $e');
    }
  }

  // ========== MÉTODOS PÚBLICOS ADICIONALES ==========

  /// Obtiene todas las listas predeterminadas del usuario actual
  Future<List<CustomList>> getUserDefaultLists() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return [];

    return await _getExistingDefaultLists(currentUser.id);
  }

  /// Verifica si las listas están inicializadas para el usuario actual
  Future<bool> areDefaultListsInitialized() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return false;

    return await _areListsAlreadyInitialized(currentUser.id);
  }

  /// Fuerza la recreación de todas las listas predeterminadas
  Future<void> forceRecreateAllDefaultLists() async {
    await initializeDefaultListsForUser(forceRecreate: true);
  }

  /// Obtiene estadísticas de las listas predeterminadas
  Future<DefaultListsStats> getStats() async {
    try {
      final lists = await getUserDefaultLists();
      final totalMovies =
          lists.fold(0, (sum, list) => sum + list.movieIds.length);

      return DefaultListsStats(
        totalLists: lists.length,
        expectedLists: _getDefaultListsConfiguration().length,
        totalMovies: totalMovies,
        isComplete: lists.length == _getDefaultListsConfiguration().length,
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      return DefaultListsStats(
        totalLists: 0,
        expectedLists: _getDefaultListsConfiguration().length,
        totalMovies: 0,
        isComplete: false,
        lastChecked: DateTime.now(),
      );
    }
  }
}

// ========== CLASES DE DATOS ==========

/// Configuración para una lista predeterminada
class DefaultListConfiguration {
  const DefaultListConfiguration({
    required this.name,
    required this.description,
    required this.emoji,
    required this.colorHex,
    required this.defaultType,
    required this.priority,
  });

  final String name;
  final String description;
  final String emoji;
  final String colorHex;
  final String defaultType;
  final int priority;
}

/// Estadísticas de las listas predeterminadas
class DefaultListsStats {
  const DefaultListsStats({
    required this.totalLists,
    required this.expectedLists,
    required this.totalMovies,
    required this.isComplete,
    required this.lastChecked,
  });

  final int totalLists;
  final int expectedLists;
  final int totalMovies;
  final bool isComplete;
  final DateTime lastChecked;

  bool get isHealthy => totalLists == expectedLists && isComplete;
}
