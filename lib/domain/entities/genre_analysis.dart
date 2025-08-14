import 'movie.dart';
import 'watched_movie.dart';

class GenreAnalysis {
  GenreAnalysis({
    required this.favoriteGenres,
    required this.watchedGenres,
    required this.topFavoriteGenres,
    required this.topWatchedGenres,
    required this.underexploredGenres,
    required this.genreDiversity,
  });

  factory GenreAnalysis.fromMovies({
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
  }) {
    final favoriteGenres = <String, int>{};
    final watchedGenres = <String, int>{};
    
    // Contar géneros en favoritas
    for (final movie in favoriteMovies) {
      for (final genre in movie.genreIds) {
        favoriteGenres[genre] = (favoriteGenres[genre] ?? 0) + 1;
      }
    }
    
    // Contar géneros en vistas
    for (final watchedMovie in watchedMovies) {
      final genres = _getSimulatedGenres(watchedMovie.movie.id);
      for (final genre in genres) {
        watchedGenres[genre] = (watchedGenres[genre] ?? 0) + 1;
      }
    }
    
    // Top géneros
    final topFavoriteGenres = favoriteGenres.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    final topFavoriteGenresList = topFavoriteGenres
        .take(5)
        .map((e) => e.key)
        .toList();
    
    final topWatchedGenres = watchedGenres.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    final topWatchedGenresList = topWatchedGenres
        .take(5)
        .map((e) => e.key)
        .toList();
    
    // Géneros poco explorados
    final allGenres = {
      'Acción', 'Aventura', 'Animación', 'Comedia', 'Crimen', 'Documental',
      'Drama', 'Familia', 'Fantasía', 'Historia', 'Terror', 'Música',
      'Misterio', 'Romance', 'Ciencia ficción', 'Suspense', 'Guerra', 'Western'
    };
    
    final exploredGenres = {...favoriteGenres.keys, ...watchedGenres.keys};
    final underexploredGenres = allGenres.difference(exploredGenres).toList();
    
    // Diversidad de géneros
    final genreDiversity = exploredGenres.length / allGenres.length;
    
    return GenreAnalysis(
      favoriteGenres: favoriteGenres,
      watchedGenres: watchedGenres,
      topFavoriteGenres: topFavoriteGenresList,
      topWatchedGenres: topWatchedGenresList,
      underexploredGenres: underexploredGenres,
      genreDiversity: genreDiversity,
    );
  }

  final Map<String, int> favoriteGenres;
  final Map<String, int> watchedGenres;
  final List<String> topFavoriteGenres;
  final List<String> topWatchedGenres;
  final List<String> underexploredGenres;
  final double genreDiversity;

  static List<String> _getSimulatedGenres(int movieId) {
    final genres = ['Acción', 'Drama', 'Comedia', 'Suspense', 'Romance'];
    return [genres[movieId % genres.length]];
  }
}