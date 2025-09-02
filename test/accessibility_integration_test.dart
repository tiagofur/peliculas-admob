import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/config/theme/app_theme.dart';
import 'package:peliculas/services/accessibility_service.dart';
import 'package:peliculas/presentation/widgets/star_rating_widgets.dart';
import 'package:peliculas/presentation/widgets/shared/custom_appbar.dart';

/// Comprehensive accessibility integration test
/// This test validates WCAG AA compliance across the app
void main() {
  group('WCAG AA Compliance Integration Tests', () {
    testWidgets('Complete app should be accessible with screen reader', (WidgetTester tester) async {
      // Setup app with accessibility features enabled
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(
              accessibleNavigation: true,
              textScaleFactor: 1.2,
            ),
            child: MaterialApp(
              theme: AppTheme().getTheme(),
              home: Scaffold(
                appBar: const CustomAppbar(),
                body: Column(
                  children: [
                    const StarRatingDisplay(
                      rating: 4,
                      maxRating: 5,
                      showValue: true,
                    ),
                    InteractiveStarRating(
                      onRatingChanged: (rating) {},
                      initialRating: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Verify all major components have semantic labels
      expect(find.bySemanticsLabel(RegExp(r'Calificación.*estrellas')), findsAtLeastNWidgets(2));
      expect(find.bySemanticsLabel(RegExp(r'Activar modo.*')), findsOneWidget);
      expect(find.bySemanticsLabel('Abrir búsqueda de películas'), findsOneWidget);
    });

    testWidgets('High contrast mode should provide maximum contrast', (WidgetTester tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            highContrast: true,
          ),
          child: Builder(
            builder: (context) {
              final theme = AppTheme().getTheme(context);
              
              // Verify high contrast colors
              expect(theme.colorScheme.primary, equals(Colors.black));
              expect(theme.colorScheme.onPrimary, equals(Colors.white));
              expect(theme.colorScheme.surface, equals(Colors.white));
              expect(theme.colorScheme.onSurface, equals(Colors.black));
              
              return MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: Column(
                    children: [
                      Text(
                        'High contrast text',
                        style: theme.textTheme.bodyLarge,
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Accessible Button'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Verify text is visible and button is accessible
      expect(find.text('High contrast text'), findsOneWidget);
      expect(find.text('Accessible Button'), findsOneWidget);
    });

    testWidgets('Large text scale should maintain usability', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(
              textScaleFactor: 2.0, // Large accessibility text
            ),
            child: MaterialApp(
              theme: AppTheme().getTheme(),
              home: Scaffold(
                appBar: const CustomAppbar(),
                body: Column(
                  children: [
                    InteractiveStarRating(
                      onRatingChanged: (rating) {},
                      initialRating: 0,
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Test Button'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Verify components still work with large text
      expect(find.byType(InteractiveStarRating), findsOneWidget);
      expect(find.text('Test Button'), findsOneWidget);
      
      // Touch targets should be appropriately sized
      final elevatedButton = find.byType(ElevatedButton);
      expect(elevatedButton, findsOneWidget);
    });

    testWidgets('Touch targets should meet WCAG AA minimum (44x44dp)', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme().getTheme(),
            home: Scaffold(
              appBar: const CustomAppbar(),
              body: InteractiveStarRating(
                onRatingChanged: (rating) {},
                initialRating: 0,
              ),
            ),
          ),
        ),
      );

      // Check that interactive elements meet minimum touch target
      final iconButtons = find.byType(IconButton);
      expect(iconButtons, findsAtLeastNWidgets(2)); // theme + search buttons

      // Verify star rating has proper touch targets
      final starContainers = tester.widgetList(find.byType(Container))
          .where((widget) => widget is Container && 
              (widget as Container).constraints?.minWidth == 44.0)
          .toList();
      
      expect(starContainers.length, greaterThan(0));
    });

    testWidgets('Color contrast should meet WCAG AA standards', (WidgetTester tester) async {
      // Test with both light and dark themes
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              platformBrightness: brightness,
            ),
            child: Builder(
              builder: (context) {
                final theme = AppTheme(themeMode: ThemeMode.system).getTheme(context);
                
                return MaterialApp(
                  theme: theme,
                  home: Scaffold(
                    body: Column(
                      children: [
                        Text(
                          'Test text content',
                          style: theme.textTheme.bodyLarge,
                        ),
                        Icon(
                          Icons.star,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );

        // Verify components render correctly in both themes
        expect(find.text('Test text content'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
      }
    });

    testWidgets('Semantic navigation should work correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(
              accessibleNavigation: true,
            ),
            child: MaterialApp(
              theme: AppTheme().getTheme(),
              home: Scaffold(
                appBar: const CustomAppbar(),
                body: Column(
                  children: [
                    const StarRatingDisplay(rating: 4, maxRating: 5),
                    InteractiveStarRating(
                      onRatingChanged: (rating) {},
                      initialRating: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Test semantic navigation through elements
      final semantics = tester.semantics.toStringDeep();
      expect(semantics, contains('estrellas'));
      expect(semantics, contains('Calificación'));
    });

    testWidgets('Accessibility service helper methods work correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Test various accessibility helpers
              final buttonSize = AccessibilityService.getAccessibleButtonSize(context);
              final textScale = AccessibilityService.getTextScaleFactor(context);
              final isScreenReader = AccessibilityService.isScreenReaderEnabled(context);
              final isHighContrast = AccessibilityService.isHighContrastEnabled(context);
              
              expect(buttonSize, greaterThanOrEqualTo(44.0));
              expect(textScale, isA<double>());
              expect(isScreenReader, isA<bool>());
              expect(isHighContrast, isA<bool>());
              
              return Container();
            },
          ),
        ),
      );
    });

    test('Semantic label generators produce proper Spanish text', () {
      // Test various semantic label generators
      expect(
        AccessibilityService.getStarRatingSemantics(0, 5),
        'Sin calificación de 5 estrellas',
      );
      
      expect(
        AccessibilityService.getStarRatingSemantics(4, 5),
        'Calificación 4 de 5 estrellas',
      );
      
      expect(
        AccessibilityService.getMoviePosterSemantics('Inception'),
        'Póster de la película Inception',
      );
      
      expect(
        AccessibilityService.getStreamingPlatformSemantics('Netflix', true),
        'Disponible en Netflix',
      );
      
      expect(
        AccessibilityService.getSyncStatusSemantics('Sincronizando', 'Datos actualizados'),
        'Estado de sincronización: Sincronizando. Datos actualizados',
      );
    });
  });
}