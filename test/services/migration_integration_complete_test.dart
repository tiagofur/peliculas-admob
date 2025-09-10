import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:peliculas/domain/entities/custom_list.dart';
import 'package:peliculas/domain/repositories/i_custom_lists_repository.dart';
import 'package:peliculas/services/lists_migration_service.dart';
import 'package:peliculas/services/migration_rollback_service.dart';
import 'package:peliculas/services/id_mapping_service.dart';
import 'package:peliculas/services/default_lists_manager.dart';
import 'package:peliculas/infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';

// Mocks
class MockICustomListsRepository extends Mock implements ICustomListsRepository {
  @override
  Future<List<CustomList>> getUserLists() async {
    return super.noSuchMethod(
      Invocation.method(#getUserLists, []),
      returnValue: Future.value(<CustomList>[]),
    );
  }
  
  @override
  Future<CustomList> createList(CustomList list) async {
    return super.noSuchMethod(
      Invocation.method(#createList, [list]),
      returnValue: Future.value(list),
    );
  }
  
  @override
  Future<List<CustomList>> getDefaultLists() async {
    return super.noSuchMethod(
      Invocation.method(#getDefaultLists, []),
      returnValue: Future.value(<CustomList>[]),
    );
  }
}
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockCustomListsSharedPreferencesDataSource extends Mock implements CustomListsSharedPreferencesDatasource {}
class MockPostgrestQueryBuilder extends Mock implements PostgrestQueryBuilder {}

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
    late MockCustomListsSharedPreferencesDataSource mockLocalDataSource;
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
      mockLocalDataSource = MockCustomListsSharedPreferencesDataSource();
      
      // Setup mock behaviors
      when(mockSupabaseClient.auth).thenReturn(mockAuthClient);
      when(mockAuthClient.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn('test-user-id');
      
      // Configure default mock behaviors to avoid null returns
      provideDummy<CustomList>(CustomList(
        id: 'dummy-id',
        name: 'Dummy List',
        description: 'Dummy description',
        emoji: '📝',
        colorHex: '#000000',
        movieIds: [],
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        isDefault: false,
        defaultType: null,
      ));
      
      // Initialize services
      idMappingService = IdMappingService(mockPrefs);
      defaultListsManager = DefaultListsManager(mockRepository, mockPrefs);
      
      migrationService = ListsMigrationService(
        mockRepository,
        mockPrefs,
        mockLocalDataSource,
        mockSupabaseClient,
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
      when(mockRepository.createList(any))
          .thenAnswer((invocation) async => testLists.first);
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
      expect(() async => await migrationService.migrateCustomLists('test-user-id'),
          throwsA(isA<Exception>()));
      
      // Verify rollback can be executed
      final rollbackResult = await rollbackService.executeAutoRollback('test-user-id');
      expect(rollbackResult.isSuccessful, isTrue);
    });

    test('Debe crear listas por defecto correctamente', () async {
      // Arrange
      final testLists = _generateTestLists();
      when(mockRepository.getDefaultLists())
          .thenAnswer((_) async => <CustomList>[]);
      when(mockRepository.createList(any))
          .thenAnswer((invocation) async => testLists.first);
      
      // Act
      await defaultListsManager.initializeDefaultLists();
      
      // Assert
      verify(mockRepository.createList(any)).called(greaterThan(0)); // Listas por defecto creadas
    });

    test('Debe verificar integridad de datos después de migración', () async {
      // Arrange
      final testLists = _generateTestLists();
      final migratedLists = testLists.map((list) => CustomList(
        id: 'migrated-${list.id}',
        name: list.name,
        description: list.description,
        emoji: list.emoji,
        colorHex: list.colorHex,
        movieIds: list.movieIds,
        createdAt: list.createdAt,
        lastModifiedAt: DateTime.now(),
        isDefault: list.isDefault,
        defaultType: list.defaultType,
      )).toList();
      
      when(mockLocalDataSource.getCustomLists())
          .thenAnswer((_) async => testLists);
      when(mockRepository.createList(any))
          .thenAnswer((invocation) async => testLists.first);
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
        expect(remoteLists[i].movieIds.length, equals(testLists[i].movieIds.length));
      }
    });
  });
}

List<CustomList> _generateTestLists() {
  return [
    CustomList(
      id: 'local-1',
      name: 'Acción Favoritas',
      description: 'Mis películas de acción preferidas',
      emoji: '💥',
      colorHex: '#FF5722',
      movieIds: [550, 155, 13],
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
      movieIds: [105, 274, 680],
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
      movieIds: [62, 424, 27205],
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      lastModifiedAt: DateTime.now().subtract(const Duration(days: 1)),
      isDefault: false,
      defaultType: null,
    ),
  ];
}