/// Picture-in-Picture Manager Interface
/// 
/// Provides a unified interface for managing Picture-in-Picture (PiP) mode
/// across different platforms (Android, iOS, Web).
/// 
/// Platform-specific implementations:
/// - Android: Uses flutter_in_app_pip package
/// - iOS: Uses AVPictureInPictureController via native integration
/// - Web: Uses HTML5 Picture-in-Picture API
/// - Desktop: Not supported (returns false for isPipSupported)
library pip_manager;

// Platform-specific conditional imports
import 'pip_manager_stub.dart'
    if (dart.library.io) 'pip_manager_mobile.dart'
    if (dart.library.html) 'pip_manager_web.dart';

/// Abstract interface for Picture-in-Picture functionality
abstract class PipManager {
  /// Factory constructor that returns the appropriate platform implementation
  factory PipManager() {
    return getPipManager();
  }

  /// Check if Picture-in-Picture is supported on the current platform
  bool get isPipSupported;

  /// Get the current PiP status
  bool get isPipActive;

  /// Enter Picture-in-Picture mode
  /// 
  /// [youtubeId] - The YouTube video ID to play
  /// [movieTitle] - The title of the movie (for display)
  /// 
  /// Returns true if PiP was successfully activated, false otherwise
  Future<bool> enterPipMode({
    required String youtubeId,
    required String movieTitle,
  });

  /// Exit Picture-in-Picture mode
  /// 
  /// Returns true if PiP was successfully exited, false otherwise
  Future<bool> exitPipMode();

  /// Update PiP window parameters (size, position)
  /// 
  /// Only applicable on supported platforms (Android)
  Future<void> updatePipParams();

  /// Dispose of resources
  void dispose();
}
