import 'dart:math';
import 'watched_movie.dart';
import 'user_stats.dart';

class ActivityPatterns {
  ActivityPatterns({
    required this.moviesByMonth,
    required this.moviesByDayOfWeek,
    required this.mostActiveMonth,
    required this.mostActiveDay,
    required this.consistency,
    required this.activityTrends,
  });

  factory ActivityPatterns.fromWatchedMovies(List<WatchedMovie> watchedMovies) {
    final moviesByMonth = <int, int>{};
    final moviesByDayOfWeek = <int, int>{};
    
    for (final movie in watchedMovies) {
      final month = movie.watchedDate.month;
      final dayOfWeek = movie.watchedDate.weekday;
      
      moviesByMonth[month] = (moviesByMonth[month] ?? 0) + 1;
      moviesByDayOfWeek[dayOfWeek] = (moviesByDayOfWeek[dayOfWeek] ?? 0) + 1;
    }
    
    // Mes más activo
    final mostActiveMonth = moviesByMonth.isEmpty 
        ? 'N/A' 
        : UserStats.getMonthName(moviesByMonth.entries.reduce((a, b) => a.value > b.value ? a : b).key);
    
    // Día más activo
    const dayNames = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final mostActiveDay = moviesByDayOfWeek.isEmpty 
        ? 'N/A' 
        : dayNames[moviesByDayOfWeek.entries.reduce((a, b) => a.value > b.value ? a : b).key];
    
    // Consistencia
    final consistency = _calculateConsistency(moviesByMonth.values.toList());
    
    // Tendencias de actividad
    final activityTrends = _generateActivityTrends(moviesByMonth, moviesByDayOfWeek);
    
    return ActivityPatterns(
      moviesByMonth: moviesByMonth,
      moviesByDayOfWeek: moviesByDayOfWeek,
      mostActiveMonth: mostActiveMonth,
      mostActiveDay: mostActiveDay,
      consistency: consistency,
      activityTrends: activityTrends,
    );
  }

  final Map<int, int> moviesByMonth;
  final Map<int, int> moviesByDayOfWeek;
  final String mostActiveMonth;
  final String mostActiveDay;
  final double consistency;
  final List<String> activityTrends;

  static double _calculateConsistency(List<int> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(variance);
    
    return (1.0 / (1.0 + stdDev)) * 100;
  }

  static List<String> _generateActivityTrends(Map<int, int> monthlyData, Map<int, int> weeklyData) {
    final trends = <String>[];
    
    if (monthlyData.isNotEmpty) {
      final maxMonth = monthlyData.entries.reduce((a, b) => a.value > b.value ? a : b);
      trends.add('Más activo en ${UserStats.getMonthName(maxMonth.key)}');
    }
    
    if (weeklyData.isNotEmpty) {
      final weekendMovies = (weeklyData[6] ?? 0) + (weeklyData[7] ?? 0);
      final weekdayMovies = weeklyData.values.reduce((a, b) => a + b) - weekendMovies;
      
      if (weekendMovies > weekdayMovies) {
        trends.add('Prefiere ver películas los fines de semana');
      } else {
        trends.add('Ve películas durante la semana');
      }
    }
    
    return trends;
  }
}