import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/presentation/screens/movies/home_screen.dart';
import 'package:peliculas/presentation/providers/providers.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Home Screen Golden Tests', () {
    testWidgets('Home screen renders correctly in light theme', (WidgetTester tester) async {
      // Mock movie data for consistent golden test
      final mockMovies = [
        Movie(
          id: 1,
          title: 'Test Movie 1',
          overview: 'A test movie for golden tests',
          posterPath: '/test1.jpg',
          backdropPath: '/backdrop1.jpg',
          releaseDate: DateTime(2024, 1, 1),
          voteAverage: 8.5,
          genreIds: ['28', '12'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Test Movie 1',
          popularity: 100.0,
          video: false,
          voteCount: 1000,
        ),
        Movie(
          id: 2,
          title: 'Test Movie 2',
          overview: 'Another test movie for golden tests',
          posterPath: '/test2.jpg',
          backdropPath: '/backdrop2.jpg',
          releaseDate: DateTime(2024, 2, 1),
          voteAverage: 7.8,
          genreIds: ['35', '18'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Test Movie 2',
          popularity: 85.0,
          video: false,
          voteCount: 750,
        ),
      ];

      // Create a mock navigation shell
      final mockNavigationShell = MockStatefulNavigationShell();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override providers with mock data for consistent golden tests
            nowPlayingMoviesProvider.overrideWith((ref) => AsyncValue.data(mockMovies)),
            popularMoviesProvider.overrideWith((ref) => AsyncValue.data(mockMovies)),
            topRatedMoviesProvider.overrideWith((ref) => AsyncValue.data(mockMovies)),
            upcomingMoviesProvider.overrideWith((ref) => AsyncValue.data(mockMovies)),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: HomeScreen(navigationShell: mockNavigationShell),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Take golden test screenshot
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('golden_tests/home_screen_light.png'),
      );
    });

    testWidgets('Home screen renders correctly in dark theme', (WidgetTester tester) async {
      // Mock movie data for consistent golden test
      final mockMovies = [
        Movie(
          id: 1,
          title: 'Test Movie 1',
          overview: 'A test movie for golden tests',
          posterPath: '/test1.jpg',
          backdropPath: '/backdrop1.jpg',
          releaseDate: DateTime(2024, 1, 1),
          voteAverage: 8.5,
          genreIds: ['28', '12'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Test Movie 1',
          popularity: 100.0,
          video: false,
          voteCount: 1000,
        ),
        Movie(
          id: 2,
          title: 'Test Movie 2',
          overview: 'Another test movie for golden tests',
          posterPath: '/test2.jpg',
          backdropPath: '/backdrop2.jpg',
          releaseDate: DateTime(2024, 2, 1),
          voteAverage: 7.8,
          genreIds: ['35', '18'],
          adult: false,
          originalLanguage: 'en',
          originalTitle: 'Test Movie 2',
          popularity: 85.0,
          video: false,
          voteCount: 750,
        ),
      ];

      // Create a mock navigation shell
      final mockNavigationShell = MockStatefulNavigationShell();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override providers with mock data for consistent golden tests
            nowPlayingMoviesProvider.overrideWith((ref) => AsyncValue.data(mockMovies)),
            popularMoviesProvider.overrideWith((ref) => AsyncValue.data(mockMovies)),
            topRatedMoviesProvider.overrideWith((ref) => AsyncValue.data(mockMovies)),
            upcomingMoviesProvider.overrideWith((ref) => AsyncValue.data(mockMovies)),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: HomeScreen(navigationShell: mockNavigationShell),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Take golden test screenshot
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('golden_tests/home_screen_dark.png'),
      );
    });

    testWidgets('Home screen loading state renders correctly', (WidgetTester tester) async {
      // Create a mock navigation shell
      final mockNavigationShell = MockStatefulNavigationShell();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override providers with loading state
            nowPlayingMoviesProvider.overrideWith((ref) => const AsyncValue.loading()),
            popularMoviesProvider.overrideWith((ref) => const AsyncValue.loading()),
            topRatedMoviesProvider.overrideWith((ref) => const AsyncValue.loading()),
            upcomingMoviesProvider.overrideWith((ref) => const AsyncValue.loading()),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: HomeScreen(navigationShell: mockNavigationShell),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Take golden test screenshot
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('golden_tests/home_screen_loading.png'),
      );
    });

    testWidgets('Home screen error state renders correctly', (WidgetTester tester) async {
      // Create a mock navigation shell
      final mockNavigationShell = MockStatefulNavigationShell();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override providers with error state
            nowPlayingMoviesProvider.overrideWith((ref) => 
              AsyncValue.error('Test error', StackTrace.current)),
            popularMoviesProvider.overrideWith((ref) => 
              AsyncValue.error('Test error', StackTrace.current)),
            topRatedMoviesProvider.overrideWith((ref) => 
              AsyncValue.error('Test error', StackTrace.current)),
            upcomingMoviesProvider.overrideWith((ref) => 
              AsyncValue.error('Test error', StackTrace.current)),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: HomeScreen(navigationShell: mockNavigationShell),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Take golden test screenshot
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('golden_tests/home_screen_error.png'),
      );
    });
  });
}

// Mock StatefulNavigationShell for testing
class MockStatefulNavigationShell extends StatefulNavigationShell {
  MockStatefulNavigationShell()
      : super(
          branches: [],
          currentIndex: 0,
          shellRouteKey: const ValueKey('test'),
        );

  @override
  void goBranch(int index, {bool initialLocation = false}) {
    // Mock implementation
  }
}