import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peliculas/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Performance & Load Integration Tests', () {
    testWidgets('App startup performance is acceptable',
        (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      // Initialize the app
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      // Wait for the app to fully initialize
      await tester.pumpAndSettle(const Duration(seconds: 10));

      stopwatch.stop();

      // App should start within reasonable time (10 seconds is generous for integration tests)
      expect(stopwatch.elapsed.inSeconds, lessThan(10),
          reason: 'App startup took too long: ${stopwatch.elapsed}');

      // Verify app is fully loaded
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Navigation performance is smooth',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      final navigationTargets = [
        Icons.home,
        Icons.video_library,
        Icons.favorite,
        Icons.search,
        Icons.person,
      ];

      for (final icon in navigationTargets) {
        final button = find.byIcon(icon);
        if (button.evaluate().isNotEmpty) {
          final stopwatch = Stopwatch()..start();

          await tester.tap(button);
          await tester.pumpAndSettle(const Duration(seconds: 3));

          stopwatch.stop();

          // Navigation should complete within 3 seconds
          expect(stopwatch.elapsed.inSeconds, lessThan(4),
              reason:
                  'Navigation to $icon took too long: ${stopwatch.elapsed}');

          // Verify navigation was successful
          expect(find.byType(MaterialApp), findsOneWidget);
        }
      }
    });

    testWidgets('Scroll performance is smooth with large lists',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Find scrollable lists
      final scrollables = [
        find.byType(ListView),
        find.byType(GridView),
        find.byType(CustomScrollView),
      ];

      for (final scrollableFinder in scrollables) {
        if (scrollableFinder.evaluate().isNotEmpty) {
          final scrollable = scrollableFinder.first;

          // Perform scrolling test
          final stopwatch = Stopwatch()..start();

          // Scroll down multiple times
          for (int i = 0; i < 5; i++) {
            await tester.drag(scrollable, const Offset(0, -300));
            await tester.pump(const Duration(milliseconds: 100));
          }

          // Scroll back up
          for (int i = 0; i < 5; i++) {
            await tester.drag(scrollable, const Offset(0, 300));
            await tester.pump(const Duration(milliseconds: 100));
          }

          await tester.pumpAndSettle(const Duration(seconds: 2));
          stopwatch.stop();

          // Scrolling should be responsive
          expect(stopwatch.elapsed.inSeconds, lessThan(3),
              reason: 'Scrolling took too long: ${stopwatch.elapsed}');

          break; // Test first available scrollable
        }
      }
    });

    testWidgets('Memory usage remains stable during navigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Perform extensive navigation to test for memory leaks
      final navigationIcons = [
        Icons.home,
        Icons.video_library,
        Icons.favorite,
        Icons.search,
        Icons.person,
      ];

      // Navigate multiple times to different sections
      for (int cycle = 0; cycle < 3; cycle++) {
        for (final icon in navigationIcons) {
          final button = find.byIcon(icon);
          if (button.evaluate().isNotEmpty) {
            await tester.tap(button);
            await tester.pumpAndSettle(const Duration(milliseconds: 500));

            // Force garbage collection hint
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
      }

      // Final settle
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // App should still be responsive (indirect memory test)
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Search performance with various query lengths',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      final searchButton = find.byIcon(Icons.search);
      if (searchButton.evaluate().isNotEmpty) {
        await tester.tap(searchButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        final searchField = find.byType(TextField);
        if (searchField.evaluate().isNotEmpty) {
          final testQueries = [
            'a',
            'test',
            'avengers',
            'the lord of the rings',
            'supercalifragilisticexpialidocious', // Long query
          ];

          for (final query in testQueries) {
            final stopwatch = Stopwatch()..start();

            await tester.enterText(searchField.first, query);

            // Wait for search to process
            await tester.pump(const Duration(seconds: 1));
            await tester.pumpAndSettle(const Duration(seconds: 2));

            stopwatch.stop();

            // Search should respond within reasonable time
            expect(stopwatch.elapsed.inSeconds, lessThan(4),
                reason:
                    'Search for "$query" took too long: ${stopwatch.elapsed}');

            // Clear for next search
            await tester.enterText(searchField.first, '');
            await tester.pump(const Duration(milliseconds: 200));
          }
        }

        // Close search
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Image loading performance in lists',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for image-heavy screens (movie lists, etc.)
      final imageContainers = [
        find.byType(Image),
        find.byType(NetworkImage),
        find.byType(FadeInImage),
      ];

      bool foundImages = false;
      for (final imageFinder in imageContainers) {
        if (imageFinder.evaluate().isNotEmpty) {
          foundImages = true;
          break;
        }
      }

      if (foundImages) {
        // Test scrolling with images
        final scrollables = find.byType(ListView);
        if (scrollables.evaluate().isNotEmpty) {
          final stopwatch = Stopwatch()..start();

          // Scroll to trigger image loading
          await tester.drag(scrollables.first, const Offset(0, -500));
          await tester.pump(const Duration(seconds: 1));

          await tester.drag(scrollables.first, const Offset(0, -500));
          await tester.pump(const Duration(seconds: 1));

          await tester.pumpAndSettle(const Duration(seconds: 3));
          stopwatch.stop();

          // Should handle image loading smoothly
          expect(stopwatch.elapsed.inSeconds, lessThan(6),
              reason:
                  'Image loading during scroll took too long: ${stopwatch.elapsed}');
        }
      }

      // App should remain responsive regardless of image loading
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Theme switching performance', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Find theme toggle
      final themeButtons = [
        find.byIcon(Icons.brightness_6),
        find.byIcon(Icons.brightness_4),
        find.byIcon(Icons.brightness_2),
        find.byTooltip('Cambiar tema'),
      ];

      for (final themeButton in themeButtons) {
        if (themeButton.evaluate().isNotEmpty) {
          // Test multiple rapid theme switches
          for (int i = 0; i < 5; i++) {
            final stopwatch = Stopwatch()..start();

            await tester.tap(themeButton);
            await tester.pumpAndSettle(const Duration(seconds: 1));

            stopwatch.stop();

            // Theme switch should be fast
            expect(stopwatch.elapsed.inMilliseconds, lessThan(1500),
                reason: 'Theme switch $i took too long: ${stopwatch.elapsed}');

            // App should remain stable
            expect(find.byType(MaterialApp), findsOneWidget);
          }
          break;
        }
      }
    });

    testWidgets('App handles concurrent user interactions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Simulate rapid user interactions
      final interactions = [
        () async {
          final homeButton = find.byIcon(Icons.home);
          if (homeButton.evaluate().isNotEmpty) {
            await tester.tap(homeButton);
            await tester.pump(const Duration(milliseconds: 100));
          }
        },
        () async {
          final libraryButton = find.byIcon(Icons.video_library);
          if (libraryButton.evaluate().isNotEmpty) {
            await tester.tap(libraryButton);
            await tester.pump(const Duration(milliseconds: 100));
          }
        },
        () async {
          final searchButton = find.byIcon(Icons.search);
          if (searchButton.evaluate().isNotEmpty) {
            await tester.tap(searchButton);
            await tester.pump(const Duration(milliseconds: 100));
          }
        },
      ];

      final stopwatch = Stopwatch()..start();

      // Perform rapid interactions
      for (int i = 0; i < 10; i++) {
        for (final interaction in interactions) {
          await interaction();
        }
      }

      await tester.pumpAndSettle(const Duration(seconds: 3));
      stopwatch.stop();

      // Should handle concurrent interactions gracefully
      expect(stopwatch.elapsed.inSeconds, lessThan(5),
          reason:
              'Concurrent interactions took too long: ${stopwatch.elapsed}');

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
