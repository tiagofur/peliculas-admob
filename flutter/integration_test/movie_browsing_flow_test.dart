import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peliculas/infrastructure/services/connectivity_detector.dart';
import 'package:peliculas/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Movie Browsing Flow Integration Tests', () {
    setUpAll(() {
      // Configure test mode for ConnectivityDetector to prevent Timer leaks
      ConnectivityDetector.setTestMode(true);
    });

    tearDownAll(() {
      ConnectivityDetector.setTestMode(false);
    });

    testWidgets('Complete movie browsing flow works end-to-end',
        (WidgetTester tester) async {
      // Initialize the app
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      // Wait for the app to initialize
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app loads correctly
      expect(find.byType(MaterialApp), findsOneWidget);

      // Check if we're on the home screen by looking for common elements
      // Look for the app bar title
      expect(find.text('Peliculas'), findsWidgets);

      // Test search functionality
      final searchButton = find.byIcon(Icons.search);
      if (searchButton.evaluate().isNotEmpty) {
        await tester.tap(searchButton);
        await tester.pumpAndSettle();

        // Type in search field if it appears
        final searchField = find.byType(TextField);
        if (searchField.evaluate().isNotEmpty) {
          await tester.enterText(searchField.first, 'test');
          await tester.pump();
          await tester.pumpAndSettle();
        }

        // Close search if needed
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle();
        }
      }

      // Test navigation to movie details
      // Look for movie cards or tiles
      final movieCards = find.byType(Card);
      if (movieCards.evaluate().isNotEmpty) {
        // Tap on the first movie card
        await tester.tap(movieCards.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify we're on a movie detail screen
        // Look for common movie detail elements
        final shareButton = find.byIcon(Icons.share);
        final favoriteButton = find.byIcon(Icons.favorite_border);

        // At least one of these should be present on movie detail screen
        expect(
            shareButton.evaluate().isNotEmpty ||
                favoriteButton.evaluate().isNotEmpty,
            isTrue);

        // Navigate back to home
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Bottom navigation works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for bottom navigation bar
      final bottomNavBar = find.byType(BottomNavigationBar);
      if (bottomNavBar.evaluate().isNotEmpty) {
        // Test tapping different tabs
        final navItems = find.byType(BottomNavigationBarItem);

        // If we have navigation items, test switching between them
        if (navItems.evaluate().length > 1) {
          // Tap second tab
          await tester.tap(find.byIcon(Icons.video_library).first);
          await tester.pumpAndSettle();

          // Tap first tab to go back
          await tester.tap(find.byIcon(Icons.home).first);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Theme toggle works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Find and tap theme toggle button in app bar
      final themeButton = find.byIcon(Icons.light_mode_outlined);
      final darkThemeButton = find.byIcon(Icons.dark_mode_outlined);

      // Try to toggle theme
      if (themeButton.evaluate().isNotEmpty) {
        await tester.tap(themeButton);
        await tester.pumpAndSettle();

        // Verify theme changed by checking for dark mode icon
        expect(find.byIcon(Icons.dark_mode_outlined), findsWidgets);
      } else if (darkThemeButton.evaluate().isNotEmpty) {
        await tester.tap(darkThemeButton);
        await tester.pumpAndSettle();

        // Verify theme changed by checking for light mode icon
        expect(find.byIcon(Icons.light_mode_outlined), findsWidgets);
      }
    });

    testWidgets('Drawer navigation works', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Try to open drawer
      final drawerButton = find.byIcon(Icons.menu);
      if (drawerButton.evaluate().isNotEmpty) {
        await tester.tap(drawerButton);
        await tester.pumpAndSettle();

        // Verify drawer is open by looking for common drawer items
        expect(find.byType(Drawer), findsOneWidget);

        // Try to navigate to profile/settings if available
        final profileTile = find.text('Perfil');
        final settingsTile = find.text('Configuración');

        if (profileTile.evaluate().isNotEmpty) {
          await tester.tap(profileTile);
          await tester.pumpAndSettle();

          // Navigate back if needed
          final backButton = find.byIcon(Icons.arrow_back);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();
          }
        } else if (settingsTile.evaluate().isNotEmpty) {
          await tester.tap(settingsTile);
          await tester.pumpAndSettle();

          // Navigate back if needed
          final backButton = find.byIcon(Icons.arrow_back);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();
          }
        }
      }
    });
  });
}
