import 'package:hive/hive.dart';

part 'episodio.g.dart';

@HiveType(typeId: 6)
class Episodio {
  const Episodio({
    required this.serieId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.name = '',
    this.overview = '',
    this.stillPath = '',
    this.airDate,
    this.runtime,
    this.voteAverage = 0.0,
  });

  @HiveField(0)
  final int serieId;

  @HiveField(1)
  final int seasonNumber;

  @HiveField(2)
  final int episodeNumber;

  @HiveField(3)
  final String name;

  @HiveField(4)
  final String overview;

  @HiveField(5)
  final String stillPath;

  @HiveField(6)
  final DateTime? airDate;

  @HiveField(7)
  final int? runtime;

  @HiveField(8)
  final double voteAverage;

  String get key => '$serieId-$seasonNumber-$episodeNumber';

  factory Episodio.fromJson(
    int serieId,
    int seasonNumber,
    Map<String, dynamic> json,
  ) {
    return Episodio(
      serieId: serieId,
      seasonNumber: seasonNumber,
      episodeNumber:
          (json['episode_number'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      overview: json['overview']?.toString() ?? '',
      stillPath: json['still_path']?.toString() ?? '',
      airDate: json['air_date'] == null ||
              json['air_date'].toString().isEmpty
          ? null
          : DateTime.tryParse(json['air_date'].toString()),
      runtime: (json['runtime'] as num?)?.toInt(),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
