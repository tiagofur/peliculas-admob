import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lib/presentation/providers/providers.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: TestScreen(),
    );
  }
}

class TestScreen extends ConsumerWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendationsAsync = ref.watch(personalizedRecommendationsProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text('Test Recommendations')),
      body: recommendationsAsync.when(
        data: (recommendations) => Text('Recommendations loaded: ${recommendations.length}'),
        loading: () => CircularProgressIndicator(),
        error: (error, stack) => Text('Error: $error\nStack: $stack'),
      ),
    );
  }
}