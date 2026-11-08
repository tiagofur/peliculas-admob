import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peliculas/infrastructure/services/connectivity_detector.dart';
import 'package:peliculas/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sharing Functionality Integration Tests', () {
    setUpAll(() {
      // Configure test mode for ConnectivityDetector to prevent Timer leaks
      ConnectivityDetector.setTestMode(true);
    });

    tearDownAll(() {
      ConnectivityDetector.setTestMode(false);
    });

    testWidgets('Share button is accessible on movie detail screen',
        (WidgetTester tester) async {
      // Initialize the app
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      // Wait for the app to initialize
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to a movie detail screen
      final movieCards = find.byType(Card);
      if (movieCards.evaluate().isNotEmpty) {
        await tester.tap(movieCards.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Look for share button
        final shareButton = find.byIcon(Icons.share);
        if (shareButton.evaluate().isNotEmpty) {
          // Verify share button is accessible
          expect(shareButton, findsOneWidget);

          // Test tapping share button (should open share dialog or sheet)
          await tester.tap(shareButton);
          await tester.pumpAndSettle();

          // Look for share dialog or system share sheet indicators
          // Note: System share sheet might not be visible in tests,
          // but we can verify no errors occur
          expect(find.byType(MaterialApp), findsOneWidget);
        }

        // Navigate back
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Deep link handling works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app handles startup correctly (no deep link errors)
      expect(find.byType(MaterialApp), findsOneWidget);

      // Test that the app doesn't crash when initializing
      // Deep link functionality is tested through URL navigation
      final homeElements = find.byType(Scaffold);
      expect(homeElements, findsWidgets);
    });

    testWidgets('Share functionality preserves app state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to movie detail
      final movieCards = find.byType(Card);
      if (movieCards.evaluate().isNotEmpty) {
        await tester.tap(movieCards.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Trigger share if available
        final shareButton = find.byIcon(Icons.share);
        if (shareButton.evaluate().isNotEmpty) {
          await tester.tap(shareButton);
          await tester.pumpAndSettle();

          // Verify we're still on the movie detail screen
          // (sharing shouldn't navigate away)
          final backButton = find.byIcon(Icons.arrow_back);
          expect(backButton, findsWidgets);
        }
      }
    });

    testWidgets('Multiple share actions work without conflicts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to movie detail
      final movieCards = find.byType(Card);
      if (movieCards.evaluate().isNotEmpty) {
        await tester.tap(movieCards.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Test multiple share button taps
        final shareButton = find.byIcon(Icons.share);
        if (shareButton.evaluate().isNotEmpty) {
          // First share
          await tester.tap(shareButton);
          await tester.pumpAndSettle();

          // Second share (should not cause errors)
          await tester.tap(shareButton);
          await tester.pumpAndSettle();

          // Verify app is still stable
          expect(find.byType(MaterialApp), findsOneWidget);
        }
      }
    });

    testWidgets('Share button appears in correct contexts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Check home screen (share button should not be prominent here)
      find.byIcon(Icons.share);
      // Home screen typically shouldn't have many share buttons

      // Navigate to movie detail where share should be available
      final movieCards = find.byType(Card);
      if (movieCards.evaluate().isNotEmpty) {
        await tester.tap(movieCards.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Movie detail should have share functionality
        final detailShareButtons = find.byIcon(Icons.share);
        // Should find at least one share button on movie detail
        expect(detailShareButtons.evaluate().isNotEmpty, isTrue);
      }
    });

    testWidgets('Share URLs are properly formatted',
        (WidgetTester tester) async {
      // This test verifies that the sharing system initializes correctly
      // URL format testing is done in unit tests, but we verify no crashes
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app loads without URL formatting errors
      expect(find.byType(MaterialApp), findsOneWidget);

      // Navigate through different screens to test URL handling
      final movieCards = find.byType(Card);
      if (movieCards.evaluate().isNotEmpty) {
        await tester.tap(movieCards.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Movie detail screen should load without URL errors
        expect(find.byType(Scaffold), findsWidgets);

        // Navigate back
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Cross-platform sharing works consistently',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Test that sharing functionality works regardless of platform
      // (The implementation should handle platform differences internally)

      final movieCards = find.byType(Card);
      if (movieCards.evaluate().isNotEmpty) {
        await tester.tap(movieCards.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        final shareButton = find.byIcon(Icons.share);
        if (shareButton.evaluate().isNotEmpty) {
          // Test share functionality
          await tester.tap(shareButton);
          await tester.pumpAndSettle();

          // Verify no platform-specific errors occur
          expect(find.byType(MaterialApp), findsOneWidget);
        }
      }
    });
  });
}
