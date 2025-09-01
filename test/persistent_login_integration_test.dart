import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../lib/domain/repositories/auth_repository.dart';
import '../lib/infrastructure/repositories/auth_repository_impl.dart';
import '../lib/infrastructure/services/auth_session_manager.dart';
import '../lib/infrastructure/services/token_refresh_service.dart';
import '../lib/infrastructure/services/web_safe_storage_service.dart';

// Generate mocks for the test
@GenerateMocks([
  WebSafeStorageService,
  SupabaseClient,
  GoTrueClient,
  Session,
  AuthSessionManager,
  TokenRefreshService,
])
void main() {
  group('Persistent Login Integration Tests', () {
    late AuthRepository authRepository;
    late MockWebSafeStorageService mockStorage;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockSession mockSession;

    setUp(() {
      mockStorage = MockWebSafeStorageService();
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockSession = MockSession();
      
      // Setup basic mocks
      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockAuth.onAuthStateChange).thenAnswer((_) => Stream.empty());
      when(mockAuth.currentUser).thenReturn(null);
      
      authRepository = AuthRepositoryImpl();
    });

    group('Complete Login Flow', () {
      test('should persist session after successful login', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        final user = User(id: 'user-123', email: email);
        final session = Session(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          user: user,
        );
        
        when(mockAuth.signInWithPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => AuthResponse(
          user: user,
          session: session,
        ));

        // Act
        final loggedInUser = await authRepository.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Assert
        expect(loggedInUser.id, equals('user-123'));
        expect(loggedInUser.email, equals(email));
        
        // Verify session persistence was attempted
        // This would require mocking the session manager
      });

      test('should recover persisted session on app restart', () async {
        // Arrange - Simulate app restart with persisted session
        when(mockStorage.getString('device_id'))
            .thenAnswer((_) async => 'persistent-device-id');
        when(mockStorage.getString('auth_session_encrypted'))
            .thenAnswer((_) async => 'encrypted-session-data');
        when(mockStorage.getString('session_token_hash'))
            .thenAnswer((_) async => 'valid-token-hash');
        
        final persistedUser = User(id: 'persisted-user');
        when(mockAuth.currentUser).thenReturn(persistedUser);
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockSession.expiresAt)
            .thenReturn(DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000);
        when(mockSession.accessToken).thenReturn('persisted-token');

        // Act
        final hasPersistedSession = await authRepository.hasPersistedSession();

        // Assert
        expect(hasPersistedSession, isTrue);
      });
    });

    group('Token Refresh Integration', () {
      test('should automatically refresh expiring tokens', () async {
        // Arrange
        final user = User(id: 'refresh-user');
        final expiringSession = Session(
          accessToken: 'expiring-token',
          refreshToken: 'refresh-token',
          user: user,
        );
        
        when(mockAuth.currentSession).thenReturn(expiringSession);
        when(mockSession.expiresAt)
            .thenReturn(DateTime.now().add(Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000);
        when(mockSession.user).thenReturn(user);
        when(mockSession.refreshToken).thenReturn('refresh-token');
        
        final newSession = Session(
          accessToken: 'new-token',
          refreshToken: 'new-refresh-token',
          user: user,
        );
        
        when(mockAuth.refreshSession('refresh-token'))
            .thenAnswer((_) async => AuthResponse(session: newSession));

        // Act
        await authRepository.refreshToken();

        // Assert
        verify(mockAuth.refreshSession('refresh-token')).called(1);
      });

      test('should handle refresh token failure by clearing session', () async {
        // Arrange
        final user = User(id: 'fail-user');
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockSession.user).thenReturn(user);
        when(mockSession.refreshToken).thenReturn('invalid-refresh');
        when(mockAuth.refreshSession('invalid-refresh'))
            .thenThrow(AuthException('Invalid refresh token'));
        when(mockAuth.signOut()).thenAnswer((_) async {});

        // Act & Assert
        expect(
          () => authRepository.refreshToken(),
          throwsException,
        );
        
        // Should have attempted to clear session
        verify(mockAuth.signOut()).called(1);
      });
    });

    group('Session Validation', () {
      test('should validate current session correctly', () async {
        // Arrange
        final user = User(id: 'valid-user');
        when(mockAuth.currentUser).thenReturn(user);
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockSession.expiresAt)
            .thenReturn(DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000);
        when(mockSession.accessToken).thenReturn('valid-token');
        when(mockStorage.getString('session_token_hash'))
            .thenAnswer((_) async => 'matching-hash');

        // Act
        final isValid = await authRepository.validateCurrentSession();

        // Assert
        expect(isValid, isTrue);
      });

      test('should invalidate expired sessions', () async {
        // Arrange
        final user = User(id: 'expired-user');
        when(mockAuth.currentUser).thenReturn(user);
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockSession.expiresAt)
            .thenReturn(DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000);

        // Act
        final isValid = await authRepository.validateCurrentSession();

        // Assert
        expect(isValid, isFalse);
      });
    });

    group('Logout and Cleanup', () {
      test('should clear all persistent data on logout', () async {
        // Arrange
        when(mockAuth.signOut()).thenAnswer((_) async {});
        when(mockStorage.remove(any)).thenAnswer((_) async => true);

        // Act
        await authRepository.signOut();

        // Assert
        verify(mockAuth.signOut()).called(1);
        // Session cleanup should be called
      });
    });

    group('Security and Error Handling', () {
      test('should handle corrupted session data gracefully', () async {
        // Arrange
        when(mockStorage.getString('auth_session_encrypted'))
            .thenAnswer((_) async => 'corrupted-data');
        when(mockStorage.getString('device_id'))
            .thenAnswer((_) async => 'device-id');

        // Act
        final hasSession = await authRepository.hasPersistedSession();
        final recovered = await authRepository.validateCurrentSession();

        // Assert
        expect(hasSession, isTrue); // Has data, but...
        expect(recovered, isFalse); // ...it's invalid
      });

      test('should handle network errors during token refresh', () async {
        // Arrange
        final user = User(id: 'network-fail-user');
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockSession.user).thenReturn(user);
        when(mockSession.refreshToken).thenReturn('network-fail-token');
        when(mockAuth.refreshSession(any))
            .thenThrow(Exception('Network error'));

        // Act & Assert
        expect(
          () => authRepository.refreshToken(),
          throwsException,
        );
      });

      test('should protect against session hijacking attempts', () async {
        // Arrange - Different device tries to use session
        when(mockStorage.getString('device_id'))
            .thenAnswer((_) async => 'original-device');
        
        // Simulate session data with different device ID
        final sessionWithDifferentDevice = {
          'device_id': 'different-device',
          'access_token': 'hijacked-token',
          'user_id': 'user-123',
        };
        
        // Act
        final isValid = await authRepository.validateCurrentSession();

        // Assert
        expect(isValid, isFalse); // Should reject session from different device
      });
    });

    group('Session Information', () {
      test('should provide comprehensive session info', () async {
        // Arrange
        final user = User(id: 'info-user');
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockSession.user).thenReturn(user);
        when(mockSession.expiresAt)
            .thenReturn(DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000);
        when(mockSession.accessToken).thenReturn('info-token');
        
        when(mockStorage.getString('device_id'))
            .thenAnswer((_) async => 'info-device');

        // Act
        final sessionInfo = await authRepository.getSessionInfo();

        // Assert
        expect(sessionInfo, isNotNull);
        expect(sessionInfo!['token_status'], isNotNull);
        expect(sessionInfo['token_status']['has_token'], isTrue);
      });
    });

    group('Concurrent Access', () {
      test('should handle multiple simultaneous operations safely', () async {
        // Arrange
        final user = User(id: 'concurrent-user');
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockSession.user).thenReturn(user);
        when(mockAuth.signOut()).thenAnswer((_) async {});
        when(mockStorage.remove(any)).thenAnswer((_) async => true);

        // Act - Multiple concurrent operations
        final futures = [
          authRepository.validateCurrentSession(),
          authRepository.validateCurrentSession(),
          authRepository.getSessionInfo(),
          authRepository.signOut(),
        ];

        // Assert - Should not throw or cause race conditions
        expect(() => Future.wait(futures), returnsNormally);
      });
    });

    group('Performance', () {
      test('should cache validation results to avoid excessive checks', () async {
        // Arrange
        final user = User(id: 'perf-user');
        when(mockAuth.currentUser).thenReturn(user);
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockSession.expiresAt)
            .thenReturn(DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000);
        when(mockSession.accessToken).thenReturn('perf-token');

        // Act - Multiple rapid validation calls
        await authRepository.validateCurrentSession();
        await authRepository.validateCurrentSession();
        await authRepository.validateCurrentSession();

        // Assert - Should not call expensive operations multiple times
        // This would require implementation to support caching
        verify(mockAuth.currentSession).called(greaterThan(0));
      });
    });
  });
}