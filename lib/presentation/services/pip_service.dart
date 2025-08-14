import 'package:flutter/material.dart';
import 'package:flutter_in_app_pip/flutter_in_app_pip.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class PipService {
  factory PipService() => _instance;
  PipService._internal();
  static final PipService _instance = PipService._internal();

  static PipService get instance => _instance;

  /// Entra en modo Picture-in-Picture
  Future<bool> enterPipMode({
    required String youtubeId,
    required String movieTitle,
  }) async {
    try {
      final pipWidget = PiPWidget(
        onPiPClose: () {
          // Manejar el cierre del PiP
          debugPrint('PiP cerrado');
        },
        child: _PipVideoPlayer(
          youtubeId: youtubeId,
          movieTitle: movieTitle,
        ),
      );

      PictureInPicture.startPiP(pipWidget: pipWidget);
      return true;
    } catch (e) {
      debugPrint('Error al entrar en modo PiP: $e');
      return false;
    }
  }

  /// Sale del modo Picture-in-Picture
  Future<void> exitPipMode() async {
    try {
      PictureInPicture.stopPiP();
    } catch (e) {
      debugPrint('Error al salir del modo PiP: $e');
    }
  }

  /// Verifica si el dispositivo soporta PiP
  bool get isPipSupported {
    // flutter_in_app_pip funciona en todas las plataformas
    return true;
  }

  /// Actualiza los parámetros del PiP
  void updatePipParams({
    double? height,
    double? width,
    PIPViewCorner? corner,
  }) {
    PictureInPicture.updatePiPParams(
      pipParams: PiPParams(
        pipWindowHeight: height ?? 200,
        pipWindowWidth: width ?? 300,
        bottomSpace: 80,
        leftSpace: 16,
        rightSpace: 16,
        topSpace: 80,
        movable: true,
        resizable: false,
        initialCorner: corner ?? PIPViewCorner.bottomRight,
      ),
    );
  }
}

/// Widget interno para mostrar el video en modo PiP
class _PipVideoPlayer extends StatefulWidget {
  const _PipVideoPlayer({
    required this.youtubeId,
    required this.movieTitle,
  });
  final String youtubeId;
  final String movieTitle;

  @override
  State<_PipVideoPlayer> createState() => _PipVideoPlayerState();
}

class _PipVideoPlayerState extends State<_PipVideoPlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.youtubeId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: false,
        loop: false,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Barra de título del PiP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.movieTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => PipService.instance.exitPipMode(),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          // Reproductor de YouTube
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => YoutubePlayer(
                      controller: _controller,
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: Colors.red,
                      progressColors: const ProgressBarColors(
                        playedColor: Colors.red,
                        handleColor: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
