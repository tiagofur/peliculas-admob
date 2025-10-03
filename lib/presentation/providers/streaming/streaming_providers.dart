import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/streaming/streaming_service_manager.dart';
import '../../../domain/entities/watch_providers.dart';
import '../analytics_providers.dart'; // Import existing analytics provider

/// Provider for CacheService singleton
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService.instance;
});

/// Provider for StreamingServiceManager singleton
final streamingServiceManagerProvider =
    Provider<StreamingServiceManager>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  final cache = ref.watch(cacheServiceProvider);

  return StreamingServiceManager(
    analytics: analytics,
    cache: cache,
  );
});

/// Provider for fetching watch providers for a specific movie
/// Returns WatchProviders or null if not available
final watchProvidersProvider = FutureProvider.autoDispose
    .family<WatchProviders?, int>((ref, movieId) async {
  final streamingManager = ref.watch(streamingServiceManagerProvider);

  // Default region is MX, can be made configurable later
  const region = 'MX';

  try {
    final providers = await streamingManager.getWatchProviders(
      movieId,
      region: region,
      forceRefresh: false, // Use cache when available
    );

    return providers;
  } catch (e) {
    // Return null on error, widget will handle gracefully
    return null;
  }
});
