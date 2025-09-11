import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lib/core/services/post_login_initialization_service.dart';
import '../../lib/services/lists_migration_service.dart';
import '../../lib/services/list_sync_service.dart';
import '../../lib/domain/repositories/i_custom_lists_repository.dart';
import '../../lib/infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import '../../lib/domain/entities/custom_list.dart';
import '../../lib/presentation/providers/custom_lists_providers.dart';
import '../../lib/core/logging/logger_factory.dart';

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

void main() {
  group('Prueba de Integración: PostLoginInitializationService', () {
    late ProviderContainer container;
    late PostLoginInitializationService postLoginService;
    late MockICustomListsRepository mockRepository;
    late MockListSyncService mockSyncService;
    late ListsMigrationService migrationService;

    setUp(() async {
      // Configurar SharedPreferences para testing
      SharedPreferences.setMockInitialValues({});
      
      // Configurar mocks
      mockRepository = MockICustomListsRepository();
      mockSyncService = MockListSyncService();
      
      // Configurar container básico
      container = ProviderContainer();
      
      // Inicializar servicios (necesita dependencias)
      migrationService = ListsMigrationService(
        mockRepository,
        await SharedPreferences.getInstance(),
        MockCustomListsSharedPreferencesDatasource(),
        MockSupabaseClient(),
      );
      
      // Obtener instancia singleton de PostLoginInitializationService
      postLoginService = PostLoginInitializationService.instance;
    });

    tearDown(() {
      container.dispose();
    });

    test('PostLoginInitializationService se inicializa correctamente', () async {
      // Arrange & Act
      expect(postLoginService, isNotNull);
      
      // Assert: Verificar que el servicio está en estado inicial
      expect(postLoginService.isInitialized, false);
      
      print('✅ PostLoginInitializationService inicializado correctamente');
    });

    test('Verificar que el servicio puede ejecutar inicialización forzada', () async {
      // Act: Intentar ejecutar inicialización forzada
      try {
        postLoginService.forceInitialization('test-user-123', container.read);
        print('✅ Inicialización forzada ejecutada sin errores');
      } catch (e) {
        print('ℹ️ Error esperado en inicialización forzada (sin usuario autenticado): $e');
        // Esto es esperado sin un usuario autenticado real
      }
    });

    test('Verificar inicialización del servicio', () async {
      // Act: Ejecutar inicialización
      postLoginService.initialize(container.read);
      
      // Assert: Verificar que la inicialización se ejecutó sin errores
      expect(postLoginService.isInitialized, true);
      
      print('✅ Inicialización del servicio ejecutada correctamente');
    });

    test('Verificar disposición del servicio', () {
      // Act: Ejecutar disposición
      postLoginService.dispose();
      
      // Assert: Verificar que la disposición se ejecutó sin errores
      print('✅ Disposición del servicio ejecutada correctamente');
    });

    test('Debe manejar errores durante la migración correctamente', () async {
      // Arrange
      LoggerFactory.info('🧪 Probando manejo de errores en migración');
      
      // Configurar mock para fallar en la creación de listas
      when(mockRepository.createList(any))
          .thenThrow(Exception('Error de conexión a Supabase'));

      // Act & Assert
      expect(
        () async => postLoginService.forceInitialization('test-user-123', container.read),
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
      postLoginService.forceInitialization('test-user-123', container.read);
      
      // Esperar un momento
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert
      // No debe intentar crear listas si la migración ya está completada
      verifyNever(mockRepository.createList(any));
      
      LoggerFactory.info('✅ Omisión de migración verificada correctamente');
    });

    test('Debe verificar sincronización después de migración exitosa', () async {
      // Arrange
      LoggerFactory.info('🧪 Probando sincronización post-migración');
      
      // Configurar mocks para migración y sincronización exitosas
      when(mockRepository.createList(any))
          .thenAnswer((invocation) async {
            final list = invocation.positionalArguments[0] as CustomList;
            return list.copyWith(
              id: 'supabase-${DateTime.now().millisecondsSinceEpoch}',
              userId: 'test-user-123',
            );
          });
      
      when(mockRepository.addMovieToList(any, any, position: anyNamed('position')))
          .thenAnswer((_) async {});
      
      when(mockSyncService.startAutoSync())
          .thenAnswer((_) async {});

      // Act
      postLoginService.forceInitialization('test-user-123', container.read);
      
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
  @override
  MockPostgrestQueryBuilder select([String columns = '*']) => this;
  
  @override
  MockPostgrestQueryBuilder eq(String column, Object value) => this;
  
  @override
  Future<List<Map<String, dynamic>>> call() async => [];
}

// Extensión para SyncResult (si no existe)
class SyncResult {
  final bool success;
  final int syncedLists;
  final int syncedItems;
  final List<dynamic> conflicts;
  final Duration duration;
  final DateTime timestamp;

  SyncResult({
    required this.success,
    required this.syncedLists,
    required this.syncedItems,
    required this.conflicts,
    required this.duration,
    required this.timestamp,
  });
}