import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/watchlist_movie.dart';
import '../providers/watchlist_provider.dart';
import '../widgets/watchlist/watchlist_movie_card.dart';
import '../widgets/watchlist/priority_filter_chip.dart';
import '../widgets/shared/loading_indicator.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  static const name = 'watchlist-screen';

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  WatchlistPriority? _selectedPriority;
  
  @override
  void initState() {
    super.initState();
    // Cargar watchlist al inicializar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(watchlistProvider.notifier).loadWatchlist(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final watchlistState = ref.watch(watchlistProvider);
    final watchlistNotifier = ref.read(watchlistProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Watchlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              watchlistNotifier.refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros de prioridad
          _buildPriorityFilters(),
          
          // Lista de películas
          Expanded(
            child: _buildWatchlistContent(watchlistState, watchlistNotifier),
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
                ref.read(watchlistProvider.notifier).filterByPriority(null);
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
                ref.read(watchlistProvider.notifier).filterByPriority(WatchlistPriority.alta);
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
                ref.read(watchlistProvider.notifier).filterByPriority(WatchlistPriority.normal);
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
                ref.read(watchlistProvider.notifier).filterByPriority(WatchlistPriority.baja);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchlistContent(WatchlistState state, WatchlistNotifier notifier) {
    if (state.isLoading && state.movies.isEmpty) {
      return const Center(child: LoadingIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                notifier.clearError();
                notifier.refresh();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (state.movies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedPriority == null 
                ? 'Tu watchlist está vacía'
                : 'No hay películas con ${_selectedPriority!.displayName.toLowerCase()} prioridad',
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.go('/');
              },
              icon: const Icon(Icons.search),
              label: const Text('Explorar Películas'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.movies.length + (state.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.movies.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LoadingIndicator(),
            ),
          );
        }

        final movie = state.movies[index];
        return WatchlistMovieCard(
          movie: movie,
          onRemove: () {
            _showRemoveConfirmationDialog(movie, notifier);
          },
          onPriorityChanged: (newPriority) {
            notifier.updatePriority(movie.movieId, newPriority);
          },
          onTap: () {
            context.push('/movie/${movie.movieId}');
          },
        );
      },
    );
  }

  void _showRemoveConfirmationDialog(WatchlistMovie movie, WatchlistNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover de Watchlist'),
        content: Text('¿Estás seguro que quieres remover "${movie.movieTitle}" de tu watchlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              notifier.removeFromWatchlist(movie.movieId);
              
              // Mostrar snackbar de confirmación
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${movie.movieTitle} removida de watchlist'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}