import 'package:hive/hive.dart';

part 'series_progress.g.dart';

@HiveType(typeId: 8)
enum SeriesWatchStatus {
  @HiveField(0)
  notStarted,
  @HiveField(1)
  watching,
  @HiveField(2)
  completed,
  @HiveField(3)
  abandoned,
}

@HiveType(typeId: 9)
class SeriesProgress {
  const SeriesProgress({
    required this.serieId,
    required this.watchedEpisodeCount,
    required this.totalEpisodes,
    required this.status,
    this.lastWatchedAt,
  });

  @HiveField(0)
  final int serieId;

  @HiveField(1)
  final int watchedEpisodeCount;

  @HiveField(2)
  final int totalEpisodes;

  @HiveField(3)
  final SeriesWatchStatus status;

  @HiveField(4)
  final DateTime? lastWatchedAt;

  double get percent {
    if (totalEpisodes <= 0) return 0.0;
    return (watchedEpisodeCount / totalEpisodes).clamp(0.0, 1.0);
  }

  factory SeriesProgress.calculate({
    required int serieId,
    required Set<String> watchedEpisodeKeys,
    required int totalEpisodes,
    DateTime? lastWatchedAt,
  }) {
    final prefix = '$serieId-';
    final count =
        watchedEpisodeKeys.where((k) => k.startsWith(prefix)).length;
    final status = count <= 0
        ? SeriesWatchStatus.notStarted
        : count >= totalEpisodes && totalEpisodes > 0
            ? SeriesWatchStatus.completed
            : SeriesWatchStatus.watching;
    return SeriesProgress(
      serieId: serieId,
      watchedEpisodeCount: count,
      totalEpisodes: totalEpisodes,
      status: status,
      lastWatchedAt: lastWatchedAt,
    );
  }
}
