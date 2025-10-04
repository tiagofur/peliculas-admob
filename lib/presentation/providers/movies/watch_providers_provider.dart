import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_service.dart';
import '../../../domain/entities/watch_providers.dart';
import '../../../infrastructure/repositories/tmdb_watch_providers_repository.dart';

/// Provider for TmdbWatchProvidersRepository
final tmdbWatchProvidersRepositoryProvider =
    Provider<TmdbWatchProvidersRepository>((ref) {
  return TmdbWatchProvidersRepository(
    cacheService: CacheService.instance,
  );
});

/// Provider for fetching watch providers for a specific movie
final watchProvidersProvider =
    FutureProvider.family<WatchProviders?, int>((ref, movieId) async {
  final repository = ref.watch(tmdbWatchProvidersRepositoryProvider);

  try {
    return await repository.getWatchProviders(
      movieId,
      region: 'MX', // Default to Mexico, can be made configurable later
    );
  } catch (e) {
    // Return null on error, widget will handle gracefully
    return null;
  }
});

/// Provider for fetching watch providers with custom region
final watchProvidersWithRegionProvider =
    FutureProvider.family<WatchProviders?, WatchProvidersParams>(
        (ref, params) async {
  final repository = ref.watch(tmdbWatchProvidersRepositoryProvider);

  try {
    return await repository.getWatchProviders(
      params.movieId,
      region: params.region,
      forceRefresh: params.forceRefresh,
    );
  } catch (e) {
    // Re-throw the error so the widget can handle it properly
    // This allows us to show specific error messages to the user
    throw Exception('Failed to fetch streaming providers: $e');
  }
});

/// Parameters for watch providers with region
class WatchProvidersParams {
  const WatchProvidersParams({
    required this.movieId,
    required this.region,
    this.forceRefresh = false,
  });

  final int movieId;
  final String region;
  final bool forceRefresh;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchProvidersParams &&
          runtimeType == other.runtimeType &&
          movieId == other.movieId &&
          region == other.region &&
          forceRefresh == other.forceRefresh;

  @override
  int get hashCode => Object.hash(movieId, region, forceRefresh);
}
