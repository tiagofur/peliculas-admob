/// Mobile (Android/iOS) implementation of PiP Manager
///
/// Uses flutter_in_app_pip for Android and native iOS AVPictureInPictureController
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_in_app_pip/flutter_in_app_pip.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    if (dart.library.html) '../../core/platform/web_youtube_stub.dart';

import '../../core/logging/logger_factory.dart';
import 'pip_manager.dart';
import 'pip_manager_stub.dart';

/// Returns the appropriate mobile PiP manager based on platform
PipManager getPipManager() {
  if (Platform.isIOS) {
    return PipManagerIOS();
  } else if (Platform.isAndroid) {
    return PipManagerAndroid();
  }
  return PipManagerStub();
}

/// Android implementation using flutter_in_app_pip
class PipManagerAndroid implements PipManager {
  bool _isPipActive = false;

  @override
  bool get isPipSupported => true;

  @override
  bool get isPipActive => _isPipActive;

  @override
  Future<bool> enterPipMode({
    required String youtubeId,
    required String movieTitle,
  }) async {
    try {
      final pipWidget = PiPWidget(
        onPiPClose: () {
          _isPipActive = false;
          LoggerFactory.info('PiP Android cerrado');
        },
        child: _PipVideoPlayer(
          youtubeId: youtubeId,
          movieTitle: movieTitle,
        ),
      );

      PictureInPicture.startPiP(pipWidget: pipWidget);
      _isPipActive = true;
      LoggerFactory.info('PiP Android activado para: $movieTitle');
      return true;
    } catch (e, stackTrace) {
      LoggerFactory.error(
        'Error al activar PiP Android: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<bool> exitPipMode() async {
    try {
      PictureInPicture.stopPiP();
      _isPipActive = false;
      LoggerFactory.info('PiP Android desactivado');
      return true;
    } catch (e, stackTrace) {
      LoggerFactory.error(
        'Error al desactivar PiP Android: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<void> updatePipParams() async {
    try {
      PictureInPicture.updatePiPParams(
        pipParams: const PiPParams(
          pipWindowHeight: 300,
          pipWindowWidth: 400,
          bottomSpace: 80,
          leftSpace: 16,
          rightSpace: 16,
          topSpace: 80,
          movable: true,
        ),
      );
      LoggerFactory.debug('PiP Android params actualizados');
    } catch (e) {
      LoggerFactory.error('Error al actualizar params PiP Android: $e');
    }
  }

  @override
  void dispose() {
    _isPipActive = false;
  }
}

/// iOS implementation using native AVPictureInPictureController
class PipManagerIOS implements PipManager {
  bool _isPipActive = false;

  @override
  bool get isPipSupported => true;

  @override
  bool get isPipActive => _isPipActive;

  @override
  Future<bool> enterPipMode({
    required String youtubeId,
    required String movieTitle,
  }) async {
    try {
      // iOS PiP uses the same flutter_in_app_pip package
      // The native AVAudioSession configuration in AppDelegate enables PiP
      final pipWidget = PiPWidget(
        onPiPClose: () {
          _isPipActive = false;
          LoggerFactory.info('PiP iOS cerrado');
        },
        child: _PipVideoPlayer(
          youtubeId: youtubeId,
          movieTitle: movieTitle,
        ),
      );

      PictureInPicture.startPiP(pipWidget: pipWidget);
      _isPipActive = true;
      LoggerFactory.info('PiP iOS activado para: $movieTitle');
      return true;
    } catch (e, stackTrace) {
      LoggerFactory.error(
        'Error al activar PiP iOS: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<bool> exitPipMode() async {
    try {
      PictureInPicture.stopPiP();
      _isPipActive = false;
      LoggerFactory.info('PiP iOS desactivado');
      return true;
    } catch (e, stackTrace) {
      LoggerFactory.error(
        'Error al desactivar PiP iOS: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<void> updatePipParams() async {
    // iOS handles PiP window sizing automatically
    LoggerFactory.debug('PiP iOS params actualizados (auto)');
  }

  @override
  void dispose() {
    _isPipActive = false;
  }
}

/// Video player widget for PiP mode
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
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.youtubeId,
      autoPlay: true,
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
        ),
      ),
    );
  }
}
