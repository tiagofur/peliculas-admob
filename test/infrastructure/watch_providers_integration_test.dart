import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/services/logger_factory.dart';
import 'package:peliculas/infrastructure/datasources/tmdb_watch_providers_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Watch Providers TMDB API Test', () {
    late TmdbWatchProvidersDatasource datasource;

    setUpAll(() async {
      // Load environment variables
      try {
        await dotenv.load(fileName: '.env');
        LoggerFactory.info('✅ .env loaded successfully');
      } catch (e) {
        LoggerFactory.info('⚠️  Could not load .env file: $e');
        LoggerFactory.info('   Make sure .env file exists with THEMOVIEDB_KEY');
      }

      datasource = TmdbWatchProvidersDatasource();
    });

    tearDownAll(() {
      datasource.dispose();
    });

    test('Should fetch watch providers for The Matrix (603) in Mexico',
        () async {
      // Arrange
      const movieId = 603; // The Matrix
      const region = 'MX';

      // Act
      LoggerFactory.info(
          '\n🧪 Testing: Fetching watch providers for The Matrix (603) in Mexico...');
      final stopwatch = Stopwatch()..start();
      final providers = await datasource.getWatchProviders(
        movieId,
        region: region,
      );
      stopwatch.stop();

      // Assert
      LoggerFactory.info(
          '⏱️  API Response time: ${stopwatch.elapsedMilliseconds}ms');

      if (providers != null) {
        LoggerFactory.info(
            '✅ SUCCESS! Found providers for The Matrix in Mexico:');
        LoggerFactory.info(
            '   📺 Streaming platforms: ${providers.flatrate.length}');
        for (final provider in providers.flatrate) {
          LoggerFactory.info('      - ${provider.providerName}');
        }
        if (providers.rent.isNotEmpty) {
          LoggerFactory.info(
              '   💳 Rental platforms: ${providers.rent.length}');
          for (final provider in providers.rent.take(3)) {
            LoggerFactory.info('      - ${provider.providerName}');
          }
        }
        if (providers.buy.isNotEmpty) {
          LoggerFactory.info(
              '   🛒 Purchase platforms: ${providers.buy.length}');
          for (final provider in providers.buy.take(3)) {
            LoggerFactory.info('      - ${provider.providerName}');
          }
        }
        if (providers.link != null) {
          LoggerFactory.info('   🔗 Link: ${providers.link}');
        }

        expect(providers.hasProviders, isTrue,
            reason: 'Should have at least one provider');
      } else {
        LoggerFactory.info(
            '⚠️  No providers found for this region (API returned null)');
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Should handle invalid movie ID gracefully', () async {
      // Arrange
      const invalidMovieId = 999999999;
      const region = 'MX';

      // Act
      LoggerFactory.info(
          '\n🧪 Testing: Error handling with invalid movie ID...');
      final providers = await datasource.getWatchProviders(
        invalidMovieId,
        region: region,
      );

      // Assert
      LoggerFactory.info(
          '🛡️  Result: ${providers == null ? "✅ Gracefully returned null (no crash)" : "⚠️ Unexpected: got data"}');
      // Null is the expected result for invalid IDs
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Should support different regions', () async {
      // Arrange
      const movieId = 603; // The Matrix

      // Act
      LoggerFactory.info('\n🧪 Testing: Regional support for The Matrix...');
      final providersMX =
          await datasource.getWatchProviders(movieId, region: 'MX');
      await Future.delayed(
          const Duration(milliseconds: 500)); // Rate limit courtesy
      final providersUS =
          await datasource.getWatchProviders(movieId, region: 'US');
      await Future.delayed(const Duration(milliseconds: 500));
      final providersES =
          await datasource.getWatchProviders(movieId, region: 'ES');

      // Assert
      LoggerFactory.info('🌍 Regional support results:');
      LoggerFactory.info(
          '   Mexico (MX): ${providersMX != null ? "✅ ${providersMX.flatrate.length} streaming providers" : "⚠️ No data"}');
      LoggerFactory.info(
          '   United States (US): ${providersUS != null ? "✅ ${providersUS.flatrate.length} streaming providers" : "⚠️ No data"}');
      LoggerFactory.info(
          '   Spain (ES): ${providersES != null ? "✅ ${providersES.flatrate.length} streaming providers" : "⚠️ No data"}');

      // At least one region should have data for The Matrix
      final hasData =
          providersMX != null || providersUS != null || providersES != null;
      expect(hasData, isTrue,
          reason:
              'At least one region should have provider data for The Matrix');

      if (hasData) {
        LoggerFactory.info('✅ Regional support working correctly!');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Should get available regions list', () async {
      // Act
      LoggerFactory.info('\n🧪 Testing: Getting available regions...');
      final regions = await datasource.getAvailableRegions();

      // Assert
      LoggerFactory.info('📍 Available regions: ${regions.length} total');
      LoggerFactory.info(
          '   Sample (first 20): ${regions.take(20).join(", ")}');

      expect(regions, isNotEmpty, reason: 'Should have available regions');
      expect(regions.length, greaterThan(10),
          reason: 'Should have many regions (60+)');

      // Check for key regions
      final hasMX = regions.contains('MX');
      final hasUS = regions.contains('US');
      final hasES = regions.contains('ES');

      LoggerFactory.info('   Key regions found:');
      LoggerFactory.info('      Mexico (MX): ${hasMX ? "✅" : "❌"}');
      LoggerFactory.info('      United States (US): ${hasUS ? "✅" : "❌"}');
      LoggerFactory.info('      Spain (ES): ${hasES ? "✅" : "❌"}');

      expect(hasMX, isTrue, reason: 'Should include Mexico');
      expect(hasUS, isTrue, reason: 'Should include US');
      expect(hasES, isTrue, reason: 'Should include Spain');
    });

    test('Should fetch providers for Inception (27205)', () async {
      // Arrange
      const movieId = 27205; // Inception
      const region = 'US'; // Try US for better availability

      // Act
      LoggerFactory.info(
          '\n🧪 Testing: Fetching providers for Inception (27205)...');
      final providers =
          await datasource.getWatchProviders(movieId, region: region);

      // Assert
      if (providers != null) {
        LoggerFactory.info('✅ Found providers for Inception:');
        LoggerFactory.info(
            '   📺 Streaming: ${providers.flatrate.length} platforms');
        LoggerFactory.info('   💳 Rent: ${providers.rent.length} platforms');
        LoggerFactory.info('   🛒 Buy: ${providers.buy.length} platforms');
      } else {
        LoggerFactory.info('⚠️  No providers found for Inception in US');
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Should handle batch operations', () async {
      // Arrange
      const movieIds = [
        603,
        27205,
        155
      ]; // The Matrix, Inception, The Dark Knight
      const region = 'US';

      // Act
      LoggerFactory.info('\n🧪 Testing: Batch operation with 3 movies...');
      final stopwatch = Stopwatch()..start();
      final results =
          await datasource.getBatchWatchProviders(movieIds, region: region);
      stopwatch.stop();

      // Assert
      LoggerFactory.info(
          '⚡ Batch operation completed in ${stopwatch.elapsedMilliseconds}ms');
      LoggerFactory.info('📊 Results:');

      for (final entry in results.entries) {
        final movieId = entry.key;
        final providers = entry.value;
        final movieName = movieId == 603
            ? 'The Matrix'
            : movieId == 27205
                ? 'Inception'
                : 'The Dark Knight';

        if (providers != null) {
          LoggerFactory.info(
              '   ✅ $movieName (ID: $movieId): ${providers.flatrate.length} streaming providers');
        } else {
          LoggerFactory.info('   ⚠️  $movieName (ID: $movieId): No data');
        }
      }

      expect(results.length, equals(3),
          reason: 'Should return results for all 3 movies');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
