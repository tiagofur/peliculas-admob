import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/services/accessibility_service.dart';

void main() {
  group('AccessibilityService Tests', () {
    testWidgets('should detect screen reader enabled', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Test screen reader detection
              final isScreenReaderEnabled = AccessibilityService.isScreenReaderEnabled(context);
              expect(isScreenReaderEnabled, isA<bool>());
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should detect high contrast mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Test high contrast detection
              final isHighContrast = AccessibilityService.isHighContrastEnabled(context);
              expect(isHighContrast, isA<bool>());
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should get text scale factor', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Test text scale factor
              final textScale = AccessibilityService.getTextScaleFactor(context);
              expect(textScale, isA<double>());
              expect(textScale, greaterThan(0));
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should detect large text scale', (WidgetTester tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaleFactor: 1.5),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final isLargeText = AccessibilityService.isLargeTextScale(context);
                expect(isLargeText, isTrue);
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('should provide accessible button size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final buttonSize = AccessibilityService.getAccessibleButtonSize(context);
              expect(buttonSize, greaterThanOrEqualTo(44.0)); // WCAG AA minimum
              return Container();
            },
          ),
        ),
      );
    });

    test('should generate star rating semantics', () {
      expect(
        AccessibilityService.getStarRatingSemantics(0, 5),
        'Sin calificación de 5 estrellas',
      );
      expect(
        AccessibilityService.getStarRatingSemantics(4, 5),
        'Calificación 4 de 5 estrellas',
      );
    });

    test('should generate movie poster semantics', () {
      expect(
        AccessibilityService.getMoviePosterSemantics('Avatar'),
        'Póster de la película Avatar',
      );
    });

    test('should generate streaming platform semantics', () {
      expect(
        AccessibilityService.getStreamingPlatformSemantics('Netflix', true),
        'Disponible en Netflix',
      );
      expect(
        AccessibilityService.getStreamingPlatformSemantics('Disney+', false),
        'No disponible en Disney+',
      );
    });

    test('should generate sync status semantics', () {
      expect(
        AccessibilityService.getSyncStatusSemantics('Sincronizando', 'Actualizando datos'),
        'Estado de sincronización: Sincronizando. Actualizando datos',
      );
      expect(
        AccessibilityService.getSyncStatusSemantics('Completado', null),
        'Estado de sincronización: Completado',
      );
    });

    testWidgets('should recommend enhanced visuals for accessibility needs', (WidgetTester tester) async {
      // Test with high contrast
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final shouldUseEnhanced = AccessibilityService.shouldUseEnhancedVisuals(context);
                expect(shouldUseEnhanced, isTrue);
                return Container();
              },
            ),
          ),
        ),
      );

      // Test with large text scale
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaleFactor: 1.5),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final shouldUseEnhanced = AccessibilityService.shouldUseEnhancedVisuals(context);
                expect(shouldUseEnhanced, isTrue);
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('should calculate accessible spacing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaleFactor: 1.2),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final spacing = AccessibilityService.getAccessibleSpacing(context, 10.0);
                expect(spacing, greaterThanOrEqualTo(10.0));
                expect(spacing, lessThanOrEqualTo(13.0)); // clamped to 1.3
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('should provide accessible text color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final textColor = AccessibilityService.getAccessibleTextColor(
                context,
                Colors.white,
              );
              expect(textColor, isA<Color>());
              return Container();
            },
          ),
        ),
      );
    });
  });
}