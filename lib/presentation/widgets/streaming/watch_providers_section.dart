import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/streaming/streaming_providers.dart';
import '../watch_providers_widget.dart';

/// Widget that fetches and displays watch providers for a movie
/// Handles loading, error, and success states gracefully
class WatchProvidersSection extends ConsumerWidget {
  const WatchProvidersSection({
    super.key,
    required this.movieId,
    required this.movieTitle,
    this.imdbId,
    this.country = 'MX',
  });

  final int movieId;
  final String movieTitle;
  final String? imdbId;
  final String country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the providers for this movie
    final providersAsync = ref.watch(watchProvidersProvider(movieId));

    return providersAsync.when(
      // Loading state - show shimmer or simple loading indicator
      loading: () => _buildLoadingState(context),

      // Error state - fail silently, don't show error to user
      error: (error, stack) => const SizedBox.shrink(),

      // Success state - show providers if available
      data: (providers) {
        if (providers == null) {
          // No providers available - don't show anything
          return const SizedBox.shrink();
        }

        // Show the providers widget
        return Column(
          children: [
            WatchProvidersWidget(
              watchProviders: providers,
              movieTitle: movieTitle,
              imdbId: imdbId,
              country: country,
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  /// Build a subtle loading state
  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
