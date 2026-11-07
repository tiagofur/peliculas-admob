class SerieMovieDB {
  SerieMovieDB({
    required this.id,
    required this.name,
    required this.originalName,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.genreIds,
    required this.originalLanguage,
    required this.originCountry,
    required this.popularity,
    required this.voteAverage,
    required this.voteCount,
    this.firstAirDate,
  });

  factory SerieMovieDB.fromJson(Map<String, dynamic> json) => SerieMovieDB(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? 'No Title',
        originalName: json['original_name']?.toString() ?? '',
        overview: json['overview']?.toString() ?? '',
        posterPath: json['poster_path']?.toString() ?? '',
        backdropPath: json['backdrop_path']?.toString() ?? '',
        genreIds: json['genre_ids'] != null
            ? List<int>.from(
                (json['genre_ids'] as List).map((x) => (x as num).toInt()))
            : const [],
        originalLanguage: json['original_language']?.toString() ?? '',
        originCountry: json['origin_country'] is List
            ? List<String>.from(
                (json['origin_country'] as List).map((e) => e.toString()))
            : const [],
        popularity: (json['popularity'] as num?)?.toDouble() ?? 0.0,
        voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
        voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
        firstAirDate: json['first_air_date'] == null ||
                json['first_air_date'].toString().isEmpty
            ? null
            : DateTime.tryParse(json['first_air_date'].toString()),
      );

  final int id;
  final String name;
  final String originalName;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final List<int> genreIds;
  final String originalLanguage;
  final List<String> originCountry;
  final double popularity;
  final double voteAverage;
  final int voteCount;
  final DateTime? firstAirDate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'original_name': originalName,
        'overview': overview,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'genre_ids': genreIds,
        'original_language': originalLanguage,
        'origin_country': originCountry,
        'popularity': popularity,
        'vote_average': voteAverage,
        'vote_count': voteCount,
        'first_air_date': firstAirDate != null
            ? "${firstAirDate!.year.toString().padLeft(4, '0')}-${firstAirDate!.month.toString().padLeft(2, '0')}-${firstAirDate!.day.toString().padLeft(2, '0')}"
            : null,
      };
}
