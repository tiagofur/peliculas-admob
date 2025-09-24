import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/movie.dart';
import '../../services/advanced_search_service.dart';
import '../delegates/advanced_search_movie_delegate.dart';
import '../providers/movies/movie_filters_provider.dart';
import '../providers/movies/movies_repository_provider.dart';

/// Pantalla de búsqueda avanzada con filtros mejorados
class AdvancedSearchScreen extends ConsumerStatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  ConsumerState<AdvancedSearchScreen> createState() =>
      _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends ConsumerState<AdvancedSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Movie> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      } else {
        setState(() {
          _searchResults.clear();
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(movieRepositoryProvider);
      final currentFilter = ref.read(movieFiltersNotifierProvider);

      final results = await AdvancedSearchService.instance.searchWithFilters(
        query: query,
        filter: currentFilter,
        repository: repository,
        maxResults: 20,
      );

      if (mounted) {
        setState(() {
          _searchResults.clear();
          _searchResults.addAll(results);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en la búsqueda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAdvancedSearchDelegate() {
    final repository = ref.read(movieRepositoryProvider);

    showSearch(
      context: context,
      delegate: AdvancedSearchMovieDelegate(
        searchMovies: (query, filter) async {
          return await AdvancedSearchService.instance.searchWithFilters(
            query: query,
            filter: filter,
            repository: repository,
          );
        },
        initialMovies: _searchResults,
        ref: ref,
      ),
    );
  }

  void _showFiltersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _FiltersBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilters = ref.watch(movieFiltersNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Búsqueda Avanzada'),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (!activeFilters.isEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFiltersModal,
            tooltip: 'Filtros',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showAdvancedSearchDelegate,
            tooltip: 'Búsqueda avanzada',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar películas...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Active filters indicator
          if (!activeFilters.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Filtros activos',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      ref
                          .read(movieFiltersNotifierProvider.notifier)
                          .clearFilters();
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Limpiar'),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),

          // Search results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchController.text.isEmpty) {
      return _buildSearchPrompt();
    }

    if (_searchResults.isEmpty) {
      return _buildNoResults();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final movie = _searchResults[index];
        return _MovieSearchResult(
          movie: movie,
          searchQuery: _searchController.text,
        );
      },
    );
  }

  Widget _buildSearchPrompt() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Busca películas por título, género, año...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Usa los filtros para búsquedas más específicas',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron resultados para "${_searchController.text}"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Intenta con otros términos o ajusta los filtros',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieSearchResult extends StatelessWidget {
  const _MovieSearchResult({
    required this.movie,
    required this.searchQuery,
  });

  final Movie movie;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to movie details
          // Navigator.push(context, MovieDetailsScreen.route(movie));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Movie poster
              Container(
                width: 60,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade300,
                ),
                child: movie.posterPath.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          'https://image.tmdb.org/t/p/w200${movie.posterPath}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.movie, size: 30);
                          },
                        ),
                      )
                    : const Icon(Icons.movie, size: 30),
              ),
              const SizedBox(width: 12),

              // Movie info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (movie.releaseDate.year > 1900)
                      Text(
                        '${movie.releaseDate.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          movie.voteAverage.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.people,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${movie.voteCount}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (movie.overview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        movie.overview,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FiltersBottomSheet extends ConsumerWidget {
  const _FiltersBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtros de Búsqueda',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref
                        .read(movieFiltersNotifierProvider.notifier)
                        .clearFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Limpiar todo'),
                ),
              ],
            ),
          ),

          const Divider(),

          // Filters content
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Los filtros se aplicarán automáticamente',
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 20),

                    // Here you would add your filter widgets
                    // Genre filters, year range, rating range, etc.
                    Text('🚧 Filtros en desarrollo...'),

                    SizedBox(height: 100), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
