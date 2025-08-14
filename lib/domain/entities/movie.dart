import 'package:hive/hive.dart';
import 'watch_providers.dart';

part 'movie.g.dart';

@HiveType(typeId: 0)
class Movie {
  Movie({
      required this.adult,
      required this.backdropPath,
      required this.genreIds,
      required this.id,
      required this.originalLanguage,
      required this.originalTitle,
      required this.overview,
      required this.popularity,
      required this.posterPath,
      required this.releaseDate,
      required this.title,
      required this.video,
      required this.voteAverage,
      required this.voteCount,
      this.runtime,
      this.budget,
      this.revenue,
      this.homepage,
      this.imdbId,
      this.status,
      this.tagline,
      this.productionCompanies,
      this.productionCountries,
      this.spokenLanguages,
      this.belongsToCollection,
      this.watchProviders,
      this.credits,
      this.images,
      this.reviews,
      this.similar});

  @HiveField(0)
  final bool adult;
  @HiveField(1)
  final String backdropPath;
  @HiveField(2)
  final List<String> genreIds;
  @HiveField(3)
  final int id;
  @HiveField(4)
  final String originalLanguage;
  @HiveField(5)
  final String originalTitle;
  @HiveField(6)
  final String overview;
  @HiveField(7)
  final double popularity;
  @HiveField(8)
  final String posterPath;
  @HiveField(9)
  final DateTime releaseDate;
  @HiveField(10)
  final String title;
  @HiveField(11)
  final bool video;
  @HiveField(12)
  final double voteAverage;
  @HiveField(13)
  final int voteCount;
  @HiveField(14)
  final int? runtime;
  @HiveField(15)
  final int? budget;
  @HiveField(16)
  final int? revenue;
  @HiveField(17)
  final String? homepage;
  @HiveField(18)
  final String? imdbId;
  @HiveField(19)
  final String? status;
  @HiveField(20)
  final String? tagline;
  @HiveField(21)
  final List<String>? productionCompanies;
  @HiveField(22)
  final List<String>? productionCountries;
  @HiveField(23)
  final List<String>? spokenLanguages;
  @HiveField(24)
  final String? belongsToCollection;
  @HiveField(25)
  final WatchProviders? watchProviders;
  // Los siguientes campos no se almacenan en Hive por ser complejos
  final Map<String, dynamic>? credits;
  final Map<String, dynamic>? images;
  final Map<String, dynamic>? reviews;
  final Map<String, dynamic>? similar;
}
