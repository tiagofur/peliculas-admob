/// Task 2.5: Golden tests for skeleton loader widgets
///
/// These tests verify that skeleton loaders render correctly
/// and consistently across light/dark themes.
///
/// **Note**: Shimmer animations are continuous, so we capture them at initial state.
///
/// **To update goldens**: `flutter test test/golden_tests/ --update-goldens`
/// **To run tests**: `flutter test test/golden_tests/`
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/presentation/widgets/skeletons/skeletons.dart';

void main() {
  group('Skeleton Loaders Golden Tests', () {
    testWidgets('MovieCardSkeleton - Light Theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: Center(
              child: MovieCardSkeleton(),
            ),
          ),
        ),
      );

      // Pump once to capture initial shimmer state
      await tester.pump();

      await expectLater(
        find.byType(MovieCardSkeleton),
        matchesGoldenFile('goldens/movie_card_skeleton_light.png'),
      );
    });

    testWidgets('MovieCardSkeleton - Dark Theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: Center(
              child: MovieCardSkeleton(),
            ),
          ),
        ),
      );

      // Pump once to capture initial shimmer state
      await tester.pump();

      await expectLater(
        find.byType(MovieCardSkeleton),
        matchesGoldenFile('goldens/movie_card_skeleton_dark.png'),
      );
    });

    testWidgets('MovieHorizontalListSkeleton - Light Theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: MovieHorizontalListSkeleton(itemCount: 3),
          ),
        ),
      );

      // Pump once to capture initial shimmer state
      await tester.pump();

      await expectLater(
        find.byType(MovieHorizontalListSkeleton),
        matchesGoldenFile('goldens/movie_horizontal_list_skeleton_light.png'),
      );
    });

    testWidgets('MovieHorizontalListSkeleton - Dark Theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: MovieHorizontalListSkeleton(itemCount: 3),
          ),
        ),
      );

      // Pump once to capture initial shimmer state
      await tester.pump();

      await expectLater(
        find.byType(MovieHorizontalListSkeleton),
        matchesGoldenFile('goldens/movie_horizontal_list_skeleton_dark.png'),
      );
    });

    testWidgets('MovieGridSkeleton - Light Theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: MovieGridSkeleton(itemCount: 4, crossAxisCount: 2),
          ),
        ),
      );

      // Pump once to capture initial shimmer state
      await tester.pump();

      await expectLater(
        find.byType(MovieGridSkeleton),
        matchesGoldenFile('goldens/movie_grid_skeleton_light.png'),
      );
    });

    testWidgets('MovieGridSkeleton - Dark Theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: MovieGridSkeleton(itemCount: 4, crossAxisCount: 2),
          ),
        ),
      );

      // Pump once to capture initial shimmer state
      await tester.pump();

      await expectLater(
        find.byType(MovieGridSkeleton),
        matchesGoldenFile('goldens/movie_grid_skeleton_dark.png'),
      );
    });

    testWidgets('MovieDetailsSkeleton - Light Theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: MovieDetailsSkeleton(),
          ),
        ),
      );

      // Pump once to capture initial shimmer state
      await tester.pump();

      await expectLater(
        find.byType(MovieDetailsSkeleton),
        matchesGoldenFile('goldens/movie_details_skeleton_light.png'),
      );
    });

    testWidgets('MovieDetailsSkeleton - Dark Theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: MovieDetailsSkeleton(),
          ),
        ),
      );

      // Pump once to capture initial shimmer state
      await tester.pump();

      await expectLater(
        find.byType(MovieDetailsSkeleton),
        matchesGoldenFile('goldens/movie_details_skeleton_dark.png'),
      );
    });

    testWidgets('MovieCardSkeleton - Custom Size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: Center(
              child: MovieCardSkeleton(
                width: 200,
                height: 350,
              ),
            ),
          ),
        ),
      );

      // Pump once to capture initial shimmer state
      await tester.pump();

      await expectLater(
        find.byType(MovieCardSkeleton),
        matchesGoldenFile('goldens/movie_card_skeleton_custom_size.png'),
      );
    });
  });
}
