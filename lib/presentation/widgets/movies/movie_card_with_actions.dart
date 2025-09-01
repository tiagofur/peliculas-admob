import 'dart:math';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/movie.dart';
import '../../../services/hybrid_image_service.dart';
import '../../providers/providers.dart';
import '../../screens/movies/movie_screen.dart';
import '../streaming/streaming_availability_indicator.dart';

class MovieCardWithActions extends ConsumerWidget {
  const MovieCardWithActions({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final random = Random();
    final isWatched = ref.watch(isWatchedProvider(movie.id));
    final isFavorite = ref.watch(isFavoriteProvider(movie.id));

    return FadeInUp(
      from: random.nextInt(100) + 80,
      delay: Duration(milliseconds: random.nextInt(450) + 0),
      child: Stack(
        children: [
          // Imagen principal
          GestureDetector(
            onTap: () {
              if (kIsWeb) {
                context.go('/movie/${movie.id}');
              } else {
                context.push('/movie/${movie.id}');
              }
            },
            child: AspectRatio(
              aspectRatio: 2 / 3, // Relación de aspecto típica de poster de película
              child: OptimizedImage(
                imageUrl: movie.posterPath,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(20),
                enableHeroAnimation: true,
                heroTag: 'movie-card-${movie.id}',
                placeholder: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                    ),
                  ),
                ),
                errorWidget: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.movie_outlined,
                        size: 40,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Imagen no\ndisponible',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Botones de acción
          Positioned(
            top: 8,
            right: 8,
            child: Column(
              children: [
                // Botón favorito
                _buildActionButton(
                  icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.white,
                  onPressed: () => _toggleFavorite(ref, movie, isFavorite),
                ),
                
                const SizedBox(height: 4),
                
                // Botón visto
                _buildActionButton(
                  icon: isWatched ? Icons.visibility : Icons.visibility_outlined,
                  color: isWatched ? Colors.green : Colors.white,
                  onPressed: () => _toggleWatched(ref, movie, isWatched),
                ),
              ],
            ),
          ),
          
          // Indicador de estado en la parte inferior
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Rating
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        movie.voteAverage.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Streaming availability indicator
                StreamingAvailabilityBadge(
                  movieId: movie.id,
                  size: StreamingBadgeSize.small,
                  maxPlatforms: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: color,
          size: 20,
        ),
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      ),
    );
  }

  void _toggleFavorite(WidgetRef ref, Movie movie, bool currentState) {
    final favoriteMoviesNotifier = ref.read(favoriteMoviesProvider.notifier);
    
    favoriteMoviesNotifier.toggleFavorite(movie);
    
    // Invalidar el provider para actualizar la UI
    ref.invalidate(isFavoriteProvider(movie.id));
  }

  void _toggleWatched(WidgetRef ref, Movie movie, bool currentState) {
    final watchedMoviesNotifier = ref.read(watchedMoviesProvider.notifier);
    
    if (currentState) {
      watchedMoviesNotifier.removeFromWatched(movie.id);
    } else {
      watchedMoviesNotifier.markAsWatched(movie);
    }
    
    // Invalidar el provider para actualizar la UI
    ref.invalidate(isWatchedProvider(movie.id));
  }
}