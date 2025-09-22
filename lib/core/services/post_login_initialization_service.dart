import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger_factory.dart';

/// Callbacks para la inicialización post-login sin dependencias de Ref
class PostLoginInitializationCallbacks {
  const PostLoginInitializationCallbacks({
    required this.enableFavoritesAutoRefresh,
    required this.initializeFavoritesProvider,
    required this.initializeWatchedProvider,
    required this.initializeWatchlistProvider,
    required this.enableCustomListsAfterLogin,
    required this.initializeCustomListsAuth,
    required this.enableCustomListsNotifier,
    required this.getMigrationService,
    required this.invalidateCustomLists,
    required this.disableFavoritesAutoRefresh,
    required this.stopSilentSync,
    required this.cleanupCustomListsAuth,
  });

  final VoidCallback enableFavoritesAutoRefresh;
  final VoidCallback initializeFavoritesProvider;
  final VoidCallback initializeWatchedProvider;
  final VoidCallback initializeWatchlistProvider;
  final VoidCallback enableCustomListsAfterLogin;
  final Function(String userId) initializeCustomListsAuth;
  final VoidCallback enableCustomListsNotifier;
  final Future<dynamic> Function() getMigrationService;
  final VoidCallback invalidateCustomLists;
  final VoidCallback disableFavoritesAutoRefresh;
  final VoidCallback stopSilentSync;
  final VoidCallback cleanupCustomListsAuth;
}

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
  PostLoginInitializationCallbacks? _callbacks;

  /// Inicializa el servicio con callbacks específicos (sin Ref)
  void initialize(PostLoginInitializationCallbacks callbacks) {
    if (_isInitialized) return;

    LoggerFactory.info('🚀 Initializing PostLoginInitializationService');
    _callbacks = callbacks;

    // Escuchar cambios de autenticación
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) => _handleAuthStateChange(data),
    );

    // Si ya hay un usuario autenticado, inicializar inmediatamente
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _initializePostLoginServices(currentUser.id);
    }

    _isInitialized = true;
  }

  /// Maneja cambios en el estado de autenticación
  void _handleAuthStateChange(AuthState authState) {
    if (_callbacks == null) return;

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
      _initializePostLoginServices(userId);
      _currentUserId = userId;
    } else if (userId == null && _currentUserId != null) {
      LoggerFactory.info('🔐 User logged out');
      _cleanupServices();
      _currentUserId = null;
    }
  }

  /// Inicializa servicios después del login - MODO NO BLOQUEANTE
  void _initializePostLoginServices(String userId) {
    final callbacks = _callbacks;
    if (callbacks == null) return;

    LoggerFactory.info(
        '🚀 Starting NON-BLOCKING post-login initialization for user: $userId');

    // SOLO habilitar servicios, NO hacer sync automática para evitar bloqueos
    Timer(const Duration(milliseconds: 100), () {
      try {
        callbacks.enableFavoritesAutoRefresh();
        LoggerFactory.info('✅ Auto-refresh habilitado (no bloqueante)');
      } catch (e) {
        LoggerFactory.error('❌ Error habilitando auto-refresh: $e');
      }
    });

    // Inicializar DirectFavoritesProvider para activar listeners de tiempo real
    Timer(const Duration(milliseconds: 200), () {
      try {
        callbacks.initializeFavoritesProvider();
        LoggerFactory.info(
            '✅ DirectFavorites listeners habilitados para sync tiempo real');
      } catch (e) {
        LoggerFactory.error(
            '❌ Error habilitando DirectFavorites listeners: $e');
      }
    });

    // Inicializar DirectWatchedProvider para activar listeners de tiempo real
    Timer(const Duration(milliseconds: 300), () {
      try {
        callbacks.initializeWatchedProvider();
        LoggerFactory.info(
            '✅ DirectWatched listeners habilitados para sync tiempo real');
      } catch (e) {
        LoggerFactory.error('❌ Error habilitando DirectWatched listeners: $e');
      }
    });

    // Inicializar DirectWatchlistProvider para activar listeners de tiempo real
    Timer(const Duration(milliseconds: 400), () {
      try {
        callbacks.initializeWatchlistProvider();
        LoggerFactory.info(
            '✅ DirectWatchlist listeners habilitados para sync tiempo real');
      } catch (e) {
        LoggerFactory.error(
            '❌ Error habilitando DirectWatchlist listeners: $e');
      }
    });

    // Inicializar DirectCustomListsProvider para activar listeners de tiempo real
    Timer(const Duration(milliseconds: 500), () {
      try {
        callbacks.enableCustomListsAfterLogin();
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
        callbacks.initializeCustomListsAuth(userId);
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
        callbacks.enableCustomListsNotifier();
        LoggerFactory.info(
            '✅ CustomListsProvider habilitado para sync tiempo real');
      } catch (e) {
        LoggerFactory.error('❌ Error habilitando CustomListsProvider: $e');
      }
    });

    // Ejecutar migración de listas si es necesario
    Timer(const Duration(milliseconds: 700), () {
      _executeMigrationIfNeeded(userId);
    });

    // NO inicializar sync automática - será manual cuando el usuario interactúe
    LoggerFactory.info(
        'ℹ️ Sync será iniciada manualmente cuando el usuario use favoritos');
  }

  /// Ejecuta la migración de listas si es necesario
  void _executeMigrationIfNeeded(String userId) async {
    final callbacks = _callbacks;
    if (callbacks == null) return;

    try {
      LoggerFactory.info(
          '🔄 Verificando necesidad de migración para usuario: $userId');

      // Obtener instancia del servicio de migración usando callback
      final migrationService = await callbacks.getMigrationService();

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

        // Migrar listas por defecto
        if (migrationPlan.defaultListsToCreate.isNotEmpty) {
          await migrationService.migrateDefaultLists(userId);
          LoggerFactory.info('✅ Listas por defecto migradas');
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
        callbacks.invalidateCustomLists();
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
  void _cleanupServices() {
    final callbacks = _callbacks;
    if (callbacks == null) return;

    LoggerFactory.info('🧹 Cleaning up post-login services');

    try {
      // Deshabilitar auto-refresh
      callbacks.disableFavoritesAutoRefresh();

      // Detener sincronización silenciosa
      callbacks.stopSilentSync();

      // Limpiar servicios de listas personalizadas
      try {
        callbacks.cleanupCustomListsAuth();
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
  void forceInitialization(String userId) {
    LoggerFactory.info(
        '🔧 Force initializing post-login services for: $userId');
    _initializePostLoginServices(userId);
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
