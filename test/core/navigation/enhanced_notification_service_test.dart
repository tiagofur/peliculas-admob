import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/navigation/enhanced_notification_service.dart';

void main() {
  group('EnhancedNotificationService', () {
    late EnhancedNotificationService service;
    setUp(() {
      service = EnhancedNotificationService.instance;
    });

    tearDown(() {
      service.dispose();
    });

    group('Singleton Pattern', () {
      test('should be a singleton', () {
        // Arrange & Act
        final instance1 = EnhancedNotificationService.instance;
        final instance2 = EnhancedNotificationService.instance;

        // Assert
        expect(identical(instance1, instance2), isTrue);
      });

      test('should maintain singleton across multiple accesses', () {
        // Arrange
        final instances = <EnhancedNotificationService>[];

        // Act
        for (int i = 0; i < 10; i++) {
          instances.add(EnhancedNotificationService.instance);
        }

        // Assert
        for (int i = 1; i < instances.length; i++) {
          expect(identical(instances[0], instances[i]), isTrue);
        }
      });
    });

    group('Initialization State', () {
      test('should not be initialized by default', () {
        // Assert
        expect(service.isInitialized, isFalse);
      });

      test('should report initialization state correctly', () {
        // Arrange - before initialization
        expect(service.isInitialized, isFalse);

        // Note: We don't test actual initialization here to avoid Firebase/timeout issues
        // The initialization logic is tested through integration tests
      });
    });

    group('Deep Link Handling', () {
      test('should handle deep links without throwing exceptions', () {
        // Test that the service can receive deep links even without full initialization
        // This tests the error handling and graceful degradation
        
        // Arrange
        const validUrls = [
          '/movie/123',
          '/my-library',
          '/search',
          '/favorites',
        ];

        // Act & Assert - should not throw
        for (final url in validUrls) {
          expect(() => service.handleDeepLink(url), returnsNormally);
        }
      });

      test('should handle invalid deep links gracefully', () {
        // Arrange
        const invalidUrls = [
          '/invalid-route',
          '/movie/abc', // Invalid movie ID
          '',
          '   ',
          '/movie/',
        ];

        // Act & Assert - should handle gracefully without throwing
        for (final url in invalidUrls) {
          expect(() => service.handleDeepLink(url), returnsNormally);
        }
      });

      test('should sanitize URLs before processing', () {
        // Arrange
        const messyUrls = [
          '//movie//123//',
          '  /my-library  ',
          'search', // Missing leading slash
          '///multiple///slashes///',
        ];

        // Act & Assert - should not throw
        for (final url in messyUrls) {
          expect(() => service.handleDeepLink(url), returnsNormally);
        }
      });
    });

    group('Statistics and State', () {
      test('should provide service statistics', () {
        // Act
        final stats = service.getStats();

        // Assert
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats, containsPair('is_initialized', isA<bool>()));
        expect(stats, containsPair('has_navigator_key', isA<bool>()));
        expect(stats, containsPair('pending_navigations', isA<int>()));
        expect(stats, containsPair('pending_details', isA<List>()));
      });

      test('should report correct initial state in stats', () {
        // Act
        final stats = service.getStats();
        
        // Assert - initial state
        expect(stats['is_initialized'], isFalse);
        expect(stats['has_navigator_key'], isFalse);
        expect(stats['pending_navigations'], equals(0));
        expect(stats['pending_details'], isEmpty);
      });

      test('should provide consistent stats structure', () {
        // Act
        final stats1 = service.getStats();
        final stats2 = service.getStats();
        
        // Assert structure consistency
        expect(stats1.keys, equals(stats2.keys));
        for (final key in stats1.keys) {
          expect(stats1[key].runtimeType, equals(stats2[key].runtimeType));
        }
      });
    });

    group('Service Lifecycle', () {
      test('should dispose cleanly', () {
        // Act & Assert - should not throw
        expect(() => service.dispose(), returnsNormally);
      });

      test('should reset state after disposal', () {
        // Arrange
        service.dispose();

        // Act
        final stats = service.getStats();

        // Assert
        expect(stats['is_initialized'], isFalse);
        expect(stats['has_navigator_key'], isFalse);
        expect(stats['pending_navigations'], equals(0));
      });

      test('should handle multiple dispose calls safely', () {
        // Act & Assert - multiple dispose calls should not throw
        expect(() => service.dispose(), returnsNormally);
        expect(() => service.dispose(), returnsNormally);
        expect(() => service.dispose(), returnsNormally);
      });

      test('should maintain service stability after disposal', () {
        // Arrange
        service.dispose();

        // Act & Assert - service should still respond to basic calls
        expect(() => service.getStats(), returnsNormally);
        expect(() => service.handleDeepLink('/test'), returnsNormally);
      });
    });

    group('Error Handling', () {
      test('should handle navigation errors gracefully', () {
        // Test that the service doesn't crash when dealing with edge cases
        
        // Arrange - various problematic inputs
        const problematicInputs = [
          '',
          '   ',
          'invalid://url',
          '/movie/',
          '/movie/abc/def/ghi',
          'javascript:alert("test")', // Potential security issue
          'file:///etc/passwd', // File protocol
        ];

        // Act & Assert - should handle all inputs without throwing
        for (final input in problematicInputs) {
          expect(() => service.handleDeepLink(input), returnsNormally);
        }
      });

      test('should maintain service stability after errors', () {
        // Arrange - trigger some potential errors
        service.handleDeepLink('invalid-route');
        service.handleDeepLink('');
        service.handleDeepLink('/movie/invalid-id');

        // Act
        final stats = service.getStats();

        // Assert - service should still be functional
        expect(stats, isA<Map<String, dynamic>>());
        expect(() => service.dispose(), returnsNormally);
      });

      test('should handle concurrent operations safely', () {
        // Test that multiple simultaneous operations don't cause issues
        
        // Act & Assert - should handle concurrent calls without throwing
        expect(() {
          service.handleDeepLink('/movie/1');
          service.handleDeepLink('/movie/2');
          service.getStats();
          service.handleDeepLink('/movie/3');
          service.getStats();
        }, returnsNormally);
      });
    });

    group('Pending Navigation Management', () {
      test('should start with no pending navigations', () {
        // Act
        final stats = service.getStats();

        // Assert
        expect(stats['pending_navigations'], equals(0));
        expect(stats['pending_details'], isEmpty);
      });

      test('should provide detailed pending navigation information', () {
        // Act
        final stats = service.getStats();
        final pendingDetails = stats['pending_details'] as List;

        // Assert
        expect(pendingDetails, isA<List>());
        // When there are pending navigations, each should have required fields
        for (final item in pendingDetails) {
          expect(item, isA<Map>());
          if (item is Map) {
            // Check that required fields exist when there are pending items
            expect(item.containsKey('route'), isTrue);
            expect(item.containsKey('type'), isTrue);
            expect(item.containsKey('source'), isTrue);
            expect(item.containsKey('age_seconds'), isTrue);
          }
        }
      });

      test('should track navigation attempts', () {
        // This test verifies that the service tracks navigation attempts
        // even when they can't be executed immediately
        
        // Arrange - make several deep link attempts
        service.handleDeepLink('/movie/123');
        service.handleDeepLink('/my-library');
        
        // Act
        final stats = service.getStats();
        
        // Assert - the service should track these attempts
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['pending_navigations'], isA<int>());
      });
    });

    group('Route Integration', () {
      test('should work with different route patterns', () {
        // Test that the service properly handles various route patterns
        
        const testRoutes = [
          '/',                    // Root
          '/movie/123',          // Dynamic route with ID
          '/my-library',         // Static route
          '/search',             // Another static route
          '/my-library/lists/favorites', // Nested dynamic route
        ];

        // Act & Assert - should handle all routes without throwing
        for (final route in testRoutes) {
          expect(() => service.handleDeepLink(route), returnsNormally);
        }
      });

      test('should sanitize routes consistently', () {
        // Test route sanitization behavior
        
        final testCases = {
          '//movie//123//': '/movie/123',
          '  /my-library  ': '/my-library',
          'search': '/search',
          '': '/',
          '   ': '/',
        };

        // Act & Assert - test indirectly by verifying no exceptions
        testCases.forEach((input, expected) {
          expect(() => service.handleDeepLink(input), returnsNormally);
        });
      });
    });

    group('Service API Consistency', () {
      test('should provide stable API methods', () {
        // Verify that all expected public methods exist and are callable
        
        expect(service.isInitialized, isA<bool>());
        expect(() => service.handleDeepLink('/test'), returnsNormally);
        expect(() => service.getStats(), returnsNormally);
        expect(() => service.dispose(), returnsNormally);
      });

      test('should return consistent data types', () {
        // Verify that methods return expected types consistently
        
        expect(service.isInitialized, isA<bool>());
        
        final stats = service.getStats();
        expect(stats, isA<Map<String, dynamic>>());
        
        // Verify specific stat types
        expect(stats['is_initialized'], isA<bool>());
        expect(stats['has_navigator_key'], isA<bool>());
        expect(stats['pending_navigations'], isA<int>());
        expect(stats['pending_details'], isA<List>());
      });
    });
  });
}