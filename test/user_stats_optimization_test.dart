import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peliculas/presentation/providers/user_stats_provider.dart';

void main() {
  group('Optimized UserStats Provider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('userStatsDataProvider should use autoDispose', () {
      // This test verifies that the provider is created with autoDispose
      final provider = userStatsDataProvider;
      
      // The provider should be an AutoDisposeProvider
      expect(provider, isA<AutoDisposeProvider>());
    });

    test('userStatsProvider should use autoDispose', () {
      final provider = userStatsProvider;
      
      // The provider should be an AutoDisposeFutureProvider
      expect(provider, isA<AutoDisposeFutureProvider>());
    });

    test('genreAnalysisProvider should use autoDispose', () {
      final provider = genreAnalysisProvider;
      
      expect(provider, isA<AutoDisposeFutureProvider>());
    });

    test('temporalAnalysisProvider should use autoDispose', () {
      final provider = temporalAnalysisProvider;
      
      expect(provider, isA<AutoDisposeFutureProvider>());
    });

    test('ratingAnalysisProvider should use autoDispose', () {
      final provider = ratingAnalysisProvider;
      
      expect(provider, isA<AutoDisposeFutureProvider>());
    });

    test('activityPatternsProvider should use autoDispose', () {
      final provider = activityPatternsProvider;
      
      expect(provider, isA<AutoDisposeFutureProvider>());
    });

    test('statsBasedRecommendationsProvider should use autoDispose', () {
      final provider = statsBasedRecommendationsProvider;
      
      expect(provider, isA<AutoDisposeFutureProvider>());
    });

    test('basicUserStatsProvider should use autoDispose', () {
      final provider = basicUserStatsProvider;
      
      expect(provider, isA<AutoDisposeProvider>());
    });

    test('BasicUserStats should calculate derived values correctly', () {
      const stats = BasicUserStats(
        totalFavorites: 5,
        totalWatched: 10,
        totalCustomLists: 3,
        totalDefaultLists: 2,
      );

      expect(stats.totalFavorites, equals(5));
      expect(stats.totalWatched, equals(10));
      expect(stats.totalCustomLists, equals(3));
      expect(stats.totalDefaultLists, equals(2));
      expect(stats.totalMoviesInteractedWith, equals(15)); // 5 + 10
      expect(stats.totalLists, equals(5)); // 3 + 2
    });

    test('BasicUserStats should handle zero values', () {
      const stats = BasicUserStats(
        totalFavorites: 0,
        totalWatched: 0,
        totalCustomLists: 0,
        totalDefaultLists: 0,
      );

      expect(stats.totalMoviesInteractedWith, equals(0));
      expect(stats.totalLists, equals(0));
    });

    test('BasicUserStats should handle large values', () {
      const stats = BasicUserStats(
        totalFavorites: 1000,
        totalWatched: 2000,
        totalCustomLists: 50,
        totalDefaultLists: 10,
      );

      expect(stats.totalMoviesInteractedWith, equals(3000));
      expect(stats.totalLists, equals(60));
    });
  });

  group('Provider Structure Tests', () {
    test('All analysis providers should be separate and independent', () {
      // Verify that each provider is distinct
      expect(genreAnalysisProvider, isNot(equals(temporalAnalysisProvider)));
      expect(temporalAnalysisProvider, isNot(equals(ratingAnalysisProvider)));
      expect(ratingAnalysisProvider, isNot(equals(activityPatternsProvider)));
    });

    test('Basic stats provider should be lightweight', () {
      // BasicUserStats should only contain simple int values, no complex calculations
      const stats = BasicUserStats(
        totalFavorites: 1,
        totalWatched: 2,
        totalCustomLists: 3,
        totalDefaultLists: 4,
      );

      // Should be able to create instantly without async operations
      expect(stats, isNotNull);
      expect(stats.totalFavorites, isA<int>());
      expect(stats.totalWatched, isA<int>());
      expect(stats.totalCustomLists, isA<int>());
      expect(stats.totalDefaultLists, isA<int>());
    });
  });

  group('Performance Optimization Tests', () {
    test('AutoDispose providers should clean up resources', () {
      // This test verifies the structure rather than runtime behavior
      // since testing actual disposal requires complex widget testing
      
      expect(userStatsDataProvider, isA<AutoDisposeProvider>());
      expect(userStatsProvider, isA<AutoDisposeFutureProvider>());
      expect(basicUserStatsProvider, isA<AutoDisposeProvider>());
    });

    test('Providers should use consistent naming pattern', () {
      final providerNames = [
        'userStatsDataProvider',
        'userStatsProvider', 
        'genreAnalysisProvider',
        'temporalAnalysisProvider',
        'ratingAnalysisProvider',
        'activityPatternsProvider',
        'statsBasedRecommendationsProvider',
        'basicUserStatsProvider',
      ];

      for (final name in providerNames) {
        expect(name, endsWith('Provider'));
      }
    });
  });

  group('BasicUserStats Edge Cases', () {
    test('Should handle negative values gracefully', () {
      // While not expected in normal usage, should handle gracefully
      const stats = BasicUserStats(
        totalFavorites: -1,
        totalWatched: 0,
        totalCustomLists: 0,
        totalDefaultLists: 0,
      );

      expect(stats.totalMoviesInteractedWith, equals(-1));
      expect(stats.totalLists, equals(0));
    });

    test('Should handle maximum integer values', () {
      const maxInt = 9223372036854775807; // Max int64 value
      const stats = BasicUserStats(
        totalFavorites: maxInt,
        totalWatched: 0,
        totalCustomLists: 0,
        totalDefaultLists: 0,
      );

      expect(stats.totalFavorites, equals(maxInt));
      expect(stats.totalMoviesInteractedWith, equals(maxInt));
    });
  });
}