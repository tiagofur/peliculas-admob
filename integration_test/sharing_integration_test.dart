import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peliculas/main.dart' as app;
import 'package:peliculas/config/deep_links/deep_link_handler.dart';
import 'package:peliculas/services/share_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Movie Sharing Integration Tests', () {
    testWidgets('deep link URL generation works correctly', (WidgetTester tester) async {
      // Test URL generation
      final movieWebUrl = ShareService.generateMovieDeepLink(123);
      final movieAppUrl = ShareService.generateMovieAppDeepLink(123);
      final movieShareUrl = ShareService.generateMovieShareUrl(123);

      expect(movieWebUrl, equals('https://peliculas.creapolis.dev/movie/123'));
      expect(movieAppUrl, equals('peliculas://movie/123'));
      expect(movieShareUrl, equals('https://peliculas.creapolis.dev/movie/123/share'));
    });

    testWidgets('URL validation works correctly', (WidgetTester tester) async {
      // Test URL validation
      expect(ShareService.isValidShareableUrl('https://peliculas.creapolis.dev/movie/123'), isTrue);
      expect(ShareService.isValidShareableUrl('https://example.com/movie/123'), isFalse);
      expect(DeepLinkHandler.isValidDeepLink('peliculas://movie/123'), isTrue);
      expect(DeepLinkHandler.isValidDeepLink('https://example.com'), isFalse);
    });

    testWidgets('movie ID extraction works correctly', (WidgetTester tester) async {
      // Test movie ID extraction
      expect(ShareService.extractMovieIdFromUrl('https://peliculas.creapolis.dev/movie/123'), equals(123));
      expect(ShareService.extractMovieIdFromUrl('https://peliculas.creapolis.dev/movie/456/share'), equals(456));
      expect(ShareService.extractMovieIdFromUrl('invalid-url'), isNull);
    });

    testWidgets('app navigation works with movie routes', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify app loads correctly
      expect(find.byType(MaterialApp), findsOneWidget);
      
      // Note: In a real integration test, you would navigate to a specific movie
      // and test the share button functionality, but since we don't have
      // a test environment with actual movie data, we're keeping this simple
    });

    testWidgets('share URL formats are consistent', (WidgetTester tester) async {
      const movieId = 12345;
      const listId = 'test-list-123';
      const recType = 'category';
      const recId = 'action';

      // Test movie URLs
      final movieWebUrl = ShareService.generateMovieDeepLink(movieId);
      final movieAppUrl = ShareService.generateMovieAppDeepLink(movieId);
      final movieShareUrl = ShareService.generateMovieShareUrl(movieId);

      expect(movieWebUrl, contains('/movie/$movieId'));
      expect(movieAppUrl, contains('movie/$movieId'));
      expect(movieShareUrl, contains('/movie/$movieId/share'));

      // Test list URLs
      final listWebUrl = ShareService.generateListDeepLink(listId);
      final listAppUrl = ShareService.generateListAppDeepLink(listId);
      final listShareUrl = ShareService.generateListShareUrl(listId);

      expect(listWebUrl, contains('/list/$listId'));
      expect(listAppUrl, contains('list/$listId'));
      expect(listShareUrl, contains('/list/$listId/share'));

      // Test recommendation URLs
      final recWebUrl = ShareService.generateRecommendationDeepLink(recType, recId);
      final recAppUrl = ShareService.generateRecommendationAppDeepLink(recType, recId);
      final recShareUrl = ShareService.generateRecommendationShareUrl(recType, recId);

      expect(recWebUrl, contains('/recommendations/$recType/$recId'));
      expect(recAppUrl, contains('recommendations/$recType/$recId'));
      expect(recShareUrl, contains('/recommendations/$recType/$recId/share'));
    });
  });
}