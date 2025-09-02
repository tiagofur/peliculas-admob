import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/domain/entities/user.dart';
import 'package:peliculas/domain/entities/user_profile.dart';
import 'package:peliculas/domain/entities/user_stats.dart';
import 'package:peliculas/presentation/screens/profile/profile_screen.dart';
import 'package:peliculas/presentation/providers/auth_provider.dart';

void main() {
  group('Profile Screen Golden Tests', () {
    testWidgets('Profile screen with user data renders correctly in light theme', (WidgetTester tester) async {
      // Mock user data for consistent golden test
      final mockUser = User(
        id: 'test-user-123',
        email: 'test.user@example.com',
        fullName: 'Test User Golden',
        createdAt: DateTime(2023, 1, 15),
      );

      final mockProfile = UserProfile(
        id: 'profile-123',
        userId: 'test-user-123',
        fullName: 'Test User Golden',
        bio: 'Movie enthusiast and golden test subject. Love watching sci-fi and action movies.',
        avatarUrl: null,
        createdAt: DateTime(2023, 1, 15),
        updatedAt: DateTime(2024, 6, 1),
      );

      final mockStats = UserStats(
        id: 'stats-123',
        userId: 'test-user-123',
        moviesWatched: 127,
        favoritesCount: 23,
        listsCount: 8,
        averageRating: 4.2,
        totalMinutesWatched: 15420,
        lastActivity: DateTime(2024, 6, 1),
        createdAt: DateTime(2023, 1, 15),
        updatedAt: DateTime(2024, 6, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => mockUser),
            currentUserProfileProvider.overrideWith((ref) => AsyncValue.data(mockProfile)),
            currentUserStatsProvider.overrideWith((ref) => AsyncValue.data(mockStats)),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const ProfileScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Take golden test screenshot
      await expectLater(
        find.byType(ProfileScreen),
        matchesGoldenFile('golden_tests/profile_screen_light.png'),
      );
    });

    testWidgets('Profile screen with user data renders correctly in dark theme', (WidgetTester tester) async {
      // Mock user data for consistent golden test
      final mockUser = User(
        id: 'test-user-123',
        email: 'test.user@example.com',
        fullName: 'Test User Golden',
        createdAt: DateTime(2023, 1, 15),
      );

      final mockProfile = UserProfile(
        id: 'profile-123',
        userId: 'test-user-123',
        fullName: 'Test User Golden',
        bio: 'Movie enthusiast and golden test subject. Love watching sci-fi and action movies.',
        avatarUrl: null,
        createdAt: DateTime(2023, 1, 15),
        updatedAt: DateTime(2024, 6, 1),
      );

      final mockStats = UserStats(
        id: 'stats-123',
        userId: 'test-user-123',
        moviesWatched: 127,
        favoritesCount: 23,
        listsCount: 8,
        averageRating: 4.2,
        totalMinutesWatched: 15420,
        lastActivity: DateTime(2024, 6, 1),
        createdAt: DateTime(2023, 1, 15),
        updatedAt: DateTime(2024, 6, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => mockUser),
            currentUserProfileProvider.overrideWith((ref) => AsyncValue.data(mockProfile)),
            currentUserStatsProvider.overrideWith((ref) => AsyncValue.data(mockStats)),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const ProfileScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Take golden test screenshot
      await expectLater(
        find.byType(ProfileScreen),
        matchesGoldenFile('golden_tests/profile_screen_dark.png'),
      );
    });

    testWidgets('Profile screen loading state renders correctly', (WidgetTester tester) async {
      // Mock user but loading profile and stats
      final mockUser = User(
        id: 'test-user-123',
        email: 'test.user@example.com',
        fullName: 'Test User Golden',
        createdAt: DateTime(2023, 1, 15),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => mockUser),
            currentUserProfileProvider.overrideWith((ref) => const AsyncValue.loading()),
            currentUserStatsProvider.overrideWith((ref) => const AsyncValue.loading()),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const ProfileScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Take golden test screenshot
      await expectLater(
        find.byType(ProfileScreen),
        matchesGoldenFile('golden_tests/profile_screen_loading.png'),
      );
    });

    testWidgets('Profile screen unauthenticated state renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => null),
            currentUserProfileProvider.overrideWith((ref) => const AsyncValue.data(null)),
            currentUserStatsProvider.overrideWith((ref) => const AsyncValue.data(null)),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const ProfileScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Take golden test screenshot
      await expectLater(
        find.byType(ProfileScreen),
        matchesGoldenFile('golden_tests/profile_screen_unauthenticated.png'),
      );
    });
  });
}