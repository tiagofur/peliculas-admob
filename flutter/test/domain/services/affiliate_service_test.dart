import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/watch_provider.dart';
import 'package:peliculas/domain/services/affiliate_service.dart';

/// Regression: every provider must open its own platform.
/// Unknown-to-affiliates IDs used to fall back to netflix.com.
void main() {
  WatchProvider provider(int id, String name) => WatchProvider(
    providerId: id,
    providerName: name,
    logoPath: '/logo.png',
    displayPriority: 0,
  );

  group('AffiliateService.generateAffiliateLink', () {
    test('Max (1899) opens Max, not Netflix', () {
      final url = AffiliateService.generateAffiliateLink(
        provider(1899, 'HBO Max'),
      );
      expect(url, contains('hbomax.com'));
      expect(url, isNot(contains('netflix.com')));
    });

    test('Claro video opens its own site, not Netflix', () {
      final url = AffiliateService.generateAffiliateLink(
        provider(167, 'Claro video'),
      );
      expect(url, contains('clarovideo.com'));
      expect(url, isNot(contains('netflix.com')));
    });

    test('Prime Video keeps working', () {
      final url = AffiliateService.generateAffiliateLink(
        provider(119, 'Amazon Prime Video'),
      );
      expect(url, contains('primevideo.com'));
    });

    test('Netflix keeps working', () {
      final url = AffiliateService.generateAffiliateLink(
        provider(8, 'Netflix'),
      );
      expect(url, contains('netflix.com'));
    });

    test('unknown provider never opens a wrong platform', () {
      final url = AffiliateService.generateAffiliateLink(
        provider(999999, 'Some New Service'),
      );
      expect(url, isNot(contains('netflix.com')));
      expect(url, isNot(contains('provider.com')));
    });
  });

  group('AffiliateService.hasAffiliateSupport', () {
    test('Max channel variant resolves like Max', () {
      expect(AffiliateService.hasAffiliateSupport(1899), isFalse);
      expect(AffiliateService.hasAffiliateSupport(8), isFalse);
    });
  });
}
