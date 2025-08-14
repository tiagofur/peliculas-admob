import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/datasources/watched_movies_datasource.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/watched_movie.dart';

class WatchedMoviesSharedPreferencesDatasource extends WatchedMoviesDatasource {
  static const String _watchedMoviesKey = 'watched_movies';

  @override
  Future<void> markAsWatched(Movie movie) async {
    final prefs = await SharedPreferences.getInstance();
    final watchedMoviesJson = prefs.getStringList(_watchedMoviesKey) ?? [];
    
    // Verificar si ya está marcada como vista
    final alreadyWatched = watchedMoviesJson.any((watchedJson) {
      final watchedData = jsonDecode(watchedJson);
      return watchedData['movie']['id'] == movie.id;
    });

    if (!alreadyWatched) {
      final watchedMovie = WatchedMovie(
        movie: movie,
        watchedDate: DateTime.now(),
      );
      watchedMoviesJson.add(jsonEncode(_watchedMovieToJson(watchedMovie)));
      await prefs.setStringList(_watchedMoviesKey, watchedMoviesJson);
    }
  }

  @override
  Future<void> removeFromWatched(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    final watchedMoviesJson = prefs.getStringList(_watchedMoviesKey) ?? [];
    
    watchedMoviesJson.removeWhere((watchedJson) {
      final watchedData = jsonDecode(watchedJson);
      return watchedData['movie']['id'] == movieId;
    });

    await prefs.setStringList(_watchedMoviesKey, watchedMoviesJson);
  }

  @override
  Future<bool> isMovieWatched(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    final watchedMoviesJson = prefs.getStringList(_watchedMoviesKey) ?? [];
    
    return watchedMoviesJson.any((watchedJson) {
      final watchedData = jsonDecode(watchedJson);
      return watchedData['movie']['id'] == movieId;
    });
  }

  @override
  Future<List<WatchedMovie>> loadWatchedMovies({int limit = 10, int offset = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final watchedMoviesJson = prefs.getStringList(_watchedMoviesKey) ?? [];
    
    final allWatchedMovies = watchedMoviesJson
        .map((watchedJson) => _watchedMovieFromJson(jsonDecode(watchedJson)))
        .toList();
    
    // Ordenar por fecha de visualización (más recientes primero)
    allWatchedMovies.sort((a, b) => b.watchedDate.compareTo(a.watchedDate));
    
    final endIndex = (offset + limit).clamp(0, allWatchedMovies.length);
    
    if (offset >= allWatchedMovies.length) return [];
    
    return allWatchedMovies.sublist(offset, endIndex);
  }

  // Métodos de serialización
  Map<String, dynamic> _watchedMovieToJson(WatchedMovie watchedMovie) {
    return {
      'movie': _movieToJson(watchedMovie.movie),
      'watchedDate': watchedMovie.watchedDate.toIso8601String(),
    };
  }

  WatchedMovie _watchedMovieFromJson(Map<String, dynamic> json) {
    return WatchedMovie(
      movie: _movieFromJson(json['movie'] as Map<String, dynamic>),
      watchedDate: DateTime.parse(json['watchedDate'] as String),
    );
  }

  Map<String, dynamic> _movieToJson(Movie movie) {
    return {
      'id': movie.id,
      'adult': movie.adult,
      'backdropPath': movie.backdropPath,
      'genreIds': movie.genreIds,
      'originalLanguage': movie.originalLanguage,
      'originalTitle': movie.originalTitle,
      'overview': movie.overview,
      'popularity': movie.popularity,
      'posterPath': movie.posterPath,
      'releaseDate': movie.releaseDate?.toIso8601String(),
      'title': movie.title,
      'video': movie.video,
      'voteAverage': movie.voteAverage,
      'voteCount': movie.voteCount,
    };
  }

  Movie _movieFromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] as int,
      adult: json['adult'] as bool,
      backdropPath: json['backdropPath'] as String,
      genreIds: List<String>.from(json['genreIds'] as List),
      originalLanguage: json['originalLanguage'] as String,
      originalTitle: json['originalTitle'] as String,
      overview: json['overview'] as String,
      popularity: (json['popularity'] as num).toDouble(),
      posterPath: json['posterPath'] as String,
      releaseDate: json['releaseDate'] != null 
          ? DateTime.parse(json['releaseDate'] as String)
          : DateTime(1900),
      title: json['title'] as String,
      video: json['video'] as bool,
      voteAverage: (json['voteAverage'] as num).toDouble(),
      voteCount: json['voteCount'] as int,
    );
  }
}