import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/presentation/widgets/star_rating_widgets.dart';

void main() {
  group('Star Rating Widgets Tests', () {
    testWidgets('StarRatingDisplay shows correct number of stars', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRatingDisplay(
              rating: 3,
              maxRating: 5,
            ),
          ),
        ),
      );

      // Should show 3 filled stars and 2 empty stars
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    });

    testWidgets('StarRatingInput calls onRatingChanged when tapped', (WidgetTester tester) async {
      int? ratingReceived;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRatingInput(
              onRatingChanged: (rating) {
                ratingReceived = rating;
              },
              initialRating: 0,
            ),
          ),
        ),
      );

      // Tap the third star
      await tester.tap(find.byIcon(Icons.star_border).at(2));
      await tester.pump();

      expect(ratingReceived, equals(3));
    });

    testWidgets('InteractiveStarRating shows rating labels', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStarRating(
              onRatingChanged: (rating) {},
              initialRating: 4,
              showLabels: true,
            ),
          ),
        ),
      );

      // Should show the rating label for 4 stars
      expect(find.text('Buena'), findsOneWidget);
    });

    testWidgets('InteractiveStarRating disables interaction when enabled=false', (WidgetTester tester) async {
      int? ratingReceived;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStarRating(
              onRatingChanged: (rating) {
                ratingReceived = rating;
              },
              initialRating: 2,
              enabled: false,
            ),
          ),
        ),
      );

      // Try to tap the fourth star
      await tester.tap(find.byIcon(Icons.star_border).first);
      await tester.pump();

      // Rating should not change when disabled
      expect(ratingReceived, isNull);
    });
  });

  group('Movie Rating Integration Tests', () {
    testWidgets('Widget structure test with Provider', (WidgetTester tester) async {
      // Basic structure test to ensure widgets can be created
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StarRatingDisplay(
                rating: 4,
                showValue: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(StarRatingDisplay), findsOneWidget);
      expect(find.text('4/5'), findsOneWidget);
    });
  });
}