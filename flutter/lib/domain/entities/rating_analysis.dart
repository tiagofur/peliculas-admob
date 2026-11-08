import 'movie.dart';
import 'watched_movie.dart';

class RatingAnalysis {
  RatingAnalysis({
    required this.averageFavoriteRating,
    required this.averageWatchedRating,
    required this.ratingDistribution,
    required this.qualityPreference,
    required this.criticalAlignment,
  });

  factory RatingAnalysis.fromMovies({
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
  }) {
    // Calificación promedio de favoritas
    final averageFavoriteRating = favoriteMovies.isEmpty
        ? 0.0
        : favoriteMovies.map((m) => m.voteAverage).reduce((a, b) => a + b) /
            favoriteMovies.length;

    // Calificación promedio de vistas
    final averageWatchedRating = watchedMovies.isEmpty
        ? 0.0
        : watchedMovies
                .map((m) => _getSimulatedRating(m.movie.id))
                .reduce((a, b) => a + b) /
            watchedMovies.length;

    // Distribución de calificaciones
    final ratingDistribution = <String, int>{
      '9.0-10.0': 0,
      '8.0-8.9': 0,
      '7.0-7.9': 0,
      '6.0-6.9': 0,
      '5.0-5.9': 0,
      '<5.0': 0,
    };

    for (final movie in favoriteMovies) {
      final rating = movie.voteAverage;
      if (rating >= 9.0) {
        ratingDistribution['9.0-10.0'] = ratingDistribution['9.0-10.0']! + 1;
      } else if (rating >= 8.0) {
        ratingDistribution['8.0-8.9'] = ratingDistribution['8.0-8.9']! + 1;
      } else if (rating >= 7.0) {
        ratingDistribution['7.0-7.9'] = ratingDistribution['7.0-7.9']! + 1;
      } else if (rating >= 6.0) {
        ratingDistribution['6.0-6.9'] = ratingDistribution['6.0-6.9']! + 1;
      } else if (rating >= 5.0) {
        ratingDistribution['5.0-5.9'] = ratingDistribution['5.0-5.9']! + 1;
      } else {
        ratingDistribution['<5.0'] = ratingDistribution['<5.0']! + 1;
      }
    }

    // Preferencia de calidad
    String qualityPreference;
    if (averageFavoriteRating >= 8.0) {
      qualityPreference = 'High';
    } else if (averageFavoriteRating >= 6.5) {
      qualityPreference = 'Medium';
    } else {
      qualityPreference = 'Mixed';
    }

    // Alineación crítica
    final highRatedMovies =
        favoriteMovies.where((m) => m.voteAverage >= 7.5).length;
    final criticalAlignment = favoriteMovies.isEmpty
        ? 0.0
        : (highRatedMovies / favoriteMovies.length) * 100;

    return RatingAnalysis(
      averageFavoriteRating: averageFavoriteRating,
      averageWatchedRating: averageWatchedRating,
      ratingDistribution: ratingDistribution,
      qualityPreference: qualityPreference,
      criticalAlignment: criticalAlignment,
    );
  }

  final double averageFavoriteRating;
  final double averageWatchedRating;
  final Map<String, int> ratingDistribution;
  final String qualityPreference;
  final double criticalAlignment;

  static double _getSimulatedRating(int movieId) {
    return 5.0 + (movieId % 50) / 10.0;
  }
}
