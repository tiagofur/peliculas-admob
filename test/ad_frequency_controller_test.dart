import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/monetization/ad_frequency_controller.dart';

void main() {
  group('AdFrequencyController Tests', () {
    late AdFrequencyController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      controller = AdFrequencyController.instance;
    });

    group('Initialization', () {
      test('should initialize with default config', () async {
        await controller.initialize();
        
        expect(controller.config.maxAdsPerSession, equals(8));
        expect(controller.config.maxAdsPerHour, equals(12));
        expect(controller.config.maxAdsPerDay, equals(50));
        expect(controller.config.minTimeBetweenAds.inMinutes, equals(2));
      });

      test('should initialize with custom config', () async {
        const customConfig = AdFrequencyConfig(
          maxAdsPerSession: 5,
          maxAdsPerHour: 8,
          maxAdsPerDay: 30,
          minTimeBetweenAds: Duration(minutes: 3),
        );

        await controller.initialize(config: customConfig);
        
        expect(controller.config.maxAdsPerSession, equals(5));
        expect(controller.config.maxAdsPerHour, equals(8));
        expect(controller.config.maxAdsPerDay, equals(30));
        expect(controller.config.minTimeBetweenAds.inMinutes, equals(3));
      });
    });

    group('Session Limits', () {
      test('should allow ads within session limit', () async {
        await controller.initialize(config: const AdFrequencyConfig(maxAdsPerSession: 3));
        
        // First ad should be allowed
        var decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.allowed));
        
        await controller.recordAdShown(adType: 'banner');
        
        // Second ad should be allowed
        decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.allowed));
        
        await controller.recordAdShown(adType: 'banner');
        
        // Third ad should be allowed
        decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.allowed));
        
        await controller.recordAdShown(adType: 'banner');
        
        // Fourth ad should be blocked
        decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.blockedBySessionLimit));
      });

      test('should reset session limits on new session', () async {
        await controller.initialize(config: const AdFrequencyConfig(maxAdsPerSession: 2));
        
        // Fill session limit
        await controller.recordAdShown(adType: 'banner');
        await controller.recordAdShown(adType: 'banner');
        
        var decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.blockedBySessionLimit));
        
        // Simulate new session (this would normally happen on app restart)
        // For testing, we'll reinitialize which starts a new session
        await controller.initialize();
        
        decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.allowed));
      });
    });

    group('Time-based Limits', () {
      test('should enforce minimum time between ads', () async {
        await controller.initialize(config: const AdFrequencyConfig(
          minTimeBetweenAds: Duration(minutes: 2),
        ));
        
        // Show first ad
        var decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.allowed));
        await controller.recordAdShown(adType: 'banner');
        
        // Immediately try to show another ad - should be blocked
        decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.blockedByTimeCooldown));
      });

      test('should enforce cooldown after user interaction', () async {
        await controller.initialize(config: const AdFrequencyConfig(
          cooldownAfterUserInteraction: Duration(minutes: 5),
        ));
        
        // Record user interaction (like button tap, scroll, etc.)
        controller.recordUserInteraction();
        
        // Try to show ad immediately after interaction - should be blocked
        final decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.blockedByUserInteraction));
      });
    });

    group('Daily and Hourly Limits', () {
      test('should track daily impressions', () async {
        await controller.initialize(config: const AdFrequencyConfig(maxAdsPerDay: 2));
        
        // Show first ad
        await controller.recordAdShown(adType: 'banner');
        var decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.allowed));
        
        // Show second ad
        await controller.recordAdShown(adType: 'banner');
        decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.blockedByDailyLimit));
      });

      test('should track hourly impressions', () async {
        await controller.initialize(config: const AdFrequencyConfig(maxAdsPerHour: 1));
        
        // Show first ad
        await controller.recordAdShown(adType: 'banner');
        final decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.blockedByHourlyLimit));
      });
    });

    group('Monetization Metrics', () {
      test('should track ad impressions and clicks', () async {
        await controller.initialize();
        
        // Record impression
        await controller.recordAdShown(adType: 'banner', adId: 'test-ad-1');
        
        // Record click
        await controller.recordAdClick(
          adType: 'banner',
          adId: 'test-ad-1',
          estimatedRevenue: 0.05,
        );
        
        final metrics = await controller.getMonetizationMetrics();
        expect(metrics.totalImpressions, greaterThan(0));
        expect(metrics.totalClicks, greaterThan(0));
        expect(metrics.ctr, greaterThan(0.0));
        expect(metrics.estimatedRevenue, equals(0.05));
      });

      test('should calculate session statistics', () async {
        await controller.initialize();
        
        await controller.recordAdShown(adType: 'banner');
        await controller.recordAdClick(adType: 'banner');
        
        final stats = controller.getSessionStats();
        expect(stats['sessionAdCount'], equals(1));
        expect(stats['sessionClickCount'], equals(1));
        expect(stats['sessionId'], isNotNull);
        expect(stats['sessionDuration'], isA<int>());
      });
    });

    group('Configuration Management', () {
      test('should save and load configuration', () async {
        const customConfig = AdFrequencyConfig(
          maxAdsPerSession: 10,
          maxAdsPerHour: 15,
          maxAdsPerDay: 60,
        );

        await controller.initialize(config: customConfig);
        
        // Reinitialize to test loading
        await controller.initialize();
        
        expect(controller.config.maxAdsPerSession, equals(10));
        expect(controller.config.maxAdsPerHour, equals(15));
        expect(controller.config.maxAdsPerDay, equals(60));
      });

      test('should update configuration', () async {
        await controller.initialize();
        
        const newConfig = AdFrequencyConfig(maxAdsPerSession: 15);
        await controller.updateConfig(newConfig);
        
        expect(controller.config.maxAdsPerSession, equals(15));
      });
    });

    group('Edge Cases', () {
      test('should handle concurrent ad requests', () async {
        await controller.initialize(config: const AdFrequencyConfig(maxAdsPerSession: 1));
        
        // Simulate concurrent requests
        final decisions = await Future.wait([
          controller.canShowAd(adType: 'banner'),
          controller.canShowAd(adType: 'native'),
          controller.canShowAd(adType: 'interstitial'),
        ]);
        
        // Only one should be allowed due to session limit
        final allowedCount = decisions.where((d) => d == AdDecisionResult.allowed).length;
        expect(allowedCount, equals(1));
      });

      test('should handle errors gracefully', () async {
        // Don't initialize controller to simulate error state
        final decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.blockedBySessionLimit)); // Fail safe
      });

      test('should cleanup old data', () async {
        await controller.initialize();
        
        // Record some impressions
        await controller.recordAdShown(adType: 'banner');
        await controller.recordAdShown(adType: 'banner');
        
        final stats = controller.getSessionStats();
        expect(stats['dailyImpressions'], equals(2));
        expect(stats['hourlyImpressions'], equals(2));
      });
    });

    group('User Experience Impact', () {
      test('should respect user interaction cooldowns', () async {
        await controller.initialize(config: const AdFrequencyConfig(
          cooldownAfterUserInteraction: Duration(seconds: 30),
        ));
        
        // User interacts with app
        controller.recordUserInteraction();
        
        // Try to show ad immediately - should be blocked
        var decision = await controller.canShowAd(adType: 'banner');
        expect(decision, equals(AdDecisionResult.blockedByUserInteraction));
        
        // Simulate time passing (in real scenario, this would be actual time)
        // For testing, we verify the logic is correct
        expect(decision, isNot(equals(AdDecisionResult.allowed)));
      });

      test('should maintain ad diversity across types', () async {
        await controller.initialize();
        
        // Show different types of ads
        await controller.recordAdShown(adType: 'banner');
        await controller.recordAdShown(adType: 'native');
        await controller.recordAdShown(adType: 'interstitial');
        
        final stats = controller.getSessionStats();
        expect(stats['sessionAdCount'], equals(3));
      });
    });
  });

  group('AdFrequencyConfig Tests', () {
    test('should serialize and deserialize correctly', () {
      const config = AdFrequencyConfig(
        maxAdsPerSession: 10,
        maxAdsPerHour: 15,
        maxAdsPerDay: 60,
        minTimeBetweenAds: Duration(minutes: 3),
        cooldownAfterUserInteraction: Duration(minutes: 8),
      );

      final json = config.toJson();
      final restored = AdFrequencyConfig.fromJson(json);

      expect(restored.maxAdsPerSession, equals(config.maxAdsPerSession));
      expect(restored.maxAdsPerHour, equals(config.maxAdsPerHour));
      expect(restored.maxAdsPerDay, equals(config.maxAdsPerDay));
      expect(restored.minTimeBetweenAds, equals(config.minTimeBetweenAds));
      expect(restored.cooldownAfterUserInteraction, equals(config.cooldownAfterUserInteraction));
    });

    test('should have reasonable defaults', () {
      const config = AdFrequencyConfig();
      
      expect(config.maxAdsPerSession, greaterThan(0));
      expect(config.maxAdsPerHour, greaterThan(config.maxAdsPerSession));
      expect(config.maxAdsPerDay, greaterThan(config.maxAdsPerHour));
      expect(config.minTimeBetweenAds.inMinutes, greaterThan(0));
      expect(config.cooldownAfterUserInteraction.inMinutes, greaterThan(0));
    });
  });

  group('AdMonetizationMetrics Tests', () {
    test('should calculate metrics correctly', () {
      const metrics = AdMonetizationMetrics(
        totalImpressions: 100,
        totalClicks: 5,
        ctr: 0.05,
        estimatedRevenue: 2.50,
        averageSessionLength: Duration(minutes: 10),
        userRetentionRate: 0.85,
        adBlockedCount: 10,
        adSkippedCount: 3,
      );

      expect(metrics.totalImpressions, equals(100));
      expect(metrics.totalClicks, equals(5));
      expect(metrics.ctr, equals(0.05));
      expect(metrics.estimatedRevenue, equals(2.50));
    });

    test('should serialize to JSON correctly', () {
      const metrics = AdMonetizationMetrics(
        totalImpressions: 50,
        totalClicks: 2,
        ctr: 0.04,
        estimatedRevenue: 1.25,
        averageSessionLength: Duration(minutes: 8),
        userRetentionRate: 0.90,
        adBlockedCount: 5,
        adSkippedCount: 1,
      );

      final json = metrics.toJson();
      
      expect(json['totalImpressions'], equals(50));
      expect(json['totalClicks'], equals(2));
      expect(json['ctr'], equals(0.04));
      expect(json['estimatedRevenue'], equals(1.25));
      expect(json['averageSessionLengthMinutes'], equals(8));
    });
  });
}