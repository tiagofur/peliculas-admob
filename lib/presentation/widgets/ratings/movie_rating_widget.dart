import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/movie.dart';
import '../../../domain/entities/syncable_movie_rating.dart';
import '../../providers/movie_ratings_provider.dart';
import 'rating_dialog.dart';
import 'star_rating_widget.dart';

/// Widget para mostrar y manejar la calificación de una película
class MovieRatingWidget extends ConsumerWidget {
  const MovieRatingWidget({
    super.key,
    required this.movie,
    this.showReview = true,
    this.size = 20.0,
    this.readonly = false,
  });

  final Movie movie;
  final bool showReview;
  final double size;
  final bool readonly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingAsync = ref.watch(movieRatingProvider(movie.id));

    return ratingAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Icon(
        Icons.error,
        color: Colors.red,
        size: size,
      ),
      data: (rating) => _buildRatingWidget(context, ref, rating),
    );
  }

  Widget _buildRatingWidget(
    BuildContext context,
    WidgetRef ref,
    SyncableMovieRating? rating,
  ) {
    if (rating == null) {
      // No hay calificación - mostrar opción para calificar
      return readonly
          ? const SizedBox.shrink()
          : _buildRateButton(context, ref);
    }

    // Hay calificación - mostrar calificación actual
    return _buildExistingRating(context, ref, rating);
  }

  Widget _buildRateButton(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showRatingDialog(context, ref),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).primaryColor, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_border,
              size: size,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              'Rate',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: size * 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingRating(
    BuildContext context,
    WidgetRef ref,
    SyncableMovieRating rating,
  ) {
    return InkWell(
      onTap: readonly ? null : () => _showRatingDialog(context, ref, rating),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StarRatingWidget(
                  rating: rating.rating,
                  size: size,
                  readonly: true,
                ),
                const SizedBox(width: 4),
                Text(
                  rating.rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: size * 0.8,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            if (showReview && rating.hasReview) ...[
              const SizedBox(height: 4),
              Text(
                rating.review!.length > 50
                    ? '${rating.review!.substring(0, 50)}...'
                    : rating.review!,
                style: TextStyle(
                  fontSize: size * 0.6,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context, WidgetRef ref,
      [SyncableMovieRating? existingRating]) {
    showDialog(
      context: context,
      builder: (context) => RatingDialog(
        movie: movie,
        existingRating: existingRating,
      ),
    );
  }
}

/// Widget compacto para mostrar solo las estrellas
class CompactMovieRatingWidget extends ConsumerWidget {
  const CompactMovieRatingWidget({
    super.key,
    required this.movie,
    this.size = 16.0,
  });

  final Movie movie;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingAsync = ref.watch(movieRatingProvider(movie.id));

    return ratingAsync.when(
      loading: () => SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, _) => const SizedBox.shrink(),
      data: (rating) => rating != null
          ? StarRatingWidget(
              rating: rating.rating,
              size: size,
              readonly: true,
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Widget para mostrar estadísticas de calificaciones en el perfil
class UserRatingStatsWidget extends ConsumerWidget {
  const UserRatingStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userRatingStatsProvider);

    if (stats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No rating statistics available'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Your Ratings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              context,
              'Total Rated',
              stats['totalRatings'].toString(),
              Icons.movie,
            ),
            _buildStatRow(
              context,
              'Average Rating',
              '${stats['averageRating']}/10.0',
              Icons.star_half,
            ),
            _buildStatRow(
              context,
              'With Reviews',
              stats['ratingsWithReview'].toString(),
              Icons.rate_review,
            ),
            _buildStatRow(
              context,
              'Recent (30 days)',
              stats['recentRatingsCount'].toString(),
              Icons.schedule,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

/// Widget para mostrar lista de calificaciones recientes
class RecentRatingsWidget extends ConsumerWidget {
  const RecentRatingsWidget({
    super.key,
    this.limit = 5,
  });

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentRatingsAsync = ref.watch(recentRatingsProvider);

    return recentRatingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text('Error: $error'),
      data: (ratings) {
        if (ratings.isEmpty) {
          return const Text('No recent ratings');
        }

        final limitedRatings = ratings.take(limit).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Ratings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ...limitedRatings.map((rating) => ListTile(
                  leading: StarRatingWidget(
                    rating: rating.rating,
                    size: 16,
                    readonly: true,
                  ),
                  title: Text(rating.movieTitle),
                  subtitle: rating.hasReview
                      ? Text(
                          rating.review!.length > 50
                              ? '${rating.review!.substring(0, 50)}...'
                              : rating.review!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: Text(
                    '${rating.rating}/10',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  dense: true,
                )),
          ],
        );
      },
    );
  }
}
