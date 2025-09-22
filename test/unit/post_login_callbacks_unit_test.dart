import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/logging/logger_factory.dart';
import 'package:peliculas/core/services/post_login_initialization_service.dart';

void main() {
  group('PostLoginInitializationCallbacks - Unit Tests', () {
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
      // Reinicializar variables de estado antes de cada test
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
    });

    test('PostLoginInitializationCallbacks se crea correctamente', () {
      // Assert
      expect(callbacks, isNotNull);
      expect(callbacks.enableFavoritesAutoRefresh, isNotNull);
      expect(callbacks.initializeFavoritesProvider, isNotNull);
      expect(callbacks.initializeWatchedProvider, isNotNull);
      expect(callbacks.initializeWatchlistProvider, isNotNull);
      expect(callbacks.enableCustomListsAfterLogin, isNotNull);
      expect(callbacks.initializeCustomListsAuth, isNotNull);
      expect(callbacks.enableCustomListsNotifier, isNotNull);
      expect(callbacks.getMigrationService, isNotNull);
      expect(callbacks.invalidateCustomLists, isNotNull);
      expect(callbacks.disableFavoritesAutoRefresh, isNotNull);
      expect(callbacks.stopSilentSync, isNotNull);
      expect(callbacks.cleanupCustomListsAuth, isNotNull);

      LoggerFactory.info('✅ Todos los callbacks están definidos correctamente');
    });

    test('enableFavoritesAutoRefresh callback funciona', () {
      // Act
      callbacks.enableFavoritesAutoRefresh();

      // Assert
      expect(favoritesAutoRefreshEnabled, isTrue);
      LoggerFactory.info(
          '✅ enableFavoritesAutoRefresh callback ejecutado correctamente');
    });

    test('initializeFavoritesProvider callback funciona', () {
      // Act
      callbacks.initializeFavoritesProvider();

      // Assert
      expect(favoritesProviderInitialized, isTrue);
      LoggerFactory.info(
          '✅ initializeFavoritesProvider callback ejecutado correctamente');
    });

    test('initializeWatchedProvider callback funciona', () {
      // Act
      callbacks.initializeWatchedProvider();

      // Assert
      expect(watchedProviderInitialized, isTrue);
      LoggerFactory.info(
          '✅ initializeWatchedProvider callback ejecutado correctamente');
    });

    test('initializeWatchlistProvider callback funciona', () {
      // Act
      callbacks.initializeWatchlistProvider();

      // Assert
      expect(watchlistProviderInitialized, isTrue);
      LoggerFactory.info(
          '✅ initializeWatchlistProvider callback ejecutado correctamente');
    });

    test('enableCustomListsAfterLogin callback funciona', () {
      // Act
      callbacks.enableCustomListsAfterLogin();

      // Assert
      expect(customListsAfterLoginEnabled, isTrue);
      LoggerFactory.info(
          '✅ enableCustomListsAfterLogin callback ejecutado correctamente');
    });

    test('initializeCustomListsAuth callback funciona con userId', () {
      // Arrange
      const testUserId = 'test-user-123';

      // Act
      callbacks.initializeCustomListsAuth(testUserId);

      // Assert
      expect(customListsAuthUserId, equals(testUserId));
      LoggerFactory.info(
          '✅ initializeCustomListsAuth callback ejecutado correctamente');
    });

    test('enableCustomListsNotifier callback funciona', () {
      // Act
      callbacks.enableCustomListsNotifier();

      // Assert
      expect(customListsNotifierEnabled, isTrue);
      LoggerFactory.info(
          '✅ enableCustomListsNotifier callback ejecutado correctamente');
    });

    test('getMigrationService callback funciona', () async {
      // Act
      final result = await callbacks.getMigrationService();

      // Assert
      expect(result, isNull); // En el test retorna null
      LoggerFactory.info(
          '✅ getMigrationService callback ejecutado correctamente');
    });

    test('invalidateCustomLists callback funciona', () {
      // Act
      callbacks.invalidateCustomLists();

      // Assert
      expect(customListsInvalidated, isTrue);
      LoggerFactory.info(
          '✅ invalidateCustomLists callback ejecutado correctamente');
    });

    test('disableFavoritesAutoRefresh callback funciona', () {
      // Act
      callbacks.disableFavoritesAutoRefresh();

      // Assert
      expect(favoritesAutoRefreshDisabled, isTrue);
      LoggerFactory.info(
          '✅ disableFavoritesAutoRefresh callback ejecutado correctamente');
    });

    test('stopSilentSync callback funciona', () {
      // Act
      callbacks.stopSilentSync();

      // Assert
      expect(silentSyncStopped, isTrue);
      LoggerFactory.info('✅ stopSilentSync callback ejecutado correctamente');
    });

    test('cleanupCustomListsAuth callback funciona', () {
      // Act
      callbacks.cleanupCustomListsAuth();

      // Assert
      expect(customListsAuthCleaned, isTrue);
      LoggerFactory.info(
          '✅ cleanupCustomListsAuth callback ejecutado correctamente');
    });

    test('Múltiples callbacks pueden ejecutarse en secuencia', () {
      // Act: Ejecutar múltiples callbacks
      callbacks.enableFavoritesAutoRefresh();
      callbacks.initializeFavoritesProvider();
      callbacks.initializeWatchedProvider();
      callbacks.initializeWatchlistProvider();
      callbacks.enableCustomListsAfterLogin();
      callbacks.initializeCustomListsAuth('multi-user-test');
      callbacks.enableCustomListsNotifier();

      // Assert: Verificar que todos se ejecutaron
      expect(favoritesAutoRefreshEnabled, isTrue);
      expect(favoritesProviderInitialized, isTrue);
      expect(watchedProviderInitialized, isTrue);
      expect(watchlistProviderInitialized, isTrue);
      expect(customListsAfterLoginEnabled, isTrue);
      expect(customListsAuthUserId, equals('multi-user-test'));
      expect(customListsNotifierEnabled, isTrue);

      LoggerFactory.info(
          '✅ Múltiples callbacks ejecutados correctamente en secuencia');
    });

    test('Callbacks de limpieza funcionan correctamente', () {
      // Act: Ejecutar callbacks de limpieza
      callbacks.disableFavoritesAutoRefresh();
      callbacks.stopSilentSync();
      callbacks.cleanupCustomListsAuth();

      // Assert: Verificar que todos los callbacks de limpieza se ejecutaron
      expect(favoritesAutoRefreshDisabled, isTrue);
      expect(silentSyncStopped, isTrue);
      expect(customListsAuthCleaned, isTrue);

      LoggerFactory.info('✅ Callbacks de limpieza ejecutados correctamente');
    });
  });
}
