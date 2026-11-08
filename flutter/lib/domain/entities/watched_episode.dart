import 'package:hive/hive.dart';

part 'watched_episode.g.dart';

@HiveType(typeId: 7)
class WatchedEpisode {
  WatchedEpisode({
    required this.serieId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.watchedDate,
    required this.lastModifiedAt,
    this.serieName = '',
    this.posterPath = '',
    this.isDeleted = false,
    this.syncStatus = 'synced',
  });

  @HiveField(0)
  final int serieId;

  @HiveField(1)
  final int seasonNumber;

  @HiveField(2)
  final int episodeNumber;

  @HiveField(3)
  final DateTime watchedDate;

  @HiveField(4)
  final DateTime lastModifiedAt;

  @HiveField(5)
  final String serieName;

  @HiveField(6)
  final String posterPath;

  @HiveField(7)
  final bool isDeleted;

  @HiveField(8)
  final String syncStatus;

  String get key => '$serieId-$seasonNumber-$episodeNumber';
}
