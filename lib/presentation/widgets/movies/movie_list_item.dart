import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/movie.dart';
import '../../providers/providers.dart';
import '../../providers/storage/direct_favorites_provider.dart';
import '../../providers/watched_movies_provider.dart';
import '../../screens/movies/movie_screen.dart';
import 'movie_rating.dart';

class MovieListItem extends ConsumerStatefulWidget {
  const MovieListItem({
    super.key,
    required this.movie,
    required this.listId,
    this.onRemove,
  });

  final Movie movie;
  final String listId;
  final VoidCallback? onRemove;

  @override
  ConsumerState<MovieListItem> createState() => _MovieListItemState();
}

class _MovieListItemState extends ConsumerState<MovieListItem>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOut,
    ));
    _elevationAnimation = Tween<double>(
      begin: 4.0,
      end: 12.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    if (isHovered) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(icon, color: color),
        onPressed: onPressed,
      ),
    );
  }

  void _removeFromList() {
    ref
        .read(allListsProvider.notifier)
        .removeMovieFromList(widget.listId, widget.movie.id);

    // Notificar al widget padre para que actualice la UI
    widget.onRemove?.call();
  }

  void _toggleFavorite(bool currentValue) {
    ref.read(directFavoriteMoviesProvider.notifier).toggleFavorite(widget.movie);
  }

  void _toggleWatched(bool currentValue) {
    if (currentValue) {
      ref
          .read(watchedMoviesProvider.notifier)
          .removeFromWatched(widget.movie.id);
    } else {
      ref.read(watchedMoviesProvider.notifier).markAsWatched(widget.movie);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final isWatched = ref.watch(isWatchedProvider(widget.movie.id));
    final isFavorite = ref.watch(directIsFavoriteProvider(widget.movie.id));

    return AnimatedBuilder(
      animation: _hoverController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //* Imagen con micro-interacciones
                GestureDetector(
                  onTap: () => context.push('/movie/${widget.movie.id}'),
                  child: MouseRegion(
                    onEnter: (_) => _onHover(true),
                    onExit: (_) => _onHover(false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: _elevationAnimation.value,
                            offset: Offset(0, _elevationAnimation.value / 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: 220,
                              width: 150,
                              child: Image.network(
                                widget.movie.posterPath,
                                fit: BoxFit.cover,
                                width: 150,
                                height: 220,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 220,
                                    width: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.grey),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 220,
                                    width: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[900],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                  );
                                },
                              ),
                            ),

                            // Botones de acción
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Column(
                                children: [
                                  // Botón para quitar de la lista
                                  _buildActionButton(
                                    icon: Icons.remove_circle,
                                    color: Colors.red,
                                    onPressed: _removeFromList,
                                  ),

                                  const SizedBox(height: 4),

                                  // Botón favorito
                                  _buildActionButton(
                                    icon: isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color:
                                        isFavorite ? Colors.red : Colors.white,
                                    onPressed: () =>
                                        _toggleFavorite(isFavorite),
                                  ),

                                  const SizedBox(height: 4),

                                  // Botón visto
                                  _buildActionButton(
                                    icon: isWatched
                                        ? Icons.visibility
                                        : Icons.visibility_outlined,
                                    color:
                                        isWatched ? Colors.green : Colors.white,
                                    onPressed: () => _toggleWatched(isWatched),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                //* Title con animación
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 150,
                  transform: Matrix4.translationValues(
                    0,
                    _isHovered ? -2 : 0,
                    0,
                  ),
                  child: Text(
                    widget.movie.title,
                    maxLines: 2,
                    style: textStyles.titleSmall?.copyWith(
                      color: _isHovered
                          ? Theme.of(context).primaryColor
                          : textStyles.titleSmall?.color,
                    ),
                  ),
                ),

                //* Rating con animación
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: Matrix4.translationValues(
                    0,
                    _isHovered ? -2 : 0,
                    0,
                  ),
                  child: MovieRating(voteAverage: widget.movie.voteAverage),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
