import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/providers/auto_default_lists_provider.dart';
import '../../presentation/providers/custom_lists_providers.dart';
import '../../presentation/providers/storage/direct_custom_lists_provider.dart';
import '../../presentation/providers/storage/direct_favorites_provider.dart';
import '../../presentation/providers/storage/direct_watched_provider.dart';
import '../../presentation/providers/storage/direct_watchlist_provider.dart';
import '../../presentation/providers/storage/favorite_movies_provider.dart';
import '../../presentation/providers/unified_ratings_provider.dart';
import '../../presentation/providers/unified_sync_provider.dart';
import '../../services/custom_lists_auth_integration.dart';
import '../../services/unified_rating_service.dart';
import '../logging/logger_factory.dart';
import '../sync/silent_favorites_sync_service.dart';

/// Servicio que maneja la inicialización de servicios después del login
/// para evitar bloqueos durante la autenticación
class PostLoginInitializationService {
  PostLoginInitializationService._internal();

  static final PostLoginInitializationService _instance =
      PostLoginInitializationService._internal();
  static PostLoginInitializationService get instance => _instance;

  StreamSubscription<AuthState>? _authSubscription;
  bool _isInitialized = false;
  String? _currentUserId;

  /// Inicializa el servicio
  void initialize(Ref ref) {
    if (_isInitialized) return;

    LoggerFactory.info('🚀 Initializing PostLoginInitializationService');

    // Escuchar cambios de autenticación
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) => _handleAuthStateChange(data, ref),
    );

    // Si ya hay un usuario autenticado, inicializar inmediatamente
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _initializePostLoginServices(currentUser.id, ref);
    }

    _isInitialized = true;
  }

  /// Maneja cambios en el estado de autenticación
  void _handleAuthStateChange(AuthState authState, Ref ref) {
    String? userId;
    try {
      if (authState.session?.user != null) {
        userId = authState.session?.user.id;
      }
    } catch (e) {
      LoggerFactory.error('❌ Error extracting user ID from auth state: $e');
      userId = null;
    }

    if (userId != null && userId != _currentUserId) {
      LoggerFactory.info('🔐 User logged in: $userId');
      _initializePostLoginServices(userId, ref);
      _currentUserId = userId;
    } else if (userId == null && _currentUserId != null) {
      LoggerFactory.info('🔐 User logged out');
      _cleanupServices(ref);
      _currentUserId = null;
    }
  }

  /// Inicializa servicios después del login - MODO NO BLOQUEANTE
  void _initializePostLoginServices(String userId, Ref ref) {
    LoggerFactory.info(
        '🚀 Starting NON-BLOCKING post-login initialization for user: $userId');

    // ✅ PASO 1: Habilitar sistema unificado de Favorites (PRIORIDAD)
    Timer(const Duration(milliseconds: 50), () {
      try {
        ref.read(unifiedFavoritesProvider.notifier).enableAfterLogin();
        LoggerFactory.info(
            '✅ UnifiedFavorites habilitado para sync tiempo real');
      } catch (e) {
        LoggerFactory.error('❌ Error habilitando UnifiedFavorites: $e');
      }
    });

    // ✅ PASO 2: Habilitar sistema unificado de Watched (PRIORIDAD)
    Timer(const Duration(milliseconds: 100), () {
      try {
        ref.read(unifiedWatchedProvider.notifier).enableAfterLogin();
        LoggerFactory.info('✅ UnifiedWatched habilitado para sync tiempo real');
      } catch (e) {
        LoggerFactory.error('❌ Error habilitando UnifiedWatched: $e');
      }
    });

    // PASO 3: Habilitar auto-refresh (compatibilidad con código existente)
    Timer(const Duration(milliseconds: 150), () {
      try {
        ref.read(favoriteMoviesProvider.notifier).enableAutoRefresh();
        LoggerFactory.info('✅ Auto-refresh habilitado (no bloqueante)');
      } catch (e) {
        LoggerFactory.error('❌ Error habilitando auto-refresh: $e');
      }
    });

    // PASO 4: Inicializar DirectFavoritesProvider (solo para compatibilidad legacy)
    Timer(const Duration(milliseconds: 200), () {
      try {
        ref.read(directFavoriteMoviesProvider.notifier).enableAfterLogin();
        LoggerFactory.info(
            '✅ DirectFavorites listeners habilitados para sync tiempo real');
      } catch (e) {
        LoggerFactory.error(
            '❌ Error habilitando DirectFavorites listeners: $e');
      }
    });

    // PASO 5: Inicializar DirectWatchedProvider (solo para compatibilidad legacy)
    Timer(const Duration(milliseconds: 250), () {
      try {
        ref.read(directWatchedMoviesProvider.notifier).enableAfterLogin();
        LoggerFactory.info(
            '✅ DirectWatched listeners habilitados para sync tiempo real');
      } catch (e) {
        LoggerFactory.error('❌ Error habilitando DirectWatched listeners: $e');
      }
    });

    // PASO 6: Inicializar DirectWatchlistProvider para activar listeners de tiempo real
    Timer(const Duration(milliseconds: 300), () {
      try {
        // Solo acceder al provider para que se inicialice y configure los listeners
        ref.read(directWatchlistMoviesProvider.notifier).enableAfterLogin();
        LoggerFactory.info(
            '✅ DirectWatchlist listeners habilitados para sync tiempo real');
      } catch (e) {
        LoggerFactory.error(
            '❌ Error habilitando DirectWatchlist listeners: $e');
      }
    });

    // PASO 7: Inicializar sistema de ratings unificado para activar listeners de tiempo real
    Timer(const Duration(milliseconds: 350), () {
      try {
        // Inicializar el servicio unificado de ratings
        ref.read(unifiedRatingsProvider.notifier).refresh();
        LoggerFactory.info(
            '✅ UnifiedRatings initialized para sync tiempo real');
      } catch (e) {
        LoggerFactory.error('❌ Error inicializando UnifiedRatings: $e');
      }
    });

    // PASO 8: Inicializar DirectCustomListsProvider para activar listeners de tiempo real
    Timer(const Duration(milliseconds: 400), () {
      try {
        // Solo acceder al provider para que se inicialice y configure los listeners
        ref.read(directCustomListsProvider.notifier).enableAfterLogin();
        LoggerFactory.info(
            '✅ DirectCustomLists listeners habilitados para sync tiempo real');
      } catch (e) {
        LoggerFactory.error(
            '❌ Error habilitando DirectCustomLists listeners: $e');
      }
    });

    // Inicializar sistema de listas personalizadas con integración de autenticación
    Timer(const Duration(milliseconds: 600), () {
      try {
        // Inicializar la integración de autenticación para listas personalizadas
        ref
            .read(customListsAuthIntegrationProvider)
            .forceInitialization(userId, ref);
        LoggerFactory.info(
            '✅ CustomListsAuthIntegration inicializado para sync tiempo real');
      } catch (e) {
        LoggerFactory.error(
            '❌ Error inicializando CustomListsAuthIntegration: $e');
      }
    });

    // Inicializar CustomListsProvider para activar listeners de tiempo real
    Timer(const Duration(milliseconds: 650), () {
      try {
        // Habilitar el provider después del login
        ref.read(customListsNotifierProvider.notifier).enableAfterLogin();
        LoggerFactory.info(
            '✅ CustomListsProvider habilitado para sync tiempo real');
      } catch (e) {
        LoggerFactory.error('❌ Error habilitando CustomListsProvider: $e');
      }
    });

    // Limpiar duplicados de listas predefinidas (one-time, solo primera vez)
    Timer(const Duration(milliseconds: 400), () async {
      await _cleanDuplicateDefaultListsOnce(ref);
    });

    // Inicializar listas predefinidas (con caché para rendimiento)
    Timer(const Duration(milliseconds: 500), () {
      try {
        // Usar ref.read en lugar de ref.watch para evitar listeners innecesarios
        ref.read(autoDefaultListsProvider).ensureDefaultListsExist();
        LoggerFactory.info(
            '✅ Listas predefinidas verificadas para sync tiempo real');
      } catch (e) {
        LoggerFactory.error('❌ Error inicializando listas predefinidas: $e');
      }
    });

    // Ejecutar migración de listas si es necesario
    Timer(const Duration(milliseconds: 700), () {
      _executeMigrationIfNeeded(userId, ref);
    });

    // NO inicializar sync automática - será manual cuando el usuario interactúe
    LoggerFactory.info(
        'ℹ️ Sync será iniciada manualmente cuando el usuario use favoritos');
  }

  /// Limpia duplicados de listas predefinidas (ejecuta solo una vez)
  Future<void> _cleanDuplicateDefaultListsOnce(Ref ref) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanedKey = 'default_lists_cleaned_v2_${DateTime.now().year}';
      final alreadyCleaned = prefs.getBool(cleanedKey) ?? false;

      if (alreadyCleaned) {
        LoggerFactory.debug(
            '✅ Listas predefinidas ya fueron limpiadas anteriormente');
        return;
      }

      LoggerFactory.info('🧹 Limpiando duplicados de listas predefinidas...');

      final defaultListsManager =
          await ref.read(defaultListsManagerProvider.future);
      await defaultListsManager.cleanAndRecreateDefaultLists();

      await prefs.setBool(cleanedKey, true);
      LoggerFactory.info(
          '✅ Duplicados de listas predefinidas eliminados exitosamente');
    } catch (e) {
      LoggerFactory.error('❌ Error limpiando duplicados de listas: $e');
      // No bloquear la inicialización por este error
    }
  }

  /// Ejecuta la migración de listas si es necesario
  void _executeMigrationIfNeeded(String userId, Ref ref) async {
    try {
      LoggerFactory.info(
          '🔄 Verificando necesidad de migración para usuario: $userId');

      // Obtener instancia del servicio de migración desde el provider
      final migrationService =
          await ref.read(listsMigrationServiceProvider.future);

      // Verificar si la migración ya fue completada
      if (migrationService.isMigrationCompleted()) {
        LoggerFactory.info('✅ Migración ya completada para este dispositivo');
        return;
      }

      LoggerFactory.info('🚀 Iniciando proceso de migración de listas...');

      // Analizar necesidades de migración
      final migrationPlan =
          await migrationService.analyzeMigrationNeeds(userId);

      if (migrationPlan.hasWork) {
        LoggerFactory.info(
            '📋 Plan de migración: ${migrationPlan.totalEstimatedTime}ms estimados');

        // ✅ DESHABILITADO: Las listas por defecto ahora se manejan con DefaultListsManager
        // Migrar listas por defecto
        if (migrationPlan.defaultListsToCreate.isNotEmpty) {
          LoggerFactory.info(
              'ℹ️ Omitiendo migración de listas por defecto - usando DefaultListsManager');
          // await migrationService.migrateDefaultLists(userId);
          // LoggerFactory.info('✅ Listas por defecto migradas');
        }

        // Migrar listas personalizadas
        if (migrationPlan.customListsToMigrate.isNotEmpty) {
          await migrationService.migrateCustomLists(userId);
          LoggerFactory.info('✅ Listas personalizadas migradas');
        }

        // Marcar migración como completada
        await migrationService.markMigrationCompleted();
        LoggerFactory.info('🎉 Migración completada exitosamente');

        // Invalidar providers para que recarguen los datos migrados
        ref.invalidate(directCustomListsProvider);
      } else {
        LoggerFactory.info('ℹ️ No hay datos locales para migrar');
        // Marcar como completada para evitar verificaciones futuras
        await migrationService.markMigrationCompleted();
      }
    } catch (e) {
      LoggerFactory.error('❌ Error durante la migración: $e');
      // No bloquear la inicialización por errores de migración
    }
  }

  /// Limpia servicios cuando el usuario se desconecta
  void _cleanupServices(Ref ref) {
    LoggerFactory.info('🧹 Cleaning up post-login services');

    try {
      // Deshabilitar auto-refresh
      ref.read(favoriteMoviesProvider.notifier).disableAutoRefresh();

      // Detener sincronización silenciosa
      SilentFavoritesSyncService.instance.stopSync();

      // Limpiar sistema de ratings unificado
      try {
        UnifiedRatingService.instance.dispose();
        LoggerFactory.info('✅ UnifiedRatings cleaned up');
      } catch (e) {
        LoggerFactory.error('❌ Error cleaning up UnifiedRatings: $e');
      }

      // Limpiar servicios de listas personalizadas
      try {
        ref.read(customListsAuthIntegrationProvider);
        LoggerFactory.info('✅ CustomListsAuthIntegration cleaned up');
      } catch (e) {
        LoggerFactory.error(
            '❌ Error cleaning up CustomListsAuthIntegration: $e');
      }

      LoggerFactory.info('✅ Post-login services cleaned up');
    } catch (e) {
      LoggerFactory.error('❌ Error cleaning up services: $e');
    }
  }

  /// Fuerza la inicialización manual para un usuario específico
  void forceInitialization(String userId, Ref ref) {
    LoggerFactory.info(
        '🔧 Force initializing post-login services for: $userId');
    _initializePostLoginServices(userId, ref);
    _currentUserId = userId;
  }

  /// Verifica si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  /// Obtiene el ID del usuario actual
  String? get currentUserId => _currentUserId;

  /// Cierra el servicio
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _isInitialized = false;
    _currentUserId = null;

    LoggerFactory.info('🗑️ PostLoginInitializationService disposed');
  }
}
