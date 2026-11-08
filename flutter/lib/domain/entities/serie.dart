import 'package:hive/hive.dart';

part 'serie.g.dart';

@HiveType(typeId: 4)
class Serie {
  Serie({
    required this.id,
    required this.name,
    this.originalName = '',
    this.overview = '',
    this.posterPath = '',
    this.backdropPath = '',
    this.firstAirDate,
    this.originCountry = const [],
    this.genreIds = const [],
    this.voteAverage = 0.0,
    this.voteCount = 0,
    this.popularity = 0.0,
    this.originalLanguage = '',
    this.numberOfSeasons = 0,
    this.numberOfEpisodes = 0,
    this.episodeRunTime = const [],
    this.status = '',
    this.inProduction = false,
    this.type = '',
    this.networks = const [],
  });

  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String originalName;

  @HiveField(3)
  final String overview;

  @HiveField(4)
  final String posterPath;

  @HiveField(5)
  final String backdropPath;

  @HiveField(6)
  final DateTime? firstAirDate;

  @HiveField(7)
  final List<String> originCountry;

  @HiveField(8)
  final List<int> genreIds;

  @HiveField(9)
  final double voteAverage;

  @HiveField(10)
  final int voteCount;

  @HiveField(11)
  final double popularity;

  @HiveField(12)
  final String originalLanguage;

  @HiveField(13)
  final int numberOfSeasons;

  @HiveField(14)
  final int numberOfEpisodes;

  @HiveField(15)
  final List<int> episodeRunTime;

  @HiveField(16)
  final String status;

  @HiveField(17)
  final bool inProduction;

  @HiveField(18)
  final String type;

  @HiveField(19)
  final List<String> networks;

  factory Serie.fromJson(Map<String, dynamic> json) {
    return Serie(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      originalName: json['original_name']?.toString() ?? '',
      overview: json['overview']?.toString() ?? '',
      posterPath: json['poster_path']?.toString() ?? '',
      backdropPath: json['backdrop_path']?.toString() ?? '',
      firstAirDate: _parseDate(json['first_air_date']),
      originCountry: json['origin_country'] is List
          ? List<String>.from(
              (json['origin_country'] as List).map((e) => e.toString()))
          : const [],
      genreIds: json['genre_ids'] != null
          ? List<int>.from(
              (json['genre_ids'] as List).map((e) => (e as num).toInt()))
          : const [],
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0.0,
      originalLanguage: json['original_language']?.toString() ?? '',
      numberOfSeasons:
          (json['number_of_seasons'] as num?)?.toInt() ?? 0,
      numberOfEpisodes:
          (json['number_of_episodes'] as num?)?.toInt() ?? 0,
      episodeRunTime: json['episode_run_time'] is List
          ? List<int>.from((json['episode_run_time'] as List)
              .map((e) => (e as num).toInt()))
          : const [],
      status: json['status']?.toString() ?? '',
      inProduction: json['in_production'] as bool? ?? false,
      type: json['type']?.toString() ?? '',
      networks: _networkNames(json['networks']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'original_name': originalName,
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'first_air_date': firstAirDate?.toIso8601String().split('T').first,
      'origin_country': originCountry,
      'genre_ids': genreIds,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'popularity': popularity,
      'original_language': originalLanguage,
      'number_of_seasons': numberOfSeasons,
      'number_of_episodes': numberOfEpisodes,
      'episode_run_time': episodeRunTime,
      'status': status,
      'in_production': inProduction,
      'type': type,
      'networks': networks.map((n) => {'name': n}).toList(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static List<String> _networkNames(dynamic value) {
    if (value is! List) return [];
    return value
        .map((e) {
          if (e is Map && e['name'] != null) return e['name'].toString();
          return e.toString();
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }
}
