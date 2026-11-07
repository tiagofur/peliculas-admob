import 'package:hive/hive.dart';

part 'temporada.g.dart';

@HiveType(typeId: 5)
class Temporada {
  const Temporada({
    required this.serieId,
    required this.seasonNumber,
    this.episodeCount = 0,
    this.name = '',
    this.overview = '',
    this.posterPath = '',
    this.airDate,
  });

  @HiveField(0)
  final int serieId;

  @HiveField(1)
  final int seasonNumber;

  @HiveField(2)
  final int episodeCount;

  @HiveField(3)
  final String name;

  @HiveField(4)
  final String overview;

  @HiveField(5)
  final String posterPath;

  @HiveField(6)
  final DateTime? airDate;

  String get key => '$serieId-$seasonNumber';

  factory Temporada.fromJson(int serieId, Map<String, dynamic> json) {
    return Temporada(
      serieId: serieId,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      episodeCount:
          (json['episode_count'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      overview: json['overview']?.toString() ?? '',
      posterPath: json['poster_path']?.toString() ?? '',
      airDate: json['air_date'] == null ||
              json['air_date'].toString().isEmpty
          ? null
          : DateTime.tryParse(json['air_date'].toString()),
    );
  }
}
