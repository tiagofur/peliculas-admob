import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Simple widget test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Hello World'),
        ),
      ),
    );

    // Verify that our widget displays the text.
    expect(find.text('Hello World'), findsOneWidget);
  });
}
