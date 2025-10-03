import '../../core/video/pip_manager.dart';
import '../../core/logging/logger_factory.dart';

/// Picture-in-Picture Service
///
/// High-level service that uses the PipManager to provide
/// Picture-in-Picture functionality across all platforms.
///
/// This service acts as a facade to the platform-specific PipManager
/// implementations, providing a simple API for the presentation layer.
///
/// Platform support:
/// - Android: Full support via flutter_in_app_pip
/// - iOS: Full support via AVPictureInPictureController
/// - Web: Limited support (user guidance to use browser PiP)
/// - Desktop: Not supported
class PipService {
  factory PipService() => _instance;
  PipService._internal() {
    _pipManager = PipManager();
  }

  static final PipService _instance = PipService._internal();

  static PipService get instance => _instance;

  late final PipManager _pipManager;

  /// Check if PiP is supported on current platform
  bool get isPipSupported => _pipManager.isPipSupported;

  /// Check if PiP is currently active
  bool get isPipActive => _pipManager.isPipActive;

  /// Entra en modo Picture-in-Picture
  ///
  /// [youtubeId] - El ID del video de YouTube
  /// [movieTitle] - El título de la película para mostrar
  ///
  /// Retorna true si PiP se activó correctamente, false en caso contrario
  Future<bool> enterPipMode({
    required String youtubeId,
    required String movieTitle,
  }) async {
    if (!isPipSupported) {
      LoggerFactory.info(
        'PiP no está soportado en esta plataforma. '
        'Android e iOS soportan PiP nativamente. '
        'En web, por favor abre el video directamente en YouTube.',
      );
      return false;
    }

    return await _pipManager.enterPipMode(
      youtubeId: youtubeId,
      movieTitle: movieTitle,
    );
  }

  /// Sale del modo Picture-in-Picture
  Future<void> exitPipMode() async {
    await _pipManager.exitPipMode();
  }

  /// Actualiza los parámetros del PiP (solo Android)
  ///
  /// [height] - Altura de la ventana PiP
  /// [width] - Ancho de la ventana PiP
  void updatePipParams({
    double? height,
    double? width,
  }) {
    _pipManager.updatePipParams();
  }

  /// Libera recursos
  void dispose() {
    _pipManager.dispose();
  }
}
