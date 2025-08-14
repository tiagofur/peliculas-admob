import 'package:dio/dio.dart';

import '../../config/constants/environment.dart';
import '../../domain/datasources/recommendations_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/entities/watched_movie.dart';


class RecommendationsMoviedbDatasource extends RecommendationsDatasource {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.themoviedb.org/3',
    queryParameters: {
      'api_key': Environment.theMovieDbKey,
      'language': 'es-MX'
    },
  ));

  @override
  Future<List<Recommendation>> getRecommendationsBasedOnFavorites(List<Movie> favoriteMovies) async {
    if (favoriteMovies.isEmpty) return [];

    final recommendations = <Recommendation>[];
    final processedMovies = <int>{};

    // Analizar géneros favoritos
    final genreCount = <String, int>{};
    for (final movie in favoriteMovies) {
      for (final genre in movie.genreIds) {
        genreCount[genre] = (genreCount[genre] ?? 0) + 1;
      }
    }

    // Obtener géneros más populares del usuario
    final topGenres = genreCount.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    // Buscar películas similares por género
    for (final genreEntry in topGenres.take(3)) {
      try {
        final response = await dio.get('/discover/movie', queryParameters: {
          'with_genres': genreEntry.key,
          'sort_by': 'vote_average.desc',
          'vote_count.gte': 100,
          'page': 1,
        });

        final movies = response.data['results'] as List;
        for (final movieData in movies.take(5)) {
          final movieId = movieData['id'] as int;
          if (!processedMovies.contains(movieId) && 
              !favoriteMovies.any((fav) => fav.id == movieId)) {
            
            recommendations.add(Recommendation(
              movieId: movieId,
              title: movieData['title'] ?? '',
              posterPath: movieData['poster_path'] ?? '',
              score: _calculateScore(movieData, genreEntry.value),
              reason: 'Te gusta el género ${_getGenreName(genreEntry.key)}',
              type: RecommendationType.basedOnFavorites,
              tags: ['género', _getGenreName(genreEntry.key)],
            ));
            processedMovies.add(movieId);
          }
        }
      } catch (e) {
        continue;
      }
    }

    // Buscar películas similares a las favoritas
    for (final movie in favoriteMovies.take(3)) {
      try {
        final response = await dio.get('/movie/${movie.id}/similar');
        final movies = response.data['results'] as List;
        
        for (final movieData in movies.take(3)) {
          final movieId = movieData['id'] as int;
          if (!processedMovies.contains(movieId)) {
            recommendations.add(Recommendation(
              movieId: movieId,
              title: movieData['title'] ?? '',
              posterPath: movieData['poster_path'] ?? '',
              score: _calculateScore(movieData, 3),
              reason: 'Similar a "${movie.title}"',
              type: RecommendationType.similar,
              tags: ['similar', movie.title],
            ));
            processedMovies.add(movieId);
          }
        }
      } catch (e) {
        continue;
      }
    }

    recommendations.sort((a, b) => b.score.compareTo(a.score));
    return recommendations.take(20).toList();
  }

  @override
  Future<List<Recommendation>> getRecommendationsBasedOnWatched(List<WatchedMovie> watchedMovies) async {
    if (watchedMovies.isEmpty) return [];

    final recommendations = <Recommendation>[];
    final processedMovies = <int>{};
    final watchedIds = watchedMovies.map((w) => w.id).toSet();

    // Analizar patrones de películas vistas
    final genreCount = <String, int>{};
    final yearCount = <int, int>{};
    
    for (final watchedMovie in watchedMovies) {
      // Obtener detalles de la película vista
      try {
        final response = await dio.get('/movie/${watchedMovie.id}');
        final movieData = response.data;
        
        // Contar géneros
        final genres = movieData['genres'] as List;
        for (final genre in genres) {
          final genreId = genre['id'].toString();
          genreCount[genreId] = (genreCount[genreId] ?? 0) + 1;
        }
        
        // Contar años
        final releaseDate = movieData['release_date'] as String?;
        if (releaseDate != null && releaseDate.isNotEmpty) {
          final year = int.tryParse(releaseDate.substring(0, 4));
          if (year != null) {
            yearCount[year] = (yearCount[year] ?? 0) + 1;
          }
        }
      } catch (e) {
        continue;
      }
    }

    // Recomendar basado en géneros más vistos
    final topGenres = genreCount.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    for (final genreEntry in topGenres.take(2)) {
      try {
        final response = await dio.get('/discover/movie', queryParameters: {
          'with_genres': genreEntry.key,
          'sort_by': 'popularity.desc',
          'page': 1,
        });

        final movies = response.data['results'] as List;
        for (final movieData in movies.take(5)) {
          final movieId = movieData['id'] as int;
          if (!processedMovies.contains(movieId) && !watchedIds.contains(movieId)) {
            recommendations.add(Recommendation(
              movieId: movieId,
              title: movieData['title'] ?? '',
              posterPath: movieData['poster_path'] ?? '',
              score: _calculateScore(movieData, genreEntry.value),
              reason: 'Has visto muchas de ${_getGenreName(genreEntry.key)}',
              type: RecommendationType.basedOnWatched,
              tags: ['historial', _getGenreName(genreEntry.key)],
            ));
            processedMovies.add(movieId);
          }
        }
      } catch (e) {
        continue;
      }
    }

    recommendations.sort((a, b) => b.score.compareTo(a.score));
    return recommendations.take(15).toList();
  }

  @override
  Future<List<Recommendation>> getRecommendationsByGenre(List<String> genres) async {
    final recommendations = <Recommendation>[];
    
    for (final genre in genres) {
      try {
        final response = await dio.get('/discover/movie', queryParameters: {
          'with_genres': genre,
          'sort_by': 'vote_average.desc',
          'vote_count.gte': 50,
          'page': 1,
        });

        final movies = response.data['results'] as List;
        for (final movieData in movies.take(5)) {
          recommendations.add(Recommendation(
            movieId: movieData['id'] as int,
            title: movieData['title'] ?? '',
            posterPath: movieData['poster_path'] ?? '',
            score: _calculateScore(movieData, 2),
            reason: 'Película de ${_getGenreName(genre)}',
            type: RecommendationType.basedOnGenre,
            tags: ['género', _getGenreName(genre)],
          ));
        }
      } catch (e) {
        continue;
      }
    }

    recommendations.sort((a, b) => b.score.compareTo(a.score));
    return recommendations;
  }

  @override
  Future<List<Recommendation>> getRecommendationsByMood(String mood) async {
    final moodFilters = _getMoodFilters(mood);
    final recommendations = <Recommendation>[];

    try {
      final response = await dio.get('/discover/movie', queryParameters: {
        ...moodFilters,
        'page': 1,
      });

      final movies = response.data['results'] as List;
      for (final movieData in movies.take(10)) {
        recommendations.add(Recommendation(
          movieId: movieData['id'] as int,
          title: movieData['title'] ?? '',
          posterPath: movieData['poster_path'] ?? '',
          score: _calculateScore(movieData, 3),
          reason: 'Perfect para cuando estás ${_getMoodDescription(mood)}',
          type: RecommendationType.mood,
          tags: ['estado de ánimo', mood],
        ));
      }
    } catch (e) {
      // Handle error
    }

    return recommendations;
  }

  @override
  Future<List<Recommendation>> getTrendingRecommendations() async {
    final recommendations = <Recommendation>[];

    try {
      final response = await dio.get('/trending/movie/week');
      final movies = response.data['results'] as List;

      for (final movieData in movies.take(10)) {
        recommendations.add(Recommendation(
          movieId: movieData['id'] as int,
          title: movieData['title'] ?? '',
          posterPath: movieData['poster_path'] ?? '',
          score: _calculateScore(movieData, 4),
          reason: 'Tendencia esta semana',
          type: RecommendationType.trending,
          tags: ['trending', 'popular'],
        ));
      }
    } catch (e) {
      // Handle error
    }

    return recommendations;
  }

  @override
  Future<List<Recommendation>> getSimilarMovies(int movieId) async {
    final recommendations = <Recommendation>[];

    try {
      final response = await dio.get('/movie/$movieId/similar');
      final movies = response.data['results'] as List;

      for (final movieData in movies.take(10)) {
        recommendations.add(Recommendation(
          movieId: movieData['id'] as int,
          title: movieData['title'] ?? '',
          posterPath: movieData['poster_path'] ?? '',
          score: _calculateScore(movieData, 3),
          reason: 'Similar a esta película',
          type: RecommendationType.similar,
          tags: ['similar'],
        ));
      }
    } catch (e) {
      // Handle error
    }

    return recommendations;
  }

  @override
  Future<UserPreferences> analyzeUserPreferences(List<Movie> favoriteMovies, List<WatchedMovie> watchedMovies) async {
    final genreCount = <String, int>{};
    final genreRating = <String, double>{};
    final actors = <String>{};
    final directors = <String>{};
    final languages = <String>{};
    double totalRating = 0;
    int ratingCount = 0;

    // Analizar películas favoritas
    for (final movie in favoriteMovies) {
      for (final genre in movie.genreIds) {
        genreCount[genre] = (genreCount[genre] ?? 0) + 1;
        genreRating[genre] = (genreRating[genre] ?? 0) + movie.voteAverage;
      }
      languages.add(movie.originalLanguage);
      totalRating += movie.voteAverage;
      ratingCount++;

      // Obtener actores y directores
      try {
        final creditsResponse = await dio.get('/movie/${movie.id}/credits');
        final cast = creditsResponse.data['cast'] as List;
        final crew = creditsResponse.data['crew'] as List;

        for (final actor in cast.take(3)) {
          actors.add(actor['name'] ?? '');
        }

        for (final member in crew) {
          if (member['job'] == 'Director') {
            directors.add(member['name'] ?? '');
          }
        }
      } catch (e) {
        // Continue without credits
      }
    }

    // Normalizar ratings por género
    final normalizedGenreRating = <String, double>{};
    for (final entry in genreRating.entries) {
      normalizedGenreRating[entry.key] = entry.value / (genreCount[entry.key] ?? 1);
    }

    return UserPreferences(
      favoriteGenres: (genreCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
          .take(5)
          .map((e) => e.key)
          .toList(),
      favoriteActors: actors.take(10).toList(),
      favoriteDirectors: directors.take(5).toList(),
      averageRatingPreference: ratingCount > 0 ? totalRating / ratingCount : 7.0,
      preferredLanguages: languages.take(3).toList(),
      genreCount: genreCount,
      genreRating: normalizedGenreRating,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<List<RecommendationCategory>> getDiscoveryCategories() async {
    return [
      RecommendationCategory(
        id: 'romantic_night',
        title: 'Para ver en pareja',
        description: 'Películas perfectas para una noche romántica',
        icon: 'favorite',
        moods: ['romántico', 'relajado'],
        genres: ['10749'], // Romance
        filters: {'vote_average.gte': 7.0},
      ),
      RecommendationCategory(
        id: 'hidden_gems',
        title: 'Joyas ocultas',
        description: 'Películas increíbles que pocos conocen',
        icon: 'diamond',
        filters: {
          'vote_average.gte': 7.5,
          'vote_count.lte': 1000,
          'sort_by': 'vote_average.desc'
        },
      ),
      RecommendationCategory(
        id: 'classic_forgotten',
        title: 'Clásicos olvidados',
        description: 'Grandes películas del pasado que vale la pena redescubrir',
        icon: 'history',
        filters: {
          'primary_release_date.lte': '1999-12-31',
          'vote_average.gte': 7.0,
          'sort_by': 'vote_average.desc'
        },
      ),
      RecommendationCategory(
        id: 'weekend_fun',
        title: 'Para el fin de semana',
        description: 'Entretenimiento ligero y divertido',
        icon: 'weekend',
        genres: ['35', '28'], // Comedy, Action
        filters: {'vote_average.gte': 6.5},
      ),
      RecommendationCategory(
        id: 'mind_bending',
        title: 'Para pensar',
        description: 'Películas que te harán reflexionar',
        icon: 'psychology',
        genres: ['878', '53'], // Sci-Fi, Thriller
        filters: {'vote_average.gte': 7.0},
      ),
      RecommendationCategory(
        id: 'feel_good',
        title: 'Para sentirse bien',
        description: 'Películas que alegran el día',
        icon: 'sentiment_very_satisfied',
        genres: ['35', '10751'], // Comedy, Family
        filters: {'vote_average.gte': 6.8},
      ),
    ];
  }

  double _calculateScore(Map<String, dynamic> movieData, int baseScore) {
    final voteAverage = (movieData['vote_average'] as num?)?.toDouble() ?? 5.0;
    final popularity = (movieData['popularity'] as num?)?.toDouble() ?? 1.0;
    final voteCount = (movieData['vote_count'] as num?)?.toInt() ?? 0;
    
    // Fórmula de scoring personalizada
    double score = baseScore.toDouble();
    score += (voteAverage - 5.0) * 0.5; // Bonus por rating
    score += (popularity / 100) * 0.3; // Bonus por popularidad
    score += (voteCount / 1000) * 0.2; // Bonus por cantidad de votos
    
    return score.clamp(0.0, 10.0);
  }

  String _getGenreName(String genreId) {
    final genres = {
      '28': 'Acción',
      '12': 'Aventura',
      '16': 'Animación',
      '35': 'Comedia',
      '80': 'Crimen',
      '99': 'Documental',
      '18': 'Drama',
      '10751': 'Familiar',
      '14': 'Fantasía',
      '36': 'Historia',
      '27': 'Terror',
      '10402': 'Música',
      '9648': 'Misterio',
      '10749': 'Romance',
      '878': 'Ciencia ficción',
      '10770': 'Película de TV',
      '53': 'Suspenso',
      '10752': 'Guerra',
      '37': 'Western',
    };
    return genres[genreId] ?? 'Desconocido';
  }

  Map<String, dynamic> _getMoodFilters(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
      case 'feliz':
        return {
          'with_genres': '35,10751', // Comedy, Family
          'sort_by': 'vote_average.desc',
          'vote_average.gte': 6.5,
        };
      case 'sad':
      case 'triste':
        return {
          'with_genres': '18', // Drama
          'sort_by': 'vote_average.desc',
          'vote_average.gte': 7.0,
        };
      case 'excited':
      case 'emocionado':
        return {
          'with_genres': '28,12', // Action, Adventure
          'sort_by': 'popularity.desc',
          'vote_average.gte': 6.0,
        };
      case 'romantic':
      case 'romántico':
        return {
          'with_genres': '10749', // Romance
          'sort_by': 'vote_average.desc',
          'vote_average.gte': 6.5,
        };
      case 'scared':
      case 'asustado':
        return {
          'with_genres': '27', // Horror
          'sort_by': 'vote_average.desc',
          'vote_average.gte': 6.0,
        };
      default:
        return {
          'sort_by': 'popularity.desc',
          'vote_average.gte': 6.5,
        };
    }
  }

  String _getMoodDescription(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
      case 'feliz':
        return 'de buen humor';
      case 'sad':
      case 'triste':
        return 'melancólico';
      case 'excited':
      case 'emocionado':
        return 'con ganas de acción';
      case 'romantic':
      case 'romántico':
        return 'romántico';
      case 'scared':
      case 'asustado':
        return 'con ganas de sustos';
      default:
        return 'relajado';
    }
  }
}