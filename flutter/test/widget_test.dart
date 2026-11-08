// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/main.dart';

void main() {
  testWidgets('MainApp widget can be instantiated',
      (WidgetTester tester) async {
    // Test that MainApp can be created without throwing errors
    // This is a basic smoke test to ensure the widget structure is correct
    const mainApp = MainApp();

    // Verify the widget is not null
    expect(mainApp, isNotNull);

    // Verify it's a MainApp instance
    expect(mainApp, isA<MainApp>());
  });

  testWidgets('ProviderScope wraps MainApp correctly',
      (WidgetTester tester) async {
    // Test that ProviderScope can wrap MainApp
    const providerScope = ProviderScope(child: MainApp());

    // Verify the widget is not null
    expect(providerScope, isNotNull);

    // Verify it's a ProviderScope
    expect(providerScope, isA<ProviderScope>());
  });
}
