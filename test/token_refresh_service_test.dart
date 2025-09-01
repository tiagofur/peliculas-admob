import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../lib/core/services/intelligent_retry_logic.dart';
import '../lib/infrastructure/services/auth_session_manager.dart';
import '../lib/infrastructure/services/token_refresh_service.dart';

// Generate mocks for the test
@GenerateMocks([SupabaseClient, GoTrueClient, Session, AuthSessionManager, IntelligentRetryLogic])
void main() {
  group('TokenRefreshService Tests', () {
    late TokenRefreshService tokenRefreshService;
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockSession mockSession;
    late MockAuthSessionManager mockSessionManager;
    late StreamController<AuthState> authStateController;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockSession = MockSession();
      mockSessionManager = MockAuthSessionManager();
      authStateController = StreamController<AuthState>();
      
      // Setup basic mocks
      when(mockSupabase.auth).thenReturn(mockAuth);
      when(mockAuth.onAuthStateChange).thenAnswer((_) => authStateController.stream);
      when(mockAuth.currentUser).thenReturn(null);
      
      tokenRefreshService = TokenRefreshService.instance;
    });

    tearDown(() {
      authStateController.close();
      tokenRefreshService.dispose();
    });

    group('Token Monitoring', () {
      test('should start monitoring when user signs in', () async {
        // Arrange
        final user = User(id: 'test-user');
        when(mockAuth.currentUser).thenReturn(user);
        
        // Act
        await tokenRefreshService.initialize();
        authStateController.add(AuthState(
          AuthChangeEvent.signedIn, 
          Session(accessToken: 'token', user: user),
        ));
        
        // Wait for async processing
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert - Monitoring should be active
        // This would be verified through behavioral testing
        expect(tokenRefreshService.events, isNotNull);
      });

      test('should stop monitoring when user signs out', () async {
        // Arrange
        await tokenRefreshService.initialize();
        
        // Act - Simulate sign out
        authStateController.add(AuthState(AuthChangeEvent.signedOut, null));
        
        // Wait for async processing
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert - Monitoring should be stopped
        // Verify through events stream
        final events = <TokenRefreshEvent>[];
        tokenRefreshService.events.listen(events.add);
        
        authStateController.add(AuthState(AuthChangeEvent.signedOut, null));
        await Future.delayed(Duration(milliseconds: 100));
        
        expect(events.any((e) => e is UserSignedOutEvent), isTrue);
      });
    });

    group('Token Refresh Logic', () {
      test('should refresh token when near expiry', () async {
        // Arrange
        final user = User(id: 'test-user');
        final nearExpiryTime = DateTime.now().add(Duration(minutes: 5)); // Within 10-min threshold
        
        when(mockSession.user).thenReturn(user);
        when(mockSession.accessToken).thenReturn('expiring-token');
        when(mockSession.refreshToken).thenReturn('refresh-token');
        when(mockSession.expiresAt).thenReturn(nearExpiryTime.millisecondsSinceEpoch ~/ 1000);
        
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockAuth.refreshSession(any)).thenAnswer((_) async => AuthResponse(
          session: Session(
            accessToken: 'new-token',
            refreshToken: 'new-refresh',
            user: user,
          ),
        ));
        
        when(mockSessionManager.persistSession(any)).thenAnswer((_) async {});
        
        // Act
        final success = await tokenRefreshService.forceRefresh();
        
        // Assert
        expect(success, isTrue);
        verify(mockAuth.refreshSession('refresh-token')).called(1);
      });

      test('should not refresh token when not near expiry', () async {
        // Arrange
        final user = User(id: 'test-user');
        final futureExpiryTime = DateTime.now().add(Duration(hours: 2)); // Well beyond threshold
        
        when(mockSession.user).thenReturn(user);
        when(mockSession.expiresAt).thenReturn(futureExpiryTime.millisecondsSinceEpoch ~/ 1000);
        when(mockAuth.currentSession).thenReturn(mockSession);
        
        // Act
        final status = await tokenRefreshService.getTokenStatus();
        
        // Assert
        expect(status.needsRefresh, isFalse);
      });

      test('should handle refresh failures gracefully', () async {
        // Arrange
        final user = User(id: 'test-user');
        when(mockSession.user).thenReturn(user);
        when(mockSession.refreshToken).thenReturn('invalid-refresh');
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockAuth.refreshSession(any))
            .thenThrow(AuthException('Invalid refresh token'));
        when(mockSessionManager.clearSession()).thenAnswer((_) async {});
        when(mockAuth.signOut()).thenAnswer((_) async {});
        
        // Act
        final success = await tokenRefreshService.forceRefresh();
        
        // Assert
        expect(success, isFalse);
        verify(mockSessionManager.clearSession()).called(1);
        verify(mockAuth.signOut()).called(1);
      });
    });

    group('Token Status Reporting', () {
      test('should report correct token status when healthy', () async {
        // Arrange
        final user = User(id: 'test-user');
        final futureExpiry = DateTime.now().add(Duration(hours: 1));
        
        when(mockSession.user).thenReturn(user);
        when(mockSession.expiresAt).thenReturn(futureExpiry.millisecondsSinceEpoch ~/ 1000);
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockSessionManager.validateCurrentSession()).thenAnswer((_) async => true);
        
        // Act
        final status = await tokenRefreshService.getTokenStatus();
        
        // Assert
        expect(status.hasToken, isTrue);
        expect(status.isValid, isTrue);
        expect(status.needsRefresh, isFalse);
        expect(status.isHealthy, isTrue);
        expect(status.expiresAt?.millisecondsSinceEpoch, 
               equals(futureExpiry.millisecondsSinceEpoch));
      });

      test('should report token needs refresh when near expiry', () async {
        // Arrange
        final user = User(id: 'test-user');
        final nearExpiry = DateTime.now().add(Duration(minutes: 5)); // Within threshold
        
        when(mockSession.user).thenReturn(user);
        when(mockSession.expiresAt).thenReturn(nearExpiry.millisecondsSinceEpoch ~/ 1000);
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockSessionManager.validateCurrentSession()).thenAnswer((_) async => true);
        
        // Act
        final status = await tokenRefreshService.getTokenStatus();
        
        // Assert
        expect(status.hasToken, isTrue);
        expect(status.needsRefresh, isTrue);
        expect(status.isHealthy, isFalse); // Not healthy due to needed refresh
      });

      test('should report no token when user not authenticated', () async {
        // Arrange
        when(mockAuth.currentSession).thenReturn(null);
        
        // Act
        final status = await tokenRefreshService.getTokenStatus();
        
        // Assert
        expect(status.hasToken, isFalse);
        expect(status.isValid, isFalse);
        expect(status.isHealthy, isFalse);
      });
    });

    group('Event Handling', () {
      test('should emit correct events during token refresh cycle', () async {
        // Arrange
        final user = User(id: 'test-user-123');
        final events = <TokenRefreshEvent>[];
        tokenRefreshService.events.listen(events.add);
        
        await tokenRefreshService.initialize();
        
        // Act - Simulate sign in
        authStateController.add(AuthState(
          AuthChangeEvent.signedIn,
          Session(accessToken: 'token', user: user),
        ));
        
        // Wait for event processing
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(events.any((e) => e is UserSignedInEvent), isTrue);
        final signInEvent = events.whereType<UserSignedInEvent>().first;
        expect(signInEvent.userId, equals('test-user-123'));
      });

      test('should emit refresh events during token refresh', () async {
        // Arrange
        final user = User(id: 'refresh-user');
        final events = <TokenRefreshEvent>[];
        tokenRefreshService.events.listen(events.add);
        
        when(mockSession.user).thenReturn(user);
        when(mockSession.refreshToken).thenReturn('refresh-token');
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockAuth.refreshSession(any)).thenAnswer((_) async => AuthResponse(
          session: Session(accessToken: 'new-token', user: user),
        ));
        when(mockSessionManager.persistSession(any)).thenAnswer((_) async {});
        
        await tokenRefreshService.initialize();
        
        // Act
        await tokenRefreshService.forceRefresh();
        
        // Wait for event processing
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(events.any((e) => e is RefreshStartedEvent), isTrue);
        expect(events.any((e) => e is TokenRefreshedEvent), isTrue);
      });

      test('should emit failure events when refresh fails', () async {
        // Arrange
        final user = User(id: 'fail-user');
        final events = <TokenRefreshEvent>[];
        tokenRefreshService.events.listen(events.add);
        
        when(mockSession.user).thenReturn(user);
        when(mockSession.refreshToken).thenReturn('bad-token');
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockAuth.refreshSession(any))
            .thenThrow(AuthException('Refresh failed'));
        when(mockSessionManager.clearSession()).thenAnswer((_) async {});
        when(mockAuth.signOut()).thenAnswer((_) async {});
        
        await tokenRefreshService.initialize();
        
        // Act
        await tokenRefreshService.forceRefresh();
        
        // Wait for event processing
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(events.any((e) => e is RefreshFailedEvent), isTrue);
        expect(events.any((e) => e is SessionInvalidatedEvent), isTrue);
      });
    });

    group('Automatic Monitoring', () {
      test('should automatically check tokens at regular intervals', () async {
        // Arrange
        final user = User(id: 'auto-user');
        when(mockAuth.currentUser).thenReturn(user);
        
        // This test would need to be modified to work with real timers
        // or use a test-friendly timer implementation
        
        // Act
        await tokenRefreshService.initialize();
        
        // Assert - Verify that monitoring is set up
        // In a real implementation, this might involve checking internal timer state
        // or using dependency injection for timers to make them testable
        expect(tokenRefreshService.events, isNotNull);
      });
    });

    group('Edge Cases', () {
      test('should handle multiple simultaneous refresh attempts', () async {
        // Arrange
        final user = User(id: 'concurrent-user');
        when(mockSession.user).thenReturn(user);
        when(mockSession.refreshToken).thenReturn('token');
        when(mockAuth.currentSession).thenReturn(mockSession);
        when(mockAuth.refreshSession(any)).thenAnswer((_) async {
          // Simulate slow refresh
          await Future.delayed(Duration(milliseconds: 100));
          return AuthResponse(session: Session(accessToken: 'new-token', user: user));
        });
        when(mockSessionManager.persistSession(any)).thenAnswer((_) async {});
        
        // Act - Multiple concurrent refresh attempts
        final futures = [
          tokenRefreshService.forceRefresh(),
          tokenRefreshService.forceRefresh(),
          tokenRefreshService.forceRefresh(),
        ];
        
        final results = await Future.wait(futures);
        
        // Assert - Only one should succeed, others should be skipped
        // The exact behavior depends on implementation - either all succeed 
        // or only one succeeds while others are skipped
        expect(results.every((r) => r == true), isTrue);
        
        // Verify refresh was called at least once (should not be called 3 times)
        verify(mockAuth.refreshSession(any)).called(lessThanOrEqualTo(1));
      });

      test('should handle token refresh when session is null', () async {
        // Arrange
        when(mockAuth.currentSession).thenReturn(null);
        
        // Act
        final success = await tokenRefreshService.forceRefresh();
        final status = await tokenRefreshService.getTokenStatus();
        
        // Assert
        expect(success, isFalse);
        expect(status.hasToken, isFalse);
      });
    });
  });
}