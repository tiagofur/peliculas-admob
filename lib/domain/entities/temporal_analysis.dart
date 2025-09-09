import 'movie.dart';
import 'watched_movie.dart';

class TemporalAnalysis {
  TemporalAnalysis({
    required this.moviesByYear,
    required this.moviesByDecade,
    required this.preferredEra,
    required this.mostActiveYears,
    required this.vintagePreference,
  });

  factory TemporalAnalysis.fromMovies({
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
  }) {
    final moviesByYear = <int, int>{};
    final moviesByDecade = <String, int>{};

    // Analizar años de películas favoritas
    for (final movie in favoriteMovies) {
      final year = movie.releaseDate.year;
      final decade = '${(year ~/ 10) * 10}s';

      moviesByYear[year] = (moviesByYear[year] ?? 0) + 1;
      moviesByDecade[decade] = (moviesByDecade[decade] ?? 0) + 1;
    }

    // Era preferida
    final preferredEra = moviesByDecade.isEmpty
        ? 'N/A'
        : moviesByDecade.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

    // Años más activos
    final sortedYears = moviesByYear.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mostActiveYears = sortedYears.take(3).map((e) => e.key).toList();

    // Preferencia vintage
    final vintageMovies =
        favoriteMovies.where((m) => m.releaseDate.year < 2000).length;
    final vintagePreference = favoriteMovies.isEmpty
        ? 0.0
        : (vintageMovies / favoriteMovies.length) * 100;

    return TemporalAnalysis(
      moviesByYear: moviesByYear,
      moviesByDecade: moviesByDecade,
      preferredEra: preferredEra,
      mostActiveYears: mostActiveYears,
      vintagePreference: vintagePreference,
    );
  }

  final Map<int, int> moviesByYear;
  final Map<String, int> moviesByDecade;
  final String preferredEra;
  final List<int> mostActiveYears;
  final double vintagePreference;
}
