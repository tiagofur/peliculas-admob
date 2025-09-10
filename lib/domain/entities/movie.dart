import 'package:hive/hive.dart';

import 'watch_providers.dart';

part 'movie.g.dart';

@HiveType(typeId: 0)
class Movie {
  Movie(
      {required this.adult,
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

  /// Crea una instancia de Movie desde JSON
  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] ?? 0,
      adult: json['adult'] ?? false,
      backdropPath: json['backdrop_path'] ?? '',
      genreIds:
          json['genre_ids'] != null ? List<String>.from(json['genre_ids']) : [],
      originalLanguage: json['original_language'] ?? '',
      originalTitle: json['original_title'] ?? '',
      overview: json['overview'] ?? '',
      popularity: json['popularity']?.toDouble() ?? 0.0,
      posterPath: json['poster_path'] ?? '',
      releaseDate: json['release_date'] != null
          ? DateTime.parse(json['release_date'])
          : DateTime.now(),
      title: json['title'] ?? '',
      video: json['video'] ?? false,
      voteAverage: json['vote_average']?.toDouble() ?? 0.0,
      voteCount: json['vote_count'] ?? 0,
      runtime: json['runtime'],
      budget: json['budget'],
      revenue: json['revenue'],
      homepage: json['homepage'],
      imdbId: json['imdb_id'],
      status: json['status'],
      tagline: json['tagline'],
      productionCompanies: json['production_companies'],
      productionCountries: json['production_countries'],
      spokenLanguages: json['spoken_languages'],
      belongsToCollection: json['belongs_to_collection'],
    );
  }

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

  /// Getter para external IDs (para compatibilidad con deep links)
  Map<String, String>? get externalIds {
    // Crear un mapa de IDs externos basado en los campos disponibles
    final Map<String, String> ids = {};
    
    if (imdbId != null && imdbId!.isNotEmpty) {
      ids['imdb'] = imdbId!;
    }
    
    // Aquí se pueden agregar más IDs externos según sea necesario
    // Por ejemplo, si se tienen IDs de Netflix, Amazon, etc.
    
    return ids.isEmpty ? null : ids;
  }

  /// Getter para website URL (alias de homepage)
  String? get websiteUrl => homepage;

  /// Crea una copia de la película con los campos especificados modificados
  Movie copyWith({
    bool? adult,
    String? backdropPath,
    List<String>? genreIds,
    int? id,
    String? originalLanguage,
    String? originalTitle,
    String? overview,
    double? popularity,
    String? posterPath,
    DateTime? releaseDate,
    String? title,
    bool? video,
    double? voteAverage,
    int? voteCount,
    int? runtime,
    int? budget,
    int? revenue,
    String? homepage,
    String? imdbId,
    String? status,
    String? tagline,
    List<String>? productionCompanies,
    List<String>? productionCountries,
    List<String>? spokenLanguages,
    String? belongsToCollection,
    WatchProviders? watchProviders,
    Map<String, dynamic>? credits,
    Map<String, dynamic>? images,
    Map<String, dynamic>? reviews,
    Map<String, dynamic>? similar,
  }) {
    return Movie(
      adult: adult ?? this.adult,
      backdropPath: backdropPath ?? this.backdropPath,
      genreIds: genreIds ?? this.genreIds,
      id: id ?? this.id,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      originalTitle: originalTitle ?? this.originalTitle,
      overview: overview ?? this.overview,
      popularity: popularity ?? this.popularity,
      posterPath: posterPath ?? this.posterPath,
      releaseDate: releaseDate ?? this.releaseDate,
      title: title ?? this.title,
      video: video ?? this.video,
      voteAverage: voteAverage ?? this.voteAverage,
      voteCount: voteCount ?? this.voteCount,
      runtime: runtime ?? this.runtime,
      budget: budget ?? this.budget,
      revenue: revenue ?? this.revenue,
      homepage: homepage ?? this.homepage,
      imdbId: imdbId ?? this.imdbId,
      status: status ?? this.status,
      tagline: tagline ?? this.tagline,
      productionCompanies: productionCompanies ?? this.productionCompanies,
      productionCountries: productionCountries ?? this.productionCountries,
      spokenLanguages: spokenLanguages ?? this.spokenLanguages,
      belongsToCollection: belongsToCollection ?? this.belongsToCollection,
      watchProviders: watchProviders ?? this.watchProviders,
      credits: credits ?? this.credits,
      images: images ?? this.images,
      reviews: reviews ?? this.reviews,
      similar: similar ?? this.similar,
    );
  }

  /// Convierte la película a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'adult': adult,
      'backdrop_path': backdropPath,
      'genre_ids': genreIds,
      'original_language': originalLanguage,
      'original_title': originalTitle,
      'overview': overview,
      'popularity': popularity,
      'poster_path': posterPath,
      'release_date': releaseDate.toIso8601String(),
      'title': title,
      'video': video,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'runtime': runtime,
      'budget': budget,
      'revenue': revenue,
      'homepage': homepage,
      'imdb_id': imdbId,
      'status': status,
      'tagline': tagline,
      'production_companies': productionCompanies,
      'production_countries': productionCountries,
      'spoken_languages': spokenLanguages,
      'belongs_to_collection': belongsToCollection,
    };
  }
}
