import 'dart:math';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/movie_filter.dart';
import '../../domain/repositories/movies_repository.dart';

/// Service para búsqueda avanzada de películas con filtros múltiples
class AdvancedSearchService {
  AdvancedSearchService._();

  static final AdvancedSearchService _instance = AdvancedSearchService._();
  static AdvancedSearchService get instance => _instance;

  /// Búsqueda avanzada con filtros múltiples
  Future<List<Movie>> searchWithFilters({
    required String query,
    required MovieFilter filter,
    required MoviesRepository repository,
    int page = 1,
    int maxResults = 20,
  }) async {
    try {
      LoggerFactory.info(
          '🔍 Advanced search - Query: "$query", Filters: ${_summarizeFilters(filter)}');

      List<Movie> results = [];

      // Step 1: Base search by query
      if (query.isNotEmpty) {
        results = await repository.searchMovies(query);
        LoggerFactory.info('📊 Base search returned ${results.length} movies');
      } else {
        // If no query, get popular/discover movies
        results = await repository.getPopular();
        LoggerFactory.info(
            '📊 Discover search returned ${results.length} movies');
      }

      // Step 2: Apply filters
      results = _applyFilters(results, filter);
      LoggerFactory.info('📊 After filtering: ${results.length} movies');

      // Step 3: Apply sorting
      results = _applySorting(results, filter.sortBy);

      // Step 4: Apply pagination
      final startIndex = (page - 1) * maxResults;
      final endIndex = min(startIndex + maxResults, results.length);

      if (startIndex >= results.length) {
        return [];
      }

      final paginatedResults = results.sublist(startIndex, endIndex);
      LoggerFactory.info(
          '✅ Advanced search completed: ${paginatedResults.length} movies returned');

      return paginatedResults;
    } catch (e) {
      LoggerFactory.error('❌ Advanced search failed: $e');
      return [];
    }
  }

  /// Aplica filtros a una lista de películas
  List<Movie> _applyFilters(List<Movie> movies, MovieFilter filter) {
    var filteredMovies = movies;

    // Genre filter
    if (filter.genres.isNotEmpty) {
      filteredMovies = filteredMovies.where((movie) {
        return filter.genres.any((genre) => movie.genreIds.contains(genre));
      }).toList();
      LoggerFactory.debug(
          '🎭 Genre filter applied: ${filteredMovies.length} movies remaining');
    }

    // Year range filter
    if (filter.minYear != null || filter.maxYear != null) {
      filteredMovies = filteredMovies.where((movie) {
        final movieYear = movie.releaseDate.year;
        final minYear = filter.minYear ?? 1900;
        final maxYear = filter.maxYear ?? DateTime.now().year + 5;
        return movieYear >= minYear && movieYear <= maxYear;
      }).toList();
      LoggerFactory.debug(
          '📅 Year filter applied: ${filteredMovies.length} movies remaining');
    }

    // Rating range filter
    if (filter.minRating != null || filter.maxRating != null) {
      filteredMovies = filteredMovies.where((movie) {
        final rating = movie.voteAverage;
        final minRating = filter.minRating ?? 0.0;
        final maxRating = filter.maxRating ?? 10.0;
        return rating >= minRating && rating <= maxRating;
      }).toList();
      LoggerFactory.debug(
          '⭐ Rating filter applied: ${filteredMovies.length} movies remaining');
    }

    // Duration range filter
    if (filter.minDuration != null || filter.maxDuration != null) {
      filteredMovies = filteredMovies.where((movie) {
        if (movie.runtime == null) return false;
        final duration = movie.runtime!;
        final minDuration = filter.minDuration ?? 0;
        final maxDuration = filter.maxDuration ?? 999;
        return duration >= minDuration && duration <= maxDuration;
      }).toList();
      LoggerFactory.debug(
          '⏱️ Duration filter applied: ${filteredMovies.length} movies remaining');
    }

    // Language filter
    if (filter.language != null) {
      filteredMovies = filteredMovies.where((movie) {
        return movie.originalLanguage == filter.language;
      }).toList();
      LoggerFactory.debug(
          '🌍 Language filter applied: ${filteredMovies.length} movies remaining');
    }

    // Adult content filter
    if (filter.includeAdult == false) {
      filteredMovies = filteredMovies.where((movie) {
        return !movie.adult;
      }).toList();
      LoggerFactory.debug(
          '🔞 Adult content filter applied: ${filteredMovies.length} movies remaining');
    }

    // Minimum vote count filter
    if (filter.minVoteCount != null) {
      filteredMovies = filteredMovies.where((movie) {
        return movie.voteCount >= (filter.minVoteCount ?? 0);
      }).toList();
      LoggerFactory.debug(
          '🗳️ Vote count filter applied: ${filteredMovies.length} movies remaining');
    }

    return filteredMovies;
  }

  /// Aplica ordenamiento a los resultados
  List<Movie> _applySorting(List<Movie> movies, String? sortBy) {
    if (sortBy == null || sortBy.isEmpty) {
      return movies;
    }

    final moviesList = List<Movie>.from(movies);

    switch (sortBy) {
      case 'popularity.desc':
        moviesList.sort((a, b) => b.popularity.compareTo(a.popularity));
        break;
      case 'popularity.asc':
        moviesList.sort((a, b) => a.popularity.compareTo(b.popularity));
        break;
      case 'vote_average.desc':
        moviesList.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
        break;
      case 'vote_average.asc':
        moviesList.sort((a, b) => a.voteAverage.compareTo(b.voteAverage));
        break;
      case 'release_date.desc':
        moviesList.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
        break;
      case 'release_date.asc':
        moviesList.sort((a, b) => a.releaseDate.compareTo(b.releaseDate));
        break;
      case 'title.asc':
        moviesList.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'title.desc':
        moviesList.sort((a, b) => b.title.compareTo(a.title));
        break;
      case 'vote_count.desc':
        moviesList.sort((a, b) => b.voteCount.compareTo(a.voteCount));
        break;
      case 'vote_count.asc':
        moviesList.sort((a, b) => a.voteCount.compareTo(b.voteCount));
        break;
      default:
        LoggerFactory.warning('⚠️ Unknown sort option: $sortBy');
        break;
    }

    LoggerFactory.debug('📊 Movies sorted by: $sortBy');
    return moviesList;
  }

  /// Búsqueda inteligente por múltiples criterios
  Future<List<Movie>> intelligentSearch({
    required String query,
    required MoviesRepository repository,
    int maxResults = 20,
  }) async {
    try {
      LoggerFactory.info('🧠 Intelligent search for: "$query"');

      final results = <Movie>[];

      // Search by title (primary)
      final titleResults = await repository.searchMovies(query);
      results.addAll(titleResults);

      // If we have few results, try broader search
      if (results.length < maxResults) {
        // Try searching for actors/directors (if the service supports it)
        // For now, just return what we have
      }

      // Remove duplicates
      final uniqueResults = <Movie>[];
      final seenIds = <int>{};

      for (final movie in results) {
        if (!seenIds.contains(movie.id)) {
          uniqueResults.add(movie);
          seenIds.add(movie.id);
        }
      }

      // Sort by relevance (popularity + rating weighted)
      uniqueResults.sort((a, b) {
        final aScore = _calculateRelevanceScore(a, query);
        final bScore = _calculateRelevanceScore(b, query);
        return bScore.compareTo(aScore);
      });

      final finalResults = uniqueResults.take(maxResults).toList();
      LoggerFactory.info(
          '✅ Intelligent search completed: ${finalResults.length} movies found');

      return finalResults;
    } catch (e) {
      LoggerFactory.error('❌ Intelligent search failed: $e');
      return [];
    }
  }

  /// Calcula un score de relevancia para ordenar resultados
  double _calculateRelevanceScore(Movie movie, String query) {
    double score = 0.0;

    // Exact title match gets highest score
    if (movie.title.toLowerCase() == query.toLowerCase()) {
      score += 100.0;
    } else if (movie.title.toLowerCase().contains(query.toLowerCase())) {
      score += 50.0;
    }

    // Original title match
    if (movie.originalTitle.toLowerCase().contains(query.toLowerCase())) {
      score += 25.0;
    }

    // Overview match (less important)
    if (movie.overview.toLowerCase().contains(query.toLowerCase())) {
      score += 10.0;
    }

    // Factor in popularity and rating
    score += movie.popularity * 0.1;
    score += movie.voteAverage * 2.0;
    score += (movie.voteCount / 1000.0) * 1.0;

    return score;
  }

  /// Obtiene sugerencias de búsqueda basadas en términos populares
  List<String> getSearchSuggestions(String query) {
    final suggestions = <String>[];

    if (query.isEmpty) {
      // Default suggestions
      suggestions.addAll([
        'Marvel',
        'DC',
        'Star Wars',
        'Harry Potter',
        'Avengers',
        'Batman',
        'Spider-Man',
        'Disney',
        'Pixar',
        'Studio Ghibli',
        'Tarantino',
        'Nolan'
      ]);
    } else {
      // Context-based suggestions
      final lowerQuery = query.toLowerCase();

      final contextSuggestions = {
        'action': [
          'Marvel',
          'Fast & Furious',
          'John Wick',
          'Mission Impossible'
        ],
        'comedy': ['Comedy', 'Adam Sandler', 'Will Ferrell', 'Jim Carrey'],
        'horror': ['Horror', 'Stephen King', 'Halloween', 'Friday the 13th'],
        'sci-fi': ['Star Wars', 'Star Trek', 'Blade Runner', 'The Matrix'],
        'animation': ['Pixar', 'Disney', 'Studio Ghibli', 'DreamWorks'],
        'superhero': ['Marvel', 'DC', 'Batman', 'Superman', 'Spider-Man'],
      };

      for (final entry in contextSuggestions.entries) {
        if (lowerQuery.contains(entry.key)) {
          suggestions.addAll(entry.value);
          break;
        }
      }

      // If no context match, provide general suggestions
      if (suggestions.isEmpty) {
        suggestions.addAll([
          '$query movie',
          '$query series',
          '$query actor',
          '$query director',
        ]);
      }
    }

    return suggestions.take(6).toList();
  }

  /// Crea un resumen legible de los filtros aplicados
  String _summarizeFilters(MovieFilter filter) {
    final parts = <String>[];

    if (filter.genres.isNotEmpty) {
      parts.add('genres=${filter.genres.length}');
    }
    if (filter.minYear != null || filter.maxYear != null) {
      parts.add('years=${filter.minYear ?? "?"}-${filter.maxYear ?? "?"}');
    }
    if (filter.minRating != null || filter.maxRating != null) {
      parts.add('rating=${filter.minRating ?? "?"}-${filter.maxRating ?? "?"}');
    }
    if (filter.sortBy != null) {
      parts.add('sort=${filter.sortBy}');
    }

    return parts.isEmpty ? 'none' : parts.join(', ');
  }

  /// Valida si un filtro es aplicable a los datos disponibles
  bool isFilterValid(MovieFilter filter) {
    // Check for reasonable year range
    if (filter.minYear != null && filter.minYear! < 1895) return false;
    if (filter.maxYear != null && filter.maxYear! > DateTime.now().year + 10) {
      return false;
    }

    // Check for reasonable rating range
    if (filter.minRating != null &&
        (filter.minRating! < 0.0 || filter.minRating! > 10.0)) {
      return false;
    }
    if (filter.maxRating != null &&
        (filter.maxRating! < 0.0 || filter.maxRating! > 10.0)) {
      return false;
    }

    // Check for reasonable duration range
    if (filter.minDuration != null && filter.minDuration! < 0) return false;
    if (filter.maxDuration != null && filter.maxDuration! > 600) {
      return false; // 10 hours max
    }

    return true;
  }
}
