import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/video.dart';
import '../../providers/movies/movies_repository_provider.dart';
import '../../services/pip_service.dart';
import '../shared/cinema_mode.dart';

final FutureProviderFamily<List<Video>, int> videosFromMovieProvider =
    FutureProvider.family((ref, int movieId) {
  final movieRepository = ref.watch(movieRepositoryProvider);
  return movieRepository.getYoutubeVideosById(movieId);
});

class VideosFromMovie extends ConsumerWidget {
  const VideosFromMovie({super.key, required this.movieId});

  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesFromVideo = ref.watch(videosFromMovieProvider(movieId));

    return moviesFromVideo.when(
      data: (videos) => _VideosList(videos: videos),
      error: (_, __) =>
          const Center(child: Text('No se pudo cargar películas similares')),
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _VideosList extends StatelessWidget {
  const _VideosList({required this.videos});

  final List<Video> videos;

  @override
  Widget build(BuildContext context) {
    //* Nada que mostrar
    if (videos.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con título y botón de modo cine
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Videos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              // Botón de modo cine
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade600, Colors.red.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  CinemaMode(
                            youtubeId: videos.first.youtubeKey,
                            movieTitle: videos.first.name,
                          ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.8,
                                  end: 1.0,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: child,
                              ),
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 600),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.movie,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'MODO CINE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        //* Aunque tengo varios videos, sólo quiero mostrar el primero
        _YouTubeVideoPlayer(
          youtubeId: videos.first.youtubeKey,
          name: videos.first.name,
          videos: videos,
        )

        //* Si se desean mostrar todos los videos
        // ...videos.map(
        //   (video) => _YouTubeVideoPlayer(youtubeId: videos.first.youtubeKey, name: video.name)
        // ).toList()
      ],
    );
  }
}

class _YouTubeVideoPlayer extends StatefulWidget {
  const _YouTubeVideoPlayer({
    required this.youtubeId,
    required this.name,
    required this.videos,
  });

  final String youtubeId;
  final String name;
  final List<Video> videos;

  @override
  State<_YouTubeVideoPlayer> createState() => _YouTubeVideoPlayerState();
}

class _YouTubeVideoPlayerState extends State<_YouTubeVideoPlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController(
      initialVideoId: widget.youtubeId,
      flags: const YoutubePlayerFlags(
        hideThumbnail: true,
        showLiveFullscreenButton: false,
        mute: false,
        autoPlay: false,
        disableDragSeek: true,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con título y botón PiP
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Botón PiP
                GestureDetector(
                  onTap: () async {
                    final success = await PipService.instance.enterPipMode(
                      youtubeId: widget.youtubeId,
                      movieTitle: widget.name,
                    );
                    if (success) {
                      // PiP iniciado exitosamente
                      LoggerFactory.info('PiP iniciado para: ${widget.name}');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.picture_in_picture_alt,
                          color: Colors.blue,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'PiP',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            YoutubePlayer(controller: _controller),
          ],
        ));
  }
}
