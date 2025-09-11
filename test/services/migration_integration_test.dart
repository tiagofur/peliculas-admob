import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../lib/domain/repositories/i_custom_lists_repository.dart';
import '../../lib/services/lists_migration_service.dart';
import '../../lib/services/migration_rollback_service.dart';
import '../../lib/services/id_mapping_service.dart';
import '../../lib/infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import '../../lib/domain/entities/custom_list.dart';

// Generar mocks
@GenerateMocks([
  ICustomListsRepository,
  SupabaseClient,
  GoTrueClient,
  User,
  CustomListsSharedPreferencesDatasource,
  PostgrestQueryBuilder,
])
import 'migration_integration_test.mocks.dart';

void main() {
  group('Migration Integration Tests', () {
    late MockICustomListsRepository mockRepository;
    late MockSupabaseClient mockSupabaseClient;
    late MockGoTrueClient mockAuthClient;
    late MockUser mockUser;
    late MockCustomListsSharedPreferencesDatasource mockLocalDataSource;
    late MockPostgrestQueryBuilder mockQueryBuilder;
    late SharedPreferences prefs;
    late ListsMigrationService migrationService;
    late MigrationRollbackService rollbackService;
    late IdMappingService idMappingService;

    setUp(() async {
      // Inicializar mocks
      mockRepository = MockICustomListsRepository();
      mockSupabaseClient = MockSupabaseClient();
      mockAuthClient = MockGoTrueClient();
      mockUser = MockUser();
      mockLocalDataSource = MockCustomListsSharedPreferencesDatasource();
      mockQueryBuilder = MockPostgrestQueryBuilder();
      
      // Configurar SharedPreferences para testing
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      
      // Inicializar servicios
      idMappingService = IdMappingService(prefs);
      migrationService = ListsMigrationService(
        mockRepository,
        prefs,
        mockLocalDataSource,
        mockSupabaseClient,
      );
      rollbackService = MigrationRollbackService(
        prefs,
        mockSupabaseClient,
        mockLocalDataSource,
        idMappingService,
      );
    });

    test('Debe analizar correctamente las necesidades de migración', () async {
      // Arrange
      const userId = 'test-user-123';
      when(mockRepository.getCustomLists()).thenAnswer((_) async => _generateTestLists());
      
      // Act
      final plan = await migrationService.analyzeMigrationNeeds(userId);
      
      // Assert
      expect(plan.hasWork, isTrue);
      expect(plan.customListsToMigrate.length, equals(2));
      expect(plan.totalEstimatedTime, isA<Duration>());
    });

    test('should create ID mappings correctly', () async {
      // Crear mapeos de prueba
      await idMappingService.createMapping('favorites', 'uuid-favorites');
      await idMappingService.createMapping('watchlist', 'uuid-watchlist');
      
      // Verificar mapeos
      final favoritesUuid = await idMappingService.getSupabaseId('favorites');
      final watchlistUuid = await idMappingService.getSupabaseId('watchlist');
      
      expect(favoritesUuid, equals('uuid-favorites'));
      expect(watchlistUuid, equals('uuid-watchlist'));
      
      // Verificar mapeo inverso
      final localId = await idMappingService.getLocalId('uuid-favorites');
      expect(localId, equals('favorites'));
    });

    test('Debe crear y usar puntos de rollback correctamente', () async {
      // Arrange
      const userId = 'test-user-123';
      const description = 'Punto de rollback de prueba';
      
      // Act
      final rollbackId = await rollbackService.createRollbackPoint(userId, description);
      
      // Assert
      expect(rollbackId, isNotEmpty);
      expect(rollbackId, startsWith('rollback_'));
    });

    test('Debe migrar listas por defecto exitosamente', () async {
      // Arrange
      const userId = 'test-user-123';
      when(mockSupabaseClient.from('user_lists')).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.select()).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.eq(any, any)).thenReturn(mockQueryBuilder);
      when(mockQueryBuilder.maybeSingle()).thenAnswer((_) async => null);
      when(mockQueryBuilder.insert(any)).thenAnswer((_) async => {});
      
      // Act
      final idMapping = await migrationService.migrateDefaultLists(userId);
      
      // Assert
      expect(idMapping, isA<Map<String, String>>());
      expect(idMapping.isNotEmpty, isTrue);
    });

    test('Debe manejar errores de migración con rollback', () async {
      // Arrange
      const userId = 'test-user-123';
      when(mockSupabaseClient.from('user_lists')).thenThrow(Exception('Network error'));
      
      // Act & Assert
      expect(
        () => migrationService.migrateDefaultLists(userId),
        throwsA(isA<MigrationException>()),
      );
      
      // Verificar que no se marcó como completada
      expect(migrationService.isMigrationCompleted(), isFalse);
    });
  });
}

// Función auxiliar para generar listas de prueba
List<CustomList> _generateTestLists() {
  return [
    CustomList(
      id: 'local-favorites',
      name: 'Favoritas',
      description: 'Mis películas favoritas',
      emoji: '⭐',
      colorHex: '#FFD700',
      movieIds: [1, 2, 3],
      isDefault: false,
      defaultType: null,
      createdAt: DateTime.now().subtract(Duration(days: 30)),
      lastModifiedAt: DateTime.now().subtract(Duration(days: 1)),
    ),
    CustomList(
      id: 'local-watchlist',
      name: 'Por Ver',
      description: 'Películas que quiero ver',
      emoji: '📺',
      colorHex: '#4CAF50',
      movieIds: [4, 5, 6],
      isDefault: false,
      defaultType: null,
      createdAt: DateTime.now().subtract(Duration(days: 25)),
      lastModifiedAt: DateTime.now().subtract(Duration(days: 2)),
    ),
  ];
}