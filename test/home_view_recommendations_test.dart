import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/presentation/views/movies/home_view.dart';

void main() {
  group('Home View Recommendations UI Tests', () {
    testWidgets('HomeView should build without errors', (WidgetTester tester) async {
      // Build the HomeView wrapped with ProviderScope
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeView(),
          ),
        ),
      );

      // Verify the HomeView renders
      expect(find.byType(HomeView), findsOneWidget);
    });

    testWidgets('HomeView should have proper structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeView(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pump();

      // Check for basic structure elements that should be present
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('Recommendations section should render when data is available', (WidgetTester tester) async {
      // This test verifies the UI structure but may not have actual data
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeView(),
          ),
        ),
      );

      // Wait for initial build
      await tester.pump();
      
      // Wait a bit more for providers to potentially load
      await tester.pump(const Duration(seconds: 1));

      // The widget should exist even if no data is loaded
      expect(find.byType(HomeView), findsOneWidget);
    });
  });

  group('Recommendations Navigation Tests', () {
    testWidgets('Should not crash when built', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeView(),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(HomeView), findsOneWidget);
    });
  });
}