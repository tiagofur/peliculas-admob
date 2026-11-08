import '../../../domain/entities/watch_providers.dart';
import 'credits.dart';
import 'images.dart';
import 'reviews.dart';
import 'watch_providers_response.dart';

class MovieDetails {
  MovieDetails({
    required this.adult,
    required this.backdropPath,
    required this.belongsToCollection,
    required this.budget,
    required this.genres,
    required this.homepage,
    required this.id,
    required this.imdbId,
    required this.originalLanguage,
    required this.originalTitle,
    required this.overview,
    required this.popularity,
    required this.posterPath,
    required this.productionCompanies,
    required this.productionCountries,
    required this.releaseDate,
    required this.revenue,
    required this.runtime,
    required this.spokenLanguages,
    required this.status,
    required this.tagline,
    required this.title,
    required this.video,
    required this.voteAverage,
    required this.voteCount,
    this.credits,
    this.images,
    this.reviews,
    this.similar,
    this.watchProviders,
  });
  factory MovieDetails.fromJson(Map<String, dynamic> json) => MovieDetails(
        adult: json['adult'] ?? false,
        backdropPath: json['backdrop_path'] ?? '',
        belongsToCollection: json['belongs_to_collection'] == null
            ? null
            : BelongsToCollection.fromJson(json['belongs_to_collection']),
        budget: json['budget']?.toInt(),
        genres: json['genres'] != null
            ? List<Genre>.from(json['genres'].map((x) => Genre.fromJson(x)))
            : <Genre>[],
        homepage: json['homepage'] ?? '',
        id: json['id'] ?? 0,
        imdbId: json['imdb_id'],
        originalLanguage: json['original_language'] ?? '',
        originalTitle: json['original_title'] ?? '',
        overview: json['overview'] ?? '',
        popularity: json['popularity']?.toDouble(),
        posterPath: json['poster_path'] ?? '',
        productionCompanies: json['production_companies'] != null
            ? List<ProductionCompany>.from(json['production_companies']
                .map((x) => ProductionCompany.fromJson(x)))
            : <ProductionCompany>[],
        productionCountries: json['production_countries'] != null
            ? List<ProductionCountry>.from(json['production_countries']
                .map((x) => ProductionCountry.fromJson(x)))
            : <ProductionCountry>[],
        releaseDate: json['release_date'] != null
            ? DateTime.parse(json['release_date'])
            : null,
        revenue: json['revenue']?.toInt(),
        runtime: json['runtime']?.toInt(),
        spokenLanguages: json['spoken_languages'] != null
            ? List<SpokenLanguage>.from(
                json['spoken_languages'].map((x) => SpokenLanguage.fromJson(x)))
            : <SpokenLanguage>[],
        status: json['status'] ?? '',
        tagline: json['tagline'] ?? '',
        title: json['title'] ?? '',
        video: json['video'] ?? false,
        voteAverage: json['vote_average']?.toDouble(),
        voteCount: json['vote_count']?.toInt(),
        credits:
            json['credits'] != null ? Credits.fromJson(json['credits']) : null,
        images: json['images'] != null ? Images.fromJson(json['images']) : null,
        reviews:
            json['reviews'] != null ? Reviews.fromJson(json['reviews']) : null,
        similar: json['similar'],
        watchProviders: json['watch/providers'] != null
            ? WatchProvidersResponse.fromJson(json['watch/providers'])
                .primaryProviders
            : null,
      );

  final bool adult;
  final String backdropPath;
  final BelongsToCollection? belongsToCollection;
  final int? budget;
  final List<Genre> genres;
  final String? homepage;
  final int id;
  final String? imdbId;
  final String originalLanguage;
  final String originalTitle;
  final String? overview;
  final double? popularity;
  final String? posterPath;
  final List<ProductionCompany> productionCompanies;
  final List<ProductionCountry> productionCountries;
  final DateTime? releaseDate;
  final int? revenue;
  final int? runtime;
  final List<SpokenLanguage> spokenLanguages;
  final String status;
  final String tagline;
  final String title;
  final bool video;
  final double? voteAverage;
  final int? voteCount;
  final Credits? credits;
  final Images? images;
  final Reviews? reviews;
  final Map<String, dynamic>? similar;
  final WatchProviders? watchProviders;

  Map<String, dynamic> toJson() => {
        'adult': adult,
        'backdrop_path': backdropPath,
        'belongs_to_collection': belongsToCollection?.toJson(),
        'budget': budget,
        'genres': List<dynamic>.from(genres.map((x) => x.toJson())),
        'homepage': homepage,
        'id': id,
        'imdb_id': imdbId,
        'original_language': originalLanguage,
        'original_title': originalTitle,
        'overview': overview,
        'popularity': popularity,
        'poster_path': posterPath,
        'production_companies':
            List<dynamic>.from(productionCompanies.map((x) => x.toJson())),
        'production_countries':
            List<dynamic>.from(productionCountries.map((x) => x.toJson())),
        'release_date': releaseDate != null
            ? "${releaseDate?.year.toString().padLeft(4, '0')}-${releaseDate?.month.toString().padLeft(2, '0')}-${releaseDate?.day.toString().padLeft(2, '0')}"
            : null,
        'revenue': revenue,
        'runtime': runtime,
        'spoken_languages':
            List<dynamic>.from(spokenLanguages.map((x) => x.toJson())),
        'status': status,
        'tagline': tagline,
        'title': title,
        'video': video,
        'vote_average': voteAverage,
        'vote_count': voteCount,
        'credits': credits?.toJson(),
        'images': images?.toJson(),
        'reviews': reviews?.toJson(),
        'similar': similar,
        'watch/providers': watchProviders?.toJson(),
      };
}

class BelongsToCollection {
  const BelongsToCollection({
    required this.id,
    required this.name,
    required this.posterPath,
    required this.backdropPath,
  });
  factory BelongsToCollection.fromJson(Map<String, dynamic> json) =>
      BelongsToCollection(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        posterPath: json['poster_path'] ?? '',
        backdropPath: json['backdrop_path'] ?? '',
      );

  final int id;
  final String name;
  final String posterPath;
  final String backdropPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
      };
}

class Genre {
  const Genre({
    required this.id,
    required this.name,
  });
  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
      );

  final int id;
  final String name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}

class ProductionCompany {
  const ProductionCompany({
    required this.id,
    this.logoPath,
    required this.name,
    this.originCountry,
  });
  factory ProductionCompany.fromJson(Map<String, dynamic> json) =>
      ProductionCompany(
        id: json['id'] ?? 0,
        logoPath: json['logo_path'],
        name: json['name'] ?? '',
        originCountry: json['origin_country'],
      );

  final int id;
  final String? logoPath;
  final String name;
  final String? originCountry;

  Map<String, dynamic> toJson() => {
        'id': id,
        'logo_path': logoPath,
        'name': name,
        'origin_country': originCountry,
      };
}

class ProductionCountry {
  const ProductionCountry({
    required this.iso31661,
    required this.name,
  });
  factory ProductionCountry.fromJson(Map<String, dynamic> json) =>
      ProductionCountry(
        iso31661: json['iso_3166_1'] ?? '',
        name: json['name'] ?? '',
      );

  final String iso31661;
  final String name;

  Map<String, dynamic> toJson() => {
        'iso_3166_1': iso31661,
        'name': name,
      };
}

class SpokenLanguage {
  const SpokenLanguage({
    required this.englishName,
    required this.iso6391,
    required this.name,
  });
  factory SpokenLanguage.fromJson(Map<String, dynamic> json) => SpokenLanguage(
        englishName: json['english_name'] ?? '',
        iso6391: json['iso_639_1'] ?? '',
        name: json['name'] ?? '',
      );

  final String englishName;
  final String iso6391;
  final String name;

  Map<String, dynamic> toJson() => {
        'english_name': englishName,
        'iso_639_1': iso6391,
        'name': name,
      };
}
