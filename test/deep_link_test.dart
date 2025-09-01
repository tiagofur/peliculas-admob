import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/config/deep_links/deep_link_handler.dart';
import 'package:peliculas/services/share_service.dart';

void main() {
  group('Deep Link Functionality Tests', () {
    test('should generate correct movie deep links', () {
      // Test web URL generation
      final webUrl = ShareService.generateMovieDeepLink(12345);
      expect(webUrl, equals('https://peliculas.creapolis.dev/movie/12345'));

      // Test app scheme URL generation
      final appUrl = ShareService.generateMovieAppDeepLink(12345);
      expect(appUrl, equals('peliculas://movie/12345'));
    });

    test('should generate correct movie share URLs', () {
      final shareUrl = ShareService.generateMovieShareUrl(12345);
      expect(shareUrl, equals('https://peliculas.creapolis.dev/movie/12345/share'));
    });

    test('should generate correct list deep links', () {
      // Test web URL generation
      final webUrl = ShareService.generateListDeepLink('list123');
      expect(webUrl, equals('https://peliculas.creapolis.dev/list/list123'));

      // Test app scheme URL generation
      final appUrl = ShareService.generateListAppDeepLink('list123');
      expect(appUrl, equals('peliculas://list/list123'));
    });

    test('should generate correct recommendation deep links', () {
      // Test web URL generation
      final webUrl = ShareService.generateRecommendationDeepLink('category', 'action');
      expect(webUrl, equals('https://peliculas.creapolis.dev/recommendations/category/action'));

      // Test app scheme URL generation
      final appUrl = ShareService.generateRecommendationAppDeepLink('category', 'action');
      expect(appUrl, equals('peliculas://recommendations/category/action'));
    });

    test('should validate deep link URLs correctly', () {
      // Valid deep links
      expect(DeepLinkHandler.isValidDeepLink('peliculas://movie/123'), isTrue);
      expect(DeepLinkHandler.isValidDeepLink('peliculas://list/abc'), isTrue);
      
      // Invalid deep links
      expect(DeepLinkHandler.isValidDeepLink('https://example.com'), isFalse);
      expect(DeepLinkHandler.isValidDeepLink('invalid://url'), isFalse);
    });

    test('should identify share URLs correctly', () {
      // Valid share URLs
      expect(DeepLinkHandler.isShareUrl('https://peliculas.creapolis.dev/movie/123/share'), isTrue);
      expect(DeepLinkHandler.isShareUrl('https://peliculas.creapolis.dev/list/abc/share'), isTrue);
      
      // Non-share URLs
      expect(DeepLinkHandler.isShareUrl('https://peliculas.creapolis.dev/movie/123'), isFalse);
      expect(DeepLinkHandler.isShareUrl('https://example.com'), isFalse);
    });

    test('should validate shareable URLs correctly', () {
      // Valid shareable URLs
      expect(ShareService.isValidShareableUrl('https://peliculas.creapolis.dev/movie/123/share'), isTrue);
      expect(ShareService.isValidShareableUrl('https://peliculas.creapolis.dev/movie/123'), isTrue);
      expect(ShareService.isValidShareableUrl('https://peliculas.creapolis.dev/list/abc'), isTrue);
      
      // Invalid shareable URLs
      expect(ShareService.isValidShareableUrl('https://example.com/movie/123'), isFalse);
      expect(ShareService.isValidShareableUrl('invalid-url'), isFalse);
    });

    test('should extract movie ID from URLs correctly', () {
      // Valid movie URLs
      expect(ShareService.extractMovieIdFromUrl('https://peliculas.creapolis.dev/movie/123'), equals(123));
      expect(ShareService.extractMovieIdFromUrl('https://peliculas.creapolis.dev/movie/456/share'), equals(456));
      
      // Invalid movie URLs
      expect(ShareService.extractMovieIdFromUrl('https://peliculas.creapolis.dev/list/123'), isNull);
      expect(ShareService.extractMovieIdFromUrl('invalid-url'), isNull);
    });

    test('should extract list ID from URLs correctly', () {
      // Valid list URLs
      expect(ShareService.extractListIdFromUrl('https://peliculas.creapolis.dev/list/abc123'), equals('abc123'));
      expect(ShareService.extractListIdFromUrl('https://peliculas.creapolis.dev/list/xyz/share'), equals('xyz'));
      
      // Invalid list URLs
      expect(ShareService.extractListIdFromUrl('https://peliculas.creapolis.dev/movie/123'), isNull);
      expect(ShareService.extractListIdFromUrl('invalid-url'), isNull);
    });

    test('should generate app deep links with correct format', () {
      final movieDeepLink = DeepLinkHandler.generateAppDeepLink(
        contentType: 'movie',
        contentId: '123',
        action: 'view',
        parameters: {'source': 'share'},
      );
      
      expect(movieDeepLink, equals('peliculas://movie/123/view?source=share'));
    });
  });
}