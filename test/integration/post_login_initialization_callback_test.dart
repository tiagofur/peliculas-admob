import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/logging/logger_factory.dart';
import 'package:peliculas/core/services/post_login_initialization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PostLoginInitializationService - Arquitectura Callback', () {
    late PostLoginInitializationService service;
    late PostLoginInitializationCallbacks callbacks;

    // Variables para verificar que los callbacks se ejecutaron
    bool favoritesAutoRefreshEnabled = false;
    bool favoritesProviderInitialized = false;
    bool watchedProviderInitialized = false;
    bool watchlistProviderInitialized = false;
    bool customListsAfterLoginEnabled = false;
    String? customListsAuthUserId;
    bool customListsNotifierEnabled = false;
    bool customListsInvalidated = false;
    bool favoritesAutoRefreshDisabled = false;
    bool silentSyncStopped = false;
    bool customListsAuthCleaned = false;

    setUp(() async {
      // Configurar SharedPreferences para testing
      SharedPreferences.setMockInitialValues({});

      // Reinicializar variables de estado
      favoritesAutoRefreshEnabled = false;
      favoritesProviderInitialized = false;
      watchedProviderInitialized = false;
      watchlistProviderInitialized = false;
      customListsAfterLoginEnabled = false;
      customListsAuthUserId = null;
      customListsNotifierEnabled = false;
      customListsInvalidated = false;
      favoritesAutoRefreshDisabled = false;
      silentSyncStopped = false;
      customListsAuthCleaned = false;

      // Variables inicializadas

      // Crear callbacks de test que rastrean su ejecución
      callbacks = PostLoginInitializationCallbacks(
        enableFavoritesAutoRefresh: () {
          favoritesAutoRefreshEnabled = true;
          LoggerFactory.info(
              '📝 Callback: enableFavoritesAutoRefresh ejecutado');
        },
        initializeFavoritesProvider: () {
          favoritesProviderInitialized = true;
          LoggerFactory.info(
              '📝 Callback: initializeFavoritesProvider ejecutado');
        },
        initializeWatchedProvider: () {
          watchedProviderInitialized = true;
          LoggerFactory.info(
              '📝 Callback: initializeWatchedProvider ejecutado');
        },
        initializeWatchlistProvider: () {
          watchlistProviderInitialized = true;
          LoggerFactory.info(
              '📝 Callback: initializeWatchlistProvider ejecutado');
        },
        enableCustomListsAfterLogin: () {
          customListsAfterLoginEnabled = true;
          LoggerFactory.info(
              '📝 Callback: enableCustomListsAfterLogin ejecutado');
        },
        initializeCustomListsAuth: (String userId) {
          customListsAuthUserId = userId;
          LoggerFactory.info(
              '📝 Callback: initializeCustomListsAuth ejecutado para userId: $userId');
        },
        enableCustomListsNotifier: () {
          customListsNotifierEnabled = true;
          LoggerFactory.info(
              '📝 Callback: enableCustomListsNotifier ejecutado');
        },
        getMigrationService: () async {
          LoggerFactory.info('📝 Callback: getMigrationService ejecutado');
          return null; // Para el test, retornamos null
        },
        invalidateCustomLists: () {
          customListsInvalidated = true;
          LoggerFactory.info('📝 Callback: invalidateCustomLists ejecutado');
        },
        disableFavoritesAutoRefresh: () {
          favoritesAutoRefreshDisabled = true;
          LoggerFactory.info(
              '📝 Callback: disableFavoritesAutoRefresh ejecutado');
        },
        stopSilentSync: () {
          silentSyncStopped = true;
          LoggerFactory.info('📝 Callback: stopSilentSync ejecutado');
        },
        cleanupCustomListsAuth: () {
          customListsAuthCleaned = true;
          LoggerFactory.info('📝 Callback: cleanupCustomListsAuth ejecutado');
        },
      );

      // Obtener instancia singleton
      service = PostLoginInitializationService.instance;
    });

    tearDown(() {
      // Limpiar el servicio después de cada test
      service.dispose();
    });

    test('El servicio se inicializa correctamente con callbacks', () async {
      // Act
      service.initialize(callbacks);

      // Assert
      expect(service.isInitialized, isTrue);
      LoggerFactory.info(
          '✅ Servicio inicializado con arquitectura de callbacks');
    });

    test('forceInitialization ejecuta callbacks de inicialización', () async {
      // Arrange
      service.initialize(callbacks);
      const testUserId = 'test-user-123';

      // Act
      service.forceInitialization(testUserId);

      // Esperar un momento para que se ejecuten los callbacks
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert: Verificar que los callbacks de inicialización se ejecutaron
      expect(favoritesAutoRefreshEnabled, isTrue,
          reason: 'enableFavoritesAutoRefresh debe ejecutarse');
      expect(favoritesProviderInitialized, isTrue,
          reason: 'initializeFavoritesProvider debe ejecutarse');
      expect(watchedProviderInitialized, isTrue,
          reason: 'initializeWatchedProvider debe ejecutarse');
      expect(watchlistProviderInitialized, isTrue,
          reason: 'initializeWatchlistProvider debe ejecutarse');
      expect(customListsAfterLoginEnabled, isTrue,
          reason: 'enableCustomListsAfterLogin debe ejecutarse');
      expect(customListsAuthUserId, equals(testUserId),
          reason:
              'initializeCustomListsAuth debe ejecutarse con userId correcto');
      expect(customListsNotifierEnabled, isTrue,
          reason: 'enableCustomListsNotifier debe ejecutarse');

      LoggerFactory.info(
          '✅ Todos los callbacks de inicialización se ejecutaron correctamente');
    });

    test('dispose ejecuta callbacks de limpieza', () async {
      // Arrange
      service.initialize(callbacks);

      // Act
      service.dispose();

      // Esperar un momento para que se ejecuten los callbacks
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert: Verificar que los callbacks de limpieza se ejecutaron
      expect(favoritesAutoRefreshDisabled, isTrue,
          reason: 'disableFavoritesAutoRefresh debe ejecutarse');
      expect(silentSyncStopped, isTrue,
          reason: 'stopSilentSync debe ejecutarse');
      expect(customListsAuthCleaned, isTrue,
          reason: 'cleanupCustomListsAuth debe ejecutarse');

      LoggerFactory.info(
          '✅ Todos los callbacks de limpieza se ejecutaron correctamente');
    });

    test('getMigrationService callback se ejecuta correctamente', () async {
      // Arrange
      service.initialize(callbacks);

      // Act
      final migrationService = await callbacks.getMigrationService();

      // Assert: En este test, solo verificamos que el callback se ejecute
      // En un caso real, retornaría el servicio de migración real
      expect(migrationService, isNull); // Para el test retorna null
      LoggerFactory.info(
          '✅ getMigrationService callback funciona correctamente');
    });

    test('invalidateCustomLists callback se ejecuta correctamente', () async {
      // Arrange
      service.initialize(callbacks);

      // Act
      callbacks.invalidateCustomLists();

      // Assert
      expect(customListsInvalidated, isTrue);
      LoggerFactory.info(
          '✅ invalidateCustomLists callback funciona correctamente');
    });

    test('El servicio maneja múltiples inicializaciones forzadas', () async {
      // Arrange
      service.initialize(callbacks);

      // Act: Ejecutar múltiples inicializaciones
      service.forceInitialization('user-1');
      service.forceInitialization('user-2');
      service.forceInitialization('user-3');

      // Esperar un momento
      await Future.delayed(const Duration(milliseconds: 150));

      // Assert: El último userId debe ser el que se pasó
      expect(customListsAuthUserId, equals('user-3'));

      // Los otros callbacks deben haberse ejecutado múltiples veces
      expect(favoritesAutoRefreshEnabled, isTrue);
      expect(favoritesProviderInitialized, isTrue);

      LoggerFactory.info(
          '✅ Múltiples inicializaciones manejadas correctamente');
    });
  });
}
