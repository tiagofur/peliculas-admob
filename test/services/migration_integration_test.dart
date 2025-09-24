import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peliculas/domain/entities/custom_list.dart';
import 'package:peliculas/domain/repositories/i_custom_lists_repository.dart';
import 'package:peliculas/infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import 'package:peliculas/services/id_mapping_service.dart';
import 'package:peliculas/services/lists_migration_service.dart';
import 'package:peliculas/services/migration_rollback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Generar mocks
@GenerateNiceMocks([
  MockSpec<ICustomListsRepository>(),
  MockSpec<SupabaseClient>(),
  MockSpec<CustomListsSharedPreferencesDatasource>(),
])
import 'migration_integration_test.mocks.dart';

void main() {
  group('Migration Integration Tests', () {
    late MockICustomListsRepository mockRepository;
    late MockSupabaseClient mockSupabaseClient;
    late MockCustomListsSharedPreferencesDatasource mockLocalDataSource;
    late SharedPreferences prefs;
    late ListsMigrationService migrationService;
    late MigrationRollbackService rollbackService;
    late IdMappingService idMappingService;

    setUp(() async {
      // Inicializar mocks
      mockRepository = MockICustomListsRepository();
      mockSupabaseClient = MockSupabaseClient();
      mockLocalDataSource = MockCustomListsSharedPreferencesDatasource();

      // Configurar SharedPreferences para testing
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      // Inicializar servicios
      idMappingService = IdMappingService(prefs);
      migrationService = ListsMigrationService(
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
      when(mockLocalDataSource.getCustomLists())
          .thenAnswer((_) async => _generateTestLists());

      // Act
      final plan = await migrationService.analyzeMigrationNeeds(userId);

      // Assert
      expect(plan.hasWork, isTrue);
      expect(plan.customListsToMigrate.length, equals(2));
      expect(plan.totalEstimatedTime, isA<Duration>());
    });

    test('should create ID mappings correctly', () async {
      // Crear mapeos de prueba
      await idMappingService.saveMapping('favorites', 'uuid-favorites');
      await idMappingService.saveMapping('watchlist', 'uuid-watchlist');

      // Verificar mapeos
      final favoritesUuid = idMappingService.getSupabaseId('favorites');
      final watchlistUuid = idMappingService.getSupabaseId('watchlist');

      expect(favoritesUuid, equals('uuid-favorites'));
      expect(watchlistUuid, equals('uuid-watchlist'));

      // Verificar mapeo inverso
      final localId = idMappingService.getLocalId('uuid-favorites');
      expect(localId, equals('favorites'));
    });

    test('Debe crear y usar puntos de rollback correctamente', () async {
      // Arrange
      const userId = 'test-user-123';
      const description = 'Punto de rollback de prueba';

      // Act
      final rollbackId =
          await rollbackService.createRollbackPoint(userId, description);

      // Assert
      expect(rollbackId, isNotEmpty);
      expect(rollbackId, startsWith('rollback_'));
    });

    test('Debe migrar listas por defecto exitosamente', () async {
      // Arrange
      const userId = 'test-user-123';

      // Configurar mocks del repositorio
      when(mockRepository.getDefaultLists())
          .thenAnswer((_) async => <CustomList>[]);
      when(mockRepository.createList(any)).thenAnswer((invocation) async {
        final CustomList inputList =
            invocation.positionalArguments[0] as CustomList;
        return inputList.copyWith(id: 'new-id-${inputList.name}');
      });

      // Act
      final idMapping = await migrationService.migrateDefaultLists(userId);

      // Assert
      expect(idMapping, isA<Map<String, String>>());
      expect(idMapping.isNotEmpty, isTrue);
    });

    test('Debe manejar errores de migración con rollback', () async {
      // Arrange
      const userId = 'test-user-123';
      when(mockRepository.createList(any))
          .thenThrow(Exception('Network error'));

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
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      lastModifiedAt: DateTime.now().subtract(const Duration(days: 1)),
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
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      lastModifiedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
}
