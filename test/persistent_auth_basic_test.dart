import 'package:flutter_test/flutter_test.dart';

import '../lib/infrastructure/services/auth_session_manager.dart';
import '../lib/infrastructure/services/token_refresh_service.dart';

/// Simple integration tests for persistent auth without complex mocking
void main() {
  group('Persistent Auth Basic Tests', () {
    test('AuthSessionManager instance should be singleton', () {
      final instance1 = AuthSessionManager.instance;
      final instance2 = AuthSessionManager.instance;
      
      expect(instance1, equals(instance2));
    });

    test('TokenRefreshService instance should be singleton', () {
      final instance1 = TokenRefreshService.instance;
      final instance2 = TokenRefreshService.instance;
      
      expect(instance1, equals(instance2));
    });

    test('AuthSessionManager should handle null session info gracefully', () async {
      final sessionManager = AuthSessionManager.instance;
      
      // Should not throw when getting session info without initialization
      final info = await sessionManager.getSessionInfo();
      expect(info, isNull);
    });

    test('TokenRefreshService should report no token when not authenticated', () async {
      final tokenService = TokenRefreshService.instance;
      
      // Should report no token status when not authenticated
      final status = await tokenService.getTokenStatus();
      expect(status.hasToken, isFalse);
      expect(status.isValid, isFalse);
      expect(status.isHealthy, isFalse);
    });

    test('AuthSessionManager should handle non-existent persisted session', () async {
      final sessionManager = AuthSessionManager.instance;
      
      // Should return false when no session is persisted
      final hasSession = await sessionManager.hasPersistedSession();
      expect(hasSession, isFalse);
    });

    test('AuthSessionManager should validate session without current user', () async {
      final sessionManager = AuthSessionManager.instance;
      
      // Should return false when no current user
      final isValid = await sessionManager.validateCurrentSession();
      expect(isValid, isFalse);
    });

    test('TokenRefreshService should handle force refresh without session', () async {
      final tokenService = TokenRefreshService.instance;
      
      // Should return false when trying to refresh without session
      final success = await tokenService.forceRefresh();
      expect(success, isFalse);
    });

    test('TokenRefreshService should report token is not near expiry when no token', () async {
      final tokenService = TokenRefreshService.instance;
      
      // Should return false when no token exists
      final nearExpiry = await tokenService.isTokenNearExpiry();
      expect(nearExpiry, isFalse);
    });

    test('TokenRefreshService events stream should be available', () {
      final tokenService = TokenRefreshService.instance;
      
      // Events stream should be available
      expect(tokenService.events, isNotNull);
      expect(tokenService.events, isA<Stream<TokenRefreshEvent>>());
    });

    test('Session manager should handle clearing non-existent session', () async {
      final sessionManager = AuthSessionManager.instance;
      
      // Should not throw when clearing non-existent session
      expect(() => sessionManager.clearSession(), returnsNormally);
    });

    test('Token status should have correct properties', () async {
      final tokenService = TokenRefreshService.instance;
      final status = await tokenService.getTokenStatus();
      
      // Status should have expected properties
      expect(status.hasToken, isA<bool>());
      expect(status.isValid, isA<bool>());
      expect(status.needsRefresh, isA<bool>());
      expect(status.isRefreshing, isA<bool>());
      expect(status.isHealthy, isA<bool>());
    });
  });

  group('Token Refresh Events', () {
    test('UserSignedInEvent should have correct properties', () {
      const event = UserSignedInEvent('test-user-123');
      expect(event.userId, equals('test-user-123'));
    });

    test('UserSignedOutEvent should be instantiable', () {
      const event = UserSignedOutEvent();
      expect(event, isA<UserSignedOutEvent>());
    });

    test('RefreshStartedEvent should have correct properties', () {
      const event = RefreshStartedEvent('refresh-user');
      expect(event.userId, equals('refresh-user'));
    });

    test('TokenRefreshedEvent should have correct properties', () {
      const event = TokenRefreshedEvent('refreshed-user');
      expect(event.userId, equals('refreshed-user'));
    });

    test('RefreshFailedEvent should have correct properties', () {
      const event = RefreshFailedEvent('Test error message');
      expect(event.error, equals('Test error message'));
    });

    test('SessionInvalidatedEvent should be instantiable', () {
      const event = SessionInvalidatedEvent();
      expect(event, isA<SessionInvalidatedEvent>());
    });
  });

  group('Token Status', () {
    test('TokenStatus.noToken should have correct properties', () {
      final status = TokenStatus.noToken();
      
      expect(status.hasToken, isFalse);
      expect(status.isValid, isFalse);
      expect(status.isHealthy, isFalse);
      expect(status.expiresAt, isNull);
      expect(status.timeUntilExpiry, isNull);
      expect(status.needsRefresh, isFalse);
      expect(status.isRefreshing, isFalse);
      expect(status.error, isNull);
    });

    test('TokenStatus.error should have correct properties', () {
      const errorMessage = 'Test error';
      final status = TokenStatus.error(errorMessage);
      
      expect(status.hasToken, isFalse);
      expect(status.isValid, isFalse);
      expect(status.isHealthy, isFalse);
      expect(status.error, equals(errorMessage));
    });

    test('TokenStatus should correctly report healthy status', () {
      // Healthy token status
      final healthyStatus = TokenStatus(
        hasToken: true,
        isValid: true,
        needsRefresh: false,
        isRefreshing: false,
        expiresAt: DateTime.now().add(Duration(hours: 1)),
      );
      
      expect(healthyStatus.isHealthy, isTrue);
      
      // Unhealthy token status
      final unhealthyStatus = TokenStatus(
        hasToken: true,
        isValid: true,
        needsRefresh: true, // Needs refresh = not healthy
        isRefreshing: false,
      );
      
      expect(unhealthyStatus.isHealthy, isFalse);
    });
  });
});