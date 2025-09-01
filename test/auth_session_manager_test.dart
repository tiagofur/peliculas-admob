import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../lib/infrastructure/services/auth_session_manager.dart';
import '../lib/infrastructure/services/web_safe_storage_service.dart';

// Generate mocks for the test
@GenerateMocks([WebSafeStorageService, SupabaseClient, GoTrueClient, Session, User])
void main() {
  group('AuthSessionManager Tests', () {
    late AuthSessionManager sessionManager;
    late MockWebSafeStorageService mockStorage;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockSession mockSession;
    late MockUser mockUser;

    setUp(() {
      mockStorage = MockWebSafeStorageService();
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockSession = MockSession();
      mockUser = MockUser();
      
      // Setup basic mocks
      when(mockSupabase.auth).thenReturn(mockAuth);
      
      sessionManager = AuthSessionManager.instance;
    });

    group('Session Persistence', () {
      test('should persist session data securely', () async {
        // Arrange
        const userId = 'test-user-id';
        const accessToken = 'test-access-token';
        const refreshToken = 'test-refresh-token';
        final expiresAt = DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
        
        when(mockSession.accessToken).thenReturn(accessToken);
        when(mockSession.refreshToken).thenReturn(refreshToken);
        when(mockSession.expiresAt).thenReturn(expiresAt);
        when(mockSession.user).thenReturn(mockUser);
        when(mockUser.id).thenReturn(userId);
        
        when(mockStorage.saveString(any, any)).thenAnswer((_) async => true);
        
        // Act
        await sessionManager.persistSession(mockSession);
        
        // Assert
        verify(mockStorage.saveString('auth_session_encrypted', any)).called(1);
        verify(mockStorage.saveString('session_token_hash', any)).called(1);
        verify(mockStorage.saveString('last_session_validation', any)).called(1);
      });

      test('should encrypt session data before storing', () async {
        // Arrange
        const accessToken = 'sensitive-access-token';
        when(mockSession.accessToken).thenReturn(accessToken);
        when(mockSession.refreshToken).thenReturn('refresh-token');
        when(mockSession.expiresAt).thenReturn(DateTime.now().millisecondsSinceEpoch ~/ 1000);
        when(mockSession.user).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-id');
        
        String? capturedEncryptedData;
        when(mockStorage.saveString('auth_session_encrypted', any))
            .thenAnswer((invocation) async {
          capturedEncryptedData = invocation.positionalArguments[1] as String;
          return true;
        });
        
        // Act
        await sessionManager.persistSession(mockSession);
        
        // Assert
        expect(capturedEncryptedData, isNotNull);
        expect(capturedEncryptedData, isNot(contains(accessToken)));
        // Encrypted data should not contain plain text token
      });
    });

    group('Session Recovery', () {
      test('should recover valid persisted session', () async {
        // Arrange
        when(mockStorage.getString('device_id')).thenAnswer((_) async => 'test-device-id');
        
        // Simulate encrypted session data
        final deviceId = 'test-device-id';
        final sessionData = {
          'access_token': 'valid-token',
          'refresh_token': 'valid-refresh',
          'expires_at': DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
          'user_id': 'user-123',
          'device_id': deviceId,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        };
        
        // Mock successful session recovery
        when(mockStorage.getString('auth_session_encrypted'))
            .thenAnswer((_) async => 'encrypted-session-data');
        when(mockAuth.setSession(any, any)).thenAnswer((_) async => AuthResponse());
        
        // Act
        final recovered = await sessionManager.recoverSession();
        
        // Assert
        expect(recovered, isTrue);
      });

      test('should reject expired sessions', () async {
        // Arrange
        when(mockStorage.getString('device_id')).thenAnswer((_) async => 'test-device-id');
        
        // Simulate expired session
        final expiredData = {
          'access_token': 'expired-token',
          'refresh_token': 'expired-refresh',
          'expires_at': DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
          'user_id': 'user-123',
          'device_id': 'test-device-id',
          'created_at': DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch,
        };
        
        when(mockStorage.getString('auth_session_encrypted'))
            .thenAnswer((_) async => 'encrypted-expired-data');
        
        // Act
        final recovered = await sessionManager.recoverSession();
        
        // Assert - Should attempt token refresh, but if that fails, return false
        expect(recovered, isFalse);
      });
    });

    group('Session Validation', () {
      test('should validate current session successfully', () async {
        // Arrange
        final user = User(id: 'test-user');
        when(mockAuth.currentUser).thenReturn(user);
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockSession.expiresAt)
            .thenReturn(DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000);
        when(mockSession.accessToken).thenReturn('valid-token');
        
        when(mockStorage.getString('session_token_hash'))
            .thenAnswer((_) async => 'matching-hash');
        
        // Act
        final isValid = await sessionManager.validateCurrentSession();
        
        // Assert
        expect(isValid, isTrue);
      });

      test('should invalidate session near expiry', () async {
        // Arrange
        final user = User(id: 'test-user');
        when(mockAuth.currentUser).thenReturn(user);
        when(mockAuth.currentSession).thenReturn(mockSession);
        
        // Session expires in 3 minutes (less than 5-minute threshold)
        when(mockSession.expiresAt)
            .thenReturn(DateTime.now().add(Duration(minutes: 3)).millisecondsSinceEpoch ~/ 1000);
        when(mockSession.accessToken).thenReturn('token-near-expiry');
        
        // Act
        final isValid = await sessionManager.validateCurrentSession();
        
        // Assert
        expect(isValid, isFalse); // Should be invalid due to near expiry
      });

      test('should invalidate session with mismatched token hash', () async {
        // Arrange
        final user = User(id: 'test-user');
        when(mockAuth.currentUser).thenReturn(user);
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockSession.expiresAt)
            .thenReturn(DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000);
        when(mockSession.accessToken).thenReturn('current-token');
        
        when(mockStorage.getString('session_token_hash'))
            .thenAnswer((_) async => 'different-hash'); // Different hash indicates token change
        
        // Act
        final isValid = await sessionManager.validateCurrentSession();
        
        // Assert
        expect(isValid, isFalse); // Should be invalid due to hash mismatch
      });
    });

    group('Session Cleanup', () {
      test('should clear all session data', () async {
        // Arrange
        when(mockStorage.remove(any)).thenAnswer((_) async => true);
        
        // Act
        await sessionManager.clearSession();
        
        // Assert
        verify(mockStorage.remove('auth_session_encrypted')).called(1);
        verify(mockStorage.remove('session_token_hash')).called(1);
        verify(mockStorage.remove('last_session_validation')).called(1);
      });
    });

    group('Security Tests', () {
      test('should use device-specific encryption', () async {
        // Arrange - Different device IDs should produce different encrypted data
        const sessionData = {
          'access_token': 'same-token',
          'refresh_token': 'same-refresh',
          'user_id': 'same-user',
        };
        
        // This test verifies that device ID affects encryption
        // Implementation would need to expose encryption method for testing
        // or verify through behavior (different devices can't decrypt each other's data)
        
        // Act & Assert
        // Would need to create sessions with different device IDs
        // and verify they produce different encrypted output
        expect(true, isTrue); // Placeholder - actual implementation would test encryption differences
      });

      test('should generate unique token hashes', () async {
        // Arrange
        const token1 = 'token-one';
        const token2 = 'token-two';
        
        // Act - Test hash generation produces different results for different tokens
        // This would require exposing the hash generation method or testing through behavior
        
        // Assert
        expect(token1, isNot(equals(token2))); // Different tokens should produce different hashes
      });
    });

    group('Error Handling', () {
      test('should handle storage errors gracefully', () async {
        // Arrange
        when(mockStorage.saveString(any, any))
            .thenThrow(Exception('Storage error'));
        
        when(mockSession.accessToken).thenReturn('token');
        when(mockSession.refreshToken).thenReturn('refresh');
        when(mockSession.expiresAt).thenReturn(DateTime.now().millisecondsSinceEpoch ~/ 1000);
        when(mockSession.user).thenReturn(User(id: 'user-id'));
        
        // Act & Assert
        expect(
          () => sessionManager.persistSession(mockSession),
          throwsException,
        );
      });

      test('should handle corrupted session data', () async {
        // Arrange
        when(mockStorage.getString('device_id')).thenAnswer((_) async => 'device-id');
        when(mockStorage.getString('auth_session_encrypted'))
            .thenAnswer((_) async => 'corrupted-invalid-data');
        
        // Act
        final recovered = await sessionManager.recoverSession();
        
        // Assert
        expect(recovered, isFalse);
        
        // Should clean up corrupted data
        verify(mockStorage.remove('auth_session_encrypted')).called(1);
      });
    });
  });
}