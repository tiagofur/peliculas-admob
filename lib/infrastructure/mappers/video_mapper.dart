import '../../domain/entities/video.dart';
import '../models/moviedb/moviedb_videos.dart';

class VideoMapper {
  static Video moviedbVideoToEntity(Result moviedbVideo) => Video(
      id: moviedbVideo.id,
      name: moviedbVideo.name,
      youtubeKey: moviedbVideo.key,
      publishedAt: moviedbVideo.publishedAt);
}
