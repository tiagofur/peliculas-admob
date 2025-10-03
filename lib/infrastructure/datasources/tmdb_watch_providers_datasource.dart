import 'package:dio/dio.dart';

import '../../config/constants/environment.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/watch_providers.dart';

/// Datasource for fetching watch providers from TMDB API
/// Provides real streaming availability data for movies
class TmdbWatchProvidersDatasource {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      queryParameters: {
        'api_key': Environment.theMovieDbKey,
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  /// Get watch providers for a movie
  ///
  /// [movieId] - TMDB movie ID
  /// [region] - ISO 3166-1 country code (e.g., 'US', 'MX', 'ES')
  ///
  /// Returns [WatchProviders] with streaming, rent, and buy options
  /// Returns null if no providers found or API error
  Future<WatchProviders?> getWatchProviders(
    int movieId, {
    String region = 'MX',
  }) async {
    try {
      LoggerFactory.info(
        '🌐 Fetching watch providers for movie $movieId in region $region',
      );

      final response = await _dio.get('/movie/$movieId/watch/providers');

      if (response.statusCode != 200) {
        LoggerFactory.warning(
          'Watch providers API returned status ${response.statusCode}',
        );
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final results = data['results'] as Map<String, dynamic>?;

      if (results == null || results[region] == null) {
        LoggerFactory.info(
          'No watch providers found for movie $movieId in region $region',
        );
        return null;
      }

      final regionData = results[region] as Map<String, dynamic>;
      final providers = WatchProviders.fromJson(regionData);

      LoggerFactory.info(
        '✅ Found watch providers for movie $movieId: '
        '${providers.flatrate.length} streaming, '
        '${providers.rent.length} rent, '
        '${providers.buy.length} buy',
      );

      return providers;
    } on DioException catch (e) {
      LoggerFactory.error(
        'DioException fetching watch providers for movie $movieId: ${e.message}',
      );
      return null; // Fail silently, don't crash the app
    } catch (e) {
      LoggerFactory.error(
        'Unexpected error fetching watch providers for movie $movieId: $e',
      );
      return null; // Fail silently
    }
  }

  /// Get watch providers for multiple movies (batch operation)
  ///
  /// [movieIds] - List of TMDB movie IDs
  /// [region] - ISO 3166-1 country code
  ///
  /// Returns Map of movie ID to WatchProviders
  Future<Map<int, WatchProviders?>> getBatchWatchProviders(
    List<int> movieIds, {
    String region = 'MX',
  }) async {
    final results = <int, WatchProviders?>{};

    // TMDB doesn't support batch requests, so we need to make individual calls
    // We'll use Future.wait for parallel execution
    final futures = movieIds.map((id) async {
      final providers = await getWatchProviders(id, region: region);
      return MapEntry(id, providers);
    });

    final entries = await Future.wait(futures);

    for (final entry in entries) {
      results[entry.key] = entry.value;
    }

    LoggerFactory.info(
      'Batch fetch completed: ${results.length} movies, '
      '${results.values.where((p) => p != null).length} with providers',
    );

    return results;
  }

  /// Get available regions for watch providers
  ///
  /// Returns list of ISO 3166-1 country codes where TMDB has data
  Future<List<String>> getAvailableRegions() async {
    try {
      final response = await _dio.get('/watch/providers/regions');

      if (response.statusCode != 200) {
        return _getDefaultRegions();
      }

      final data = response.data as Map<String, dynamic>;
      final results = data['results'] as List?;

      if (results == null) {
        return _getDefaultRegions();
      }

      return results.map((r) => r['iso_3166_1'] as String).toList();
    } catch (e) {
      LoggerFactory.warning(
        'Failed to fetch available regions, using defaults: $e',
      );
      return _getDefaultRegions();
    }
  }

  /// Default regions with good TMDB coverage
  List<String> _getDefaultRegions() {
    return [
      'US', // United States
      'MX', // Mexico
      'ES', // Spain
      'AR', // Argentina
      'CO', // Colombia
      'CL', // Chile
      'BR', // Brazil
      'GB', // United Kingdom
      'FR', // France
      'DE', // Germany
      'IT', // Italy
      'CA', // Canada
      'AU', // Australia
      'JP', // Japan
      'KR', // South Korea
    ];
  }

  /// Dispose resources
  void dispose() {
    _dio.close();
  }
}
