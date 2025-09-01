import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/domain/entities/user.dart';
import 'package:peliculas/domain/entities/user_profile.dart';
import 'package:peliculas/domain/entities/user_stats.dart';
import 'package:peliculas/presentation/providers/auth_provider.dart';
import 'package:peliculas/presentation/screens/profile/profile_screen.dart';

void main() {
  group('ProfileScreen Tests', () {
    testWidgets('Profile screen shows user info correctly', (WidgetTester tester) async {
      // Mock user and profile data
      final mockUser = User(
        id: 'test-user-id',
        email: 'test@example.com',
        fullName: 'Test User',
        createdAt: DateTime.now(),
      );

      final mockProfile = UserProfile(
        id: 'profile-id',
        userId: 'test-user-id',
        fullName: 'Test User',
        bio: 'Test bio',
        avatarUrl: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mockStats = UserStats(
        id: 'stats-id',
        userId: 'test-user-id',
        moviesWatched: 10,
        favoritesCount: 5,
        listsCount: 2,
        averageRating: 4.5,
        totalMinutesWatched: 1200,
        lastActivity: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => mockUser),
            currentUserProfileProvider.overrideWith((ref) => AsyncValue.data(mockProfile)),
            currentUserStatsProvider.overrideWith((ref) => AsyncValue.data(mockStats)),
          ],
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify that user information is displayed
      expect(find.text('Mi Perfil'), findsOneWidget);
      expect(find.text('Test User'), findsAtLeastNWidgets(1));
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('Test bio'), findsOneWidget);
    });

    testWidgets('Edit button switches to edit mode', (WidgetTester tester) async {
      // Mock user and profile data
      final mockUser = User(
        id: 'test-user-id',
        email: 'test@example.com',
        fullName: 'Test User',
        createdAt: DateTime.now(),
      );

      final mockProfile = UserProfile(
        id: 'profile-id',
        userId: 'test-user-id',
        fullName: 'Test User',
        bio: 'Test bio',
        avatarUrl: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => mockUser),
            currentUserProfileProvider.overrideWith((ref) => AsyncValue.data(mockProfile)),
            currentUserStatsProvider.overrideWith((ref) => AsyncValue.data(null)),
          ],
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Tap the edit button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Verify that form fields are shown
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      
      // Verify that text fields are present
      expect(find.byType(TextFormField), findsAtLeastNWidgets(3)); // Name, email, bio
    });

    testWidgets('Form validation works for required fields', (WidgetTester tester) async {
      // Mock user and profile data
      final mockUser = User(
        id: 'test-user-id',
        email: 'test@example.com',
        fullName: 'Test User',
        createdAt: DateTime.now(),
      );

      final mockProfile = UserProfile(
        id: 'profile-id',
        userId: 'test-user-id',
        fullName: 'Test User',
        bio: 'Test bio',
        avatarUrl: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => mockUser),
            currentUserProfileProvider.overrideWith((ref) => AsyncValue.data(mockProfile)),
            currentUserStatsProvider.overrideWith((ref) => AsyncValue.data(null)),
          ],
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Tap the edit button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Clear the name field
      final nameField = find.byType(TextFormField).first;
      await tester.tap(nameField);
      await tester.enterText(nameField, '');

      // Try to save
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('Por favor ingresa tu nombre'), findsOneWidget);
    });

    testWidgets('Email validation works correctly', (WidgetTester tester) async {
      // Mock user and profile data
      final mockUser = User(
        id: 'test-user-id',
        email: 'test@example.com',
        fullName: 'Test User',
        createdAt: DateTime.now(),
      );

      final mockProfile = UserProfile(
        id: 'profile-id',
        userId: 'test-user-id',
        fullName: 'Test User',
        bio: 'Test bio',
        avatarUrl: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => mockUser),
            currentUserProfileProvider.overrideWith((ref) => AsyncValue.data(mockProfile)),
            currentUserStatsProvider.overrideWith((ref) => AsyncValue.data(null)),
          ],
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Tap the edit button
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // Find email field (should be the second TextFormField)
      final emailField = find.byType(TextFormField).at(1);
      await tester.tap(emailField);
      await tester.enterText(emailField, 'invalid-email');

      // Try to save
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // Should show email validation error
      expect(find.text('Por favor ingresa un email válido'), findsOneWidget);
    });
  });
}