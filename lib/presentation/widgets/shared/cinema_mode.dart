// ignore_for_file: use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/logging/logger_factory.dart';
import '../../services/pip_service.dart';

// Solo importar youtube_player_flutter en plataformas no web
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    if (dart.library.html) '../../../core/platform/web_youtube_stub.dart';

class CinemaMode extends StatefulWidget {
  const CinemaMode({
    super.key,
    required this.youtubeId,
    required this.movieTitle,
  });

  final String youtubeId;
  final String movieTitle;

  @override
  State<CinemaMode> createState() => _CinemaModeState();
}

class _CinemaModeState extends State<CinemaMode> with TickerProviderStateMixin {
  YoutubePlayerController? _controller;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _showControls = true;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();

    // Configurar modo cine
    _enterCinemaMode();

    // Configurar controlador de YouTube solo en plataformas no web
    if (!kIsWeb) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.youtubeId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
        ),
      );
    }

    // Configurar animaciones
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Iniciar animaciones
    _fadeController.forward();
    _slideController.forward();

    // Auto-ocultar controles después de 3 segundos
    _startControlsTimer();
  }

  void _enterCinemaMode() {
    // SystemChrome no es compatible con web
    if (kIsWeb) return;

    // Ocultar barra de estado y navegación
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Forzar orientación horizontal para mejor experiencia
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _exitCinemaMode() {
    // SystemChrome no es compatible con web
    if (kIsWeb) return;

    // Restaurar UI del sistema
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Restaurar orientación
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _startControlsTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _startControlsTimer();
    }
  }

  @override
  void dispose() {
    _exitCinemaMode();
    if (!kIsWeb && _controller != null) {
      _controller!.close();
    }
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video player con efecto de fade
            FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: kIsWeb
                    ? _buildWebPlayer()
                    : _controller != null
                        ? YoutubePlayer(
                            controller: _controller!,
                          )
                        : const SizedBox(),
              ),
            ),

            // Overlay con controles cinematográficos
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Header con título y botón de salir
                      SlideTransition(
                        position: _slideAnimation,
                        child: _CinemaHeader(
                          title: widget.movieTitle,
                          onExit: () => Navigator.of(context).pop(),
                        ),
                      ),

                      const Spacer(),

                      // Footer con controles adicionales
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -1),
                          end: Offset.zero,
                        ).animate(_slideController),
                        child: _CinemaFooter(
                          onFullscreen: () {
                            setState(() {
                              _isFullscreen = !_isFullscreen;
                            });
                          },
                          isFullscreen: _isFullscreen,
                          onPip: () async {
                            final success =
                                await PipService.instance.enterPipMode(
                              youtubeId: widget.youtubeId,
                              movieTitle: widget.movieTitle,
                            );
                            if (success && mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebPlayer() {
    return GestureDetector(
      onTap: _openYouTubeInNewTab,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
                'https://img.youtube.com/vi/${widget.youtubeId}/maxresdefault.jpg'),
            fit: BoxFit.contain,
          ),
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 120,
                ),
                SizedBox(height: 24),
                Text(
                  'Toca para ver en YouTube',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 2),
                        blurRadius: 4,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openYouTubeInNewTab() async {
    final url =
        Uri.parse('https://www.youtube.com/watch?v=${widget.youtubeId}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      LoggerFactory.error('No se pudo abrir YouTube: ${widget.youtubeId}');
    }
  }
}

class _CinemaHeader extends StatelessWidget {
  const _CinemaHeader({
    required this.title,
    required this.onExit,
  });

  final String title;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Botón de salir con efecto cinematográfico
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: onExit,
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Título con efecto de texto cinematográfico
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    offset: Offset(0, 2),
                    blurRadius: 4,
                    color: Colors.black54,
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CinemaFooter extends StatelessWidget {
  const _CinemaFooter({
    required this.onFullscreen,
    required this.isFullscreen,
    required this.onPip,
  });

  final VoidCallback onFullscreen;
  final bool isFullscreen;
  final VoidCallback onPip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Botón Picture-in-Picture
          GestureDetector(
            onTap: onPip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.picture_in_picture_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'PiP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Indicador de modo cine
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Row(
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
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
