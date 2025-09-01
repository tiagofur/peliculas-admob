import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/watched_movie.dart';
import '../../domain/entities/watchlist_movie.dart';
import 'web_safe_storage_service.dart';

/// Servicio de inicialización multiplataforma que funciona en Web y nativo
class CrossPlatformInitService {
  CrossPlatformInitService._();
  static CrossPlatformInitService? _instance;
  static CrossPlatformInitService get instance =>
      _instance ??= CrossPlatformInitService._();

  bool _isInitialized = false;

  /// Inicializar todos los servicios de manera compatible con Web
  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        LoggerFactory.info('CrossPlatformInitService ya fue inicializado');
      }
      return;
    }

    try {
      if (kDebugMode) {
        LoggerFactory.info(
            '🚀 Inicializando servicios para ${kIsWeb ? 'Web' : 'plataforma nativa'}...');
      }

      // 1. Inicializar Hive (compatible con Web)
      await _initializeHive();

      // 2. Inicializar servicio de almacenamiento web-safe
      await _initializeWebSafeStorage();

      // 3. Registrar adaptadores de Hive
      await _registerHiveAdapters();

      _isInitialized = true;

      if (kDebugMode) {
        LoggerFactory.info(
            '✅ Servicios inicializados correctamente para ${kIsWeb ? 'Web' : 'plataforma nativa'}');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error inicializando servicios: $e');
      }
      rethrow;
    }
  }

  /// Inicializar Hive de manera compatible con Web
  Future<void> _initializeHive() async {
    try {
      // Inicializar Hive sin usar path_provider
      // Hive.initFlutter() sin parámetros funciona tanto en Web (IndexedDB) como en nativo (directorio por defecto)
      await Hive.initFlutter();

      if (kDebugMode) {
        LoggerFactory.info(
            '📦 Hive inicializado correctamente para ${kIsWeb ? 'Web (IndexedDB)' : 'plataforma nativa'}');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error inicializando Hive: $e');
      }
      rethrow;
    }
  }

  /// Inicializar el servicio de almacenamiento web-safe
  Future<void> _initializeWebSafeStorage() async {
    try {
      // El servicio se inicializa automáticamente al acceder
      final storage = WebSafeStorageService.instance;

      // Verificar que funciona correctamente
      await storage.saveBool('init_test', true);
      final testResult = await storage.getBool('init_test');

      if (testResult) {
        await storage.remove('init_test');
        if (kDebugMode) {
          LoggerFactory.info(
              '💾 WebSafeStorageService inicializado y probado correctamente');
        }
      } else {
        throw Exception('WebSafeStorageService no funciona correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error inicializando WebSafeStorageService: $e');
      }
      rethrow;
    }
  }

  /// Registrar adaptadores de Hive
  Future<void> _registerHiveAdapters() async {
    try {
      // Registrar adaptador de Movie si no está registrado
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(MovieAdapter());
        if (kDebugMode) {
          LoggerFactory.info('🎬 MovieAdapter registrado (ID: 0)');
        }
      }

      // Registrar adaptador de WatchedMovie si no está registrado
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(WatchedMovieAdapter());
        if (kDebugMode) {
          LoggerFactory.info('👁️ WatchedMovieAdapter registrado (ID: 1)');
        }
      }

      // Registrar adaptador de WatchlistPriority si no está registrado
      if (!Hive.isAdapterRegistered(100)) {
        Hive.registerAdapter(WatchlistPriorityAdapter());
        if (kDebugMode) {
          LoggerFactory.info('⭐ WatchlistPriorityAdapter registrado (ID: 100)');
        }
      }

      // Registrar adaptador de WatchlistMovie si no está registrado
      if (!Hive.isAdapterRegistered(101)) {
        Hive.registerAdapter(WatchlistMovieAdapter());
        if (kDebugMode) {
          LoggerFactory.info('📖 WatchlistMovieAdapter registrado (ID: 101)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error registrando adaptadores de Hive: $e');
      }
      rethrow;
    }
  }

  /// Verificar el estado de inicialización
  bool get isInitialized => _isInitialized;

  /// Limpiar todos los datos (útil para logout o reset)
  Future<void> clearAllData() async {
    try {
      if (kDebugMode) {
        LoggerFactory.info('🧹 Limpiando todos los datos...');
      }

      // Limpiar Hive boxes
      if (Hive.isBoxOpen('movies')) {
        final moviesBox = Hive.box<Movie>('movies');
        await moviesBox.clear();
      }

      if (Hive.isBoxOpen('watched_movies')) {
        final watchedBox = Hive.box<WatchedMovie>('watched_movies');
        await watchedBox.clear();
      }

      if (Hive.isBoxOpen('watchlist_movies')) {
        final watchlistBox = Hive.box<WatchlistMovie>('watchlist_movies');
        await watchlistBox.clear();
      }

      // Limpiar SharedPreferences
      final storage = WebSafeStorageService.instance;
      await storage.clearAll();

      if (kDebugMode) {
        LoggerFactory.info('✅ Todos los datos han sido limpiados');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error limpiando datos: $e');
      }
      rethrow;
    }
  }

  /// Cerrar todas las conexiones de manera segura
  Future<void> dispose() async {
    try {
      if (kDebugMode) {
        LoggerFactory.info('🔄 Cerrando conexiones...');
      }

      // Cerrar boxes de Hive si están abiertos
      if (Hive.isBoxOpen('movies')) {
        await Hive.box('movies').close();
      }

      if (Hive.isBoxOpen('watched_movies')) {
        await Hive.box('watched_movies').close();
      }

      _isInitialized = false;

      if (kDebugMode) {
        LoggerFactory.info('✅ Conexiones cerradas correctamente');
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error('❌ Error cerrando conexiones: $e');
      }
      // No rethrow aquí porque es un cleanup
    }
  }

  /// Verificar la salud de todos los servicios
  Future<Map<String, bool>> checkHealth() async {
    final health = <String, bool>{};

    try {
      // Verificar Hive
      try {
        await Hive.openBox('health_check');
        await Hive.box('health_check').put('test', 'value');
        final testValue = Hive.box('health_check').get('test');
        await Hive.box('health_check').close();
        health['hive'] = testValue == 'value';
      } catch (e) {
        health['hive'] = false;
      }

      // Verificar WebSafeStorage
      try {
        final storage = WebSafeStorageService.instance;
        await storage.saveString('health_check', 'test');
        final testValue = await storage.getString('health_check');
        await storage.remove('health_check');
        health['web_safe_storage'] = testValue == 'test';
      } catch (e) {
        health['web_safe_storage'] = false;
      }

      // Verificar adaptadores
      health['movie_adapter'] = Hive.isAdapterRegistered(0);
      health['watched_movie_adapter'] = Hive.isAdapterRegistered(1);

      if (kDebugMode) {
        LoggerFactory.info('🏥 Estado de salud de los servicios:');
        health.forEach((service, isHealthy) {
          LoggerFactory.info('  $service: ${isHealthy ? '✅' : '❌'}');
        });
      }
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.error(
            '❌ Error verificando la salud de los servicios: $e');
      }
    }

    return health;
  }
}
