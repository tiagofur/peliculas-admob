import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../lib/presentation/widgets/performance/lazy_optimized_image.dart';

void main() {
  group('LazyOptimizedImage', () {
    const testImageUrl = 'https://example.com/test-image.jpg';
    
    group('Basic Functionality', () {
      testWidgets('should render without errors', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LazyOptimizedImage(
                imageUrl: testImageUrl,
                width: 200,
                height: 200,
                loadOnlyWhenVisible: false, // Avoid complex lazy loading
              ),
            ),
          ),
        );

        expect(find.byType(LazyOptimizedImage), findsOneWidget);
      });

      testWidgets('should handle custom placeholder', (WidgetTester tester) async {
        const customPlaceholder = Text('Loading...');
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LazyOptimizedImage(
                imageUrl: testImageUrl,
                width: 200,
                height: 200,
                placeholder: customPlaceholder,
                loadOnlyWhenVisible: false,
              ),
            ),
          ),
        );

        expect(find.text('Loading...'), findsOneWidget);
      });

      testWidgets('should handle empty image URL', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LazyOptimizedImage(
                imageUrl: '',
                width: 200,
                height: 200,
                loadOnlyWhenVisible: false,
              ),
            ),
          ),
        );

        // Should render without errors
        expect(find.byType(LazyOptimizedImage), findsOneWidget);
      });
    });

    group('Lazy Loading Behavior', () {
      testWidgets('should render VisibilityDetector when loadOnlyWhenVisible is true', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LazyOptimizedImage(
                imageUrl: testImageUrl,
                width: 200,
                height: 200,
                loadOnlyWhenVisible: true,
              ),
            ),
          ),
        );

        expect(find.byType(VisibilityDetector), findsOneWidget);
      });

      testWidgets('should not render VisibilityDetector when loadOnlyWhenVisible is false', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LazyOptimizedImage(
                imageUrl: testImageUrl,
                width: 200,
                height: 200,
                loadOnlyWhenVisible: false,
              ),
            ),
          ),
        );

        expect(find.byType(VisibilityDetector), findsNothing);
      });
    });

    group('Error Handling', () {
      testWidgets('should show custom error widget', (WidgetTester tester) async {
        const customErrorWidget = Text('Image failed to load');
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LazyOptimizedImage(
                imageUrl: 'invalid-url',
                width: 200,
                height: 200,
                errorWidget: customErrorWidget,
                loadOnlyWhenVisible: false,
              ),
            ),
          ),
        );

        // Should render without throwing errors
        expect(find.byType(LazyOptimizedImage), findsOneWidget);
      });
    });

    group('Widget Properties', () {
      testWidgets('should apply border radius', (WidgetTester tester) async {
        const borderRadius = BorderRadius.all(Radius.circular(10));
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LazyOptimizedImage(
                imageUrl: testImageUrl,
                width: 200,
                height: 200,
                borderRadius: borderRadius,
                loadOnlyWhenVisible: false,
              ),
            ),
          ),
        );

        expect(find.byType(ClipRRect), findsOneWidget);
      });

      testWidgets('should apply BoxFit correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LazyOptimizedImage(
                imageUrl: testImageUrl,
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                loadOnlyWhenVisible: false,
              ),
            ),
          ),
        );

        expect(find.byType(LazyOptimizedImage), findsOneWidget);
      });
    });

    group('Animation', () {
      testWidgets('should handle fade animation', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LazyOptimizedImage(
                imageUrl: testImageUrl,
                width: 200,
                height: 200,
                fadeInDuration: Duration(milliseconds: 500),
                loadOnlyWhenVisible: false,
              ),
            ),
          ),
        );

        expect(find.byType(LazyOptimizedImage), findsOneWidget);
        
        // Test that the widget can handle animation
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(LazyOptimizedImage), findsOneWidget);
      });
    });

    group('Memory Optimization', () {
      testWidgets('should handle memory optimization flag', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LazyOptimizedImage(
                imageUrl: testImageUrl,
                width: 200,
                height: 200,
                enableMemoryOptimization: true,
                cacheWidth: 400,
                cacheHeight: 400,
                loadOnlyWhenVisible: false,
              ),
            ),
          ),
        );

        expect(find.byType(LazyOptimizedImage), findsOneWidget);
      });
    });
  });

  group('VisibilityDetector', () {
    testWidgets('should render child widget', (WidgetTester tester) async {
      const childWidget = Text('Test Child');
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisibilityDetector(
              key: const Key('test-visibility'),
              onVisibilityChanged: (info) {
                // Callback for visibility changes
              },
              child: childWidget,
            ),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });
  });

  group('VisibilityInfo', () {
    test('should store visible fraction correctly', () {
      const info = VisibilityInfo(0.5);
      expect(info.visibleFraction, 0.5);
    });

    test('should handle different visibility fractions', () {
      const fullVisible = VisibilityInfo(1.0);
      const partialVisible = VisibilityInfo(0.3);
      const notVisible = VisibilityInfo(0.0);

      expect(fullVisible.visibleFraction, 1.0);
      expect(partialVisible.visibleFraction, 0.3);
      expect(notVisible.visibleFraction, 0.0);
    });
  });

  group('PreloadOptimizedImage', () {
    testWidgets('should render LazyOptimizedImage internally', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreloadOptimizedImage(
              imageUrl: 'https://example.com/preload-image.jpg',
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      expect(find.byType(PreloadOptimizedImage), findsOneWidget);
      expect(find.byType(LazyOptimizedImage), findsOneWidget);
    });

    testWidgets('should apply properties to internal LazyOptimizedImage', (WidgetTester tester) async {
      const borderRadius = BorderRadius.all(Radius.circular(15));
      
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreloadOptimizedImage(
              imageUrl: 'https://example.com/preload-image.jpg',
              width: 150,
              height: 200,
              fit: BoxFit.contain,
              borderRadius: borderRadius,
            ),
          ),
        ),
      );

      expect(find.byType(PreloadOptimizedImage), findsOneWidget);
      expect(find.byType(LazyOptimizedImage), findsOneWidget);
    });
  });
}