import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/helpers/human_formats.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/movie_filter.dart';
import '../../services/hybrid_image_service.dart';
import '../providers/movies/movie_filters_provider.dart';

typedef AdvancedSearchMoviesCallback = Future<List<Movie>> Function(
    String query, MovieFilter filter);

class AdvancedSearchMovieDelegate extends SearchDelegate<Movie?> {
  AdvancedSearchMovieDelegate({
    required this.searchMovies,
    required this.initialMovies,
    required this.ref,
  }) : super(
          searchFieldLabel: 'Buscar películas...',
          searchFieldStyle: const TextStyle(fontSize: 16),
        );

  final AdvancedSearchMoviesCallback searchMovies;
  List<Movie> initialMovies;
  final WidgetRef ref;

  StreamController<List<Movie>> debouncedMovies = StreamController.broadcast();
  StreamController<bool> isLoadingStream = StreamController.broadcast();

  Timer? _debounceTimer;
  bool _hasActiveFilters = false;

  void clearStreams() {
    debouncedMovies.close();
    isLoadingStream.close();
  }

  void _onQueryChanged(String query) {
    isLoadingStream.add(true);

    final timer = _debounceTimer;
    if (timer?.isActive ?? false) timer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final filter = ref.read(movieFiltersNotifierProvider);
      _hasActiveFilters = !filter.isEmpty;

      final movies = await searchMovies(query, filter);
      initialMovies = movies;
      debouncedMovies.add(movies);
      isLoadingStream.add(false);
    });
  }

  Widget buildResultsAndSuggestions() {
    return Column(
      children: [
        // Filters indicator and quick access
        if (_hasActiveFilters) _buildActiveFiltersIndicator(),

        // Search results
        Expanded(
          child: StreamBuilder(
            initialData: initialMovies,
            stream: debouncedMovies.stream,
            builder: (context, snapshot) {
              final movies = snapshot.data ?? [];

              if (movies.isEmpty && query.isNotEmpty) {
                return _buildNoResultsWidget();
              }

              if (movies.isEmpty && query.isEmpty) {
                return _buildSearchSuggestions();
              }

              return ListView.builder(
                itemCount: movies.length,
                itemBuilder: (context, index) => _AdvancedMovieItem(
                  movie: movies[index],
                  searchQuery: query,
                  onMovieSelected: (context, movie) {
                    clearStreams();
                    close(context, movie);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFiltersIndicator() {
    return Consumer(
      builder: (context, ref, child) {
        final filter = ref.watch(movieFiltersNotifierProvider);
        final filtersCount = _countActiveFilters(filter);

        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color:
                Theme.of(context).primaryColor.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  Theme.of(context).primaryColor.withAlpha((0.3 * 255).toInt()),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.filter_alt,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$filtersCount filtros activos',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _showFiltersBottomSheet(context);
                },
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Editar'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoResultsWidget() {
    return Builder(
      builder: (context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron películas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con otros términos o ajusta los filtros',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showFiltersBottomSheet(context),
              icon: const Icon(Icons.tune),
              label: const Text('Ajustar filtros'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sugerencias de búsqueda',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildSuggestionChips(),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.tune, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Usa filtros avanzados para una búsqueda más precisa',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final suggestions = [
      'Acción',
      'Comedia',
      'Drama',
      'Terror',
      'Aventura',
      'Marvel',
      'DC',
      'Animación',
      'Documental',
      'Romance'
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions.map((suggestion) {
        return ActionChip(
          label: Text(suggestion),
          onPressed: () {
            query = suggestion;
            _onQueryChanged(query);
          },
        );
      }).toList(),
    );
  }

  int _countActiveFilters(MovieFilter filter) {
    int count = 0;
    if (filter.genres.isNotEmpty) count++;
    if (filter.minYear != null || filter.maxYear != null) count++;
    if (filter.minRating != null || filter.maxRating != null) count++;
    if (filter.minDuration != null || filter.maxDuration != null) count++;
    if (filter.language != null) count++;
    if (filter.sortBy != null) count++;
    if (filter.includeAdult == true) count++;
    if (filter.watchProviders.isNotEmpty) count++;
    return count;
  }

  void _showFiltersBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FiltersBottomSheet(
        onFiltersApplied: () {
          _onQueryChanged(query);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      // Filter button
      IconButton(
        onPressed: () => _showFiltersBottomSheet(context),
        icon: Badge(
          isLabelVisible: _hasActiveFilters,
          child: const Icon(Icons.tune),
        ),
        tooltip: 'Filtros avanzados',
      ),
      // Loading/Clear button
      StreamBuilder(
        initialData: false,
        stream: isLoadingStream.stream,
        builder: (context, snapshot) {
          if (snapshot.data ?? false) {
            return SpinPerfect(
              duration: const Duration(seconds: 2),
              infinite: true,
              child: IconButton(
                onPressed: () => query = '',
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Buscando...',
              ),
            );
          }

          return FadeIn(
            animate: query.isNotEmpty,
            child: IconButton(
              onPressed: () => query = '',
              icon: const Icon(Icons.clear),
              tooltip: 'Limpiar búsqueda',
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        clearStreams();
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      tooltip: 'Volver',
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildResultsAndSuggestions();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _onQueryChanged(query);
    return buildResultsAndSuggestions();
  }
}

class _AdvancedMovieItem extends StatelessWidget {
  const _AdvancedMovieItem({
    required this.movie,
    required this.searchQuery,
    required this.onMovieSelected,
  });

  final Movie movie;
  final String searchQuery;
  final Function onMovieSelected;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () {
        onMovieSelected(context, movie);
      },
      child: FadeIn(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1 * 255),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Movie Poster
                SizedBox(
                  width: size.width * 0.2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: OptimizedImage(
                        imageUrl: movie.posterPath,
                        fit: BoxFit.cover,
                        enableHeroAnimation: true,
                        heroTag: 'advanced-search-${movie.id}',
                        placeholder: Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: Container(
                          color: Colors.grey[900],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.movie_outlined,
                                size: 30,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sin imagen',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Movie Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        movie.title,
                        style: textStyles.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Release year
                      Text(
                        'Año: ${movie.releaseDate.year}',
                        style: textStyles.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Overview
                      Text(
                        movie.overview.length > 120
                            ? '${movie.overview.substring(0, 120)}...'
                            : movie.overview,
                        style: textStyles.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Rating and popularity
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            HumanFormats.number(movie.voteAverage, 1),
                            style: textStyles.bodySmall?.copyWith(
                              color: Colors.amber[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.trending_up,
                            color: Colors.blue,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            HumanFormats.number(movie.popularity, 0),
                            style: textStyles.bodySmall?.copyWith(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltersBottomSheet extends ConsumerWidget {
  const _FiltersBottomSheet({
    required this.onFiltersApplied,
  });

  final VoidCallback onFiltersApplied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Filtros de búsqueda',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref
                        .read(movieFiltersNotifierProvider.notifier)
                        .clearFilters();
                  },
                  child: const Text('Limpiar todo'),
                ),
              ],
            ),
          ),

          const Divider(),

          // Filters content (simplified for this example)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick genre selection
                  const Text(
                    'Géneros populares',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGenreChips(ref),

                  const SizedBox(height: 24),

                  // Year range
                  const Text(
                    'Año de estreno',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildYearSliders(ref),

                  const SizedBox(height: 24),

                  // Rating filter
                  const Text(
                    'Calificación mínima',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRatingSlider(ref),
                ],
              ),
            ),
          ),

          // Apply button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onFiltersApplied,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Aplicar filtros',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreChips(WidgetRef ref) {
    final popularGenres = [
      {'id': 28, 'name': 'Acción'},
      {'id': 35, 'name': 'Comedia'},
      {'id': 18, 'name': 'Drama'},
      {'id': 27, 'name': 'Terror'},
      {'id': 878, 'name': 'Ciencia Ficción'},
      {'id': 10749, 'name': 'Romance'},
    ];

    final selectedGenres = ref.watch(movieFiltersNotifierProvider).genres;
    final notifier = ref.read(movieFiltersNotifierProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: popularGenres.map((genre) {
        final isSelected = selectedGenres.contains(genre['id']);
        return FilterChip(
          label: Text(genre['name']! as String),
          selected: isSelected,
          onSelected: (selected) {
            final newGenres = List<int>.from(selectedGenres);
            if (selected) {
              newGenres.add(genre['id']! as int);
            } else {
              newGenres.remove(genre['id']!);
            }
            notifier.updateGenres(newGenres);
          },
        );
      }).toList(),
    );
  }

  Widget _buildYearSliders(WidgetRef ref) {
    final filter = ref.watch(movieFiltersNotifierProvider);
    final notifier = ref.read(movieFiltersNotifierProvider.notifier);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Desde',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final year = int.tryParse(value);
                  notifier.updateYearRange(year, filter.maxYear);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Hasta',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final year = int.tryParse(value);
                  notifier.updateYearRange(filter.minYear, year);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingSlider(WidgetRef ref) {
    final filter = ref.watch(movieFiltersNotifierProvider);
    final notifier = ref.read(movieFiltersNotifierProvider.notifier);

    return Column(
      children: [
        Slider(
          value: filter.minRating ?? 0.0,
          min: 0.0,
          max: 10.0,
          divisions: 20,
          label: (filter.minRating ?? 0.0).toStringAsFixed(1),
          onChanged: (value) {
            notifier.updateRatingRange(value, filter.maxRating);
          },
        ),
        Text(
          'Mínimo: ${(filter.minRating ?? 0.0).toStringAsFixed(1)} estrellas',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
