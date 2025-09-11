import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:peliculas/domain/entities/custom_list.dart';
import 'package:peliculas/services/lists_migration_service.dart';
import 'package:peliculas/infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import 'package:peliculas/domain/repositories/i_custom_lists_repository.dart';
import 'package:peliculas/services/default_lists_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'migration_integration_simple_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<CustomListsSharedPreferencesDatasource>(),
  MockSpec<ICustomListsRepository>(),
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
])
void main() {
  group('Migration Simple Tests', () {
    late ListsMigrationService migrationService;
    late MockCustomListsSharedPreferencesDatasource mockLocalDataSource;
    late MockICustomListsRepository mockRepository;
    late SharedPreferences mockPrefs;
    late MockSupabaseClient mockSupabaseClient;
    late MockGoTrueClient mockAuthClient;
    late MockUser mockUser;
    late DefaultListsManager defaultListsManager;

    setUp(() async {
      mockLocalDataSource = MockCustomListsSharedPreferencesDatasource();
      mockRepository = MockICustomListsRepository();
      
      // Initialize SharedPreferences with mock data
      SharedPreferences.setMockInitialValues({
        'lists_migration_completed': false,
      });
      mockPrefs = await SharedPreferences.getInstance();
      mockSupabaseClient = MockSupabaseClient();
      mockAuthClient = MockGoTrueClient();
      mockUser = MockUser();
      defaultListsManager = DefaultListsManager(mockRepository, mockPrefs);

      // Setup basic auth mocks
      when(mockSupabaseClient.auth).thenReturn(mockAuthClient);
      when(mockAuthClient.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn('test-user-id');

      migrationService = ListsMigrationService(
        mockRepository,
        mockPrefs,
        mockLocalDataSource,
        mockSupabaseClient,
      );
    });

    test('Debe verificar estado inicial de migración', () {
      // Act
      final isCompleted = migrationService.isMigrationCompleted();
      
      // Assert
      expect(isCompleted, isFalse);
    });

    test('Debe marcar migración como completada', () async {
      // Act
      await migrationService.markMigrationCompleted();
      
      // Assert
      final isCompleted = migrationService.isMigrationCompleted();
      expect(isCompleted, isTrue);
    });

    test('Debe inicializar DefaultListsManager correctamente', () {
      // Act & Assert - should not throw during initialization
      expect(defaultListsManager, isNotNull);
    });

    test('Debe procesar migración de listas por defecto sin errores', () async {
      // Arrange
      when(mockRepository.getDefaultLists())
          .thenAnswer((_) async => <CustomList>[]);
      
      // Act & Assert - should not throw
      await expectLater(
        () => migrationService.migrateDefaultLists('test-user-id'),
        returnsNormally,
      );
    });
  });
}