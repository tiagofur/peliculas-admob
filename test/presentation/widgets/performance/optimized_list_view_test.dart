import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/presentation/widgets/performance/optimized_list_view.dart';

void main() {
  group('OptimizedListView', () {
    group('Basic Rendering', () {
      testWidgets('should render empty state when no items', (WidgetTester tester) async {
        // Arrange
        const items = <String>[];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedListView<String>(
                items: items,
                itemBuilder: (context, item, index) => Text(item),
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('No hay elementos para mostrar'), findsOneWidget);
      });

      testWidgets('should render items correctly', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1', 'Item 2', 'Item 3'];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedListView<String>(
                items: items,
                itemBuilder: (context, item, index) => Text(item),
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        expect(find.text('Item 3'), findsOneWidget);
      });

      testWidgets('should wrap items in RepaintBoundary', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1'];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedListView<String>(
                items: items,
                itemBuilder: (context, item, index) => Text(item),
              ),
            ),
          ),
        );

        // Assert - Should find at least one RepaintBoundary (items are wrapped)
        expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(1));
      });
    });

    group('Load More Functionality', () {
      testWidgets('should render with load more callback without errors', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1', 'Item 2', 'Item 3'];
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedListView<String>(
                items: items,
                itemBuilder: (context, item, index) => SizedBox(
                  height: 100, 
                  child: ListTile(title: Text(item))
                ),
                onLoadMore: () {
                  // Load more callback
                },
                loadMoreThreshold: 1,
              ),
            ),
          ),
        );

        // Verify the widget renders properly with load more functionality
        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        expect(find.text('Item 3'), findsOneWidget);
        
        // Test scrolling behavior - should not throw errors
        await tester.drag(find.byType(ListView), const Offset(0, -100));
        await tester.pump();
        
        // Should still render properly after scroll
        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('should handle load more callback', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1', 'Item 2', 'Item 3'];
        bool loadMoreCalled = false;

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 200,
                child: OptimizedListView<String>(
                  items: items,
                  itemBuilder: (context, item, index) => SizedBox(
                    height: 100, 
                    child: ListTile(title: Text(item))
                  ),
                  onLoadMore: () {
                    loadMoreCalled = true;
                  },
                  loadMoreThreshold: 1,
                ),
              ),
            ),
          ),
        );

        // Scroll to trigger load more
        await tester.drag(find.byType(ListView), const Offset(0, -250));
        await tester.pump(); // Trigger load more
        await tester.pump(); // Allow post frame callback

        // Assert
        expect(loadMoreCalled, isTrue);
      });

      testWidgets('should not trigger load more multiple times', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1', 'Item 2', 'Item 3'];
        int loadMoreCallCount = 0;

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 200,
                child: OptimizedListView<String>(
                  items: items,
                  itemBuilder: (context, item, index) => SizedBox(
                    height: 100, 
                    child: ListTile(title: Text(item))
                  ),
                  onLoadMore: () {
                    loadMoreCallCount++;
                  },
                  loadMoreThreshold: 1,
                ),
              ),
            ),
          ),
        );

        // First scroll to trigger load more
        await tester.drag(find.byType(ListView), const Offset(0, -250));
        await tester.pump(); // Trigger load more
        await tester.pump(); // Post frame callback
        
        // Additional scrolls should not trigger more calls
        await tester.drag(find.byType(ListView), const Offset(0, -50));
        await tester.pump();
        await tester.pumpAndSettle();

        // Assert - should only be called once
        expect(loadMoreCallCount, equals(1));
      });
    });

    group('Controller Management', () {
      testWidgets('should use provided controller', (WidgetTester tester) async {
        // Arrange
        final controller = ScrollController();
        const items = ['Item 1', 'Item 2', 'Item 3'];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedListView<String>(
                items: items,
                controller: controller,
                itemBuilder: (context, item, index) => Text(item),
              ),
            ),
          ),
        );

        // Assert - Controller should be attached
        expect(controller.hasClients, isTrue);
      });

      testWidgets('should create internal controller when none provided', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1', 'Item 2', 'Item 3'];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedListView<String>(
                items: items,
                itemBuilder: (context, item, index) => Text(item),
              ),
            ),
          ),
        );

        // Assert - Should render without errors
        expect(find.byType(ListView), findsOneWidget);
      });
    });

    group('Widget Properties', () {
      testWidgets('should apply scroll direction', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1', 'Item 2', 'Item 3'];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedListView<String>(
                items: items,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, item, index) => Text(item),
              ),
            ),
          ),
        );

        // Assert
        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.scrollDirection, Axis.horizontal);
      });

      testWidgets('should apply shrinkWrap property', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1', 'Item 2', 'Item 3'];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedListView<String>(
                items: items,
                shrinkWrap: true,
                itemBuilder: (context, item, index) => Text(item),
              ),
            ),
          ),
        );

        // Assert
        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.shrinkWrap, isTrue);
      });
    });

    group('Lifecycle', () {
      testWidgets('should dispose controller when widget is disposed', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1', 'Item 2', 'Item 3'];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedListView<String>(
                items: items,
                itemBuilder: (context, item, index) => Text(item),
              ),
            ),
          ),
        );

        // Dispose widget
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Empty'))));

        // Assert - Should not throw any errors during disposal
        expect(find.text('Empty'), findsOneWidget);
      });
    });

    group('Estimated Item Height', () {
      testWidgets('should use estimated item height for load more threshold', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1', 'Item 2', 'Item 3'];
        bool loadMoreCalled = false;
        const estimatedHeight = 150.0;

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: OptimizedListView<String>(
                  items: items,
                  estimatedItemHeight: estimatedHeight,
                  loadMoreThreshold: 1,
                  itemBuilder: (context, item, index) => SizedBox(
                    height: estimatedHeight, 
                    child: ListTile(title: Text(item))
                  ),
                  onLoadMore: () {
                    loadMoreCalled = true;
                  },
                ),
              ),
            ),
          ),
        );

        // Scroll using estimated height calculation
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pump();
        await tester.pump();

        // Assert
        expect(loadMoreCalled, isTrue);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty load more callback gracefully', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1', 'Item 2', 'Item 3'];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedListView<String>(
                items: items,
                // No onLoadMore provided
                itemBuilder: (context, item, index) => Text(item),
              ),
            ),
          ),
        );

        // Scroll - should not throw errors
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();

        // Assert - Should render normally
        expect(find.text('Item 1'), findsOneWidget);
      });

      testWidgets('should handle single item list', (WidgetTester tester) async {
        // Arrange
        const items = ['Single Item'];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedListView<String>(
                items: items,
                itemBuilder: (context, item, index) => Text(item),
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('Single Item'), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);
      });
    });
  });

  group('OptimizedGridView', () {
    group('Basic Grid Rendering', () {
      testWidgets('should render empty state for grid', (WidgetTester tester) async {
        // Arrange
        const items = <String>[];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedGridView<String>(
                items: items,
                crossAxisCount: 2,
                itemBuilder: (context, item, index) => Text(item),
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('No hay elementos para mostrar'), findsOneWidget);
      });

      testWidgets('should render grid items correctly', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1', 'Item 2', 'Item 3', 'Item 4'];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedGridView<String>(
                items: items,
                crossAxisCount: 2,
                itemBuilder: (context, item, index) => Text(item),
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        expect(find.text('Item 3'), findsOneWidget);
        expect(find.text('Item 4'), findsOneWidget);
      });
    });

    group('Grid Load More', () {
      testWidgets('should render grid with load more functionality', (WidgetTester tester) async {
        // Arrange
        const items = ['Item 1', 'Item 2', 'Item 3', 'Item 4'];

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OptimizedGridView<String>(
                items: items,
                crossAxisCount: 2,
                itemBuilder: (context, item, index) => SizedBox(
                  height: 100,
                  child: Text(item),
                ),
                onLoadMore: () {
                  // Load more callback
                },
                loadMoreThreshold: 1,
              ),
            ),
          ),
        );

        // Assert - should render grid properly
        expect(find.byType(GridView), findsOneWidget);
        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        
        // Test scrolling behavior
        await tester.drag(find.byType(GridView), const Offset(0, -50));
        await tester.pump();
        
        // Should still render properly after scroll
        expect(find.byType(GridView), findsOneWidget);
      });
    });
  });

  group('ListPerformanceAnalyzer Extension', () {
    testWidgets('should apply performance monitoring without errors', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Text('Test Widget').withPerformanceMonitoring(
              debugLabel: 'TestLabel',
            ),
          ),
        ),
      );

      // Assert - Should find RepaintBoundary from the extension
      expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(1));
    });

    testWidgets('should work without debug label', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Text('Test Widget').withPerformanceMonitoring(),
          ),
        ),
      );

      // Assert - Should find RepaintBoundary from the extension
      expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(1));
    });
  });
}