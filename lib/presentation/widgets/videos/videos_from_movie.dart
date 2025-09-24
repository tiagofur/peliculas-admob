import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
// Solo importar youtube_player_flutter en plataformas no web
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    if (dart.library.html) '../../../core/platform/web_youtube_stub.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/video.dart';
import '../../providers/movies/movies_repository_provider.dart';
import '../../services/pip_service.dart';
import '../shared/cinema_mode.dart';

final videosFromMovieProvider =
    FutureProvider.family<List<Video>, int>((ref, int movieId) {
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
        kIsWeb
            ? _WebYouTubePlayer(
                youtubeId: videos.first.youtubeKey,
                name: videos.first.name,
              )
            : _YouTubeVideoPlayer(
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
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();

    // Solo inicializar el controller en plataformas no web
    if (!kIsWeb) {
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
  }

  @override
  void dispose() {
    if (!kIsWeb && _controller != null) {
      _controller!.dispose();
    }
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
            if (!kIsWeb && _controller != null)
              YoutubePlayer(controller: _controller!),
            if (kIsWeb) _buildWebFallback(),
          ],
        ));
  }

  Widget _buildWebFallback() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ver en YouTube',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openYouTubeVideo(),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir YouTube'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openYouTubeVideo() async {
    final url =
        Uri.parse('https://www.youtube.com/watch?v=${widget.youtubeId}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      LoggerFactory.error('No se pudo abrir YouTube: ${widget.youtubeId}');
    }
  }
}

// Widget específico para web
class _WebYouTubePlayer extends StatelessWidget {
  const _WebYouTubePlayer({
    required this.youtubeId,
    required this.name,
  });

  final String youtubeId;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openYouTubeVideo,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('YouTube'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 32),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Thumbnail con overlay de play
          GestureDetector(
            onTap: _openYouTubeVideo,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(
                      'https://img.youtube.com/vi/$youtubeId/maxresdefault.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black.withValues(alpha: 0.3),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openYouTubeVideo() async {
    final url = Uri.parse('https://www.youtube.com/watch?v=$youtubeId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      LoggerFactory.error('No se pudo abrir YouTube: $youtubeId');
    }
  }
}
