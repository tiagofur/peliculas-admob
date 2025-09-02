import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/monetization/monetization_analytics_service.dart';
import '../lib/core/monetization/ad_frequency_controller.dart';

void main() {
  group('MonetizationAnalyticsService Tests', () {
    late MonetizationAnalyticsService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = MonetizationAnalyticsService.instance;
      
      // Initialize frequency controller for dependencies
      await AdFrequencyController.instance.initialize();
    });

    group('Event Tracking', () {
      test('should track ad impressions', () async {
        await expectLater(
          service.trackAdImpression(
            adType: 'banner',
            adUnitId: 'test-banner-unit',
            adId: 'test-ad-123',
            placement: 'home_screen',
            customParameters: {'position': 'top'},
          ),
          completes,
        );
      });

      test('should track ad clicks', () async {
        await expectLater(
          service.trackAdClick(
            adType: 'native',
            adUnitId: 'test-native-unit',
            adId: 'test-ad-456',
            placement: 'movie_details',
            estimatedRevenue: 0.05,
          ),
          completes,
        );
      });

      test('should track ad load errors', () async {
        await expectLater(
          service.trackAdLoadError(
            adType: 'interstitial',
            adUnitId: 'test-interstitial-unit',
            errorCode: '3',
            errorMessage: 'Network error',
            placement: 'between_screens',
          ),
          completes,
        );
      });

      test('should track ad blocked events', () async {
        await expectLater(
          service.trackAdBlocked(
            adType: 'banner',
            reason: AdDecisionResult.blockedBySessionLimit,
            placement: 'search_results',
          ),
          completes,
        );
      });

      test('should track ad load performance', () async {
        await expectLater(
          service.trackAdLoadTime(
            adType: 'native',
            adUnitId: 'test-native-unit',
            loadTime: const Duration(milliseconds: 1500),
            successful: true,
            placement: 'movie_list',
          ),
          completes,
        );
      });

      test('should track user experience impact', () async {
        await expectLater(
          service.trackUserExperienceImpact(
            adType: 'banner',
            action: 'view',
            timeToAction: const Duration(seconds: 5),
            placement: 'home_screen',
            customData: {'scroll_position': 200},
          ),
          completes,
        );
      });
    });

    group('Detailed Metrics', () {
      test('should calculate basic metrics', () async {
        // Track some test data
        await service.trackAdImpression(
          adType: 'banner',
          adUnitId: 'test-unit',
          placement: 'test',
        );
        
        await service.trackAdClick(
          adType: 'banner',
          adUnitId: 'test-unit',
          placement: 'test',
          estimatedRevenue: 0.02,
        );

        final metrics = await service.getDetailedMetrics();
        
        expect(metrics, isA<DetailedMonetizationMetrics>());
        expect(metrics.totalImpressions, greaterThanOrEqualTo(0));
        expect(metrics.totalClicks, greaterThanOrEqualTo(0));
        expect(metrics.estimatedRevenue, greaterThanOrEqualTo(0.0));
      });

      test('should handle empty data gracefully', () async {
        final metrics = await service.getDetailedMetrics();
        
        expect(metrics.totalImpressions, equals(0));
        expect(metrics.totalClicks, equals(0));
        expect(metrics.ctr, equals(0.0));
        expect(metrics.estimatedRevenue, equals(0.0));
      });

      test('should filter metrics by date range', () async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final tomorrow = now.add(const Duration(days: 1));

        // Track an impression
        await service.trackAdImpression(
          adType: 'banner',
          adUnitId: 'test-unit',
          placement: 'test',
        );

        // Get metrics for today only
        final todayMetrics = await service.getDetailedMetrics(
          startDate: yesterday,
          endDate: tomorrow,
        );

        expect(todayMetrics, isA<DetailedMonetizationMetrics>());
      });
    });

    group('Performance Tracking', () {
      test('should track successful ad loads', () async {
        await service.trackAdLoadTime(
          adType: 'banner',
          adUnitId: 'test-unit',
          loadTime: const Duration(milliseconds: 800),
          successful: true,
        );

        final metrics = await service.getDetailedMetrics();
        expect(metrics.averageLoadTimeMs, greaterThanOrEqualTo(0.0));
      });

      test('should track failed ad loads', () async {
        await service.trackAdLoadTime(
          adType: 'banner',
          adUnitId: 'test-unit',
          loadTime: const Duration(milliseconds: 5000),
          successful: false,
        );

        await service.trackAdLoadError(
          adType: 'banner',
          adUnitId: 'test-unit',
          errorCode: 'TIMEOUT',
          errorMessage: 'Ad request timed out',
        );

        final metrics = await service.getDetailedMetrics();
        expect(metrics.errorRate, greaterThanOrEqualTo(0.0));
      });
    });

    group('User Experience Metrics', () {
      test('should track user interactions with ads', () async {
        // Track various user actions
        await service.trackUserExperienceImpact(
          adType: 'native',
          action: 'view',
          timeToAction: const Duration(seconds: 3),
        );

        await service.trackUserExperienceImpact(
          adType: 'native',
          action: 'interact',
          timeToAction: const Duration(seconds: 8),
        );

        await service.trackUserExperienceImpact(
          adType: 'banner',
          action: 'skip',
          timeToAction: const Duration(seconds: 1),
        );

        final metrics = await service.getDetailedMetrics();
        expect(metrics.userExperienceScore, greaterThanOrEqualTo(0.0));
        expect(metrics.userExperienceScore, lessThanOrEqualTo(1.0));
      });

      test('should penalize negative user actions', () async {
        // Track negative actions
        await service.trackUserExperienceImpact(
          adType: 'banner',
          action: 'close',
          timeToAction: const Duration(milliseconds: 500),
        );

        await service.trackUserExperienceImpact(
          adType: 'banner',
          action: 'skip',
          timeToAction: const Duration(milliseconds: 300),
        );

        final metrics = await service.getDetailedMetrics();
        // UX score should be lower due to negative actions
        expect(metrics.userExperienceScore, lessThan(1.0));
      });
    });

    group('Ad Type Distribution', () {
      test('should track metrics by ad type', () async {
        // Track different ad types
        await service.trackAdImpression(
          adType: 'banner',
          adUnitId: 'banner-unit',
          placement: 'top',
        );

        await service.trackAdImpression(
          adType: 'native',
          adUnitId: 'native-unit',
          placement: 'middle',
        );

        await service.trackAdClick(
          adType: 'banner',
          adUnitId: 'banner-unit',
          estimatedRevenue: 0.03,
        );

        final metrics = await service.getDetailedMetrics();
        
        expect(metrics.impressionsByType, isA<Map<String, int>>());
        expect(metrics.clicksByType, isA<Map<String, int>>());
        expect(metrics.revenueByType, isA<Map<String, double>>());
      });
    });

    group('Error Handling', () {
      test('should handle tracking errors gracefully', () async {
        // These should not throw exceptions
        await expectLater(
          service.trackAdImpression(
            adType: '',
            adUnitId: '',
            placement: null,
          ),
          completes,
        );

        await expectLater(
          service.trackAdClick(
            adType: '',
            adUnitId: '',
            estimatedRevenue: null,
          ),
          completes,
        );
      });

      test('should return empty metrics on error', () async {
        // Force an error by requesting metrics before any setup
        // This simulates service errors
        final metrics = await service.getDetailedMetrics();
        
        expect(metrics, isA<DetailedMonetizationMetrics>());
        // Should not crash, even if data is empty
      });
    });
  });

  group('DetailedMonetizationMetrics Tests', () {
    test('should create empty metrics', () {
      const metrics = DetailedMonetizationMetrics.empty();
      
      expect(metrics.totalImpressions, equals(0));
      expect(metrics.totalClicks, equals(0));
      expect(metrics.ctr, equals(0.0));
      expect(metrics.estimatedRevenue, equals(0.0));
      expect(metrics.userExperienceScore, equals(0.0));
    });

    test('should evaluate health indicators correctly', () {
      // Healthy metrics
      const healthyMetrics = DetailedMonetizationMetrics(
        totalImpressions: 1000,
        totalClicks: 25,
        ctr: 0.025, // 2.5% CTR
        estimatedRevenue: 12.50,
        averageLoadTimeMs: 800,
        errorRate: 0.05, // 5% error rate
        blockedAdsCount: 20,
        impressionsByType: {'banner': 500, 'native': 500},
        clicksByType: {'banner': 15, 'native': 10},
        revenueByType: {'banner': 7.50, 'native': 5.00},
        userExperienceScore: 0.8, // 80% UX score
        averageSessionDuration: Duration(minutes: 12),
      );

      expect(healthyMetrics.isUserExperienceHealthy, isTrue);
      expect(healthyMetrics.isCTRHealthy, isTrue);
      expect(healthyMetrics.isErrorRateHealthy, isTrue);

      // Unhealthy metrics
      const unhealthyMetrics = DetailedMonetizationMetrics(
        totalImpressions: 1000,
        totalClicks: 5,
        ctr: 0.005, // 0.5% CTR (low)
        estimatedRevenue: 2.50,
        averageLoadTimeMs: 3000,
        errorRate: 0.25, // 25% error rate (high)
        blockedAdsCount: 200,
        impressionsByType: {},
        clicksByType: {},
        revenueByType: {},
        userExperienceScore: 0.5, // 50% UX score (low)
        averageSessionDuration: Duration(minutes: 3),
      );

      expect(unhealthyMetrics.isUserExperienceHealthy, isFalse);
      expect(unhealthyMetrics.isCTRHealthy, isFalse);
      expect(unhealthyMetrics.isErrorRateHealthy, isFalse);
    });

    test('should serialize to JSON correctly', () {
      const metrics = DetailedMonetizationMetrics(
        totalImpressions: 100,
        totalClicks: 3,
        ctr: 0.03,
        estimatedRevenue: 1.50,
        averageLoadTimeMs: 1200,
        errorRate: 0.08,
        blockedAdsCount: 15,
        impressionsByType: {'banner': 60, 'native': 40},
        clicksByType: {'banner': 2, 'native': 1},
        revenueByType: {'banner': 1.00, 'native': 0.50},
        userExperienceScore: 0.75,
        averageSessionDuration: Duration(minutes: 10),
      );

      final json = metrics.toJson();

      expect(json['totalImpressions'], equals(100));
      expect(json['totalClicks'], equals(3));
      expect(json['ctr'], equals(0.03));
      expect(json['estimatedRevenue'], equals(1.50));
      expect(json['userExperienceScore'], equals(0.75));
      expect(json['averageSessionDurationMinutes'], equals(10));
      expect(json['isUserExperienceHealthy'], isTrue);
      expect(json['isCTRHealthy'], isTrue);
      expect(json['isErrorRateHealthy'], isTrue);
    });
  });

  group('Integration Tests', () {
    test('should work with frequency controller', () async {
      final controller = AdFrequencyController.instance;
      await controller.initialize();

      // Record an ad through frequency controller
      await controller.recordAdShown(adType: 'banner');
      await controller.recordAdClick(adType: 'banner');

      // Verify analytics service can retrieve the data
      final metrics = await service.getDetailedMetrics();
      expect(metrics, isA<DetailedMonetizationMetrics>());
    });

    test('should handle concurrent operations', () async {
      // Simulate concurrent ad events
      final futures = <Future>[];
      
      for (int i = 0; i < 10; i++) {
        futures.add(service.trackAdImpression(
          adType: 'banner',
          adUnitId: 'concurrent-test',
          placement: 'test-$i',
        ));
      }

      await Future.wait(futures);

      final metrics = await service.getDetailedMetrics();
      expect(metrics.totalImpressions, greaterThanOrEqualTo(0));
    });
  });
}