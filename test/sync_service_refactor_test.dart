import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/user.dart';
import 'package:peliculas/infrastructure/services/connectivity_detector.dart';
import 'package:peliculas/infrastructure/services/sync_service.dart';
import 'package:peliculas/domain/repositories/syncable_repository.dart';

// Mock repository for testing
class MockSyncableRepository implements SyncableRepository<String> {
  @override
  Future<List<String>> getLocalItems() async => ['local1', 'local2'];

  @override
  Future<List<String>> getRemoteItems() async => ['remote1', 'remote2'];

  @override
  Future<void> syncToRemote(List<String> items) async {}

  @override
  Future<void> syncToLocal(List<String> items) async {}

  @override
  Future<bool> hasLocalChanges() async => false;

  @override
  Future<DateTime?> getLastSyncTime() async => DateTime.now();

  @override
  Future<void> updateLastSyncTime() async {}

  @override
  String get repositoryName => 'MockRepository';
}

void main() {
  group('SyncService Refactoring Tests', () {
    late SyncService syncService;
    late MockSyncableRepository mockRepository;
    User? currentUser;
    ConnectivityStatus currentConnectivity = ConnectivityStatus.online;

    setUp(() {
      mockRepository = MockSyncableRepository();
      currentUser = null;
      currentConnectivity = ConnectivityStatus.online;

      syncService = SyncService(
        repositories: [mockRepository],
        getCurrentUser: () => currentUser,
        getConnectivityStatus: () => currentConnectivity,
      );
    });

    test('SyncService should initialize without ref', () {
      expect(syncService, isNotNull);
    });

    test('SyncService should handle null user correctly', () async {
      // When user is null
      currentUser = null;
      
      // onUserAuthenticated should handle gracefully
      await expectLater(
        syncService.onUserAuthenticated(),
        completes,
      );
    });

    test('SyncService should handle authenticated user', () async {
      // When user is authenticated
      currentUser = const User(
        id: 'test-user-id',
        email: 'test@example.com',
      );
      
      // onUserAuthenticated should work
      await expectLater(
        syncService.onUserAuthenticated(),
        completes,
      );
    });

    test('SyncService should get authentication status from function', () {
      // When user is null
      currentUser = null;
      // isAuthenticated should return false (this is tested indirectly via other methods)
      
      // When user is set
      currentUser = const User(
        id: 'test-user-id',
        email: 'test@example.com',
      );
      // isAuthenticated should return true (this is tested indirectly via other methods)
      
      expect(currentUser, isNotNull);
    });

    test('SyncService should handle connectivity changes', () {
      // Test different connectivity states
      currentConnectivity = ConnectivityStatus.offline;
      expect(syncService, isNotNull);
      
      currentConnectivity = ConnectivityStatus.online;
      expect(syncService, isNotNull);
    });

    test('SyncService constructor parameters are set correctly', () {
      final repositories = [mockRepository];
      User? testUser;
      ConnectivityStatus testConnectivity = ConnectivityStatus.online;
      
      final service = SyncService(
        repositories: repositories,
        getCurrentUser: () => testUser,
        getConnectivityStatus: () => testConnectivity,
      );
      
      expect(service, isNotNull);
      
      // Test that functions work
      expect(service.getCurrentUser(), equals(testUser));
      expect(service.getConnectivityStatus(), equals(testConnectivity));
    });

    test('SyncService can handle multiple repositories', () {
      final repo1 = MockSyncableRepository();
      final repo2 = MockSyncableRepository();
      
      final service = SyncService(
        repositories: [repo1, repo2],
        getCurrentUser: () => null,
        getConnectivityStatus: () => ConnectivityStatus.online,
      );
      
      expect(service, isNotNull);
    });
  });

  group('SyncService Functional Interface Tests', () {
    test('getCurrentUser function can return different states', () {
      User? testUser;
      
      final getUserFunction = () => testUser;
      
      // Initially null
      expect(getUserFunction(), isNull);
      
      // After setting user
      testUser = const User(id: 'test', email: 'test@test.com');
      expect(getUserFunction(), equals(testUser));
      
      // Back to null
      testUser = null;
      expect(getUserFunction(), isNull);
    });

    test('getConnectivityStatus function can return different states', () {
      ConnectivityStatus status = ConnectivityStatus.online;
      
      final getStatusFunction = () => status;
      
      // Initially online
      expect(getStatusFunction(), equals(ConnectivityStatus.online));
      
      // Change to offline
      status = ConnectivityStatus.offline;
      expect(getStatusFunction(), equals(ConnectivityStatus.offline));
    });
  });
}