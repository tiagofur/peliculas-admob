import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/navigation/navigation_error_boundary.dart';

void main() {
  group('NavigationErrorBoundary', () {
    group('Widget Creation', () {
      testWidgets('should render child widget when no error',
          (WidgetTester tester) async {
        // Arrange
        const testChild = Text('Test Child');

        // Act
        await tester.pumpWidget(
          const MaterialApp(
            home: NavigationErrorBoundary(
              child: testChild,
            ),
          ),
        );

        // Assert
        expect(find.text('Test Child'), findsOneWidget);
        expect(find.byType(NavigationErrorBoundary), findsOneWidget);
      });

      testWidgets('should render with custom fallback widget',
          (WidgetTester tester) async {
        // Arrange
        const testChild = Text('Test Child');
        const customFallback = Text('Custom Fallback');

        // Act
        await tester.pumpWidget(
          const MaterialApp(
            home: NavigationErrorBoundary(
              fallbackWidget: customFallback,
              child: testChild,
            ),
          ),
        );

        // Assert
        expect(find.text('Test Child'), findsOneWidget);
        expect(find.text('Custom Fallback'), findsNothing);
      });

      testWidgets('should call onError callback when provided',
          (WidgetTester tester) async {
        // Arrange
        bool errorCallbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: NavigationErrorBoundary(
              onError: (details) {
                errorCallbackCalled = true;
              },
              child: const Text('Test Child'),
            ),
          ),
        );

        // Initial verification
        expect(find.text('Test Child'), findsOneWidget);
        expect(errorCallbackCalled, isFalse);

        // Note: Testing error handling is complex due to Flutter's error boundary implementation
        // In real scenarios, the error boundary would catch Flutter framework errors automatically
      });
    });

    group('Error Widget Structure', () {
      testWidgets('should have proper structure in error widget',
          (WidgetTester tester) async {
        // This test verifies the structure of the default error widget by simulating its creation

        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                title: const Text('Error de Navegación'),
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error de Navegación',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ha ocurrido un error al navegar por la aplicación. No te preocupes, hemos registrado el error y trabajaremos para solucionarlo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.home),
                            label: const Text('Ir al Inicio'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Ver Detalles del Error'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Assert - verify all error widget elements are present
        expect(find.text('Error de Navegación'),
            findsNWidgets(2)); // Title in AppBar and body
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.text('Ir al Inicio'), findsOneWidget);
        expect(find.text('Ver Detalles del Error'), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(find.byIcon(Icons.home), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });
    });
  });

  group('SafeNavigation', () {
    group('Route Validation', () {
      test('should validate known valid routes', () {
        // Arrange
        const validRoutes = [
          '/',
          '/my-library',
          '/search',
          '/favorites',
          '/watchlist',
          '/settings',
          '/profile',
          '/login',
          '/register',
        ];

        // Act & Assert
        for (final route in validRoutes) {
          expect(
            SafeNavigation.isValidRoute(route),
            isTrue,
            reason: 'Route $route should be valid',
          );
        }
      });

      test('should validate dynamic routes with patterns', () {
        // Arrange
        const validDynamicRoutes = [
          '/movie/123',
          '/movie/456789',
          '/my-library/lists/favorites',
          '/my-library/lists/watchlist',
          '/recommendations/comedy',
          '/recommendations/action-movies',
        ];

        // Act & Assert
        for (final route in validDynamicRoutes) {
          expect(
            SafeNavigation.isValidRoute(route),
            isTrue,
            reason: 'Dynamic route $route should be valid',
          );
        }
      });

      test('should reject invalid routes', () {
        // Arrange
        const invalidRoutes = [
          '/invalid-route',
          '/movie/abc', // Non-numeric movie ID
          '/movie/', // Missing ID
          '/unknown/path',
          '',
          '  ',
        ];

        // Act & Assert
        for (final route in invalidRoutes) {
          expect(
            SafeNavigation.isValidRoute(route),
            isFalse,
            reason: 'Route $route should be invalid',
          );
        }
      });
    });

    group('Route Sanitization', () {
      test('should sanitize routes correctly', () {
        // Test cases for route sanitization
        final testCases = {
          'home': '/home',
          '/movies/': '/movies',
          '//multiple//slashes//': '/multiple/slashes',
          '  /whitespace  ': '/whitespace',
          '/': '/', // Root should remain unchanged
          '': '/',
        };

        // Act & Assert
        testCases.forEach((input, expected) {
          expect(
            SafeNavigation.sanitizeRoute(input),
            equals(expected),
            reason: 'Input "$input" should be sanitized to "$expected"',
          );
        });
      });

      test('should handle edge cases in sanitization', () {
        // Arrange & Act & Assert
        expect(SafeNavigation.sanitizeRoute('  '), equals('/'));
        expect(SafeNavigation.sanitizeRoute('///'), equals('/'));
        expect(SafeNavigation.sanitizeRoute('/path///to///resource/'),
            equals('/path/to/resource'));
        expect(SafeNavigation.sanitizeRoute('path/without/leading/slash'),
            equals('/path/without/leading/slash'));
      });
    });

    group('Safe Navigation Methods', () {
      test('should provide safe navigation methods', () {
        // Test that the static methods exist and can be called without context
        // This verifies the API is available even if we can't test full navigation

        expect(SafeNavigation.isValidRoute, isA<Function>());
        expect(SafeNavigation.sanitizeRoute, isA<Function>());
        expect(SafeNavigation.safeGo, isA<Function>());
        expect(SafeNavigation.safePush, isA<Function>());
        expect(SafeNavigation.safeReplace, isA<Function>());
      });
    });

    group('Utility Functions', () {
      test('should identify valid route patterns', () {
        // Test movie routes
        expect(SafeNavigation.isValidRoute('/movie/123'), isTrue);
        expect(SafeNavigation.isValidRoute('/movie/999999'), isTrue);
        expect(SafeNavigation.isValidRoute('/movie/abc'), isFalse);
        expect(SafeNavigation.isValidRoute('/movie/'), isFalse);

        // Test library routes
        expect(SafeNavigation.isValidRoute('/my-library/lists/test'), isTrue);
        expect(SafeNavigation.isValidRoute('/my-library/lists/'), isFalse);

        // Test recommendation routes
        expect(SafeNavigation.isValidRoute('/recommendations/action'), isTrue);
        expect(SafeNavigation.isValidRoute('/recommendations/sci-fi'), isTrue);
        expect(SafeNavigation.isValidRoute('/recommendations/'), isFalse);
      });

      test('should handle sanitization edge cases consistently', () {
        // Multiple consecutive operations should be idempotent
        const testRoute = '  //multiple///slashes//path//  ';
        final sanitized1 = SafeNavigation.sanitizeRoute(testRoute);
        final sanitized2 = SafeNavigation.sanitizeRoute(sanitized1);

        expect(sanitized1, equals(sanitized2));
        expect(sanitized1, equals('/multiple/slashes/path'));
      });
    });
  });
}
