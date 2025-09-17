import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/presentation/widgets/star_rating_widgets.dart';

void main() {
  group('Widget Golden Tests - Star Rating', () {
    testWidgets('StarRatingInput widget golden test - empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StarRatingInput(
                onRatingChanged: _mockRatingChanged,
                initialRating: 0,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(StarRatingInput),
        matchesGoldenFile('goldens/star_rating_empty.png'),
      );
    });

    testWidgets('StarRatingInput widget golden test - partial', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StarRatingInput(
                onRatingChanged: _mockRatingChanged,
                initialRating: 3.0,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(StarRatingInput),
        matchesGoldenFile('goldens/star_rating_partial.png'),
      );
    });

    testWidgets('StarRatingInput widget golden test - full', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StarRatingInput(
                onRatingChanged: _mockRatingChanged,
                initialRating: 5.0,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(StarRatingInput),
        matchesGoldenFile('goldens/star_rating_full.png'),
      );
    });

    testWidgets('StarRatingDisplay widget golden test - various ratings',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StarRatingDisplay(rating: 0),
                SizedBox(height: 10),
                StarRatingDisplay(rating: 2.5),
                SizedBox(height: 10),
                StarRatingDisplay(rating: 4.8),
                SizedBox(height: 10),
                StarRatingDisplay(rating: 10.0),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/star_rating_display_variants.png'),
      );
    });
  });

  // Note: GuestModeBanner tests removed due to Hive initialization requirements
  // These will be added in a separate test file with proper setup

  group('Widget Golden Tests - Theme Comparison', () {
    testWidgets('StarRating theme comparison golden test', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                // Light theme column
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Light Theme',
                            style: TextStyle(color: Colors.black)),
                        SizedBox(height: 20),
                        StarRatingInput(
                          onRatingChanged: _mockRatingChanged,
                          initialRating: 3.5,
                        ),
                        SizedBox(height: 10),
                        StarRatingDisplay(rating: 4.2),
                      ],
                    ),
                  ),
                ),
                // Dark theme column
                Expanded(
                  child: Container(
                    color: Colors.grey[900],
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Dark Theme',
                            style: TextStyle(color: Colors.white)),
                        SizedBox(height: 20),
                        StarRatingInput(
                          onRatingChanged: _mockRatingChanged,
                          initialRating: 3.5,
                          color: Colors.amber,
                        ),
                        SizedBox(height: 10),
                        StarRatingDisplay(rating: 4.2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/star_rating_theme_comparison.png'),
      );
    });
  });

  group('Widget Golden Tests - Different Sizes', () {
    testWidgets('StarRating size variants golden test', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Small (16px)'),
                StarRatingInput(
                  onRatingChanged: _mockRatingChanged,
                  initialRating: 3.0,
                  size: 16.0,
                ),
                SizedBox(height: 20),
                Text('Default (32px)'),
                StarRatingInput(
                  onRatingChanged: _mockRatingChanged,
                  initialRating: 3.0,
                  size: 32.0,
                ),
                SizedBox(height: 20),
                Text('Large (48px)'),
                StarRatingInput(
                  onRatingChanged: _mockRatingChanged,
                  initialRating: 3.0,
                  size: 48.0,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/star_rating_size_variants.png'),
      );
    });
  });

  group('Widget Golden Tests - Accessibility', () {
    testWidgets('StarRating with large text scale golden test', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Large Text Scale (2.0x)'),
                  SizedBox(height: 20),
                  StarRatingInput(
                    onRatingChanged: _mockRatingChanged,
                    initialRating: 4.0,
                  ),
                  SizedBox(height: 20),
                  StarRatingDisplay(rating: 7.5),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/star_rating_large_text_scale.png'),
      );
    });

    testWidgets('High contrast theme golden test', (tester) async {
      final highContrastTheme = ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.yellow,
          surface: Colors.black,
          onSurface: Colors.white,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: highContrastTheme,
          home: const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('High Contrast Theme'),
                  SizedBox(height: 20),
                  StarRatingInput(
                    onRatingChanged: _mockRatingChanged,
                    initialRating: 3.0,
                    color: Colors.yellow,
                  ),
                  SizedBox(height: 20),
                  StarRatingDisplay(rating: 4.5),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/high_contrast_theme.png'),
      );
    });
  });
}

void _mockRatingChanged(double rating) {
  // Mock function for testing
}
