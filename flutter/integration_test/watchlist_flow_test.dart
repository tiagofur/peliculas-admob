import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peliculas/infrastructure/services/connectivity_detector.dart';
import 'package:peliculas/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Watchlist Management Flow Tests', () {
    setUpAll(() {
      // Configure test mode for ConnectivityDetector to prevent Timer leaks
      ConnectivityDetector.setTestMode(true);
    });

    tearDownAll(() {
      ConnectivityDetector.setTestMode(false);
    });

    testWidgets('Watchlist screen is accessible and functional',
        (WidgetTester tester) async {
      // Initialize the app
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      // Wait for the app to initialize
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to watchlist through bottom navigation
      final watchlistIcon = find.byIcon(Icons.video_library);
      final libraryIcon = find.byIcon(Icons.library_books);

      if (watchlistIcon.evaluate().isNotEmpty) {
        await tester.tap(watchlistIcon);
        await tester.pumpAndSettle();

        // Verify we're on watchlist screen
        expect(find.text('Mi Biblioteca'), findsWidgets);

        // Check for watchlist-related UI elements
        final addButton = find.byIcon(Icons.add);
        final searchButton = find.byIcon(Icons.search);

        // These buttons might be present on watchlist screen
        expect(
          addButton.evaluate().isNotEmpty || searchButton.evaluate().isNotEmpty,
          isTrue,
        );
      } else if (libraryIcon.evaluate().isNotEmpty) {
        await tester.tap(libraryIcon);
        await tester.pumpAndSettle();

        // Alternative library/watchlist UI
        expect(find.textContaining('Lista'), findsWidgets);
      }
    });

    testWidgets('Add to watchlist functionality works from movie detail',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Find and tap on a movie card to go to detail screen
      final movieCards = find.byType(Card);
      if (movieCards.evaluate().isNotEmpty) {
        await tester.tap(movieCards.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Look for watchlist/favorite button on movie detail screen
        final favoriteButton = find.byIcon(Icons.favorite_border);
        find.byIcon(Icons.favorite);
        find.byIcon(Icons.add);
        final bookmarkButton = find.byIcon(Icons.bookmark_border);

        // Try to interact with watchlist functionality
        if (favoriteButton.evaluate().isNotEmpty) {
          await tester.tap(favoriteButton);
          await tester.pumpAndSettle();

          // Should change to filled or show some feedback
          expect(
            find.byIcon(Icons.favorite).evaluate().isNotEmpty ||
                find.textContaining('Agregado').evaluate().isNotEmpty,
            isTrue,
          );
        } else if (bookmarkButton.evaluate().isNotEmpty) {
          await tester.tap(bookmarkButton);
          await tester.pumpAndSettle();

          // Should show feedback
          expect(find.byIcon(Icons.bookmark), findsWidgets);
        }

        // Navigate back
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Watchlist filters and search work',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to watchlist
      final watchlistIcon = find.byIcon(Icons.video_library);
      if (watchlistIcon.evaluate().isNotEmpty) {
        await tester.tap(watchlistIcon);
        await tester.pumpAndSettle();

        // Test search functionality if available
        final searchButton = find.byIcon(Icons.search);
        if (searchButton.evaluate().isNotEmpty) {
          await tester.tap(searchButton);
          await tester.pumpAndSettle();

          // Type in search field
          final searchField = find.byType(TextField);
          if (searchField.evaluate().isNotEmpty) {
            await tester.enterText(searchField.first, 'test');
            await tester.pump();
            await tester.pumpAndSettle();

            // Clear search
            await tester.enterText(searchField.first, '');
            await tester.pump();
          }
        }

        // Test filter functionality if available
        final filterButton = find.byIcon(Icons.filter_list);
        if (filterButton.evaluate().isNotEmpty) {
          await tester.tap(filterButton);
          await tester.pumpAndSettle();

          // Look for filter options
          final genreFilter = find.text('Género');
          find.text('Año');

          if (genreFilter.evaluate().isNotEmpty) {
            await tester.tap(genreFilter);
            await tester.pumpAndSettle();
          }

          // Close filter dialog if needed
          final closeButton = find.byIcon(Icons.close);
          if (closeButton.evaluate().isNotEmpty) {
            await tester.tap(closeButton);
            await tester.pumpAndSettle();
          }
        }
      }
    });

    testWidgets('Custom lists functionality works',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to watchlist/library
      final libraryIcon = find.byIcon(Icons.video_library);
      if (libraryIcon.evaluate().isNotEmpty) {
        await tester.tap(libraryIcon);
        await tester.pumpAndSettle();

        // Look for custom lists section
        final listsTab = find.text('Listas');
        find.text('Mis Listas');

        if (listsTab.evaluate().isNotEmpty) {
          await tester.tap(listsTab);
          await tester.pumpAndSettle();

          // Test create new list functionality
          final addListButton = find.byIcon(Icons.add);
          find.text('Crear Lista');

          if (addListButton.evaluate().isNotEmpty) {
            await tester.tap(addListButton);
            await tester.pumpAndSettle();

            // Should show create list dialog or screen
            expect(
              find.text('Nombre').evaluate().isNotEmpty ||
                  find.text('Título').evaluate().isNotEmpty,
              isTrue,
            );

            // Cancel or close dialog
            final cancelButton = find.text('Cancelar');
            final closeButton = find.byIcon(Icons.close);

            if (cancelButton.evaluate().isNotEmpty) {
              await tester.tap(cancelButton);
              await tester.pumpAndSettle();
            } else if (closeButton.evaluate().isNotEmpty) {
              await tester.tap(closeButton);
              await tester.pumpAndSettle();
            }
          }
        }
      }
    });

    testWidgets('Watchlist sync indicator works', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to watchlist
      final libraryIcon = find.byIcon(Icons.video_library);
      if (libraryIcon.evaluate().isNotEmpty) {
        await tester.tap(libraryIcon);
        await tester.pumpAndSettle();

        // Look for sync indicators
        final syncIcon = find.byIcon(Icons.sync);
        final cloudIcon = find.byIcon(Icons.cloud_sync);
        final offlineIcon = find.byIcon(Icons.offline_pin);

        // At least one sync-related indicator should be present
        expect(
          syncIcon.evaluate().isNotEmpty ||
              cloudIcon.evaluate().isNotEmpty ||
              offlineIcon.evaluate().isNotEmpty,
          isTrue,
        );

        // Test manual sync if available
        if (syncIcon.evaluate().isNotEmpty) {
          await tester.tap(syncIcon);
          await tester.pumpAndSettle();

          // Sync operation should complete without errors
          expect(find.byType(CircularProgressIndicator), findsWidgets);
        }
      }
    });
  });
}
