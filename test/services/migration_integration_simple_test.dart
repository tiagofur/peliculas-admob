import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:peliculas/domain/entities/custom_list.dart';
import 'package:peliculas/domain/repositories/i_custom_lists_repository.dart';
import 'package:peliculas/services/lists_migration_service.dart';
import 'package:peliculas/infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';

// Simple mocks
class MockICustomListsRepository extends Mock
    implements ICustomListsRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockCustomListsSharedPreferencesDataSource extends Mock
    implements CustomListsSharedPreferencesDatasource {}

void main() {
  group('Migration Integration Simple Tests', () {
    late ListsMigrationService migrationService;
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

      // Initialize services
      migrationService = ListsMigrationService(
        mockRepository,
        mockPrefs,
        mockLocalDataSource,
        mockSupabaseClient,
      );
    });

    test('Debe inicializar correctamente el servicio de migración', () async {
      // Act
      final isCompleted = migrationService.isMigrationCompleted();

      // Assert
      expect(isCompleted, isFalse);
    });

    test('Debe marcar migración como completada', () async {
      // Act
      await migrationService.markMigrationCompleted();
      final isCompleted = migrationService.isMigrationCompleted();

      // Assert
      expect(isCompleted, isTrue);
    });
  });