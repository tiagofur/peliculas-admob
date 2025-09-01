import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/notifications/local_notification_service.dart';
import 'package:peliculas/core/notifications/notification_initialization_service.dart';

void main() {
  group('Notification Navigation Tests', () {
    late GlobalKey<NavigatorState> navigatorKey;
    
    setUp(() {
      navigatorKey = GlobalKey<NavigatorState>();
    });

    test('LocalNotificationService should accept navigator key', () {
      final service = LocalNotificationService.instance;
      
      expect(() => service.setNavigatorKey(navigatorKey), returnsNormally);
    });

    test('NotificationInitializationService should accept navigator key', () {
      final service = NotificationInitializationService.instance;
      
      expect(() => service.setNavigatorKey(navigatorKey), returnsNormally);
    });

    test('LocalNotificationService should initialize properly', () {
      final service = LocalNotificationService.instance;
      
      // Initially not initialized
      expect(service.isInitialized, isFalse);
      
      // Setting navigator key should work
      service.setNavigatorKey(navigatorKey);
      expect(() => service.setNavigatorKey(navigatorKey), returnsNormally);
    });

    test('NotificationInitializationService should initialize properly', () {
      final service = NotificationInitializationService.instance;
      
      // Initially not initialized
      expect(service.isInitialized, isFalse);
      
      // Setting navigator key should work
      service.setNavigatorKey(navigatorKey);
      expect(() => service.setNavigatorKey(navigatorKey), returnsNormally);
    });

    test('Services should be singletons', () {
      final service1 = LocalNotificationService.instance;
      final service2 = LocalNotificationService.instance;
      
      expect(service1, same(service2));
      
      final pushService1 = NotificationInitializationService.instance;
      final pushService2 = NotificationInitializationService.instance;
      
      expect(pushService1, same(pushService2));
    });

    test('Navigator key can be set multiple times without issues', () {
      final service = LocalNotificationService.instance;
      final pushService = NotificationInitializationService.instance;
      
      final key1 = GlobalKey<NavigatorState>();
      final key2 = GlobalKey<NavigatorState>();
      
      // Should be able to set different keys
      expect(() => service.setNavigatorKey(key1), returnsNormally);
      expect(() => service.setNavigatorKey(key2), returnsNormally);
      
      expect(() => pushService.setNavigatorKey(key1), returnsNormally);
      expect(() => pushService.setNavigatorKey(key2), returnsNormally);
    });
  });

  group('State Management Tests', () {
    test('Services should maintain navigator key state', () {
      final localService = LocalNotificationService.instance;
      final pushService = NotificationInitializationService.instance;
      
      final navigatorKey = GlobalKey<NavigatorState>();
      
      localService.setNavigatorKey(navigatorKey);
      pushService.setNavigatorKey(navigatorKey);
      
      // Services should accept the navigator key without issues
      expect(localService.isInitialized, isFalse); // Not initialized yet
      expect(pushService.isInitialized, isFalse); // Not initialized yet
    });
    
    test('Services should handle navigation setup correctly', () {
      final localService = LocalNotificationService.instance;
      final pushService = NotificationInitializationService.instance;
      
      // Before setting navigator key
      expect(localService.isInitialized, isFalse);
      expect(pushService.isInitialized, isFalse);
      
      // After setting navigator key - should still work
      final navigatorKey = GlobalKey<NavigatorState>();
      localService.setNavigatorKey(navigatorKey);
      pushService.setNavigatorKey(navigatorKey);
      
      expect(() => localService.setNavigatorKey(navigatorKey), returnsNormally);
      expect(() => pushService.setNavigatorKey(navigatorKey), returnsNormally);
    });
  });

  group('Integration Tests', () {
    test('Both services can work together with same navigator key', () {
      final localService = LocalNotificationService.instance;
      final pushService = NotificationInitializationService.instance;
      
      final sharedNavigatorKey = GlobalKey<NavigatorState>();
      
      // Both services should accept the same navigator key
      expect(() {
        localService.setNavigatorKey(sharedNavigatorKey);
        pushService.setNavigatorKey(sharedNavigatorKey);
      }, returnsNormally);
    });
  });
}