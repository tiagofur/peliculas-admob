import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/movie.dart';
import '../../generated/app_localizations.dart';
import '../providers/movies/watch_providers_provider.dart';
import 'watch_providers_widget.dart';

/// Widget wrapper for WatchProvidersWidget that connects to Riverpod providers
class MovieWatchProvidersWidget extends ConsumerWidget {
  const MovieWatchProvidersWidget({
    super.key,
    required this.movie,
    this.country = 'MX',
  });

  final Movie movie;
  final String country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // Use the watch providers provider with movie-specific parameters
    final watchProvidersAsync = ref.watch(
      watchProvidersWithRegionProvider(
        WatchProvidersParams(
          movieId: movie.id,
          region: country,
        ),
      ),
    );

    return watchProvidersAsync.when(
      data: (watchProviders) {
        if (watchProviders == null) {
          // Show informative message when no streaming data is available
          return Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.streamingProvidersTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.streamingProvidersNotAvailable,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return WatchProvidersWidget(
          watchProviders: watchProviders,
          movieTitle: movie.title,
          imdbId: movie.imdbId,
          country: country,
        );
      },
      loading: () => Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.streamingProvidersTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(l10n.streamingProvidersLoading),
                ],
              ),
            ],
          ),
        ),
      ),
      error: (error, stackTrace) {
        // Show helpful error message with retry option
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.streamingProvidersTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.streamingProvidersError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Force refresh the provider to retry
                      ref.invalidate(watchProvidersWithRegionProvider(
                        WatchProvidersParams(
                          movieId: movie.id,
                          region: country,
                          forceRefresh: true,
                        ),
                      ));
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.streamingProvidersRetry),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
