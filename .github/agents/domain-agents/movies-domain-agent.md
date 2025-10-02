# Movies Domain Agent - peliculas-admob

## 🎬 Role

You are a domain expert for the Movies feature in peliculas-admob, specializing in movie data management, API integration, search, and movie-related business logic.

## 🎯 Domain Expertise

- **Movie Entity Modeling**: Movie data structure and relationships
- **TMDb API Integration**: The Movie Database API
- **Trakt.tv API Integration**: Movie tracking and recommendations
- **Movie Search**: Advanced search and filtering
- **Movie Details**: Comprehensive movie information
- **Recommendations**: Movie recommendation algorithms
- **Ratings & Reviews**: User ratings and reviews

## 📊 Domain Context

### Movie Entity

```dart
// lib/domain/entities/movie.dart
class Movie extends Equatable {
  final String id;
  final String title;
  final String overview;
  final DateTime? releaseDate;
  final double voteAverage;
  final int voteCount;
  final String? posterPath;
  final String? backdropPath;
  final List<String> genres;
  final String? originalLanguage;
  final bool adult;
  final double popularity;

  const Movie({
    required this.id,
    required this.title,
    required this.overview,
    this.releaseDate,
    required this.voteAverage,
    required this.voteCount,
    this.posterPath,
    this.backdropPath,
    this.genres = const [],
    this.originalLanguage,
    this.adult = false,
    required this.popularity,
  });

  // Business logic methods
  bool isHighlyRated() => voteAverage >= 7.0;
  bool isPopular() => voteCount >= 1000;
  bool isRecent() {
    if (releaseDate == null) return false;
    final now = DateTime.now();
    final diff = now.difference(releaseDate!);
    return diff.inDays <= 365;
  }

  bool isValid() {
    return title.isNotEmpty &&
           id.isNotEmpty &&
           voteAverage >= 0 &&
           voteAverage <= 10;
  }

  @override
  List<Object?> get props => [
    id, title, overview, releaseDate, voteAverage,
    voteCount, posterPath, backdropPath, genres,
    originalLanguage, adult, popularity,
  ];
}
```

## 📋 Responsibilities

### 1. Movie Data Management

- Design movie entity and value objects
- Implement movie repository
- Handle movie CRUD operations
- Manage movie caching strategy

### 2. API Integration

- TMDb API integration for movie data
- Trakt.tv API for tracking and recommendations
- Handle API rate limiting
- Implement error handling for API calls

### 3. Search & Discovery

- Implement movie search functionality
- Design filtering and sorting
- Handle search result pagination
- Optimize search performance

### 4. Business Logic

- Implement movie validation
- Define movie categorization rules
- Handle movie ratings and reviews
- Implement recommendation logic

## 🔌 API Integration

### TMDb API Configuration

```dart
// lib/infrastructure/datasources/remote/tmdb_datasource.dart
import 'package:dio/dio.dart';
import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/movie.dart';
import '../../../models/movie_model.dart';
import '../../../config/api_config.dart';

class TMDbDatasource {
  final Dio _dio;
  static const _baseUrl = 'https://api.themoviedb.org/3';

  TMDbDatasource(this._dio);

  Future<List<Movie>> getPopularMovies({int page = 1}) async {
    try {
      LoggerFactory.info('Fetching popular movies, page: $page');

      final response = await _dio.get(
        '$_baseUrl/movie/popular',
        queryParameters: {
          'api_key': ApiConfig.movieDbKey,
          'page': page,
          'language': 'es-ES',
        },
      );

      final results = response.data['results'] as List;
      final movies = results
          .map((json) => MovieModel.fromTMDbJson(json).toEntity())
          .toList();

      LoggerFactory.info('Fetched ${movies.length} popular movies');
      return movies;
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to fetch popular movies: $e', stackTrace);
      rethrow;
    }
  }

  Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    try {
      LoggerFactory.info('Searching movies: $query');

      final response = await _dio.get(
        '$_baseUrl/search/movie',
        queryParameters: {
          'api_key': ApiConfig.movieDbKey,
          'query': query,
          'page': page,
          'language': 'es-ES',
        },
      );

      final results = response.data['results'] as List;
      final movies = results
          .map((json) => MovieModel.fromTMDbJson(json).toEntity())
          .toList();

      LoggerFactory.info('Found ${movies.length} movies for: $query');
      return movies;
    } catch (e, stackTrace) {
      LoggerFactory.error('Movie search failed: $e', stackTrace);
      rethrow;
    }
  }

  Future<Movie> getMovieDetails(String movieId) async {
    try {
      LoggerFactory.info('Fetching movie details: $movieId');

      final response = await _dio.get(
        '$_baseUrl/movie/$movieId',
        queryParameters: {
          'api_key': ApiConfig.movieDbKey,
          'language': 'es-ES',
          'append_to_response': 'credits,videos,similar',
        },
      );

      final movie = MovieModel.fromTMDbJson(response.data).toEntity();

      LoggerFactory.info('Movie details loaded: ${movie.title}');
      return movie;
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to load movie details: $e', stackTrace);
      rethrow;
    }
  }

  Future<List<Movie>> getMovieRecommendations(String movieId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/movie/$movieId/recommendations',
        queryParameters: {
          'api_key': ApiConfig.movieDbKey,
          'language': 'es-ES',
        },
      );

      final results = response.data['results'] as List;
      return results
          .map((json) => MovieModel.fromTMDbJson(json).toEntity())
          .toList();
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to fetch recommendations: $e', stackTrace);
      rethrow;
    }
  }
}
```

### Trakt.tv Integration

```dart
// lib/infrastructure/datasources/remote/trakt_datasource.dart
import 'package:dio/dio.dart';
import '../../../core/logging/logger_factory.dart';
import '../../../config/api_config.dart';

class TraktDatasource {
  final Dio _dio;
  static const _baseUrl = 'https://api.trakt.tv';

  TraktDatasource(this._dio) {
    _dio.options.headers['Content-Type'] = 'application/json';
    _dio.options.headers['trakt-api-version'] = '2';
    _dio.options.headers['trakt-api-key'] = ApiConfig.traktClientId;
  }

  Future<List<Movie>> getTrendingMovies() async {
    try {
      LoggerFactory.info('Fetching trending movies from Trakt');

      final response = await _dio.get('$_baseUrl/movies/trending');

      final results = response.data as List;
      // Convert Trakt data to Movie entities
      // Implementation depends on your model structure

      LoggerFactory.info('Fetched ${results.length} trending movies');
      return [];  // Implement conversion
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to fetch trending movies: $e', stackTrace);
      rethrow;
    }
  }
}
```

## 🗄️ Repository Implementation

```dart
// lib/infrastructure/repositories/movie_repository_impl.dart
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/movie.dart';
import '../../domain/repositories/movie_repository.dart';
import '../datasources/local/local_movie_datasource.dart';
import '../datasources/remote/tmdb_datasource.dart';

class MovieRepositoryImpl implements MovieRepository {
  final TMDbDatasource _remote;
  final LocalMovieDatasource _local;

  MovieRepositoryImpl({
    required TMDbDatasource remote,
    required LocalMovieDatasource local,
  })  : _remote = remote,
        _local = local;

  @override
  Future<List<Movie>> getPopularMovies({
    int page = 1,
    bool forceRemote = false,
  }) async {
    try {
      // Try local cache first (offline-first)
      if (!forceRemote && page == 1) {
        final cached = await _local.getPopularMovies();
        if (cached.isNotEmpty) {
          LoggerFactory.info('Loaded ${cached.length} popular movies from cache');

          // Background refresh
          _refreshPopularMovies(page);

          return cached;
        }
      }

      // Fetch from remote
      final movies = await _remote.getPopularMovies(page: page);

      // Cache only first page
      if (page == 1) {
        await _local.cachePopularMovies(movies);
      }

      return movies;
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to get popular movies: $e', stackTrace);

      // Fallback to cache on error
      final cached = await _local.getPopularMovies();
      if (cached.isNotEmpty) {
        LoggerFactory.warning('Using cached popular movies due to error');
        return cached;
      }

      rethrow;
    }
  }

  @override
  Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      // Search is always remote for fresh results
      return await _remote.searchMovies(query, page: page);
    } catch (e, stackTrace) {
      LoggerFactory.error('Movie search failed: $e', stackTrace);

      // Fallback to local search
      return await _local.searchMovies(query);
    }
  }

  @override
  Future<Movie> getMovieDetails(String movieId) async {
    try {
      // Check local cache first
      final cached = await _local.getMovie(movieId);
      if (cached != null && _isDetailsCached(cached)) {
        LoggerFactory.info('Movie details loaded from cache: ${cached.title}');

        // Background refresh
        _refreshMovieDetails(movieId);

        return cached;
      }

      // Fetch from remote
      final movie = await _remote.getMovieDetails(movieId);

      // Cache details
      await _local.saveMovie(movie);

      return movie;
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to get movie details: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<Movie>> getRecommendations(String movieId) async {
    try {
      return await _remote.getMovieRecommendations(movieId);
    } catch (e, stackTrace) {
      LoggerFactory.error('Failed to get recommendations: $e', stackTrace);
      return [];  // Return empty on error
    }
  }

  // Private helper methods
  bool _isDetailsCached(Movie movie) {
    // Check if movie has full details (not just basic info)
    return movie.overview.isNotEmpty && movie.genres.isNotEmpty;
  }

  Future<void> _refreshPopularMovies(int page) async {
    try {
      final movies = await _remote.getPopularMovies(page: page);
      await _local.cachePopularMovies(movies);
    } catch (e) {
      LoggerFactory.warning('Background refresh failed: $e');
    }
  }

  Future<void> _refreshMovieDetails(String movieId) async {
    try {
      final movie = await _remote.getMovieDetails(movieId);
      await _local.saveMovie(movie);
    } catch (e) {
      LoggerFactory.warning('Background details refresh failed: $e');
    }
  }
}
```

## 🔍 Search Functionality

### Advanced Search Service

```dart
// lib/domain/services/movie_search_service.dart
import '../entities/movie.dart';
import '../repositories/movie_repository.dart';
import '../../core/logging/logger_factory.dart';

class MovieSearchService {
  final MovieRepository _repository;

  MovieSearchService(this._repository);

  Future<List<Movie>> search({
    required String query,
    double? minRating,
    List<String>? genres,
    int? year,
    bool? onlyRecent,
  }) async {
    LoggerFactory.info('Advanced search: query=$query, minRating=$minRating');

    // Get search results
    var movies = await _repository.searchMovies(query);

    // Apply filters
    if (minRating != null) {
      movies = movies.where((m) => m.voteAverage >= minRating).toList();
    }

    if (genres != null && genres.isNotEmpty) {
      movies = movies.where((m) {
        return m.genres.any((g) => genres.contains(g));
      }).toList();
    }

    if (year != null && year > 0) {
      movies = movies.where((m) {
        return m.releaseDate?.year == year;
      }).toList();
    }

    if (onlyRecent == true) {
      movies = movies.where((m) => m.isRecent()).toList();
    }

    LoggerFactory.info('Search returned ${movies.length} results');
    return movies;
  }

  List<Movie> sortMovies(List<Movie> movies, MovieSortOption sortBy) {
    switch (sortBy) {
      case MovieSortOption.rating:
        movies.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
        break;
      case MovieSortOption.popularity:
        movies.sort((a, b) => b.popularity.compareTo(a.popularity));
        break;
      case MovieSortOption.releaseDate:
        movies.sort((a, b) {
          if (a.releaseDate == null) return 1;
          if (b.releaseDate == null) return -1;
          return b.releaseDate!.compareTo(a.releaseDate!);
        });
        break;
      case MovieSortOption.title:
        movies.sort((a, b) => a.title.compareTo(b.title));
        break;
    }

    return movies;
  }
}

enum MovieSortOption { rating, popularity, releaseDate, title }
```

## 🎯 Business Logic Examples

### Movie Validation

```dart
// lib/domain/value_objects/movie_rating.dart
import 'package:equatable/equatable.dart';

class MovieRating extends Equatable {
  final double value;

  const MovieRating._(this.value);

  factory MovieRating(double rating) {
    if (rating < 0 || rating > 10) {
      throw ArgumentError('Rating must be between 0 and 10');
    }
    return MovieRating._(rating);
  }

  bool get isHighRating => value >= 7.0;
  bool get isMediumRating => value >= 5.0 && value < 7.0;
  bool get isLowRating => value < 5.0;

  String get displayText => value.toStringAsFixed(1);

  @override
  List<Object?> get props => [value];
}
```

## 📊 Providers (Riverpod)

```dart
// lib/presentation/providers/movie_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/movie.dart';
import '../../domain/repositories/movie_repository.dart';
import '../../infrastructure/repositories/movie_repository_impl.dart';

// Repository provider
final movieRepositoryProvider = Provider<MovieRepository>((ref) {
  final remote = ref.watch(tmdbDatasourceProvider);
  final local = ref.watch(localMovieDatasourceProvider);
  return MovieRepositoryImpl(remote: remote, local: local);
});

// Popular movies provider
final popularMoviesProvider = FutureProvider<List<Movie>>((ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return await repository.getPopularMovies();
});

// Movie details provider
final movieDetailsProvider = FutureProvider.family<Movie, String>((ref, id) async {
  final repository = ref.watch(movieRepositoryProvider);
  return await repository.getMovieDetails(id);
});

// Search provider
final movieSearchProvider = StateNotifierProvider<MovieSearchNotifier, AsyncValue<List<Movie>>>(
  (ref) => MovieSearchNotifier(ref.watch(movieRepositoryProvider)),
);

class MovieSearchNotifier extends StateNotifier<AsyncValue<List<Movie>>> {
  final MovieRepository _repository;

  MovieSearchNotifier(this._repository) : super(const AsyncValue.data([]));

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();

    try {
      final results = await _repository.searchMovies(query);
      state = AsyncValue.data(results);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}
```

## 📋 Domain Checklist

- [ ] **Entity Validation**: Movie data is validated
- [ ] **API Integration**: TMDb/Trakt properly integrated
- [ ] **Caching**: Offline-first strategy implemented
- [ ] **Search**: Advanced search with filters working
- [ ] **Error Handling**: API errors handled gracefully
- [ ] **Logging**: All operations logged with LoggerFactory
- [ ] **Testing**: Unit tests for business logic
- [ ] **Performance**: Search and list loading optimized

## 📚 References

- **TMDb API**: https://developers.themoviedb.org/3
- **Trakt.tv API**: https://trakt.docs.apiary.io/
- **Main Instructions**: `.github/copilot-instructions.md`
- **Repository Pattern**: `.github/agents/architecture-agent.md`

---

**Agent Version**: 1.0.0  
**Last Updated**: October 2025  
**Domain**: Movies, Search, Recommendations
