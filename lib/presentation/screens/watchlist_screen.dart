import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/movie.dart';
import '../../domain/entities/watchlist_movie.dart';
import '../providers/storage/direct_watchlist_provider.dart';
import '../widgets/watchlist/priority_filter_chip.dart';
import '../widgets/watchlist/watchlist_movie_card.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  static const name = 'watchlist-screen';

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  WatchlistPriority? _selectedPriority;

  @override
  Widget build(BuildContext context) {
    // Usar el sistema directo que mantiene datos en tiempo real
    final watchlistMovies = ref.watch(directWatchlistMoviesProvider);

    // Filtrar por prioridad si está seleccionada
    List<WatchlistMovie> filteredMovies = watchlistMovies.values.toList();
    if (_selectedPriority != null) {
      filteredMovies = filteredMovies
          .where((movie) => movie.priority == _selectedPriority)
          .toList();
    }

    // Ordenar por fecha de agregado (más recientes primero)
    filteredMovies.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return Scaffold(
      appBar: AppBar(
        title: Text('Mi Watchlist (${filteredMovies.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Forzar recarga de datos
              ref
                  .read(directWatchlistMoviesProvider.notifier)
                  .enableAfterLogin();
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros de prioridad
          _buildPriorityFilters(),

          // Lista de películas
          Expanded(
            child: _buildWatchlistContent(filteredMovies),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            PriorityFilterChip(
              label: 'Todas',
              isSelected: _selectedPriority == null,
              onTap: () {
                setState(() {
                  _selectedPriority = null;
                });
              },
            ),
            const SizedBox(width: 8),
            PriorityFilterChip(
              label: 'Alta Prioridad',
              isSelected: _selectedPriority == WatchlistPriority.alta,
              color: Colors.red,
              onTap: () {
                setState(() {
                  _selectedPriority = WatchlistPriority.alta;
                });
              },
            ),
            const SizedBox(width: 8),
            PriorityFilterChip(
              label: 'Prioridad Normal',
              isSelected: _selectedPriority == WatchlistPriority.normal,
              color: Colors.orange,
              onTap: () {
                setState(() {
                  _selectedPriority = WatchlistPriority.normal;
                });
              },
            ),
            const SizedBox(width: 8),
            PriorityFilterChip(
              label: 'Baja Prioridad',
              isSelected: _selectedPriority == WatchlistPriority.baja,
              color: Colors.green,
              onTap: () {
                setState(() {
                  _selectedPriority = WatchlistPriority.baja;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchlistContent(List<WatchlistMovie> movies) {
    // Si no hay películas en la watchlist
    if (movies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedPriority == null
                  ? 'Tu watchlist está vacía'
                  : 'No hay películas con ${_selectedPriority?.displayName.toLowerCase() ?? 'esta'} prioridad',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega películas que quieras ver después',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.go('/home');
              },
              icon: const Icon(Icons.home),
              label: const Text('Explorar Películas'),
            ),
          ],
        ),
      );
    }

    // Mostrar la lista de películas
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return WatchlistMovieCard(
          movie: movie,
          onRemove: () {
            _showRemoveConfirmationDialog(movie);
          },
          onPriorityChanged: (newPriority) {
            ref
                .read(directWatchlistMoviesProvider.notifier)
                .changePriority(movie.movieId, newPriority);
          },
          onTap: () {
            context.push('/movie/${movie.movieId}');
          },
        );
      },
    );
  }

  void _showRemoveConfirmationDialog(WatchlistMovie movie) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover de Watchlist'),
        content: Text(
            '¿Estás seguro que quieres remover "${movie.movieTitle}" de tu watchlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Crear objeto Movie para el método toggleWatchlist
              final movieEntity = Movie(
                id: movie.movieId,
                title: movie.movieTitle,
                overview: movie.movieOverview ?? '',
                releaseDate: movie.movieReleaseDate ?? DateTime.now(),
                posterPath: movie.moviePosterPath ?? '',
                backdropPath: movie.movieBackdropPath ?? '',
                genreIds: const [],
                originalLanguage: 'en',
                originalTitle: movie.movieTitle,
                popularity: 0.0,
                voteAverage: movie.movieVoteAverage ?? 0.0,
                voteCount: 0,
                adult: false,
                video: false,
              );

              // Remover usando el provider directo
              await ref
                  .read(directWatchlistMoviesProvider.notifier)
                  .toggleWatchlist(movieEntity);

              // Mostrar snackbar de confirmación de forma más segura
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${movie.movieTitle} removida de watchlist'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}
