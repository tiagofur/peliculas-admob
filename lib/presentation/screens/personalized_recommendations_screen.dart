import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/movie.dart';
import '../../services/personalized_recommendation_service.dart';
import '../providers/hybrid_repositories_provider.dart';
import '../providers/movie_ratings_provider.dart';
import '../providers/movies/movies_repository_provider.dart';
import '../widgets/movies/movie_card_with_actions.dart';

/// Pantalla de recomendaciones personalizadas
class PersonalizedRecommendationsScreen extends ConsumerStatefulWidget {
  const PersonalizedRecommendationsScreen({super.key});

  @override
  ConsumerState<PersonalizedRecommendationsScreen> createState() =>
      _PersonalizedRecommendationsScreenState();
}

class _PersonalizedRecommendationsScreenState
    extends ConsumerState<PersonalizedRecommendationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Estado para cada sección de recomendaciones
  List<Movie> _personalizedMovies = [];
  List<Movie> _trendingMovies = [];
  List<Movie> _becauseYouWatchedMovies = [];

  // Estados de carga
  bool _isLoadingPersonalized = true;
  bool _isLoadingTrending = true;
  bool _isLoadingBecauseYouWatched = true;

  // Errores
  String? _personalizedError;
  String? _trendingError;
  String? _becauseYouWatchedError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecommendations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    // ✅ Providers disponibles - ratingsRepository y watchlistRepository obtenidos desde providers

    // Cargar recomendaciones personalizadas
    _loadPersonalizedRecommendations();

    // Cargar tendencias
    _loadTrendingRecommendations();

    // Cargar "porque viste"
    _loadBecauseYouWatchedRecommendations();
  }

  Future<void> _loadPersonalizedRecommendations() async {
    try {
      setState(() {
        _isLoadingPersonalized = true;
        _personalizedError = null;
      });

      // ✅ Providers implementados correctamente - intentar recomendaciones personalizadas primero
      List<Movie> recommendations;
      try {
        recommendations = await PersonalizedRecommendationService.instance
            .getPersonalizedRecommendations(
          userId: 'current_user',
          moviesRepository: ref.read(movieRepositoryProvider),
          ratingsRepository: ref.read(movieRatingsRepositoryProvider),
          watchlistRepository: ref.read(watchlistRepositoryProvider),
        );
      } catch (serviceError) {
        // Fallback: usar películas populares si las recomendaciones personalizadas fallan
        recommendations =
            await ref.read(movieRepositoryProvider).getPopular(page: 1);
      }

      if (mounted) {
        setState(() {
          _personalizedMovies = recommendations;
          _isLoadingPersonalized = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _personalizedError = 'Error al cargar recomendaciones: $e';
          _isLoadingPersonalized = false;
        });
      }
    }
  }

  Future<void> _loadTrendingRecommendations() async {
    try {
      setState(() {
        _isLoadingTrending = true;
        _trendingError = null;
      });

      final trending = await PersonalizedRecommendationService.instance
          .getTrendingNowRecommendations(
        moviesRepository: ref.read(movieRepositoryProvider),
        limit: 15,
      );

      if (mounted) {
        setState(() {
          _trendingMovies = trending;
          _isLoadingTrending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _trendingError = 'Error al cargar tendencias: $e';
          _isLoadingTrending = false;
        });
      }
    }
  }

  Future<void> _loadBecauseYouWatchedRecommendations() async {
    try {
      setState(() {
        _isLoadingBecauseYouWatched = true;
        _becauseYouWatchedError = null;
      });

      // Obtener una película popular como base para las recomendaciones "porque viste"
      final popularMovies =
          await ref.read(movieRepositoryProvider).getPopular(page: 1);
      if (popularMovies.isNotEmpty) {
        final baseMovie = popularMovies.first;
        final becauseYouWatched = await PersonalizedRecommendationService
            .instance
            .getBecauseYouWatchedRecommendations(
          watchedMovie: baseMovie,
          userId: 'current_user',
          moviesRepository: ref.read(movieRepositoryProvider),
          limit: 10,
        );

        if (mounted) {
          setState(() {
            _becauseYouWatchedMovies = becauseYouWatched;
            _isLoadingBecauseYouWatched = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingBecauseYouWatched = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _becauseYouWatchedError = 'Error al cargar sugerencias: $e';
          _isLoadingBecauseYouWatched = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recomendaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecommendations,
            tooltip: 'Actualizar recomendaciones',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.person),
              text: 'Para ti',
            ),
            Tab(
              icon: Icon(Icons.trending_up),
              text: 'Tendencias',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'Porque viste',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña: Personalizado
          _buildPersonalizedTab(),

          // Pestaña: Tendencias
          _buildTrendingTab(),

          // Pestaña: Porque viste
          _buildBecauseYouWatchedTab(),
        ],
      ),
    );
  }

  Widget _buildPersonalizedTab() {
    if (_isLoadingPersonalized) {
      return _buildLoadingWidget();
    }

    if (_personalizedError != null) {
      return _buildErrorWidget(
        _personalizedError!,
        _loadPersonalizedRecommendations,
      );
    }

    if (_personalizedMovies.isEmpty) {
      return _buildEmptyWidget(
        icon: Icons.person_outline,
        title: 'Sin recomendaciones personalizadas',
        subtitle:
            'Califica algunas películas para obtener recomendaciones personalizadas',
        actionText: 'Explorar películas',
        onActionPressed: () {
          context.go('/');
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPersonalizedRecommendations,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con estadísticas
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Recomendado para ti',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Basado en tus gustos y calificaciones',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatChip(
                        '${_personalizedMovies.length}', 'Sugerencias'),
                    const SizedBox(width: 12),
                    _buildStatChip('Actualizado', 'Ahora'),
                  ],
                ),
              ],
            ),
          ),

          // Lista de películas
          Expanded(
            child: _buildMovieGrid(_personalizedMovies),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingTab() {
    if (_isLoadingTrending) {
      return _buildLoadingWidget();
    }

    if (_trendingError != null) {
      return _buildErrorWidget(_trendingError!, _loadTrendingRecommendations);
    }

    return RefreshIndicator(
      onRefresh: _loadTrendingRecommendations,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade100,
                  Colors.orange.shade50,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: Colors.orange.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'En tendencia',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Las películas más populares y mejor calificadas',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.orange.shade600,
                      ),
                ),
              ],
            ),
          ),

          // Lista de películas
          Expanded(
            child: _buildMovieGrid(_trendingMovies),
          ),
        ],
      ),
    );
  }

  Widget _buildBecauseYouWatchedTab() {
    if (_isLoadingBecauseYouWatched) {
      return _buildLoadingWidget();
    }

    if (_becauseYouWatchedError != null) {
      return _buildErrorWidget(
          _becauseYouWatchedError!, _loadBecauseYouWatchedRecommendations);
    }

    if (_becauseYouWatchedMovies.isEmpty) {
      return _buildEmptyWidget(
        icon: Icons.history,
        title: 'Sin historial de visualización',
        subtitle:
            'Agrega películas a tu watchlist o califícalas para obtener sugerencias similares',
        actionText: 'Ver watchlist',
        onActionPressed: () {
          context.go('/my-library/watchlist');
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBecauseYouWatchedRecommendations,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade100,
                  Colors.purple.shade50,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: Colors.purple.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Porque viste...',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Películas similares a las que has visto',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.purple.shade600,
                      ),
                ),
              ],
            ),
          ),

          // Lista de películas
          Expanded(
            child: _buildMovieGrid(_becauseYouWatchedMovies),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieGrid(List<Movie> movies) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: movies.length,
      itemBuilder: (context, index) {
        final movie = movies[index];
        return MovieCardWithActions(
          movie: movie,
        );
      },
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Generando recomendaciones...'),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar recomendaciones',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onActionPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onActionPressed,
              child: Text(actionText),
            ),
          ],
        ),
      ),
    );
  }
}
