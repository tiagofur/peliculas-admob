import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/datasources/local_storage_datasource.dart';
import '../../domain/entities/movie.dart';

class FavoriteMoviesSharedPreferencesDatasource extends LocalStorageDatasource {
  static const String _favoriteMoviesKey = 'favorite_movies';

  @override
  Future<bool> isMovieFavorite(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteMoviesJson = prefs.getStringList(_favoriteMoviesKey) ?? [];

    return favoriteMoviesJson.any((movieJson) {
      final movieData = jsonDecode(movieJson);
      return movieData['id'] == movieId;
    });
  }

  @override
  Future<void> toggleFavorite(Movie movie) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteMoviesJson = prefs.getStringList(_favoriteMoviesKey) ?? [];

    final existingIndex = favoriteMoviesJson.indexWhere((movieJson) {
      final movieData = jsonDecode(movieJson);
      return movieData['id'] == movie.id;
    });

    if (existingIndex != -1) {
      // Remover de favoritos
      favoriteMoviesJson.removeAt(existingIndex);
    } else {
      // Agregar a favoritos
      favoriteMoviesJson.add(jsonEncode(_movieToJson(movie)));
    }

    await prefs.setStringList(_favoriteMoviesKey, favoriteMoviesJson);
  }

  @override
  Future<List<Movie>> loadMovies({int limit = 10, offset = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteMoviesJson = prefs.getStringList(_favoriteMoviesKey) ?? [];

    final allMovies = favoriteMoviesJson
        .map((movieJson) => _movieFromJson(jsonDecode(movieJson)))
        .toList();

    final endIndex = (offset + limit).clamp(0, allMovies.length);

    if (offset >= allMovies.length) return [];

    return allMovies.sublist(offset, endIndex);
  }

  // Métodos de serialización
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
      'releaseDate': movie.releaseDate.toIso8601String(),
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
