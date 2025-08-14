import 'movie.dart';
import 'watched_movie.dart';
import 'custom_list.dart';

class UserStats {
  UserStats({
    required this.totalFavorites,
    required this.totalWatched,
    required this.totalLists,
    required this.totalMoviesInLists,
    required this.averageRating,
    required this.mostActiveMonth,
    required this.preferredDecade,
    required this.topGenres,
    required this.moviesThisMonth,
    required this.moviesThisYear,
    required this.discoveryRate,
    required this.userType,
  });

  factory UserStats.fromMovies({
    required List<Movie> favoriteMovies,
    required List<WatchedMovie> watchedMovies,
    required List<CustomList> customLists,
    required List<CustomList> defaultLists,
  }) {
    final totalFavorites = favoriteMovies.length;
    final totalWatched = watchedMovies.length;
    final totalLists = customLists.length + defaultLists.length;
    final totalMoviesInLists = customLists.fold(0, (sum, list) => sum + list.movieIds.length) +
                              defaultLists.fold(0, (sum, list) => sum + list.movieIds.length);
    
    // Calcular calificación promedio de favoritas
    final averageRating = favoriteMovies.isEmpty 
        ? 0.0 
        : favoriteMovies.map((m) => m.voteAverage).reduce((a, b) => a + b) / favoriteMovies.length;
    
    // Mes más activo (simulado)
    final monthCounts = <int, int>{};
    for (final movie in watchedMovies) {
      final month = movie.watchedDate.month;
      monthCounts[month] = (monthCounts[month] ?? 0) + 1;
    }
    final mostActiveMonth = monthCounts.isEmpty 
        ? 'N/A' 
        : getMonthName(monthCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key);
    
    // Década preferida
    final decadeCounts = <String, int>{};
    for (final movie in favoriteMovies) {
      final decade = '${(movie.releaseDate.year ~/ 10) * 10}s';
      decadeCounts[decade] = (decadeCounts[decade] ?? 0) + 1;
    }
    final preferredDecade = decadeCounts.isEmpty 
        ? 'N/A' 
        : decadeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    
    // Géneros principales
    final genreCounts = <String, int>{};
    for (final movie in favoriteMovies) {
      for (final genre in movie.genreIds) {
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }
    }
    final topGenres = genreCounts.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    final topGenresList = topGenres.take(3).map((e) => e.key).toList();
    
    // Películas este mes y año (simulado)
    final now = DateTime.now();
    final moviesThisMonth = watchedMovies.where((m) => 
        m.watchedDate.year == now.year && m.watchedDate.month == now.month).length;
    final moviesThisYear = watchedMovies.where((m) => 
        m.watchedDate.year == now.year).length;
    
    // Tasa de descubrimiento
    final discoveryRate = totalWatched == 0 ? 0.0 : (totalFavorites / totalWatched) * 100;
    
    // Tipo de usuario
    String userType;
    if (totalFavorites > 50) {
      userType = 'Cinéfilo';
    } else if (totalFavorites > 20) {
      userType = 'Entusiasta';
    } else if (totalFavorites > 5) {
      userType = 'Aficionado';
    } else {
      userType = 'Casual';
    }
    
    return UserStats(
      totalFavorites: totalFavorites,
      totalWatched: totalWatched,
      totalLists: totalLists,
      totalMoviesInLists: totalMoviesInLists.toInt(),
      averageRating: averageRating,
      mostActiveMonth: mostActiveMonth,
      preferredDecade: preferredDecade,
      topGenres: topGenresList,
      moviesThisMonth: moviesThisMonth,
      moviesThisYear: moviesThisYear,
      discoveryRate: discoveryRate,
      userType: userType,
    );
  }

  final int totalFavorites;
  final int totalWatched;
  final int totalLists;
  final int totalMoviesInLists;
  final double averageRating;
  final String mostActiveMonth;
  final String preferredDecade;
  final List<String> topGenres;
  final int moviesThisMonth;
  final int moviesThisYear;
  final double discoveryRate;
  final String userType;

  static String getMonthName(int month) {
    const months = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return months[month];
  }
}