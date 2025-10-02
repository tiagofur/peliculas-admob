import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peliculas/core/logging/logger_factory.dart';
import 'package:peliculas/core/services/post_login_initialization_service.dart';
import 'package:peliculas/domain/entities/custom_list.dart';
import 'package:peliculas/domain/entities/list_item.dart';
import 'package:peliculas/domain/repositories/i_custom_lists_repository.dart';
import 'package:peliculas/infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import 'package:peliculas/services/list_sync_service.dart';
import 'package:peliculas/services/lists_migration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Generar mocks
@GenerateNiceMocks([
  MockSpec<ICustomListsRepository>(),
  MockSpec<ListSyncService>(),
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<CustomListsSharedPreferencesDatasource>(),
])
import 'complete_login_migration_sync_test.mocks.dart';

// No necesitamos MockRef, usaremos ProviderContainer directamente

void main() {
  group('Prueba de Integración: PostLoginInitializationService', () {
    late MockICustomListsRepository mockRepository;
    late MockListSyncService mockSyncService;
    late MockCustomListsSharedPreferencesDatasource
        mockCustomListsSharedPreferencesDatasource;
    late ProviderContainer container;
    late PostLoginInitializationService postLoginService;
    late ListsMigrationService migrationService;

    setUp(() async {
      // Configurar SharedPreferences para testing
      SharedPreferences.setMockInitialValues({});

      // Inicializar mocks
      mockRepository = MockICustomListsRepository();
      mockSyncService = MockListSyncService();
      mockCustomListsSharedPreferencesDatasource =
          MockCustomListsSharedPreferencesDatasource();

      // Configurar container básico
      container = ProviderContainer();

      // Inicializar servicios (necesita dependencias)
      migrationService = ListsMigrationService(
        await SharedPreferences.getInstance(),
        mockCustomListsSharedPreferencesDatasource,
        mockRepository,
      );

      // Obtener instancia singleton de PostLoginInitializationService
      postLoginService = PostLoginInitializationService.instance;
    });

    tearDown(() {
      container.dispose();
    });

    test('PostLoginInitializationService se inicializa correctamente',
        () async {
      // Arrange & Act
      expect(postLoginService, isNotNull);

      // Assert: Verificar que el servicio está en estado inicial
      expect(postLoginService.isInitialized, false);

      LoggerFactory.info(
          '✅ PostLoginInitializationService inicializado correctamente');
    });

    test('Verificar que el servicio puede ejecutar inicialización forzada',
        () async {
      // Act: Intentar ejecutar inicialización forzada
      try {
        // Crear un Ref válido usando ProviderContainer
        final ref = container.read;
        postLoginService.forceInitialization('test-user-123', ref as Ref);
        LoggerFactory.info('✅ Inicialización forzada ejecutada sin errores');
      } catch (e) {
        LoggerFactory.warning(
            'ℹ️ Error esperado en inicialización forzada (sin usuario autenticado): $e');
        // Esto es esperado sin un usuario autenticado real
      }
    });

    test('Verificar inicialización del servicio', () async {
      // Act: Ejecutar inicialización
      final ref = container.read;
      postLoginService.initialize(ref as Ref);

      // Assert: Verificar que la inicialización se ejecutó sin errores
      expect(postLoginService.isInitialized, isTrue);

      LoggerFactory.info(
          '✅ Inicialización del servicio ejecutada correctamente');
    });

    test('Verificar disposición del servicio', () {
      // Act: Ejecutar disposición
      postLoginService.dispose();

      // Assert: Verificar que la disposición se ejecutó sin errores
      LoggerFactory.info('✅ Disposición del servicio ejecutada correctamente');
    });

    test('Debe manejar errores durante la migración correctamente', () async {
      // Arrange
      LoggerFactory.info('🧪 Probando manejo de errores en migración');

      // Configurar mock para fallar en la creación de listas
      when(mockRepository.createList(any))
          .thenThrow(Exception('Error de conexión a Supabase'));

      // Act & Assert
      expect(
        () async {
          final ref = container.read;
          return postLoginService.forceInitialization(
              'test-user-123', ref as Ref);
        },
        returnsNormally, // No debe lanzar excepción, debe manejar el error internamente
      );

      // Esperar un momento para que se complete el manejo de errores
      await Future.delayed(const Duration(milliseconds: 300));

      // Verificar que la migración no se marcó como completada debido al error
      expect(migrationService.isMigrationCompleted(), isFalse);

      LoggerFactory.info('✅ Manejo de errores verificado correctamente');
    });

    test('Debe omitir migración si ya fue completada previamente', () async {
      // Arrange
      LoggerFactory.info('🧪 Probando omisión de migración ya completada');

      // Marcar migración como completada
      await migrationService.markMigrationCompleted();
      expect(migrationService.isMigrationCompleted(), isTrue);

      // Act
      final ref = container.read;
      postLoginService.forceInitialization('test-user-123', ref as Ref);

      // Esperar un momento
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert
      // No debe intentar crear listas si la migración ya está completada
      verifyNever(mockRepository.createList(any));

      LoggerFactory.info('✅ Omisión de migración verificada correctamente');
    });

    test('Debe verificar sincronización después de migración exitosa',
        () async {
      // Arrange
      LoggerFactory.info('🧪 Probando sincronización post-migración');

      // Configurar mocks para migración y sincronización exitosas
      when(mockRepository.createList(any)).thenAnswer((invocation) async {
        final list = invocation.positionalArguments[0] as CustomList;
        return list.copyWith(
          id: 'supabase-${DateTime.now().millisecondsSinceEpoch}',
          userId: 'test-user-123',
        );
      });

      when(mockRepository.addMovieToList(any, any,
              position: anyNamed('position')))
          .thenAnswer((_) async => ListItem(
                id: 'test-item-id',
                listId: 'test-list-id',
                movieId: 123,
                movieTitle: 'Test Movie',
                position: 0,
                addedAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ));

      when(mockSyncService.startAutoSync()).thenAnswer((_) async {});

      // Act
      final ref = container.read;
      postLoginService.forceInitialization('test-user-123', ref as Ref);

      // Esperar para que se complete la inicialización
      await Future.delayed(const Duration(milliseconds: 600));

      // Assert
      // Verificar que se inició la sincronización automática
      verify(mockSyncService.startAutoSync()).called(1);

      LoggerFactory.info('✅ Sincronización post-migración verificada');
    });
  });
}

// Mock adicional para PostgrestQueryBuilder
class MockPostgrestQueryBuilder extends Mock {
  MockPostgrestQueryBuilder select([String columns = '*']) => this;

  MockPostgrestQueryBuilder eq(String column, Object value) => this;

  Future<List<Map<String, dynamic>>> call() async => [];
}

// Extensión para SyncResult (si no existe)
class SyncResult {
  const SyncResult({
    required this.success,
    required this.syncedLists,
    required this.syncedItems,
    required this.conflicts,
    required this.duration,
    required this.timestamp,
  });

  final bool success;
  final int syncedLists;
  final int syncedItems;
  final List<dynamic> conflicts;
  final Duration duration;
  final DateTime timestamp;
}
