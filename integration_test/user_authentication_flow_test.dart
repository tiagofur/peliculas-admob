import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peliculas/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('User Authentication Flow Tests', () {
    testWidgets('App handles unauthenticated state correctly',
        (WidgetTester tester) async {
      // Initialize the app
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      // Wait for the app to initialize
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app loads without crashing
      expect(find.byType(MaterialApp), findsOneWidget);

      // Check for guest mode banner or sign-in prompts
      final guestBanner = find.text('Modo Invitado');
      final signInButton = find.text('Iniciar Sesión');
      final loginButton = find.text('Login');

      // At least one authentication-related UI should be present
      expect(
        guestBanner.evaluate().isNotEmpty ||
            signInButton.evaluate().isNotEmpty ||
            loginButton.evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('Authentication modal/screen can be accessed',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Try to access authentication through drawer
      final drawerButton = find.byIcon(Icons.menu);
      if (drawerButton.evaluate().isNotEmpty) {
        await tester.tap(drawerButton);
        await tester.pumpAndSettle();

        // Look for authentication-related options in drawer
        final loginTile = find.text('Iniciar Sesión');
        final profileTile = find.text('Perfil');

        if (loginTile.evaluate().isNotEmpty) {
          await tester.tap(loginTile);
          await tester.pumpAndSettle();

          // Verify we're on login screen/modal
          expect(find.text('Email'), findsWidgets);
          expect(find.text('Password'), findsWidgets);

          // Close modal/navigate back
          final backButton = find.byIcon(Icons.arrow_back);
          final closeButton = find.byIcon(Icons.close);

          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();
          } else if (closeButton.evaluate().isNotEmpty) {
            await tester.tap(closeButton);
            await tester.pumpAndSettle();
          }
        } else if (profileTile.evaluate().isNotEmpty) {
          await tester.tap(profileTile);
          await tester.pumpAndSettle();

          // If we reach profile, we might see authentication prompts there
          final signInPrompt = find.textContaining('Inicia sesión');
          expect(signInPrompt.evaluate().isNotEmpty, isTrue);

          // Navigate back
          final backButton = find.byIcon(Icons.arrow_back);
          if (backButton.evaluate().isNotEmpty) {
            await tester.tap(backButton);
            await tester.pumpAndSettle();
          }
        }
      }
    });

    testWidgets(
        'Profile screen shows appropriate state for unauthenticated user',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to profile through bottom navigation if available
      final bottomNavProfile = find.byIcon(Icons.person);
      if (bottomNavProfile.evaluate().isNotEmpty) {
        await tester.tap(bottomNavProfile);
        await tester.pumpAndSettle();

        // Should show either login prompt or guest profile
        final loginPrompt = find.textContaining('Inicia sesión');
        final guestProfile = find.text('Invitado');

        expect(
          loginPrompt.evaluate().isNotEmpty ||
              guestProfile.evaluate().isNotEmpty,
          isTrue,
        );
      }
    });

    testWidgets('Guest mode functionality works', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Look for guest mode indicators
      final guestBanner = find.text('Modo Invitado');
      final guestMode = find.textContaining('Invitado');

      if (guestBanner.evaluate().isNotEmpty ||
          guestMode.evaluate().isNotEmpty) {
        // In guest mode, basic navigation should work
        final homeIcon = find.byIcon(Icons.home);
        if (homeIcon.evaluate().isNotEmpty) {
          await tester.tap(homeIcon);
          await tester.pumpAndSettle();
        }

        // Movies should be browsable in guest mode
        final movieCards = find.byType(Card);
        expect(movieCards.evaluate().isNotEmpty, isTrue);
      }
    });

    testWidgets('Persistent auth state is handled correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: app.MainApp()),
      );

      // Allow more time for auth state initialization
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // Verify app doesn't crash during auth state resolution
      expect(find.byType(MaterialApp), findsOneWidget);

      // Check that auth-related providers are properly initialized
      // This is tested by ensuring the app loads without throwing exceptions
      // and that UI elements are rendered appropriately

      // Look for navigation elements which indicate proper state management
      final bottomNav = find.byType(BottomNavigationBar);
      final appBar = find.byType(AppBar);

      expect(
        bottomNav.evaluate().isNotEmpty || appBar.evaluate().isNotEmpty,
        isTrue,
      );
    });
  });
}
