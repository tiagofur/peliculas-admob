import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/tmdb_image_utils.dart';
import '../../../domain/entities/watchlist_movie.dart';

class WatchlistMovieCard extends StatelessWidget {
  const WatchlistMovieCard({
    super.key,
    required this.movie,
    required this.onRemove,
    required this.onPriorityChanged,
    required this.onTap,
  });

  final WatchlistMovie movie;
  final void Function() onRemove;
  final Function(WatchlistPriority) onPriorityChanged;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster de la película
              _buildMoviePoster(),
              const SizedBox(width: 12),

              // Información de la película
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      movie.movieTitle,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Fecha de lanzamiento y rating
                    if (movie.movieReleaseDate != null ||
                        movie.movieVoteAverage != null)
                      _buildMovieMetadata(theme),

                    const SizedBox(height: 8),

                    // Overview
                    if (movie.movieOverview != null &&
                        movie.movieOverview!.isNotEmpty) ...[
                      Text(
                        movie.movieOverview!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Controles (prioridad y acciones)
                    _buildMovieControls(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoviePoster() {
    const posterWidth = 80.0;
    const posterHeight = 120.0;

    return Container(
      width: posterWidth,
      height: posterHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[300],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: movie.moviePosterPath != null
            ? CachedNetworkImage(
                imageUrl: resolvePosterUrl(
                  movie.moviePosterPath,
                  size: 'w500',
                ),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.movie, color: Colors.grey),
                ),
              )
            : Container(
                color: Colors.grey[300],
                child: const Icon(Icons.movie, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildMovieMetadata(ThemeData theme) {
    final List<Widget> metadata = [];

    if (movie.movieReleaseDate != null) {
      final releaseDate = movie.movieReleaseDate;
      if (releaseDate != null) {
        metadata.add(
          Text(
            '${releaseDate.year}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        );
      }
    }

    if (movie.movieVoteAverage != null) {
      if (metadata.isNotEmpty) {
        metadata.add(
          Text(
            ' • ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        );
      }

      metadata.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              size: 14,
              color: Colors.amber[700],
            ),
            const SizedBox(width: 2),
            Text(
              (movie.movieVoteAverage ?? 0.0).toStringAsFixed(1),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: metadata,
    );
  }

  Widget _buildMovieControls(ThemeData theme) {
    return Row(
      children: [
        // Selector de prioridad
        _buildPrioritySelector(theme),

        const Spacer(),

        // Fecha agregada
        Text(
          'Agregada: ${_formatDate(movie.addedAt)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),

        const SizedBox(width: 8),

        // Botón remover
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
          iconSize: 20,
          color: Colors.grey[600],
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritySelector(ThemeData theme) {
    return PopupMenuButton<WatchlistPriority>(
      onSelected: onPriorityChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getPriorityColor(movie.priority).withValues(alpha: 0.1 * 255),
          border: Border.all(
            color: _getPriorityColor(movie.priority),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getPriorityColor(movie.priority),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              movie.priority.displayName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _getPriorityColor(movie.priority),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: _getPriorityColor(movie.priority),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: WatchlistPriority.alta,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Alta Prioridad'),
            ],
          ),
        ),
        PopupMenuItem(
          value: WatchlistPriority.normal,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Prioridad Normal'),
            ],
          ),
        ),
        PopupMenuItem(
          value: WatchlistPriority.baja,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Baja Prioridad'),
            ],
          ),
        ),
      ],
    );
  }

  dynamic _getPriorityColor(WatchlistPriority priority) {
    switch (priority) {
      case WatchlistPriority.alta:
        return Colors.red;
      case WatchlistPriority.normal:
        return Colors.orange;
      case WatchlistPriority.baja:
        return Colors.green;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Hace $weeks semana${weeks > 1 ? 's' : ''}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
