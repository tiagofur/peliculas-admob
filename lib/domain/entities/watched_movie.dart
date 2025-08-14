import 'package:hive/hive.dart';
import 'movie.dart';

part 'watched_movie.g.dart';

@HiveType(typeId: 1)
class WatchedMovie {
  WatchedMovie({
    required this.movie,
    required this.watchedDate,
  });

  @HiveField(0)
  final Movie movie;
  
  @HiveField(1)
  final DateTime watchedDate;

  // Métodos de conveniencia para acceder a propiedades de la película
  int get id => movie.id;
  String get title => movie.title;
  String get posterPath => movie.posterPath;
  String get backdropPath => movie.backdropPath;
  String get overview => movie.overview;
  double get voteAverage => movie.voteAverage;
  DateTime get releaseDate => movie.releaseDate;
  List<String> get genreIds => movie.genreIds;
}