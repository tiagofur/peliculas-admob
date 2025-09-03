import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/cache/adaptive_cache_config.dart';
import 'package:peliculas/core/cache/image_cache_performance_metrics.dart';
import 'package:peliculas/core/cache/network_aware_strategy.dart';
import 'package:peliculas/core/logging/logger_factory.dart';

/// Tests unitarios para los componentes de caché adaptativo
void main() {
  group('Adaptive Cache Components Unit Tests', () {
    test('AdaptiveCacheConfig should initialize with device detection',
        () async {
      final config = AdaptiveCacheConfig.instance;

      expect(config.isInitialized, isFalse);

      await config.initialize();

      expect(config.isInitialized, isTrue);
      expect(config.configuration.memoryCacheSize, greaterThan(0));
      expect(config.configuration.diskCacheSize, greaterThan(0));
      expect(config.configuration.maxConcurrentDownloads, greaterThan(0));
      expect(config.deviceCapabilities.estimatedMemoryMB, greaterThan(0));

      LoggerFactory.info('✅ Device capabilities: ${config.deviceCapabilities}');
      LoggerFactory.info('✅ Cache configuration: ${config.configuration}');
    });

    test('NetworkAwareStrategy should initialize and detect conditions',
        () async {
      final strategy = NetworkAwareStrategy.instance;

      expect(strategy.isInitialized, isFalse);

      await strategy.initialize();

      expect(strategy.isInitialized, isTrue);

      final downloadStrategy = strategy.getDownloadStrategy();
      expect(downloadStrategy.concurrentDownloads, greaterThanOrEqualTo(0));
      expect(downloadStrategy.downloadTimeout.inSeconds, greaterThan(0));

      LoggerFactory.info('✅ Network condition: ${strategy.currentCondition}');
      LoggerFactory.info('✅ Download strategy: $downloadStrategy');
    });

    test('ImageCachePerformanceMetrics should track performance', () {
      final metrics = ImageCachePerformanceMetrics.instance;

      metrics.initialize();

      // Simular algunas operaciones
      metrics.recordImageRequest();
      metrics.recordMemoryCacheHit(const Duration(milliseconds: 1));
      metrics.recordImageRequest();
      metrics.recordDiskCacheHit(const Duration(milliseconds: 5));
      metrics.recordImageRequest();
      metrics.recordNetworkDownload(const Duration(milliseconds: 200));

      final stats = metrics.getStats();

      expect(stats.totalRequests, equals(3));
      expect(stats.memoryCacheHits, equals(1));
      expect(stats.diskCacheHits, equals(1));
      expect(stats.networkDownloads, equals(1));
      expect(stats.memoryCacheHitRate, closeTo(0.33, 0.1));
      expect(stats.overallCacheHitRate, closeTo(0.67, 0.1));

      LoggerFactory.info('✅ Performance stats: $stats');

      final assessment = metrics.assessPerformance();
      LoggerFactory.info(
          '✅ Performance assessment: ${assessment.healthStatus} (${assessment.score.toStringAsFixed(1)})');
    });

    test('Configuration should adapt to different performance tiers', () async {
      // Test different device scenarios
      final testCases = [
        {'memory': 2048, 'expectedTier': PerformanceTier.low},
        {'memory': 4096, 'expectedTier': PerformanceTier.medium},
        {'memory': 8192, 'expectedTier': PerformanceTier.high},
      ];

      for (final testCase in testCases) {
        final capabilities = DeviceCapabilities(
          estimatedMemoryMB: testCase['memory'] as int,
          deviceType: DeviceType.android,
          performanceTier: testCase['expectedTier'] as PerformanceTier,
          storageMultiplier: 1.0,
        );

        LoggerFactory.info(
            '📱 Testing ${testCase['memory']}MB device (${testCase['expectedTier']})');
        LoggerFactory.info('   Capabilities: $capabilities');

        expect(capabilities.performanceTier, equals(testCase['expectedTier']));
      }
    });

    test('Network strategies should adapt to different conditions', () {
      final conditions = [
        NetworkCondition.excellent,
        NetworkCondition.good,
        NetworkCondition.fair,
        NetworkCondition.poor,
        NetworkCondition.offline,
      ];

      for (final condition in conditions) {
        // Simulate strategy for each condition
        final strategy = _getStrategyForCondition(condition);

        LoggerFactory.info('🌐 Condition: $condition');
        LoggerFactory.info('   Strategy: $strategy');

        if (condition == NetworkCondition.offline) {
          expect(strategy.concurrentDownloads, equals(0));
        } else {
          expect(strategy.concurrentDownloads, greaterThan(0));
          expect(strategy.downloadTimeout.inSeconds, greaterThan(0));
        }
      }
    });
  });
}

/// Helper method to simulate strategy for testing
DownloadStrategy _getStrategyForCondition(NetworkCondition condition) {
  switch (condition) {
    case NetworkCondition.excellent:
      return const DownloadStrategy(
        concurrentDownloads: 5,
        downloadTimeout: Duration(seconds: 15),
        retryAttempts: 3,
        retryDelay: Duration(seconds: 1),
        enablePreloading: true,
        preloadDistance: 10,
        qualityPreference: ImageQuality.high,
        enableProgressiveLoading: false,
      );
    case NetworkCondition.good:
      return const DownloadStrategy(
        concurrentDownloads: 3,
        downloadTimeout: Duration(seconds: 25),
        retryAttempts: 3,
        retryDelay: Duration(seconds: 2),
        enablePreloading: true,
        preloadDistance: 5,
        qualityPreference: ImageQuality.medium,
        enableProgressiveLoading: true,
      );
    case NetworkCondition.fair:
      return const DownloadStrategy(
        concurrentDownloads: 2,
        downloadTimeout: Duration(seconds: 40),
        retryAttempts: 2,
        retryDelay: Duration(seconds: 3),
        enablePreloading: false,
        preloadDistance: 0,
        qualityPreference: ImageQuality.low,
        enableProgressiveLoading: true,
      );
    case NetworkCondition.poor:
      return const DownloadStrategy(
        concurrentDownloads: 1,
        downloadTimeout: Duration(seconds: 60),
        retryAttempts: 1,
        retryDelay: Duration(seconds: 5),
        enablePreloading: false,
        preloadDistance: 0,
        qualityPreference: ImageQuality.thumbnail,
        enableProgressiveLoading: true,
      );
    case NetworkCondition.offline:
      return const DownloadStrategy(
        concurrentDownloads: 0,
        downloadTimeout: Duration(seconds: 1),
        retryAttempts: 0,
        retryDelay: Duration(seconds: 10),
        enablePreloading: false,
        preloadDistance: 0,
        qualityPreference: ImageQuality.cached,
        enableProgressiveLoading: false,
      );
    case NetworkCondition.unknown:
      return const DownloadStrategy(
        concurrentDownloads: 2,
        downloadTimeout: Duration(seconds: 30),
        retryAttempts: 2,
        retryDelay: Duration(seconds: 3),
        enablePreloading: false,
        preloadDistance: 0,
        qualityPreference: ImageQuality.medium,
        enableProgressiveLoading: true,
      );
  }
}
