import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:peliculas/config/constants/environment.dart';
import 'package:peliculas/core/streaming/real_availability_service.dart';
import 'package:peliculas/domain/entities/streaming_availability.dart';
import 'package:peliculas/domain/entities/streaming_platform.dart';

void main() {
  late RealAvailabilityService service;

  setUpAll(() async {
    // Initialize environment variables from .env file
    TestWidgetsFlutterBinding.ensureInitialized();
    await Environment.load();
  });

  setUp(() {
    service = RealAvailabilityService(
      httpClient: http.Client(),
    );
  });

  group('RealAvailabilityService - TMDB Integration', () {
    test('checkMovieAvailability returns parsed TMDB providers', () async {
      // This is an integration test that will call the real TMDB API
      // We use a well-known movie ID that should have streaming data
      const movieId = '550'; // Fight Club
      const region = 'US';

      final availability = await service.checkMovieAvailability(
        tmdbId: movieId,
        region: region,
      );

      // Should return a list (even if empty for some regions)
      expect(availability, isA<List<PlatformAvailability>>());

      // Log what we found for debugging
      if (availability.isNotEmpty) {
        for (final avail in availability) {
          // ignore: avoid_print
          print('Found: ${avail.platform.displayName} - '
              'Free: ${avail.isFree}, '
              'Subscription: ${avail.requiresSubscription}, '
              'Rent: ${avail.canRent}, '
              'Buy: ${avail.canPurchase}');
        }
      }
    });

    test('checkMovieAvailability handles invalid movie ID gracefully',
        () async {
      const invalidMovieId = 'invalid_id';
      const region = 'US';

      final availability = await service.checkMovieAvailability(
        tmdbId: invalidMovieId,
        region: region,
      );

      // Should return empty list on error, not throw
      expect(availability, isEmpty);
    });

    test('checkMovieAvailability caches results', () async {
      const movieId = '550';
      const region = 'US';

      // First call - hits API
      await service.checkMovieAvailability(
        tmdbId: movieId,
        region: region,
      );

      // Second call - should use cache (faster)
      final stopwatch = Stopwatch()..start();
      final availability2 = await service.checkMovieAvailability(
        tmdbId: movieId,
        region: region,
      );
      stopwatch.stop();

      // Cached call should be very fast (< 100ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));

      // Should return a list
      expect(availability2, isA<List<PlatformAvailability>>());
    });
  });

  group('RealAvailabilityService - Platform Mapping', () {
    test('maps TMDB provider IDs correctly', () async {
      const movieId = '550';
      const region = 'US';

      final availability = await service.checkMovieAvailability(
        tmdbId: movieId,
        region: region,
      );

      // Check that recognized platforms are properly mapped
      for (final avail in availability) {
        expect(avail.platform, isA<StreamingPlatform>());
        expect(avail.platform.id, isNotEmpty);
        expect(avail.platform.displayName, isNotEmpty);

        // Should be one of our known platforms
        final knownPlatforms = StreamingPlatform.allPlatforms;
        final isKnown = knownPlatforms.any((p) => p.id == avail.platform.id);
        expect(isKnown, isTrue,
            reason: 'Platform ${avail.platform.id} should be in allPlatforms');
      }
    });
  });

  group('RealAvailabilityService - Data Quality', () {
    test('returned PlatformAvailability has valid data', () async {
      const movieId = '550';
      const region = 'US';

      final availability = await service.checkMovieAvailability(
        tmdbId: movieId,
        region: region,
      );

      for (final avail in availability) {
        // Basic validation
        expect(avail.isAvailable, isTrue);
        expect(avail.platform, isNotNull);

        // At least one availability type should be true
        final hasAvailabilityType = avail.isFree ||
            avail.requiresSubscription ||
            avail.canRent ||
            avail.canPurchase;
        expect(hasAvailabilityType, isTrue,
            reason: 'Should have at least one availability type');

        // Quality should be set
        expect(avail.quality, isNotEmpty);

        // Currency should be set
        expect(avail.currency, isNotEmpty);
      }
    });
  });
}
