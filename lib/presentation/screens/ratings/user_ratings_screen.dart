import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/user_movie_rating.dart';
import '../../providers/user_movie_ratings_provider.dart';
// import '../../widgets/shared/minimal_sync_indicator.dart';

class UserRatingsScreen extends ConsumerStatefulWidget {
  const UserRatingsScreen({super.key});

  static const String name = 'user-ratings';

  @override
  ConsumerState<UserRatingsScreen> createState() => _UserRatingsScreenState();
}

class _UserRatingsScreenState extends ConsumerState<UserRatingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String _sortBy = 'created_at'; // 'created_at', 'rating', 'movie_title'
  bool _ascending = false;
  double? _filterRating;
  bool _showOnlyWithReviews = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Cargar calificaciones al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userRatingsProvider.notifier).loadRatings(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(userRatingsProvider.notifier).loadRatings();
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filtros y Ordenamiento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ordenamiento
              const Text('Ordenar por:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _sortBy,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'created_at', child: Text('Fecha')),
                  DropdownMenuItem(value: 'rating', child: Text('Calificación')),
                  DropdownMenuItem(value: 'movie_title', child: Text('Título')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    _sortBy = value ?? 'created_at';
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _ascending,
                    onChanged: (value) {
                      setDialogState(() {
                        _ascending = value ?? false;
                      });
                    },
                  ),
                  const Text('Orden ascendente'),
                ],
              ),
              const SizedBox(height: 16),
              
              // Filtro por calificación
              const Text('Filtrar por calificación:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<double?>(
                value: _filterRating,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todas')),
                  DropdownMenuItem(value: 9.0, child: Text('9+ estrellas')),
                  DropdownMenuItem(value: 8.0, child: Text('8+ estrellas')),
                  DropdownMenuItem(value: 7.0, child: Text('7+ estrellas')),
                  DropdownMenuItem(value: 6.0, child: Text('6+ estrellas')),
                  DropdownMenuItem(value: 5.0, child: Text('5+ estrellas')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    _filterRating = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Filtro por reseñas
              Row(
                children: [
                  Checkbox(
                    value: _showOnlyWithReviews,
                    onChanged: (value) {
                      setDialogState(() {
                        _showOnlyWithReviews = value ?? false;
                      });
                    },
                  ),
                  const Text('Solo con reseñas'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  _sortBy = 'created_at';
                  _ascending = false;
                  _filterRating = null;
                  _showOnlyWithReviews = false;
                });
              },
              child: const Text('Limpiar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {});
                Navigator.of(context).pop();
                _applyFilters();
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyFilters() {
    // Aplicar filtros localmente y refrescar la UI
    setState(() {
      // Los filtros se aplican en _applyLocalFilters que se llama en build
    });
    // También refrescar los datos del provider si es necesario
    ref.read(userRatingsProvider.notifier).loadRatings(refresh: true);
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      ref.read(userRatingsProvider.notifier).loadRatings(refresh: true);
    } else {
      ref.read(userRatingsProvider.notifier).searchRatings(query);
    }
  }

  List<UserMovieRating> _applyLocalFilters(List<UserMovieRating> ratings) {
    var filtered = ratings;

    // Filtrar por calificación mínima
    if (_filterRating != null) {
      filtered = filtered.where((rating) => rating.rating >= _filterRating!).toList();
    }

    // Filtrar solo con reseñas
    if (_showOnlyWithReviews) {
      filtered = filtered.where((rating) => rating.review != null && rating.review!.isNotEmpty).toList();
    }

    // Ordenar
    filtered.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'rating':
          comparison = a.rating.compareTo(b.rating);
          break;
        case 'movie_title':
          comparison = a.movieTitle.compareTo(b.movieTitle);
          break;
        case 'created_at':
        default:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
      }
      return _ascending ? comparison : -comparison;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final ratingsState = ref.watch(userRatingsProvider);
    final filteredRatings = _applyLocalFilters(ratingsState.ratings);

    return Scaffold(
      body: Column(
        children: [
          // MinimalSyncIndicator
          // const MinimalSyncIndicator(),
          
          // AppBar personalizado
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Título y botones
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Expanded(
                        child: Text(
                          'Mis Calificaciones',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        onPressed: _showFilterDialog,
                        icon: const Icon(Icons.filter_list),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Barra de búsqueda
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por título...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ],
              ),
            ),
          ),
          
          // Contenido principal
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(userRatingsProvider.notifier).loadRatings(refresh: true);
              },
              child: _buildContent(filteredRatings, ratingsState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<UserMovieRating> ratings, UserRatingsState state) {
    if (state.isLoading && ratings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null && ratings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar calificaciones',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(userRatingsProvider.notifier).loadRatings(refresh: true);
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (ratings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_border,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay calificaciones',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Comienza calificando algunas películas',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: ratings.length + (state.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= ratings.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final rating = ratings[index];
        return _RatingCard(rating: rating);
      },
    );
  }


}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.rating});

  final UserMovieRating rating;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/movie/${rating.movieId}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 90,
                  child: rating.moviePosterPath != null
                      ? Image.network(
                          'https://image.tmdb.org/t/p/w500${rating.moviePosterPath}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPosterPlaceholder(),
                        )
                      : _buildPosterPlaceholder(),
                ),
              ),
              const SizedBox(width: 16),
              
              // Información
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(
                      rating.movieTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Rating y fecha
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            final starValue = (index + 1) * 2;
                            return Icon(
                              starValue <= rating.rating
                                  ? Icons.star
                                  : starValue - 1 <= rating.rating
                                      ? Icons.star_half
                                      : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rating.rating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dateFormat.format(rating.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    
                    // Reseña (si existe)
                    if (rating.review != null && rating.review!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        rating.review!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.movie_outlined,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}