// Import necesario para StatelessWidget
import 'package:flutter/material.dart';

// Stub para youtube_player_flutter en web
// Este archivo previene errores de compilación en web

// Clases stub que coinciden con las de youtube_player_flutter
class YoutubePlayerController {
  YoutubePlayerController({
    required String initialVideoId,
    required YoutubePlayerFlags flags,
  });

  void dispose() {}
}

class YoutubePlayerFlags {
  const YoutubePlayerFlags({
    bool? hideThumbnail,
    bool? showLiveFullscreenButton,
    bool? mute,
    bool? autoPlay,
    bool? disableDragSeek,
    bool? loop,
    bool? isLive,
    bool? forceHD,
    bool? enableCaption,
    bool? controlsVisibleAtStart,
  });
}

class YoutubePlayer extends StatelessWidget {
  const YoutubePlayer({
    super.key,
    required this.controller,
    this.showVideoProgressIndicator = false,
    this.progressIndicatorColor,
    this.progressColors,
  });

  final YoutubePlayerController controller;
  final bool showVideoProgressIndicator;
  final Color? progressIndicatorColor;
  final ProgressBarColors? progressColors;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(); // Widget vacío para web
  }
}

class ProgressBarColors {
  const ProgressBarColors({
    required this.playedColor,
    required this.handleColor,
  });

  final Color playedColor;
  final Color handleColor;
}