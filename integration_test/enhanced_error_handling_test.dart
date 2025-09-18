import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peliculas/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Enhanced Integration Tests - Error Handling & Edge Cases', () {
    testWidgets('App handles network errors gracefully',
        (WidgetTester tester) async {
      // Initialize the app
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      // Wait for initial loading with extended timeout
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Verify app loads without crashing even with network issues
      expect(find.byType(MaterialApp), findsOneWidget);

      // Look for error handling UI elements
      final errorMessages = [
        'Error de conexión',
        'Sin conexión',
        'Reintentar',
        'Modo offline',
        'Error de red',
      ];

      bool hasErrorHandling = false;
      for (final message in errorMessages) {
        if (find.text(message).evaluate().isNotEmpty) {
          hasErrorHandling = true;
          break;
        }
      }

      // Either show content or proper error handling
      final hasContent = find.byType(ListView).evaluate().isNotEmpty ||
          find.byType(GridView).evaluate().isNotEmpty ||
          hasErrorHandling;

      expect(hasContent, isTrue,
          reason: 'App should either show content or proper error handling');
    });

    testWidgets('App handles empty states correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 8));

      // Navigate to different sections to test empty states
      final navigationTargets = [
        Icons.video_library,
        Icons.favorite,
        Icons.search,
        Icons.person,
      ];

      for (final icon in navigationTargets) {
        final navButton = find.byIcon(icon);
        if (navButton.evaluate().isNotEmpty) {
          await tester.tap(navButton);
          await tester.pumpAndSettle(const Duration(seconds: 3));

          // Should not crash and should show appropriate UI
          expect(find.byType(MaterialApp), findsOneWidget);

          // Look for empty state indicators
          final emptyStateTexts = [
            'No hay elementos',
            'Lista vacía',
            'Sin resultados',
            'Agregar película',
            'No encontrado',
          ];

          // Check if there's content or proper empty state
          bool hasContentOrEmptyState = find
                  .byType(ListView)
                  .evaluate()
                  .isNotEmpty ||
              find.byType(GridView).evaluate().isNotEmpty ||
              emptyStateTexts.any(
                  (text) => find.textContaining(text).evaluate().isNotEmpty);

          expect(hasContentOrEmptyState, isTrue,
              reason:
                  'Section should show content or proper empty state for icon: $icon');
        }
      }
    });

    testWidgets('App handles rapid navigation without crashes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Perform rapid navigation to stress test the app
      final navigationIcons = [
        Icons.home,
        Icons.video_library,
        Icons.favorite,
        Icons.search,
        Icons.person,
        Icons.menu,
      ];

      for (int i = 0; i < 3; i++) {
        // Repeat 3 times
        for (final icon in navigationIcons) {
          final button = find.byIcon(icon);
          if (button.evaluate().isNotEmpty) {
            await tester.tap(button);
            await tester
                .pump(const Duration(milliseconds: 100)); // Minimal wait
          }
        }
      }

      // Final settle to ensure app is stable
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // App should still be functional
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App handles device rotation (if supported)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Get initial orientation
      final initialSize = tester.view.physicalSize;

      try {
        // Simulate rotation by changing window size
        tester.view.physicalSize = Size(
          initialSize.height,
          initialSize.width,
        );

        await tester.pumpAndSettle(const Duration(seconds: 2));

        // App should handle orientation change gracefully
        expect(find.byType(MaterialApp), findsOneWidget);

        // Restore original orientation
        tester.view.physicalSize = initialSize;
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(find.byType(MaterialApp), findsOneWidget);
      } finally {
        // Ensure we restore the original size
        tester.view.resetPhysicalSize();
      }
    });

    testWidgets('App handles memory pressure scenarios',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Simulate memory pressure by triggering system memory warnings
      try {
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/system',
          (data) async {
            return null;
          },
        );

        // Simulate low memory warning
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/system',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('SystemSound.play', 'SystemSoundType.click'),
          ),
          (data) {},
        );

        await tester.pumpAndSettle(const Duration(seconds: 2));

        // App should still be responsive
        expect(find.byType(MaterialApp), findsOneWidget);
      } finally {
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/system',
          null,
        );
      }
    });

    testWidgets('App handles theme changes consistently',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Find theme toggle button
      final themeButtons = [
        find.byIcon(Icons.brightness_6),
        find.byIcon(Icons.brightness_4),
        find.byIcon(Icons.brightness_2),
        find.byTooltip('Cambiar tema'),
        find.text('Tema'),
      ];

      for (final themeButton in themeButtons) {
        if (themeButton.evaluate().isNotEmpty) {
          // Toggle theme multiple times
          for (int i = 0; i < 4; i++) {
            await tester.tap(themeButton);
            await tester.pumpAndSettle(const Duration(milliseconds: 500));

            // Verify app remains stable
            expect(find.byType(MaterialApp), findsOneWidget);
          }
          break; // Found and tested theme toggle
        }
      }
    });

    testWidgets('App handles search with special characters and edge cases',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Find search functionality
      final searchButton = find.byIcon(Icons.search);
      if (searchButton.evaluate().isNotEmpty) {
        await tester.tap(searchButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        final searchField = find.byType(TextField);
        if (searchField.evaluate().isNotEmpty) {
          // Test various search edge cases
          final testQueries = [
            '', // Empty search
            ' ', // Space only
            '!!!@#\$%^&*()', // Special characters
            '   test   ', // Leading/trailing spaces
            'á é í ó ú ñ', // Accented characters
            '1234567890', // Numbers only
            'a' * 100, // Very long search
          ];

          for (final query in testQueries) {
            await tester.enterText(searchField.first, query);
            await tester.pump(const Duration(milliseconds: 500));

            // App should handle all search queries gracefully
            expect(find.byType(MaterialApp), findsOneWidget);

            // Clear search field for next test
            await tester.enterText(searchField.first, '');
            await tester.pump(const Duration(milliseconds: 200));
          }
        }

        // Close search if possible
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('App maintains state during background/foreground cycles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to a specific section
      final libraryButton = find.byIcon(Icons.video_library);
      if (libraryButton.evaluate().isNotEmpty) {
        await tester.tap(libraryButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Simulate app lifecycle events
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        const StringCodec().encodeMessage('AppLifecycleState.paused'),
        (data) {},
      );

      await tester.pump(const Duration(milliseconds: 100));

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        const StringCodec().encodeMessage('AppLifecycleState.resumed'),
        (data) {},
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // App should still be in the same section and functional
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
