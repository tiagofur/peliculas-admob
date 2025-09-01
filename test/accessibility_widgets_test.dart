import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/presentation/widgets/star_rating_widgets.dart';

void main() {
  group('Star Rating Widgets Accessibility Tests', () {
    testWidgets('StarRatingDisplay should have proper semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRatingDisplay(
              rating: 4,
              maxRating: 5,
              showValue: true,
            ),
          ),
        ),
      );

      // Check that semantics are present
      expect(find.bySemanticsLabel('Calificación 4 de 5 estrellas'), findsOneWidget);
      expect(find.bySemanticsLabel('Valor numérico: 4 de 5'), findsOneWidget);
    });

    testWidgets('StarRatingDisplay should handle zero rating semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRatingDisplay(
              rating: 0,
              maxRating: 5,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Sin calificación de 5 estrellas'), findsOneWidget);
    });

    testWidgets('InteractiveStarRating should have proper accessibility', (WidgetTester tester) async {
      int? ratingReceived;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStarRating(
              onRatingChanged: (rating) {
                ratingReceived = rating;
              },
              initialRating: 0,
              maxRating: 5,
            ),
          ),
        ),
      );

      // Check main semantic label
      expect(
        find.bySemanticsLabel(RegExp(r'Calificación interactiva.*Sin calificación.*Seleccione')),
        findsOneWidget,
      );

      // Check individual star buttons have proper labels
      expect(
        find.bySemanticsLabel(RegExp(r'Calificar con 3 de 5 estrellas')),
        findsOneWidget,
      );
    });

    testWidgets('InteractiveStarRating disabled should have proper semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStarRating(
              onRatingChanged: (rating) {},
              initialRating: 3,
              enabled: false,
            ),
          ),
        ),
      );

      // Check disabled semantics
      expect(
        find.bySemanticsLabel(RegExp(r'Calificación no editable.*Calificación 3 de 5')),
        findsOneWidget,
      );
    });

    testWidgets('InteractiveStarRating should have accessible touch targets', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveStarRating(
              onRatingChanged: (rating) {},
              initialRating: 0,
            ),
          ),
        ),
      );

      // Find the star buttons and verify they have minimum touch target size
      final starContainers = tester.widgetList(find.byType(Container))
          .where((widget) => widget is Container && 
              (widget as Container).constraints?.minWidth == 44.0)
          .toList();
      
      expect(starContainers.length, greaterThan(0));
    });

    testWidgets('StarRatingInput should have accessible button sizes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StarRatingInput(
              onRatingChanged: (rating) {},
              initialRating: 0,
            ),
          ),
        ),
      );

      // Verify the widget renders without error and has proper constraints
      expect(find.byType(StarRatingInput), findsOneWidget);
      
      // Check that touch targets meet accessibility requirements
      final containers = tester.widgetList(find.byType(Container))
          .where((widget) => widget is Container && 
              (widget as Container).constraints?.minWidth == 44.0)
          .toList();
      
      expect(containers.length, greaterThan(0));
    });

    testWidgets('Star icons should have semantic labels', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StarRatingDisplay(
              rating: 3,
              maxRating: 5,
            ),
          ),
        ),
      );

      // Check that individual stars have semantic labels
      expect(find.bySemanticsLabel('Estrella llena'), findsNWidgets(3));
      expect(find.bySemanticsLabel('Estrella vacía'), findsNWidgets(2));
    });

    testWidgets('Should handle large text scale properly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaleFactor: 1.5),
          child: MaterialApp(
            home: Scaffold(
              body: InteractiveStarRating(
                onRatingChanged: (rating) {},
                initialRating: 0,
              ),
            ),
          ),
        ),
      );

      // Verify the widget still renders correctly with large text
      expect(find.byType(InteractiveStarRating), findsOneWidget);
      
      // Touch targets should be scaled appropriately (but not exceed 1.5x)
      final containers = tester.widgetList(find.byType(Container))
          .where((widget) => widget is Container && 
              (widget as Container).constraints?.minWidth != null &&
              (widget as Container).constraints!.minWidth >= 44.0)
          .toList();
      
      expect(containers.length, greaterThan(0));
    });
  });
}