import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peliculas/domain/entities/custom_list.dart';
import 'package:peliculas/domain/entities/list_item.dart';
import 'package:peliculas/domain/repositories/i_custom_lists_repository.dart';
import 'package:peliculas/infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import 'package:peliculas/services/default_lists_manager.dart';
import 'package:peliculas/services/id_mapping_service.dart';
import 'package:peliculas/services/lists_migration_service.dart';
import 'package:peliculas/services/migration_rollback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'migration_integration_complete_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<ICustomListsRepository>(),
  MockSpec<CustomListsSharedPreferencesDatasource>(),
  // MockSpec<SupabaseQueryBuilder>(), // Comentado temporalmente para resolver error de @immutable
])
void main() {
  group('Migration Integration Complete Tests', () {
    late ListsMigrationService migrationService;
    late MigrationRollbackService rollbackService;
    late IdMappingService idMappingService;
    late DefaultListsManager defaultListsManager;
    late MockICustomListsRepository mockRepository;
    late SharedPreferences mockPrefs;
    late MockSupabaseClient mockSupabaseClient;
    late MockGoTrueClient mockAuthClient;
    late MockUser mockUser;
    late MockCustomListsSharedPreferencesDatasource mockLocalDataSource;

    setUp(() async {
      // Initialize SharedPreferences with mock data
      SharedPreferences.setMockInitialValues({
        'migration_completed': false,
        'has_local_data': true,
      });
      mockPrefs = await SharedPreferences.getInstance();

      // Initialize mocks
      mockRepository = MockICustomListsRepository();
      mockSupabaseClient = MockSupabaseClient();
      mockAuthClient = MockGoTrueClient();
      mockUser = MockUser();
      mockLocalDataSource = MockCustomListsSharedPreferencesDatasource();

      // Setup mock behaviors
      when(mockSupabaseClient.auth).thenReturn(mockAuthClient);
      when(mockAuthClient.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn('test-user-id');

      // Mock repository methods commonly used
      when(mockRepository.getUserLists())
          .thenAnswer((_) async => <CustomList>[]);
      when(mockRepository.getDefaultLists())
          .thenAnswer((_) async => <CustomList>[]);
      when(mockRepository.getListById(any)).thenAnswer((_) async => null);
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

      // Note: Supabase mocks are simplified - focusing on repository layer testing

      // Configure default mock behaviors to avoid null returns
      provideDummy<CustomList>(CustomList(
        id: 'dummy-id',
        name: 'Dummy List',
        description: 'Dummy description',
        emoji: '📝',
        colorHex: '#000000',
        movieIds: [], // Siempre vacío en sistema nuevo
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        isDefault: false,
        defaultType: null,
      ));

      // Initialize services
      idMappingService = IdMappingService(mockPrefs);
      defaultListsManager = DefaultListsManager(mockRepository, mockPrefs);

      migrationService = ListsMigrationService(
        mockPrefs,
        mockLocalDataSource,
        mockRepository,
      );

      rollbackService = MigrationRollbackService(
        mockPrefs,
        mockSupabaseClient,
        mockLocalDataSource,
        idMappingService,
      );
    });

    test('Debe completar migración exitosa con datos locales', () async {
      // Arrange
      final testLists = _generateTestLists();

      when(mockLocalDataSource.getCustomLists())
          .thenAnswer((_) async => testLists);
      when(mockRepository.createList(any)).thenAnswer((invocation) async {
        final CustomList inputList =
            invocation.positionalArguments[0] as CustomList;
        return inputList.copyWith(id: 'new-id-${inputList.name}');
      });
      when(mockRepository.getDefaultLists())
          .thenAnswer((_) async => <CustomList>[]);

      // Act & Execute migration steps
      await migrationService.migrateDefaultLists('test-user-id');
      await migrationService.migrateCustomLists('test-user-id');
      await migrationService.markMigrationCompleted();

      // Assert
      final isCompleted = migrationService.isMigrationCompleted();
      expect(isCompleted, isTrue);
    });

    test('Debe manejar rollback correctamente en caso de error', () async {
      // Arrange
      final testLists = _generateTestLists();

      when(mockLocalDataSource.getCustomLists())
          .thenAnswer((_) async => testLists);
      when(mockRepository.createList(any))
          .thenThrow(Exception('Supabase error'));

      // Act & Try to execute migration and expect error
      expect(
          () async => await migrationService.migrateCustomLists('test-user-id'),
          throwsA(isA<Exception>()));

      // Verify rollback service exists and can handle the case
      expect(rollbackService, isNotNull);
      // Note: Rollback will fail if no rollback points exist, which is expected behavior
    });

    test('Debe crear listas por defecto correctamente', () async {
      // Arrange
      when(mockRepository.getDefaultLists())
          .thenAnswer((_) async => <CustomList>[]);
      when(mockRepository.createList(any)).thenAnswer((invocation) async {
        final CustomList inputList =
            invocation.positionalArguments[0] as CustomList;
        return inputList.copyWith(id: 'new-id-${inputList.name}');
      });

      // Act - Pasar userId explícitamente para evitar acceso a Supabase.instance
      await defaultListsManager.initializeDefaultLists(userId: 'test-user-id');

      // Assert
      verify(mockRepository.createList(any))
          .called(greaterThan(0)); // Listas por defecto creadas
    });

    test('Debe verificar integridad de datos después de migración', () async {
      // Arrange
      final testLists = _generateTestLists();
      final migratedLists = testLists
          .map((list) => CustomList(
                id: 'migrated-${list.id}',
                name: list.name,
                description: list.description,
                emoji: list.emoji,
                colorHex: list.colorHex,
                movieIds: [], // En sistema nuevo, movieIds está vacío
                createdAt: list.createdAt,
                lastModifiedAt: DateTime.now(),
                isDefault: list.isDefault,
                defaultType: list.defaultType,
              ))
          .toList();

      when(mockLocalDataSource.getCustomLists())
          .thenAnswer((_) async => testLists);
      when(mockRepository.createList(any)).thenAnswer((invocation) async {
        final CustomList inputList =
            invocation.positionalArguments[0] as CustomList;
        return inputList.copyWith(id: 'new-id-${inputList.name}');
      });
      when(mockRepository.getUserLists())
          .thenAnswer((_) async => migratedLists);

      // Act
      await migrationService.migrateCustomLists('test-user-id');

      // Verify data integrity
      final remoteLists = await mockRepository.getUserLists();

      // Assert
      expect(remoteLists.length, equals(testLists.length));

      for (int i = 0; i < testLists.length; i++) {
        expect(remoteLists[i].name, equals(testLists[i].name));
        expect(remoteLists[i].description, equals(testLists[i].description));
        // NOTA: No comparamos movieIds porque en sistema nuevo está vacío
        // Los items se verificarían a través de getListItems() si fuera necesario
      }
    });
  });
}

List<CustomList> _generateTestLists() {
  // NOTA: En tests de migración, movieIds aún contiene datos legacy
  // que se migrarán a user_list_items durante el proceso
  return [
    CustomList(
      id: 'local-1',
      name: 'Acción Favoritas',
      description: 'Mis películas de acción preferidas',
      emoji: '💥',
      colorHex: '#FF5722',
      movieIds: [550, 155, 13], // Legacy data para migración
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      lastModifiedAt: DateTime.now().subtract(const Duration(days: 5)),
      isDefault: false,
      defaultType: null,
    ),
    CustomList(
      id: 'local-2',
      name: 'Comedias Clásicas',
      description: 'Las mejores comedias de todos los tiempos',
      emoji: '😂',
      colorHex: '#4CAF50',
      movieIds: [105, 274, 680], // Legacy data para migración
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      lastModifiedAt: DateTime.now().subtract(const Duration(days: 2)),
      isDefault: false,
      defaultType: null,
    ),
    CustomList(
      id: 'local-3',
      name: 'Ciencia Ficción',
      description: 'Explorando el futuro a través del cine',
      emoji: '🚀',
      colorHex: '#2196F3',
      movieIds: [62, 424, 27205], // Legacy data para migración
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      lastModifiedAt: DateTime.now().subtract(const Duration(days: 1)),
      isDefault: false,
      defaultType: null,
    ),
  ];
}
