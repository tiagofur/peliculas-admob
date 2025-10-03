/// Web implementation of PiP Manager using HTML5 Picture-in-Picture API
/// 
/// NOTE: Web PiP for YouTube is limited due to browser restrictions.
/// YouTube videos in iframes cannot directly use the Picture-in-Picture API
/// due to cross-origin restrictions.
/// 
/// Recommended approach for users:
/// - Open video in YouTube directly (button to open in new tab)
/// - Use browser's native PiP controls (right-click on video)
/// 
/// Browser support:
/// - Chrome 70+
/// - Safari 13.1+
/// - Firefox 69+
/// - Edge 79+
library pip_manager_web;

import '../../core/logging/logger_factory.dart';
import 'pip_manager.dart';

/// Returns the web PiP manager
PipManager getPipManager() => PipManagerWeb();

/// Web implementation - Provides fallback with user guidance
/// 
/// Due to browser security restrictions, YouTube videos in iframes
/// cannot programmatically enter Picture-in-Picture mode.
/// Instead, we provide helpful messages and alternative actions.
class PipManagerWeb implements PipManager {
  bool _isPipActive = false;

  @override
  bool get isPipSupported {
    // Web browsers support PiP, but YouTube iframes have restrictions
    // We return true to show alternative options to users
    return true;
  }

  @override
  bool get isPipActive => _isPipActive;

  @override
  Future<bool> enterPipMode({
    required String youtubeId,
    required String movieTitle,
  }) async {
    LoggerFactory.info(
      'PiP Web: Debido a restricciones del navegador, '
      'los videos de YouTube en iframes no pueden activar PiP automáticamente.',
    );

    LoggerFactory.info(
      'Alternativas para el usuario:\n'
      '1. Abrir el video en YouTube (youtube.com/watch?v=$youtubeId)\n'
      '2. Hacer clic derecho en el video y seleccionar "Picture-in-Picture"\n'
      '3. Usar el botón de PiP en los controles del reproductor de YouTube',
    );

    // Could open YouTube in new tab as fallback
    // window.open('https://www.youtube.com/watch?v=$youtubeId', '_blank');

    return false;
  }

  @override
  Future<bool> exitPipMode() async {
    _isPipActive = false;
    LoggerFactory.info('PiP Web: El usuario debe cerrar PiP desde el navegador');
    return false;
  }

  @override
  Future<void> updatePipParams() async {
    // Web PiP window sizing is controlled by the browser
    LoggerFactory.debug('PiP Web params (controlado por navegador)');
  }

  @override
  void dispose() {
    _isPipActive = false;
  }
}

